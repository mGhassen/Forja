import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs-backed URL sets for remote pack handshake (install defer / pending purge).
abstract final class _RemotePackUrlSet {
  static Future<Set<String>> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? const <String>[];
    return {
      for (final u in raw)
        if (u.trim().isNotEmpty) u.trim(),
    };
  }

  static Future<void> write(String key, Set<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    final list = urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList()
      ..sort();
    await prefs.setStringList(key, list);
    RemotePackIntentStore.changeNotifier.value++;
  }

  static String _norm(String url) => url.trim();

  static Future<bool> contains(String key, String url) async {
    final want = _norm(url);
    if (want.isEmpty) return false;
    return (await read(key)).contains(want);
  }

  static Future<void> add(String key, String url) async {
    final want = _norm(url);
    if (want.isEmpty) return;
    final next = await read(key);
    if (!next.add(want)) return;
    await write(key, next);
  }

  static Future<void> remove(String key, String url) async {
    final want = _norm(url);
    if (want.isEmpty) return;
    final next = await read(key);
    if (!next.remove(want)) return;
    await write(key, next);
  }

  static Future<void> clearAll(String key) async {
    final next = await read(key);
    if (next.isEmpty) return;
    await write(key, {});
  }
}

/// Bumped when deferred-install or pending-purge sets change.
abstract final class RemotePackIntentStore {
  static final ValueNotifier<int> changeNotifier = ValueNotifier(0);

  @visibleForTesting
  static void resetSignalsForTest() {
    changeNotifier.value = 0;
  }
}

/// User tapped Not now on a remote-profile install prompt.
abstract final class DeferredRemoteInstallStore {
  static const _key = 'engine_deferred_remote_install_v1';

  static Future<Set<String>> read() => _RemotePackUrlSet.read(_key);

  static Future<bool> contains(String manifestUrl) =>
      _RemotePackUrlSet.contains(_key, manifestUrl);

  static Future<void> defer(String manifestUrl) =>
      _RemotePackUrlSet.add(_key, manifestUrl);

  static Future<void> clear(String manifestUrl) =>
      _RemotePackUrlSet.remove(_key, manifestUrl);

  static Future<void> clearAll() => _RemotePackUrlSet.clearAll(_key);
}

/// User tapped After this session on a remote-profile uninstall prompt.
/// URLs must be omitted from Forja cloud export so they cannot resurrect.
abstract final class PendingRemotePurgeStore {
  static const _key = 'engine_pending_remote_purge_v1';

  static Future<Set<String>> read() => _RemotePackUrlSet.read(_key);

  static Future<bool> contains(String manifestUrl) =>
      _RemotePackUrlSet.contains(_key, manifestUrl);

  static Future<void> defer(String manifestUrl) =>
      _RemotePackUrlSet.add(_key, manifestUrl);

  static Future<void> clear(String manifestUrl) =>
      _RemotePackUrlSet.remove(_key, manifestUrl);

  static Future<void> clearAll() => _RemotePackUrlSet.clearAll(_key);
}
