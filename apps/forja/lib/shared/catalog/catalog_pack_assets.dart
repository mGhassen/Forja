import 'dart:io';

import 'package:forja/shared/catalog/forja_host_assets.dart';
import 'package:forja/shared/engine/plugin_registry.dart';

/// Resolves pack-relative asset paths from a hub plugin manifest URL.
abstract final class CatalogPackAssets {
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

  /// True when [ref] is a pack-owned nav icon (relative path or http(s)).
  static bool isPackNavIcon(String? ref) {
    final s = ref?.trim() ?? '';
    if (s.isEmpty) return false;
    if (s.startsWith('forja://')) return false;
    if (s.startsWith('assets/')) return false;
    if (s.startsWith('http://') || s.startsWith('https://')) return true;
    if (s.startsWith('file://')) return true;
    if (s.contains('..')) return false;
    return true;
  }

  /// Resolve [nav.icon] to a display path for [NavDestination.iconAsset].
  ///
  /// Returns a Flutter `assets/…` path, an absolute file path, or an http(s)
  /// URL. Null → use Material default.
  static String? resolveNavIconDisplay({
    required String? packSourceUrl,
    required String? icon,
  }) {
    final raw = icon?.trim() ?? '';
    if (raw.isEmpty) return null;

    final host = ForjaHostAssets.resolveFlutterPath(raw);
    if (host != null) return host;

    if (raw.startsWith('forja://')) return null;
    if (raw.startsWith('assets/')) return null;
    if (!isPackNavIcon(raw)) return null;

    final resolved = resolveUrl(packSourceUrl: packSourceUrl, relative: raw);
    if (resolved.isEmpty) return null;

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return resolved;
    }

    final file = asLocalFile(resolved);
    if (file != null) {
      return file.existsSync() ? file.path : null;
    }
    return null;
  }

  /// Host Flutter assets are single-color glyphs — tint to rail color.
  /// Pack / remote bitmaps keep their own colors (e.g. cartoon mascot).
  static bool navIconShouldTint(String? displayPath) {
    final p = displayPath?.trim() ?? '';
    return p.startsWith('assets/');
  }
}
