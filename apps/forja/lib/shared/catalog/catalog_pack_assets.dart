import 'dart:io';

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
    if (raw.startsWith('/') || RegExp(r'^[A-Za-z]:\\').hasMatch(raw)) {
      return File(raw);
    }
    return null;
  }
}
