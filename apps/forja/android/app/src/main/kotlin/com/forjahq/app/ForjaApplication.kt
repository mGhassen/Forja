package com.forjahq.app

import android.app.Application
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.renderer.FlutterRenderer

class ForjaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Init Impeller OpenGLES before AudioService creates the engine.
        // Do not force EnableImpeller in the manifest — phones keep the API 29+
        // default (Vulkan when available); TV-only args live here + MainActivity.
        if (PlatformUtils.isAndroidTv(this)) {
            try {
                // API 29+ defaults createSurfaceProducer() to ImageReader. On Amlogic
                // leanback (Xiaomi Box Android 11+) that yields MediaKit audio-only
                // black. SurfaceTexture works with Impeller OpenGLES (issue 114).
                // Do not set on phones — undefined with Impeller Vulkan.
                FlutterRenderer.debugForceSurfaceProducerGlTextures = true
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(this)
                loader.ensureInitializationComplete(
                    this,
                    TvFlutterShellArgs.forLeanback(),
                )
                Log.i(
                    TAG,
                    "Android TV: Impeller OpenGLES + SurfaceTexture producers " +
                        "(MediaKit mediacodec_embed)",
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to set Impeller OpenGLES on Android TV", e)
            }
        }
        // WebView warm-up is deferred to first ForjaInAppWebView /
        // ForjaHeadlessInAppWebView use (TvWebViewWarm → prepareWebViewForTv).
    }

    companion object {
        private const val TAG = "ForjaApplication"
    }
}
