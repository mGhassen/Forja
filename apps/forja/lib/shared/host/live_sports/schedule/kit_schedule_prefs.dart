import 'package:shared_preferences/shared_preferences.dart';

/// Kit schedule prefs — catalog filter, schedule window, list/cards style.
abstract final class KitSchedulePrefs {
  KitSchedulePrefs._();

  /// Persisted list/cards layout for `live_schedule` lists.
  static const styleKey = 'live_sports_list_style';

  /// Alias of [styleKey] (tests / older call sites).
  static const viewKey = styleKey;

  static const mergeUpgradeDoneKey = 'live_sports_hub_merge_v1_done';

  static const styleList = 'list';
  static const styleCards = 'cards';

  static const catalogFilterKey = 'live_sports_forja_catalog_filter_v1';
  static const scheduleKey = 'live_sports_schedule_v2';
  static const timeWindowLegacyKey = 'live_sports_time_window_v1';

  static Future<String?> getString(SharedPreferences prefs, String key) async {
    return prefs.getString(key);
  }
}
