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
import android.view.View
import androidx.core.content.ContextCompat
import com.google.ar.core.Anchor
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.InstantPlacementPoint
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Pose
import com.google.ar.core.Session
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

    private var session: Session? = null
    private var isSessionConfigured = false
    private var cameraTextureId = -1

    // Rendering buffers
    private var quadVertices: FloatBuffer? = null
    private var quadTexCoords: FloatBuffer? = null
    private var transformedTexCoords: FloatBuffer? = null
    private var glProgram = 0
    private var positionAttrib = 0
    private var texCoordAttrib = 0
    private var textureUniform = 0

    private var viewportWidth = 1080
    private var viewportHeight = 2400
    private var viewportChanged = false

    // State Tracking
    @Volatile
    private var latestFrame: Frame? = null
    private val activeAnchors = ConcurrentHashMap<String, Anchor>()
    private var hasSurface = false
    private var surfaceType = "NONE"
    private var planesCount = 0
    private var trackingStateStr = "SEARCHING"

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
                instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
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

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

        if (session == null) {
            initSession()
        }

        val arSession = session ?: return
        if (!isSessionConfigured) return

        try {
            if (viewportChanged) {
                arSession.setDisplayGeometry(0, viewportWidth, viewportHeight)
                viewportChanged = false
            }

            arSession.setCameraTextureName(cameraTextureId)
            val frame = arSession.update()
            latestFrame = frame

            // Always render the camera background feed so the user sees live video immediately!
            drawBackground(frame)

            val camera = frame.camera
            if (camera.trackingState == TrackingState.TRACKING) {
                updateSurfaceTracking(frame, arSession)
            } else {
                hasSurface = false
                trackingStateStr = "SEARCHING"
            }
        } catch (e: Exception) {
            // Ignore camera frame drop exceptions during resume/pause
        }
    }

    private fun updateSurfaceTracking(frame: Frame, arSession: Session) {
        val planes = arSession.getAllTrackables(Plane::class.java)
        var detected = false
        var count = 0
        var type = "NONE"

        for (plane in planes) {
            if (plane.trackingState == TrackingState.TRACKING && plane.subsumedBy == null) {
                count++
                detected = true
                type = if (plane.type == Plane.Type.VERTICAL) "VERTICAL" else "HORIZONTAL"
            }
        }

        // When instant placement is enabled, the camera can track surfaces immediately
        if (!detected && frame.camera.trackingState == TrackingState.TRACKING) {
            detected = true
            type = "INSTANT_SURFACE"
        }

        hasSurface = detected
        planesCount = count
        surfaceType = type
        trackingStateStr = if (detected) "SURFACE_DETECTED" else "SEARCHING"
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
        val quadCoords = floatArrayOf(
            -1.0f, -1.0f, 0.0f,
            -1.0f,  1.0f, 0.0f,
             1.0f, -1.0f, 0.0f,
             1.0f,  1.0f, 0.0f
        )
        val texCoords = floatArrayOf(
            0.0f, 1.0f,
            0.0f, 0.0f,
            1.0f, 1.0f,
            1.0f, 0.0f
        )

        quadVertices = ByteBuffer.allocateDirect(quadCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(quadCoords); position(0) }

        quadTexCoords = ByteBuffer.allocateDirect(texCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(texCoords); position(0) }

        transformedTexCoords = ByteBuffer.allocateDirect(texCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
    }

    private fun drawBackground(frame: Frame) {
        val texCoordsIn = quadTexCoords ?: return
        val texCoordsOut = transformedTexCoords ?: return
        val vertices = quadVertices ?: return

        frame.transformCoordinates2d(
            Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
            texCoordsIn,
            Coordinates2d.IMAGE_NORMALIZED,
            texCoordsOut
        )
        texCoordsOut.position(0)
        vertices.position(0)

        GLES20.glUseProgram(glProgram)
        GLES20.glDepthMask(false)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glUniform1i(textureUniform, 0)

        GLES20.glVertexAttribPointer(positionAttrib, 3, GLES20.GL_FLOAT, false, 0, vertices)
        GLES20.glVertexAttribPointer(texCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, texCoordsOut)

        GLES20.glEnableVertexAttribArray(positionAttrib)
        GLES20.glEnableVertexAttribArray(texCoordAttrib)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(positionAttrib)
        GLES20.glDisableVertexAttribArray(texCoordAttrib)
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
            "querySurfaceStatus" -> {
                val data = mapOf(
                    "hasSurface" to hasSurface,
                    "planesCount" to planesCount,
                    "surfaceType" to surfaceType,
                    "trackingState" to trackingStateStr,
                    "statusMessage" to when {
                        !hasSurface -> "Move camera slowly to detect surfaces"
                        activeAnchors.isEmpty() -> "Surface detected • Ready to measure"
                        else -> "Move to second point & tap +"
                    }
                )
                result.success(data)
            }
            "hitTest" -> {
                val normX = (call.argument<Number>("x")?.toFloat() ?: 0.5f)
                val normY = (call.argument<Number>("y")?.toFloat() ?: 0.5f)

                val frame = latestFrame
                if (frame == null || frame.camera.trackingState != TrackingState.TRACKING) {
                    result.error("TRACKING_NOT_READY", "ARCore tracking is not ready", null)
                    return
                }

                val pixelX = normX * viewportWidth
                val pixelY = normY * viewportHeight

                val hitResults = frame.hitTest(pixelX, pixelY)
                var bestHit: HitResult? = null

                // 1. Preference: Hit on tracked plane polygon
                for (hit in hitResults) {
                    val trackable = hit.trackable
                    if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                        bestHit = hit
                        break
                    }
                }

                // 2. Preference: Hit on InstantPlacementPoint or feature point
                if (bestHit == null) {
                    for (hit in hitResults) {
                        val trackable = hit.trackable
                        if (trackable is InstantPlacementPoint ||
                            (trackable is Point && trackable.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL)) {
                            bestHit = hit
                            break
                        }
                    }
                }

                // 3. Fallback: Any hit result
                if (bestHit == null && hitResults.isNotEmpty()) {
                    bestHit = hitResults[0]
                }

                if (bestHit != null) {
                    val anchor = bestHit.createAnchor()
                    val anchorId = UUID.randomUUID().toString()
                    activeAnchors[anchorId] = anchor

                    val pose = anchor.pose
                    val cameraPose = frame.camera.pose
                    val dx = pose.tx() - cameraPose.tx()
                    val dy = pose.ty() - cameraPose.ty()
                    val dz = pose.tz() - cameraPose.tz()
                    val depth = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble())

                    result.success(mapOf(
                        "anchorId" to anchorId,
                        "x" to pose.tx().toDouble(),
                        "y" to pose.ty().toDouble(),
                        "z" to pose.tz().toDouble(),
                        "depth" to depth,
                        "planeType" to if (bestHit.trackable is Plane) "PLANE" else "INSTANT"
                    ))
                } else {
                    result.error("NO_HIT", "No surface hit at this position", null)
                }
            }
            "getAnchorScreenPositions" -> {
                val anchorIds = call.argument<List<String>>("anchorIds") ?: emptyList()
                val frame = latestFrame
                if (frame == null || frame.camera.trackingState != TrackingState.TRACKING) {
                    result.success(emptyMap<String, Any>())
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

                for (id in anchorIds) {
                    val anchor = activeAnchors[id] ?: continue
                    if (anchor.trackingState != TrackingState.TRACKING) continue

                    val pose = anchor.pose
                    worldPosIn[0] = pose.tx()
                    worldPosIn[1] = pose.ty()
                    worldPosIn[2] = pose.tz()
                    worldPosIn[3] = 1.0f

                    Matrix.multiplyMV(clipPosOut, 0, viewProjMatrix, 0, worldPosIn, 0)

                    val w = clipPosOut[3]
                    if (w > 0.05f) {
                        val ndcX = clipPosOut[0] / w
                        val ndcY = clipPosOut[1] / w
                        val screenNormX = (ndcX + 1.0f) * 0.5f
                        val screenNormY = (1.0f - ndcY) * 0.5f

                        resultMap[id] = mapOf(
                            "x" to screenNormX.toDouble(),
                            "y" to screenNormY.toDouble(),
                            "inView" to (screenNormX in -0.1f..1.1f && screenNormY in -0.1f..1.1f),
                            "worldX" to pose.tx().toDouble(),
                            "worldY" to pose.ty().toDouble(),
                            "worldZ" to pose.tz().toDouble()
                        )
                    }
                }
                result.success(resultMap)
            }
            "removeAnchor" -> {
                val anchorId = call.argument<String>("anchorId")
                if (anchorId != null) {
                    val anchor = activeAnchors.remove(anchorId)
                    anchor?.detach()
                }
                result.success(true)
            }
            "clearAllAnchors" -> {
                for (anchor in activeAnchors.values) {
                    anchor.detach()
                }
                activeAnchors.clear()
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
