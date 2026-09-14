package com.forjahq.app

import android.app.Application
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.renderer.FlutterRenderer

class ForjaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // ipdigi: Impeller off (Skia) so media_kit video paints. TV-only shell
        // args + SurfaceTexture producers (phones keep Flutter default Impeller).
        if (PlatformUtils.isAndroidTv(this)) {
            try {
                // API 29+ ImageReader SurfaceProducers → MediaKit audio-only black
                // on Amlogic leanback; SurfaceTexture paints under Skia (issue 114).
                FlutterRenderer.debugForceSurfaceProducerGlTextures = true
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(this)
                loader.ensureInitializationComplete(
                    this,
                    TvFlutterShellArgs.forLeanback(),
                )
                Log.i(
                    TAG,
                    "Android TV: Impeller off (Skia) + SurfaceTexture producers " +
                        "(MediaKit mediacodec_embed, ipdigi parity)",
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to set Impeller-off on Android TV", e)
            }
        }
        // WebView warm-up is deferred to first ForjaInAppWebView /
        // ForjaHeadlessInAppWebView use (TvWebViewWarm → prepareWebViewForTv).
    }

    companion object {
        private const val TAG = "ForjaApplication"
    }
}
