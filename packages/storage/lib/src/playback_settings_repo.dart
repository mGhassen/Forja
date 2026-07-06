import 'package:rust/rust.dart';

class PlaybackSettingsRepo {
  static const _autoNextKey = 'forja_auto_next';
  static const _externalPlayerKey = 'forja_external_player';

  Future<bool> getAutoNext() async {
    if (!Engine.isReady) return true;
    return Engine.storageReadBool(_autoNextKey, fallback: true);
  }

  Future<void> setAutoNext(bool value) async {
    if (!Engine.isReady) return;
    Engine.storageWriteBool(_autoNextKey, value);
  }

  Future<String> getExternalPlayer() async {
    if (!Engine.isReady) return 'Built-in Player';
    return Engine.storageReadString(
      _externalPlayerKey,
      fallback: 'Built-in Player',
    );
  }

  Future<void> setExternalPlayer(String value) async {
    if (!Engine.isReady) return;
    Engine.storageWriteString(_externalPlayerKey, value);
  }
}
