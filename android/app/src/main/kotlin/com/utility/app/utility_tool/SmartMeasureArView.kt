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
import android.util.Log
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
        private const val MAX_OVERLAY_POINTS = 4096
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
        // Surface fitted from depth hits when ARCore has no plane (plain tables). Tune on-device.
        private const val FIT_WINDOW = 600            // depth samples kept (~10-20 s): single estimates of a
                                                      // plain table's height wander by +-5 cm, their long-run
                                                      // median is far steadier, so repeat measurements agree
        private const val FIT_RECENT = 30             // newest samples, used to notice a change of surface
        private const val FIT_NEW_SURFACE_M = 0.15f   // recent median this far from the fit = new surface, restart
        private const val FIT_MIN_SAMPLES = 120       // samples needed before the fit is trusted (~4-5 s of
                                                      // scanning; early fits measured ~10% off)
        private const val FIT_MAX_SPREAD_M = 0.07f    // samples must agree this well (median abs. deviation)
        private const val PLANE_BEHIND_RATIO = 1.3f   // plane hit this much farther than the depth hit ...
        private const val PLANE_BEHIND_M = 0.05f      // ... plus this = plane is behind the real surface
        private const val PLANE_BELOW_FIT_M = 0.10f   // plane this far below the fitted surface = behind it
        private const val FIT_SNAP_M = 0.12f          // depth hits within this of the fit lie on that surface
        private const val LOCK_SNAP_M = 0.15f         // same, for the surface locked by the first point
        private const val RAY_MIN_DOWN = 0.2f         // only fit when aiming at least ~12 degrees below the horizon

        private const val TAG = "SmartMeasure"        // adb logcat -s SmartMeasure (one line per tap/measurement)

        private const val OVERLAY_VS = """
            attribute vec2 a_Pos;
            uniform float u_Size;
            void main() { gl_Position = vec4(a_Pos, 0.0, 1.0); gl_PointSize = u_Size; }
        """
        private const val OVERLAY_FS = """
            precision mediump float;
            uniform vec4 u_Color;
            void main() {
                vec2 c = gl_PointCoord - vec2(0.5);
                if (dot(c, c) > 0.25) discard;   // round point
                gl_FragColor = u_Color;
            }
        """
    }

    // --- Same-frame overlay (points + lines drawn with the camera image: no lag behind the video) ---
    private var overlayProgram = 0
    private var overlayPosAttrib = 0
    private var overlaySizeUniform = 0
    private var overlayColorUniform = 0
    private var overlayBuffer: FloatBuffer = ByteBuffer.allocateDirect(MAX_OVERLAY_POINTS * 2 * FLOAT_SIZE)
        .order(ByteOrder.nativeOrder()).asFloatBuffer()
    private val density = context.resources.displayMetrics.density
    @Volatile private var overlaySegments: List<Pair<String, String>> = emptyList()
    @Volatile private var overlayActiveStart: String? = null
    private val viewProj = FloatArray(16)

    // Diagnostics (GL thread)
    private var lastFrame: Frame? = null
    private var reticleType = "NONE"
    private var lastStatusLogMs = 0L
    private var fitMedian = 0f
    private var fitSpread = 0f
    private var lastPlaneDist = -1f
    private var lastDepthDist = -1f

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
    private var reticleSurface: Any? = null // Plane instance, "FITTED" or "DEPTH"
    private val depthYs = FloatArray(FIT_WINDOW)
    private var depthYCount = 0
    private var depthYNext = 0
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
        overlayProgram = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, compileShader(GLES20.GL_VERTEX_SHADER, OVERLAY_VS))
            GLES20.glAttachShader(it, compileShader(GLES20.GL_FRAGMENT_SHADER, OVERLAY_FS))
            GLES20.glLinkProgram(it)
        }
        overlayPosAttrib = GLES20.glGetAttribLocation(overlayProgram, "a_Pos")
        overlaySizeUniform = GLES20.glGetUniformLocation(overlayProgram, "u_Size")
        overlayColorUniform = GLES20.glGetUniformLocation(overlayProgram, "u_Color")

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
            if (tracking) {
                val proj = FloatArray(16)
                val view = FloatArray(16)
                frame.camera.getProjectionMatrix(proj, 0, 0.05f, 50.0f)
                frame.camera.getViewMatrix(view, 0)
                Matrix.multiplyMM(viewProj, 0, proj, 0, view, 0)
                updateReticle(frame)
                drawOverlay() // same frame as the camera image
            } else {
                resetReticle()
            }
            publishStatus(frame, arSession, tracking)
            publishAnchors(tracking)
        } catch (e: Exception) {
            // Ignore camera frame drop exceptions during resume/pause
        }
    }

    private fun resetReticle() {
        reticleSurface = null
        depthYCount = 0
        depthYNext = 0
        reticleSmoothed = null
        reticlePublished = null
    }

    /** ARCore's own confidence (0-255) for the depth pixel under the screen centre; 0 if unavailable. */
    private fun centreDepthConfidence(frame: Frame): Int {
        return try {
            frame.acquireRawDepthConfidenceImage().use { img ->
                // Depth images share the camera texture's orientation: map screen centre -> texture UV.
                val uv = FloatArray(2)
                frame.transformCoordinates2d(
                    Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, floatArrayOf(0f, 0f),
                    Coordinates2d.TEXTURE_NORMALIZED, uv
                )
                val x = (uv[0] * img.width).toInt().coerceIn(0, img.width - 1)
                val y = (uv[1] * img.height).toInt().coerceIn(0, img.height - 1)
                val plane = img.planes[0]
                plane.buffer.get(y * plane.rowStride + x * plane.pixelStride).toInt() and 0xFF
            }
        } catch (e: Exception) {
            0 // not yet available / unsupported: treat as not confident
        }
    }

    private fun dist(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]; val dy = a[1] - b[1]; val dz = a[2] - b[2]
        return Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }

    /** Height (world Y) of the horizontal surface under the reticle, fitted from recent depth hits:
     *  the median of the last samples, valid only once they agree. Single depth-from-motion hits
     *  are centimetres noisy; the median of a few dozen is steady. */
    private fun fittedSurfaceY(): Float? {
        if (depthYCount < FIT_MIN_SAMPLES) return null
        val ys = depthYs.copyOf(depthYCount).also { it.sort() }
        val median = ys[ys.size / 2]
        val dev = FloatArray(ys.size) { Math.abs(ys[it] - median) }.also { it.sort() }
        fitMedian = median
        fitSpread = dev[dev.size / 2] // median absolute deviation
        return if (fitSpread <= FIT_MAX_SPREAD_M) median else null
    }

    /** Centre hit-test. Priority: (1) inside a detected plane, (2) on the horizontal surface fitted
     *  from depth, (3) raw depth for objects off that surface. Raw feature points, estimated planes
     *  and instant placement are ignored. */
    private fun updateReticle(frame: Frame) {
        val hits = frame.hitTest(viewportWidth * 0.5f, viewportHeight * 0.5f)
        lastFrame = frame

        val planeHit = hits.firstOrNull { h ->
            val t = h.trackable
            t is Plane && t.trackingState == TrackingState.TRACKING && t.subsumedBy == null &&
                t.isPoseInPolygon(h.hitPose)
        }
        val depthHit = hits.firstOrNull { h ->
            val t = h.trackable
            t is DepthPoint && t.trackingState == TrackingState.TRACKING
        }

        // Feed the surface fit with every depth hit (ring buffer of recent heights).
        if (depthHit != null) {
            depthYs[depthYNext] = depthHit.hitPose.ty()
            depthYNext = (depthYNext + 1) % depthYs.size
            if (depthYCount < depthYs.size) depthYCount++
        }
        var fitY = fittedSurfaceY()
        // Aimed at a different surface (table -> floor)? Restart the fit from the newest samples.
        // (Only once a fit exists: before that fitMedian is unset and everything would look "new".)
        if (depthYCount >= FIT_MIN_SAMPLES) {
            val recent = FloatArray(FIT_RECENT) { depthYs[(depthYNext - 1 - it + depthYs.size * 2) % depthYs.size] }
            recent.sort()
            if (Math.abs(recent[FIT_RECENT / 2] - fitMedian) > FIT_NEW_SURFACE_M) {
                for (i in 0 until FIT_RECENT) depthYs[i] = recent[i]
                depthYCount = FIT_RECENT
                depthYNext = FIT_RECENT
                fitY = fittedSurfaceY()
            }
        }
        lastPlaneDist = planeHit?.distance ?: -1f
        lastDepthDist = depthHit?.distance ?: -1f

        // A detected plane can lie BEHIND the surface the user is aiming at: ARCore maps the floor,
        // its outline extends under an undetected plain table, and the ray goes "through" the table.
        // Depth sees the real, nearer surface, so a plane clearly beyond it is the wrong one.
        val planeBehind = planeHit != null && (
            (depthHit != null && planeHit.distance > depthHit.distance * PLANE_BEHIND_RATIO + PLANE_BEHIND_M) ||
            (fitY != null && planeHit.hitPose.ty() < fitY - PLANE_BELOW_FIT_M))

        var raw: FloatArray? = null
        var surface: Any? = null
        var type = "NONE"
        if (planeHit != null && !planeBehind) {
            raw = planeHit.hitPose.translation
            surface = planeHit.trackable
            type = "PLANE"
            reticleRotation = planeHit.hitPose.rotationQuaternion
        } else if (depthHit != null) {
            val p = depthHit.hitPose.translation
            val cam = frame.camera.pose.translation
            val len = dist(p, cam)
            val dy = if (len > 1e-4f) (p[1] - cam[1]) / len else 0f
            // While a measurement is in progress, keep the second point on the SAME horizontal surface
            // as the first: the fitted height drifts by centimetres between taps on plain tables, and
            // two points at different heights on one table is pure error.
            val lockY = overlayActiveStart?.let { activeAnchors[it]?.pose?.ty() }
            val surfY = lockY ?: fitY
            val snap = if (lockY != null) LOCK_SNAP_M else FIT_SNAP_M
            if (surfY != null && dy < -RAY_MIN_DOWN && Math.abs(p[1] - surfY) < snap) {
                // Same ray through the screen centre, intersected with that surface.
                val t = (surfY - cam[1]) / (p[1] - cam[1])
                raw = floatArrayOf(cam[0] + (p[0] - cam[0]) * t, surfY, cam[2] + (p[2] - cam[2]) * t)
                surface = "FITTED"
                type = "FITTED"
            }
            // Otherwise no reticle: either still collecting samples, or the hit is far off the fitted
            // surface. A single depth-from-motion reading is +-10 cm on this class of phone (measured:
            // one such pair gave 265 mm for a 147 mm object), so it never places a point on its own.
            reticleRotation = depthHit.hitPose.rotationQuaternion
        }
        reticleType = type

        if (raw == null) {
            reticleSurface = null
            reticleSmoothed = null
            reticlePublished = null
            return
        }

        val smoothed = reticleSmoothed
        val published = reticlePublished
        if (smoothed == null || published == null || surface != reticleSurface || dist(smoothed, raw) > RETICLE_JUMP_M) {
            reticleSmoothed = raw.copyOf()
            reticlePublished = raw.copyOf()
        } else {
            for (i in 0..2) smoothed[i] += RETICLE_EMA_ALPHA * (raw[i] - smoothed[i])
            if (dist(published, smoothed) > RETICLE_DEADBAND_M) reticlePublished = smoothed.copyOf()
        }
        reticleSurface = surface
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
        if (reticleType == "FITTED" || reticleType == "DEPTH") type = reticleType

        val reticle = reticlePublished
        val onSurface = tracking && reticle != null
        val message = when {
            !tracking -> when (frame.camera.trackingFailureReason) {
                TrackingFailureReason.INSUFFICIENT_LIGHT -> "Tracking limited • More light needed"
                TrackingFailureReason.INSUFFICIENT_FEATURES -> "Point at a textured surface"
                TrackingFailureReason.EXCESSIVE_MOTION -> "Move your phone slowly"
                else -> "Tracking limited • Move your phone slowly"
            }
            !onSurface && depthYCount in 1 until FIT_MIN_SAMPLES -> "Keep moving slowly • scanning surface"
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
                reticleType == "DEPTH" -> "Low confidence • scan the table edges slowly"
                else -> ""
            }
        } else ""
        // Diagnostics, once a second: enough to see why the + button is or isn't available.
        val now = System.currentTimeMillis()
        if (now - lastStatusLogMs >= 1000) {
            lastStatusLogMs = now
            Log.i(TAG, "STATUS tracking=${frame.camera.trackingState} reason=${frame.camera.trackingFailureReason} " +
                "planes=$count hit=${if (tracking) reticleType else "NONE"} canPlace=$onSurface " +
                "depthConf=${if (tracking) centreDepthConfidence(frame) else -1} depthSamples=$depthYCount " +
                "fitY=${fittedSurfaceY()} fitMedian=%.3f fitSpread=%.3f planeDist=%.2f depthDist=%.2f ".format(
                    fitMedian, fitSpread, lastPlaneDist, lastDepthDist) + "anchors=${activeAnchors.size} msg=\"$message\"")
        }
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
    private fun publishAnchors(tracking: Boolean) {
        if (!tracking) {
            anchorSnapshot = emptyMap() // Dart hides points rather than leaving them at stale screen positions
            return
        }
        val resultMap = mutableMapOf<String, Any>()

        for ((id, anchor) in activeAnchors) {
            if (anchor.trackingState != TrackingState.TRACKING) continue
            val pose = anchor.pose
            val ndc = projectToNdc(pose.tx(), pose.ty(), pose.tz())
            resultMap[id] = mapOf(
                "x" to if (ndc != null) ((ndc[0] + 1.0f) * 0.5f).toDouble() else -1.0,
                "y" to if (ndc != null) ((1.0f - ndc[1]) * 0.5f).toDouble() else -1.0,
                "inView" to (ndc != null), // behind the camera = hide; off-screen in front still draws to the edge
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

    // --- Diagnostics: one line per tap / finished measurement (not per frame). adb logcat -s SmartMeasure ---

    private fun logPlacement(anchorId: String, pose: Pose) {
        val frame = lastFrame ?: return
        try {
            val cam = frame.camera
            val c = cam.pose
            val intr = cam.imageIntrinsics
            val f = intr.focalLength
            val pp = intr.principalPoint
            val range = dist(pose.translation, c.translation)
            Log.i(TAG, "POINT id=${anchorId.take(8)} ts=${frame.timestamp} tracking=${cam.trackingState} " +
                "reason=${cam.trackingFailureReason} hit=$reticleType " +
                "world=(%.4f, %.4f, %.4f) cam=(%.4f, %.4f, %.4f) range=%.3fm ".format(
                    pose.tx(), pose.ty(), pose.tz(), c.tx(), c.ty(), c.tz(), range) +
                "focal=(%.1f, %.1f) pp=(%.1f, %.1f) depth=%s".format(
                    f[0], f[1], pp[0], pp[1], session?.config?.depthMode))
        } catch (e: Exception) {
            Log.w(TAG, "POINT log failed: ${e.message}")
        }
    }

    private fun logSegment(a: String, b: String) {
        val pa = activeAnchors[a]?.pose ?: return
        val pb = activeAnchors[b]?.pose ?: return
        val d = dist(pa.translation, pb.translation)
        Log.i(TAG, "MEASURE ${a.take(8)}->${b.take(8)} distance=%.4fm (%.1f mm) start=(%.4f, %.4f, %.4f) end=(%.4f, %.4f, %.4f)".format(
            d, d * 1000f, pa.tx(), pa.ty(), pa.tz(), pb.tx(), pb.ty(), pb.tz()))
    }

    /** World point -> normalised device coords with this frame's camera, or null if behind the camera. */
    private fun projectToNdc(x: Float, y: Float, z: Float): FloatArray? {
        val clip = FloatArray(4)
        Matrix.multiplyMV(clip, 0, viewProj, 0, floatArrayOf(x, y, z, 1f), 0)
        val w = clip[3]
        if (w <= 0.05f) return null
        return floatArrayOf(clip[0] / w, clip[1] / w)
    }

    private fun anchorNdc(id: String?): FloatArray? {
        val a = id?.let { activeAnchors[it] } ?: return null
        if (a.trackingState != TrackingState.TRACKING) return null
        val p = a.pose
        return projectToNdc(p.tx(), p.ty(), p.tz())
    }

    /** Draws finished lines (solid), the live line to the reticle (dotted) and endpoint dots,
     *  using the SAME camera frame as the video so nothing lags or swims. Labels stay in Flutter. */
    private fun drawOverlay() {
        if (overlayProgram == 0) return
        val segments = overlaySegments
        val activeStart = overlayActiveStart
        if (segments.isEmpty() && activeStart == null) return

        val pxToNdcX = 2f / viewportWidth
        val pxToNdcY = 2f / viewportHeight
        val solid = ArrayList<FloatArray>()   // pairs of NDC endpoints
        val ends = ArrayList<FloatArray>()
        for ((a, b) in segments) {
            val pa = anchorNdc(a) ?: continue
            val pb = anchorNdc(b) ?: continue
            solid.add(floatArrayOf(pa[0], pa[1], pb[0], pb[1]))
            ends.add(pa); ends.add(pb)
        }
        var live: FloatArray? = null
        anchorNdc(activeStart)?.let { ps ->
            ends.add(ps)
            if (reticlePublished != null) live = floatArrayOf(ps[0], ps[1], 0f, 0f) // reticle = screen centre
        }

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glUseProgram(overlayProgram)

        // Points along a segment, spacing in device pixels, ends included.
        fun pointsAlong(lines: List<FloatArray>, spacingPx: Float): Int {
            overlayBuffer.clear()
            var count = 0
            for (l in lines) {
                val dxPx = (l[2] - l[0]) / pxToNdcX
                val dyPx = (l[3] - l[1]) / pxToNdcY
                val len = Math.sqrt((dxPx * dxPx + dyPx * dyPx).toDouble()).toFloat()
                val n = Math.max(1, Math.min((len / spacingPx).toInt(), MAX_OVERLAY_POINTS / 2))
                for (i in 0..n) {
                    if (count >= MAX_OVERLAY_POINTS) break
                    val t = i.toFloat() / n
                    overlayBuffer.put(l[0] + (l[2] - l[0]) * t).put(l[1] + (l[3] - l[1]) * t)
                    count++
                }
            }
            return count
        }
        fun draw(count: Int, sizeDp: Float, r: Float, g: Float, b: Float, a: Float) {
            if (count == 0) return
            overlayBuffer.position(0)
            GLES20.glVertexAttribPointer(overlayPosAttrib, 2, GLES20.GL_FLOAT, false, 0, overlayBuffer)
            GLES20.glEnableVertexAttribArray(overlayPosAttrib)
            GLES20.glUniform1f(overlaySizeUniform, sizeDp * density)
            GLES20.glUniform4f(overlayColorUniform, r, g, b, a)
            GLES20.glDrawArrays(GLES20.GL_POINTS, 0, count)
            GLES20.glDisableVertexAttribArray(overlayPosAttrib)
        }

        // Finished measurements: solid white line (densely packed round points) with a dark halo.
        var n = pointsAlong(solid, 1f * density)
        draw(n, 5f, 0f, 0f, 0f, 0.35f); draw(n, 3f, 1f, 1f, 1f, 1f)
        // Live preview: evenly spaced dots.
        live?.let {
            n = pointsAlong(listOf(it), 9f * density)
            draw(n, 6.4f, 0f, 0f, 0f, 0.35f); draw(n, 4.6f, 1f, 1f, 1f, 1f)
        }
        // Endpoints.
        overlayBuffer.clear()
        ends.forEach { overlayBuffer.put(it[0]).put(it[1]) }
        draw(ends.size, 12f, 0f, 0f, 0f, 0.35f); draw(ends.size, 9.6f, 1f, 1f, 1f, 1f)

        GLES20.glDisable(GLES20.GL_BLEND)
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
                    val position = reticlePublished
                    val hitType = reticleType
                    // World anchor at the stabilised hit position (not attached to the plane): plane-attached
                    // anchors follow every refinement of the plane estimate, so points crept on plain tables.
                    val anchor = try {
                        if (position != null) session?.createAnchor(Pose(position, reticleRotation)) else null
                    } catch (e: Exception) { null }

                    if (anchor == null) {
                        mainHandler.post { result.error("NO_HIT", "No tracked surface under the reticle", null) }
                        return@queueEvent
                    }
                    val anchorId = UUID.randomUUID().toString()
                    activeAnchors[anchorId] = anchor
                    val pose = anchor.pose
                    logPlacement(anchorId, pose)
                    mainHandler.post {
                        result.success(mapOf(
                            "anchorId" to anchorId,
                            "x" to pose.tx().toDouble(),
                            "y" to pose.ty().toDouble(),
                            "z" to pose.tz().toDouble(),
                            "planeType" to hitType
                        ))
                    }
                }
            }
            "getAnchorScreenPositions" -> result.success(anchorSnapshot)
            "setOverlay" -> {
                // What to draw natively: finished segments as [startId, endId] and the pending first point.
                val segs = call.argument<List<List<String>>>("segments").orEmpty()
                    .filter { it.size == 2 }.map { it[0] to it[1] }
                val added = segs.filter { it !in overlaySegments }
                overlaySegments = segs
                overlayActiveStart = call.argument<String>("activeStart")
                if (added.isNotEmpty()) glSurfaceView.queueEvent { added.forEach { logSegment(it.first, it.second) } }
                result.success(true)
            }
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
