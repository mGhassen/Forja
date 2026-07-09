import 'dart:async';

import 'package:media_kit/media_kit.dart';

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
