import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';

/// Browser-like UA so CDNs that reject bare `libmpv` still serve the file.
const kDefaultStreamUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

final _trailingMediaSlash = RegExp(
  r'\.(mp4|mkv|webm|avi|mov|m4v|ts|mpd|m3u8)/+$',
  caseSensitive: false,
);

/// Strip CDN junk like `…/file.mp4/` that browsers forgive and demuxers reject.
String normalizePlaybackStreamUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (_trailingMediaSlash.hasMatch(trimmed)) {
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
  return trimmed;
}

/// Headers for every network open: extractor headers + guaranteed browser UA.
///
/// Prefer [providerId] (RFC-044) over CDN hostname matching. Do **not**
/// comma-join into mpv `http-header-fields` — UA values contain commas
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
  final policy = cfg.playbackPolicyFor(pid);
  final banSelf = cfg.bansCdnSelfReferer(pid);
  final catalogForMatch = streamUrl != null && isLocalLoopbackPlayUrl(streamUrl)
      ? (hlsProxyTargetUrl(streamUrl) ?? streamUrl)
      : streamUrl;

  final referer = take('Referer', 'referer');
  if (referer != null && referer.isNotEmpty) {
    putCanonical('Referer', 'referer', referer);
  } else if (policy != null) {
    // RFC-044: recover from provider identity — never invent CDN self-Referer.
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
  if (policy != null) {
    final ref = take('Referer', 'referer') ?? '';
    final refHost = Uri.tryParse(ref)?.host.toLowerCase() ?? ref.toLowerCase();
    final streamHost =
        Uri.tryParse(catalogForMatch ?? '')?.host.toLowerCase() ?? '';
    final selfCdn = streamHost.isNotEmpty &&
        refHost.isNotEmpty &&
        (refHost == streamHost ||
            refHost.contains(streamHost) ||
            streamHost.contains(refHost));
    final scrapeLeak = refHost.contains('enma');
    final policyHost =
        Uri.tryParse(policy.referer)?.host.toLowerCase() ?? '';
    final familyOk = _refererMatchesPolicyFamily(refHost, policyHost);
    final accepted =
        ref.isNotEmpty && !selfCdn && !scrapeLeak && familyOk;
    if (!accepted) {
      putCanonical('Referer', 'referer', policy.referer);
      putCanonical('Origin', 'origin', policy.origin);
    }
  }

  // Legacy KissKh CDN sniff — only when provider identity is unknown.
  if (policy == null &&
      streamUrl != null &&
      _isKissKhCdnStream(streamUrl)) {
    final ref = take('Referer', 'referer') ?? '';
    if (ref.isEmpty || _isKissKhCdnStream(ref) || !ref.contains('kisskh')) {
      putCanonical('Referer', 'referer', 'https://kisskh.co/');
      putCanonical('Origin', 'origin', 'https://kisskh.co');
    }
  }

  // Vidsrc CloudStream (`/pl/…/master.m3u8?token=`): master/variant 200 with
  // any headers, but leaf `page-N.html` segments return CF 403 when Referer or
  // Origin is set. Browser players use referrerpolicy=no-referrer — strip both
  // and never derive them from the stream host.
  if (streamUrl != null && _isVidsrcCloudStreamPl(streamUrl)) {
    out.remove('Referer');
    out.remove('referer');
    out.remove('Origin');
    out.remove('origin');
  }

  // VidNest MovieBox CDN (`*.hakunaymatata.com`): progressive MP4 returns HTTP
  // 429 whenever Referer is set (including self-origin). Browser JWPlayer uses
  // no-referrer — strip Referer/Origin and never derive them from the CDN host.
  if (streamUrl != null && _isVidnestMovieBoxCdn(streamUrl)) {
    out.remove('Referer');
    out.remove('referer');
    out.remove('Origin');
    out.remove('origin');
  }

  // Legacy CDN host rules — only when provider identity is unknown (RFC-044).
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

/// Tokenized Vidsrc CloudStream playlist — segments reject Referer/Origin.
bool _isVidsrcCloudStreamPl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  final path = uri.path.toLowerCase();
  if (!path.contains('/pl/')) return false;
  if (!path.contains('.m3u8')) return false;
  return uri.queryParameters.containsKey('token');
}

/// VidNest Gama/MovieBox (and related) CDN — rejects any Referer with HTTP 429.
bool _isVidnestMovieBoxCdn(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return host.contains('hakunaymatata.com');
}

/// Set mpv `user-agent` / `referrer` before `open`. Full header list goes on
/// [Media.httpHeaders] — never via comma-joined `http-header-fields`.
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
  // Empty string clears a previous source's referrer — do not leave it sticky.
  await native.setProperty('referrer', referer ?? '');

  final ua = resolved['User-Agent'] ?? resolved['user-agent'];
  await native.setProperty(
    'user-agent',
    (ua != null && ua.isNotEmpty) ? ua : kDefaultStreamUserAgent,
  );
}

/// Kill audible output immediately via libmpv, without waiting on media_kit's
/// video-controller init futures (those can hang and leave audio after exit).
Future<void> silenceMediaKitPlayer(Player player) async {
  try {
    if (player.platform is NativePlayer) {
      final mpv = player.platform as NativePlayer;
      // waitForInitialization: false — must not block exit on stuck VC init.
      await mpv.setProperty('mute', 'yes', waitForInitialization: false);
      await mpv.setProperty('pause', 'yes', waitForInitialization: false);
      await mpv.setProperty('volume', '0', waitForInitialization: false);
      // Detach audio output so decode cannot keep playing after the UI pops.
      await mpv.setProperty('ao', 'null', waitForInitialization: false);
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
Future<void> teardownMediaKitPlayer(Player player) async {
  await silenceMediaKitPlayer(player);
  try {
    if (player.platform is NativePlayer) {
      final mpv = player.platform as NativePlayer;
      await mpv.setProperty('msg-level', 'all=no', waitForInitialization: false);
      await mpv.setProperty('quiet', 'yes', waitForInitialization: false);
    }
  } catch (_) {}
  try {
    await player.stop().timeout(const Duration(seconds: 2));
  } catch (_) {}
  // Let demux_thread finish demux_free before dispose clears wakeup.
  await Future.delayed(const Duration(milliseconds: 80));
  try {
    await player.dispose().timeout(const Duration(seconds: 2));
  } catch (_) {}
}

/// Normalize URL + headers, apply mpv UA/referrer, open via media_kit.
Future<String> openPlayerStream(
  Player player, {
  required String url,
  Map<String, String>? headers,
  String? providerId,
}) async {
  final openUrl = normalizePlaybackStreamUrl(url);
  if (isTorrentStreamUrl(openUrl)) {
    throw Exception(
      'Cannot open magnet/torrent URL directly — resolve to a stream first',
    );
  }
  final hdrs = resolvePlaybackHttpHeaders(
    headers,
    streamUrl: openUrl,
    providerId: providerId,
  );
  await applyMediaHttpHeaders(
    player,
    hdrs,
    streamUrl: openUrl,
    alreadyResolved: true,
  );
  final isRemoteHttp = (openUrl.startsWith('http://') ||
          openUrl.startsWith('https://')) &&
      !isLocalTorrentStreamUrl(openUrl) &&
      !isLocalLoopbackPlayUrl(openUrl);
  await player.open(
    Media(openUrl, httpHeaders: isRemoteHttp ? hdrs : null),
  );
  return openUrl;
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

/// HTTP/CDN rejects during the open probe — fatal for fallback, ignore mid-play.
bool isOpenHttpFailure(String err) {
  if (err.isEmpty) return false;
  final lower = err.toLowerCase();
  return lower.contains('http error') ||
      lower.contains('403') ||
      lower.contains('404') ||
      lower.contains('502') ||
      lower.contains('failed to open');
}

/// Local librqbit HTTP URLs — mpv may emit "Failed to recognize file format"
/// while the first pieces are still arriving; that is not a hard fail yet.
bool isLocalTorrentStreamUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') return false;
  return uri.path.contains('/torrents/') && uri.path.contains('/stream/');
}

/// Catalog stream kind for logs — Nuvio vs Stremio from stream metadata.
String catalogStreamKindLabel(Map<String, dynamic> stream) {
  if (stream['_nuvioScraperId'] != null) return 'Nuvio';
  final base = stream['_addonBaseUrl']?.toString();
  if (base != null && base.startsWith('nuvio:')) return 'Nuvio';
  return 'Stremio';
}

bool isTransientTorrentProbeError(String err) {
  final lower = err.toLowerCase();
  return lower.contains('failed to recognize file format') ||
      lower.contains('failed to open') ||
      lower.contains('error opening') ||
      lower.contains('no data');
}

/// mpv is ready to play — VOD duration, decoded video, or live/buffered data.
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

/// Adaptive playlists can report buffer/duration while serving HTML/empty
/// segments. Progressive containers (mkv/mp4) get real demuxer duration —
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
/// playable — buffer/position alone false-positives on dead CDNs.
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
/// When GPU decode stalls (seen on some Windows `auto-safe` setups), retry once
/// with `hwdec=no` before failing over to the next source.
///
/// Set [force] for in-player Stremio/Nuvio switches: progressive HTTP can report
/// duration/buffer while only audio demuxes — without a frame the UI stays black.
Future<bool> confirmOpenedStreamVideoDecode(
  Player player, {
  required String openUrl,
  Map<String, String>? headers,
  String? type,
  bool force = false,
}) async {
  if (!force && !sourceRequiresVideoDecode(openUrl, type: type)) return true;
  final openTimeout = isLocalTorrentStreamUrl(openUrl)
      ? const Duration(seconds: 90)
      : const Duration(seconds: 25);
  final decodeTimeout = videoDecodeTimeoutForUrl(openUrl);

  if (await waitForVideoDecode(player, timeout: decodeTimeout)) {
    return true;
  }

  if (player.platform is! NativePlayer) return false;
  debugPrint('[Player] hw decode miss — retry software: $openUrl');
  await resetPlayerForOpen(player);
  await (player.platform as NativePlayer).setProperty('hwdec', 'no');
  final retryUrl = await openPlayerStream(
    player,
    url: openUrl,
    headers: headers,
  );
  if (!await waitForMediaOpen(
    player,
    streamUrl: retryUrl,
    timeout: openTimeout,
  )) {
    return false;
  }
  return waitForVideoDecode(player, timeout: decodeTimeout);
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

/// Wall-clock time after [_playbackConfirmed] before EOF can count as natural.
/// Local torrents demux a real duration then hit EOF within seconds.
const kMinConfirmedPlaybackForNaturalEnd = Duration(seconds: 45);

/// True when [positionMs] is clearly in the body of a long title (not open/EOF).
bool isMidEpisodePlayback(int positionMs, int durationMs) {
  if (durationMs < 90 * 1000) return false;
  return positionMs >= 30 * 1000 && positionMs <= durationMs - 90 * 1000;
}

/// Age of the current source open only (ignores session mid / first confirm).
Duration openPlaybackAge({
  required DateTime? openConfirmedAt,
  DateTime? now,
}) {
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
  // Dead CDN after a mid session jumps to EOF in seconds — still abortive.
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
  // auto-next fires — episode looks like it "started finished".
  if (dur < 90 * 1000) return false;
  // Early EOF with a real moov duration: position jumps to end immediately.
  if (confirmedFor != null && confirmedFor < minConfirmed) return false;
  // Sitting at EOF for minutes must not become "natural" after the grace
  // window — require evidence the user actually watched the middle.
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

/// Grace after scrubbing away from EOF — ignore stale near-end position reports.
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
}) async {
  final dur = duration ?? player.state.duration;
  final previous = positionNotifier.value;
  var target = position;
  if (target < Duration.zero) target = Duration.zero;
  if (dur > Duration.zero && target > dur) target = dur;
  final leavingEof = dur > Duration.zero &&
      shouldPinSeekBarAtEof(uiPosition: previous, duration: dur) &&
      !shouldPinSeekBarAtEof(uiPosition: target, duration: dur);
  positionNotifier.value = target;
  await player.seek(target);
  final nearEnd = dur > Duration.zero &&
      target >= dur - const Duration(milliseconds: 500);
  if (!player.state.playing && !nearEnd) {
    await player.play();
  }
  if (leavingEof) onSeekAwayFromEof?.call();
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
/// first pieces are empty — that used to mark playback confirmed and leave a
/// black stuck player. Require a decoded video frame for those URLs.
bool isOpenReadyForStream(PlayerState state, {required bool localTorrent}) {
  if (localTorrent) return hasDecodedVideo(state);
  return isMediaOpenReady(state);
}

/// Returns true once mpv reports playable media, false on fatal open error or
/// [timeout].
///
/// Pass [streamUrl] for local torrent streams so early demux probe failures
/// are ignored until the timeout — pieces may still be filling — and so
/// readiness requires a decoded video frame (not buffer alone).
Future<bool> waitForMediaOpen(
  Player player, {
  Duration timeout = const Duration(seconds: 25),
  String? streamUrl,
}) async {
  final completer = Completer<bool>();
  final subs = <StreamSubscription<dynamic>>[];
  var settled = false;
  final localTorrent =
      streamUrl != null && isLocalTorrentStreamUrl(streamUrl);

  void settle(bool ok) {
    if (settled) return;
    settled = true;
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

  subs.addAll([
    player.stream.error.listen((err) {
      final fatal = isFatalPlayerOpenError(err) || isOpenHttpFailure(err);
      if (!fatal) return;
      if (localTorrent && isTransientTorrentProbeError(err)) {
        debugPrint('[Player] Transient torrent probe error (waiting): $err');
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
        final ok =
            isOpenReadyForStream(player.state, localTorrent: localTorrent);
        settle(ok);
        return ok;
      },
    );
  } finally {
    for (final sub in subs) {
      await sub.cancel();
    }
  }
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

/// Label for audio/subtitle chips — language endonym when known
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

HlsQuality? matchActiveHlsVariant(List<HlsQuality> qualities, PlayerState state) {
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

String? activeHlsQualityLabel(
  PlayerState state,
  List<HlsQuality> qualities,
) {
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

/// Catalog URL inside a local `/hls-proxy?url=…` play endpoint, if any.
String? hlsProxyTargetUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (!uri.path.contains('/hls-proxy')) return null;
  final target = uri.queryParameters['url']?.trim() ?? '';
  return target.isEmpty ? null : target;
}

/// True when this play URL unwraps PNG-shelled MPEG-TS (`strip=png`).
bool hlsProxyStripIsPng(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.path.contains('/hls-proxy')) return false;
  return uri.queryParameters['strip'] == 'png';
}

/// Known hosts that serve Megaplay-style PNG-wrapped MPEG-TS (need hls-proxy strip).
///
/// Prefer [animeHlsNeedsPngStripFor] with a [sourceKey] — host lists live on
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

/// True when [bytes] are a PNG shell with MPEG-TS after IEND or offset 252.
bool pngWrapsMpegTs(List<int> bytes) {
  if (bytes.length < 16) return false;
  if (bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) {
    return false;
  }
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

/// Whether catalog HLS should open via `/hls-proxy?strip=png`.
///
/// [AnimePngStripMode.auto] is content-only — host needles never force strip.
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
/// Host needles do **not** force strip for [auto] — plain HLS stays direct.
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
  final profile = ProviderRuntimeConfig.instance.animePlaybackProfile(pid ?? '');
  final mode = profile.pngStrip;
  if (mode == AnimePngStripMode.never) return source;

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
  return StreamSource(
    url: proxied,
    title: source.title,
    type: source.type,
    headers: null,
    providerId: pid,
    catalogUrl: source.catalogUrl ?? url,
  );
}

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
      return pngWrapsMpegTs(sample);
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

/// Known anti-scraper CDN hosts — may still wrap real video (see [pngWrapsMpegTs]).
bool _isAnimeHlsAdHost(String url) {
  final u = url.toLowerCase();
  return u.contains('ibyteimg.com') ||
      u.contains('byteimg.com') ||
      u.contains('p16-ad-') ||
      u.contains('ad-site-i18n');
}

String _joinPlaylistUri(String base, String uri) {
  final t = uri.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  final b = Uri.tryParse(base);
  if (b == null) return t;
  return b.resolve(t).toString();
}

/// Sample media segments — masters can be valid while every segment is a PNG ad.
///
/// PNG shells that wrap MPEG-TS (Megaplay / nekostream) count as playable —
/// open those via [applyAnimePngStripIfNeeded].
///
/// Runs in Dart (not only Rust) so a stale app-bundle `libffi` cannot let
/// nekostream/vivibebe green-pass then fail at decode.
Future<bool> hlsMediaSegmentsLookPlayable(
  String playlistUrl,
  Map<String, String> headers, {
  String? sourceKey,
}) async {
  try {
    final master = await animeHttp(
      'GET',
      playlistUrl,
      headers: headers,
      maxRetries: 0,
      timeoutSecs: 8,
    );
    if (master.status != 200 || !master.body.contains('#EXTM3U')) return false;

    // Provider profile (or legacy host list) says PNG-strip — skip segment
    // poison sample; master OK ⇒ playable via /hls-proxy?strip=png.
    if (hlsProxyStripIsPng(playlistUrl) ||
        animeHlsNeedsPngStripFor(playlistUrl, sourceKey: sourceKey)) {
      return true;
    }

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
        final maybeWrapped = _isAnimeHlsAdHost(res.finalUrl) ||
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
            if (sample.isNotEmpty && pngWrapsMpegTs(sample)) {
              continue;
            }
          } catch (_) {}
          poisoned++;
        }
      } catch (_) {
        // Network blip — don't count.
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

Future<bool> _probeHeadOrRange(
  String catalog,
  Map<String, String> hdrs,
) async {
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
/// [ProviderRuntimeConfig.animePlaybackProfile] (DB / builtins) — not host
/// heuristics.
Future<bool> probeStreamSourceUrl(
  String url,
  Map<String, String>? headers, {
  String? sourceKey,
}) async {
  final normalized = normalizePlaybackStreamUrl(url);
  if (normalized.isEmpty) return false;
  // Already on the PNG-strip play path — don't re-sample nested segments.
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
          if (!await hlsMediaSegmentsLookPlayable(
            catalog,
            hdrs,
            sourceKey: key,
          )) {
            debugPrint(
              '[Player] HLS media poison/ad segments — reject $catalog '
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
        debugPrint('[Player] HLS media poison/ad segments — reject $catalog');
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
/// proxy URL as the catalog stream — those are session-local play endpoints.
Future<bool> validateStreamSourceForCheck({
  required String? providerId,
  required StreamSource source,
  Map<String, String>? headers,
}) async {
  if (providerId == 'service111477') {
    final url = source.url.trim();
    if (url.isEmpty || isUnplayableCachedStreamUrl(url)) return false;
    // Catalog hosts only — loopback is rejected by [isUnplayableCachedStreamUrl].
    return url.contains('://');
  }
  return probeStreamSourceUrl(
    source.url,
    headers,
    sourceKey: providerId,
  );
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
