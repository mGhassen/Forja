import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';

/// Handles `forja://install?manifest=<url>` from the web plugin catalog.
abstract final class ForjaPluginDeepLink {
  static final AppLinks _links = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> ensureListening() async {
    if (kIsWeb) return;
    if (_sub != null) return;
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) {
        unawaited(_handleUri(initial));
      }
      _sub = _links.uriLinkStream.listen(
        (uri) => unawaited(_handleUri(uri)),
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

  static Future<void> _handleUri(Uri uri) async {
    if (!_isInstallLink(uri)) return;
    final manifest = _manifestFromUri(uri);
    if (manifest == null || manifest.isEmpty) {
      debugPrint('[PluginDeepLink] missing manifest param: $uri');
      return;
    }
    debugPrint('[PluginDeepLink] install $manifest');
    try {
      await PluginInstallCoordinator.instance.installManifest(manifest);
      scheduleForjaSyncPush();
    } catch (e, st) {
      debugPrint('[PluginDeepLink] install failed: $e\n$st');
    }
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
    return _manifestFromUri(uri);
  }
}
