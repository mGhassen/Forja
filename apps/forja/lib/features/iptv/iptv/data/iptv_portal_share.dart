import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

import 'models.dart';

/// Creates and resolves IPTV portal share tokens.
///
/// Self-contained `F1.` tokens (AES in Rust) — no pastebin / no server.
class IptvPortalShare {
  IptvPortalShare._();

  static const embeddedPrefix = 'F1.';

  static bool isEmbeddedToken(String raw) =>
      raw.trim().startsWith(embeddedPrefix);

  static bool isValidCode(String raw) =>
      isEmbeddedToken(raw) &&
      raw.trim().length > embeddedPrefix.length + 16;

  /// Encrypt portal credentials into a self-contained `F1.` token (Rust).
  static Future<String> createShare(IptvPortal portal) async {
    final token = RustLib.instance.iptvPortalShareEncode(
      portal.url,
      portal.username,
      portal.password,
    );
    if (token.isEmpty || !isEmbeddedToken(token)) {
      throw StateError('Could not create share code');
    }
    return token;
  }

  /// Resolve an embedded `F1.` token.
  static Future<IptvPortal?> resolveShare(String rawCode) async {
    final trimmed = rawCode.trim();
    if (!isEmbeddedToken(trimmed)) return null;
    return _resolveEmbedded(trimmed);
  }

  static IptvPortal? _resolveEmbedded(String token) {
    try {
      final jsonStr = RustLib.instance.iptvPortalShareDecode(token);
      if (jsonStr.isEmpty) return null;
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final url = (map['url'] as String?)?.trim() ?? '';
      final username = (map['username'] as String?)?.trim() ?? '';
      final password = (map['password'] as String?)?.trim() ?? '';
      if (url.isEmpty || username.isEmpty || password.isEmpty) return null;
      return IptvPortal(
        url: url,
        username: username,
        password: password,
        source: 'Shared',
      );
    } catch (e, st) {
      debugPrint('[IptvPortalShare] decode failed: $e\n$st');
      return null;
    }
  }
}
