import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-disk cache for Engine + Nuvio plugin JS (Application Support).
///
/// Layout: `plugin_scripts_v1/accounts/{accountId}/profiles/{profileId}/…`
/// Guest / signed-out: `accounts/local/profiles/default/…`
///
/// Pack metadata stays in SharedPreferences / KV. Local checkout manifests
/// never write here — callers skip disk for those paths.
abstract final class PluginScriptDiskStore {
  static const subdir = 'plugin_scripts_v1';
  static const _legacyMigratedKey = 'plugin_scripts_scoped_v1_migrated';

  /// Test override — when set, all paths resolve under this directory (flat).
  @visibleForTesting
  static Directory? debugRoot;

  static Directory? _cachedRoot;
  static String _accountId = 'local';
  static String _profileId = 'default';

  @visibleForTesting
  static void resetForTest() {
    debugRoot = null;
    _cachedRoot = null;
    _accountId = 'local';
    _profileId = 'default';
  }

  /// Active account + profile — must track [SyncService.selectProfile].
  static Future<void> configureScope({
    required String? accountId,
    required String? profileId,
  }) async {
    final account = _sanitizePathSegment(accountId ?? 'local');
    final profile = _sanitizePathSegment(profileId ?? 'default');
    if (_accountId == account && _profileId == profile) return;
    _accountId = account;
    _profileId = profile;
    _cachedRoot = null;
    await _migrateLegacyLayoutIfNeeded();
  }

  static String _sanitizePathSegment(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'default';
    return t.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  static Future<Directory> root() async {
    final cached = _cachedRoot;
    if (cached != null) return cached;

    final String basePath;
    if (debugRoot != null) {
      basePath = debugRoot!.path;
    } else {
      final support = await getApplicationSupportDirectory();
      basePath = p.join(support.path, subdir);
    }

    final dir = Directory(
      p.join(
        basePath,
        'accounts',
        _accountId,
        'profiles',
        _profileId,
      ),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedRoot = dir;
    return dir;
  }

  static Future<Directory> _legacyFlatRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, subdir));
  }

  /// One-time: flat `plugin_scripts_v1/{engine,nuvio}` → active profile scope.
  static Future<void> _migrateLegacyLayoutIfNeeded() async {
    if (debugRoot != null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyMigratedKey) == true) return;

    final legacy = await _legacyFlatRoot();
    final legacyEngine = Directory(p.join(legacy.path, 'engine'));
    final legacyNuvio = Directory(p.join(legacy.path, 'nuvio'));
    final hasLegacy =
        await legacyEngine.exists() || await legacyNuvio.exists();
    if (!hasLegacy) {
      await prefs.setBool(_legacyMigratedKey, true);
      return;
    }

    final target = await root();
    for (final entry in [
      (legacyEngine, 'engine'),
      (legacyNuvio, 'nuvio'),
    ]) {
      final src = entry.$1;
      if (!await src.exists()) continue;
      final dest = Directory(p.join(target.path, entry.$2));
      if (await dest.exists()) {
        await dest.delete(recursive: true);
      }
      await src.rename(dest.path);
    }

    await prefs.setBool(_legacyMigratedKey, true);
    debugPrint(
      '[PluginScriptDiskStore] migrated legacy scripts → '
      'accounts/$_accountId/profiles/$_profileId',
    );
  }

  static String packHash(String sourceUrl) => EnginePack.urlHash(sourceUrl);

  static String digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static Future<Directory> _enginePackDir(String sourceUrl) async {
    final r = await root();
    return Directory(p.join(r.path, 'engine', packHash(sourceUrl)));
  }

  static Future<File> _engineScriptFile(
    String sourceUrl,
    String pluginId,
  ) async {
    final pack = await _enginePackDir(sourceUrl);
    return File(p.join(pack.path, 'plugins', '$pluginId.js'));
  }

  static Future<File> _enginePreludeFile(
    String sourceUrl,
    String preludeEntry,
  ) async {
    final pack = await _enginePackDir(sourceUrl);
    return File(
      p.join(pack.path, 'preludes', '${digest(preludeEntry)}.js'),
    );
  }

  static Future<File> _nuvioScraperFile(String scraperId) async {
    final r = await root();
    return File(p.join(r.path, 'nuvio', '${digest(scraperId)}.js'));
  }

  /// Atomic write: temp in parent → rename to [target].
  static Future<void> _atomicWrite(File target, String body) async {
    final parent = target.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final tmp = File(
      p.join(
        parent.path,
        '.${p.basename(target.path)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await tmp.writeAsString(body, flush: true);
      if (await target.exists()) {
        await target.delete();
      }
      await tmp.rename(target.path);
    } catch (e) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<bool> hasEngineScript({
    required String sourceUrl,
    required String pluginId,
  }) async {
    try {
      return await (await _engineScriptFile(sourceUrl, pluginId)).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasEnginePrelude({
    required String sourceUrl,
    required String preludeEntry,
  }) async {
    try {
      return await (await _enginePreludeFile(sourceUrl, preludeEntry)).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<String?> loadEngineScript({
    required String sourceUrl,
    required String pluginId,
  }) async {
    try {
      final file = await _engineScriptFile(sourceUrl, pluginId);
      if (!await file.exists()) return null;
      final body = await file.readAsString();
      return body.isEmpty ? null : body;
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] loadEngineScript failed: $e');
      return null;
    }
  }

  static Future<String?> loadEnginePrelude({
    required String sourceUrl,
    required String preludeEntry,
  }) async {
    try {
      final file = await _enginePreludeFile(sourceUrl, preludeEntry);
      if (!await file.exists()) return null;
      final body = await file.readAsString();
      return body.isEmpty ? null : body;
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] loadEnginePrelude failed: $e');
      return null;
    }
  }

  static Future<void> saveEngineScript({
    required String sourceUrl,
    required String pluginId,
    required String body,
  }) async {
    await _atomicWrite(await _engineScriptFile(sourceUrl, pluginId), body);
  }

  static Future<void> saveEnginePrelude({
    required String sourceUrl,
    required String preludeEntry,
    required String body,
  }) async {
    await _atomicWrite(
      await _enginePreludeFile(sourceUrl, preludeEntry),
      body,
    );
  }

  static Future<void> removeEngineScript({
    required String sourceUrl,
    required String pluginId,
  }) async {
    try {
      final file = await _engineScriptFile(sourceUrl, pluginId);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] removeEngineScript failed: $e');
    }
  }

  static Future<void> removeEnginePrelude({
    required String sourceUrl,
    required String preludeEntry,
  }) async {
    try {
      final file = await _enginePreludeFile(sourceUrl, preludeEntry);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] removeEnginePrelude failed: $e');
    }
  }

  /// Deletes the whole `engine/<hash>/` tree for [sourceUrl].
  static Future<void> removeEnginePack(String sourceUrl) async {
    try {
      final dir = await _enginePackDir(sourceUrl);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] removeEnginePack failed: $e');
    }
  }

  static Future<bool> hasNuvioScraper(String scraperId) async {
    try {
      return await (await _nuvioScraperFile(scraperId)).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<String?> loadNuvioScraper(String scraperId) async {
    try {
      final file = await _nuvioScraperFile(scraperId);
      if (!await file.exists()) return null;
      final body = await file.readAsString();
      return body.isEmpty ? null : body;
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] loadNuvioScraper failed: $e');
      return null;
    }
  }

  static Future<void> saveNuvioScraper({
    required String scraperId,
    required String body,
  }) async {
    await _atomicWrite(await _nuvioScraperFile(scraperId), body);
  }

  static Future<void> removeNuvioScraper(String scraperId) async {
    try {
      final file = await _nuvioScraperFile(scraperId);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[PluginScriptDiskStore] removeNuvioScraper failed: $e');
    }
  }
}
