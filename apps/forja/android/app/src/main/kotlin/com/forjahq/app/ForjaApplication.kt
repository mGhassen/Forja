package com.forjahq.app

import android.app.Application
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.renderer.FlutterRenderer

class ForjaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Impeller off globally via AndroidManifest (ipdigi). TV-only:
        // SurfaceTexture producers — ImageReader → MediaKit audio-only black
        // on Amlogic leanback (issue 114).
        if (PlatformUtils.isAndroidTv(this)) {
            try {
                FlutterRenderer.debugForceSurfaceProducerGlTextures = true
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(this)
                loader.ensureInitializationComplete(this, null)
                Log.i(
                    TAG,
                    "Android TV: SurfaceTexture producers " +
                        "(MediaKit mediacodec_embed; Impeller off in manifest)",
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed TV SurfaceTexture / Flutter init", e)
            }
        }
        // WebView warm-up is deferred to first ForjaInAppWebView /
        // ForjaHeadlessInAppWebView use (TvWebViewWarm → prepareWebViewForTv).
    }

    companion object {
        private const val TAG = "ForjaApplication"
    }
}
