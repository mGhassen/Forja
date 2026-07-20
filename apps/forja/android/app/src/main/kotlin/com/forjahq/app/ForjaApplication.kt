package com.forjahq.app

import android.app.Application
import android.content.Context
import android.util.Log
import android.webkit.WebView

class ForjaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        WebViewTvWorkaround.applyIfNeeded(this)
    }
}
