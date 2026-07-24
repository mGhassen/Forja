import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';

void main() {
  test('normalizeCoverUrl rewrites media.themoviedb.org to image CDN', () {
    expect(
      KissKhService.normalizeCoverUrl(
        'https://media.themoviedb.org/t/p/w1000_and_h563_face/abc.jpg',
      ),
      'https://image.tmdb.org/t/p/w1000_and_h563_face/abc.jpg',
    );
  });

  test('normalizeCoverUrl leaves non-TMDB hosts unchanged', () {
    const proxy = 'https://serveproxy.com/?url=https://x/y.jpg';
    expect(KissKhService.normalizeCoverUrl(proxy), proxy);
    expect(KissKhService.normalizeCoverUrl(''), '');
  });
}
