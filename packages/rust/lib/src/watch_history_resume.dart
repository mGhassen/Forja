/// Shared continue-watching / in-progress resume rules (2–90% watched).
bool isInProgressResume(int position, int duration) {
  if (duration <= 0) return false;
  final progress = position / duration;
  return progress >= 0.02 && progress < 0.9;
}

/// After this age, episode picks show the source panel instead of auto-launch.
const watchHistoryStaleResumeThreshold = Duration(days: 7);

/// Coerce JSON / FFI numbers (`int` or `double`) to [int].
int watchHistoryInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

/// True when saved progress is older than [threshold] (missing timestamp = stale).
bool isStaleResume(
  Map<String, dynamic>? progress, {
  Duration threshold = watchHistoryStaleResumeThreshold,
}) {
  if (progress == null) return false;
  final pos = watchHistoryInt(progress['position']);
  if (pos <= 0) return false;
  final ts = watchHistoryInt(progress['updatedAt'], -1);
  if (ts <= 0) return true;
  return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)) >
      threshold;
}

/// Episode was played before and has a saved playback method to reuse.
bool hasSavedEpisodePlayback(Map<String, dynamic>? progress) {
  if (progress == null) return false;
  final method = progress['method'] as String?;
  if (method == null || method.isEmpty || method == 'trakt_import') {
    return false;
  }
  return true;
}

/// Resume position when still in progress; otherwise replay from the start
/// using the same saved source.
Duration resumeStartPositionFromProgress(Map<String, dynamic> progress) {
  final pos = watchHistoryInt(progress['position']);
  final dur = watchHistoryInt(progress['duration']);
  if (pos <= 0) return Duration.zero;
  if (isInProgressResume(pos, dur)) return Duration(milliseconds: pos);
  return Duration.zero;
}

/// Latest in-progress history entry for a TV show (by [updatedAt]).
Map<String, dynamic>? latestInProgressForShow(
  int tmdbId,
  List<Map<String, dynamic>> history,
) {
  Map<String, dynamic>? best;
  for (final item in history) {
    if (watchHistoryInt(item['tmdbId'], -1) != tmdbId) continue;
    final pos = watchHistoryInt(item['position']);
    final dur = watchHistoryInt(item['duration']);
    if (!isInProgressResume(pos, dur)) continue;
    final ts = watchHistoryInt(item['updatedAt']);
    final bestTs = best == null ? -1 : watchHistoryInt(best['updatedAt'], -1);
    if (ts > bestTs) best = item;
  }
  return best;
}

/// One latest in-progress item per tmdbId (Continue Watching pool).
List<Map<String, dynamic>> inProgressPoolByShow(
  List<Map<String, dynamic>> history,
) {
  final byShow = <int, Map<String, dynamic>>{};
  for (final item in history) {
    final pos = watchHistoryInt(item['position']);
    final dur = watchHistoryInt(item['duration']);
    if (!isInProgressResume(pos, dur)) continue;
    final tmdbId = watchHistoryInt(item['tmdbId'], -1);
    if (tmdbId < 0) continue;
    final existing = byShow[tmdbId];
    final ts = watchHistoryInt(item['updatedAt']);
    final existingTs =
        existing == null ? -1 : watchHistoryInt(existing['updatedAt'], -1);
    if (ts > existingTs) byShow[tmdbId] = item;
  }
  return byShow.values.toList();
}
