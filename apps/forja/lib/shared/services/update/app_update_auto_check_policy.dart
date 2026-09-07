/// Pure rules for in-session / auto update checks (RFC-015 R15-A08 / R15-A09).
class AppUpdateAutoCheckPolicy {
  AppUpdateAutoCheckPolicy._();

  /// Minimum gap between automatic network checks while the shell is open.
  static const Duration minCheckInterval = Duration(hours: 1);

  /// Whether a background network check should run now.
  static bool shouldNetworkCheck({
    required DateTime now,
    required DateTime? lastCheckAt,
    required bool autoCheckEnabled,
    Duration interval = minCheckInterval,
  }) {
    if (!autoCheckEnabled) return false;
    if (lastCheckAt == null) return true;
    return !now.isBefore(lastCheckAt.add(interval));
  }

  /// Whether an available update should prompt the user.
  ///
  /// Skips when the user already dismissed this exact [latestVersion]
  /// ("Later" / "Skip for now").
  static bool shouldPrompt({
    required String latestVersion,
    required String? dismissedVersion,
  }) {
    final latest = latestVersion.trim();
    if (latest.isEmpty) return false;
    final dismissed = dismissedVersion?.trim();
    if (dismissed == null || dismissed.isEmpty) return true;
    return dismissed != latest;
  }
}
