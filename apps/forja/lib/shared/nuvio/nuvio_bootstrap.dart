import 'package:flutter/foundation.dart';

import 'nuvio_service.dart';

/// Nuvio entry for profile warm. **Never** auto-installs or auto-refreshes —
/// user installs / refreshes in Settings → Sources.
class NuvioBootstrap {
  NuvioBootstrap._();

  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/D3adlyRocket/All-in-One-Nuvio/'
      'refs/heads/main/manifest.json';

  static Future<void> ensureInstalled({String? manifestUrl}) async {
    debugPrint(
      '[NuvioBootstrap] skip auto-install/refresh — user confirm required',
    );
    // Keep signature; [NuvioService.ensureBundledInstalled] is also a no-op.
    await NuvioService.instance.ensureBundledInstalled();
  }
}
