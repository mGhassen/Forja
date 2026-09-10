import 'dart:io';

import 'package:flutter/foundation.dart';

/// Resolves the local [forja-packs](https://github.com/mGhassen/forja-packs)
/// checkout for debug installs and script load.
///
/// Order:
/// 1. `FORJA_PACKS_ROOT` (dart-define or process env)
/// 2. `$FORJA_REPO_ROOT/plugins` (legacy monorepo layout)
/// 3. `$FORJA_REPO_ROOT/../forja-packs` (sibling checkout)
/// 4. Walk up from [Directory.current] for `plugins/` or `forja-packs/` / pack root
abstract final class ForjaPacksRoot {
  /// Absolute path to the packs tree root, or null if not found.
  static String? resolve({bool requireDebug = true}) {
    if (requireDebug && !kDebugMode) return null;

    final explicit = _packsRootEnv();
    if (explicit.isNotEmpty) {
      final normalized = _norm(explicit);
      if (_looksLikePacksRoot(normalized)) return normalized;
    }

    final repo = _repoRootEnv();
    if (repo.isNotEmpty) {
      final normalized = _norm(repo);
      final legacy = '$normalized/plugins';
      if (_looksLikePacksRoot(legacy)) return legacy;
      final sibling = _norm('$normalized/../forja-packs');
      if (_looksLikePacksRoot(sibling)) return sibling;
    }

    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      final plugins = '${dir.path}/plugins';
      if (_looksLikePacksRoot(plugins)) return _norm(plugins);

      final sibling = '${dir.path}/forja-packs';
      if (_looksLikePacksRoot(sibling)) return _norm(sibling);

      if (_looksLikePacksRoot(dir.path)) return _norm(dir.path);

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;

      final nextSibling = '${dir.path}/forja-packs';
      if (_looksLikePacksRoot(nextSibling)) return _norm(nextSibling);
    }
    return null;
  }

  /// Absolute path to a pack manifest under the resolved root, or null.
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

  static bool _looksLikePacksRoot(String path) {
    return File('$path/providers/manifest.json').existsSync();
  }

  static String _packsRootEnv() {
    var v = const String.fromEnvironment('FORJA_PACKS_ROOT').trim();
    if (v.isEmpty) {
      v = Platform.environment['FORJA_PACKS_ROOT']?.trim() ?? '';
    }
    return v;
  }

  static String _repoRootEnv() {
    var v = const String.fromEnvironment('FORJA_REPO_ROOT').trim();
    if (v.isEmpty) {
      v = Platform.environment['FORJA_REPO_ROOT']?.trim() ?? '';
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
