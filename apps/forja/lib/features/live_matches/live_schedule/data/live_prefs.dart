import 'package:shared_preferences/shared_preferences.dart';

/// Live Sports hub prefs — catalog filter, schedule window, view.
///
/// Mode prefs (`live_matches_mode_v1` / `live_matches_server_v1`) are retired
/// (RFC-073); browse is always the catalog schedule.
abstract final class LivePrefs {
  LivePrefs._();

  static const viewKey = 'live_matches_timeline_view';
  static const catalogFilterKey = 'live_matches_forja_catalog_filter_v1';
  static const scheduleKey = 'live_matches_schedule_v2';
  static const timeWindowLegacyKey = 'live_matches_time_window_v1';

  static const _retiredModeKey = 'live_matches_mode_v1';
  static const _retiredServerKey = 'live_matches_server_v1';

  /// Drop retired mode/server prefs once (no-op if already gone).
  static Future<void> clearRetiredModePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_retiredModeKey);
    await prefs.remove(_retiredServerKey);
  }
}
