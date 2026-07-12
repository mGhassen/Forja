import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as pc;

import 'models.dart';

/// Creates and resolves 8-character IPTV portal share codes.
///
/// Portal credentials are AES-encrypted with a key derived from the share code,
/// then stored on [rentry.co](https://rentry.co) under a custom URL slug that
/// matches the code.
class IptvPortalShare {
  IptvPortalShare._();

  static const shareCodeLength = 8;
  static const _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _rentryBase = 'https://rentry.co';
  static const _rentryEditCode = 'ForjaIptvShare1';
  static const _ua = 'Forja/1.2 (https://github.com/forja-forja/forja)';

  static String generateCode() {
    final rand = Random.secure();
    return List.generate(
      shareCodeLength,
      (_) => _charset[rand.nextInt(_charset.length)],
    ).join();
  }

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValidCode(String raw) =>
      normalizeCode(raw).length == shareCodeLength;

  /// Upload encrypted portal credentials and return the 8-char share code.
  static Future<String> createShare(IptvPortal portal) async {
    Object? lastError;
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = generateCode();
      try {
        final encrypted = _encryptPortal(portal, code);
        await _rentryCreate(code: code, text: encrypted);
        return code;
      } on _RentryUrlInUseException {
        continue;
      } catch (e, st) {
        lastError = e;
        debugPrint('[IptvPortalShare] create failed ($code): $e\n$st');
        rethrow;
      }
    }
    throw StateError('Could not allocate share code: $lastError');
  }

  /// Resolve an 8-char share code into portal credentials.
  static Future<IptvPortal?> resolveShare(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.length != shareCodeLength) return null;

    final encrypted = await _rentryFetch(code);
    if (encrypted == null || encrypted.isEmpty) return null;

    return _decryptPortal(encrypted, code);
  }

  static String _encryptPortal(IptvPortal portal, String code) {
    final plain = utf8.encode(
      jsonEncode({
        'v': 1,
        'url': portal.url,
        'username': portal.username,
        'password': portal.password,
      }),
    );
    final key = _deriveKey(code);
    final iv = _deriveIv(code);
    final cipherBytes = _aesCbcEncrypt(key, iv, Uint8List.fromList(plain));
    return base64Encode(cipherBytes);
  }

  static IptvPortal? _decryptPortal(String encryptedB64, String code) {
    try {
      final cipherBytes = base64.decode(encryptedB64.replaceAll('\n', '').trim());
      final key = _deriveKey(code);
      final iv = _deriveIv(code);
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
      debugPrint('[IptvPortalShare] decrypt failed: $e\n$st');
      return null;
    }
  }

  static Uint8List _deriveKey(String code) =>
      Uint8List.fromList(sha256.convert(utf8.encode('forja-iptv-share-v1:$code')).bytes);

  static Uint8List _deriveIv(String code) => Uint8List.fromList(
        sha256.convert(utf8.encode('forja-iptv-iv-v1:$code')).bytes.sublist(0, 16),
      );

  static Uint8List _aesCbcEncrypt(Uint8List key, Uint8List iv, Uint8List data) {
    final padded = _pkcs7Pad(data, 16);
    final cipher = pc.CBCBlockCipher(pc.AESEngine())
      ..init(true, pc.ParametersWithIV(pc.KeyParameter(key), iv));
    final out = Uint8List(padded.length);
    for (var offset = 0; offset < padded.length; offset += 16) {
      cipher.processBlock(padded, offset, out, offset);
    }
    return out;
  }

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

  static Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final out = Uint8List(data.length + padLen);
    out.setRange(0, data.length, data);
    out.fillRange(data.length, out.length, padLen);
    return out;
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

  static Future<void> _rentryCreate({
    required String code,
    required String text,
  }) async {
    final session = await _rentrySession();
    final headers = <String, String>{
      'User-Agent': _ua,
      'Content-Type': 'application/x-www-form-urlencoded',
      if (session.cookie != null) 'Cookie': session.cookie!,
    };
    final body = {
      'csrfmiddlewaretoken': session.csrf,
      'url': code,
      'edit_code': _rentryEditCode,
      'text': text,
    };
    final resp = await http.post(
      Uri.parse('$_rentryBase/api/new'),
      headers: headers,
      body: body,
    );
    if (resp.statusCode != 200) {
      throw StateError('Share upload failed (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw StateError('Share upload failed (invalid response)');
    }
    final status = '${decoded['status'] ?? ''}';
    if (status == '400') {
      final errors = '${decoded['errors'] ?? ''}'.toLowerCase();
      if (errors.contains('already in use')) {
        throw _RentryUrlInUseException();
      }
    }
    if (status != '200') {
      throw StateError('Share upload failed ($status)');
    }
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
    if ('${decoded['status']}' != '200') return null;
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

class _RentryUrlInUseException implements Exception {}
