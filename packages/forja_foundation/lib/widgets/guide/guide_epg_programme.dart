/// Opaque EPG programme row for guide paint (host maps portal `EpgEntry`).
class GuideEpgProgramme {
  final String title;
  final String description;
  final DateTime start;
  final DateTime stop;

  const GuideEpgProgramme({
    required this.title,
    required this.start,
    required this.stop,
    this.description = '',
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(stop);
  }
}
