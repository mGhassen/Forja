import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/utils/torrent_meta_parser.dart';

void main() {
  group('TorrentMetaParser languages', () {
    test('French subtitle tags are not French audio', () {
      expect(
        TorrentMetaParser.parse('Frieren S01E03 VOSTFR 1080p').languageCodes,
        isNot(contains('fr')),
      );
      expect(
        TorrentMetaParser.parse('Movie.2024.SUBFRENCH.1080p').languageCodes,
        isNot(contains('fr')),
      );
      expect(
        TorrentMetaParser.parse('Movie.2024.FRENCH.1080p').languageCodes,
        contains('fr'),
      );
      expect(
        TorrentMetaParser.parse('Movie.2024.TRUEFRENCH.1080p').languageCodes,
        contains('fr'),
      );
    });
  });

  group('TorrentMetaParser.resolveSizeLabel', () {
    test('drops bogus tiny sizes and quality tokens in the size slot', () {
      expect(
        TorrentMetaParser.resolveSizeLabel(fallbackText: '1080p 4K WEB-DL'),
        isNull,
      );
      expect(
        TorrentMetaParser.resolveSizeLabel(sizeText: '4K'),
        isNull,
      );
      expect(
        TorrentMetaParser.resolveSizeLabel(sizeText: '4 KB'),
        isNull,
      );
      expect(
        TorrentMetaParser.resolveSizeLabel(sizeText: '4096'),
        isNull,
      );
      expect(
        TorrentMetaParser.streamSizeBytesForFilters({
          'title': 'Reacher S1E1',
          'behaviorHints': {'videoSize': 4096},
        }),
        0,
      );
    });

    test('parses real size tokens', () {
      expect(
        TorrentMetaParser.resolveSizeLabel(fallbackText: 'release 1.2 GB'),
        '1.2 GB',
      );
      expect(
        TorrentMetaParser.resolveSizeLabel(fallbackText: '850 MB HEVC'),
        '850 MB',
      );
    });
  });
}
