import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';
import 'package:forja/shared/host/packs/pack_assets.dart';

/// Pack-relative file loader for the opaque live unlock runtime.
///
/// Host never names unlock recipes (goat/gasm/…). Callers pass paths relative
/// to the **calling** pack ([LiveUnlockScope.packSourceUrl]).
abstract final class PackUnlockFiles {
  /// Optional Flutter asset root for last-resort fallback (`relative` as-is).
  static const assetRoot = 'assets/plugins/live';

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

  /// Copy pack-relative [relative] → [dest]. Pack first, then asset fallback.
  static Future<void> writeTo({
    required String packSourceUrl,
    required String relative,
    required File dest,
  }) async {
    final packFile = await resolve(
      packSourceUrl: packSourceUrl,
      relative: relative,
    );
    if (packFile != null) {
      final parent = dest.parent;
      if (!await parent.exists()) await parent.create(recursive: true);
      await packFile.copy(dest.path);
      return;
    }

    final rel = relative.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final assetPath = '$assetRoot/$rel';
    final data = await rootBundle.load(assetPath);
    final parent = dest.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await dest.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    debugPrint('[PackUnlockFiles] asset fallback $assetPath → ${dest.path}');
  }

  static Future<Uint8List> loadBytes({
    required String packSourceUrl,
    required String relative,
  }) async {
    final packFile = await resolve(
      packSourceUrl: packSourceUrl,
      relative: relative,
    );
    if (packFile != null) {
      return Uint8List.fromList(await packFile.readAsBytes());
    }
    final rel = relative.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final data = await rootBundle.load('$assetRoot/$rel');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// Calling pack for unlock file resolution (set while a live plugin runs).
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
