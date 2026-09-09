import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/plugin_registry.dart';
import 'package:forja/shared/engine/packs/plugin_script_disk_store.dart';
import 'package:forja/shared/foundation/lib/pack_assets.dart';

/// Resolves GOAT / GASM / sportsembed unlock modules from the live pack.
///
/// Host owns Node/WebView runtime; packs own crack scripts + wasm (RFC-099).
/// Flutter `assets/plugins/live/…` remains a last-resort fallback.
abstract final class LiveUnlockModules {
  static const goat = 'goat';
  static const gasm = 'gasm';
  static const sportsembed = 'sportsembed';

  static const _assetRoot = 'assets/plugins/live';

  /// Prefer local live checkout when present, else enabled ForjaHQ `live`
  /// pack, else any pack whose bundle lists `goat/unlock.mjs`.
  static Future<String?> livePackSourceUrl() async {
    final registry = PluginRegistry.instance;
    final packs = await registry.listPacksRaw();
    EnginePack? liveSlot;
    EnginePack? goatBundle;
    for (final pack in packs) {
      if (!pack.enabled) continue;
      if (EnginePack.forjaHqSlot(pack.sourceUrl) == 'live') {
        liveSlot ??= pack;
      }
      if (pack.bundle.any((p) => p.replaceAll('\\', '/') == 'goat/unlock.mjs')) {
        goatBundle ??= pack;
      }
    }

    if (liveSlot != null &&
        PluginRegistry.isLocalManifestUrl(liveSlot.sourceUrl)) {
      return liveSlot.sourceUrl;
    }

    if (kDebugMode) {
      final local = _debugLiveManifestPath();
      if (local != null) {
        final goat = PackAssets.asLocalFile(
          registry.resolveScriptUrl(local, 'goat/unlock.mjs'),
        );
        if (goat != null && await goat.exists()) return local;
      }
    }

    return liveSlot?.sourceUrl ?? goatBundle?.sourceUrl;
  }

  static String? _debugLiveManifestPath() {
    var explicit = const String.fromEnvironment(
      'FORJA_HQ_LIVE_MANIFEST_URL',
    ).trim();
    if (explicit.isEmpty) {
      explicit =
          Platform.environment['FORJA_HQ_LIVE_MANIFEST_URL']?.trim() ?? '';
    }
    if (explicit.isNotEmpty) return explicit;

    var root = const String.fromEnvironment('FORJA_REPO_ROOT').trim();
    if (root.isEmpty) {
      root = Platform.environment['FORJA_REPO_ROOT']?.trim() ?? '';
    }
    if (root.isNotEmpty) {
      final normalized = root
          .replaceAll('\\', '/')
          .replaceAll(RegExp(r'/+$'), '');
      final candidate = File('$normalized/plugins/live/manifest.json');
      if (candidate.existsSync()) return candidate.path;
    }

    var dir = Directory.current;
    for (var i = 0; i < 8; i++) {
      final candidate = File('${dir.path}/plugins/live/manifest.json');
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Absolute file for `module/relative` from pack install or local checkout.
  static Future<File?> resolvePackFile({
    required String module,
    required String relative,
  }) async {
    final rel = '$module/${relative.replaceAll('\\', '/')}';
    final sourceUrl = await livePackSourceUrl();
    if (sourceUrl == null || sourceUrl.isEmpty) return null;

    if (PluginRegistry.isLocalManifestUrl(sourceUrl)) {
      final path = PluginRegistry.instance.resolveScriptUrl(sourceUrl, rel);
      final file = PackAssets.asLocalFile(path);
      if (file != null && await file.exists()) return file;
      return null;
    }

    return PluginScriptDiskStore.packRelativeFile(
      sourceUrl: sourceUrl,
      relative: rel,
    );
  }

  /// Copy module file → [dest]. Pack first, then Flutter asset fallback.
  static Future<void> writeTo({
    required String module,
    required String relative,
    required File dest,
  }) async {
    final packFile = await resolvePackFile(module: module, relative: relative);
    if (packFile != null) {
      final parent = dest.parent;
      if (!await parent.exists()) await parent.create(recursive: true);
      await packFile.copy(dest.path);
      return;
    }

    final assetPath = '$_assetRoot/$module/$relative';
    final data = await rootBundle.load(assetPath);
    final parent = dest.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await dest.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    debugPrint(
      '[LiveUnlockModules] fallback Flutter asset $assetPath → ${dest.path}',
    );
  }

  /// Bytes for WebView local server (pack or asset).
  static Future<Uint8List> loadBytes({
    required String module,
    required String relative,
  }) async {
    final packFile = await resolvePackFile(module: module, relative: relative);
    if (packFile != null) {
      return Uint8List.fromList(await packFile.readAsBytes());
    }
    final data = await rootBundle.load('$_assetRoot/$module/$relative');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
