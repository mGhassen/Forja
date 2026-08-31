import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// STREAMCRYPTO (`enc=2`) — seed + media id → XOR keystream → `mvm1` JSON.
///
/// Same algorithm as the player JS and AniWorld's Python port. Used by every
/// Forja path that hits this player family (Videasy provider, VidSrc.sbs 4K
/// `player.videasy.*` nested embeds, …) — not a Videasy-only cipher.
abstract final class StreamCrypto {
  static const _mask = 0xFFFFFFFF;
  static const _golden = 2654435769; // 0x9E3779B9
  static const _magic = [109, 118, 109, 49]; // mvm1

  /// True when [url] is the enc=2 player (not Cinesrc / nxsha / …).
  static bool isPlayerUrl(String url, {String? configuredOrigin}) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (_isVideasyFamilyHost(host)) return true;
    final extra = Uri.tryParse(configuredOrigin?.trim() ?? '')?.host
            .toLowerCase() ??
        '';
    return extra.isNotEmpty && host == extra;
  }

  static bool _isVideasyFamilyHost(String host) {
    return host == 'videasy.to' ||
        host == 'videasy.net' ||
        host.endsWith('.videasy.to') ||
        host.endsWith('.videasy.net');
  }

  /// Decrypt an `enc=2` body into UTF-8 JSON (no `mvm1` prefix).
  ///
  /// Throws [FormatException] on bad magic / garbage.
  static String decrypt(String payload, String seed, String mediaId) {
    final data = _b64urlDecode(payload);
    if (data.length < _magic.length) {
      throw const FormatException('STREAMCRYPTO: payload too short');
    }
    final id = int.tryParse(mediaId.trim());
    if (id == null) {
      throw FormatException('STREAMCRYPTO: invalid media id $mediaId');
    }
    final ks = _keystream(seed, id, data.length);
    for (var i = 0; i < data.length; i++) {
      data[i] ^= ks[i];
    }
    for (var j = 0; j < _magic.length; j++) {
      if (data[j] != _magic[j]) {
        throw const FormatException(
          'STREAMCRYPTO: bad seed or tampered payload',
        );
      }
    }
    return utf8.decode(data.sublist(_magic.length));
  }

  /// Inverse of [decrypt] for unit round-trips. Not used in extract.
  @visibleForTesting
  static String encryptForTest(String json, String seed, String mediaId) {
    final id = int.parse(mediaId);
    final plain = Uint8List.fromList([..._magic, ...utf8.encode(json)]);
    final ks = _keystream(seed, id, plain.length);
    for (var i = 0; i < plain.length; i++) {
      plain[i] ^= ks[i];
    }
    return base64Url.encode(plain).replaceAll('=', '');
  }

  static int _imul(int a, int b) => (a * b) & _mask;

  static int _f(int e) {
    e &= _mask;
    e ^= e >> 16;
    e = _imul(e, 2246822507);
    e ^= e >> 13;
    e = _imul(e, 3266489909);
    e ^= e >> 16;
    return e & _mask;
  }

  static int _rotl(int e, int t) {
    e &= _mask;
    t &= 31;
    if (t == 0) return e;
    return ((e << t) | (e >> (32 - t))) & _mask;
  }

  static int _fnvF(String text) {
    var t = 2166136261;
    for (final code in text.codeUnits) {
      t = _imul(t ^ code, 16777619);
    }
    return _f(t);
  }

  static ({Map<int, int> state, int acc}) _keySchedule(
    String seed,
    int mediaId,
  ) {
    var n = _f(_fnvF(seed) ^ _f((mediaId & _mask) ^ _golden));
    final state = <int, int>{};
    for (var e = 0; e < 8; e++) {
      final idx = n % 61;
      n = _rotl((n + _golden) & _mask, 7 + (e & 7));
      state[idx] = (n ^ _f(n)) & _mask;
      n = _f((n + idx) & _mask);
    }
    final acc = _f(2779096485 ^ n);
    return (state: state, acc: acc);
  }

  static Uint8List _keystream(String seed, int mediaId, int length) {
    final sched = _keySchedule(seed, mediaId);
    final state = Map<int, int>.from(sched.state);
    var acc = sched.acc;
    final out = Uint8List(length);
    var pos = 0;
    var counter = 0;
    while (pos < length) {
      final a = acc;
      final i = a % 61;
      final mask = state.containsKey(i) ? _mask : 0;
      final low = (state[i] ?? 0) & _mask;
      final mixed = (low ^ _imul(_golden, counter + 1)) & _mask;
      var c = ((a ^ mixed) | (a & mixed & mask)) & _mask;
      c = (_rotl((c + a) & _mask, i & 31) ^ _rotl(a, _imul(i, 7) & 31)) &
          _mask;
      acc = _f((c + _golden) & _mask);
      state[i] = acc & _mask;
      counter++;
      final val = acc;
      out[pos++] = val & 255;
      if (pos < length) out[pos++] = (val >> 8) & 255;
      if (pos < length) out[pos++] = (val >> 16) & 255;
      if (pos < length) out[pos++] = (val >> 24) & 255;
    }
    return out;
  }

  static Uint8List _b64urlDecode(String text) {
    var t = text.trim().replaceAll('-', '+').replaceAll('_', '/');
    if (t.isEmpty) {
      throw const FormatException('STREAMCRYPTO: empty payload');
    }
    final pad = (4 - t.length % 4) % 4;
    t += '=' * pad;
    try {
      return Uint8List.fromList(base64.decode(t));
    } on FormatException {
      throw const FormatException('STREAMCRYPTO: invalid payload');
    }
  }
}
