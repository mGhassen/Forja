import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  tearDown(() {
    TmdbWatchRegion.resolve = null;
  });

  test('normalize accepts ISO 3166-1 alpha-2', () {
    expect(TmdbWatchRegion.normalize('fr'), 'FR');
    expect(TmdbWatchRegion.normalize(' US '), 'US');
    expect(TmdbWatchRegion.normalize('gb'), 'GB');
  });

  test('normalize falls back for invalid codes', () {
    expect(TmdbWatchRegion.normalize(null), 'US');
    expect(TmdbWatchRegion.normalize(''), 'US');
    expect(TmdbWatchRegion.normalize('FRA'), 'US');
    expect(TmdbWatchRegion.normalize('12'), 'US');
  });

  test('current uses resolver when set', () {
    TmdbWatchRegion.resolve = () => 'de';
    expect(TmdbWatchRegion.current, 'DE');
  });

  test('current falls back when resolver missing', () {
    expect(TmdbWatchRegion.current, 'US');
  });
}
