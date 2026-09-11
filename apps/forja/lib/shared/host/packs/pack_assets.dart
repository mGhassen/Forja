import 'dart:io';

import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';

/// Resolves pack-relative asset paths from a hub plugin manifest URL.
abstract final class PackAssets {
  static String resolveUrl({
    required String? packSourceUrl,
    required String relative,
  }) {
    final raw = relative.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('file://')) return raw;
    final base = packSourceUrl?.trim() ?? '';
    if (base.isEmpty) return raw;
    return PluginRegistry.instance.resolveScriptUrl(base, raw);
  }

  static File? asLocalFile(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('file://')) {
      return File(Uri.parse(raw).toFilePath());
    }
    if (raw.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(raw)) {
      return File(raw);
    }
    return null;
  }

  /// True when [ref] is a pack-owned asset (relative path or http(s)).
  static bool isPackAsset(String? ref) {
    final s = ref?.trim() ?? '';
    if (s.isEmpty) return false;
    if (s.startsWith('forja://')) return false;
    if (s.startsWith('assets/')) return false;
    if (s.startsWith('http://') || s.startsWith('https://')) return true;
    if (s.startsWith('file://')) return true;
    if (s.contains('..')) return false;
    return true;
  }

  /// Pack-relative path only (not absolute http(s) / file).
  static bool isPackRelativeAsset(String? ref) {
    final s = ref?.trim() ?? '';
    if (!isPackAsset(s)) return false;
    if (s.startsWith('http://') || s.startsWith('https://')) return false;
    if (s.startsWith('file://')) return false;
    return true;
  }

  /// Alias — hub nav icons use the same rules as other pack assets.
  static bool isPackNavIcon(String? ref) => isPackAsset(ref);

  /// Alias — pack-relative nav icon / logo path.
  static bool isPackRelativeNavIcon(String? ref) => isPackRelativeAsset(ref);

  /// Resolve a pack asset ([nav.icon], `logos/…`, …) for display.
  ///
  /// Prefers an on-disk pack file (checkout or [PluginScriptDiskStore]) so the
  /// UI does not depend on a live CDN fetch. Falls back to http(s) when the
  /// file is not cached yet.
  ///
  /// Returns an absolute file path or http(s) URL. Null → caller fallback.
  static Future<String?> resolvePackAssetDisplay({
    required String? packSourceUrl,
    required String? relative,
  }) async {
    final raw = relative?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('forja://')) return null;
    if (raw.startsWith('assets/')) return null;
    if (!isPackAsset(raw)) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final base = packSourceUrl?.trim() ?? '';
    final resolved = resolveUrl(packSourceUrl: packSourceUrl, relative: raw);
    if (resolved.isEmpty) return null;

    final file = asLocalFile(resolved);
    if (file != null) {
      return file.existsSync() ? file.path : null;
    }

    if (base.isNotEmpty &&
        !PluginRegistry.isLegacyAssetPack(base) &&
        !PluginRegistry.isLocalManifestUrl(base) &&
        isPackRelativeAsset(raw)) {
      final disk = await PluginScriptDiskStore.packRelativeFile(
        sourceUrl: base,
        relative: raw,
      );
      if (disk != null) return disk.path;
    }

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return resolved;
    }
    return null;
  }

  /// Alias for [resolvePackAssetDisplay] (hub nav icons).
  static Future<String?> resolveNavIconDisplay({
    required String? packSourceUrl,
    required String? icon,
  }) =>
      resolvePackAssetDisplay(packSourceUrl: packSourceUrl, relative: icon);
}
