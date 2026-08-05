package com.forjahq.app

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

/**
 * Bounded on-disk cache in front of remote VOD (issue 151).
 *
 * Without it Media3 has no back buffer at all, so every backward seek discards
 * what just played and re-fetches it from the CDN.
 *
 * [SimpleCache] takes an exclusive lock on its directory for the life of the
 * process, so this must stay a singleton — a second instance on the same folder
 * throws.
 */
object ForjaExoMediaCache {
    private const val TAG = "ForjaExo"
    private const val DIR = "forja-exo-media"
    private const val MAX_BYTES = 512L * 1024 * 1024

    @Volatile
    private var cache: SimpleCache? = null

    @Synchronized
    private fun cache(context: Context): SimpleCache? {
        cache?.let { return it }
        return try {
            SimpleCache(
                File(context.cacheDir, DIR),
                LeastRecentlyUsedCacheEvictor(MAX_BYTES),
                StandaloneDatabaseProvider(context),
            ).also {
                cache = it
                Log.i(TAG, "media cache ready (${MAX_BYTES / (1024 * 1024)} MB LRU)")
            }
        } catch (e: Exception) {
            // Full disk, or the folder is locked by a previous process that has
            // not been reaped yet. Playback must not depend on the cache.
            Log.w(TAG, "media cache unavailable: ${e.message}")
            null
        }
    }

    /**
     * Loopback streams (librqbit torrents, the Rust `/hls-proxy`) already read
     * from local storage — caching them would just double the writes.
     */
    fun isCacheable(url: String): Boolean {
        val uri = runCatching { Uri.parse(url) }.getOrNull() ?: return false
        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return false
        val host = uri.host?.lowercase() ?: return false
        return host != "localhost" &&
            host != "127.0.0.1" &&
            host != "::1" &&
            host != "10.0.2.2"
    }

    /** Wraps [upstream] with the disk cache, or returns it untouched if unavailable. */
    fun wrap(context: Context, upstream: DataSource.Factory): DataSource.Factory {
        val simpleCache = cache(context) ?: return upstream
        return CacheDataSource.Factory()
            .setCache(simpleCache)
            .setUpstreamDataSourceFactory(upstream)
            // A corrupt or unreadable span must fall through to the network
            // rather than surface as a playback error.
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }
}
