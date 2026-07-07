// Thin Dart wrapper around the Rust Mega.nz AES-CTR loopback proxy (crates/proxy/mega).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

class MegaProxy {
  MegaProxy._();
  static final MegaProxy instance = MegaProxy._();

  /// Resolves a `mega.nz/embed/<id>!<key>` URL to a local proxy URL
  /// playable by media_kit. Returns `null` if the URL cannot be parsed
  /// or the Mega API call fails.
  Future<MegaResolved?> resolve(String embedUrl) async {
    try {
      final raw = await runMegaResolveJson(embedUrl);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final error = map['error'] as String?;
      if (error != null) {
        debugPrint('[MegaProxy] resolve failed: $error');
        return null;
      }
      final url = map['url'] as String?;
      final size = (map['size'] as num?)?.toInt();
      if (url == null || url.isEmpty || size == null || size <= 0) {
        debugPrint('[MegaProxy] resolve missing url/size: $map');
        return null;
      }
      return MegaResolved(url: url, size: size);
    } catch (e, st) {
      debugPrint('[MegaProxy] resolve failed: $e\n$st');
      return null;
    }
  }
}

class MegaResolved {
  final String url;
  final int size;
  const MegaResolved({required this.url, required this.size});
}
