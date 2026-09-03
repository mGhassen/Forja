import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_mode_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live Sports hub prefs (RFC-071). Migrates `live_matches_server_v1` → `mode_v1`.
abstract final class LivePrefs {
  LivePrefs._();

  static const modeKey = LiveModeRegistry.modePreferenceKey;
  static const legacyServerKey = LiveModeRegistry.legacyServerPreferenceKey;
  static const viewKey = 'live_matches_timeline_view';
  static const catalogFilterKey = 'live_matches_forja_catalog_filter_v1';
  static const scheduleKey = 'live_matches_schedule_v2';
  static const timeWindowLegacyKey = 'live_matches_time_window_v1';

  static Future<LiveModeId> readMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(modeKey) ?? prefs.getString(legacyServerKey);
    final mode = LiveModeIdX.tryParse(raw) ?? LiveModeId.forjaLive;
    if (prefs.containsKey(legacyServerKey)) {
      await prefs.setString(modeKey, mode.wireId);
      await prefs.remove(legacyServerKey);
    }
    return mode;
  }

  static Future<void> writeMode(LiveModeId mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modeKey, mode.wireId);
    await prefs.remove(legacyServerKey);
  }
}
