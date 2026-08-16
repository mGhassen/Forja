import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:forja/shared/supabase/forja_supabase.dart';

import 'models.dart';

/// Creates and resolves 8-character IPTV portal share codes.
///
/// Credentials are encrypted locally (Rust `F1.` token) and stored under the
/// short code in Supabase — no pastebin.
class IptvPortalShare {
  IptvPortalShare._();

  static const shareCodeLength = 8;
  static const embeddedPrefix = 'F1.';
  static const _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _table = 'iptv_share_codes';

  static String generateCode() {
    final rand = Random.secure();
    return List.generate(
      shareCodeLength,
      (_) => _charset[rand.nextInt(_charset.length)],
    ).join();
  }

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isEmbeddedToken(String raw) =>
      raw.trim().startsWith(embeddedPrefix);

  static bool isLegacyCode(String raw) =>
      normalizeCode(raw).length == shareCodeLength;

  static bool isValidCode(String raw) =>
      isEmbeddedToken(raw) || isLegacyCode(raw);

  static String formatCode(String raw) {
    final trimmed = raw.trim();
    if (isEmbeddedToken(trimmed)) return trimmed;
    final code = normalizeCode(trimmed);
    if (code.length <= 4) return code;
    return '${code.substring(0, 4)}-${code.substring(4)}';
  }

  /// Encrypt portal credentials and store under a new 8-char code.
  static Future<String> createShare(IptvPortal portal) async {
    final token = RustLib.instance.iptvPortalShareEncode(
      portal.url,
      portal.username,
      portal.password,
    );
    if (token.isEmpty || !isEmbeddedToken(token)) {
      throw StateError('Could not create share code');
    }

    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw StateError('Share service unavailable');
    }

    Object? lastError;
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = generateCode();
      try {
        await client.from(_table).insert({'code': code, 'token': token});
        return code;
      } on PostgrestException catch (e) {
        if (e.code == '23505') continue;
        lastError = e;
        debugPrint('[IptvPortalShare] create failed ($code): $e');
        rethrow;
      }
    }
    throw StateError('Could not allocate share code: $lastError');
  }

  /// Resolve an 8-char code or a leftover `F1.` token.
  static Future<IptvPortal?> resolveShare(String rawCode) async {
    final trimmed = rawCode.trim();
    if (isEmbeddedToken(trimmed)) {
      return _resolveEmbedded(trimmed);
    }

    final code = normalizeCode(trimmed);
    if (code.length != shareCodeLength) return null;

    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw StateError('Share service unavailable');
    }

    final row = await client
        .from(_table)
        .select('token')
        .eq('code', code)
        .maybeSingle();
    final token = row?['token'] as String?;
    if (token == null || token.isEmpty) return null;
    return _resolveEmbedded(token);
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
