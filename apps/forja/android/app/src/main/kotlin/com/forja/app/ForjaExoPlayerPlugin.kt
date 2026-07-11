package com.forja.app

import android.content.Context
import android.content.res.Configuration
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

class ExoPlayerHost(
    private val context: Context,
    private val viewId: Int,
    private val emitEvent: (Map<String, Any?>) -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var playerView: PlayerView? = null
    private var player: ExoPlayer? = null
    private var progressRunnable: Runnable? = null

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            when (state) {
                Player.STATE_READY -> emit(mapOf("type" to "ready"))
                Player.STATE_ENDED -> emit(mapOf("type" to "ended"))
                Player.STATE_BUFFERING -> emit(mapOf("type" to "buffering", "value" to true))
                Player.STATE_IDLE -> emit(mapOf("type" to "buffering", "value" to false))
            }
            emitProgress()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emit(mapOf("type" to "playing", "value" to isPlaying))
        }

        override fun onPlayerError(error: PlaybackException) {
            emit(
                mapOf(
                    "type" to "error",
                    "message" to (error.message ?: error.toString()),
                ),
            )
        }
    }

    fun attachView(view: PlayerView) {
        playerView = view
        view.useController = false
        player?.let { view.player = it }
    }

    fun detachView() {
        playerView?.player = null
        playerView = null
    }

    fun open(url: String, headers: Map<String, String>, startMs: Long, subtitles: List<Map<String, String>>) {
        stopInternal(releasePlayer = true)
        val httpFactory = DefaultHttpDataSource.Factory()
        val requestHeaders = headers.toMutableMap()
        val userAgent = requestHeaders.remove("User-Agent")
            ?: requestHeaders.remove("user-agent")
        if (!userAgent.isNullOrEmpty()) {
            httpFactory.setUserAgent(userAgent)
        }
        if (requestHeaders.isNotEmpty()) {
            httpFactory.setDefaultRequestProperties(requestHeaders)
        }

        val mediaSourceFactory = DefaultMediaSourceFactory(context)
            .setDataSourceFactory(httpFactory)

        val builder = MediaItem.Builder().setUri(Uri.parse(url))
        if (subtitles.isNotEmpty()) {
            val configs = subtitles.mapNotNull { sub ->
                val subUrl = sub["url"]?.trim().orEmpty()
                if (subUrl.isEmpty()) return@mapNotNull null
                val mime = when {
                    subUrl.lowercase().endsWith(".vtt") -> MimeTypes.TEXT_VTT
                    subUrl.lowercase().endsWith(".srt") -> MimeTypes.APPLICATION_SUBRIP
                    else -> MimeTypes.TEXT_VTT
                }
                MediaItem.SubtitleConfiguration.Builder(Uri.parse(subUrl))
                    .setMimeType(mime)
                    .setLanguage(sub["lang"] ?: "und")
                    .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                    .build()
            }
            if (configs.isNotEmpty()) {
                builder.setSubtitleConfigurations(configs)
            }
        }

        val exo = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()
        exo.addListener(listener)
        player = exo
        playerView?.player = exo
        exo.setMediaItem(builder.build())
        exo.prepare()
        if (startMs > 0) {
            exo.seekTo(startMs)
        }
        exo.playWhenReady = true
        startProgressLoop()
    }

    fun play() {
        player?.play()
    }

    fun pause() {
        player?.pause()
    }

    fun seekTo(ms: Long) {
        player?.seekTo(ms)
        emitProgress()
    }

    fun stop() {
        stopInternal(releasePlayer = true)
    }

    fun dispose() {
        stopInternal(releasePlayer = true)
    }

    private fun stopInternal(releasePlayer: Boolean) {
        stopProgressLoop()
        player?.removeListener(listener)
        playerView?.player = null
        if (releasePlayer) {
            player?.release()
            player = null
        }
    }

    private fun startProgressLoop() {
        stopProgressLoop()
        val runnable = object : Runnable {
            override fun run() {
                emitProgress()
                mainHandler.postDelayed(this, 500)
            }
        }
        progressRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun stopProgressLoop() {
        progressRunnable?.let { mainHandler.removeCallbacks(it) }
        progressRunnable = null
    }

    private fun emitProgress() {
        val p = player ?: return
        emit(
            mapOf(
                "type" to "progress",
                "position" to p.currentPosition,
                "duration" to if (p.duration > 0) p.duration else 0L,
                "buffered" to p.bufferedPosition,
            ),
        )
    }

    private fun emit(payload: Map<String, Any?>) {
        val out = payload.toMutableMap()
        out["viewId"] = viewId
        emitEvent(out)
    }
}

class ForjaExoPlayerPlugin : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var appContext: Context? = null
    private val hosts = ConcurrentHashMap<Int, ExoPlayerHost>()
    private var eventSink: EventChannel.EventSink? = null

    fun bindEngine(context: Context, messenger: io.flutter.plugin.common.BinaryMessenger, registry: io.flutter.plugin.platform.PlatformViewRegistry) {
        appContext = context.applicationContext
        methodChannel = MethodChannel(messenger, CHANNEL)
        methodChannel?.setMethodCallHandler(this)
        eventChannel = EventChannel(messenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(this)
        registry.registerViewFactory(VIEW_TYPE, ExoPlayerViewFactory(this))
    }

    internal fun hostFor(viewId: Int): ExoPlayerHost {
        val ctx = appContext ?: throw IllegalStateException("ExoPlayer plugin not initialized")
        return hosts.getOrPut(viewId) {
            ExoPlayerHost(ctx, viewId) { event -> eventSink?.success(event) }
        }
    }

    internal fun releaseHost(viewId: Int) {
        hosts.remove(viewId)?.dispose()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isTelevision" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.success(false)
                    return
                }
                val uiMode = ctx.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
                result.success(uiMode == Configuration.UI_MODE_TYPE_TELEVISION)
            }
            "open" -> {
                val viewId = call.argument<Int>("viewId") ?: return result.error("ARG", "viewId required", null)
                val url = call.argument<String>("url") ?: return result.error("ARG", "url required", null)
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                @Suppress("UNCHECKED_CAST")
                val subtitles = call.argument<List<Map<String, String>>>("subtitles") ?: emptyList()
                hostFor(viewId).open(url, headers, startMs, subtitles)
                result.success(null)
            }
            "play" -> {
                val viewId = call.argument<Int>("viewId")!!
                hostFor(viewId).play()
                result.success(null)
            }
            "pause" -> {
                val viewId = call.argument<Int>("viewId")!!
                hostFor(viewId).pause()
                result.success(null)
            }
            "seekTo" -> {
                val viewId = call.argument<Int>("viewId")!!
                val ms = call.argument<Number>("positionMs")?.toLong() ?: 0L
                hostFor(viewId).seekTo(ms)
                result.success(null)
            }
            "stop" -> {
                val viewId = call.argument<Int>("viewId")!!
                hostFor(viewId).stop()
                result.success(null)
            }
            "dispose" -> {
                val viewId = call.argument<Int>("viewId")!!
                releaseHost(viewId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        const val CHANNEL = "com.forja.app/exoplayer"
        const val EVENT_CHANNEL = "com.forja.app/exoplayer_events"
        const val VIEW_TYPE = "forja-exoplayer"
    }
}

class ExoPlayerViewFactory(private val plugin: ForjaExoPlayerPlugin) :
    io.flutter.plugin.platform.PlatformViewFactory(io.flutter.plugin.common.StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): io.flutter.plugin.platform.PlatformView {
        val map = args as? Map<*, *>
        val hostId = (map?.get("viewId") as? Number)?.toInt() ?: viewId
        return ExoPlayerPlatformView(context, hostId, plugin)
    }
}

class ExoPlayerPlatformView(
    context: Context,
    private val hostId: Int,
    private val plugin: ForjaExoPlayerPlugin,
) : io.flutter.plugin.platform.PlatformView {
    private val playerView = PlayerView(context)

    init {
        plugin.hostFor(hostId).attachView(playerView)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        plugin.hostFor(hostId).detachView()
        plugin.releaseHost(hostId)
    }
}
