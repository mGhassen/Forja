import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

void main() {
  test('normalizeCoverUrl rewrites media.themoviedb.org to Forja gateway', () {
    expect(
      normalizeCoverUrl(
        'https://media.themoviedb.org/t/p/w1000_and_h563_face/abc.jpg',
      ),
      'https://tmdb.forjahq.xyz/t/p/w1000_and_h563_face/abc.jpg',
    );
  });

  test('normalizeCoverUrl rewrites image.tmdb.org to Forja gateway', () {
    expect(
      normalizeCoverUrl('https://image.tmdb.org/t/p/w500/abc.jpg'),
      'https://tmdb.forjahq.xyz/t/p/w500/abc.jpg',
    );
  });

  test('normalizeCoverUrl unwraps serveproxy to the image URL', () {
    expect(
      normalizeCoverUrl('https://serveproxy.com/?url=https://x/y.jpg'),
      'https://x/y.jpg',
    );
    expect(
      normalizeCoverUrl('https://example.com/poster.jpg'),
      'https://example.com/poster.jpg',
    );
    expect(normalizeCoverUrl(''), '');
  });
}
