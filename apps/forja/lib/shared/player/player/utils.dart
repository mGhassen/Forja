import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
export 'package:forja/shared/playback/playback_stream_guards.dart'
    show
        catalogStreamRowMatchesPlaying,
        durableStreamCatalogUrl,
        hlsProxyTargetUrl,
        isVideasyCdnStreamUrl,
        playbackUrlsEquivalent,
        streamSourceMatchesPlaying;
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/playback/stream_open_pipeline.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';

/// Browser-like UA so CDNs that reject bare `libmpv` still serve the file.
const kDefaultStreamUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

/// Soft Auto ceiling (~1080p mid-high) — faster first frame than `max`.
const kHlsBitrateAutoSoftCeiling = '5000000';
const kExoBitrateAutoSoftCeiling = 5_000_000;

/// Prefer catalog/master URL for the quality menu when play opened a media playlist.
String catalogUrlForHlsQualities({
  String? catalogUrl,
  required String sourceUrl,
  required String playUrl,
}) {
  final catalog = (catalogUrl ?? '').trim();
  if (catalog.toLowerCase().contains('.m3u8')) return catalog;
  if (sourceUrl.toLowerCase().contains('.m3u8')) return sourceUrl;
  return playUrl;
}

/// Softvol gain applied to Android TV MediaKit so it matches ExoPlayer loudness
/// (issue 152).
///
/// mpv decodes to PCM and pushes it straight at `ao=audiotrack`, while Exo goes
/// through MediaCodec and the TV's media DSP (dialog lift / stream DRC), and
/// mpv's software 5.1→stereo downmix attenuates more than Exo's. At the same UI
/// level MediaKit therefore lands audibly quieter on leanback. ~+2.3 dB is a
/// deliberate compromise: enough to stop the engine swap feeling broken,
/// small enough that boosted peaks rarely clip (softvol has no limiter).
///
/// Requires mpv `volume-max` ≥ gain × the surface's UI max.
const double kAtvMediaKitVolumeGain = 1.3;

/// mpv `volume` for a UI level. TV MediaKit gets [kAtvMediaKitVolumeGain].
double mpvVolumeForUi(double uiVolume, {required bool atvMediaKit}) =>
    atvMediaKit ? uiVolume * kAtvMediaKitVolumeGain : uiVolume;

/// mpv `hls-bitrate` from Settings → Max stream quality (`0` = Auto).
String hlsBitrateForMaxPlaybackHeight(int maxHeight) {
  if (maxHeight <= 0) return kHlsBitrateAutoSoftCeiling;
  if (maxHeight <= 480) return '1500000';
  if (maxHeight <= 720) return '3500000';
  if (maxHeight <= 1080) return '8000000';
  if (maxHeight <= 1440) return '12000000';
  return 'max';
}

/// Exo ABR caps from Settings → Max stream quality (`0` = Auto soft bitrate).
({int maxVideoHeight, int maxVideoBitrate}) exoVodCapsForMaxPlaybackHeight(
  int maxHeight,
) {
  if (maxHeight <= 0) {
    return (maxVideoHeight: 0, maxVideoBitrate: kExoBitrateAutoSoftCeiling);
  }
  if (maxHeight <= 480) {
    return (maxVideoHeight: 480, maxVideoBitrate: 1_500_000);
  }
  if (maxHeight <= 720) {
    return (maxVideoHeight: 720, maxVideoBitrate: 3_500_000);
  }
  if (maxHeight <= 1080) {
    return (maxVideoHeight: 1080, maxVideoBitrate: 8_000_000);
  }
  if (maxHeight <= 1440) {
    return (maxVideoHeight: 1440, maxVideoBitrate: 12_000_000);
  }
  return (maxVideoHeight: 2160, maxVideoBitrate: 0);
}

final _trailingMediaSlash = RegExp(
  r'\.(mp4|mkv|webm|avi|mov|m4v|ts|mpd|m3u8)/+$',
  caseSensitive: false,
);

/// Strip CDN junk like `…/file.mp4/` that browsers forgive and demuxers reject.
///
/// Peakstorm / Videasy HLS often resolves to demuxed `index-s1080p-v1-a1.m3u8`
/// child playlists — seek stalls on those; open sibling `master.m3u8` instead
/// (extract-time rewrite can miss cached rows).
///
/// When [preserveHlsVariant] is true (manual Quality pick / locked remount),
/// keep the demuxed variant URL — rewriting to master drops the quality lock.
String normalizePlaybackStreamUrl(
  String url, {
  bool preserveHlsVariant = false,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  var out = trimmed;
  if (_trailingMediaSlash.hasMatch(out)) {
    out = out.replaceFirst(RegExp(r'/+$'), '');
  }
  if (!preserveHlsVariant && isVideasyCdnStreamUrl(out)) {
    out = VideasyExtractor.preferHlsMasterUrl(out);
  }
  return out;
}

/// Play URL for [source] — peakstorm child playlists → master.m3u8.
StreamSource normalizeStreamSourcePlayUrl(StreamSource source) {
  final raw = source.url.trim();
  final play = normalizePlaybackStreamUrl(raw);
  if (play == raw) return source;
  final catalog = source.catalogUrl?.trim();
  return source.copyWith(
    url: play,
    catalogUrl: (catalog != null && catalog.isNotEmpty) ? catalog : raw,
  );
}

List<StreamSource> normalizeStreamSourcesPlayUrls(List<StreamSource> sources) =>
    sources.map(normalizeStreamSourcePlayUrl).toList();

/// Headers for every network open: extractor headers + guaranteed browser UA.
///
/// Prefer [providerId] (RFC-044) over CDN hostname matching. Do **not**
/// comma-join into mpv `http-header-fields` - UA values contain commas
/// (`KHTML, like Gecko`) and that corrupts the list. Pass the map to
/// [Media.httpHeaders] so media_kit sets a proper NODE_ARRAY on load.
Map<String, String> resolvePlaybackHttpHeaders(
  Map<String, String>? headers, {
  String? streamUrl,
  String? providerId,
}) {
  final out = <String, String>{};
  if (headers != null) {
    for (final e in headers.entries) {
      final k = e.key.trim();
      final v = e.value.trim();
      if (k.isEmpty || v.isEmpty) continue;
      out[k] = v;
    }
  }

  String? take(String a, String b) => out[a] ?? out[b];
  void putCanonical(String canonical, String alt, String value) {
    out.remove(alt);
    out[canonical] = value;
  }

  final ua = take('User-Agent', 'user-agent');
  putCanonical(
    'User-Agent',
    'user-agent',
    (ua != null && ua.isNotEmpty) ? ua : kDefaultStreamUserAgent,
  );

  final cfg = ProviderRuntimeConfig.instance;
  final pid = providerId?.trim();
  final catalogForMatchEarly = streamUrl != null && isLocalLoopbackPlayUrl(streamUrl)
      ? (hlsProxyTargetUrl(streamUrl) ?? streamUrl)
      : streamUrl;
  // VidSrc.sbs nested STREAMCRYPTO mirrors land on Videasy CDNs (peakstorm).
  // Those rows keep vidsrcsbs / engine:vidsrcsbs identity but must open with
  // player.videasy.to Referer — vidsrc.sbs gets 403 on the CDN.
  var policy = cfg.playbackPolicyFor(pid);
  if (catalogForMatchEarly != null &&
      isVideasyCdnStreamUrl(catalogForMatchEarly)) {
    policy = cfg.playbackPolicyFor('videasy') ?? policy;
  }
  final banSelf = cfg.bansCdnSelfReferer(pid);
  // Movie/TV VidNest CDNs (lamda/delta/alfa/…) reject forced vidnest.fun
  // Referer; web uses no-referrer. Keep extractor/API headers only — do not
  // invent policy Referer. Anime `vidnest:*` still uses policy below.
  final pidLower = pid?.toLowerCase() ?? '';
  final vidnestMovieTv =
      pidLower == 'vidnest' || pidLower == 'engine:vidnest';
  final catalogForMatch = catalogForMatchEarly;

  final referer = take('Referer', 'referer');
  if (referer != null && referer.isNotEmpty) {
    putCanonical('Referer', 'referer', referer);
  } else if (policy != null && !vidnestMovieTv) {
    // RFC-044: recover from provider identity - never invent CDN self-Referer.
    putCanonical('Referer', 'referer', policy.referer);
    putCanonical('Origin', 'origin', policy.origin);
  } else if (!banSelf &&
      streamUrl != null &&
      streamUrl.isNotEmpty &&
      !isLocalTorrentStreamUrl(streamUrl) &&
      !isLocalLoopbackPlayUrl(streamUrl)) {
    final uri = Uri.tryParse(streamUrl);
    if (uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty) {
      putCanonical('Referer', 'referer', '${uri.origin}/');
    }
  }

  // Provider policy: force when missing, self-CDN, or scrape (enma) Referer.
  if (policy != null && !vidnestMovieTv) {
    final ref = take('Referer', 'referer') ?? '';
    final refHost = Uri.tryParse(ref)?.host.toLowerCase() ?? ref.toLowerCase();
    final streamHost =
        Uri.tryParse(catalogForMatch ?? '')?.host.toLowerCase() ?? '';
    final selfCdn =
        streamHost.isNotEmpty &&
        refHost.isNotEmpty &&
        (refHost == streamHost ||
            refHost.contains(streamHost) ||
            streamHost.contains(refHost));
    final scrapeLeak = refHost.contains('enma');
    final policyHost = Uri.tryParse(policy.referer)?.host.toLowerCase() ?? '';
    final familyOk = _refererMatchesPolicyFamily(refHost, policyHost);
    // Miruro pipes ship upstream embed Referers (kwik / animepahe / …).
    // Forcing miruro.tv (v1.2.406 regression) 403s owocdn segments.
    final miruroPipe = (pid ?? '').toLowerCase().startsWith('miruro:');
    final accepted =
        ref.isNotEmpty && !selfCdn && !scrapeLeak && (familyOk || miruroPipe);
    if (!accepted) {
      putCanonical('Referer', 'referer', policy.referer);
      putCanonical('Origin', 'origin', policy.origin);
    }
  }

  // Legacy KissKh CDN sniff - only when provider identity is unknown.
  if (policy == null && streamUrl != null && _isKissKhCdnStream(streamUrl)) {
    final ref = take('Referer', 'referer') ?? '';
    if (ref.isEmpty || _isKissKhCdnStream(ref) || !ref.contains('kisskh')) {
      putCanonical('Referer', 'referer', 'https://kisskh.co/');
      putCanonical('Origin', 'origin', 'https://kisskh.co');
    }
  }

  // Vidsrc CloudStream (`/pl/…/master.m3u8?token=`): master/variant 200 with
  // any headers, but leaf `page-N.html` segments return CF 403 when Referer or
  // Origin is set. Browser players use referrerpolicy=no-referrer - strip both
  // and never derive them from the stream host.
  if (streamUrl != null && _isVidsrcCloudStreamPl(streamUrl)) {
    out.remove('Referer');
    out.remove('referer');
    out.remove('Origin');
    out.remove('origin');
  }

  // VidNest MovieBox CDN (`*.hakunaymatata.com`): progressive MP4 returns HTTP
  // 429 whenever Referer is set (including self-origin). Browser JWPlayer uses
  // no-referrer - strip Referer/Origin and never derive them from the CDN host.
  // NetMirror direct (D3adly net27 embed) requires videodownloader.site Referer.
  if (streamUrl != null && _isVidnestMovieBoxCdn(streamUrl)) {
    final pidLower = pid?.toLowerCase() ?? '';
    final netmirror =
        pidLower == 'engine:netmirror' || pidLower == 'netmirror';
    if (!netmirror) {
      out.remove('Referer');
      out.remove('referer');
      out.remove('Origin');
      out.remove('origin');
    }
  }

  // Vidlink mwVault proxy URLs carry upstream headers in query — extra Referer
  // (e.g. derived from noon.mooncase.online) breaks the proxy open in mpv.
  if (streamUrl != null && isMwVaultProxyPlayUrl(streamUrl)) {
    out.remove('Referer');
    out.remove('referer');
    out.remove('Origin');
    out.remove('origin');
  }

  // Legacy CDN host rules - only when provider identity is unknown (RFC-044).
  if (policy == null && catalogForMatch != null) {
    for (final rule in cfg.cdnRefererRules) {
      if (!rule.matchesStreamUrl(catalogForMatch)) continue;
      final ref = take('Referer', 'referer') ?? '';
      if (ref.isEmpty || !rule.refererAccepted(ref)) {
        if (rule.referer.isNotEmpty) {
          putCanonical('Referer', 'referer', rule.referer);
        }
        if (rule.origin.isNotEmpty) {
          putCanonical('Origin', 'origin', rule.origin);
        }
      }
      break;
    }
  }

  final origin = take('Origin', 'origin');
  if (origin != null && origin.isNotEmpty) {
    putCanonical('Origin', 'origin', origin);
  } else {
    final ref = out['Referer'];
    if (ref != null) {
      final refUri = Uri.tryParse(ref);
      if (refUri != null && refUri.hasScheme && refUri.host.isNotEmpty) {
        putCanonical('Origin', 'origin', refUri.origin);
      }
    }
  }

  // YouTube googlevideo (ANDROID_VR direct URLs): CDN self-Referer / Origin → 403.
  if (streamUrl != null && isGooglevideoPlaybackUrl(streamUrl)) {
    out.remove('Referer');
    out.remove('referer');
    out.remove('Origin');
    out.remove('origin');
  }

  return out;
}

bool _isKissKhCdnStream(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  // cdnvideo*.shop (legacy) · streamingcdn*.site (current HLS) · kisskh hosts
  return host.contains('cdnvideo') ||
      host.contains('streamingcdn') ||
      host.contains('kisskh');
}

/// Accept any host in the same provider family as [policyHost].
bool _refererMatchesPolicyFamily(String refHost, String policyHost) {
  if (refHost.isEmpty || policyHost.isEmpty) return false;
  if (refHost.contains(policyHost) || policyHost.contains(refHost)) {
    return true;
  }
  if (policyHost.contains('megaplay') && refHost.contains('megaplay')) {
    return true;
  }
  if (policyHost.contains('vidwish') && refHost.contains('vidwish')) {
    return true;
  }
  if ((policyHost.contains('allmanga') || policyHost.contains('allanime')) &&
      (refHost.contains('allmanga') || refHost.contains('allanime'))) {
    return true;
  }
  if (policyHost.contains('kisskh') && refHost.contains('kisskh')) {
    return true;
  }
  return false;
}

/// Tokenized Vidsrc CloudStream playlist - segments reject Referer/Origin.
bool _isVidsrcCloudStreamPl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  final path = uri.path.toLowerCase();
  if (!path.contains('/pl/')) return false;
  if (!path.contains('.m3u8')) return false;
  return uri.queryParameters.containsKey('token');
}

/// VidNest Gama/MovieBox (and related) CDN - rejects any Referer with HTTP 429.
bool isMovieBoxCdnStreamUrl(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return host.contains('hakunaymatata.com');
}

bool _isVidnestMovieBoxCdn(String url) => isMovieBoxCdnStreamUrl(url);

/// YouTube videoplayback CDN — mpv must not send googlevideo self-Referer.
bool isGooglevideoPlaybackUrl(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  return host.contains('googlevideo.com');
}

/// Vidlink mwVault play URLs (mooncase mp / suubmon sacdn) embed upstream
/// headers in query params — mpv must not add Referer/Origin on top.
bool isMwVaultProxyPlayUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if (host.contains('mooncase.online') && path.startsWith('/mp/')) {
    return uri.queryParameters.containsKey('headers') &&
        uri.queryParameters.containsKey('host');
  }
  if (host.contains('suubmon.store') && path.startsWith('/sacdn/')) {
    return uri.queryParameters.containsKey('host');
  }
  return false;
}

/// Set mpv `user-agent` / `referrer` before `open`. Full header list goes on
/// [Media.httpHeaders] - never via comma-joined `http-header-fields`.
///
/// Pass [alreadyResolved]: true when [headers] came from
/// [resolvePlaybackHttpHeaders] (avoids dropping URL-derived Referer).
/// Clears stale `referrer` when the next source has none.
Future<void> applyMediaHttpHeaders(
  Player player,
  Map<String, String>? headers, {
  String? streamUrl,
  String? providerId,
  bool alreadyResolved = false,
}) async {
  final resolved = alreadyResolved
      ? Map<String, String>.from(headers ?? const {})
      : resolvePlaybackHttpHeaders(
          headers,
          streamUrl: streamUrl,
          providerId: providerId,
        );
  if (player.platform is! NativePlayer) return;
  final native = player.platform as NativePlayer;

  final referer = resolved['Referer'] ?? resolved['referer'];
  // Empty string clears a previous source's referrer - do not leave it sticky.
  await native.setProperty('referrer', referer ?? '');

  final ua = resolved['User-Agent'] ?? resolved['user-agent'];
  await native.setProperty(
    'user-agent',
    (ua != null && ua.isNotEmpty) ? ua : kDefaultStreamUserAgent,
  );
}

/// True when NativePlayer has finished libmpv create (`ctx` non-null).
///
/// [NativePlayer.setProperty] with `waitForInitialization: false` calls
/// `mpv_set_property_string` even when `ctx` is still `nullptr` → SIGSEGV
/// (issue 115 — IPTV Player menu Exo switch before create completes).
Future<bool> mediaKitPlayerHandleReady(
  NativePlayer mpv, {
  Duration timeout = const Duration(milliseconds: 400),
}) async {
  if (mpv.disposed) return false;
  if (mpv.completer.isCompleted) return true;
  try {
    await mpv.waitForPlayerInitialization.timeout(timeout);
    return !mpv.disposed;
  } catch (_) {
    return false;
  }
}

/// Restore mpv audio output after [silenceMediaKitPlayer] or a fresh boot.
///
/// Exit sets `mute=yes` and `ao=null` (non-Android). ATV already re-applies
/// this after every open; desktop IPTV / live must too (issue 138 pattern).
Future<void> restoreMediaKitAudioOutput(NativePlayer mpv) async {
  if (mpv.disposed) return;
  if (!await mediaKitPlayerHandleReady(mpv)) return;
  Future<void> prop(String key, String value) => mpv
      .setProperty(key, value, waitForInitialization: false)
      .timeout(const Duration(milliseconds: 150));
  try {
    await prop('mute', 'no');
  } catch (_) {}
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await prop('ao', 'audiotrack');
    } catch (_) {}
    return;
  }
  const aoByPlatform = {
    TargetPlatform.windows: 'wasapi',
    TargetPlatform.macOS: 'coreaudio',
    TargetPlatform.linux: 'pulse',
  };
  final ao = aoByPlatform[defaultTargetPlatform];
  if (ao == null) return;
  try {
    await prop('ao', ao);
  } catch (_) {}
}

/// Switch audio and re-sync demux/output — raw [Player.setAudioTrack] can
/// leave mpv silent until the next seek (HLS / multi-track MP4).
Future<void> selectPlayerAudioTrack(Player player, AudioTrack track) async {
  final active = player.state.track.audio;
  if (active.id == track.id) return;

  final pos = player.state.position;
  final playing = player.state.playing;

  await player.setAudioTrack(track);

  final platform = player.platform;
  if (platform is NativePlayer) {
    await restoreMediaKitAudioOutput(platform);
  }

  if (pos > Duration.zero) {
    await player.seek(pos);
    if (playing && !player.state.playing) {
      await player.play();
    }
  }
}

/// Kill audible output immediately via libmpv, without waiting on media_kit's
/// video-controller init futures (those can hang and leave audio after exit).
Future<void> silenceMediaKitPlayer(Player player) async {
  try {
    if (player.platform is NativePlayer) {
      final mpv = player.platform as NativePlayer;
      // Skip native props if create never finished — waitForInitialization:
      // false would SIGSEGV on null ctx. Still try Dart pause/volume below.
      if (!await mediaKitPlayerHandleReady(mpv)) return;
      Future<void> prop(String key, String value) => mpv
          .setProperty(key, value, waitForInitialization: false)
          .timeout(const Duration(milliseconds: 150));
      await prop('mute', 'yes');
      await prop('pause', 'yes');
      await prop('volume', '0');
      // ao=null drains audiotrack/MediaCodec. On Android that FFI does not
      // yield — Player-menu MediaKit→Exo ANRs (issue 128). mute+pause is enough;
      // stop/dispose still run on the tracked teardown.
      if (defaultTargetPlatform != TargetPlatform.android) {
        await prop('ao', 'null');
      }
    }
  } catch (_) {}
  try {
    await player.setVolume(0).timeout(const Duration(milliseconds: 250));
  } catch (_) {}
  try {
    await player.pause().timeout(const Duration(milliseconds: 250));
  } catch (_) {}
}

/// Stop then dispose with timeouts so a hung media_kit lock cannot leave
/// audio forever. Always silences first.
///
/// On macOS quit, a short [Player.stop] timeout raced [Player.dispose]: Dart
/// cleared mpv's `msg_wakeup` NativeCallable while `*/demux` was still in
/// `demux_free` / `av_log` → SIGSEGV in `msg_wakeup` (issue 081). Quiet logs
/// first, give stop longer to finish demux join, then dispose.
///
/// [fast]: Android / ATV **exit** path — MediaCodec + mpv stop/dispose on the UI
/// isolate can exceed the 5s input ANR window (issue 128). Prefer silence +
/// short timeouts after the Video surface is already unmounted. Do not use for
/// hot-swap / recreate (zombie mpv breaks the next MediaKit open).
Future<void> teardownMediaKitPlayer(Player player, {bool fast = false}) async {
  await silenceMediaKitPlayer(player);
  try {
    if (player.platform is NativePlayer) {
      final mpv = player.platform as NativePlayer;
      if (await mediaKitPlayerHandleReady(mpv)) {
        await mpv.setProperty(
          'msg-level',
          'all=no',
          waitForInitialization: false,
        );
        await mpv.setProperty('quiet', 'yes', waitForInitialization: false);
      }
    }
  } catch (_) {}
  final stopTimeout = fast
      ? const Duration(milliseconds: 400)
      : const Duration(seconds: 2);
  final disposeTimeout = fast
      ? const Duration(milliseconds: 500)
      : const Duration(seconds: 2);
  try {
    await player.stop().timeout(stopTimeout);
  } catch (_) {}
  // Let demux_thread finish demux_free before dispose clears wakeup.
  await Future.delayed(Duration(milliseconds: fast ? 20 : 80));
  try {
    await player.dispose().timeout(disposeTimeout);
  } catch (_) {}
}

/// Normalize URL + headers, apply mpv UA/referrer, open via media_kit.
Future<String> openPlayerStream(
  Player player, {
  required String url,
  Map<String, String>? headers,
  String? providerId,
  /// MediaKit/mpv: open demuxer at this time (HLS resume / server switch).
  /// Cleared after [player.open] so later seeks are not pinned to it.
  Duration? startAt,
  /// Keep peakstorm demuxed variant URLs (manual Quality menu selection).
  bool preserveHlsVariant = false,
}) async {
  var openUrl = normalizePlaybackStreamUrl(
    url,
    preserveHlsVariant: preserveHlsVariant,
  );
  if (isTorrentStreamUrl(openUrl)) {
    throw Exception(
      'Cannot open magnet/torrent URL directly - resolve to a stream first',
    );
  }
  final proxied1shows = await proxy1showsHlsIfNeeded(
    streamUrl: openUrl,
    headers: headers ?? const <String, String>{},
    providerId: providerId,
  );
  openUrl = proxied1shows.url;
  final catalogForHeaders = hlsProxyTargetUrl(openUrl) ?? openUrl;
  final mwVaultProxy = isMwVaultProxyPlayUrl(openUrl);
  final hdrs =
      isLocalLoopbackPlayUrl(openUrl) && is1showsCdnStreamUrl(catalogForHeaders)
      ? const <String, String>{}
      : resolvePlaybackHttpHeaders(
          headers,
          streamUrl: catalogForHeaders,
          providerId: providerId,
        );
  await applyMediaHttpHeaders(
    player,
    hdrs,
    streamUrl: openUrl,
    alreadyResolved: true,
  );
  final isRemoteHttp =
      (openUrl.startsWith('http://') || openUrl.startsWith('https://')) &&
      !isLocalTorrentStreamUrl(openUrl) &&
      !isLocalLoopbackPlayUrl(openUrl);
  final useStart = startAt != null && startAt > Duration.zero;
  if (useStart) await _mpvStartAt(player, startAt);
  try {
    // mwVault proxy auth lives in the URL query — do not duplicate via httpHeaders.
    await player.open(
      Media(openUrl, httpHeaders: isRemoteHttp && !mwVaultProxy ? hdrs : null),
    );
  } finally {
    if (useStart) await _mpvStartAt(player, null);
  }
  return openUrl;
}

/// Catalog row (Forja / Nuvio / Stremio HTTP) — 1shows proxy + RFC-045 pipeline.
Future<String?> openCatalogHttpStreamWithPipeline(
  Player player, {
  required Map<String, dynamic> stream,
  required String streamUrl,
  Map<String, String>? headers,
  String? providerId,
  Duration openTimeout = const Duration(seconds: 25),
}) async {
  final proxied = await proxyCatalogHttpStreamIfNeeded(
    streamUrl: streamUrl,
    headers: headers ?? const <String, String>{},
    stream: stream,
  );
  final playUrl = proxied.url;
  final playHeaders = proxied.headers;
  final pid = providerId ?? catalogHttpPlayProviderId(stream);
  final catalog = (hlsProxyTargetUrl(playUrl) ?? playUrl).trim();
  final isHls =
      playUrl.toLowerCase().contains('.m3u8') ||
      catalog.toLowerCase().contains('.m3u8') ||
      isLocalLoopbackPlayUrl(playUrl);
  if (!isHls) {
    await resetPlayerForOpen(player);
    return openPlayerStream(
      player,
      url: playUrl,
      headers: playHeaders,
      providerId: pid,
    );
  }

  final pipeline = await StreamOpenPipeline.start(
    catalogUrl: catalog,
    headers: playHeaders.isNotEmpty ? playHeaders : headers,
    providerId: pid,
  );
  while (true) {
    final step = await pipeline.next();
    if (step == null) return null;
    await resetPlayerForOpen(player);
    final openUrl = await openPlayerStream(
      player,
      url: step.playUrl,
      headers: step.headers ?? playHeaders,
      providerId: pid,
    );
    final opened = await waitForMediaOpen(
      player,
      streamUrl: openUrl,
      timeout: openTimeout,
    );
    if (!opened) {
      await player.stop();
      pipeline.report(StreamOpenStepResult.openFailed);
      continue;
    }
    final decoded = await confirmOpenedStreamVideoDecode(
      player,
      openUrl: openUrl,
      headers: step.headers,
      providerId: pid,
    );
    if (!decoded) {
      await player.stop();
      pipeline.report(StreamOpenStepResult.decodeFailed);
      continue;
    }
    pipeline.report(StreamOpenStepResult.success);
    return openUrl;
  }
}

/// Hard-seek if open-at-[target] (mpv `start`) did not land near it.
///
/// [skipNearCredits] matches history resume: do not jump into the last 15s
/// when duration is already known (finished / credits poison).
Future<void> ensureOpenedNearPosition(
  Player player,
  Duration? target, {
  bool skipNearCredits = true,
}) async {
  if (target == null || target.inSeconds <= 0) return;
  final dur = player.state.duration;
  if (skipNearCredits &&
      dur.inSeconds >= 90 &&
      target >= dur - const Duration(seconds: 15)) {
    return;
  }
  final pos = player.state.position;
  if ((pos - target).abs() <= const Duration(seconds: 5)) return;
  if (player.platform is NativePlayer) {
    try {
      await (player.platform as NativePlayer).setProperty('hr-seek', 'no');
    } catch (_) {}
  }
  await player.seek(target);
}

/// Avoid opening mpv while a route fade is still covering the player surface.
Future<void> waitForRouteTransition(BuildContext context) async {
  if (!context.mounted) return;
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.status == AnimationStatus.completed) {
    return;
  }
  final done = Completer<void>();
  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      animation.removeStatusListener(onStatus);
      if (!done.isCompleted) done.complete();
    }
  }

  animation.addStatusListener(onStatus);
  await done.future;
}

bool isVideoDecoderError(String err) {
  if (err.isEmpty) return false;
  final lower = err.toLowerCase();
  if (lower.contains('error decoding video')) return true;
  if (lower.contains('video decoder') && lower.contains('fail')) return true;
  if (lower.contains('hardware accelerator failed')) return true;
  if (lower.contains('no suitable decoder') &&
      !lower.contains('audio') &&
      !lower.contains('subtitle')) {
    return true;
  }
  if (lower.contains('failed to initialize a decoder') &&
      !lower.contains('audio') &&
      !lower.contains('subtitle')) {
    return true;
  }
  return false;
}

bool isAudioDecoderError(String err) {
  if (err.isEmpty) return false;
  return isAudioDecoderLog(err);
}

/// mpv log / error text that indicates the active audio track failed to decode.
bool isAudioDecoderLog(String text) {
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  if (lower.contains('error decoding audio')) return true;
  if (lower.contains('failed to initialize a decoder') &&
      lower.contains('audio')) {
    return true;
  }
  if (lower.contains('could not open codec') && lower.contains('audio')) {
    return true;
  }
  return false;
}

bool isIgnorablePlayerError(String err) {
  if (err.isEmpty) return true;
  if (isAudioDecoderError(err)) return true;
  if (isVideoDecoderError(err)) return false;
  final lower = err.toLowerCase();
  return lower.contains('subtitle') ||
      lower.contains('sub-add') ||
      lower.contains('external file') ||
      lower.contains("expected '='") ||
      lower.contains('expected =') ||
      lower.contains('.srt') ||
      lower.contains('.vtt') ||
      lower.contains('.ass') ||
      lower.contains('.ssa') ||
      lower.contains('502') ||
      lower.contains('http error');
}

bool isFatalPlayerOpenError(String err) =>
    !isIgnorablePlayerError(err) &&
    (err.contains('Failed') || err.contains('No such file'));

/// HTTP/CDN rejects during the open probe - fatal for fallback, ignore mid-play.
bool isOpenHttpFailure(String err) {
  if (err.isEmpty) return false;
  final lower = err.toLowerCase();
  return lower.contains('http error') ||
      lower.contains('403') ||
      lower.contains('404') ||
      lower.contains('502') ||
      lower.contains('failed to open');
}

/// Local librqbit HTTP URLs - mpv may emit "Failed to recognize file format"
/// while the first pieces are still arriving; that is not a hard fail yet.
bool isLocalTorrentStreamUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') return false;
  return uri.path.contains('/torrents/') && uri.path.contains('/stream/');
}

/// Catalog stream kind for logs - Nuvio vs Stremio from stream metadata.
String catalogStreamKindLabel(Map<String, dynamic> stream) {
  if (stream['_enginePluginId'] != null) return 'Forja';
  if (stream['_nuvioScraperId'] != null) return 'Nuvio';
  final base = stream['_addonBaseUrl']?.toString();
  if (base != null && base.startsWith('engine:')) return 'Forja';
  if (base != null && base.startsWith('nuvio:')) return 'Nuvio';
  return 'Stremio';
}

String? _torrentIndexerFromSessionCache(String cacheKey, String magnet) {
  final torrents = CatalogSourcesSessionCache.readTorrents(cacheKey);
  if (torrents == null) return null;
  for (final t in torrents) {
    if (t.magnet != magnet) continue;
    final src = t.source.trim();
    if (src.isNotEmpty && src != 'Unknown') return src;
    return null;
  }
  return null;
}

String? _catalogAddonNameFromSessionCaches(
  String cacheKey, {
  required String playUrl,
  String? catalogUrl,
}) {
  final stremio = CatalogSourcesSessionCache.readStremio(cacheKey);
  final nuvio = CatalogSourcesSessionCache.readNuvio(cacheKey)?.streams;
  final engine = CatalogSourcesSessionCache.readEngine(cacheKey)?.streams;
  for (final streams in [stremio, nuvio, engine]) {
    if (streams == null) continue;
    for (final stream in streams) {
      if (!catalogStreamRowMatchesPlaying(
        stream,
        playUrl: playUrl,
        catalogUrl: catalogUrl,
      )) {
        continue;
      }
      final addonName = stream['_addonName']?.toString().trim();
      if (addonName != null && addonName.isNotEmpty) return addonName;
      final base = stream['_addonBaseUrl']?.toString().trim();
      if (base != null && base.isNotEmpty) {
        return StreamProviderDisplay.playerLabel(base);
      }
    }
  }
  return null;
}

/// Player Sources button label — active scraper/addon or torrent indexer.
String catalogSourcesButtonLabel({
  required Movie? movie,
  required int? season,
  required int? episode,
  String? catalogAddonBaseUrl,
  String? widgetAddonBaseUrl,
  String? currentProvider,
  String? activeProvider,
  String? activeMagnet,
  String? widgetMagnetLink,
  String? currentStreamUrl,
  String? currentPlayingCatalogUrl,
  String? catalogSourceKind,
  int? anilistId,
  int? malId,
  int? kisskhId,
  String? animeAudioCategory,
}) {
  final addon = (catalogAddonBaseUrl ?? widgetAddonBaseUrl)?.trim();
  if (addon != null && addon.isNotEmpty) {
    return StreamProviderDisplay.playerLabel(addon);
  }

  final cacheKey = movie == null
      ? null
      : CatalogSourcesSessionCache.cacheKey(
          mediaId: movie.id,
          mediaType: movie.mediaType,
          season: season,
          episode: episode,
          anilistId: anilistId,
          malId: malId,
          kisskhId: kisskhId,
          animeAudioCategory: animeAudioCategory,
        );

  if (cacheKey != null) {
    final magnet = (activeMagnet ?? widgetMagnetLink)?.trim();
    if (magnet != null && magnet.isNotEmpty) {
      final indexer = _torrentIndexerFromSessionCache(cacheKey, magnet);
      if (indexer != null) return indexer;
    }

    final playUrl = currentStreamUrl?.trim();
    if (playUrl != null && playUrl.isNotEmpty) {
      final addonName = _catalogAddonNameFromSessionCaches(
        cacheKey,
        playUrl: playUrl,
        catalogUrl: currentPlayingCatalogUrl,
      );
      if (addonName != null) return addonName;
    }
  }

  final pid = (currentProvider ?? activeProvider)?.trim();
  if (pid != null && pid.isNotEmpty) {
    return StreamProviderDisplay.playerLabel(pid);
  }

  return switch (catalogSourceKind) {
    'torrents' => 'Torrent',
    'nuvio' => 'Nuvio',
    'engine' => 'Forja',
    'stremio' => 'Stremio',
    _ => 'Sources',
  };
}

/// `activeProvider` / RFC-044 identity for a Sources HTTP row.
String catalogHttpPlayProviderId(Map<String, dynamic> stream) {
  final engineId = stream['_enginePluginId']?.toString();
  if (engineId != null && engineId.isNotEmpty) return 'engine:$engineId';
  return 'stremio_direct';
}

List<Map<String, dynamic>>? catalogStreamExternalSubtitles(
  Map<String, dynamic> stream,
) {
  final raw = stream['subtitles'];
  if (raw is! List || raw.isEmpty) return null;
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final url = item['url']?.toString().trim() ?? '';
    if (url.isEmpty) continue;
    final name =
        item['name']?.toString() ??
        item['language']?.toString() ??
        'Subtitle';
    out.add({
      'url': url,
      'language':
          item['language']?.toString() ?? item['lang']?.toString() ?? 'en',
      'name': name,
      'display': name,
    });
  }
  return out.isEmpty ? null : out;
}

/// 111477 catalog rows and explicit `requires_proxy` need the local seek proxy.
bool catalogStreamRequiresSeekProxy(Map<String, dynamic> stream) {
  if (stream['requires_proxy'] == true) return true;
  final pid = catalogHttpPlayProviderId(stream);
  if (pid == 'engine:service111477') return true;
  return false;
}

/// Rewrites catalog HTTP streams that cannot be opened directly (111477).
Future<({String url, Map<String, String> headers})> proxyCatalogHttpStreamIfNeeded({
  required String streamUrl,
  required Map<String, String> headers,
  required Map<String, dynamic> stream,
}) async {
  if (catalogStreamRequiresSeekProxy(stream)) {
    final pid = catalogHttpPlayProviderId(stream);
    final upstream = resolvePlaybackHttpHeaders(
      headers,
      streamUrl: streamUrl,
      providerId: pid,
    );
    final proxied = await start111477Proxy(streamUrl, headers: upstream);
    return (url: proxied, headers: const <String, String>{});
  }
  final pid = catalogHttpPlayProviderId(stream);
  return proxy1showsHlsIfNeeded(
    streamUrl: streamUrl,
    headers: headers,
    providerId: pid,
  );
}

bool isTransientTorrentProbeError(String err) {
  final lower = err.toLowerCase();
  return lower.contains('failed to recognize file format') ||
      lower.contains('failed to open') ||
      lower.contains('error opening') ||
      lower.contains('no data');
}

/// mpv is ready to play - VOD duration, decoded video, or live/buffered data.
bool hasDecodedVideo(PlayerState state) {
  final w = state.videoParams.w ?? 0;
  final h = state.videoParams.h ?? 0;
  return w > 0 && h > 0;
}

bool isMediaOpenReady(PlayerState state) {
  if (hasDecodedVideo(state)) return true;
  if (state.duration.inMilliseconds > 0) return true;
  if (state.buffer.inMilliseconds > 0) return true;
  if (state.position.inMilliseconds > 0) return true;
  if (state.playing && state.bufferingPercentage > 0) return true;
  return false;
}

bool sourceExpectsDuration(String url, {String? type}) {
  final normalizedType = type?.toLowerCase() ?? '';
  if (normalizedType == 'hls' ||
      normalizedType == 'video' ||
      normalizedType == 'mp4' ||
      normalizedType == 'dash') {
    return true;
  }
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') ||
      lower.contains('.mp4') ||
      lower.contains('.mkv') ||
      lower.contains('.webm') ||
      lower.contains('.mpd');
}

/// Progressive containers skip [confirmOpenedStreamVideoDecode] — require demuxer
/// duration before confirm so empty/HTML probes do not look playable.
///
/// HLS/DASH already proved a decoded frame. Their playlist duration often
/// arrives after confirm; the UI duration listener drops pre-confirm events, so
/// a hard 5s gate falsely fails hosts like VixSrc while video is already up.
bool sourceRequiresSeekableDurationBeforeConfirm(String url, {String? type}) {
  if (!sourceExpectsDuration(url, type: type)) return false;
  if (sourceRequiresVideoDecode(url, type: type)) return false;
  return true;
}

/// Adaptive playlists can report buffer/duration while serving HTML/empty
/// segments. Progressive containers (mkv/mp4) get real demuxer duration -
/// do not require a decoded frame or large remote files fail the 8s probe.
///
/// Local torrent HTTP is the exception: moov duration arrives before any
/// frame, then an early EOF looks like a finished episode and auto-next fires.
bool sourceRequiresVideoDecode(String url, {String? type}) {
  if (isLocalTorrentStreamUrl(url)) return true;
  final normalizedType = type?.toLowerCase() ?? '';
  if (normalizedType == 'hls' || normalizedType == 'dash') return true;
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') || lower.contains('.mpd');
}

Duration videoDecodeTimeoutForUrl(String url) {
  return isLocalTorrentStreamUrl(url)
      ? const Duration(seconds: 90)
      : const Duration(seconds: 8);
}

/// Adaptive opens must decode at least one video frame before we treat them as
/// playable - buffer/position alone false-positives on dead CDNs.
Future<bool> waitForVideoDecode(
  Player player, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (hasDecodedVideo(player.state)) return true;
  try {
    await player.stream.videoParams
        .firstWhere((p) => (p.w ?? 0) > 0 && (p.h ?? 0) > 0)
        .timeout(timeout);
    return true;
  } catch (_) {
    return hasDecodedVideo(player.state);
  }
}

/// After [waitForMediaOpen], require a decoded frame for adaptive streams.
///
/// Observe-only - no reopen, no `hwdec=no`. The open pipeline owns the next
/// branch; [PlaybackRecovery] owns live decoder failures after confirm.
///
/// Set [force] for in-player Stremio/Nuvio switches: progressive HTTP can report
/// duration/buffer while only audio demuxes - without a frame the UI stays black.
Future<bool> confirmOpenedStreamVideoDecode(
  Player player, {
  required String openUrl,
  Map<String, String>? headers,
  String? type,
  String? providerId,
  bool force = false,
}) async {
  if (!force && !sourceRequiresVideoDecode(openUrl, type: type)) return true;
  return waitForVideoDecode(player, timeout: videoDecodeTimeoutForUrl(openUrl));
}

Future<bool> waitForSeekableDuration(
  Player player, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (player.state.duration.inMilliseconds > 0) return true;
  try {
    await player.stream.duration
        .firstWhere((d) => d.inMilliseconds > 0)
        .timeout(timeout);
    return true;
  } catch (_) {
    return player.state.duration.inMilliseconds > 0;
  }
}

void syncPlayerProgressNotifiers(
  Player player, {
  required ValueNotifier<Duration> duration,
  required ValueNotifier<Duration> position,
  required ValueNotifier<Duration> buffered,
}) {
  duration.value = player.state.duration;
  position.value = player.state.position;
  buffered.value = player.state.buffer;
}

/// Playhead to carry across provider/source switches (UI notifier or live mpv).
Duration switchResumePosition({
  required Duration uiPosition,
  required Duration playerPosition,
}) {
  if (uiPosition.inSeconds > 0) return uiPosition;
  if (playerPosition.inSeconds > 0) return playerPosition;
  return Duration.zero;
}

/// Seekbar buffer-end from mpv `demuxer-cache-duration` (seconds ahead).
///
/// `stream.buffer` is `demuxer-cache-time` (absolute PTS) and often stays at
/// 0 / playhead on HLS. Prefer whichever end is further ahead.
Duration? bufferedEndFromCacheAhead({
  required Duration position,
  required Duration duration,
  required double aheadSecs,
  Duration cacheTime = Duration.zero,
}) {
  if (!aheadSecs.isFinite || aheadSecs < 0) return null;
  var fromAhead = position +
      Duration(milliseconds: (aheadSecs * 1000).round());
  if (duration > Duration.zero && fromAhead > duration) {
    fromAhead = duration;
  }
  if (cacheTime > fromAhead) return cacheTime;
  if (aheadSecs <= 0 && cacheTime <= Duration.zero) return null;
  return fromAhead;
}

/// Wall-clock time after [_playbackConfirmed] before EOF can count as natural.
/// Local torrents demux a real duration then hit EOF within seconds.
const kMinConfirmedPlaybackForNaturalEnd = Duration(seconds: 45);

/// True when [positionMs] is clearly in the body of a long title (not open/EOF).
bool isMidEpisodePlayback(int positionMs, int durationMs) {
  if (durationMs < 90 * 1000) return false;
  return positionMs >= 30 * 1000 && positionMs <= durationMs - 90 * 1000;
}

/// Age of the current source open only (ignores session mid / first confirm).
Duration openPlaybackAge({required DateTime? openConfirmedAt, DateTime? now}) {
  if (openConfirmedAt == null) return Duration.zero;
  return (now ?? DateTime.now()).difference(openConfirmedAt);
}

/// Confirmed-playback age used for natural-end / persist guards.
///
/// When the user already watched the episode body this session, prefer the
/// first confirm timestamp so a late source switch / re-open near credits does
/// not reset the 45s grace and mis-label a real finish as abortive EOF.
Duration confirmedPlaybackAge({
  required DateTime? openConfirmedAt,
  DateTime? sessionFirstConfirmedAt,
  bool hadMidPlayback = false,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (hadMidPlayback && sessionFirstConfirmedAt != null) {
    return n.difference(sessionFirstConfirmedAt);
  }
  return openPlaybackAge(openConfirmedAt: openConfirmedAt, now: n);
}

/// Whether `completed` should count as a real finish (pin EOF / auto-next).
///
/// Session mid from a prior source must not make a dead CDN open look finished.
/// Early-EOF grace always uses [openConfirmedFor]; credits source-switches still
/// qualify once this open survives the grace and the UI is already at EOF.
bool shouldAcceptNaturalPlaybackEnd({
  required PlayerState state,
  required Duration openConfirmedFor,
  required bool openHadMidPlayback,
  required bool sessionHadMidPlayback,
  required Duration uiPosition,
  required Duration uiDuration,
}) {
  if (isNaturalPlaybackEnd(
    state,
    confirmedFor: openConfirmedFor,
    hadMidPlayback: openHadMidPlayback,
  )) {
    return true;
  }
  final pinDur = uiDuration > Duration.zero ? uiDuration : state.duration;
  if (!shouldPinSeekBarAtEof(uiPosition: uiPosition, duration: pinDur)) {
    return false;
  }
  if (!sessionHadMidPlayback) return false;
  // Dead CDN after a mid session jumps to EOF in seconds - still abortive.
  if (openConfirmedFor < kMinConfirmedPlaybackForNaturalEnd) return false;
  return isNaturalPlaybackEnd(
    state,
    confirmedFor: openConfirmedFor,
    hadMidPlayback: true,
  );
}

bool isNaturalPlaybackEnd(
  PlayerState state, {
  Duration? confirmedFor,
  Duration minConfirmed = kMinConfirmedPlaybackForNaturalEnd,
  bool? hadMidPlayback,
}) {
  final dur = state.duration.inMilliseconds;
  final pos = state.position.inMilliseconds;
  // Torrent/HLS often report a tiny duration while probing. Then
  // `pos >= dur - 1000` is true at position 0 (e.g. dur=500ms → -500) and
  // auto-next fires - episode looks like it "started finished".
  if (dur < 90 * 1000) return false;
  // Early EOF with a real moov duration: position jumps to end immediately.
  if (confirmedFor != null && confirmedFor < minConfirmed) return false;
  // Sitting at EOF for minutes must not become "natural" after the grace
  // window - require evidence the user actually watched the middle.
  if (hadMidPlayback == false) return false;
  // keep-open / HLS: `completed` often fires after position resets to 0 while
  // duration remains. Mid-watch + grace already proved a real session.
  if (pos <= 0) {
    return hadMidPlayback == true &&
        confirmedFor != null &&
        confirmedFor >= minConfirmed;
  }
  return pos >= dur - 1000;
}

/// Skip saving near-end progress from an early-EOF session (poisons resume).
bool shouldPersistWatchProgress({
  required int positionMs,
  required int durationMs,
  DateTime? confirmedAt,
  DateTime? sessionFirstConfirmedAt,
  bool hadMidPlayback = false,
  DateTime? now,
}) {
  if (positionMs <= 10000 || durationMs <= 0) return false;
  if (confirmedAt == null && sessionFirstConfirmedAt == null) return true;
  final alive = confirmedPlaybackAge(
    openConfirmedAt: confirmedAt,
    sessionFirstConfirmedAt: sessionFirstConfirmedAt,
    hadMidPlayback: hadMidPlayback,
    now: now,
  );
  if (alive < kMinConfirmedPlaybackForNaturalEnd &&
      durationMs >= 90 * 1000 &&
      positionMs >= durationMs - 5000) {
    return false;
  }
  return true;
}

/// Dead HLS / torrent opens often jump `position` to `duration` within the
/// early-EOF grace window. Painting that on the seek bar looks like a finished
/// episode and makes scrub-back fight a fake end.
bool shouldSuppressEarlyEofSeekBarPosition({
  required int positionMs,
  required int durationMs,
  required Duration confirmedFor,
  required bool hadMidPlayback,
  Duration minConfirmed = kMinConfirmedPlaybackForNaturalEnd,
}) {
  if (hadMidPlayback) return false;
  if (durationMs < 90 * 1000) return false;
  if (confirmedFor >= minConfirmed) return false;
  return positionMs >= durationMs - 5000;
}

/// keep-open EOF: `completed` can re-fire while mpv position is still 0/end.
/// If the UI already scrubbed away, do not yank the bar back to duration.
bool shouldPinSeekBarAtEof({
  required Duration uiPosition,
  required Duration duration,
}) {
  if (duration <= Duration.zero) return false;
  return uiPosition >= duration - const Duration(seconds: 2);
}

/// Grace after scrubbing away from EOF - ignore stale near-end position reports.
const kSeekAwayFromEofGrace = Duration(seconds: 2);

bool shouldIgnoreStaleEofPosition({
  required Duration reported,
  required Duration duration,
  required Duration uiPosition,
  DateTime? seekAwayFromEofAt,
  DateTime? now,
  Duration grace = kSeekAwayFromEofGrace,
}) {
  if (seekAwayFromEofAt == null || duration <= Duration.zero) return false;
  final n = now ?? DateTime.now();
  if (n.difference(seekAwayFromEofAt) > grace) return false;
  // UI already away from end; drop reports that are still sitting at EOF.
  if (shouldPinSeekBarAtEof(uiPosition: uiPosition, duration: duration)) {
    return false;
  }
  return shouldPinSeekBarAtEof(uiPosition: reported, duration: duration);
}

/// Seek that keeps the progress bar alive after EOF.
///
/// Without mpv `keep-open`, EOF leaves the player idle and seeks no-op. Even
/// with keep-open, resume playback when scrubbing away from the end.
///
/// Calls [onSeekAwayFromEof] when the scrub leaves the last ~2s so callers can
/// suppress completed re-pins and stale EOF position events.
Future<void> seekPlayerPreservingProgress(
  Player player, {
  required Duration position,
  required ValueNotifier<Duration> positionNotifier,
  Duration? duration,
  void Function()? onSeekAwayFromEof,
  void Function(Duration target)? onSeekCommitted,
  bool ensureTorrentSeekable = false,
}) async {
  final dur = duration ?? player.state.duration;
  final previous = positionNotifier.value;
  var target = position;
  if (target < Duration.zero) target = Duration.zero;
  if (dur > Duration.zero && target > dur) target = dur;
  final leavingEof =
      dur > Duration.zero &&
      shouldPinSeekBarAtEof(uiPosition: previous, duration: dur) &&
      !shouldPinSeekBarAtEof(uiPosition: target, duration: dur);
  positionNotifier.value = target;
  if (ensureTorrentSeekable) {
    await ensureLocalTorrentSeekable(player);
  }
  await player.seek(target);
  final nearEnd =
      dur > Duration.zero && target >= dur - const Duration(milliseconds: 500);
  if (!player.state.playing && !nearEnd) {
    await player.play();
  }
  if (leavingEof) onSeekAwayFromEof?.call();
  onSeekCommitted?.call(target);
}

/// True when remount actually resumed — not just opened at 0:00.
///
/// [buffering] is ignored when [position] is already near [target] — deep HLS
/// seeks often sit on the right PTS while segments refill.
bool remountPlaybackLooksLive({
  required bool playing,
  required bool buffering,
  required Duration position,
  required Duration target,
  Duration slop = const Duration(seconds: 12),
}) {
  if (!playing) return false;
  if (target > const Duration(seconds: 5) &&
      position < const Duration(seconds: 2)) {
    return false;
  }
  return position + slop >= target;
}

/// Post-seek remount wait — deep VOD HLS needs longer than 15s to refill.
Duration remountResumeTimeoutForSeek(Duration seekTarget) {
  final extra = (seekTarget.inMinutes ~/ 10) * 10;
  return Duration(seconds: (15 + extra).clamp(15, 60));
}

/// Stall timer before post-seek remount — scales with seek depth (issue 184).
Duration postSeekStallTimeoutForTarget(Duration seekTarget) {
  final extra = (seekTarget.inMinutes ~/ 10) * 5;
  return Duration(seconds: (15 + extra).clamp(15, 45));
}

/// Skip arming remount watchdog when a seek lands on the resume point right
/// after open — HLS is still prefetching segments at the saved timestamp.
bool shouldSkipPostSeekStallArm({
  required Duration target,
  Duration? resumeStartPosition,
  DateTime? playbackConfirmedAt,
  Duration graceAfterOpen = const Duration(seconds: 25),
  Duration resumeSlop = const Duration(seconds: 20),
}) {
  if (resumeStartPosition == null || playbackConfirmedAt == null) return false;
  if (resumeStartPosition.inSeconds <= 0) return false;
  if (DateTime.now().difference(playbackConfirmedAt) > graceAfterOpen) {
    return false;
  }
  return (target - resumeStartPosition).abs() <= resumeSlop;
}

Future<void> _mpvStartAt(Player player, Duration? start) async {
  if (player.platform is! NativePlayer) return;
  try {
    final mpv = player.platform as NativePlayer;
    if (start == null || start <= Duration.zero) {
      await mpv.setProperty('start', 'none');
    } else {
      await mpv.setProperty(
        'start',
        (start.inMilliseconds / 1000.0).toStringAsFixed(3),
      );
    }
  } catch (_) {}
}

/// Re-open the same play URL at [seekTarget] (post-seek stall remount).
///
/// Stops the hung demuxer first, opens with mpv `start` so HLS does not
/// play 0:00 then Range-seek 70 minutes (that re-stalls 4K). Returns true
/// only after playback is live near the target — not after first frame at 0.
Future<bool> remountPlayerStreamAtPosition(
  Player player, {
  required String url,
  Map<String, String>? headers,
  String? providerId,
  required Duration seekTarget,
  Duration? resumeTimeout,
  bool preserveHlsVariant = false,
}) async {
  final timeout = resumeTimeout ?? remountResumeTimeoutForSeek(seekTarget);
  await resetPlayerForOpen(player);
  final useStart = seekTarget > Duration.zero;
  final openUrl = await openPlayerStream(
    player,
    url: url,
    headers: headers,
    providerId: providerId,
    startAt: useStart ? seekTarget : null,
    preserveHlsVariant: preserveHlsVariant,
  );
  final opened = await waitForPlayerStreamOpen(
    player,
    streamUrl: openUrl,
    headers: headers,
    providerId: providerId,
  );
  if (!opened) return false;

  await ensureOpenedNearPosition(
    player,
    useStart ? seekTarget : null,
    skipNearCredits: false,
  );
  if (!player.state.playing) {
    await player.play();
  }

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (remountPlaybackLooksLive(
      playing: player.state.playing,
      buffering: player.state.buffering,
      position: player.state.position,
      target: seekTarget,
    )) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return remountPlaybackLooksLive(
    playing: player.state.playing,
    buffering: player.state.buffering,
    position: player.state.position,
    target: seekTarget,
  );
}

/// Clears stale duration/buffer from a prior failed open before trying again.
Future<void> resetPlayerForOpen(Player player) async {
  await player.stop();
  final deadline = DateTime.now().add(const Duration(milliseconds: 500));
  while (DateTime.now().isBefore(deadline)) {
    if (!isMediaOpenReady(player.state)) return;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

/// Ready check for [waitForMediaOpen].
///
/// Local torrent HTTP can report buffer / moov duration / playing while the
/// first pieces are empty - that used to mark playback confirmed and leave a
/// black stuck player. Require a decoded video frame for those URLs.
bool isOpenReadyForStream(PlayerState state, {required bool localTorrent}) {
  if (localTorrent) return hasDecodedVideo(state);
  return isMediaOpenReady(state);
}

/// Default open wait for local torrent HTTP — peers may still be filling the
/// head after the engine returned the URL; short timeouts abort while GBs land.
const kLocalTorrentOpenTimeout = Duration(seconds: 180);

/// Returns true once mpv reports playable media, false on fatal open error or
/// [timeout].
///
/// Pass [streamUrl] for local torrent streams so early demux probe failures
/// are ignored until the timeout - pieces may still be filling - and so
/// readiness requires a decoded video frame (not buffer alone).
///
/// [onProbeRetry] (local torrent only): re-open the same URL when lavf dies on
/// an incomplete head — waiting alone does nothing once demux has aborted.
Future<bool> waitForMediaOpen(
  Player player, {
  Duration timeout = const Duration(seconds: 25),
  String? streamUrl,
  Future<void> Function()? onProbeRetry,
  Duration probeRetryEvery = const Duration(seconds: 15),
}) async {
  final completer = Completer<bool>();
  final subs = <StreamSubscription<dynamic>>[];
  var settled = false;
  final localTorrent = streamUrl != null && isLocalTorrentStreamUrl(streamUrl);
  var retryInFlight = false;
  Timer? retryTimer;

  void settle(bool ok) {
    if (settled) return;
    settled = true;
    retryTimer?.cancel();
    for (final sub in subs) {
      sub.cancel();
    }
    if (!completer.isCompleted) completer.complete(ok);
  }

  void probe() {
    if (isOpenReadyForStream(player.state, localTorrent: localTorrent)) {
      settle(true);
    }
  }

  Future<void> tryReopen(String reason) async {
    final reopen = onProbeRetry;
    if (!localTorrent || reopen == null || settled || retryInFlight) return;
    retryInFlight = true;
    debugPrint('[Player] Torrent probe retry ($reason)');
    try {
      await reopen();
    } catch (e) {
      debugPrint('[Player] Torrent probe retry failed: $e');
    } finally {
      retryInFlight = false;
      probe();
    }
  }

  if (localTorrent && onProbeRetry != null) {
    retryTimer = Timer.periodic(probeRetryEvery, (_) {
      if (settled) return;
      if (isOpenReadyForStream(player.state, localTorrent: true)) {
        settle(true);
        return;
      }
      unawaited(tryReopen('periodic'));
    });
  }

  subs.addAll([
    player.stream.error.listen((err) {
      final fatal = isFatalPlayerOpenError(err) || isOpenHttpFailure(err);
      if (!fatal) return;
      if (localTorrent && isTransientTorrentProbeError(err)) {
        debugPrint('[Player] Transient torrent probe error (waiting): $err');
        unawaited(tryReopen('format/open'));
        return;
      }
      settle(false);
    }),
    player.stream.duration.listen((_) => probe()),
    player.stream.videoParams.listen((_) => probe()),
    player.stream.width.listen((_) => probe()),
    player.stream.height.listen((_) => probe()),
    player.stream.buffer.listen((_) => probe()),
    player.stream.position.listen((_) => probe()),
    player.stream.playing.listen((_) => probe()),
    player.stream.bufferingPercentage.listen((_) => probe()),
  ]);

  probe();

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        final ok = isOpenReadyForStream(
          player.state,
          localTorrent: localTorrent,
        );
        settle(ok);
        return ok;
      },
    );
  } finally {
    retryTimer?.cancel();
    for (final sub in subs) {
      await sub.cancel();
    }
  }
}

/// Belt-and-suspenders: ensure torrent scrub can Range (see configure path).
Future<void> ensureLocalTorrentSeekable(Player player) async {
  if (player.platform is! NativePlayer) return;
  final mpv = player.platform as NativePlayer;
  Future<void> safeSet(String key, String val) async {
    try {
      await mpv.setProperty(key, val);
    } catch (e) {
      debugPrint('[Player] Warning: failed to set mpv property $key=$val: $e');
    }
  }

  await safeSet('force-seekable', 'yes');
  await safeSet('hr-seek', 'yes');
  await safeSet('hr-seek-framedrop', 'no');
}

/// [waitForMediaOpen] with local-torrent timeout + optional probe re-open.
Future<bool> waitForPlayerStreamOpen(
  Player player, {
  required String streamUrl,
  Map<String, String>? headers,
  String? providerId,
  Future<String> Function()? reopen,
}) async {
  final localTorrent = isLocalTorrentStreamUrl(streamUrl);
  final opened = await waitForMediaOpen(
    player,
    streamUrl: streamUrl,
    timeout: localTorrent
        ? kLocalTorrentOpenTimeout
        : const Duration(seconds: 25),
    onProbeRetry: localTorrent
        ? () async {
            if (reopen != null) {
              await reopen();
              return;
            }
            await openPlayerStream(
              player,
              url: streamUrl,
              headers: headers,
              providerId: providerId,
            );
          }
        : null,
  );
  if (opened && localTorrent) {
    await ensureLocalTorrentSeekable(player);
  }
  return opened;
}

String? playbackQualityLabel(PlayerState state) {
  final w = state.videoParams.w ?? 0;
  final h = state.videoParams.h ?? 0;
  if (w <= 0 && h <= 0) return null;
  if (h > 0) return '${h}p';
  return '${w}p';
}

String? playbackQualityDetail(PlayerState state) {
  final w = state.videoParams.w ?? 0;
  final h = state.videoParams.h ?? 0;
  if (w <= 0 || h <= 0) return null;
  return '$w × $h';
}

/// Label for audio/subtitle chips - language endonym when known
/// (हिन्दी, தமிழ், English…), else raw title / Track id.
String formatPlayerTrackLabel({
  required String id,
  String? title,
  String? language,
}) {
  final fromLang = languageEndonym(language);
  if (fromLang != null && fromLang != 'Unknown') return fromLang;

  final trimmedTitle = title?.trim();
  if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
    final fromTitle = languageEndonym(trimmedTitle);
    if (fromTitle != null && fromTitle != 'Unknown') return fromTitle;
    // "English 5.1" / "Hindi [Forced]" → first token
    final first = trimmedTitle.split(RegExp(r'[\s\[\(,/·]+')).first;
    final fromFirst = languageEndonym(first);
    if (fromFirst != null && fromFirst != 'Unknown') return fromFirst;
    return trimmedTitle;
  }

  final trimmedLanguage = language?.trim();
  if (trimmedLanguage != null && trimmedLanguage.isNotEmpty) {
    return languageDisplayName(trimmedLanguage);
  }
  return 'Track $id';
}

bool _sameTrackText(String a, String? b) {
  if (b == null) return false;
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

bool _titleIsLanguageOnly(String title, String languageLabel, String? language) {
  if (_sameTrackText(title, languageLabel) || _sameTrackText(title, language)) {
    return true;
  }
  final asLang = languageEndonym(title);
  if (asLang != null &&
      asLang != 'Unknown' &&
      _sameTrackText(asLang, languageLabel)) {
    return true;
  }
  return false;
}

String? _composeAudioTechFormat({
  String? codec,
  String? channels,
  int? channelscount,
  int? samplerate,
  int? bitrate,
}) {
  final parts = <String>[];
  final c = codec?.trim();
  if (c != null && c.isNotEmpty) parts.add(c);

  final ch = channels?.trim();
  if (ch != null && ch.isNotEmpty) {
    parts.add(ch);
  } else if (channelscount != null && channelscount > 0) {
    parts.add('$channelscount ch');
  }

  if (samplerate != null && samplerate > 0) {
    parts.add(
      samplerate % 1000 == 0
          ? '${samplerate ~/ 1000} kHz'
          : '${(samplerate / 1000).toStringAsFixed(1)} kHz',
    );
  }

  if (bitrate != null && bitrate > 0) {
    parts.add(
      bitrate >= 1000 ? '${(bitrate / 1000).round()} kbps' : '$bitrate bps',
    );
  }

  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Secondary line under the language in the audio menu — container title or
/// demux codec / channels / rate / bitrate. Null when nothing useful beyond
/// the language label.
String? formatPlayerAudioFormatSubtitle({
  required String languageLabel,
  String? title,
  String? language,
  String? codec,
  String? channels,
  int? channelscount,
  int? samplerate,
  int? bitrate,
}) {
  final trimmedTitle = title?.trim();
  if (trimmedTitle != null &&
      trimmedTitle.isNotEmpty &&
      !_titleIsLanguageOnly(trimmedTitle, languageLabel, language)) {
    return trimmedTitle;
  }

  final composed = _composeAudioTechFormat(
    codec: codec,
    channels: channels,
    channelscount: channelscount,
    samplerate: samplerate,
    bitrate: bitrate,
  );
  if (composed == null || _sameTrackText(composed, languageLabel)) return null;
  return composed;
}

Future<String?> _mpvTrackProperty(Player player, String property) async {
  if (player.platform is! NativePlayer) return null;
  try {
    final raw = await (player.platform as NativePlayer).getProperty(property);
    if (raw.isEmpty || raw == 'no' || raw == 'auto') return null;
    return raw;
  } catch (_) {
    return null;
  }
}

AudioTrack? findAudioTrack(List<AudioTrack> tracks, String id) {
  for (final track in tracks) {
    if (track.id == id) return track;
  }
  return null;
}

SubtitleTrack? findSubtitleTrack(List<SubtitleTrack> tracks, String id) {
  for (final track in tracks) {
    if (track.id == id) return track;
  }
  return null;
}

/// Embedded (in-stream) subtitle tracks — excludes Off/auto and sideloaded URIs.
List<SubtitleTrack> embeddedSubtitleTracks(Iterable<SubtitleTrack> tracks) {
  return tracks
      .where(
        (t) =>
            t.id != 'no' && t.id != 'auto' && !t.id.startsWith('http'),
      )
      .toList();
}

Future<AudioTrack?> resolveActiveAudioTrack(Player player) async {
  final selected = player.state.track.audio;
  if (selected.id != 'auto' && selected.id != 'no') return selected;
  final aid = await _mpvTrackProperty(player, 'aid');
  if (aid != null) {
    return findAudioTrack(player.state.tracks.audio, aid);
  }
  return null;
}

Future<SubtitleTrack?> resolveActiveSubtitleTrack(Player player) async {
  final selected = player.state.track.subtitle;
  if (selected.id != 'auto' && selected.id != 'no') return selected;
  final sid = await _mpvTrackProperty(player, 'sid');
  if (sid != null) {
    return findSubtitleTrack(player.state.tracks.subtitle, sid);
  }
  return null;
}

bool isHlsQualityAuto(String? currentQualityUrl, String? masterUrl) {
  if (masterUrl == null || currentQualityUrl == null) return false;
  return currentQualityUrl == masterUrl;
}

bool isHlsQualityLocked(String? currentQualityUrl, String? masterUrl) =>
    !isHlsQualityAuto(currentQualityUrl, masterUrl);

/// Normalize for remount / reopen — keep locked variant URLs on peakstorm HLS.
String remountPlaybackStreamUrl(
  String url, {
  required bool qualityLocked,
}) =>
    normalizePlaybackStreamUrl(url, preserveHlsVariant: qualityLocked);

HlsQuality? matchActiveHlsVariant(
  List<HlsQuality> qualities,
  PlayerState state,
) {
  final height = state.videoParams.h ?? 0;
  if (height > 0) {
    for (final quality in qualities) {
      if (quality.isAuto) continue;
      if (quality.height == height) return quality;
      if (quality.label == '${height}p') return quality;
    }
  }
  final width = state.videoParams.w ?? 0;
  if (width > 0) {
    for (final quality in qualities) {
      if (quality.isAuto) continue;
      if (quality.label == '${width}p') return quality;
    }
  }
  return null;
}

String? activeHlsQualityLabel(PlayerState state, List<HlsQuality> qualities) {
  final fromParams = playbackQualityLabel(state);
  if (fromParams != null) return fromParams;
  return matchActiveHlsVariant(qualities, state)?.label;
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  } else {
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

/// True when this play URL unwraps PNG-shelled MPEG-TS (`strip=png`).
bool hlsProxyStripIsPng(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.path.contains('/hls-proxy')) return false;
  return uri.queryParameters['strip'] == 'png';
}

/// Known hosts that serve Megaplay-style PNG-wrapped MPEG-TS (need hls-proxy strip).
///
/// Prefer [animeHlsNeedsPngStripFor] with a [sourceKey] - host lists live on
/// each provider's [AnimePlaybackProfile] (RFC-039 / DB).
bool animeHlsNeedsPngStrip(String url) {
  return animeHlsNeedsPngStripFor(url, sourceKey: null);
}

/// Whether [applyAnimePngStripIfNeeded] should run for [url] / [sourceKey].
///
/// [AnimePngStripMode.auto] returns true for HLS so apply can content-sample
/// (RFC-044). Host needles alone no longer gate strip.
bool animeHlsNeedsPngStripFor(String url, {String? sourceKey}) {
  final u = url.trim();
  if (u.isEmpty) return false;
  if (u.toLowerCase().contains('/hls-proxy')) {
    final target = hlsProxyTargetUrl(u);
    return target != null &&
        animeHlsNeedsPngStripFor(target, sourceKey: sourceKey);
  }
  final cfg = ProviderRuntimeConfig.instance;
  if (sourceKey != null && sourceKey.trim().isNotEmpty) {
    final p = cfg.animePlaybackProfile(sourceKey);
    if (p.pngStrip == AnimePngStripMode.never) return false;
    if (p.pngStrip == AnimePngStripMode.force ||
        p.pngStrip == AnimePngStripMode.auto) {
      return u.contains('.m3u8');
    }
    return p.urlNeedsPngStrip(u);
  }
  // No key: only legacy host needles / force profiles that match the URL.
  for (final p in cfg.animePlaybackProfiles.values) {
    if (p.urlNeedsPngStrip(u)) return true;
  }
  return false;
}

/// True when [bytes] start with a PNG signature.
bool looksLikePng(List<int> bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

/// True when [bytes] are a PNG shell with MPEG-TS after IEND or offset 252.
bool pngWrapsMpegTs(List<int> bytes) {
  if (bytes.length < 16) return false;
  if (!looksLikePng(bytes)) return false;
  // IEND then TS sync
  for (var i = 8; i < bytes.length - 4; i++) {
    if (bytes[i] == 0x49 &&
        bytes[i + 1] == 0x45 &&
        bytes[i + 2] == 0x4E &&
        bytes[i + 3] == 0x44) {
      final start = i + 8;
      for (var p = start; p < bytes.length - 188; p++) {
        if (bytes[p] == 0x47 && bytes[p + 188] == 0x47) return true;
      }
      for (var p = start; p < bytes.length; p++) {
        if (bytes[p] == 0x47) return true;
      }
      break;
    }
  }
  return bytes.length > 252 + 188 &&
      bytes[252] == 0x47 &&
      bytes[252 + 188] == 0x47;
}

/// Whether a Range/prefix sample means PNG-strip should run.
///
/// kotocdn (Megaplay) answers `Range: bytes=0-N` with a tiny ad PNG on
/// `ibyteimg` while a full GET returns PNG-wrapped MPEG-TS. Treat that decoy
/// as wrapped so we still open via `/hls-proxy?strip=png`.
@visibleForTesting
bool animeSegmentSampleLooksPngWrapped(List<int> sample) {
  if (pngWrapsMpegTs(sample)) return true;
  // Tiny PNG, no TS - Range decoy (real body is PNG+TS).
  return looksLikePng(sample) && sample.length < 512;
}

/// Whether catalog HLS should open via `/hls-proxy?strip=png`.
///
/// [AnimePngStripMode.auto] is content-only - host needles never force strip.
@visibleForTesting
bool animePngStripShouldProxy({
  required AnimePngStripMode mode,
  required bool contentLooksWrapped,
}) {
  return switch (mode) {
    AnimePngStripMode.never => false,
    AnimePngStripMode.force => true,
    AnimePngStripMode.auto => contentLooksWrapped,
  };
}

/// Route PNG-wrapped HLS through local `/hls-proxy?strip=png` (RFC-044).
///
/// [AnimePngStripMode.force] always proxies; [AnimePngStripMode.auto] samples a
/// media segment and strips only when [pngWrapsMpegTs]; [never] is a no-op.
/// Host needles do **not** force strip for [auto] - plain HLS stays direct.
Future<StreamSource> applyAnimePngStripIfNeeded(
  StreamSource source, {
  String? sourceKey,
  @visibleForTesting
  Future<bool> Function(String url, Map<String, String> headers)?
  segmentLooksPngWrapped,
  @visibleForTesting
  String Function(String url, Map<String, String> headers)? buildStripProxy,
}) async {
  final url = source.url.trim();
  if (url.isEmpty || url.contains('/hls-proxy')) return source;
  if (!url.contains('.m3u8')) return source;

  final pid = source.providerId?.trim().isNotEmpty == true
      ? source.providerId
      : sourceKey;
  final profile = ProviderRuntimeConfig.instance.animePlaybackProfile(
    pid ?? '',
  );
  final mode = profile.pngStrip;
  // `auto` is owned by [StreamOpenStrategy] at open time (try direct ↔ strip).
  // This helper only materializes `force` (or legacy callers that pass a mock).
  if (mode == AnimePngStripMode.never) return source;
  if (mode == AnimePngStripMode.auto && segmentLooksPngWrapped == null) {
    return source;
  }

  final hdrs = resolvePlaybackHttpHeaders(
    source.headers,
    streamUrl: url,
    providerId: pid,
  );
  final looksWrapped = mode == AnimePngStripMode.auto
      ? await (segmentLooksPngWrapped ?? _animeHlsSegmentLooksPngWrapped)(
          url,
          hdrs,
        )
      : false;
  if (!animePngStripShouldProxy(
    mode: mode,
    contentLooksWrapped: looksWrapped,
  )) {
    if (kDebugMode && mode == AnimePngStripMode.auto) {
      debugPrint(
        '[Player] PNG-strip skip (no wrap detected) $url key=${pid ?? ''}',
      );
    }
    return source;
  }

  late final String proxied;
  if (buildStripProxy != null) {
    proxied = buildStripProxy(url, hdrs);
  } else {
    final ls = LocalServerService();
    if (ls.port == 0) {
      await ls.start();
    }
    if (ls.port == 0) return source;
    proxied = ls.getHlsProxyUrl(url, hdrs, stripMode: 'png');
  }
  if (kDebugMode) {
    debugPrint('[Player] PNG-strip via hls-proxy key=${pid ?? ''} $url');
  }
  return StreamSource(
    url: proxied,
    title: source.title,
    type: source.type,
    headers: null,
    providerId: pid,
    catalogUrl: source.catalogUrl ?? url,
  );
}

/// True when the first playable media segment is a PNG shell wrapping MPEG-TS
/// (or a kotocdn-style Range decoy that implies wrap).
///
/// Used by [StreamOpenStrategy] sniff and [applyAnimePngStripIfNeeded].
Future<bool> animeHlsSegmentLooksPngWrappedForStrategy(
  String playlistUrl,
  Map<String, String> headers,
) => _animeHlsSegmentLooksPngWrapped(playlistUrl, headers);

/// True when the first playable media segment is a PNG shell wrapping MPEG-TS.
Future<bool> _animeHlsSegmentLooksPngWrapped(
  String playlistUrl,
  Map<String, String> headers,
) async {
  try {
    final master = await animeHttp(
      'GET',
      playlistUrl,
      headers: headers,
      maxRetries: 0,
      timeoutSecs: 8,
    );
    if (master.status != 200 || !master.body.contains('#EXTM3U')) return false;
    var mediaPlaylistUrl = playlistUrl;
    final masterLines = master.body.split('\n');
    for (final line in masterLines) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      if (t.contains('.m3u8')) {
        mediaPlaylistUrl = _joinPlaylistUri(playlistUrl, t);
        break;
      }
    }
    String body = master.body;
    if (mediaPlaylistUrl != playlistUrl) {
      final media = await animeHttp(
        'GET',
        mediaPlaylistUrl,
        headers: headers,
        maxRetries: 0,
        timeoutSecs: 8,
      );
      if (media.status != 200) return false;
      body = media.body;
    }
    for (final line in body.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      if (_isAnimeHlsAdHost(t)) continue;
      final segUrl = _joinPlaylistUri(mediaPlaylistUrl, t);
      final sample = await animeHttpBytes(
        segUrl,
        headers: {...headers, 'Range': 'bytes=0-2047'},
        timeoutSecs: 8,
        maxRetries: 0,
      );
      if (sample.isEmpty) continue;
      if (animeSegmentSampleLooksPngWrapped(sample)) {
        if (kDebugMode && looksLikePng(sample) && !pngWrapsMpegTs(sample)) {
          debugPrint(
            '[Player] PNG Range decoy (${sample.length}B) - strip $segUrl',
          );
        }
        return true;
      }
    }
  } catch (_) {}
  return false;
}

Future<List<StreamSource>> applyAnimePngStripAll(
  List<StreamSource> sources, {
  String? sourceKey,
}) async {
  final out = <StreamSource>[];
  for (final s in sources) {
    out.add(await applyAnimePngStripIfNeeded(s, sourceKey: sourceKey));
  }
  return out;
}

/// Known anti-scraper CDN hosts - may still wrap real video (see [pngWrapsMpegTs]).
bool _isAnimeHlsAdHost(String url) {
  final u = url.toLowerCase();
  return u.contains('ibyteimg.com') ||
      u.contains('byteimg.com') ||
      u.contains('tiktokcdn.com') ||
      u.contains('p16-ad-') ||
      u.contains('ad-site-i18n');
}

/// VidRock / Vidzee / WebStreamr 1shows CDN — PNG-wrapped segments; proxy at play.
bool is1showsCdnStreamUrl(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  return host.contains('1shows.app');
}

/// Same HLS re-proxy as [WebStreamrService] (local strip=png).
Future<({String url, Map<String, String> headers})> proxy1showsHlsIfNeeded({
  required String streamUrl,
  required Map<String, String> headers,
  String? providerId,
}) async {
  if (!is1showsCdnStreamUrl(streamUrl) || isLocalLoopbackPlayUrl(streamUrl)) {
    return (url: streamUrl, headers: headers);
  }
  final upstream = resolvePlaybackHttpHeaders(
    headers,
    streamUrl: streamUrl,
    providerId: providerId,
  );
  final ls = LocalServerService();
  if (ls.port == 0) await ls.start();
  if (ls.port == 0) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await ls.start();
  }
  if (ls.port == 0) {
    if (kDebugMode) {
      debugPrint(
        '[Player] 1shows HLS proxy unavailable — opening direct $streamUrl',
      );
    }
    return (url: streamUrl, headers: upstream);
  }
  return (
    url: ls.getHlsProxyUrl(streamUrl, upstream, stripMode: 'png'),
    headers: const <String, String>{},
  );
}

String _joinPlaylistUri(String base, String uri) {
  final t = uri.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  final b = Uri.tryParse(base);
  if (b == null) return t;
  return b.resolve(t).toString();
}

/// Sample media segments - masters can be valid while every segment is a PNG ad.
///
/// PNG shells that wrap MPEG-TS (Megaplay / nekostream) count as playable -
/// open those via [applyAnimePngStripIfNeeded].
///
/// Runs in Dart (not only Rust) so a stale app-bundle `libffi` cannot let
/// nekostream/vivibebe green-pass then fail at decode.
Future<bool> hlsMediaSegmentsLookPlayable(
  String playlistUrl,
  Map<String, String> headers,
) async {
  try {
    final master = await animeHttp(
      'GET',
      playlistUrl,
      headers: headers,
      maxRetries: 0,
      timeoutSecs: 8,
    );
    if (master.status != 200 || !master.body.contains('#EXTM3U')) return false;

    // Already on /hls-proxy?strip=png - nested sample is redundant.
    // Do NOT skip sampling just because the profile has pngStrip auto/force:
    // pure image ads (vivibebe → ibyteimg PNG) are not fixable by strip.
    if (hlsProxyStripIsPng(playlistUrl)) return true;

    var mediaUrl = playlistUrl;
    var body = master.body;
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      if (i + 1 >= lines.length) break;
      final next = lines[i + 1].trim();
      if (next.isEmpty || next.startsWith('#')) continue;
      mediaUrl = _joinPlaylistUri(playlistUrl, next);
      final media = await animeHttp(
        'GET',
        mediaUrl,
        headers: headers,
        maxRetries: 0,
        timeoutSecs: 8,
      );
      if (media.status != 200 || !media.body.contains('#EXTM3U')) return false;
      body = media.body;
      break;
    }

    final segs = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => _joinPlaylistUri(mediaUrl, l))
        .take(4)
        .toList();
    if (segs.isEmpty) {
      return !body.contains('#EXT-X-STREAM-INF');
    }

    var checked = 0;
    var poisoned = 0;
    for (final seg in segs) {
      try {
        final res = await animeHttp(
          'GET',
          seg,
          headers: {...headers, 'Range': 'bytes=0-1023'},
          maxRetries: 0,
          timeoutSecs: 8,
        );
        if (res.status == 401 || res.status == 403 || res.status == 404) {
          checked++;
          poisoned++;
          continue;
        }
        if (res.status != 200 && res.status != 206) continue;
        checked++;

        final ct = (res.headers['content-type'] ?? '').toLowerCase();
        final maybeWrapped =
            _isAnimeHlsAdHost(res.finalUrl) ||
            _isAnimeHlsAdHost(seg) ||
            ct.startsWith('image/');
        if (maybeWrapped) {
          try {
            final sample = await animeHttpBytes(
              seg,
              headers: {...headers, 'Range': 'bytes=0-1023'},
              timeoutSecs: 8,
              maxRetries: 0,
            );
            if (sample.isNotEmpty &&
                animeSegmentSampleLooksPngWrapped(sample)) {
              continue;
            }
          } catch (_) {}
          poisoned++;
        }
      } catch (_) {
        // Network blip - don't count.
      }
    }
    if (checked == 0) return true;
    return poisoned * 2 < checked;
  } catch (_) {
    return false;
  }
}

Future<bool> _probeHlsMasterOnly(
  String catalog,
  Map<String, String> hdrs,
) async {
  try {
    final master = await animeHttp(
      'GET',
      catalog,
      headers: hdrs,
      maxRetries: 0,
      timeoutSecs: 8,
    );
    return master.status == 200 && master.body.contains('#EXTM3U');
  } catch (_) {
    return false;
  }
}

Future<bool> _probeHeadOrRange(String catalog, Map<String, String> hdrs) async {
  try {
    var res = await animeHttp(
      'HEAD',
      catalog,
      headers: hdrs,
      maxRetries: 0,
      timeoutSecs: 8,
    );
    if (res.status >= 200 && res.status < 400) return true;
    res = await animeHttp(
      'GET',
      catalog,
      headers: {...hdrs, 'Range': 'bytes=0-0'},
      maxRetries: 0,
      timeoutSecs: 8,
    );
    return res.status == 200 || res.status == 206;
  } catch (_) {
    return false;
  }
}

/// Lightweight reachability check for stream menu reload.
///
/// Pass [sourceKey] for anime so probe mode comes from
/// [ProviderRuntimeConfig.animePlaybackProfile] (DB / builtins) - not host
/// heuristics.
Future<bool> probeStreamSourceUrl(
  String url,
  Map<String, String>? headers, {
  String? sourceKey,
}) async {
  final normalized = normalizePlaybackStreamUrl(url);
  if (normalized.isEmpty) return false;
  // Already on the PNG-strip play path - don't re-sample nested segments.
  if (hlsProxyStripIsPng(normalized)) return true;
  final catalog = hlsProxyTargetUrl(normalized) ?? normalized;
  final key = sourceKey?.trim();
  final hdrs = resolvePlaybackHttpHeaders(
    headers,
    streamUrl: catalog,
    providerId: key,
  );

  if (key != null && key.isNotEmpty) {
    final profile = ProviderRuntimeConfig.instance.animePlaybackProfile(key);
    switch (profile.probe) {
      case AnimeProbeMode.skip:
        return true;
      case AnimeProbeMode.masterOnly:
        if (catalog.contains('.m3u8') ||
            catalog.toLowerCase().contains('/api/proxy') ||
            normalized.contains('/hls-proxy')) {
          return _probeHlsMasterOnly(catalog, hdrs);
        }
        return _probeHeadOrRange(catalog, hdrs);
      case AnimeProbeMode.headOrRange:
        return _probeHeadOrRange(catalog, hdrs);
      case AnimeProbeMode.segmentPoisonSample:
        if (catalog.contains('.m3u8') ||
            catalog.toLowerCase().contains('/api/proxy') ||
            normalized.contains('/hls-proxy')) {
          if (!await hlsMediaSegmentsLookPlayable(catalog, hdrs)) {
            debugPrint(
              '[Player] HLS media poison/ad segments - reject $catalog '
              '(sourceKey=$key)',
            );
            return false;
          }
          return true;
        }
        return _probeHeadOrRange(catalog, hdrs);
    }
  }

  try {
    if (catalog.contains('.m3u8') ||
        catalog.toLowerCase().contains('/api/proxy') ||
        normalized.contains('/hls-proxy')) {
      // Legacy (no sourceKey): keep segment sample for movie/misc HLS.
      if (!await hlsMediaSegmentsLookPlayable(catalog, hdrs)) {
        debugPrint('[Player] HLS media poison/ad segments - reject $catalog');
        return false;
      }
      return true;
    }
    return _probeHeadOrRange(catalog, hdrs);
  } catch (_) {
    return false;
  }
}

/// Menu / auto-probe pre-check.
///
/// **111477:** catalog URLs only get a shape check (CDN HEAD is slow/flaky);
/// the local seek proxy is validated at play. Never treat a dead localhost
/// proxy URL as the catalog stream - those are session-local play endpoints.
Future<bool> validateStreamSourceForCheck({
  required String? providerId,
  required StreamSource source,
  Map<String, String>? headers,
}) async {
  if (providerId == 'service111477') {
    final url = source.url.trim();
    if (url.isEmpty || isUnplayableCachedStreamUrl(url)) return false;
    // Catalog hosts only - loopback is rejected by [isUnplayableCachedStreamUrl].
    return url.contains('://');
  }
  // MovieBlast / NetMirror: trust extract — CDN probes false-fail or rate-limit.
  if (providerId == 'engine:movieblast' ||
      providerId == 'movieblast' ||
      providerId == 'engine:netmirror' ||
      providerId == 'netmirror') {
    final url = source.url.trim();
    return url.contains('://') && !isUnplayableCachedStreamUrl(url);
  }
  return probeStreamSourceUrl(source.url, headers, sourceKey: providerId);
}

/// Index of [current] in a flat hub episode list, or null if not found.
int? hubEpisodeIndex(List<PlayerHubEpisode> episodes, num current) {
  for (var i = 0; i < episodes.length; i++) {
    if (episodes[i].number == current) return i;
  }
  return null;
}

/// Whether hub playback has a previous / next list entry for [current].
({bool hasPrev, bool hasNext}) adjacentHubEpisodeFlags(
  List<PlayerHubEpisode>? episodes,
  num? current,
) {
  if (episodes == null || episodes.isEmpty || current == null) {
    return (hasPrev: false, hasNext: false);
  }
  final idx = hubEpisodeIndex(episodes, current);
  if (idx == null) return (hasPrev: false, hasNext: false);
  return (hasPrev: idx > 0, hasNext: idx < episodes.length - 1);
}

/// Whether the floating "Next Episode" chip should show.
///
/// Requires a trustworthy duration (avoids HLS briefly reporting a short
/// length and latching the button for the whole episode). Last ~5% of short
/// titles, or last 2 minutes of longer ones. Cleared when the user seeks back.
bool isNearEndOfEpisode(Duration position, Duration duration) {
  // Ignore bogus early duration reports from adaptive streams.
  if (duration.inSeconds < 90) return false;
  final remaining = duration - position;
  if (remaining.isNegative) return true;
  final threshold = duration.inMinutes < 10
      ? Duration(seconds: (duration.inSeconds * 0.05).round().clamp(5, 30))
      : const Duration(minutes: 2);
  return remaining <= threshold;
}
