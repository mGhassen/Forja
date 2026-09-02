package com.forjahq.app

import android.app.Application
import android.util.Log
import io.flutter.FlutterInjector

class ForjaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Init Impeller OpenGLES before AudioService creates the engine.
        // Do not force EnableImpeller in the manifest — phones keep the API 29+
        // default (Vulkan when available); TV-only args live here + MainActivity.
        if (PlatformUtils.isAndroidTv(this)) {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(this)
                loader.ensureInitializationComplete(
                    this,
                    TvFlutterShellArgs.forLeanback(),
                )
                Log.i(TAG, "Impeller OpenGLES enabled for Android TV (glyph atlas + MediaKit embed)")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to set Impeller OpenGLES on Android TV", e)
            }
        }
        WebViewTvWorkaround.applyIfNeeded(this)
    }

    companion object {
        private const val TAG = "ForjaApplication"
    }
}
