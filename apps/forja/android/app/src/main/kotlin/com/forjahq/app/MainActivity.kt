package com.forjahq.app

import android.graphics.Color
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val exoPlugin = ForjaExoPlayerPlugin()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isAndroidTv()) {
            window.statusBarColor = APP_BACKGROUND
            window.navigationBarColor = APP_BACKGROUND
        }
    }

    // Belt-and-suspenders with ForjaApplication: MediaKit + Impeller =
    // audio-only / black video on leanback.
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        if (isAndroidTv()) {
            args.add(FlutterShellArgs.ARG_DISABLE_IMPELLER)
        }
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        exoPlugin.bindEngine(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.platformViewsController.registry,
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "forja/platform",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> result.success(isAndroidTv())
                "isAndroidEmulator" -> result.success(PlatformUtils.isLikelyEmulator())
                "getPlaybackCapabilities" -> result.success(PlaybackCapabilities.probe())
                "prepareWebViewForTv" -> {
                    WebViewTvWorkaround.warmUpSoftwareWebView(applicationContext)
                    result.success(null)
                }
                "exitAppCompletely" -> {
                    // Double Back on nav / remote Exit — leave leanback and
                    // free process memory so the next open is a cold start.
                    finishAndRemoveTask()
                    android.os.Process.killProcess(android.os.Process.myPid())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAndroidTv(): Boolean = PlatformUtils.isAndroidTv(this)

    companion object {
        private val APP_BACKGROUND = Color.parseColor("#141414")
    }
}
