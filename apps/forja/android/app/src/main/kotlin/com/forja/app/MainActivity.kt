package com.forja.app

import android.graphics.Color
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isAndroidTv()) {
            window.statusBarColor = APP_BACKGROUND
            window.navigationBarColor = APP_BACKGROUND
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "forja/platform",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> result.success(isAndroidTv())
                "prepareWebViewForTv" -> {
                    WebViewTvWorkaround.warmUpSoftwareWebView(applicationContext)
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
