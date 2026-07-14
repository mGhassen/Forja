import 'package:forja/shared/playback/settings_data_cleaner.dart';

/// User-triggered playback cache reset (settings / recovery).
abstract final class PlaybackCacheService {
  static Future<void> clearAll() => SettingsDataCleaner.clearStreamCaches();
}
