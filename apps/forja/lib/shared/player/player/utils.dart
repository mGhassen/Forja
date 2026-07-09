import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';

/// Hub players (Asian drama, anime Arabic, …) pass an already-resolved URL.
bool hasPreResolvedStreamSources({
  Movie? movie,
  Map<String, dynamic>? providers,
  List<StreamSource>? sources,
}) =>
    movie == null &&
    providers == null &&
    sources != null &&
    sources.isNotEmpty;

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

bool isIgnorablePlayerError(String err) {
  if (err.isEmpty) return true;
  if (err.contains('Error decoding audio') ||
      err.contains('Failed to initialize a decoder for codec')) {
    return true;
  }
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

/// mpv is ready to play — VOD duration, decoded video, or live/buffered data.
bool isMediaOpenReady(PlayerState state) {
  if (state.duration.inMilliseconds > 0) return true;
  final w = state.videoParams.w ?? 0;
  final h = state.videoParams.h ?? 0;
  if (w > 0 && h > 0) return true;
  if (state.buffer.inMilliseconds > 0) return true;
  if (state.position.inMilliseconds > 0) return true;
  if (state.playing && state.bufferingPercentage > 0) return true;
  return false;
}

/// Returns true once mpv reports playable media, false on fatal open error or
/// [timeout].
Future<bool> waitForMediaOpen(
  Player player, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (isMediaOpenReady(player.state)) return true;

  final completer = Completer<bool>();
  final subs = <StreamSubscription<dynamic>>[];
  var settled = false;

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
      if (isFatalPlayerOpenError(err)) settle(false);
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
