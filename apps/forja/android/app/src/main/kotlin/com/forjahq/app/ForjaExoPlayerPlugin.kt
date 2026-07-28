package com.forjahq.app

import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

/** Playback hints from Dart (IPTV live vs Home VOD). */
data class ExoOpenOptions(
    val live: Boolean = false,
    /** 0 = let host pick a device-safe cap for live, or no cap for VOD. */
    val maxVideoHeight: Int = 0,
    /** 0 = let host pick a device-safe bitrate for live, or no cap for VOD. */
    val maxVideoBitrate: Int = 0,
)

private const val TAG = "ForjaExo"

// Live IPTV: deeper buffers for underrun cushion. No automatic height/bitrate
// caps — aggressive caps made ATV look soft / low-FPS and unwatchable.
private const val LIVE_MIN_BUFFER_MS = 12_000
private const val LIVE_MAX_BUFFER_MS = 45_000
private const val LIVE_BUFFER_FOR_PLAYBACK_MS = 2_000
private const val LIVE_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 4_000
private const val LIVE_TARGET_OFFSET_MS = 8_000L
private const val LIVE_MIN_OFFSET_MS = 3_000L
private const val LIVE_MAX_OFFSET_MS = 25_000L

private fun isTelevisionContext(context: Context): Boolean =
    PlatformUtils.isAndroidTv(context)

class ExoPlayerHost(
    private val context: Context,
    private val viewId: Int,
    private val emitEvent: (Map<String, Any?>) -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var playerView: PlayerView? = null
    private var player: ExoPlayer? = null
    private var progressRunnable: Runnable? = null
    private var videoAuto = true
    private var lastUrl: String? = null
    private var lastOptions: ExoOpenOptions = ExoOpenOptions()

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            when (state) {
                Player.STATE_READY -> {
                    emit(mapOf("type" to "ready"))
                    emit(mapOf("type" to "buffering", "value" to false))
                    emitTracks()
                }
                Player.STATE_ENDED -> emit(mapOf("type" to "ended"))
            }
            emitProgress()
        }

        override fun onIsLoadingChanged(isLoading: Boolean) {
            emit(mapOf("type" to "buffering", "value" to isLoading))
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emit(mapOf("type" to "playing", "value" to isPlaying))
            if (isPlaying) {
                emit(mapOf("type" to "buffering", "value" to false))
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            emitTracks()
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
        if (playerView === view) return
        // Remount: swap surface without releasing the ExoPlayer host.
        playerView?.player = null
        playerView = view
        view.useController = false
        player?.let { view.player = it }
    }

    fun detachView(view: PlayerView) {
        // Ignore stale PlatformView dispose after a remount already attached a new view.
        if (playerView !== view) return
        view.player = null
        playerView = null
    }

    fun open(
        url: String,
        headers: Map<String, String>,
        startMs: Long,
        subtitles: List<Map<String, String>>,
        options: ExoOpenOptions = ExoOpenOptions(),
    ) {
        stopInternal(releasePlayer = true)
        videoAuto = true
        lastUrl = url
        lastOptions = options

        val httpFactory = buildHttpFactory(headers)
        // DefaultDataSource handles file:// / content:// / asset; HTTP goes through [httpFactory].
        val dataSourceFactory = DefaultDataSource.Factory(context, httpFactory)
        val mediaSourceFactory = DefaultMediaSourceFactory(context)
            .setDataSourceFactory(dataSourceFactory)

        val builder = mediaItemBuilder(url, subtitles, options)

        val loadControl = if (options.live) {
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    LIVE_MIN_BUFFER_MS,
                    LIVE_MAX_BUFFER_MS,
                    LIVE_BUFFER_FOR_PLAYBACK_MS,
                    LIVE_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
                )
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()
        } else {
            DefaultLoadControl.Builder().build()
        }

        // Prefer HW decode; fall back to software if MediaCodec rejects the
        // stream (common on weak ATV SoCs with odd IPTV profiles).
        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)

        val exo = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setRenderersFactory(renderersFactory)
            .setLoadControl(loadControl)
            .build()
        exo.addListener(listener)
        // Wake lock while playing live IPTV — weak TVs throttle decode in doze.
        exo.setWakeMode(
            if (options.live) C.WAKE_MODE_NETWORK else C.WAKE_MODE_NONE,
        )
        player = exo
        playerView?.player = exo

        applyLiveTrackCaps(exo, options)

        exo.setMediaItem(builder.build())
        exo.prepare()
        if (startMs > 0) {
            exo.seekTo(startMs)
        }
        exo.playWhenReady = true
        startProgressLoop()
    }

    /**
     * Soft-reload the current media with new external subtitle sideloads,
     * preserving position and play/pause. Used when online subs arrive or
     * the user picks a language after open.
     */
    fun setSubtitles(subtitles: List<Map<String, String>>) {
        val p = player ?: return
        val url = lastUrl ?: return
        val pos = p.currentPosition
        val playWhenReady = p.playWhenReady
        val item = mediaItemBuilder(url, subtitles, lastOptions).build()
        p.setMediaItem(item, pos)
        p.prepare()
        p.playWhenReady = playWhenReady
    }

    private fun buildHttpFactory(headers: Map<String, String>): DefaultHttpDataSource.Factory {
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
        return httpFactory
    }

    private fun mediaItemBuilder(
        url: String,
        subtitles: List<Map<String, String>>,
        options: ExoOpenOptions,
    ): MediaItem.Builder {
        val builder = MediaItem.Builder().setUri(Uri.parse(url))
        // Force HLS/DASH when the URI path has no .m3u8/.mpd (e.g. local
        // `/hls-proxy?url=…`). Without this, DefaultMediaSourceFactory picks
        // ProgressiveMediaSource and fails with UnrecognizedInputFormatException
        // on the playlist body — Live Matches Streamed handoff black screen.
        mimeForAdaptiveUrl(url)?.let { builder.setMimeType(it) }
        if (subtitles.isNotEmpty()) {
            val configs = subtitles.mapNotNull { sub ->
                subtitleConfiguration(sub)
            }
            if (configs.isNotEmpty()) {
                builder.setSubtitleConfigurations(configs)
            }
        }
        // Live IPTV: sit behind the edge so TextureView + weak SoCs have cushion.
        if (options.live) {
            builder.setLiveConfiguration(
                MediaItem.LiveConfiguration.Builder()
                    .setTargetOffsetMs(LIVE_TARGET_OFFSET_MS)
                    .setMinOffsetMs(LIVE_MIN_OFFSET_MS)
                    .setMaxOffsetMs(LIVE_MAX_OFFSET_MS)
                    .setMinPlaybackSpeed(0.97f)
                    .setMaxPlaybackSpeed(1.03f)
                    .build(),
            )
        }
        return builder
    }

    /** HLS/DASH mime when URI inference would wrongly choose progressive. */
    private fun mimeForAdaptiveUrl(url: String): String? {
        val lower = url.lowercase()
        val nested = runCatching {
            Uri.parse(url).getQueryParameter("url")?.lowercase().orEmpty()
        }.getOrDefault("")
        val haystack = "$lower $nested"
        return when {
            haystack.contains(".mpd") -> MimeTypes.APPLICATION_MPD
            haystack.contains(".m3u8") ||
                haystack.contains("/hls-proxy") ||
                haystack.contains("strmd.st") -> MimeTypes.APPLICATION_M3U8
            else -> null
        }
    }

    private fun subtitleConfiguration(sub: Map<String, String>): MediaItem.SubtitleConfiguration? {
        val subUrl = sub["url"]?.trim().orEmpty()
        if (subUrl.isEmpty()) return null
        val mime = mimeForSubtitleUrl(subUrl) ?: return null
        val lang = sub["lang"]?.takeIf { it.isNotBlank() } ?: "und"
        val label = sub["label"]?.takeIf { it.isNotBlank() } ?: lang
        return MediaItem.SubtitleConfiguration.Builder(Uri.parse(subUrl))
            .setMimeType(mime)
            .setLanguage(lang)
            .setLabel(label)
            // Let Dart apply preferred language - do not force-select every track.
            .setSelectionFlags(0)
            .build()
    }

    private fun mimeForSubtitleUrl(subUrl: String): String? {
        val path = subUrl.lowercase().substringBefore('?').substringBefore('#')
        return when {
            path.endsWith(".vtt") -> MimeTypes.TEXT_VTT
            path.endsWith(".srt") -> MimeTypes.APPLICATION_SUBRIP
            // ASS/SSA needs libass (media_kit) - skip rather than mis-label as VTT.
            path.endsWith(".ass") || path.endsWith(".ssa") -> null
            // Extensionless / unknown: MediaKit downloads as .srt; treat as SubRip.
            else -> MimeTypes.APPLICATION_SUBRIP
        }
    }

    private fun applyLiveTrackCaps(exo: ExoPlayer, options: ExoOpenOptions) {
        val maxHeight = resolveMaxVideoHeight(options)
        val maxBitrate = resolveMaxVideoBitrate(options, maxHeight)
        if (maxHeight <= 0 && maxBitrate <= 0) return
        var params = exo.trackSelectionParameters.buildUpon()
        if (maxHeight > 0) {
            // Width follows 16:9 from height - caps adaptive HLS/DASH variants.
            val maxWidth = (maxHeight * 16) / 9
            params = params.setMaxVideoSize(maxWidth, maxHeight)
        }
        if (maxBitrate > 0) {
            params = params.setMaxVideoBitrate(maxBitrate)
        }
        exo.trackSelectionParameters = params.build()
        Log.i(
            TAG,
            "open live=${options.live} maxHeight=$maxHeight maxBitrate=$maxBitrate sdk=${Build.VERSION.SDK_INT}",
        )
    }

    private fun resolveMaxVideoHeight(options: ExoOpenOptions): Int {
        // Explicit Dart override only — do not auto-cap live ABR (soft/low-FPS picture).
        if (options.maxVideoHeight > 0) return options.maxVideoHeight
        return 0
    }

    private fun resolveMaxVideoBitrate(options: ExoOpenOptions, maxHeight: Int): Int {
        if (options.maxVideoBitrate > 0) return options.maxVideoBitrate
        return 0
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

    fun setVolume(volume: Float) {
        player?.volume = volume.coerceIn(0f, 1f)
    }

    fun setRate(rate: Float) {
        player?.setPlaybackSpeed(rate.coerceIn(0.25f, 2.0f))
    }

    fun setResizeMode(mode: String) {
        val view = playerView ?: return
        view.resizeMode = when (mode) {
            "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            "zoom" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
    }

    fun getTracks(): Map<String, Any?> {
        val p = player ?: return emptyTracks()
        return mapOf(
            "audio" to trackList(p.currentTracks, C.TRACK_TYPE_AUDIO),
            "text" to trackList(p.currentTracks, C.TRACK_TYPE_TEXT),
            "video" to trackList(p.currentTracks, C.TRACK_TYPE_VIDEO),
            "videoAuto" to videoAuto,
            "textOff" to !p.currentTracks.isTypeSelected(C.TRACK_TYPE_TEXT),
            "rate" to p.playbackParameters.speed.toDouble(),
        )
    }

    fun selectTrack(type: String, trackId: String?) {
        val p = player ?: return
        val trackType = when (type) {
            "audio" -> C.TRACK_TYPE_AUDIO
            "text" -> C.TRACK_TYPE_TEXT
            "video" -> C.TRACK_TYPE_VIDEO
            else -> return
        }

        if (type == "video" && (trackId == null || trackId == "auto")) {
            videoAuto = true
            p.trackSelectionParameters = p.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, false)
                .build()
            emitTracks()
            return
        }

        if (type == "text" && (trackId == null || trackId == "off")) {
            p.trackSelectionParameters = p.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                .build()
            emitTracks()
            return
        }

        val parsed = parseTrackId(trackId ?: return) ?: return
        if (parsed.first != trackType) return
        val groups = p.currentTracks.groups
        if (parsed.second < 0 || parsed.second >= groups.size) return
        val group = groups[parsed.second]
        if (group.type != trackType) return
        if (parsed.third < 0 || parsed.third >= group.length) return

        if (type == "video") videoAuto = false

        p.trackSelectionParameters = p.trackSelectionParameters
            .buildUpon()
            .setTrackTypeDisabled(trackType, false)
            .setOverrideForType(
                TrackSelectionOverride(group.mediaTrackGroup, listOf(parsed.third)),
            )
            .build()
        emitTracks()
    }

    fun stop() {
        stopInternal(releasePlayer = true)
    }

    fun dispose() {
        stopInternal(releasePlayer = true)
    }

    private fun emptyTracks(): Map<String, Any?> = mapOf(
        "audio" to emptyList<Map<String, Any?>>(),
        "text" to emptyList<Map<String, Any?>>(),
        "video" to emptyList<Map<String, Any?>>(),
        "videoAuto" to true,
        "textOff" to true,
        "rate" to 1.0,
    )

    private fun trackList(tracks: Tracks, type: Int): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        for (gi in 0 until tracks.groups.size) {
            val group = tracks.groups[gi]
            if (group.type != type) continue
            for (ti in 0 until group.length) {
                if (!group.isTrackSupported(ti)) continue
                val format = group.getTrackFormat(ti)
                val id = "$type:$gi:$ti"
                val label = when (type) {
                    C.TRACK_TYPE_VIDEO -> {
                        val h = format.height
                        val bitrate = format.bitrate
                        when {
                            h > 0 -> "${h}p"
                            bitrate > 0 -> "${bitrate / 1000} kbps"
                            else -> "Track ${out.size + 1}"
                        }
                    }
                    else -> {
                        val lang = format.language
                        val label = format.label
                        when {
                            !label.isNullOrBlank() -> label
                            !lang.isNullOrBlank() -> lang
                            else -> "Track ${out.size + 1}"
                        }
                    }
                }
                out.add(
                    mapOf(
                        "id" to id,
                        "label" to label,
                        "language" to (format.language ?: ""),
                        "selected" to group.isTrackSelected(ti),
                        "height" to format.height,
                        "bitrate" to format.bitrate,
                    ),
                )
            }
        }
        return out
    }

    private fun parseTrackId(id: String): Triple<Int, Int, Int>? {
        val parts = id.split(':')
        if (parts.size != 3) return null
        val type = parts[0].toIntOrNull() ?: return null
        val group = parts[1].toIntOrNull() ?: return null
        val track = parts[2].toIntOrNull() ?: return null
        return Triple(type, group, track)
    }

    private fun emitTracks() {
        emit(mapOf("type" to "tracksChanged") + getTracks())
    }

    private fun stopInternal(releasePlayer: Boolean) {
        stopProgressLoop()
        player?.removeListener(listener)
        playerView?.player = null
        if (releasePlayer) {
            player?.release()
            player = null
            lastUrl = null
            lastOptions = ExoOpenOptions()
        }
        videoAuto = true
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

    /** Detach a surface only - host/player live until Dart calls [dispose]. */
    internal fun detachHostView(viewId: Int, view: PlayerView) {
        hosts[viewId]?.detachView(view)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isTelevision" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.success(false)
                    return
                }
                result.success(isTelevisionContext(ctx))
            }
            "open" -> {
                val viewId = call.argument<Int>("viewId") ?: return result.error("ARG", "viewId required", null)
                val url = call.argument<String>("url") ?: return result.error("ARG", "url required", null)
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                @Suppress("UNCHECKED_CAST")
                val subtitles = call.argument<List<Map<String, String>>>("subtitles") ?: emptyList()
                val options = ExoOpenOptions(
                    live = call.argument<Boolean>("live") == true,
                    maxVideoHeight = call.argument<Number>("maxVideoHeight")?.toInt() ?: 0,
                    maxVideoBitrate = call.argument<Number>("maxVideoBitrate")?.toInt() ?: 0,
                )
                hostFor(viewId).open(url, headers, startMs, subtitles, options)
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
            "setVolume" -> {
                val viewId = call.argument<Int>("viewId")!!
                val volume = call.argument<Number>("volume")?.toFloat() ?: 1f
                hostFor(viewId).setVolume(volume)
                result.success(null)
            }
            "setRate" -> {
                val viewId = call.argument<Int>("viewId")!!
                val rate = call.argument<Number>("rate")?.toFloat() ?: 1f
                hostFor(viewId).setRate(rate)
                result.success(null)
            }
            "setResizeMode" -> {
                val viewId = call.argument<Int>("viewId")!!
                val mode = call.argument<String>("mode") ?: "fit"
                hostFor(viewId).setResizeMode(mode)
                result.success(null)
            }
            "getTracks" -> {
                val viewId = call.argument<Int>("viewId")!!
                result.success(hostFor(viewId).getTracks())
            }
            "selectTrack" -> {
                val viewId = call.argument<Int>("viewId")!!
                val type = call.argument<String>("type") ?: return result.error("ARG", "type required", null)
                val trackId = call.argument<String>("trackId")
                hostFor(viewId).selectTrack(type, trackId)
                result.success(null)
            }
            "setSubtitles" -> {
                val viewId = call.argument<Int>("viewId")
                    ?: return result.error("ARG", "viewId required", null)
                @Suppress("UNCHECKED_CAST")
                val subtitles = call.argument<List<Map<String, String>>>("subtitles") ?: emptyList()
                hostFor(viewId).setSubtitles(subtitles)
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
        const val CHANNEL = "com.forjahq.app/exoplayer"
        const val EVENT_CHANNEL = "com.forjahq.app/exoplayer_events"
        const val VIEW_TYPE = "forja-exoplayer"
    }
}

class ExoPlayerViewFactory(private val plugin: ForjaExoPlayerPlugin) :
    io.flutter.plugin.platform.PlatformViewFactory(io.flutter.plugin.common.StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): io.flutter.plugin.platform.PlatformView {
        val map = args as? Map<*, *>
        val hostId = (map?.get("viewId") as? Number)?.toInt() ?: viewId
        val surfaceType = (map?.get("surfaceType") as? String)?.lowercase() ?: "texture"
        return ExoPlayerPlatformView(context, hostId, plugin, surfaceType)
    }
}

class ExoPlayerPlatformView(
    context: Context,
    private val hostId: Int,
    private val plugin: ForjaExoPlayerPlugin,
    surfaceType: String,
) : io.flutter.plugin.platform.PlatformView {
    // Phone: texture_view (TLHC-safe). ATV: surface_view + Dart hybrid composition
    // for accurate frame timing / full display resolution (TextureView felt low-FPS).
    private val playerView: PlayerView = LayoutInflater.from(context)
        .inflate(
            if (surfaceType == "surface") {
                R.layout.forja_exo_player_view_surface
            } else {
                R.layout.forja_exo_player_view
            },
            null,
        ) as PlayerView

    init {
        // Leanback D-pad must stay in Flutter chrome — PlayerView/SurfaceView
        // otherwise steals focus and remote keys do nothing (IPTV + VOD Exo).
        playerView.isFocusable = false
        playerView.isFocusableInTouchMode = false
        playerView.descendantFocusability = android.view.ViewGroup.FOCUS_BLOCK_DESCENDANTS
        plugin.hostFor(hostId).attachView(playerView)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        // Do not releaseHost here - Flutter remounts VirtualDisplay AndroidViews
        // (common on ATV) and that would kill playback mid-stream.
        plugin.detachHostView(hostId, playerView)
    }
}
