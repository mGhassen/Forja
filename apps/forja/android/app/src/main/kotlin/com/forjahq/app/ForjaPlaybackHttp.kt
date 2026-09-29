package com.forjahq.app

import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/** Shared ExoPlayer HTTP client. Uses the platform DNS resolver. */
object ForjaPlaybackHttp {
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()
}
