/// Picks director or creator name from a crew list of `{job, name}` maps.
String? pickDirectorFromCrew(List<Map<String, String>> crew) {
  for (final c in crew) {
    final job = (c['job'] ?? '').toLowerCase();
    if (job.contains('director')) return c['name'];
  }
  for (final c in crew) {
    final job = (c['job'] ?? '').toLowerCase();
    if (job.contains('creator')) return c['name'];
  }
  return null;
}
