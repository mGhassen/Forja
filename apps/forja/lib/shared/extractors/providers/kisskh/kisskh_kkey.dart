import 'package:forja/shared/extractors/providers/kisskh/kisskh_kkey_tables.dart';

/// Consumet-compatible KissKh `kkey` (same as `crates/kisskh/src/kkey.rs`).
abstract final class KissKhKkey {
  static const hashConst = 'mg3c3b04ba';
  static const version = '2.8.10';
  static const viGuid = '62f176f3bb1b5b8e70e39932ad34a0c7';
  static const subGuid = 'VgV52sWhwvBSf8BsM3BRY9weWiiCbtGp';
  static const platformVer = '4830201';
  static const iv = <int>[22039283, 1457920463, 776125350, -1941999367];

  static String generate(int episodeId, {bool subtitle = false}) {
    final guid = subtitle ? subGuid : viGuid;
    final idS = episodeId.toString();
    final beforeHash = [
      '',
      idS,
      '',
      hashConst,
      version,
      guid,
      platformVer,
      'kisskh',
      'kisskh',
      'kisskh',
      'kisskh',
      'kisskh',
      'kisskh',
      '00',
      '',
    ];
    final hashN = _calculateHash(beforeHash.join('|'));
    final parts = <String>[
      '',
      hashN.toString(),
      idS,
      '',
      hashConst,
      version,
      guid,
      platformVer,
      'kisskh',
      'kisskh',
      'kisskh',
      'kisskh',
      'kisskh',
      'kisskh',
      '00',
      '',
    ];
    final padded = _padString(parts.join('|'));
    final words = _stringToWordArray(padded);
    _processBlock(words);
    return _wordArrayToHex(words, padded.length);
  }

  static int _i32(int n) => n.toSigned(32);

  static int _calculateHash(String input) {
    var hash = 0;
    for (final c in input.runes) {
      final shifted = _i32(_i32(hash) << 5);
      hash = shifted - hash + c;
    }
    return hash;
  }

  static String _padString(String input) {
    final padding = 16 - (input.length % 16);
    final padCh = String.fromCharCode(padding);
    return input + padCh * padding;
  }

  static List<int> _stringToWordArray(String input) {
    final bytes = input.codeUnits;
    final words = List<int>.filled((bytes.length + 3) ~/ 4, 0);
    for (var i = 0; i < bytes.length; i++) {
      final shift = 24 - (i % 4) * 8;
      words[i ~/ 4] = _i32(words[i ~/ 4] | ((bytes[i] & 0xff) << shift));
    }
    return words;
  }

  static String _wordArrayToHex(List<int> array, int length) {
    final out = StringBuffer();
    for (var i = 0; i < length; i++) {
      final word = array[i ~/ 4].toUnsigned(32);
      final shift = 24 - (i % 4) * 8;
      final byte = (word >> shift) & 0xff;
      out.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return out.toString().toUpperCase();
  }

  static void _encryptBlock(List<int> n, int offset) {
    final prev = offset == 0
        ? iv
        : [n[offset - 4], n[offset - 3], n[offset - 2], n[offset - 1]];
    for (var i = 0; i < 4; i++) {
      n[offset + i] = _i32(n[offset + i] ^ prev[i]);
    }

    var s0 = _i32(n[offset] ^ kKissKhRK[0]);
    var s1 = _i32(n[offset + 1] ^ kKissKhRK[1]);
    var s2 = _i32(n[offset + 2] ^ kKissKhRK[2]);
    var s3 = _i32(n[offset + 3] ^ kKissKhRK[3]);
    var rki = 4;

    for (var r = 1; r < 10; r++) {
      final t0 = _i32(
        kKissKhT0[(s0.toUnsigned(32) >> 24) & 255] ^
            kKissKhT1[(s1.toUnsigned(32) >> 16) & 255] ^
            kKissKhT2[(s2.toUnsigned(32) >> 8) & 255] ^
            kKissKhT3[s3.toUnsigned(32) & 255] ^
            kKissKhRK[rki],
      );
      rki++;
      final t1 = _i32(
        kKissKhT0[(s1.toUnsigned(32) >> 24) & 255] ^
            kKissKhT1[(s2.toUnsigned(32) >> 16) & 255] ^
            kKissKhT2[(s3.toUnsigned(32) >> 8) & 255] ^
            kKissKhT3[s0.toUnsigned(32) & 255] ^
            kKissKhRK[rki],
      );
      rki++;
      final t2 = _i32(
        kKissKhT0[(s2.toUnsigned(32) >> 24) & 255] ^
            kKissKhT1[(s3.toUnsigned(32) >> 16) & 255] ^
            kKissKhT2[(s0.toUnsigned(32) >> 8) & 255] ^
            kKissKhT3[s1.toUnsigned(32) & 255] ^
            kKissKhRK[rki],
      );
      rki++;
      final t3 = _i32(
        kKissKhT0[(s3.toUnsigned(32) >> 24) & 255] ^
            kKissKhT1[(s0.toUnsigned(32) >> 16) & 255] ^
            kKissKhT2[(s1.toUnsigned(32) >> 8) & 255] ^
            kKissKhT3[s2.toUnsigned(32) & 255] ^
            kKissKhRK[rki],
      );
      rki++;
      s0 = t0;
      s1 = t1;
      s2 = t2;
      s3 = t3;
    }

    n[offset] = _i32(
      (((kKissKhSBOX[(s0.toUnsigned(32) >> 24) & 255] << 24) |
                  (kKissKhSBOX[(s1.toUnsigned(32) >> 16) & 255] << 16) |
                  (kKissKhSBOX[(s2.toUnsigned(32) >> 8) & 255] << 8) |
                  kKissKhSBOX[s3.toUnsigned(32) & 255])
              .toSigned(32)) ^
          kKissKhRK[rki],
    );
    rki++;
    n[offset + 1] = _i32(
      (((kKissKhSBOX[(s1.toUnsigned(32) >> 24) & 255] << 24) |
                  (kKissKhSBOX[(s2.toUnsigned(32) >> 16) & 255] << 16) |
                  (kKissKhSBOX[(s3.toUnsigned(32) >> 8) & 255] << 8) |
                  kKissKhSBOX[s0.toUnsigned(32) & 255])
              .toSigned(32)) ^
          kKissKhRK[rki],
    );
    rki++;
    n[offset + 2] = _i32(
      (((kKissKhSBOX[(s2.toUnsigned(32) >> 24) & 255] << 24) |
                  (kKissKhSBOX[(s3.toUnsigned(32) >> 16) & 255] << 16) |
                  (kKissKhSBOX[(s0.toUnsigned(32) >> 8) & 255] << 8) |
                  kKissKhSBOX[s1.toUnsigned(32) & 255])
              .toSigned(32)) ^
          kKissKhRK[rki],
    );
    rki++;
    n[offset + 3] = _i32(
      (((kKissKhSBOX[(s3.toUnsigned(32) >> 24) & 255] << 24) |
                  (kKissKhSBOX[(s0.toUnsigned(32) >> 16) & 255] << 16) |
                  (kKissKhSBOX[(s1.toUnsigned(32) >> 8) & 255] << 8) |
                  kKissKhSBOX[s2.toUnsigned(32) & 255])
              .toSigned(32)) ^
          kKissKhRK[rki],
    );
  }

  static void _processBlock(List<int> n) {
    var i = 0;
    while (i + 4 <= n.length) {
      _encryptBlock(n, i);
      i += 4;
    }
  }
}
