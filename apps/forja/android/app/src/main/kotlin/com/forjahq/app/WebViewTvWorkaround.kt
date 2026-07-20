package com.forjahq.app

import android.content.Context
import android.util.Log
import android.view.View
import android.webkit.WebView

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
}
