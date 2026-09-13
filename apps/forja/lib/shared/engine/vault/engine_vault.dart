import 'package:rust/rust.dart';

/// Opaque encrypted string vault for packs (`ctx.host.vault`).
///
/// Keys are pack-chosen; host never interprets IPTV / portal semantics.
/// Backed by [SecureSettings] (Keychain / Keystore / prefs vault).
abstract final class EngineVault {
  EngineVault._();

  static const _prefix = 'engine_vault_v1_';

  static String _storageKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return '';
    return '$_prefix$k';
  }

  static Future<String?> get(String key) async {
    final sk = _storageKey(key);
    if (sk.isEmpty) return null;
    final raw = await SecureSettings.read(sk);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static Future<bool> set(String key, String value) async {
    final sk = _storageKey(key);
    if (sk.isEmpty) return false;
    final v = value;
    try {
      if (v.isEmpty) {
        await SecureSettings.delete(sk);
      } else {
        await SecureSettings.write(sk, v);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> remove(String key) async {
    final sk = _storageKey(key);
    if (sk.isEmpty) return false;
    try {
      await SecureSettings.delete(sk);
      return true;
    } catch (_) {
      return false;
    }
  }
}
