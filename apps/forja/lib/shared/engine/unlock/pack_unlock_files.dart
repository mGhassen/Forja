import 'dart:io';
import 'dart:typed_data';

import 'package:forja/shared/engine/packs/pack_assets.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';

/// Pack-relative file loader for the opaque unlock runtime.
///
/// Host never names unlock recipes (goat/gasm/…). Callers pass paths relative
/// to the **calling** pack ([LiveUnlockScope.packSourceUrl]).
/// Unlock modules ship in the pack `bundle` only — no Flutter asset fallback.
abstract final class PackUnlockFiles {
  static Future<File?> resolve({
    required String packSourceUrl,
    required String relative,
  }) async {
    final rel = relative.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (rel.isEmpty || packSourceUrl.trim().isEmpty) return null;

    if (PluginRegistry.isLocalManifestUrl(packSourceUrl)) {
      final path = PluginRegistry.instance.resolveScriptUrl(packSourceUrl, rel);
      final file = PackAssets.asLocalFile(path);
      if (file != null && await file.exists()) return file;
      return null;
    }

    return PluginScriptDiskStore.packRelativeFile(
      sourceUrl: packSourceUrl,
      relative: rel,
    );
  }

  /// Copy pack-relative [relative] → [dest]. Missing pack file → [StateError].
  static Future<void> writeTo({
    required String packSourceUrl,
    required String relative,
    required File dest,
  }) async {
    final packFile = await resolve(
      packSourceUrl: packSourceUrl,
      relative: relative,
    );
    if (packFile == null) {
      throw StateError(
        'live unlock: pack file missing ($relative) for $packSourceUrl',
      );
    }
    final parent = dest.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await packFile.copy(dest.path);
  }

  static Future<Uint8List> loadBytes({
    required String packSourceUrl,
    required String relative,
  }) async {
    final packFile = await resolve(
      packSourceUrl: packSourceUrl,
      relative: relative,
    );
    if (packFile == null) {
      throw StateError(
        'live unlock: pack file missing ($relative) for $packSourceUrl',
      );
    }
    return Uint8List.fromList(await packFile.readAsBytes());
  }
}

/// Calling pack for unlock file resolution (set while a pack unlock runs).
abstract final class LiveUnlockScope {
  static String? packSourceUrl;

  /// Pack-relative staging map for the active recipe (`from` pack path → `to` workdir).
  static List<({String from, String to})>? recipeFiles;

  static Future<T> runWithPack<T>(
    String? sourceUrl,
    Future<T> Function() body, {
    List<({String from, String to})>? files,
  }) async {
    final prevUrl = packSourceUrl;
    final prevFiles = recipeFiles;
    final next = sourceUrl?.trim();
    if (next != null && next.isNotEmpty) packSourceUrl = next;
    if (files != null) recipeFiles = files;
    try {
      return await body();
    } finally {
      packSourceUrl = prevUrl;
      recipeFiles = prevFiles;
    }
  }

  static String requirePackSourceUrl() {
    final url = packSourceUrl?.trim() ?? '';
    if (url.isEmpty) {
      throw StateError('live unlock: no packSourceUrl in scope');
    }
    return url;
  }
}
