package com.utility.app.utility_tool

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.View
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.google.ar.core.Anchor
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.DepthPoint
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.Trackable
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class SmartMeasureArViewFactory(
    private val messenger: BinaryMessenger,
    private val context: Context
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return SmartMeasureArView(context, messenger, viewId)
    }
}

class SmartMeasureArView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int
) : PlatformView, GLSurfaceView.Renderer, MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.utility.app/smart_measure_ar_view_$viewId")
    private val glSurfaceView = GLSurfaceView(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val COORDS_PER_VERTEX = 2
        private const val TEXCOORDS_PER_VERTEX = 2
        private const val FLOAT_SIZE = 4
        private val QUAD_COORDS = floatArrayOf(
            -1.0f, -1.0f,
            +1.0f, -1.0f,
            -1.0f, +1.0f,
            +1.0f, +1.0f
        )

        // Reticle stabilisation. Tune on-device if needed.
        private const val RETICLE_EMA_ALPHA = 0.2f    // low-pass weight of each new hit (60 fps)
        private const val RETICLE_DEADBAND_M = 0.003f // published reticle ignores jitter below 3 mm
        private const val RETICLE_JUMP_M = 0.08f      // a bigger jump = new surface, reset the filter
        private const val MIN_RANGE_M = 0.2f          // ARCore depth/planes get unreliable closer than this
        private const val MAX_RANGE_M = 3.5f          // error grows quickly beyond this
    }

    private var session: Session? = null
    private var isSessionConfigured = false
    private var cameraTextureId = -1

    // Rendering buffers for camera background
    private var quadCoords: FloatBuffer? = null
    private var quadTexCoords: FloatBuffer? = null
    private var glProgram = 0
    private var positionAttrib = 0
    private var texCoordAttrib = 0
    private var textureUniform = 0

    private var viewportWidth = 1080
    private var viewportHeight = 2400
    private var viewportChanged = false
    private var lastDisplayRotation = -1
    private var hasTransformedUvs = false

    // State. ARCore objects are touched only on the GL thread; the main thread
    // reads immutable snapshots published once per frame.
    private val activeAnchors = ConcurrentHashMap<String, Anchor>()
    @Volatile private var statusSnapshot: Map<String, Any> = mapOf(
        "hasSurface" to false, "canPlace" to false, "planesCount" to 0,
        "surfaceType" to "NONE", "trackingState" to "SEARCHING",
        "statusMessage" to "Move your phone slowly to find a surface", "hint" to ""
    )
    @Volatile private var anchorSnapshot: Map<String, Any> = emptyMap()

    // Stable centre-reticle hit (GL thread only)
    private var reticleTrackable: Trackable? = null
    private var reticleRotation = floatArrayOf(0f, 0f, 0f, 1f)
    private var reticleSmoothed: FloatArray? = null
    private var reticlePublished: FloatArray? = null

    init {
        channel.setMethodCallHandler(this)

        glSurfaceView.preserveEGLContextOnPause = true
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setRenderer(this)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        initSession()
    }

    private fun initSession() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        try {
            val arSession = Session(context)
            val config = Config(arSession).apply {
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                if (arSession.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    depthMode = Config.DepthMode.AUTOMATIC
                }
                // No instant placement: its estimated depth drifts, which made points slide.
                instantPlacementMode = Config.InstantPlacementMode.DISABLED
                lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                focusMode = Config.FocusMode.AUTO
            }
            arSession.configure(config)
            arSession.resume() // Opens the camera hardware and begins streaming frames!
            session = arSession
            isSessionConfigured = true

            if (cameraTextureId != -1) {
                arSession.setCameraTextureName(cameraTextureId)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun getView(): View = glSurfaceView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        try {
            session?.pause()
            session?.close()
            session = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // --- GLSurfaceView.Renderer Implementation ---

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)

        // Generate OES texture for ARCore camera
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        cameraTextureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

        setupShaders()
        setupQuadBuffers()

        session?.setCameraTextureName(cameraTextureId)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height
        viewportChanged = true
        GLES20.glViewport(0, 0, width, height)
    }

    private fun getDisplayRotation(): Int {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                glSurfaceView.display?.rotation
                    ?: (context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)?.defaultDisplay?.rotation
                    ?: Surface.ROTATION_0
            } else {
                @Suppress("DEPRECATION")
                (context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)?.defaultDisplay?.rotation
                    ?: Surface.ROTATION_0
            }
        } catch (e: Exception) {
            Surface.ROTATION_0
        }
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

        if (session == null) {
            initSession()
        }

        val arSession = session ?: return
        if (!isSessionConfigured) return

        try {
            val currentRotation = getDisplayRotation()
            if (viewportChanged || currentRotation != lastDisplayRotation) {
                arSession.setDisplayGeometry(currentRotation, viewportWidth, viewportHeight)
                lastDisplayRotation = currentRotation
                viewportChanged = false
                hasTransformedUvs = false
            }

            arSession.setCameraTextureName(cameraTextureId)
            val frame = arSession.update()

            // Always render the camera background feed so the user sees live video immediately!
            drawBackground(frame)

            val tracking = frame.camera.trackingState == TrackingState.TRACKING
            if (tracking) updateReticle(frame) else resetReticle()
            publishStatus(frame, arSession, tracking)
            publishAnchors(frame, tracking)
        } catch (e: Exception) {
            // Ignore camera frame drop exceptions during resume/pause
        }
    }

    private fun resetReticle() {
        reticleTrackable = null
        reticleSmoothed = null
        reticlePublished = null
    }

    private fun dist(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]; val dy = a[1] - b[1]; val dz = a[2] - b[2]
        return Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }

    /** Centre hit-test against real geometry only: tracked plane polygons first, depth as fallback.
     *  Raw feature points, estimated planes and instant placement are ignored. */
    private fun updateReticle(frame: Frame) {
        val hits = frame.hitTest(viewportWidth * 0.5f, viewportHeight * 0.5f)
        val hit = hits.firstOrNull { h ->
            val t = h.trackable
            t is Plane && t.trackingState == TrackingState.TRACKING && t.subsumedBy == null &&
                t.isPoseInPolygon(h.hitPose)
        } ?: hits.firstOrNull { h ->
            val t = h.trackable
            t is DepthPoint && t.trackingState == TrackingState.TRACKING
        }

        if (hit == null) {
            resetReticle()
            return
        }

        val raw = hit.hitPose.translation
        val smoothed = reticleSmoothed
        val published = reticlePublished
        // Depth points are new objects every frame, so only a change of plane counts as a new surface.
        val sameSurface = (hit.trackable is DepthPoint && reticleTrackable is DepthPoint) ||
            hit.trackable == reticleTrackable
        if (smoothed == null || published == null || !sameSurface || dist(smoothed, raw) > RETICLE_JUMP_M) {
            reticleSmoothed = raw.copyOf()
            reticlePublished = raw.copyOf()
        } else {
            for (i in 0..2) smoothed[i] += RETICLE_EMA_ALPHA * (raw[i] - smoothed[i])
            if (dist(published, smoothed) > RETICLE_DEADBAND_M) reticlePublished = smoothed.copyOf()
        }
        reticleTrackable = hit.trackable
        reticleRotation = hit.hitPose.rotationQuaternion
    }

    private fun publishStatus(frame: Frame, arSession: Session, tracking: Boolean) {
        var count = 0
        var type = "NONE"
        if (tracking) {
            for (plane in arSession.getAllTrackables(Plane::class.java)) {
                if (plane.trackingState == TrackingState.TRACKING && plane.subsumedBy == null) {
                    count++
                    type = if (plane.type == Plane.Type.VERTICAL) "VERTICAL" else "HORIZONTAL"
                }
            }
        }
        if (reticleTrackable is DepthPoint) type = "DEPTH"

        val reticle = reticlePublished
        val onSurface = tracking && reticle != null
        val message = when {
            !tracking -> when (frame.camera.trackingFailureReason) {
                TrackingFailureReason.INSUFFICIENT_LIGHT -> "Tracking limited • More light needed"
                TrackingFailureReason.INSUFFICIENT_FEATURES -> "Point at a textured surface"
                TrackingFailureReason.EXCESSIVE_MOTION -> "Move your phone slowly"
                else -> "Tracking limited • Move your phone slowly"
            }
            !onSurface -> "Move your phone slowly to find a surface"
            activeAnchors.isEmpty() -> "Surface detected • Ready to measure"
            else -> "Move to second point & tap +"
        }
        // Range hint while placement is still allowed (only shown when it applies).
        val hint = if (onSurface && reticle != null) {
            val range = dist(reticle, frame.camera.pose.translation)
            when {
                range < MIN_RANGE_M -> "Move further away"
                range > MAX_RANGE_M -> "Move closer"
                else -> ""
            }
        } else ""
        statusSnapshot = mapOf(
            "hint" to hint,
            "hasSurface" to onSurface,
            "canPlace" to onSurface,
            "planesCount" to count,
            "surfaceType" to type,
            "trackingState" to frame.camera.trackingState.name,
            "statusMessage" to message
        )
    }

    /** Projects every anchor's *current* pose (so points follow ARCore's map refinements) and the reticle. */
    private fun publishAnchors(frame: Frame, tracking: Boolean) {
        if (!tracking) {
            anchorSnapshot = emptyMap() // Dart hides points rather than leaving them at stale screen positions
            return
        }
        val camera = frame.camera
        val projMatrix = FloatArray(16)
        val viewMatrix = FloatArray(16)
        val viewProjMatrix = FloatArray(16)
        camera.getProjectionMatrix(projMatrix, 0, 0.05f, 50.0f)
        camera.getViewMatrix(viewMatrix, 0)
        Matrix.multiplyMM(viewProjMatrix, 0, projMatrix, 0, viewMatrix, 0)

        val resultMap = mutableMapOf<String, Any>()
        val worldPosIn = FloatArray(4)
        val clipPosOut = FloatArray(4)

        for ((id, anchor) in activeAnchors) {
            if (anchor.trackingState != TrackingState.TRACKING) continue
            val pose = anchor.pose
            worldPosIn[0] = pose.tx(); worldPosIn[1] = pose.ty(); worldPosIn[2] = pose.tz(); worldPosIn[3] = 1.0f
            Matrix.multiplyMV(clipPosOut, 0, viewProjMatrix, 0, worldPosIn, 0)
            val w = clipPosOut[3]
            val inFront = w > 0.05f
            resultMap[id] = mapOf(
                "x" to if (inFront) ((clipPosOut[0] / w + 1.0f) * 0.5f).toDouble() else -1.0,
                "y" to if (inFront) ((1.0f - clipPosOut[1] / w) * 0.5f).toDouble() else -1.0,
                "inView" to inFront, // behind the camera = hide; off-screen in front still draws to the edge
                "worldX" to pose.tx().toDouble(),
                "worldY" to pose.ty().toDouble(),
                "worldZ" to pose.tz().toDouble()
            )
        }

        val r = reticlePublished
        resultMap["__reticle__"] = if (r != null) mapOf(
            "worldX" to r[0].toDouble(), "worldY" to r[1].toDouble(), "worldZ" to r[2].toDouble(), "hasHit" to true
        ) else mapOf("hasHit" to false)

        anchorSnapshot = resultMap
    }

    private fun setupShaders() {
        val vertexShaderCode = """
            attribute vec4 a_Position;
            attribute vec2 a_TexCoord;
            varying vec2 v_TexCoord;
            void main() {
                gl_Position = a_Position;
                v_TexCoord = a_TexCoord;
            }
        """.trimIndent()

        val fragmentShaderCode = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 v_TexCoord;
            uniform samplerExternalOES sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, v_TexCoord);
            }
        """.trimIndent()

        val vShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
        val fShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)

        glProgram = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vShader)
            GLES20.glAttachShader(it, fShader)
            GLES20.glLinkProgram(it)
        }

        positionAttrib = GLES20.glGetAttribLocation(glProgram, "a_Position")
        texCoordAttrib = GLES20.glGetAttribLocation(glProgram, "a_TexCoord")
        textureUniform = GLES20.glGetUniformLocation(glProgram, "sTexture")
    }

    private fun setupQuadBuffers() {
        val bbCoords = ByteBuffer.allocateDirect(QUAD_COORDS.size * FLOAT_SIZE)
        bbCoords.order(ByteOrder.nativeOrder())
        quadCoords = bbCoords.asFloatBuffer().apply {
            put(QUAD_COORDS)
            position(0)
        }

        val bbTexCoords = ByteBuffer.allocateDirect(4 * TEXCOORDS_PER_VERTEX * FLOAT_SIZE)
        bbTexCoords.order(ByteOrder.nativeOrder())
        quadTexCoords = bbTexCoords.asFloatBuffer()
    }

    private fun drawBackground(frame: Frame) {
        val coords = quadCoords ?: return
        val texCoords = quadTexCoords ?: return

        // Recalculate texture UVs when display geometry changes or on first frame.
        // ARCore automatically adjusts for sensor orientation (landscape to portrait),
        // display rotation, and center-crops the feed to preserve the natural aspect ratio.
        if (frame.hasDisplayGeometryChanged() || !hasTransformedUvs) {
            coords.position(0)
            texCoords.position(0)
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                coords,
                Coordinates2d.TEXTURE_NORMALIZED,
                texCoords
            )
            hasTransformedUvs = true
        }

        coords.position(0)
        texCoords.position(0)

        GLES20.glDepthMask(false)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)

        GLES20.glUseProgram(glProgram)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glUniform1i(textureUniform, 0)

        GLES20.glVertexAttribPointer(positionAttrib, COORDS_PER_VERTEX, GLES20.GL_FLOAT, false, 0, coords)
        GLES20.glVertexAttribPointer(texCoordAttrib, TEXCOORDS_PER_VERTEX, GLES20.GL_FLOAT, false, 0, texCoords)

        GLES20.glEnableVertexAttribArray(positionAttrib)
        GLES20.glEnableVertexAttribArray(texCoordAttrib)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(positionAttrib)
        GLES20.glDisableVertexAttribArray(texCoordAttrib)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(true)
    }

    private fun compileShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)
        return shader
    }

    // --- MethodChannel Call Handler ---

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "querySurfaceStatus" -> result.success(statusSnapshot)
            "hitTest" -> {
                // Places a point at the stabilised centre reticle. Runs on the GL thread between
                // session.update() calls and anchors to the hit plane / depth trackable.
                glSurfaceView.queueEvent {
                    val trackable = reticleTrackable
                    val position = reticlePublished
                    val anchor = try {
                        if (trackable != null && position != null &&
                            trackable.trackingState == TrackingState.TRACKING) {
                            trackable.createAnchor(Pose(position, reticleRotation))
                        } else null
                    } catch (e: Exception) { null }

                    if (anchor == null) {
                        mainHandler.post { result.error("NO_HIT", "No tracked surface under the reticle", null) }
                        return@queueEvent
                    }
                    val anchorId = UUID.randomUUID().toString()
                    activeAnchors[anchorId] = anchor
                    val pose = anchor.pose
                    mainHandler.post {
                        result.success(mapOf(
                            "anchorId" to anchorId,
                            "x" to pose.tx().toDouble(),
                            "y" to pose.ty().toDouble(),
                            "z" to pose.tz().toDouble(),
                            "planeType" to if (trackable is Plane) "PLANE" else "DEPTH"
                        ))
                    }
                }
            }
            "getAnchorScreenPositions" -> result.success(anchorSnapshot)
            "removeAnchor" -> {
                val anchor = call.argument<String>("anchorId")?.let { activeAnchors.remove(it) }
                if (anchor != null) glSurfaceView.queueEvent { anchor.detach() }
                result.success(true)
            }
            "clearAllAnchors" -> {
                val anchors = activeAnchors.values.toList()
                activeAnchors.clear()
                glSurfaceView.queueEvent { anchors.forEach { it.detach() } }
                result.success(true)
            }
            "pauseSession" -> {
                try {
                    session?.pause()
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            "resumeSession" -> {
                try {
                    if (session == null) {
                        initSession()
                    } else {
                        session?.resume()
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }
}
