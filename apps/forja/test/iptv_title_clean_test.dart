import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/iptv/iptv_title_clean.dart';

void main() {
  group('cleanIptvMediaTitle', () {
    test('strips empty pipe prefixes', () {
      expect(cleanIptvMediaTitle('| | The Runner').title, 'The Runner');
    });

    test('strips pipe-wrapped lang tags', () {
      expect(cleanIptvMediaTitle('|EN| The Runner').title, 'The Runner');
      expect(cleanIptvMediaTitle('|FR| |EN| The Runner').title, 'The Runner');
    });

    test('strips quality and dashed tags', () {
      expect(
        cleanIptvMediaTitle('EN | 4K | The Runner').title,
        'The Runner',
      );
      expect(
        cleanIptvMediaTitle('EN-NETFLIX-The Runner (2024)').title,
        'The Runner',
      );
      expect(
        cleanIptvMediaTitle('EN-NETFLIX-The Runner (2024)').year,
        2024,
      );
    });
  });
}
