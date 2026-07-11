package com.forja.app

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

object PlatformUtils {
    fun isAndroidTv(context: Context): Boolean {
        val uiMode = context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        if (uiMode == Configuration.UI_MODE_TYPE_TELEVISION) return true
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }
}
