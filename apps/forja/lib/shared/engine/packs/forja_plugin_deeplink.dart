import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/widgets/desktop_window_focus.dart';
import 'package:forja/shell/shell_bus.dart';

/// Handles `forja://install?manifest=<url>` and batch
/// `forja://install?batch=1&packs=[…]` — brings app forward and asks before install.
abstract final class ForjaPluginDeepLink {
  static final AppLinks _links = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> ensureListening() async {
    if (kIsWeb) return;
    if (_sub != null) return;
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) {
        _queueInstall(initial);
      }
      _sub = _links.uriLinkStream.listen(
        _queueInstall,
        onError: (Object e) {
          debugPrint('[PluginDeepLink] stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[PluginDeepLink] init failed: $e');
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static void _queueInstall(Uri uri) {
    if (!_isInstallLink(uri)) return;

    unawaited(DesktopWindowFocus.bringToFront());

    final batch = parseBatchCandidates(uri);
    if (batch != null && batch.isNotEmpty) {
      if (batch.length == 1) {
        final only = batch.first;
        debugPrint('[PluginDeepLink] queue install ${only.manifestUrl}');
        ShellBus.enqueuePluginInstall(
          PluginInstallPrompt(
            manifestUrl: only.manifestUrl,
            displayName: only.displayName,
          ),
        );
      } else {
        debugPrint('[PluginDeepLink] queue batch install (${batch.length})');
        ShellBus.pendingPluginBatchInstall.value =
            PluginBatchInstallPrompt(candidates: batch);
      }
      ShellBus.openSettings(
        categoryId: SettingsCategoryId.forjaPacks,
        enterDetail: true,
      );
      return;
    }

    final manifest = _manifestFromUri(uri);
    if (manifest == null || manifest.isEmpty) {
      debugPrint('[PluginDeepLink] missing manifest param: $uri');
      return;
    }
    debugPrint('[PluginDeepLink] queue install $manifest');
    ShellBus.enqueuePluginInstall(
      PluginInstallPrompt(
        manifestUrl: manifest,
        displayName: uri.queryParameters['name']?.trim(),
      ),
    );
    ShellBus.openSettings(
      categoryId: SettingsCategoryId.forjaPacks,
      enterDetail: true,
    );
  }

  static bool _isInstallLink(Uri uri) {
    if (uri.scheme != 'forja') return false;
    final host = uri.host.trim().toLowerCase();
    final path = uri.path.trim().toLowerCase();
    if (host == 'install') return true;
    if (host.isEmpty && (path == '/install' || path == 'install')) return true;
    return false;
  }

  static String? _manifestFromUri(Uri uri) {
    final direct = uri.queryParameters['manifest']?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final legacy = uri.queryParameters['url']?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return null;
  }

  /// Test hook + shared parser for install deep links.
  static String? parseManifestUrl(Uri uri) {
    if (!_isInstallLink(uri)) return null;
    if (_isBatchParam(uri)) return null;
    return _manifestFromUri(uri);
  }

  static bool _isBatchParam(Uri uri) {
    final batch = uri.queryParameters['batch']?.trim();
    return batch == '1' || batch == 'true';
  }

  /// Parse `?batch=1&packs=[{m,n?},…]` — returns null when not a batch link.
  static List<PluginInstallCandidate>? parseBatchCandidates(Uri uri) {
    if (!_isInstallLink(uri) || !_isBatchParam(uri)) return null;
    final raw = uri.queryParameters['packs']?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final out = <PluginInstallCandidate>[];
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final manifest =
            (map['m'] as String?)?.trim() ??
            (map['manifestUrl'] as String?)?.trim() ??
            '';
        if (manifest.isEmpty || !seen.add(manifest)) continue;
        final name =
            (map['n'] as String?)?.trim() ??
            (map['name'] as String?)?.trim();
        out.add(
          PluginInstallCandidate(
            manifestUrl: manifest,
            displayName: (name != null && name.isNotEmpty) ? name : null,
          ),
        );
      }
      return out.isEmpty ? null : out;
    } catch (e) {
      debugPrint('[PluginDeepLink] batch packs parse failed: $e');
      return null;
    }
  }
}
