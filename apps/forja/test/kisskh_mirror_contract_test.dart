import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/extractors/providers/kisskh/kisskh_extractor.dart';

void main() {
  test('episode URL uses the selected KissKh mirror', () {
    final url = KissKhService.episodePageUrl(
      baseUrl: 'https://kisskh.nl',
      dramaId: 10633,
      title: 'Blossoms of Power',
      episodeId: 217295,
      episodeNumber: 1,
    );

    expect(url, startsWith('https://kisskh.nl/Drama/'));
    expect(url, contains('id=10633'));
    expect(url, contains('ep=217295'));
  });

  test('playback headers preserve the selected KissKh mirror', () {
    final headers = KissKhExtractor.playbackHeaders('https://kisskh.ovh');

    expect(headers['Referer'], 'https://kisskh.ovh/');
    expect(headers['Origin'], 'https://kisskh.ovh');
  });
}
