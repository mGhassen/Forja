import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as pc;
import 'package:rust/rust.dart';

import 'models.dart';

/// Creates and resolves IPTV portal share tokens.
///
/// **New shares** are self-contained `F1.` tokens (AES in Rust) — no pastebin.
/// **Legacy** 8-character codes still resolve from [rentry.co](https://rentry.co)
/// so existing codes keep working.
class IptvPortalShare {
  IptvPortalShare._();

  static const shareCodeLength = 8;
  static const embeddedPrefix = 'F1.';
  static const _rentryBase = 'https://rentry.co';
  static const _rentryEditCode = 'ForjaIptvShare1';
  static const _ua = 'Forja/1.2 (https://github.com/forja-forja/forja)';

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isEmbeddedToken(String raw) =>
      raw.trim().startsWith(embeddedPrefix);

  static bool isLegacyCode(String raw) =>
      normalizeCode(raw).length == shareCodeLength;

  static bool isValidCode(String raw) =>
      isEmbeddedToken(raw) || isLegacyCode(raw);

  /// Format for clipboard / display (legacy `XXXX-XXXX`, embedded as-is).
  static String formatCode(String raw) {
    final trimmed = raw.trim();
    if (isEmbeddedToken(trimmed)) return trimmed;
    final code = normalizeCode(trimmed);
    if (code.length <= 4) return code;
    return '${code.substring(0, 4)}-${code.substring(4)}';
  }

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

  /// Resolve an embedded `F1.` token or a legacy 8-char rentry code.
  static Future<IptvPortal?> resolveShare(String rawCode) async {
    final trimmed = rawCode.trim();
    if (isEmbeddedToken(trimmed)) {
      return _resolveEmbedded(trimmed);
    }

    final code = normalizeCode(trimmed);
    if (code.length != shareCodeLength) return null;

    final encrypted = await _rentryFetch(code);
    if (encrypted == null || encrypted.isEmpty) return null;

    return _decryptLegacyPortal(encrypted, code);
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
      debugPrint('[IptvPortalShare] embedded decode failed: $e\n$st');
      return null;
    }
  }

  /// Legacy AES (key derived from 8-char code) — same as pre-F1 shares on rentry.
  static IptvPortal? _decryptLegacyPortal(String encryptedB64, String code) {
    try {
      final cipherBytes =
          base64.decode(encryptedB64.replaceAll('\n', '').trim());
      final key = _deriveLegacyKey(code);
      final iv = _deriveLegacyIv(code);
      final plainBytes = _aesCbcDecrypt(key, iv, cipherBytes);
      final plain = utf8.decode(plainBytes);
      final decoded = jsonDecode(plain);
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
      debugPrint('[IptvPortalShare] legacy decrypt failed: $e\n$st');
      return null;
    }
  }

  static Uint8List _deriveLegacyKey(String code) =>
      Uint8List.fromList(sha256.convert(utf8.encode('forja-iptv-share-v1:$code')).bytes);

  static Uint8List _deriveLegacyIv(String code) => Uint8List.fromList(
        sha256.convert(utf8.encode('forja-iptv-iv-v1:$code')).bytes.sublist(0, 16),
      );

  static Uint8List _aesCbcDecrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List cipherBytes,
  ) {
    if (cipherBytes.isEmpty || cipherBytes.length % 16 != 0) {
      throw FormatException('invalid cipher length');
    }
    final cipher = pc.CBCBlockCipher(pc.AESEngine())
      ..init(false, pc.ParametersWithIV(pc.KeyParameter(key), iv));
    final out = Uint8List(cipherBytes.length);
    for (var offset = 0; offset < cipherBytes.length; offset += 16) {
      cipher.processBlock(cipherBytes, offset, out, offset);
    }
    return _pkcs7Unpad(out, 16);
  }

  static Uint8List _pkcs7Unpad(Uint8List data, int blockSize) {
    if (data.isEmpty || data.length % blockSize != 0) {
      throw FormatException('invalid padded data');
    }
    final padLen = data.last;
    if (padLen <= 0 || padLen > blockSize) {
      throw FormatException('invalid pkcs7 padding');
    }
    for (var i = data.length - padLen; i < data.length; i++) {
      if (data[i] != padLen) throw FormatException('invalid pkcs7 padding');
    }
    return Uint8List.sublistView(data, 0, data.length - padLen);
  }

  static Future<_RentrySession> _rentrySession() async {
    final resp = await http.get(
      Uri.parse('$_rentryBase/'),
      headers: {'User-Agent': _ua},
    );
    if (resp.statusCode != 200) {
      throw StateError('Share service unavailable (${resp.statusCode})');
    }
    final csrf = RegExp(
      r'csrfmiddlewaretoken" value="([^"]+)"',
    ).firstMatch(resp.body)?.group(1);
    if (csrf == null || csrf.isEmpty) {
      throw StateError('Share service unavailable (missing CSRF token)');
    }
    final cookie = _extractCookie(resp.headers['set-cookie']);
    return _RentrySession(csrf: csrf, cookie: cookie);
  }

  static String? _extractCookie(String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return null;
    final semi = setCookie.indexOf(';');
    return semi >= 0 ? setCookie.substring(0, semi) : setCookie;
  }

  static Future<String?> _rentryFetch(String code) async {
    final session = await _rentrySession();
    final headers = <String, String>{
      'User-Agent': _ua,
      'Content-Type': 'application/x-www-form-urlencoded',
      if (session.cookie != null) 'Cookie': session.cookie!,
    };
    final body = {
      'csrfmiddlewaretoken': session.csrf,
      'edit_code': _rentryEditCode,
    };
    final resp = await http.post(
      Uri.parse('$_rentryBase/api/fetch/${code.toLowerCase()}'),
      headers: headers,
      body: body,
    );
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    if ('${decoded['status']}' != '200') {
      final content = '${decoded['content'] ?? ''}';
      if (content.toLowerCase().contains('unavailable') ||
          '${decoded['status']}' == '503') {
        throw StateError('Share service unavailable');
      }
      return null;
    }
    final content = decoded['content'];
    if (content is! Map) return null;
    return content['text'] as String?;
  }
}

class _RentrySession {
  const _RentrySession({required this.csrf, this.cookie});

  final String csrf;
  final String? cookie;
}
