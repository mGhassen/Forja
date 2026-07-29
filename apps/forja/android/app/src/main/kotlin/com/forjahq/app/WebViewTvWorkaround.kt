package com.forjahq.app

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterView

object WebViewTvWorkaround {
    private const val TAG = "WebViewTvWorkaround"

    fun applyIfNeeded(context: Context) {
        if (!PlatformUtils.isAndroidTv(context)) return
        warmUpSoftwareWebView(context)
    }

    fun warmUpSoftwareWebView(context: Context) {
        try {
            WebView.enableSlowWholeDocumentDraw()
            Log.i(TAG, "TV WebView slow whole-document draw enabled")
        } catch (e: Exception) {
            Log.w(TAG, "enableSlowWholeDocumentDraw failed", e)
        }

        try {
            val webView = WebView(context.applicationContext)
            webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null)
            webView.destroy()
            Log.i(TAG, "Software WebView warm-up completed")
        } catch (e: Exception) {
            Log.w(TAG, "Software WebView warm-up failed", e)
        }
    }

    /**
     * Live Matches Streamed keeps the embed [WebView] under [IptvPtPlayerScreen]
     * (CDN fetches). That platform view steals leanback focus so Flutter Exo
     * chrome never sees D-pad. Mark underlay WebViews / PlayerViews non-focusable
     * and give [FlutterView] focus again.
     */
    fun releaseUnderlayPlatformViewFocus(activity: Activity) {
        if (!PlatformUtils.isAndroidTv(activity)) return
        val decor = activity.window?.decorView ?: return
        var blocked = 0
        fun blockNativeFocus(v: View) {
            v.isFocusable = false
            v.isFocusableInTouchMode = false
            if (v is ViewGroup) {
                v.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
            }
            v.clearFocus()
            blocked++
        }
        fun walk(v: View) {
            when {
                v is WebView -> blockNativeFocus(v)
                v.javaClass.name.contains("PlayerView") -> blockNativeFocus(v)
            }
            if (v is ViewGroup) {
                for (i in 0 until v.childCount) {
                    walk(v.getChildAt(i))
                }
            }
        }
        walk(decor)
        fun findFlutter(v: View): FlutterView? {
            if (v is FlutterView) return v
            if (v is ViewGroup) {
                for (i in 0 until v.childCount) {
                    findFlutter(v.getChildAt(i))?.let { return it }
                }
            }
            return null
        }
        val flutter = findFlutter(decor)
        if (flutter != null) {
            flutter.isFocusable = true
            flutter.isFocusableInTouchMode = true
            flutter.requestFocus()
        }
        Log.i(
            TAG,
            "releaseUnderlayPlatformViewFocus blocked=$blocked flutterFocus=${flutter?.hasFocus()}",
        )
    }
}
