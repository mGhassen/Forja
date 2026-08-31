import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk cache for Engine + Nuvio plugin JS (Application Support).
///
/// Pack metadata stays in SharedPreferences / KV. Local checkout manifests
/// never write here — callers skip disk for those paths.
abstract final class PluginScriptDiskStore {
  static const subdir = 'plugin_scripts_v1';

  /// Test override — when set, all paths resolve under this directory.
  @visibleForTesting
  static Directory? debugRoot;

  static Directory? _cachedRoot;

  @visibleForTesting
  static void resetForTest() {
    debugRoot = null;
    _cachedRoot = null;
  }

  static Future<Directory> root() async {
    final debug = debugRoot;
    if (debug != null) {
      if (!await debug.exists()) {
        await debug.create(recursive: true);
      }
      return debug;
    }
    final cached = _cachedRoot;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedRoot = dir;
    return dir;
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
