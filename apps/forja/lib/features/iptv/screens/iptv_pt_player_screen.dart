import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:forja/features/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv_atv_live_cache.dart';
import 'package:forja/features/iptv/iptv_title_clean.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/services/external_player_service.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/iptv/channel_guide/iptv_guide_epg.dart';
import 'package:forja/features/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/channel_guide/iptv_channel_guide_panel.dart';
import 'package:forja/features/iptv/channel_guide/iptv_channel_search_overlay.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/shared/engine/live_goat_unlock.dart';
import 'package:forja/features/iptv/iptv_live_continuity_proxy.dart';
import 'package:forja/features/iptv/channel_guide/iptv_player_stats_panel.dart';
import 'package:forja/features/iptv/iptv_lazy_url_health.dart';
import 'package:forja/features/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/providers/iptv_player_providers.dart';
import 'package:forja/features/iptv/screens/iptv_player_chrome_profile.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/play/live_engine.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_iptv_sports_config.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_escape_exit_hint.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/desktop_pip_overlay.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';
import 'package:forja/shared/player/exo/exo_atv_surface_fallback.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_menus.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/forja_network_image.dart';
import 'package:forja/shared/widgets/desktop_window_geometry.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:window_manager/window_manager.dart';

part 'iptv_pt_player_engine_core.dart';
part 'iptv_pt_player_mk_tunables.dart';
part 'iptv_pt_player_live_proxy.dart';
part 'iptv_pt_player_watchdog.dart';
part 'iptv_pt_player_recovery.dart';
part 'iptv_pt_player_engine.dart';
part 'iptv_pt_player_ui.dart';

/// True for live IPTV URLs (Xtream `/live/…`, M3U, unknown). False for Xtream VOD.
@visibleForTesting
bool iptvExoUrlLooksLive(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('/movie/') || lower.contains('/series/')) return false;
  return true;
}

/// Live native playback profile — one MediaKit/Exo config per surface type,
/// not inferred from URL shape.
enum IptvLiveSourceKind {
  /// IPTV Live tab + Forja Sports Xtream channels (TS continuity proxy).
  iptvXtream,

  /// IPTV Live / Forja Sports Stalker (create_link; no continuity proxy).
  iptvStalker,

  /// Live Matches Stremio addon streams (direct HLS / lavf reconnect).
  stremio,

  /// Forja Live / PPV / Streamed engine plugins (direct open + plugin headers).
  liveEngine;

  bool get useContinuityProxy => this == IptvLiveSourceKind.iptvXtream;
}

/// IPTV catalog / Forja Sports: Stalker create_link stays direct; Xtream/M3U use TS proxy.
@visibleForTesting
IptvLiveSourceKind iptvLiveSourceKindForPortal(IptvPortalPlatform platform) {
  return switch (platform) {
    IptvPortalPlatform.stalker => IptvLiveSourceKind.iptvStalker,
    _ => IptvLiveSourceKind.iptvXtream,
  };
}

/// Hard open failure (MediaKit / Exo) — VOD can swap engines once.
@visibleForTesting
bool iptvIsHardOpenFail(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('failed to open') ||
      lower.contains('unable to open') ||
      lower.contains('error opening') ||
      lower.contains('failed to recognize file format') ||
      lower.contains('unrecognizedinputformat') ||
      lower.contains('none of the available extractors') ||
      lower.contains('invalidresponsecode') ||
      lower.contains('response code: 403') ||
      lower.contains('response code: 401') ||
      lower.contains('response code: 407') ||
      lower.contains('arrayindexoutofbounds') ||
      lower.contains('unexpectedloaderexception') ||
      // Exo progressive VOD: HTTP death or Media3 AAC/MP4 extractor crash.
      lower.contains('source error');
}

/// Open/connect death where retrying the same URL is useless (multi-source
/// should rotate immediately). Broader than [iptvIsHardOpenFail] — includes
/// TCP timeouts that never become "Failed to open".
@visibleForTesting
bool iptvIsDeadEndpointFail(String msg) {
  final lower = msg.toLowerCase();
  if (iptvIsHardOpenFail(msg)) return true;
  return lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('connection refused') ||
      lower.contains('could not connect') ||
      lower.contains('network is unreachable') ||
      lower.contains('no route to host') ||
      (lower.contains('tcp:') && lower.contains('failed'));
}

/// Single source for the IPTV player.
class IptvPlaySource {
  final String url;
  final String label;

  /// Source-picker subtitle (e.g. category / group).
  final String? detail;

  /// Optional channel logo (Xtream `stream_icon`).
  final String? logoUrl;

  /// Xtream `stream_id` — used to pull logos from the IPTV catalog cache.
  final String? streamId;

  /// Xtream `epg_channel_id` — fallback when short EPG by stream id is empty.
  final String? epgChannelId;

  /// Optional HTTP headers (Cookie / Referer / Origin) for Exo / MediaKit.
  /// Live Matches Streamed handoff uses these instead of `/hls-proxy`.
  final Map<String, String> headers;

  /// Live Matches: which playback profile applies when this row is active.
  final IptvLiveSourceKind? liveSourceKind;

  /// Live Matches stream sheet: provider chip (PPV / Streamed / …).
  final String? liveProviderBadge;

  /// Live Matches stream sheet: concurrent viewers when known.
  final int liveViewerCount;

  /// Live Matches stream sheet: HD quality row.
  final bool liveStreamHd;

  /// Catalog embed URL before engine unlock (lazy resolve on source switch).
  final String? liveEngineEmbedUrl;

  /// Opaque resolve context for [IptvLiveEngineResolveSource].
  final Map<String, dynamic>? liveEngineResolveParams;

  const IptvPlaySource({
    required this.url,
    required this.label,
    this.detail,
    this.logoUrl,
    this.streamId,
    this.epgChannelId,
    this.headers = const {},
    this.liveSourceKind,
    this.liveProviderBadge,
    this.liveViewerCount = 0,
    this.liveStreamHd = false,
    this.liveEngineEmbedUrl,
    this.liveEngineResolveParams,
  });

  IptvPlaySource copyWith({
    String? url,
    String? label,
    String? detail,
    String? logoUrl,
    String? streamId,
    String? epgChannelId,
    Map<String, String>? headers,
    IptvLiveSourceKind? liveSourceKind,
    String? liveProviderBadge,
    int? liveViewerCount,
    bool? liveStreamHd,
    String? liveEngineEmbedUrl,
    Map<String, dynamic>? liveEngineResolveParams,
  }) {
    return IptvPlaySource(
      url: url ?? this.url,
      label: label ?? this.label,
      detail: detail ?? this.detail,
      logoUrl: logoUrl ?? this.logoUrl,
      streamId: streamId ?? this.streamId,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      headers: headers ?? this.headers,
      liveSourceKind: liveSourceKind ?? this.liveSourceKind,
      liveProviderBadge: liveProviderBadge ?? this.liveProviderBadge,
      liveViewerCount: liveViewerCount ?? this.liveViewerCount,
      liveStreamHd: liveStreamHd ?? this.liveStreamHd,
      liveEngineEmbedUrl: liveEngineEmbedUrl ?? this.liveEngineEmbedUrl,
      liveEngineResolveParams:
          liveEngineResolveParams ?? this.liveEngineResolveParams,
    );
  }

  /// Channel name for chrome — strips leading `T3 · ` rank prefix.
  String get chromeTitle {
    final t = label.replaceFirst(RegExp(r'^T\d+\s*·\s*'), '').trim();
    return t.isEmpty ? label : t;
  }

  /// Match-rank badge (`T1`…`T4`) when the label carries a Sportio tier prefix.
  String? get tierBadge {
    final m = RegExp(r'^T(\d+)\s*·\s*').firstMatch(label);
    if (m == null) return null;
    return 'T${m.group(1)}';
  }

  /// Solid fill for [tierBadge] — T1 strongest → T4 weakest.
  Color? get tierBadgeColor {
    return switch (tierBadge) {
      'T1' => const Color(0xFF22C55E), // green
      'T2' => const Color(0xFF84CC16), // lime
      'T3' => const Color(0xFFEAB308), // amber
      'T4' => const Color(0xFF64748B), // slate
      _ => null,
    };
  }

  /// Channel name for Source rows / chrome — portal name as-is (only strips `Tn ·`).
  String get pickerTitle => chromeTitle;

  /// Source-picker secondary line — category only.
  String? get pickerSubtitle {
    final cat = (detail ?? '').trim();
    if (cat.isEmpty) return null;
    return _normalizePipes(cat);
  }

  static String _normalizePipes(String s) =>
      s.replaceAll(RegExp(r'\s*\|\s*'), ' · ');
}

/// True when [url] is already a playable handoff (HLS/proxy), not a catalog embed.
bool iptvLiveEnginePlayUrlReady(String url) {
  final u = url.trim().toLowerCase();
  if (u.isEmpty) return false;
  if (u.contains('127.0.0.1') || u.contains('/hls-proxy')) return true;
  return RegExp(r'\.m3u8(\?|$)|\.mp4(\?|$)').hasMatch(u);
}

/// Cache key for live-source hover / picker health probes.
String iptvLiveSourceProbeKey(IptvPlaySource src) {
  final id = (src.streamId ?? '').trim();
  if (id.isNotEmpty) return id;
  final url = src.url.trim();
  if (url.isNotEmpty && !url.startsWith('pending:')) return url;
  final embed = (src.liveEngineEmbedUrl ?? '').trim();
  if (embed.isNotEmpty) return embed;
  return url;
}

/// Playable URL for [IptvAliveChecker], or null when HTTP cannot judge the row
/// (catalog embed page, unresolved `pending:` without a handoff URL).
String? iptvLiveSourceProbeUrl(IptvPlaySource src) {
  if (src.liveSourceKind == IptvLiveSourceKind.iptvXtream ||
      src.liveSourceKind == IptvLiveSourceKind.iptvStalker ||
      // Flixnest JWT etc.: bare probe paints red while MediaKit opens after
      // retries (same cold-open flake as "Failed to open" → healthy streak).
      src.liveSourceKind == IptvLiveSourceKind.stremio) {
    return null;
  }
  final url = src.url.trim();
  if (iptvLiveEnginePlayUrlReady(url)) {
    // WatchFooty / StreamFree / GOAT signed playlists need Referer — bare
    // engine probe false-negatives while Exo/MediaKit play fine with headers.
    if (src.liveSourceKind == IptvLiveSourceKind.liveEngine &&
        (LiveGoatUnlock.preferDirectEnginePlayback(url) ||
            (Uri.tryParse(url)?.host.toLowerCase().contains('wfty.st') ??
                false))) {
      return null;
    }
    if (src.headers.isNotEmpty) return null;
    return url;
  }

  final embed = (src.liveEngineEmbedUrl ?? '').trim();
  if (url.startsWith('pending:')) return null;

  if (src.liveSourceKind == IptvLiveSourceKind.liveEngine || embed.isNotEmpty) {
    return null;
  }

  if (url.isEmpty) return null;
  return url;
}

/// Row [iptvLiveSourceProbeUrl] cannot judge — still selectable, not dead.
/// Covers embed pages, portal Live TV, Stremio Live TV (signed flixnest JWT),
/// signed Streamed/WatchFooty HLS (Referer), and direct-playback rows that
/// drop [IptvPlaySource.liveEngineEmbedUrl].
bool iptvLiveSourceProbeSkipped(IptvPlaySource src) {
  return iptvLiveSourceProbeUrl(src) == null;
}

/// Live Sports Providers hover: portal rows, ready HLS/MP4, and Stremio http(s)
/// play URLs. Embed / `pending:` catalog pages stay off. Stremio and signed
/// Streamed/WatchFooty rows probe with headers in `_liveHoverProbe` (not bare
/// [IptvAliveChecker] — that false-fails JWT / Referer CDNs).
bool iptvLiveSourceCanHoverProbe(IptvPlaySource src) {
  if (src.liveSourceKind == IptvLiveSourceKind.iptvXtream ||
      src.liveSourceKind == IptvLiveSourceKind.iptvStalker) {
    return true;
  }
  final url = src.url.trim();
  if (url.isEmpty || url.startsWith('pending:')) return false;
  if (src.liveSourceKind == IptvLiveSourceKind.stremio) {
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
  return iptvLiveEnginePlayUrlReady(url);
}

typedef IptvLiveEngineResolveSource =
    Future<IptvPlaySource?> Function(
      IptvPlaySource catalogSource, {
      void Function(String message)? onProgress,
    });

/// Dedicated IPTV / Live native player. Android remembers Exo / MediaKit per
/// [engineContext] (IPTV ≠ VOD ≠ Live); other platforms use libmpv. Includes:
///   • Watchdog (3 detectors): long buffering, frozen position, ready-but-not-playing
///   • Tiered recovery: reopen + live-edge → stop+open → recreate
///   • Mid-stream underrun → no back-buffer (freeze, no replay); proxy + ffmpeg reconnect bridge CDN closes
///   • Multi-source rotation
///   • Backoff retries with healthy-streak reset
///   • Pretty responsive overlay UI
class IptvPtPlayerScreen extends ConsumerStatefulWidget {
  final List<IptvPlaySource> sources;
  final String title;
  final String? subtitle;
  final String? logoUrl;
  final IptvChannelGuide? channelGuide;

  /// Fired when the in-player guide tunes a different Xtream channel.
  final ValueChanged<IptvStream>? onChannelChanged;

  /// Catalog stream marked dead (Stalker create_link / format fail) → red status.
  final ValueChanged<String>? onStreamDead;

  /// Which surface preference to read/write (default IPTV).
  final BuiltInPlayerContext engineContext;

  /// When set on Android, boot with this engine for this session only.
  final BuiltInPlayerEngine? forceBuiltInEngine;

  /// Movies/series: no live-edge snap, finite recovery, online subs.
  /// Live channels leave this false so existing live behavior is unchanged.
  final bool vodPlayback;

  /// Movies/series: fetch online subs + Search-by-name (not live).
  final bool onlineSubtitles;

  /// Prefer over [title] for subtitle APIs (e.g. series show name).
  final String? subtitleSearchTitle;
  final int? subtitleSeason;
  final int? subtitleEpisode;
  final int? subtitleYear;

  /// Series: in-player episode list (same panel as hub VOD players).
  final List<IptvEpisode>? seriesEpisodes;
  final IptvPortal? seriesPortal;

  /// Show name for chrome / episode switch titles.
  final String? seriesShowTitle;

  /// When true, top chrome **subtitle** follows the active [IptvPlaySource]
  /// (My IPTV sports — title stays the match; each source is a different channel).
  final bool titleTracksSource;

  /// Default live profile when sources omit [IptvPlaySource.liveSourceKind].
  final IptvLiveSourceKind? liveSourceKind;

  /// Live Matches: unlock catalog embed rows on source switch.
  final IptvLiveEngineResolveSource? liveEngineResolveSource;

  const IptvPtPlayerScreen({
    super.key,
    required this.sources,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.channelGuide,
    this.onChannelChanged,
    this.onStreamDead,
    this.engineContext = BuiltInPlayerContext.iptv,
    this.forceBuiltInEngine,
    this.vodPlayback = false,
    this.onlineSubtitles = false,
    this.subtitleSearchTitle,
    this.subtitleSeason,
    this.subtitleEpisode,
    this.subtitleYear,
    this.seriesEpisodes,
    this.seriesPortal,
    this.seriesShowTitle,
    this.titleTracksSource = false,
    this.liveSourceKind,
    this.liveEngineResolveSource,
  });

  /// Convenience: build for a single catalog stream (Xtream / Stalker / M3U).
  factory IptvPtPlayerScreen.singleStream({
    Key? key,
    required String url,
    required IptvStream stream,
    String? portalName,
    IptvPortalPlatform? portalPlatform,
    IptvChannelGuide? channelGuide,
    ValueChanged<IptvStream>? onChannelChanged,
    ValueChanged<String>? onStreamDead,
    BuiltInPlayerContext? engineContext,
    BuiltInPlayerEngine? forceBuiltInEngine,
  }) {
    final vod = stream.kind == 'vod' || stream.kind == 'series';
    final kind = vod || portalPlatform == null
        ? null
        : iptvLiveSourceKindForPortal(portalPlatform);
    return IptvPtPlayerScreen(
      key: key,
      sources: [
        IptvPlaySource(
          url: url,
          label: portalName ?? 'Source 1',
          logoUrl: stream.icon.isEmpty ? null : stream.icon,
          streamId: stream.streamId,
          epgChannelId: stream.epgChannelId.isEmpty
              ? null
              : stream.epgChannelId,
          liveSourceKind: kind,
        ),
      ],
      title: stream.name,
      subtitle: portalName,
      logoUrl: stream.icon.isEmpty ? null : stream.icon,
      channelGuide: channelGuide,
      onChannelChanged: onChannelChanged,
      onStreamDead: onStreamDead,
      // Movies/Series share Settings → Movies; Live keeps IPTV.
      engineContext:
          engineContext ??
          (vod ? BuiltInPlayerContext.vod : BuiltInPlayerContext.iptv),
      forceBuiltInEngine: forceBuiltInEngine,
      vodPlayback: vod,
      onlineSubtitles: vod,
      subtitleSearchTitle: stream.name,
      liveSourceKind: kind,
    );
  }

  /// Convenience: build for a list of channel hits (multi-source).
  factory IptvPtPlayerScreen.fromHits({
    Key? key,
    required List<ChannelHit> hits,
    required String title,
    String? logoUrl,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.iptv,
  }) {
    final kinds = hits
        .map((h) => iptvLiveSourceKindForPortal(h.portal.portal.platform))
        .toList();
    return IptvPtPlayerScreen(
      key: key,
      title: title,
      logoUrl: logoUrl,
      engineContext: engineContext,
      liveSourceKind: kinds.isEmpty ? null : kinds.first,
      sources: [
        for (var i = 0; i < hits.length; i++)
          IptvPlaySource(
            url: hits[i].streamUrl,
            label: hits[i].portal.displayLabel,
            liveSourceKind: kinds[i],
          ),
      ],
    );
  }

  /// Root-navigator push — same full-window cover + Back slide as movies.
  /// Masks the shell underlay (no catalog peek during the slide) without
  /// Offstage/reflow of the rail.
  static Future<T?> open<T>(
    BuildContext context,
    IptvPtPlayerScreen player,
  ) async {
    final hostContext = context;
    ShellBus.maskShellUnderPlayer.value = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!hostContext.mounted) {
      ShellBus.clearMaskShellUnderPlayer();
      return null;
    }
    return Navigator.of(hostContext, rootNavigator: true).push<T>(
      AppRouter.slideRoute(
        (_) => ShellScope.rehost(hostContext, player),
        settings: const RouteSettings(name: 'iptv_player'),
      ),
    );
  }

  @override
  ConsumerState<IptvPtPlayerScreen> createState() => _IptvPtPlayerScreenState();
}

class _IptvPtPlayerScreenState extends ConsumerState<IptvPtPlayerScreen>
    with
        WidgetsBindingObserver,
        _IptvPtPlayerEngineCore,
        _IptvPtPlayerMkTunables,
        _IptvPtPlayerLiveProxy,
        _IptvPtPlayerWatchdog,
        _IptvPtPlayerRecovery,
        _IptvPtPlayerEngine,
        _IptvPtPlayerUi {
  static int _nextExoViewId = 1;

  /// When true, IPTV uses Media3 ExoPlayer; otherwise media_kit.
  /// Android reads [engineContext] prefs at boot / Player menu.
  bool _exoBackend = false;
  int? _exoViewId;
  StreamSubscription<Map<dynamic, dynamic>>? _exoEventSub;
  ExoAtvSurfaceFallback? _exoSurfaceFallback;

  Player? _player;
  VideoController? _controller;
  bool _playerReady = false;
  int _videoEpoch = 0;
  bool _softwareDecodeForced = false;

  /// Phone MediaKit: software decode (some MediaCodec paths flake).
  /// Android TV MediaKit: keep HW + [vo=mediacodec_embed] (Impeller OpenGLES).
  bool _androidMediaKitSafeMode = false;

  bool get _atvMediaKit =>
      !_exoBackend && !kIsWeb && Platform.isAndroid && PlatformInfo.isAndroidTv;

  /// Windows D3D11 / ANGLE + live IPTV: HW decode plays ~15–20s then sticks
  /// the last frame with no reconnect banner. Force software from boot.
  bool get _windowsSoftwareDecode => !kIsWeb && Platform.isWindows;

  /// macOS / Linux live: VideoToolbox / VAAPI one-shots after every CDN socket
  /// close and collapses playback. Software decode + continuity proxy.
  bool get _desktopLiveSoftwareDecode =>
      !widget.vodPlayback && !kIsWeb && (Platform.isMacOS || Platform.isLinux);

  /// Probed after each open - pure-live feeds must never be seek()'d.
  bool _streamSeekable = false;

  /// Live MediaKit: localhost TS relay so CDN socket closes never hit mpv.
  IptvLiveContinuityProxy? _liveContinuityProxy;

  StreamSubscription? _posSub, _playingSub, _bufferingSub, _errorSub, _logSub;
  StreamSubscription? _durSub, _bufferSub;

  // Seekbar: duration > 1s ⇒ VOD scrubber; live always shows EPG / live-edge bar.
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _isSeeking = false;
  double _seekPreview = 0.0;
  /// Catalog VOD, or live with a real DVR window — not mpv's ~2–6s HLS artifact.
  bool get _isVod {
    if (widget.vodPlayback) return _duration.inSeconds > 1;
    if (_duration.inSeconds <= 6) return false;
    return _duration.inSeconds > 1;
  }

  /// Live vs Movies/Series chrome (tracks / episodes / engine persist).
  IptvPlayerChromeProfile get _chrome =>
      IptvPlayerChromeProfile.fromVodPlayback(widget.vodPlayback);

  late List<IptvPlaySource> _sources;
  late String _title;
  String? _subtitle;
  String? _logoUrl;

  int _sourceIdx = 0;
  bool _playing = false;
  bool _buffering = false;
  bool _userPlayWhenReady = true;
  String? _statusBanner;

  /// Debounce live position ticks — see [_syncPlaybackBannerVisibility].
  bool? _playbackBannerSnapshot;

  /// Reconnect / switch messages always; raw "Buffering…" only when stalled.
  bool get _showPlaybackBanner {
    if (_statusBanner != null) return true;
    if (!_buffering) return false;
    return !_videoAdvancing;
  }

  /// Playhead or real frame pulse moved recently — picture not frozen.
  ///
  /// MediaKit live must not treat demuxer feed / healthy cache as painting —
  /// VO can freeze with ~30s cache while proxy keepalives still advance.
  bool get _videoAdvancing {
    if (!_playing) return false;
    return DateTime.now().difference(_lastPosChange) <
        const Duration(milliseconds: 1500);
  }

  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  final FocusNode _playerTvKeyFocus = FocusNode(debugLabel: 'player-tv-keys');
  final FocusNode _backFocus = FocusNode(debugLabel: 'iptv-player-back');
  final FocusNode _playFocus = FocusNode(debugLabel: 'iptv-player-play');
  final FocusNode _replayFocus = FocusNode(debugLabel: 'iptv-player-replay');
  final FocusNode _seekFocus = FocusNode(debugLabel: 'iptv-player-seek');

  /// Top-right Player menu (Exo ↔ MediaKit). Explicit FocusNode so D-pad →
  /// from Back can claim it — [FocusScope.focusInDirection] often fails across
  /// the wide title gap on Android TV (issue 110).
  final FocusNode _playerMenuFocus = FocusNode(debugLabel: 'iptv-player-menu');
  final FocusNode _statsFocus = FocusNode(debugLabel: 'iptv-player-stats');

  /// Bottom-row TV FocusNodes — explicit ←/→ like the top bar (Spacer gap
  /// breaks geometric [focusInDirection] on Android TV).
  final FocusNode _subtitleFocus = FocusNode(
    debugLabel: 'iptv-player-subtitles',
  );
  final FocusNode _audioFocus = FocusNode(debugLabel: 'iptv-player-audio');
  final FocusNode _episodesFocus = FocusNode(
    debugLabel: 'iptv-player-episodes',
  );
  final FocusNode _searchChromeFocus = FocusNode(
    debugLabel: 'iptv-player-search',
  );

  /// Playing series episode (updated when switching from the in-player panel).
  int? _playingSeason;
  int? _playingEpisode;
  final FocusNode _guideFocus = FocusNode(debugLabel: 'iptv-player-guide');
  final FocusNode _bottomSourceFocus = FocusNode(
    debugLabel: 'iptv-player-bottom-source',
  );

  bool _guideVisible = false;
  bool _searchVisible = false;

  /// First TV Back focused the Back control — next Back exits even before
  /// the post-frame [requestFocus] lands.
  bool _tvBackExitArmed = false;
  late String _selectedGroupId;
  late String _currentChannelId;
  IptvGuideEpgCache? _epgCache;

  /// Armed Forja Sports portal — Stalker create_link without channelGuide.
  VerifiedPortal? _sportsPortal;

  // Watchdog state
  Timer? _watchdog;
  Duration _lastPos = Duration.zero;
  DateTime _lastPosChange = DateTime.now();
  DateTime? _bufferingSince;

  /// Stall-reopen mode: when buffering flickers false, wait this long before
  /// clearing [_bufferingSince] so detector 1's grace is not reset by core-idle.
  DateTime? _bufferingClearAt;
  DateTime? _readyNotPlayingSince;
  // When the current source was last opened. Used by detector 4 to find
  // "playing=true but never produced a first frame" - the classic
  // CDN-dropped-mid-handshake hang where mpv neither buffers nor errors.
  DateTime _openedAt = DateTime.now();

  // Audio state — desktop/phone chrome has mute + hover slider; TV uses
  // hardware volume keys only (no volume button in the transport row).
  double _volume = 100.0; // 0..100 (mpv scale)
  double _volumeBeforeMute = 100.0;
  bool _muted = false;
  bool _showVolumeSlider = false;
  bool _volumeHovering = false;
  Timer? _hideVolumeTimer;

  // Tracks — MediaKit only (same menus as the home movies player).
  bool _isNativeSubtitle = false;
  double _subtitleDelay = 0.0;
  double _subtitleSize = 44.0;
  double _subtitleBottomPadding = 24.0;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0.67;
  bool _subtitleBold = false;
  String _subtitleFont = 'Default';

  List<Map<String, dynamic>> _externalSubtitles = [];
  String? _selectedExternalSubUrl;
  bool _isFetchingSubs = false;
  final Map<String, String> _externalSubFileCache = {};
  StreamSubscription<List<Map<String, dynamic>>>? _subtitleFetchSub;
  String _subQueryTitle = '';
  int? _subQueryYear;
  int? _subQuerySeason;
  int? _subQueryEpisode;

  // Fullscreen state (desktop only - mobile is permanently immersive)
  bool _isFullscreen = false;
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Desktop Escape ladder (parity with VOD [DesktopPlayerScreen]).
  bool _escapeExitArmed = false;
  DateTime? _escapeHandledAt;
  DateTime? _suppressChromeRevealUntil;

  // Picture-in-picture (same PipService as the movie player)
  bool _isPipMode = false;
  bool _pipHover = false;
  StreamSubscription<bool>? _pipSub;

  /// Paused because app left foreground — resume only if set (issue 134).
  bool _pausedByLifecycle = false;

  /// ATV: hide dead MediaCodec texture after veille while still paused (issue 182).
  bool _coverDeadSurface = false;

  // Retry state
  int _retryAttempt = 0;
  DateTime? _lastRecoveryAt;

  /// Bumped to cancel in-flight delayed live-edge snaps (recovery / reopen race).
  int _liveEdgeSnapEpoch = 0;

  /// Stalker: consecutive hard format/open fails after fresh create_link.
  int _stalkerHardFailCount = 0;

  /// One-shot Exo ↔ MediaKit swap after unrecognized-format errors.
  bool _formatEngineSwapped = false;
  // When the user explicitly paused (play-after-pause rejoins live edge).
  DateTime? _pausedAt;

  /// After [drop-buffers], VideoToolbox often logs a one-shot hw fail while
  /// re-initing — ignore those so we don't thrash into software decode.
  DateTime? _ignoreHwDecodeFailUntil;
  final List<int> _backoffMs = const [
    500,
    1000,
    2000,
    3000,
    4000,
    6000,
    8000,
    8000,
  ];
  static const int _maxRetries = 8;
  static const Duration _healthyStreakNeeded = Duration(seconds: 6);
  // After exhausting per-source retries on a single-source stream, keep
  // probing every N seconds forever - live IPTV channels routinely come
  // back from short outages, so we don't want to give up.
  static const Duration _coldRetryInterval = Duration(seconds: 15);

  /// How long a manual reload's live-edge flush gets to restore frames before
  /// escalating to a real reopen. Covers the flush's own 700ms delay.
  static const Duration _reloadEscalateAfter = Duration(seconds: 3);

  /// Seconds of demuxer/buffer ahead of the playhead. Updated every watchdog
  /// tick (MediaKit) or from Exo progress. The recovery gate: if this is above
  /// [_minHealthyCacheSecs], the stream is working — do not reopen.
  double _cacheAheadSecs = 0;

  /// Last observed buffered-end mark in ms (Exo / mpv buffer stream).
  int? _feedMarkMs;

  /// When [_feedMarkMs] last moved — socket still delivering.
  DateTime? _feedAdvancedAt;

  bool _cacheProbeInFlight = false;

  /// Debug-only UHD telemetry timer (issue 150).
  Timer? _uhdDiag;

  /// One display-mode switch per MediaKit open (issue 150 — 50 fps on 60 Hz).
  bool _displayFrameRateApplied = false;

  /// Have at least this much cache ⇒ stream is healthy, never auto-recover.
  static const double _minHealthyCacheSecs = 2.0;

  /// Continuous Buffering + frozen playhead + **empty** cache this long ⇒ dead.
  /// Must not trip while demuxer still has a healthy ahead cushion.
  static const Duration _bufferingHardWallDuration = Duration(seconds: 12);

  /// Ignore one-shot VideoToolbox / hw fails after socket blip or live-edge snap.
  static const Duration _transientHwDecodeIgnore = Duration(seconds: 8);

  /// Soft reopen when live stays paused with empty cache this long.
  static const Duration _liveEmptyPauseReopen = Duration(seconds: 5);

  /// Tunables ask for ~30 s readahead. Anything far above that is almost
  /// always a live PTS discontinuity (mpv reports multi-hour "cache"), not
  /// real buffered media — reject for the Stable recovery gate.
  static const double _maxSaneCacheAheadSecs = 90.0;

  /// Feed mark moved within this window ⇒ still downloading.
  static const Duration _networkAliveWindow = Duration(seconds: 3);

  /// How long ffmpeg gets on VOD before app escalates (live uses cache gate).
  static const Duration _ffmpegReconnectGrace = Duration(seconds: 8);

  /// Stall-reopen: require continuous non-buffering this long before resetting
  /// [_bufferingSince] (media_kit `core-idle` flicker).
  static const Duration _bufferingClearHold = Duration(milliseconds: 1500);

  bool _socketTroublePending = false;

  /// Settings raw mode ([SettingsService.iptvLiveRecoveryAuto] default).
  /// Watchdog uses [_liveRecoveryMode] after Auto resolve.
  String _liveRecoveryModeSetting = SettingsService.iptvLiveRecoveryAuto;

  /// Effective recovery policy for this open (Auto → buffered, etc.).
  String _liveRecoveryMode = SettingsService.iptvLiveRecoveryBuffered;

  void _applyLiveRecoveryModeForCurrentSource({IptvPlaySource? src}) {
    final active = src ??
        (_sources.isEmpty
            ? null
            : _sources[_sourceIdx.clamp(0, _sources.length - 1)]);
    final kind = active?.liveSourceKind ?? widget.liveSourceKind;
    _liveRecoveryMode = SettingsService.resolveIptvLiveRecoveryMode(
      _liveRecoveryModeSetting,
      liveSourceKind: kind?.name,
    );
    debugPrint(
      '[IPTV Player] live recovery kind=${kind?.name ?? "null"} '
      'setting=$_liveRecoveryModeSetting effective=$_liveRecoveryMode',
    );
  }

  /// Last decoded height / bitrate — cache tiers and proxy queue (ATV live).
  int _lastVideoHeight = 0;
  int _lastVideoBitrate = 0;
  bool _liveCacheTierApplied = false;

  /// Paint stall detection (MediaKit live — I199 / perf plan).
  int _livePaintMissStreak = 0;
  bool _voFreezeSnapAttempted = false;
  DateTime? _lastDemuxerSampleAt;
  int _stallFrameDropBaseline = -1;
  DateTime? _stallPaintWatchSince;

  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  /// ATV MediaKit live uses a smaller Player buffer — demuxer owns readahead.
  PlayerConfiguration get _mediaKitPlayerConfiguration {
    if (_atvMediaKit && !widget.vodPlayback) {
      return const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
        libass: true,
      );
    }
    return _playerConfiguration;
  }

  static bool _isBenignMpvError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('cannot seek') ||
        lower.contains('force-seekable') ||
        lower.contains("expected '=' and a value");
  }

  bool _disposed = false;
  bool _playerAlive = false;

  /// Instant mute/pause before route pop (mirrors VOD [_stopPlaybackForExit]).
  bool _playbackStopped = false;

  /// Prevents double pop from Back button + remote Back gate.
  bool _exitInProgress = false;

  static const _playerConfiguration = PlayerConfiguration(
    bufferSize: 64 * 1024 * 1024,
    logLevel: MPVLogLevel.warn,
    libass: true,
  );

  static String _fmtDur(Duration d) {
    final s = d.inSeconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  @override
  void initState() {
    super.initState();
    // Cover catalog/rail under the opaque route (set again from [open] before
    // push so the first slide frame is already masked).
    ShellBus.maskShellUnderPlayer.value = true;
    ShellBus.enterPlayerSurface();
    PlayerBackExitGate.setTryFocusBack(() {
      if (_disposed || !mounted) return false;
      if (_isPipMode) return false;
      // Menus (Stream stats, Player, …) own Back before the exit ladder.
      if (dismissAnyPlayerChromeOverlay()) {
        _tvBackExitArmed = false;
        return true;
      }
      // Guide owns Back first (HardwareKeyboard steals Focus onKey).
      // Search is handled by [setTryConsumePlayerOverlay] (results → field →
      // close) before this ladder runs.
      if (_guideVisible) {
        setState(() {
          _guideVisible = false;
          _controlsVisible = true;
        });
        _tvBackExitArmed = false;
        _hideControlsTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed || !mounted) return;
          _claimPlayFocus();
        });
        return true;
      }
      final stay = PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: _controlsVisible,
        armed: _tvBackExitArmed,
        hideChrome: () {
          _hideControlsTimer?.cancel();
          setState(() => _controlsVisible = false);
        },
        setArmed: (v) => _tvBackExitArmed = v,
      );
      return stay;
    });
    PlayerBackExitGate.setTryConsumePlayerOverlay(() {
      if (_disposed || !mounted || _isPipMode) return false;
      if (!_searchVisible) return false;
      // Results list → search field (HardwareKeyboard steals Focus onKey).
      if (IptvChannelSearchOverlay.tryConsumeBackToField()) {
        _tvBackExitArmed = false;
        return true;
      }
      // Field (or empty results) → close overlay; stay in player.
      setState(() {
        _searchVisible = false;
        _controlsVisible = true;
      });
      _tvBackExitArmed = false;
      _hideControlsTimer?.cancel();
      _scheduleHideControls();
      return true;
    });
    _sources = List<IptvPlaySource>.from(widget.sources);
    if (widget.titleTracksSource && widget.sources.isNotEmpty) {
      _title = widget.title;
      _subtitle = widget.sources.first.pickerTitle;
    } else {
      _title = widget.title;
      _subtitle = widget.subtitle;
    }
    _logoUrl = widget.logoUrl;
    _playingSeason = widget.subtitleSeason;
    _playingEpisode = widget.subtitleEpisode;
    _seedSubtitleQuery();
    final guide = widget.channelGuide;
    _selectedGroupId = guide?.initialGroupId ?? '';
    _currentChannelId = guide?.initialChannelId ?? '';
    final portal = guide?.xtreamPortal;
    if (portal != null) {
      _epgCache = IptvGuideEpgCache(portal);
    } else if (widget.titleTracksSource &&
        (widget.liveSourceKind == IptvLiveSourceKind.iptvXtream ||
            widget.liveSourceKind == IptvLiveSourceKind.iptvStalker)) {
      unawaited(_initSportsEpgCache());
    }
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onRemoteControlsActivity);
    if (_windowsSoftwareDecode || _desktopLiveSoftwareDecode) {
      _softwareDecodeForced = true;
    }
    _initOrientationAndChrome();
    WakelockPlus.enable();
    void onPipChanged(bool inPip) {
      if (_disposed || !mounted) return;
      setState(() {
        _isPipMode = inPip;
        if (inPip) {
          _controlsVisible = false;
          _guideVisible = false;
          _searchVisible = false;
          _hideControlsTimer?.cancel();
          _pausedByLifecycle = false;
        }
      });
      if (inPip && !_playing) {
        _userPlayWhenReady = true;
        unawaited(_enginePlay());
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      _pipSub = PipService.instance.androidPipChanges.listen(onPipChanged);
    } else if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      _pipSub = PipService.instance.desktopPipChanges.listen(onPipChanged);
      PipService.instance.bindAutoEnterOnDesktopSwitch(
        token: this,
        shouldEnter: () =>
            !_disposed && mounted && (_playing || _pausedByLifecycle),
      );
    }
    // Same as VOD: [waitForRouteTransition] uses ModalRoute.of — illegal in
    // initState. Defer until after the first frame so the modal scope exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      unawaited(_bootWithCachedVolume());
    });
  }

  /// Space / remote play-pause. Clears [_userPlayWhenReady] so the live
  /// watchdog does not microtask-resume after pause.
  Future<void> _togglePlayPauseFromKey() async {
    if (_playing) {
      _userPlayWhenReady = false;
      _pausedAt = DateTime.now();
      await _enginePause();
    } else {
      _userPlayWhenReady = true;
      final pausedAt = _pausedAt;
      _pausedAt = null;
      await _enginePlay();
      if (pausedAt != null &&
          _chrome == IptvPlayerChromeProfile.live &&
          iptvExoUrlLooksLive(
            _sources.isEmpty ? '' : _sources[_sourceIdx].url,
          ) &&
          DateTime.now().difference(pausedAt) >= const Duration(seconds: 2)) {
        _scheduleJumpToLive(force: true);
      }
    }
  }

  /// D-pad / remote keys while chrome is up count as activity. Row focus
  /// handlers often return [KeyEventResult.handled], so [PlayerTvKeyScope]
  /// alone never sees them - without this, controls hide mid-navigation.
  ///
  /// Desktop also handles Space / Escape here — [PlayerTvKeyScope] is TV-only.
  bool _onRemoteControlsActivity(KeyEvent event) {
    if (_disposed || !mounted) return false;

    // Desktop: Space toggles play/pause without revealing chrome.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !iptvUseTvFocus(context)) {
      if (_guideVisible || _searchVisible || _isPipMode) return false;
      if (playerChromeOverlayBlocksFocusClaim()) return false;
      unawaited(_togglePlayPauseFromKey());
      return true;
    }

    // Desktop Escape: same hide → leave-fullscreen → arm → leave ladder as VOD.
    // Live sports also uses this player.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _isDesktop) {
      if (_isPipMode) return false;
      _handleEscapeKey();
      return true;
    }

    if (!shellTvIsNavigationKey(event)) return false;
    if (!_controlsVisible || _guideVisible || _searchVisible || _isPipMode) {
      return false;
    }
    _scheduleHideControls();
    return false;
  }

  /// Boot prefs: engine from [widget.engineContext] KV; volume/EPG from
  /// [iptvPlayerBootPrefsProvider].
  Future<void> _bootWithCachedVolume() async {
    // Same contract as VOD [waitForRouteTransition]: do not open Exo/MediaKit
    // while a shell slide is still compositing (jank on weak Android 7 TVs).
    // On ATV slides are Duration.zero — this returns immediately.
    await waitForRouteTransition(context);
    if (_disposed || !mounted) return;
    // Live Matches Streamed keeps an embed WebView under this route for CDN
    // proxy fetches — that platform view steals leanback keys unless blocked.
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
      if (_disposed || !mounted) return;
    }
    final prefs = await ref.read(iptvPlayerBootPrefsProvider.future);
    if (_disposed || !mounted) return;
    final forced = widget.forceBuiltInEngine;
    if (forced != null && !kIsWeb && Platform.isAndroid) {
      _exoBackend = forced == BuiltInPlayerEngine.exoPlayer;
    } else if (!kIsWeb && Platform.isAndroid) {
      final engine = await SettingsService().getBuiltInPlayerEngine(
        context: widget.engineContext,
      );
      if (_disposed || !mounted) return;
      // Honor per-surface pref (Movies → vod, Live IPTV → iptv).
      _exoBackend = engine == BuiltInPlayerEngine.exoPlayer;
    } else {
      _exoBackend = false;
    }
    // Phone MediaKit: software-friendly. ATV MediaKit: HW + mediacodec_embed.
    _androidMediaKitSafeMode =
        !_exoBackend &&
        !kIsWeb &&
        Platform.isAndroid &&
        !PlatformInfo.isAndroidTv;
    _volume = prefs.volume;
    _volumeBeforeMute = prefs.volume > 0 ? prefs.volume : 100.0;
    _muted = prefs.volume == 0;
    _liveRecoveryModeSetting = prefs.liveRecoveryMode;
    _applyLiveRecoveryModeForCurrentSource();
    try {
      final subPrefs = await ref.read(playerSubtitlePrefsProvider(true).future);
      if (!_disposed && mounted) {
        _subtitleSize = subPrefs.size;
        _subtitleColor = Color(subPrefs.colorArgb);
        _subtitleBgOpacity = subPrefs.bgOpacity;
        _subtitleBold = subPrefs.bold;
        _subtitleBottomPadding = subPrefs.bottomPadding;
        _subtitleFont = subPrefs.font;
      }
    } catch (_) {}
    if (_exoBackend) {
      await _bootExoPlayer();
      if (!_disposed && mounted && widget.onlineSubtitles) {
        _fetchOnlineSubtitles();
      }
    } else {
      await _bootPlayer();
      if (!_disposed && mounted && widget.onlineSubtitles) {
        _fetchOnlineSubtitles();
      }
    }
  }

  void _seedSubtitleQuery() {
    if (!widget.onlineSubtitles) return;
    final raw = (widget.subtitleSearchTitle ?? widget.title).trim();
    final cleaned = cleanIptvMediaTitle(raw);
    _subQueryTitle = cleaned.title.isNotEmpty ? cleaned.title : raw;
    _subQueryYear = widget.subtitleYear ?? cleaned.year;
    _subQuerySeason = widget.subtitleSeason ?? cleaned.season;
    _subQueryEpisode = widget.subtitleEpisode ?? cleaned.episode;
  }

  /// Hot-swap Exo ↔ MediaKit from the in-player Player menu (Android).
  /// Set [persist] false for one-shot recovery so IPTV Settings stay unchanged.
  ///
  /// Matches VOD [PlayerScreen] switch: full surface unmount → release without
  /// blocking the UI isolate on MediaKit stop+dispose → cool-down → boot.
  /// Both directions then await [MpvExclusiveSession.prepareForVideoPlayer] —
  /// unbounded for MediaKit, capped at 1.2s for Exo so the MediaCodec detach is
  /// done without crossing the ATV input-ANR window (issue 128).
  Future<void> _switchBuiltInEngine(
    BuiltInPlayerEngine engine, {
    bool persist = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final wantExo = engine == BuiltInPlayerEngine.exoPlayer;
    if (persist) {
      await SettingsService().setBuiltInPlayerEngine(
        engine,
        context: widget.engineContext,
      );
    }
    if (_disposed || !mounted) return;
    if (wantExo == _exoBackend) return;

    if (mounted) {
      setState(() {
        _playerReady = false;
        _statusBanner = 'Switching player…';
      });
    }
    // Let Video / ExoPlayerView unmount before tearing down the engine.
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || !mounted) return;

    await _releaseEngineForHotSwap();
    if (_disposed || !mounted) return;

    // mediacodec_embed / Exo surface need a beat after unmount (issues 128/129).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_disposed || !mounted) return;

    if (wantExo) {
      // Exo does not share the mpv handle, but ATV MediaCodec is shared: Exo
      // mounting over a live mediacodec_embed surface plays audio with a black
      // picture (issue 129 / 133). Capped at 1.2s like the VOD switch so the
      // wait cannot cross the ATV input-ANR window (issue 128).
      await MpvExclusiveSession.instance.prepareForVideoPlayer(
        timeout: const Duration(milliseconds: 1200),
      );
      if (_disposed || !mounted) return;
    } else {
      await MpvExclusiveSession.instance.prepareForVideoPlayer();
      if (_disposed || !mounted) return;
    }

    _exoBackend = wantExo;
    _androidMediaKitSafeMode = !_exoBackend && !PlatformInfo.isAndroidTv;
    _softwareDecodeForced =
        _windowsSoftwareDecode || _desktopLiveSoftwareDecode;
    _player = null;
    _controller = null;
    _exoViewId = null;
    _retryAttempt = 0;
    _playbackStopped = false;

    if (_exoBackend) {
      await _bootExoPlayer();
    } else {
      await _bootPlayer();
    }
    if (mounted) setState(() => _statusBanner = null);
  }

  /// Instant mute/pause (native mpv props) — do not await hung stop before pop.
  Future<void> _stopPlaybackForExit() async {
    if (_playbackStopped) return;
    _playbackStopped = true;
    if (_exoBackend) {
      final id = _exoViewId;
      if (id != null) {
        try {
          await ExoPlayerBridge.pause(id);
        } catch (_) {}
      }
      return;
    }
    final player = _player;
    if (player == null) return;
    await silenceMediaKitPlayer(player);
  }

  /// Silence + unmount the video surface, then pop. Matches VOD exit so
  /// MediaKit/MediaCodec teardown is not on the Navigator.pop critical path.
  Future<void> _exitIptvPlayer() async {
    if (_disposed || _exitInProgress) return;
    if (ShellTvFocusCoordinator.consumeOverlayBack()) {
      _tvBackExitArmed = false;
      PlayerBackExitGate.exitReady = false;
      return;
    }
    _exitInProgress = true;
    final nav = Navigator.of(context, rootNavigator: true);
    await _stopPlaybackForExit();
    if (!mounted || _disposed) return;
    // Android: unmount MediaCodec before pop (ANR). Desktop keeps the
    // surface so the slide does not flash the underlay mid-transition.
    if (!kIsWeb && Platform.isAndroid && _playerReady) {
      setState(() => _playerReady = false);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || _disposed) return;
    if (nav.canPop()) {
      nav.pop();
    }
  }

  static bool _isUnrecognizedFormatError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('failed to recognize file format') ||
        lower.contains('unrecognizedinputformat') ||
        lower.contains('none of the available extractors') ||
        (lower.contains('source error') && lower.contains('m3u8'));
  }

  /// After format / hard-open errors, try the other Android engine once.
  /// Live never auto-swaps — only the Player menu (or VOD hard-open) may.
  Future<void> _autoSwapEngineForFormatError(String reason) async {
    if (_disposed || _formatEngineSwapped || kIsWeb || !Platform.isAndroid) {
      return;
    }
    if (!widget.vodPlayback) {
      debugPrint('[IPTV] skip format auto-swap on live ($reason)');
      return;
    }
    _formatEngineSwapped = true;
    final next = _exoBackend
        ? BuiltInPlayerEngine.mediaKit
        : BuiltInPlayerEngine.exoPlayer;
    debugPrint('[IPTV] format error → auto-swap to $next ($reason)');
    if (mounted) {
      setState(() => _statusBanner = 'Trying ${next.displayName}…');
    }
    await _switchBuiltInEngine(next, persist: false);
  }

  /// Apply volume to the engine and persist for the next IPTV player open.
  void _setCachedVolume(double volume) {
    final v = volume.clamp(0.0, 100.0);
    _volume = v;
    _muted = v == 0;
    if (v > 0) _volumeBeforeMute = v;
    _engineSetVolume(v);
    unawaited(IptvStore.savePlayerVolume(v));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pauseForAppBackground();
    } else if (state == AppLifecycleState.inactive) {
      if (!_disposed &&
          !_isPipMode &&
          !PipService.instance.isDesktopActive &&
          !PipService.instance.autoPipArmed &&
          !SettingsService.keepsPlayingInBackground &&
          _playing) {
        _pausedByLifecycle = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      _armDeadSurfaceCoverIfNeeded();
      _resumeAfterAppBackground();
    }
  }

  void _pauseForAppBackground() {
    if (_disposed || _isPipMode || PipService.instance.isDesktopActive) {
      return;
    }
    if (PipService.instance.autoPipArmed && (_playing || _pausedByLifecycle)) {
      unawaited(PipService.instance.enterInsteadOfPause());
      return;
    }
    if (SettingsService.keepsPlayingInBackground) return;
    // Live may report !_playing while buffering — still stop decode/audio.
    if (_playing || _userPlayWhenReady) {
      _pausedByLifecycle = true;
      _userPlayWhenReady = false;
      unawaited(_enginePause());
    }
  }

  void _resumeAfterAppBackground() {
    if (_disposed || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    if (_isPipMode || PipService.instance.isDesktopActive) return;
    _userPlayWhenReady = true;
    unawaited(_enginePlay());
  }

  /// Veille kills TextureView / mediacodec_embed; paused decode leaves green YUV.
  void _armDeadSurfaceCoverIfNeeded() {
    if (_disposed ||
        !PlatformInfo.isAndroidTv ||
        _pausedByLifecycle ||
        _playing) {
      return;
    }
    if (_coverDeadSurface) return;
    setState(() => _coverDeadSurface = true);
  }

  void _clearDeadSurfaceCover() {
    if (!_coverDeadSurface) return;
    if (mounted) {
      setState(() => _coverDeadSurface = false);
    } else {
      _coverDeadSurface = false;
    }
  }

  /// Forja Sports: resolve the armed Xtream/Stalker portal for in-player short EPG.
  Future<void> _initSportsEpgCache() async {
    final config = await LiveMatchesIptvSportsConfig.load();
    final armed = await config.resolveForFetch();
    if (armed == null || _disposed || !mounted) return;
    final portals = await IptvStore.load();
    VerifiedPortal? portal;
    for (final p in portals) {
      if (p.key == armed.portalKey) {
        portal = p;
        break;
      }
    }
    if (portal == null || _disposed || !mounted) return;
    _sportsPortal = portal;
    if (!portal.portal.platform.supportsEpg) return;
    setState(() => _epgCache = IptvGuideEpgCache(portal!));
  }

  /// Channel guide id or active sports source stream id — keys floating EPG.
  String get _floatingEpgKey {
    if (_currentChannelId.isNotEmpty) return _currentChannelId;
    if (_sources.isEmpty) return '';
    final id =
        (_sources[_sourceIdx.clamp(0, _sources.length - 1)].streamId ?? '')
            .trim();
    return id;
  }

  IptvStream? _epgStreamForActiveSource() {
    if (_sources.isEmpty) return null;
    final src = _sources[_sourceIdx.clamp(0, _sources.length - 1)];
    final streamId = (src.streamId ?? '').trim();
    if (streamId.isEmpty) return null;
    return IptvStream(
      streamId: streamId,
      name: src.chromeTitle,
      icon: src.logoUrl ?? '',
      categoryId: '',
      containerExt: 'ts',
      kind: 'live',
      epgChannelId: (src.epgChannelId ?? '').trim(),
    );
  }

  /// My IPTV sports: chrome subtitle = active channel; title stays the match.
  void _syncTitleToActiveSource() {
    if (!widget.titleTracksSource || _sources.isEmpty) return;
    final i = _sourceIdx.clamp(0, _sources.length - 1);
    _subtitle = _sources[i].pickerTitle;
  }

  @override
  void dispose() {
    PlayerBackExitGate.setTryFocusBack(null);
    PlayerBackExitGate.setTryConsumePlayerOverlay(null);
    ShellBus.leavePlayerSurface();
    ShellBus.clearMaskShellUnderPlayer();
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onRemoteControlsActivity);
    _backFocus.dispose();
    _playFocus.dispose();
    _replayFocus.dispose();
    _playerMenuFocus.dispose();
    _statsFocus.dispose();
    _subtitleFocus.dispose();
    _audioFocus.dispose();
    _episodesFocus.dispose();
    _searchChromeFocus.dispose();
    _guideFocus.dispose();
    _bottomSourceFocus.dispose();
    _pipSub?.cancel();
    PipService.instance.unbindAutoEnterOnDesktopSwitch(this);
    _watchdog?.cancel();
    _uhdDiag?.cancel();
    unawaited(PlatformChannel.clearDisplayFrameRate());
    _displayFrameRateApplied = false;
    _hideControlsTimer?.cancel();
    _hideVolumeTimer?.cancel();
    _subtitleFetchSub?.cancel();
    _playerTvKeyFocus.dispose();
    _seekFocus.dispose();
    unawaited(_finalizeExit());
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_isDesktop) {
      // Exit host fullscreen only — never unmaximize (issue 196 / Windows
      // restore-frame reset). PiP leave still restores its own saved bounds.
      Future.microtask(() async {
        try {
          if (PipService.instance.isDesktopActive) {
            await PipService.instance.leave();
          }
          await DesktopWindowGeometry.leavePlayerChrome();
        } catch (_) {}
      });
    }
    super.dispose();
  }
}
