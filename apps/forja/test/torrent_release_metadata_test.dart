import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';

void main() {
  group('TorrentReleaseMetadata.resolveSizeLabel', () {
    test('drops bogus tiny sizes and quality tokens in the size slot', () {
      expect(
        TorrentReleaseMetadata.resolveSizeLabel(fallbackText: '1080p 4K WEB-DL'),
        isNull,
      );
      expect(
        TorrentReleaseMetadata.resolveSizeLabel(sizeText: '4K'),
        isNull,
      );
      expect(
        TorrentReleaseMetadata.resolveSizeLabel(sizeText: '4 KB'),
        isNull,
      );
      expect(
        TorrentReleaseMetadata.resolveSizeLabel(sizeText: '4096'),
        isNull,
      );
      expect(
        TorrentReleaseMetadata.streamSizeBytesForFilters({
          'title': 'Reacher S1E1',
          'behaviorHints': {'videoSize': 4096},
        }),
        0,
      );
    });

    test('parses real size tokens', () {
      expect(
        TorrentReleaseMetadata.resolveSizeLabel(fallbackText: 'release 1.2 GB'),
        '1.2 GB',
      );
      expect(
        TorrentReleaseMetadata.resolveSizeLabel(fallbackText: '850 MB HEVC'),
        '850 MB',
      );
    });
  });
}
