import 'engine_storage.dart';

class PlaybackSettingsRepo {
  static const _autoNextKey = 'forja_auto_next';
  static const _externalPlayerKey = 'forja_external_player';

  Future<bool> getAutoNext() async {
    return EngineStorage.readBool(_autoNextKey, fallback: true);
  }

  Future<void> setAutoNext(bool value) async {
    EngineStorage.writeBool(_autoNextKey, value);
  }

  Future<String> getExternalPlayer() async {
    return EngineStorage.readString(
      _externalPlayerKey,
      fallback: 'Built-in Player',
    );
  }

  Future<void> setExternalPlayer(String value) async {
    EngineStorage.writeString(_externalPlayerKey, value);
  }
}
