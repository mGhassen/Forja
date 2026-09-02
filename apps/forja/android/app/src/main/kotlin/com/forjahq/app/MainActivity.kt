package com.forjahq.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val exoPlugin = ForjaExoPlayerPlugin()
    private var screenOffReceiver: BroadcastReceiver? = null
    private var exiting = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isAndroidTv()) {
            window.statusBarColor = APP_BACKGROUND
            window.navigationBarColor = APP_BACKGROUND
            registerTvStandbyExit()
        }
    }

    override fun onDestroy() {
        unregisterTvStandbyExit()
        super.onDestroy()
    }

    // Power is often eaten before Flutter; catch it here if the box delivers it.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isAndroidTv() &&
            event.action == KeyEvent.ACTION_DOWN &&
            isPowerKey(event.keyCode)
        ) {
            exitCompletely()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    // Belt-and-suspenders with ForjaApplication: Impeller OpenGLES on leanback
    // (Skia glyph atlas corruption; MediaKit stays on mediacodec_embed).
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        if (isAndroidTv()) {
            for (arg in TvFlutterShellArgs.forLeanback()) {
                args.add(arg)
            }
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
                "releaseUnderlayPlatformViewFocus" -> {
                    WebViewTvWorkaround.releaseUnderlayPlatformViewFocus(this)
                    result.success(null)
                }
                "exitAppCompletely" -> {
                    // Double Back on nav / remote Exit / TV power — leave
                    // leanback and free process memory so the next open is cold.
                    exitCompletely()
                    result.success(null)
                }
                // MediaKit IPTV (issue 150): same window mode switch Exo uses
                // for 50/25 fps on a 60 Hz panel. Exo calls ForjaDisplayFrameRate
                // from its plugin; MediaKit has no native host — go through here.
                "applyDisplayFrameRate" -> {
                    val fps = call.argument<Number>("fps")?.toFloat()
                    if (fps == null || fps <= 0f) {
                        result.error("bad_args", "fps required", null)
                    } else {
                        ForjaDisplayFrameRate.apply(this, fps)
                        result.success(null)
                    }
                }
                "clearDisplayFrameRate" -> {
                    ForjaDisplayFrameRate.clear(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerTvStandbyExit() {
        if (screenOffReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (action == Intent.ACTION_SCREEN_OFF ||
                    action == Intent.ACTION_SHUTDOWN
                ) {
                    exitCompletely()
                }
            }
        }
        screenOffReceiver = receiver
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SHUTDOWN)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    private fun unregisterTvStandbyExit() {
        val receiver = screenOffReceiver ?: return
        screenOffReceiver = null
        try {
            unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }
    }

    private fun isPowerKey(keyCode: Int): Boolean =
        keyCode == KeyEvent.KEYCODE_POWER ||
            keyCode == KeyEvent.KEYCODE_SLEEP ||
            keyCode == KeyEvent.KEYCODE_STB_POWER ||
            keyCode == KeyEvent.KEYCODE_TV_POWER

    private fun exitCompletely() {
        if (exiting) return
        exiting = true
        finishAndRemoveTask()
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    private fun isAndroidTv(): Boolean = PlatformUtils.isAndroidTv(this)

    companion object {
        private val APP_BACKGROUND = Color.parseColor("#141414")
    }
}
