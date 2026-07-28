package com.forjahq.app

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build

object PlatformUtils {
    fun isAndroidTv(context: Context): Boolean {
        val uiMode = context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        if (uiMode == Configuration.UI_MODE_TYPE_TELEVISION) return true
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }

    /**
     * Leanback / phone emulators (goldfish / ranchu). SurfaceView + MediaCodec
     * often fails setOutputSurface (BAD_INDEX) → audio-only black frame, and the
     * separate Surface can cover Flutter player chrome. Real devices keep
     * SurfaceView for ATV Exo FPS (issue 108).
     */
    fun isLikelyEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT
        val model = Build.MODEL
        val product = Build.PRODUCT
        val hardware = Build.HARDWARE
        val manufacturer = Build.MANUFACTURER
        return fingerprint.startsWith("generic") ||
            fingerprint.contains("emulator", ignoreCase = true) ||
            fingerprint.contains("unknown", ignoreCase = true) ||
            model.contains("Emulator", ignoreCase = true) ||
            model.contains("Android SDK", ignoreCase = true) ||
            model.contains("sdk_google", ignoreCase = true) ||
            manufacturer.contains("Genymotion", ignoreCase = true) ||
            hardware.contains("goldfish", ignoreCase = true) ||
            hardware.contains("ranchu", ignoreCase = true) ||
            product.contains("sdk", ignoreCase = true) ||
            product.contains("emulator", ignoreCase = true) ||
            product.contains("google_sdk", ignoreCase = true) ||
            product.contains("vbox", ignoreCase = true)
    }
}
