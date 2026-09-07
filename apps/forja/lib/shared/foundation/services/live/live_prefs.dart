import 'package:shared_preferences/shared_preferences.dart';

/// Live Sports hub prefs — catalog filter, schedule window, view.
///
/// Retired mode/server keys and pre-rename `live_matches_*` storage keys are
/// migrated / dropped on read (RFC-073 · RFC-087).
abstract final class LivePrefs {
  LivePrefs._();

  static const viewKey = 'live_sports_timeline_view';
  static const catalogFilterKey = 'live_sports_forja_catalog_filter_v1';
  static const scheduleKey = 'live_sports_schedule_v2';
  static const timeWindowLegacyKey = 'live_sports_time_window_v1';

  static const _legacyViewKey = 'live_matches_timeline_view';
  static const _legacyCatalogFilterKey = 'live_matches_forja_catalog_filter_v1';
  static const _legacyScheduleKey = 'live_matches_schedule_v2';
  static const _legacyTimeWindowKey = 'live_matches_time_window_v1';

  static const _retiredModeKey = 'live_matches_mode_v1';
  static const _retiredServerKey = 'live_matches_server_v1';

  /// Read [key], falling back to [legacyKey] and copying forward once.
  static Future<String?> getStringMigrated(
    SharedPreferences prefs,
    String key,
    String legacyKey,
  ) async {
    final cur = prefs.getString(key);
    if (cur != null) return cur;
    final legacy = prefs.getString(legacyKey);
    if (legacy == null) return null;
    await prefs.setString(key, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }

  /// Drop retired mode/server prefs once (no-op if already gone).
  static Future<void> clearRetiredModePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_retiredModeKey);
    await prefs.remove(_retiredServerKey);
    await prefs.remove(_legacyTimeWindowKey);
  }

  static String get legacyCatalogFilterKey => _legacyCatalogFilterKey;
  static String get legacyScheduleKey => _legacyScheduleKey;
  static String get legacyViewKey => _legacyViewKey;
  static String get legacyTimeWindowKey => _legacyTimeWindowKey;
}
