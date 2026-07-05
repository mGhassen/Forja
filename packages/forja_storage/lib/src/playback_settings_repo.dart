import 'package:shared_preferences/shared_preferences.dart';

class PlaybackSettingsRepo {
  static const _autoNextKey = 'forja_auto_next';
  static const _externalPlayerKey = 'forja_external_player';

  Future<bool> getAutoNext() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoNextKey) ?? true;
  }

  Future<void> setAutoNext(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNextKey, value);
  }

  Future<String> getExternalPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_externalPlayerKey) ?? 'Built-in Player';
  }

  Future<void> setExternalPlayer(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_externalPlayerKey, value);
  }
}
