import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv_title_clean.dart';

void main() {
  test('strips EN-/NETFLIX- prefixes and year', () {
    final c = cleanIptvMediaTitle('EN-NETFLIX-Dune Part Two 2024 1080p');
    expect(c.title.toLowerCase(), contains('dune'));
    expect(c.year, 2024);
  });

  test('parses SxxExx and cleans dots', () {
    final c = cleanIptvMediaTitle('FR-Breaking.Bad.S05E14.1080p.WEBRip');
    expect(c.season, 5);
    expect(c.episode, 14);
    expect(c.title.toLowerCase(), contains('breaking'));
    expect(c.title.toLowerCase(), isNot(contains('webrip')));
  });

  test('empty stays empty', () {
    expect(cleanIptvMediaTitle('   ').isEmpty, isTrue);
  });
}
