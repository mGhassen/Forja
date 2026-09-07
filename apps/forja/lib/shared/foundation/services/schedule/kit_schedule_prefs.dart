import 'package:shared_preferences/shared_preferences.dart';

/// Kit schedule prefs — catalog filter, schedule window, view.
abstract final class KitSchedulePrefs {
  KitSchedulePrefs._();

  static const viewKey = 'live_sports_timeline_view';
  static const catalogFilterKey = 'live_sports_forja_catalog_filter_v1';
  static const scheduleKey = 'live_sports_schedule_v2';
  static const timeWindowLegacyKey = 'live_sports_time_window_v1';

  static Future<String?> getString(SharedPreferences prefs, String key) async {
    return prefs.getString(key);
  }
}
