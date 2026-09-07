import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/lib/cover_urls.dart';

void main() {
  test('normalizeCoverUrl rewrites media.themoviedb.org to image CDN', () {
    expect(
      normalizeCoverUrl(
        'https://media.themoviedb.org/t/p/w1000_and_h563_face/abc.jpg',
      ),
      'https://image.tmdb.org/t/p/w1000_and_h563_face/abc.jpg',
    );
  });

  test('normalizeCoverUrl leaves non-TMDB hosts unchanged', () {
    const proxy = 'https://serveproxy.com/?url=https://x/y.jpg';
    expect(normalizeCoverUrl(proxy), proxy);
    expect(normalizeCoverUrl(''), '');
  });
}
