package com.forjahq.app

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultLivePlaybackSpeedControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.LivePlaybackSpeedControl
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs

/** Playback hints from Dart (IPTV live vs Home VOD). */
data class ExoOpenOptions(
    val live: Boolean = false,
    /** Explicit Settings opt-in only. 0 = full quality (never auto-cap). */
    val maxVideoHeight: Int = 0,
    /** Soft bitrate companion when [maxVideoHeight] is set. 0 = none. */
    val maxVideoBitrate: Int = 0,
)

private const val TAG = "ForjaExo"

// Live IPTV: deeper buffers for underrun cushion. Quality caps are opt-in from
// Dart (Settings → IPTV live max quality); never applied automatically.
private const val LIVE_MIN_BUFFER_MS = 12_000
private const val LIVE_MAX_BUFFER_MS = 45_000
private const val LIVE_BUFFER_FOR_PLAYBACK_MS = 2_000
private const val LIVE_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 4_000
private const val LIVE_TARGET_OFFSET_MS = 8_000L
private const val LIVE_MIN_OFFSET_MS = 3_000L
private const val LIVE_MAX_OFFSET_MS = 25_000L
/** Live edge catch-up speed — HD/FHD only. 4K disables (audio stutter). */
private const val LIVE_SPEED_MIN = 0.97f
private const val LIVE_SPEED_MAX = 1.03f
private const val LIVE_UHD_MIN_HEIGHT = 2160
private const val LIVE_UHD_MIN_WIDTH = 3840

// Home VOD. Media3 stock gives no back buffer at all, so every backward seek
// re-fetched from the CDN (issue 151). The byte allocator still caps the real
// depth, so the generous max only pays off on low-bitrate streams.
private const val VOD_MIN_BUFFER_MS = 30_000
private const val VOD_MAX_BUFFER_MS = 120_000
private const val VOD_BUFFER_FOR_PLAYBACK_MS = 2_500
private const val VOD_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 5_000
/** Small enough not to crowd 4K MediaCodec surfaces on a TV box. */
private const val VOD_BACK_BUFFER_MS = 15_000

private fun isTelevisionContext(context: Context): Boolean =
    PlatformUtils.isAndroidTv(context)

private fun isUhdVideo(width: Int, height: Int): Boolean =
    height >= LIVE_UHD_MIN_HEIGHT || width >= LIVE_UHD_MIN_WIDTH

class ExoPlayerHost(
    private val context: Context,
    private val viewId: Int,
    private val activityProvider: () -> Activity?,
    private val emitEvent: (Map<String, Any?>) -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var playerView: PlayerView? = null
    private var player: ExoPlayer? = null
    private var progressRunnable: Runnable? = null
    private var videoAuto = true
    private var lastUrl: String? = null
    private var lastOptions: ExoOpenOptions = ExoOpenOptions()
    private var lastHeaders: Map<String, String> = emptyMap()
    /** Whether the current pipeline was built with the disk cache in front. */
    private var lastCached = false
    /** One display mode switch per media — [Format.frameRate] can re-fire. */
    private var frameRateApplied = false
    /** Last Dart resize mode — re-applied when Flutter remounts the PlatformView. */
    private var resizeMode: Int = AspectRatioFrameLayout.RESIZE_MODE_FIT
    /** Last subtitle appearance — re-applied when Flutter remounts the PlatformView. */
    private var subtitleStyle: SubtitleStyleParams? = null
    /**
     * Live playback-speed catch-up locked off for UHD. Null until first size
     * sample so HD keeps 0.97–1.03 (issue 138).
     */
    private var liveSpeedDisabledForUhd: Boolean? = null

    /**
     * Live edge catch-up. Returns 1.0 for UHD so 4K does not warble audio;
     * HD/FHD keep DefaultLivePlaybackSpeedControl (issue 138).
     */
    private val liveSpeedControl = object : LivePlaybackSpeedControl {
        private val inner = DefaultLivePlaybackSpeedControl.Builder()
            .setFallbackMinPlaybackSpeed(LIVE_SPEED_MIN)
            .setFallbackMaxPlaybackSpeed(LIVE_SPEED_MAX)
            .build()

        override fun setLiveConfiguration(liveConfiguration: MediaItem.LiveConfiguration) {
            inner.setLiveConfiguration(liveConfiguration)
        }

        override fun setTargetLiveOffsetOverrideUs(liveOffsetUs: Long) {
            inner.setTargetLiveOffsetOverrideUs(liveOffsetUs)
        }

        override fun notifyRebuffer() {
            inner.notifyRebuffer()
        }

        override fun getAdjustedPlaybackSpeed(
            liveOffsetUs: Long,
            bufferedDurationUs: Long,
        ): Float {
            if (liveSpeedDisabledForUhd == true) return 1f
            return inner.getAdjustedPlaybackSpeed(liveOffsetUs, bufferedDurationUs)
        }

        override fun getTargetLiveOffsetUs(): Long = inner.targetLiveOffsetUs
    }

    private data class SubtitleStyleParams(
        val sizeSp: Float,
        val textColorArgb: Int,
        val backgroundOpacity: Float,
        val bottomPaddingPx: Float,
        val bold: Boolean,
        val font: String,
    )

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            when (state) {
                // True rebuffer — not isLoading. Live IPTV stays isLoading while
                // happily playing (prefetch), which used to stick "Reconnecting…".
                Player.STATE_BUFFERING ->
                    emit(mapOf("type" to "buffering", "value" to true))
                Player.STATE_READY -> {
                    emit(mapOf("type" to "ready"))
                    emit(mapOf("type" to "buffering", "value" to false))
                    emitTracks()
                    player?.videoSize?.let { applyLiveSpeedForVideoSize(it) }
                    applyContentFrameRate()
                }
                Player.STATE_ENDED -> emit(mapOf("type" to "ended"))
            }
            emitProgress()
            syncKeepScreenOn()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emit(mapOf("type" to "playing", "value" to isPlaying))
            if (isPlaying) {
                emit(mapOf("type" to "buffering", "value" to false))
            }
            // ATV Ambient/screensaver: FLAG_KEEP_SCREEN_ON while playWhenReady
            // (MediaKit Video re-holds wakelock on playing; Exo did not).
            syncKeepScreenOn()
        }

        override fun onTracksChanged(tracks: Tracks) {
            emitTracks()
            player?.videoSize?.let { applyLiveSpeedForVideoSize(it) }
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            applyLiveSpeedForVideoSize(videoSize)
            applyContentFrameRate()
        }

        override fun onPlaybackParametersChanged(playbackParameters: PlaybackParameters) {
            // Clamp if live catch-up still nudges while UHD-locked.
            if (liveSpeedDisabledForUhd == true &&
                abs(playbackParameters.speed - 1f) > 0.001f
            ) {
                player?.setPlaybackSpeed(1f)
            }
        }

        override fun onRenderedFirstFrame() {
            // Physical ATV SurfaceView bind health — Dart falls back to
            // TextureView when READY/playing never emits this (audio-only).
            emit(mapOf("type" to "renderedFirstFrame"))
        }

        override fun onPlayerError(error: PlaybackException) {
            // Include cause (e.g. AAC ASC ArrayIndexOutOfBounds) so Dart can
            // treat extractor deaths as hard-open fails and swap engines.
            val detail = buildString {
                append(error.message ?: error.toString())
                var c = error.cause
                var depth = 0
                while (c != null && depth < 4) {
                    append(": ")
                    append(c.javaClass.simpleName)
                    val cm = c.message
                    if (!cm.isNullOrBlank()) {
                        append(": ")
                        append(cm)
                    }
                    c = c.cause
                    depth++
                }
            }
            emit(
                mapOf(
                    "type" to "error",
                    "message" to detail,
                ),
            )
        }
    }

    /**
     * Frame-health telemetry to `logcat -s ForjaExo`. Needed because
     * `setEnableDecoderFallback(true)` can silently swap in a software decoder,
     * which looks identical to a compositing stutter from the couch (issue 108).
     */
    private val frameHealthListener = object : AnalyticsListener {
        override fun onVideoDecoderInitialized(
            eventTime: AnalyticsListener.EventTime,
            decoderName: String,
            initializedTimestampMs: Long,
            initializationDurationMs: Long,
        ) {
            Log.i("ForjaExo", "video decoder=$decoderName")
        }

        override fun onVideoInputFormatChanged(
            eventTime: AnalyticsListener.EventTime,
            format: androidx.media3.common.Format,
            decoderReuseEvaluation: androidx.media3.exoplayer.DecoderReuseEvaluation?,
        ) {
            Log.i(
                "ForjaExo",
                "video format=${format.sampleMimeType} " +
                    "${format.width}x${format.height} fps=${format.frameRate}",
            )
        }

        override fun onDroppedVideoFrames(
            eventTime: AnalyticsListener.EventTime,
            droppedFrames: Int,
            elapsedMs: Long,
        ) {
            Log.w("ForjaExo", "dropped $droppedFrames frames in ${elapsedMs}ms")
        }
    }

    fun attachView(view: PlayerView) {
        if (playerView === view) return
        // Remount: swap surface without releasing the ExoPlayer host.
        playerView?.player = null
        playerView = view
        view.useController = false
        // Remounted PlayerView defaults to FIT in XML — restore last mode so a
        // mid-stream remount cannot leave Zoom/Fill stuck or drop a user Fit.
        view.resizeMode = resizeMode
        player?.let { view.player = it }
        subtitleStyle?.let { applySubtitleStyleToView(view, it) }
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
        videoAuto = true
        liveSpeedDisabledForUhd = null
        frameRateApplied = false
        val cached = !options.live && ForjaExoMediaCache.isCacheable(url)
        val existing = player
        // Soft reopen: reuse the ExoPlayer when the pipeline shape matches.
        // Full release+recreate on every IPTV reload / recovery ANRs ATV — goldfish
        // / MediaCodec release often exceeds the 5s input window (issue 128).
        val canReuse = existing != null &&
            lastOptions.live == options.live &&
            lastOptions.maxVideoHeight == options.maxVideoHeight &&
            lastOptions.maxVideoBitrate == options.maxVideoBitrate &&
            lastHeaders == headers &&
            lastCached == cached
        lastUrl = url
        lastOptions = options
        lastHeaders = headers
        lastCached = cached
        if (canReuse) {
            applyLiveTrackCaps(existing!!, options)
            existing.setMediaItem(
                mediaItemBuilder(url, subtitles, options).build(),
                /* resetPosition= */ startMs <= 0,
            )
            existing.prepare()
            if (startMs > 0) {
                existing.seekTo(startMs)
            }
            existing.playWhenReady = true
            startProgressLoop()
            // isPlaying may not re-fire when already true — re-assert Ambient lock.
            syncKeepScreenOn()
            return
        }

        stopInternal(releasePlayer = true)

        val httpFactory = buildHttpFactory(headers)
        // DefaultDataSource handles file:// / content:// / asset; HTTP goes through [httpFactory].
        val baseFactory = DefaultDataSource.Factory(context, httpFactory)
        val dataSourceFactory = if (cached) {
            ForjaExoMediaCache.wrap(context, baseFactory)
        } else {
            baseFactory
        }
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
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    VOD_MIN_BUFFER_MS,
                    VOD_MAX_BUFFER_MS,
                    VOD_BUFFER_FOR_PLAYBACK_MS,
                    VOD_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
                )
                .setBackBuffer(VOD_BACK_BUFFER_MS, /* retainBackBufferFromKeyframe= */ true)
                // Left false on purpose: the byte allocator stays the hard cap so
                // a 4K remux cannot buffer 120s into RAM on a TV box.
                .setPrioritizeTimeOverSizeThresholds(false)
                .build()
        }

        // Prefer HW decode; fall back to software if MediaCodec rejects the
        // stream (common on weak ATV SoCs with odd IPTV profiles).
        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
            // Media3 only enables async MediaCodec queueing by default on API 31+.
            // Older leanback SoCs (Android 7 TVs) queue on the playback thread and
            // drop frames under load — force it on for even frame pacing (issue 108).
            .forceEnableMediaCodecAsynchronousQueueing()

        val exoBuilder = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setRenderersFactory(renderersFactory)
            .setLoadControl(loadControl)
            .setLivePlaybackSpeedControl(liveSpeedControl)
        if (!options.live && isTelevisionContext(context)) {
            // D-pad ±10s on a remote must feel instant. PREVIOUS_SYNC (not
            // CLOSEST_SYNC) so a resume never lands past unwatched footage.
            exoBuilder.setSeekParameters(SeekParameters.PREVIOUS_SYNC)
        }
        val exo = exoBuilder.build()
        // Pause when another app takes audio focus (Netflix, etc.) — issue 134.
        exo.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build(),
            /* handleAudioFocus= */ true,
        )
        exo.addListener(listener)
        exo.addAnalyticsListener(frameHealthListener)
        // Weak TVs throttle decode when nothing holds a wake lock. A two-hour
        // movie needs this at least as much as a live channel does (issue 151).
        exo.setWakeMode(
            if (ForjaExoMediaCache.isCacheable(url)) {
                C.WAKE_MODE_NETWORK
            } else {
                C.WAKE_MODE_LOCAL
            },
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
        syncKeepScreenOn()
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

    fun setSubtitleStyle(
        sizeSp: Float,
        textColorArgb: Int,
        backgroundOpacity: Float,
        bottomPaddingPx: Float,
        bold: Boolean,
        font: String,
    ) {
        val params = SubtitleStyleParams(
            sizeSp = sizeSp.coerceIn(10f, 80f),
            textColorArgb = textColorArgb,
            backgroundOpacity = backgroundOpacity.coerceIn(0f, 1f),
            bottomPaddingPx = bottomPaddingPx.coerceAtLeast(0f),
            bold = bold,
            font = font,
        )
        subtitleStyle = params
        playerView?.let { applySubtitleStyleToView(it, params) }
    }

    private fun applySubtitleStyleToView(view: PlayerView, params: SubtitleStyleParams) {
        val subtitleView = view.subtitleView ?: return
        subtitleView.setApplyEmbeddedStyles(false)
        subtitleView.setApplyEmbeddedFontSizes(false)
        subtitleView.setFixedTextSize(TypedValue.COMPLEX_UNIT_SP, params.sizeSp)
        // Flutter Position slider is 0–120 px; map to a small bottom fraction.
        val fraction = (0.02f + (params.bottomPaddingPx / 120f) * 0.18f).coerceIn(0.02f, 0.22f)
        subtitleView.setBottomPaddingFraction(fraction)
        val bgAlpha = (params.backgroundOpacity * 255f).toInt().coerceIn(0, 255)
        val backgroundColor = Color.argb(bgAlpha, 0, 0, 0)
        val typeface = typefaceFor(params.font, params.bold)
        val style = CaptionStyleCompat(
            params.textColorArgb,
            backgroundColor,
            Color.TRANSPARENT,
            CaptionStyleCompat.EDGE_TYPE_OUTLINE,
            Color.BLACK,
            typeface,
        )
        subtitleView.setStyle(style)
    }

    private fun typefaceFor(font: String, bold: Boolean): Typeface {
        val style = if (bold) Typeface.BOLD else Typeface.NORMAL
        return when (font) {
            "Roboto Mono" -> Typeface.create(Typeface.MONOSPACE, style)
            "Default" -> Typeface.create(Typeface.DEFAULT, style)
            else -> {
                val named = Typeface.create(font, style)
                if (named != null) named else Typeface.create(Typeface.SANS_SERIF, style)
            }
        }
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
        // Speed catch-up stays on; UHD locks it off via [liveSpeedControl].
        if (options.live) {
            builder.setLiveConfiguration(
                MediaItem.LiveConfiguration.Builder()
                    .setTargetOffsetMs(LIVE_TARGET_OFFSET_MS)
                    .setMinOffsetMs(LIVE_MIN_OFFSET_MS)
                    .setMaxOffsetMs(LIVE_MAX_OFFSET_MS)
                    .setMinPlaybackSpeed(LIVE_SPEED_MIN)
                    .setMaxPlaybackSpeed(LIVE_SPEED_MAX)
                    .build(),
            )
        }
        return builder
    }

    /**
     * 4K live: disable Exo live edge speed-ramp (0.97–1.03) — that warble is
     * the stutter. HD/FHD keep catch-up. Adaptive ladder can flip either way.
     */
    private fun applyLiveSpeedForVideoSize(videoSize: VideoSize) {
        if (!lastOptions.live) return
        if (videoSize.width <= 0 && videoSize.height <= 0) return
        val wantDisable = isUhdVideo(videoSize.width, videoSize.height)
        if (liveSpeedDisabledForUhd == wantDisable) return
        liveSpeedDisabledForUhd = wantDisable
        val p = player ?: return
        if (wantDisable && abs(p.playbackParameters.speed - 1f) > 0.001f) {
            p.setPlaybackSpeed(1f)
        }
        Log.i(
            TAG,
            "live speed ${if (wantDisable) "OFF (UHD ${videoSize.width}x${videoSize.height})" else "ON (sub-UHD)"}",
        )
    }

    /**
     * Ask the display for a refresh rate that divides cleanly into the content
     * frame rate (issues 151 / 108). Live is included: a 50 or 25 fps channel on
     * a fixed 60 Hz TV judders exactly like low FPS. [frameRateApplied] makes this
     * one switch per open, so an adaptive ladder flip cannot re-trigger an HDMI
     * re-sync mid-channel.
     *
     * `Format.frameRate` is unset on many HLS variants; those get no switch
     * rather than a guess.
     */
    private fun applyContentFrameRate() {
        if (frameRateApplied) return
        val activity = activityProvider() ?: return
        if (!isTelevisionContext(context)) return
        val fps = player?.videoFormat?.frameRate ?: return
        if (fps <= 0f) return
        frameRateApplied = true
        ForjaDisplayFrameRate.apply(activity, fps)
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
                haystack.contains("strmd.st") ||
                haystack.contains("indianservers.st") ||
                // Highfly / Streamed leaf CDN (Live Matches Stremio): signed
                // `/leaf/{id}/{token}/…` HLS without a `.m3u8` suffix — Exo
                // otherwise picks Progressive → UnrecognizedInputFormat →
                // IPTV watchdog "Reconnecting…" forever.
                haystack.contains("recaps.dev") ||
                haystack.contains("/leaf/") ||
                // VixSrc (and similar embeds): tokenised HLS at /playlist/{id}?token=
                // without a .m3u8 suffix — Exo defaults to progressive otherwise.
                (haystack.contains("/playlist/") && !haystack.contains("webmanifest")) ->
                MimeTypes.APPLICATION_M3U8
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
        // Settings opt-in only — never invent a device default cap.
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
        resizeMode = when (mode) {
            "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            "zoom" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
        playerView?.resizeMode = resizeMode
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
            // onTracksChanged emits — do not double-emit (issue 132).
            return
        }

        if (type == "text" && (trackId == null || trackId == "off")) {
            p.trackSelectionParameters = p.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                .build()
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
    }

    fun stop() {
        // Soft stop — keep the ExoPlayer instance so the next open can soft-reuse
        // without a MediaCodec release on the main thread (ATV ANR).
        stopProgressLoop()
        clearDisplayFrameRate()
        applyKeepScreenOn(false)
        try {
            player?.stop()
            player?.clearMediaItems()
        } catch (_: Exception) {
        }
        lastUrl = null
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
        clearDisplayFrameRate()
        applyKeepScreenOn(false)
        player?.removeListener(listener)
        player?.removeAnalyticsListener(frameHealthListener)
        playerView?.player = null
        if (releasePlayer) {
            player?.release()
            player = null
            lastUrl = null
            lastOptions = ExoOpenOptions()
            lastHeaders = emptyMap()
            lastCached = false
        }
        videoAuto = true
        liveSpeedDisabledForUhd = null
    }


    /**
     * Android TV Ambient Mode starts after ~10m with no user input unless the
     * foreground window holds [FLAG_KEEP_SCREEN_ON]. MediaKit's Video widget
     * re-acquires wakelock on every playing=true; Exo only had a one-shot Dart
     * enable — and PlayerView keepScreenOn inside a PlatformView does not always
     * propagate. Tie the Activity flag to playWhenReady (issue 201).
     */
    private fun syncKeepScreenOn() {
        val p = player
        val keep = p != null &&
            p.playWhenReady &&
            p.playbackState != Player.STATE_IDLE &&
            p.playbackState != Player.STATE_ENDED
        applyKeepScreenOn(keep)
    }

    private fun applyKeepScreenOn(keep: Boolean) {
        val activity = activityProvider() ?: return
        val apply = {
            activity.window?.let { window ->
                if (keep) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
            playerView?.keepScreenOn = keep
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            apply()
        } else {
            activity.runOnUiThread(apply)
        }
    }

    private fun clearDisplayFrameRate() {
        if (!frameRateApplied) return
        frameRateApplied = false
        activityProvider()?.let { ForjaDisplayFrameRate.clear(it) }
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
        // Live / DVR: Player.duration is often TIME_UNSET; contentDuration or a
        // seekable timeline window still carries a scrubbable length for VOD-like
        // IPTV movies mis-tagged live, and for catch-up windows.
        var durationMs = p.duration
        if (durationMs <= 0) {
            val content = p.contentDuration
            if (content > 0) durationMs = content
        }
        if (durationMs <= 0 && !p.currentTimeline.isEmpty) {
            val window = Timeline.Window()
            p.currentTimeline.getWindow(p.currentMediaItemIndex, window)
            if (window.durationMs > 0) durationMs = window.durationMs
        }
        if (durationMs <= 0) durationMs = 0L
        emit(
            mapOf(
                "type" to "progress",
                "position" to p.currentPosition,
                "duration" to durationMs,
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
    /** Weak: the display frame-rate switch needs a window, not the app context. */
    private var activityRef: WeakReference<Activity>? = null
    private val hosts = ConcurrentHashMap<Int, ExoPlayerHost>()
    private var eventSink: EventChannel.EventSink? = null

    fun bindEngine(context: Context, messenger: io.flutter.plugin.common.BinaryMessenger, registry: io.flutter.plugin.platform.PlatformViewRegistry) {
        appContext = context.applicationContext
        (context as? Activity)?.let { activityRef = WeakReference(it) }
        methodChannel = MethodChannel(messenger, CHANNEL)
        methodChannel?.setMethodCallHandler(this)
        eventChannel = EventChannel(messenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(this)
        registry.registerViewFactory(VIEW_TYPE, ExoPlayerViewFactory(this))
    }

    internal fun hostFor(viewId: Int): ExoPlayerHost {
        val ctx = appContext ?: throw IllegalStateException("ExoPlayer plugin not initialized")
        return hosts.getOrPut(viewId) {
            ExoPlayerHost(
                ctx,
                viewId,
                { activityRef?.get()?.takeUnless { it.isFinishing } },
            ) { event -> eventSink?.success(event) }
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
            "setSubtitleStyle" -> {
                val viewId = call.argument<Int>("viewId")
                    ?: return result.error("ARG", "viewId required", null)
                hostFor(viewId).setSubtitleStyle(
                    sizeSp = call.argument<Number>("sizeSp")?.toFloat() ?: 24f,
                    textColorArgb = call.argument<Number>("textColorArgb")?.toInt()
                        ?: Color.WHITE,
                    backgroundOpacity = call.argument<Number>("backgroundOpacity")?.toFloat()
                        ?: 0f,
                    bottomPaddingPx = call.argument<Number>("bottomPaddingPx")?.toFloat()
                        ?: 0f,
                    bold = call.argument<Boolean>("bold") == true,
                    font = call.argument<String>("font") ?: "Default",
                )
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
        val requested = (map?.get("surfaceType") as? String)?.lowercase() ?: "texture"
        // Goldfish/ranchu: SurfaceView MediaCodec often fails setOutputSurface
        // (BAD_INDEX) → audio-only + black hole covering Flutter chrome.
        val surfaceType =
            if (PlatformUtils.isLikelyEmulator()) "texture" else requested
        if (surfaceType != requested) {
            Log.i(
                "ForjaExo",
                "emulator: forcing texture_view (requested=$requested)",
            )
        }
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
        playerView.clearFocus()
        // Children (SurfaceView) can still accept focus on some API levels.
        for (i in 0 until playerView.childCount) {
            val child = playerView.getChildAt(i)
            child.isFocusable = false
            child.isFocusableInTouchMode = false
            child.clearFocus()
        }
        // Letterbox (FIT) — never inherit ZOOM/FILL from a remounted view.
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        // Media3 opt-in: SurfaceView inside Flutter hybrid composition / AndroidView
        // otherwise paints zoomed/cropped on API 34+ (androidx/media#1237). ATV
        // uses SurfaceView; phone TextureView does not need this.
        if (surfaceType == "surface") {
            playerView.setEnableComposeSurfaceSyncWorkaround(true)
        }
        plugin.hostFor(hostId).attachView(playerView)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        // Do not releaseHost here - Flutter remounts VirtualDisplay AndroidViews
        // (common on ATV) and that would kill playback mid-stream.
        plugin.detachHostView(hostId, playerView)
    }
}
