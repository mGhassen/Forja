import 'package:rust/rust.dart';

class PlaybackSettingsRepo {
  static const _autoNextKey = 'forja_auto_next';
  static const _externalPlayerKey = 'forja_external_player';

  Future<bool> getAutoNext() async {
    if (!ForjaEngine.isReady) return true;
    return ForjaEngine.storageReadBool(_autoNextKey, fallback: true);
  }

  Future<void> setAutoNext(bool value) async {
    if (!ForjaEngine.isReady) return;
    ForjaEngine.storageWriteBool(_autoNextKey, value);
  }

  Future<String> getExternalPlayer() async {
    if (!ForjaEngine.isReady) return 'Built-in Player';
    return ForjaEngine.storageReadString(
      _externalPlayerKey,
      fallback: 'Built-in Player',
    );
  }

  Future<void> setExternalPlayer(String value) async {
    if (!ForjaEngine.isReady) return;
    ForjaEngine.storageWriteString(_externalPlayerKey, value);
  }
}
