/// Shared continue-watching / in-progress resume rules (2–90% watched).
bool isInProgressResume(int position, int duration) {
  if (duration <= 0) return false;
  final progress = position / duration;
  return progress >= 0.02 && progress < 0.9;
}

/// Latest in-progress history entry for a TV show (by [updatedAt]).
Map<String, dynamic>? latestInProgressForShow(
  int tmdbId,
  List<Map<String, dynamic>> history,
) {
  Map<String, dynamic>? best;
  for (final item in history) {
    if (item['tmdbId'] != tmdbId) continue;
    final pos = (item['position'] as int?) ?? 0;
    final dur = (item['duration'] as int?) ?? 0;
    if (!isInProgressResume(pos, dur)) continue;
    final ts = (item['updatedAt'] as int?) ?? 0;
    final bestTs = (best?['updatedAt'] as int?) ?? -1;
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
    final pos = (item['position'] as int?) ?? 0;
    final dur = (item['duration'] as int?) ?? 0;
    if (!isInProgressResume(pos, dur)) continue;
    final tmdbId = item['tmdbId'] as int?;
    if (tmdbId == null) continue;
    final existing = byShow[tmdbId];
    final ts = (item['updatedAt'] as int?) ?? 0;
    final existingTs = (existing?['updatedAt'] as int?) ?? -1;
    if (ts > existingTs) byShow[tmdbId] = item;
  }
  return byShow.values.toList();
}
