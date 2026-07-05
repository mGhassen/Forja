import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Dart reference KissKH subtitle decrypt — Rust-off fallback and parity tests.
abstract final class KissKhDecryptDart {
  static String decryptBody(String body, {String? sourceUrl}) {
    final preferred = sourceUrl != null ? _preferredFor(sourceUrl) : null;
    final lines = body.split(RegExp(r'\r?\n'));
    final out = StringBuffer();
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty ||
          t == 'WEBVTT' ||
          t.startsWith('NOTE') ||
          RegExp(r'^\d+$').hasMatch(t) ||
          line.contains('-->')) {
        out.writeln(line);
        continue;
      }
      final decoded = decryptCue(line, preferred: preferred);
      out.writeln(decoded ?? line);
    }
    return out.toString();
  }

  static String? decryptCue(String b64, {_KeyIv? preferred}) {
    final trimmed = b64.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(trimmed)) return null;
    Uint8List ct;
    try {
      ct = base64.decode(trimmed);
    } catch (_) {
      return null;
    }
    if (ct.isEmpty || ct.length % 16 != 0) return null;
    if (preferred != null) {
      final r = _tryDecrypt(ct, preferred);
      if (r != null) return r;
    }
    for (final kiv in _keyVariants) {
      if (identical(kiv, preferred)) continue;
      final r = _tryDecrypt(ct, kiv);
      if (r != null) return r;
    }
    return null;
  }

  static _KeyIv? _preferredFor(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    switch (ext) {
      case 'srt':
        return null;
      case 'txt':
        return _keyVariants[1];
      case 'txt1':
        return _keyVariants[0];
      default:
        return _keyVariants[2];
    }
  }

  static String? _tryDecrypt(Uint8List ct, _KeyIv kiv) {
    try {
      final cipher = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV(KeyParameter(kiv.key), kiv.iv));
      final out = Uint8List(ct.length);
      for (var off = 0; off < ct.length; off += 16) {
        cipher.processBlock(ct, off, out, off);
      }
      final pad = out.last;
      if (pad < 1 || pad > 16) return null;
      for (var i = out.length - pad; i < out.length; i++) {
        if (out[i] != pad) return null;
      }
      return utf8.decode(out.sublist(0, out.length - pad), allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _u8(String s) => Uint8List.fromList(utf8.encode(s));

  static final List<_KeyIv> _keyVariants = [
    _KeyIv(_u8('AmSmZVcH93UQUezi'), _u8('ReBKWW8cqdjPEnF6')),
    _KeyIv(_u8('8056483646328763'), _u8('6852612370185273')),
    _KeyIv(_u8('sWODXX04QRTkHdlZ'), _u8('8pwhapJeC4hrS9hO')),
  ];
}

class _KeyIv {
  final Uint8List key;
  final Uint8List iv;
  const _KeyIv(this.key, this.iv);
}
