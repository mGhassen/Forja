import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
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
/// Do **not** comma-join into mpv `http-header-fields` — UA values contain
/// commas (`KHTML, like Gecko`) and that corrupts the list. Pass the map to
/// [Media.httpHeaders] so media_kit sets a proper NODE_ARRAY on load.
Map<String, String> resolvePlaybackHttpHeaders(
  Map<String, String>? headers, {
  String? streamUrl,
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

  final referer = take('Referer', 'referer');
  if (referer != null && referer.isNotEmpty) {
    putCanonical('Referer', 'referer', referer);
  } else if (streamUrl != null &&
      streamUrl.isNotEmpty &&
      !isLocalTorrentStreamUrl(streamUrl)) {
    final uri = Uri.tryParse(streamUrl);
    if (uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty) {
      putCanonical('Referer', 'referer', '${uri.origin}/');
    }
  }

  // KissKh CDN (cdnvideo*.shop, etc.) rejects self-origin Referer. Cached
  // sources sometimes lose headers — never derive Referer from the CDN host.
  if (streamUrl != null && _isKissKhCdnStream(streamUrl)) {
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
  return host.contains('cdnvideo') || host.contains('kisskh');
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
  bool alreadyResolved = false,
}) async {
  final resolved = alreadyResolved
      ? Map<String, String>.from(headers ?? const {})
      : resolvePlaybackHttpHeaders(headers, streamUrl: streamUrl);
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

/// Normalize URL + headers, apply mpv UA/referrer, open via media_kit.
Future<String> openPlayerStream(
  Player player, {
  required String url,
  Map<String, String>? headers,
}) async {
  final openUrl = normalizePlaybackStreamUrl(url);
  final hdrs = resolvePlaybackHttpHeaders(headers, streamUrl: openUrl);
  await applyMediaHttpHeaders(
    player,
    hdrs,
    streamUrl: openUrl,
    alreadyResolved: true,
  );
  final isRemoteHttp = (openUrl.startsWith('http://') ||
          openUrl.startsWith('https://')) &&
      !isLocalTorrentStreamUrl(openUrl);
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
bool sourceRequiresVideoDecode(String url, {String? type}) {
  final normalizedType = type?.toLowerCase() ?? '';
  if (normalizedType == 'hls' || normalizedType == 'dash') return true;
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') || lower.contains('.mpd');
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

bool isNaturalPlaybackEnd(PlayerState state) {
  final dur = state.duration.inMilliseconds;
  if (dur <= 0) return false;
  return state.position.inMilliseconds >= dur - 1000;
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

/// Returns true once mpv reports playable media, false on fatal open error or
/// [timeout].
///
/// Pass [streamUrl] for local torrent streams so early demux probe failures
/// are ignored until the timeout — pieces may still be filling.
Future<bool> waitForMediaOpen(
  Player player, {
  Duration timeout = const Duration(seconds: 25),
  String? streamUrl,
}) async {
  final completer = Completer<bool>();
  final subs = <StreamSubscription<dynamic>>[];
  var settled = false;
  final tolerateProbe =
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
    if (isMediaOpenReady(player.state)) settle(true);
  }

  subs.addAll([
    player.stream.error.listen((err) {
      final fatal = isFatalPlayerOpenError(err) || isOpenHttpFailure(err);
      if (!fatal) return;
      if (tolerateProbe && isTransientTorrentProbeError(err)) {
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

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        final ok = isMediaOpenReady(player.state);
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

String formatPlayerTrackLabel({
  required String id,
  String? title,
  String? language,
}) {
  final trimmedTitle = title?.trim();
  if (trimmedTitle != null && trimmedTitle.isNotEmpty) return trimmedTitle;
  final trimmedLanguage = language?.trim();
  if (trimmedLanguage != null && trimmedLanguage.isNotEmpty) {
    return trimmedLanguage;
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

/// Lightweight reachability check for stream menu reload.
Future<bool> probeStreamSourceUrl(
  String url,
  Map<String, String>? headers,
) async {
  final normalized = normalizePlaybackStreamUrl(url);
  if (normalized.isEmpty) return false;
  final hdrs = resolvePlaybackHttpHeaders(headers, streamUrl: normalized);
  try {
    if (normalized.contains('.m3u8') ||
        normalized.toLowerCase().contains('/api/proxy')) {
      final res = await animeHttp(
        'GET',
        normalized,
        headers: hdrs,
        maxRetries: 0,
        timeoutSecs: 8,
      );
      return res.status == 200 && res.body.contains('#EXTM3U');
    }
    var res = await animeHttp(
      'HEAD',
      normalized,
      headers: hdrs,
      maxRetries: 0,
      timeoutSecs: 8,
    );
    if (res.status >= 200 && res.status < 400) return true;
    res = await animeHttp(
      'GET',
      normalized,
      headers: {...hdrs, 'Range': 'bytes=0-0'},
      maxRetries: 0,
      timeoutSecs: 8,
    );
    return res.status == 200 || res.status == 206;
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
  return probeStreamSourceUrl(source.url, headers);
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
