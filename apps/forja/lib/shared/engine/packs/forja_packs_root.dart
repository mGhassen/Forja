import 'dart:io';

import 'package:flutter/foundation.dart';

/// Optional local packs tree for debug script hot-reload.
///
/// **Only** `FORJA_PACKS_ROOT` (dart-define or process env). No sibling repo
/// invent, no baked pack inventory — published / official / recommended come
/// from the admin catalog ([PluginCatalogRemote]).
abstract final class ForjaPacksRoot {
  /// Absolute path to the env packs root, or null.
  static String? resolve({bool requireDebug = true}) {
    if (requireDebug && !kDebugMode) return null;
    final explicit = _packsRootEnv();
    if (explicit.isEmpty) return null;
    final normalized = _norm(explicit);
    if (!Directory(normalized).existsSync()) return null;
    return normalized;
  }

  /// Absolute path to a file under [resolve], or null.
  static String? manifest(
    String relativeUnderPacks, {
    bool requireDebug = true,
  }) {
    final root = resolve(requireDebug: requireDebug);
    if (root == null) return null;
    final rel = relativeUnderPacks
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    final file = File('$root/$rel');
    if (!file.existsSync()) return null;
    return file.path;
  }

  static String _packsRootEnv() {
    var v = const String.fromEnvironment('FORJA_PACKS_ROOT').trim();
    if (v.isEmpty) {
      v = Platform.environment['FORJA_PACKS_ROOT']?.trim() ?? '';
    }
    return v;
  }

  static String _norm(String path) {
    final cleaned = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    try {
      return Directory(cleaned).absolute.path.replaceAll('\\', '/');
    } catch (_) {
      return cleaned;
    }
  }
}
