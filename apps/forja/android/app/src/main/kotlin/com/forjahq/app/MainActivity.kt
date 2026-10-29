package com.forjahq.app

import android.graphics.Color
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val exoPlugin = ForjaExoPlayerPlugin()
    private var exiting = false
    private var wifiMulticastLock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isAndroidTv()) {
            window.statusBarColor = APP_BACKGROUND
            window.navigationBarColor = APP_BACKGROUND
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        exoPlugin.bindEngine(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.platformViewsController.registry,
            flutterEngine.renderer,
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
                    // Double Back on nav / remote Exit — leave leanback and
                    // free process memory so the next open is cold.
                    // Do not call this on power / SCREEN_OFF (Xiaomi bounce).
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
                // Leanback UI ticks for D-pad focus / OK (issue 293).
                "playSoundEffect" -> {
                    playTvSoundEffect(call.argument<String>("kind"))
                    result.success(null)
                }
                // LAN mDNS browse (Settings → LAN Discover) — Wi‑Fi drops
                // multicast without an held MulticastLock (issue 481).
                "acquireWifiMulticastLock" -> {
                    acquireWifiMulticastLock()
                    result.success(null)
                }
                "releaseWifiMulticastLock" -> {
                    releaseWifiMulticastLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun acquireWifiMulticastLock() {
        val lock = wifiMulticastLock ?: run {
            val wifi = applicationContext.getSystemService(WIFI_SERVICE) as? WifiManager
                ?: return
            wifi.createMulticastLock("forja-mdns").also {
                it.setReferenceCounted(true)
                wifiMulticastLock = it
            }
        }
        lock.acquire()
    }

    private fun releaseWifiMulticastLock() {
        val lock = wifiMulticastLock ?: return
        if (!lock.isHeld) return
        try {
            lock.release()
        } catch (_: RuntimeException) {
            // Extra release vs acquire — ignore.
        }
    }

    private fun playTvSoundEffect(kind: String?) {
        val am = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        val effect = when (kind) {
            "up" -> AudioManager.FX_FOCUS_NAVIGATION_UP
            "down" -> AudioManager.FX_FOCUS_NAVIGATION_DOWN
            "left" -> AudioManager.FX_FOCUS_NAVIGATION_LEFT
            "right" -> AudioManager.FX_FOCUS_NAVIGATION_RIGHT
            "activate" -> AudioManager.FX_KEY_CLICK
            else -> AudioManager.FX_KEY_CLICK
        }
        am.playSoundEffect(effect)
    }

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
