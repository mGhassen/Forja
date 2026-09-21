import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

void main() {
  group('paintableNetworkImageUrl', () {
    test('rewrites http(s) .svg to .png for Android ImageDecoder', () {
      expect(
        paintableNetworkImageUrl(
          'https://tmdb.forjahq.xyz/t/p/w500/logo.svg',
        ),
        'https://tmdb.forjahq.xyz/t/p/w500/logo.png',
      );
      expect(
        paintableNetworkImageUrl(
          'http://image.tmdb.org/t/p/original/Title.SVG',
        ),
        'http://image.tmdb.org/t/p/original/Title.png',
      );
    });

    test('leaves raster and non-http paths alone', () {
      expect(
        paintableNetworkImageUrl(
          'https://tmdb.forjahq.xyz/t/p/w500/poster.jpg',
        ),
        'https://tmdb.forjahq.xyz/t/p/w500/poster.jpg',
      );
      expect(
        paintableNetworkImageUrl('logos/netflix.svg'),
        'logos/netflix.svg',
      );
      expect(
        paintableNetworkImageUrl('file:///tmp/logos/netflix.svg'),
        'file:///tmp/logos/netflix.svg',
      );
    });
  });

  group('normalizeCoverUrl', () {
    test('rewrites official TMDB hosts and svg extension', () {
      expect(
        normalizeCoverUrl('https://image.tmdb.org/t/p/w500/logo.svg'),
        'https://tmdb.forjahq.xyz/t/p/w500/logo.png',
      );
    });
  });
}
