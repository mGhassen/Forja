import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/hub_cover_urls.dart';

void main() {
  test('normalizeHubCoverUrl rewrites media.themoviedb.org to image CDN', () {
    expect(
      normalizeHubCoverUrl(
        'https://media.themoviedb.org/t/p/w1000_and_h563_face/abc.jpg',
      ),
      'https://image.tmdb.org/t/p/w1000_and_h563_face/abc.jpg',
    );
  });

  test('normalizeHubCoverUrl leaves non-TMDB hosts unchanged', () {
    const proxy = 'https://serveproxy.com/?url=https://x/y.jpg';
    expect(normalizeHubCoverUrl(proxy), proxy);
    expect(normalizeHubCoverUrl(''), '');
  });
}
