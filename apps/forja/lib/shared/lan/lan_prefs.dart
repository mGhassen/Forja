import 'package:rust/rust.dart';

/// Persisted LAN client pairing state (token, server address).
class LanPrefs {
  LanPrefs._();
  static final LanPrefs instance = LanPrefs._();

  static const _tokenKey = 'lan_client_token';
  static const _serverHostKey = 'lan_server_host';
  static const _serverPortKey = 'lan_server_port';
  static const _serverIdKey = 'lan_server_id';
  static const _deviceIdKey = 'lan_device_id';
  static const _serverEnabledKey = 'lan_server_enabled';
  static const _allowLocalTorrentKey = 'lan_allow_local_torrent';

  Future<String> deviceId() async {
    final existing = await kvGetString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'device-${DateTime.now().millisecondsSinceEpoch}';
    await kvSetString(_deviceIdKey, id);
    return id;
  }

  Future<String?> get token => kvGetString(_tokenKey);

  Future<void> setToken(String? value) async {
    if (value == null || value.isEmpty) {
      await kvSetString(_tokenKey, '');
    } else {
      await kvSetString(_tokenKey, value);
    }
  }

  Future<String?> get serverHost async {
    final h = await kvGetString(_serverHostKey);
    if (h == null || h.isEmpty) return null;
    return h;
  }

  Future<int?> get serverPort async {
    final v = await kvGetInt(_serverPortKey, fallback: 0);
    return v > 0 ? v : null;
  }

  Future<String?> get serverId => kvGetString(_serverIdKey);

  Future<void> setServer({
    required String host,
    required int port,
    String? serverId,
  }) async {
    await kvSetString(_serverHostKey, host);
    await kvSetInt(_serverPortKey, port);
    if (serverId != null) {
      await kvSetString(_serverIdKey, serverId);
    }
  }

  Future<void> clearServer() async {
    await kvSetString(_serverHostKey, '');
    await kvSetInt(_serverPortKey, 0);
    await kvSetString(_serverIdKey, '');
    await setToken(null);
  }

  Future<bool> isLanServerEnabled() async =>
      kvGetBool(_serverEnabledKey, fallback: false);

  Future<void> setLanServerEnabled(bool enabled) async =>
      kvSetBool(_serverEnabledKey, enabled);

  Future<bool> allowLocalTorrentOnDevice() async =>
      kvGetBool(_allowLocalTorrentKey, fallback: false);

  Future<void> setAllowLocalTorrentOnDevice(bool enabled) async =>
      kvSetBool(_allowLocalTorrentKey, enabled);

  Future<bool> get isPaired async {
    final t = await token;
    final host = await serverHost;
    final port = await serverPort;
    return t != null &&
        t.isNotEmpty &&
        host != null &&
        host.isNotEmpty &&
        port != null;
  }
}
