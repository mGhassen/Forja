import 'package:rust/rust.dart';

/// Opaque encrypted string vault for packs (`ctx.host.vault`).
///
/// Keys are pack-chosen; host never interprets IPTV / portal semantics.
/// Backed by [SecureSettings] (Keychain / Keystore / prefs vault).
/// Storage keys are identity-scoped (RFC-082 / RFC-116).
abstract final class EngineVault {
  EngineVault._();

  static const _prefix = 'engine_vault_v1_';

  static String _storageKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return '';
    return LocalDataScope.storageKey('$_prefix$k');
  }

  static Future<void> _ensureMigrated(String key) async {
    final k = key.trim();
    if (k.isEmpty) return;
    final bare = '$_prefix$k';
    final scoped = LocalDataScope.storageKey(bare);
    if (scoped == bare) return;
    final existing = await SecureSettings.read(scoped);
    if (existing != null && existing.isNotEmpty) return;
    final legacy = await SecureSettings.read(bare);
    if (legacy == null || legacy.isEmpty) return;
    await SecureSettings.write(scoped, legacy);
    await SecureSettings.delete(bare);
  }

  static Future<String?> get(String key) async {
    await _ensureMigrated(key);
    final sk = _storageKey(key);
    if (sk.isEmpty) return null;
    final raw = await SecureSettings.read(sk);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static Future<bool> set(String key, String value) async {
    await _ensureMigrated(key);
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
    await _ensureMigrated(key);
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
