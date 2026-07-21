package com.forjahq.app

import android.app.Application
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterShellArgs

class ForjaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // media_kit SurfaceProducer + Impeller = audio-only / black video on ATV
        // (Shield + leanback emulators). Init Skia before AudioService creates the engine.
        if (PlatformUtils.isAndroidTv(this)) {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(this)
                loader.ensureInitializationComplete(
                    this,
                    arrayOf(FlutterShellArgs.ARG_DISABLE_IMPELLER),
                )
                Log.i(TAG, "Impeller disabled for Android TV (MediaKit video surface)")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to disable Impeller on Android TV", e)
            }
        }
        WebViewTvWorkaround.applyIfNeeded(this)
    }

    companion object {
        private const val TAG = "ForjaApplication"
    }
}
