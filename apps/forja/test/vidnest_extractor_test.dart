import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/providers/vidnest/vidnest_extractor.dart';

void main() {
  group('VidnestExtractor.decryptCipherForTest', () {
    test('decodes MovieBox-shaped payload alphabet', () {
      // Round-trip: encode with the same alphabet, then decrypt.
      const alphabet =
          'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';
      const plain = '{"provider":"MovieBox","url":[{"link":"https://bcdn.hakunaymatata.com/x.mp4","resolution":"720p","type":"mp4"}]}';
      final encoded = _encodeCipher(plain, alphabet);
      final decoded = VidnestExtractor.decryptCipherForTest(encoded);
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      expect(map['provider'], 'MovieBox');
      final urls = map['url'] as List;
      expect(urls.first['link'], contains('hakunaymatata.com'));
    });
  });
}

String _encodeCipher(String plain, String alphabet) {
  final bytes = utf8.encode(plain);
  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i += 3) {
    final b0 = bytes[i];
    final b1 = i + 1 < bytes.length ? bytes[i + 1] : null;
    final b2 = i + 2 < bytes.length ? bytes[i + 2] : null;
    final n0 = b0 >> 2;
    final n1 = ((b0 & 3) << 4) | ((b1 ?? 0) >> 4);
    out.write(alphabet[n0]);
    out.write(alphabet[n1]);
    if (b1 == null) {
      out.write('==');
    } else {
      final n2 = ((b1 & 15) << 2) | ((b2 ?? 0) >> 6);
      out.write(alphabet[n2]);
      if (b2 == null) {
        out.write('=');
      } else {
        out.write(alphabet[b2 & 63]);
      }
    }
  }
  return out.toString();
}
