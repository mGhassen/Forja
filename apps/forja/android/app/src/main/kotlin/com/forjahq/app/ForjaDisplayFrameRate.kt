package com.forjahq.app

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.Display
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Window-level display frame-rate matching for Android TV (issues 151 / 150).
 *
 * Exo TextureView and MediaKit `mediacodec_embed` both paint into Flutter —
 * neither reaches a window-layer Surface, so Media3's `Surface.setFrameRate`
 * hint cannot trigger match-content-frame-rate. Requesting a [Display.Mode]
 * on the activity window does reach the compositor, so 24 fps film and
 * 50/25 fps live channels stop juddering on a fixed 60 Hz output.
 */
object ForjaDisplayFrameRate {
    private const val TAG = "ForjaDisplay"

    /** How far a refresh/fps ratio may sit from a whole number and still be judder-free. */
    private const val CADENCE_TOLERANCE = 0.05f

    private var applied = false

    /**
     * Switches to the best display mode for [contentFps] at the current
     * resolution. No-op when the current refresh rate already divides cleanly,
     * so 30 and 60 fps content never pays for an HDMI re-sync.
     */
    fun apply(activity: Activity, contentFps: Float) {
        if (contentFps <= 0f || contentFps > 130f) return
        val display = displayOf(activity) ?: return
        val current = display.mode ?: return
        if (isCleanCadence(current.refreshRate, contentFps)) return

        val best = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight &&
                    isCleanCadence(it.refreshRate, contentFps)
            }
            // Highest clean refresh: same cadence for the video, smoother chrome.
            .maxByOrNull { it.refreshRate }

        if (best == null) {
            Log.i(TAG, "no clean display mode for ${contentFps}fps @ ${current.refreshRate}Hz")
            return
        }

        activity.runOnUiThread {
            activity.window.attributes = activity.window.attributes.apply {
                preferredDisplayModeId = best.modeId
            }
            applied = true
            Log.i(TAG, "display ${current.refreshRate}Hz → ${best.refreshRate}Hz for ${contentFps}fps")
        }
    }

    /** Hands the display back to the system preference. */
    fun clear(activity: Activity) {
        if (!applied) return
        applied = false
        activity.runOnUiThread {
            activity.window.attributes = activity.window.attributes.apply {
                preferredDisplayModeId = 0
            }
        }
    }

    private fun displayOf(activity: Activity): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay
        }

    private fun isCleanCadence(refreshRate: Float, contentFps: Float): Boolean {
        val ratio = refreshRate / contentFps
        if (ratio < 0.99f) return false
        return abs(ratio - ratio.roundToInt()) <= CADENCE_TOLERANCE
    }
}
