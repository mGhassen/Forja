import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:media_kit/media_kit.dart';

const kPeakstormResumeLogTag = '[PeakstormResume]';

/// Structured resume/remount log — debug builds only.
void logPeakstormResume(
  String phase, {
  PlayerState? state,
  Duration? target,
  Duration? previous,
  String? detail,
  StackTrace? caller,
}) {
  if (!kDebugMode) return;
  final parts = <String>[phase];
  if (target != null) parts.add('target=${target.inSeconds}s');
  if (state != null) {
    parts.add('pos=${state.position.inSeconds}s');
    parts.add('playing=${state.playing}');
    parts.add('buf=${state.buffering}');
    final w = state.videoParams.w ?? 0;
    final h = state.videoParams.h ?? 0;
    parts.add('video=${w}x$h');
  } else if (previous != null) {
    parts.add('prev=${previous.inSeconds}s');
  }
  if (detail != null && detail.isNotEmpty) parts.add(detail);
  debugPrint('$kPeakstormResumeLogTag ${parts.join(' ')}');
  if (caller != null) {
    debugPrint('$kPeakstormResumeLogTag   caller:\n${_trimForjaStack(caller)}');
  }
}

void logPeakstormSeekTo({
  required Duration from,
  required Duration to,
  required String action,
  String? skipReason,
  StackTrace? caller,
}) {
  if (!kDebugMode) return;
  final delta = (to - from).inSeconds;
  debugPrint(
    '$kPeakstormResumeLogTag seekTo $action '
    'from=${from.inSeconds}s to=${to.inSeconds}s delta=${delta}s'
    '${skipReason != null ? ' skip=$skipReason' : ''}',
  );
  if (caller != null) {
    debugPrint('$kPeakstormResumeLogTag   caller:\n${_trimForjaStack(caller)}');
  }
}

/// Why [remountPlaybackResumed] would reject peakstorm — for sample logs.
String peakstormResumeRejectReason(
  PlayerState state,
  Duration target, {
  String? streamUrl,
  Duration? previousPosition,
}) {
  if (!state.playing) return 'not_playing';
  if (target > const Duration(seconds: 5) &&
      state.position < const Duration(seconds: 2)) {
    return 'pos_still_at_zero';
  }
  if (state.position + const Duration(seconds: 12) < target) {
    return 'pos_far_from_target';
  }
  final w = state.videoParams.w ?? 0;
  final h = state.videoParams.h ?? 0;
  if (w <= 0 || h <= 0) return 'no_decoded_video';
  final peakstorm =
      streamUrl != null && peakstormFmp4HlsAvoidHardSeek(streamUrl);
  if (peakstorm) {
    if (state.buffering) return 'buffering';
    if (previousPosition != null &&
        state.position <= previousPosition + const Duration(milliseconds: 300)) {
      return 'stagnant_pts';
    }
  } else if (state.buffering && state.bufferingPercentage <= 0) {
    return 'buffering_no_pct';
  }
  return 'ok';
}

String _trimForjaStack(StackTrace stack) {
  final lines = stack
      .toString()
      .split('\n')
      .where(
        (line) =>
            line.contains('forja/') &&
            !line.contains('player_peakstorm_resume_diag'),
      )
      .take(8);
  final trimmed = lines.join('\n');
  return trimmed.isEmpty ? stack.toString().split('\n').take(6).join('\n') : trimmed;
}
