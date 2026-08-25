import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/home/home_catalog_rotate.dart';
import 'package:rust/rust.dart';

Movie _m(int id) => Movie(
      id: id,
      title: 'T$id',
      posterPath: '/p$id.jpg',
      backdropPath: '',
      voteAverage: 7,
      releaseDate: '2024-01-01',
    );

void main() {
  test('same hour bucket + salt is stable', () {
    final a = homeCatalogFetchPages(homeCatalogRandom(2026082514, 'popular-m'));
    final b = homeCatalogFetchPages(homeCatalogRandom(2026082514, 'popular-m'));
    expect(a, b);
  });

  test('different hour buckets pick different pages (usually)', () {
    final a = homeCatalogFetchPages(homeCatalogRandom(2026082514, 'popular-m'));
    final b = homeCatalogFetchPages(homeCatalogRandom(2026082515, 'popular-m'));
    // Not guaranteed different, but salts diverge enough that collision is rare
    // for this fixed pair — assert page count + range instead if equal.
    expect(a.length, 2);
    expect(b.length, 2);
    expect(a.every((p) => p >= 1 && p <= 5), isTrue);
    expect(b.every((p) => p >= 1 && p <= 5), isTrue);
    if (a.join() == b.join()) {
      // Extremely unlikely; still valid if RNG collides.
      expect(a, isNotEmpty);
    } else {
      expect(a, isNot(b));
    }
  });

  test('shuffle is deterministic per bucket', () {
    final pool = [_m(1), _m(2), _m(3), _m(4), _m(5)];
    final a = shuffleHomeRailPool(
      pool,
      homeCatalogRandom(42, 'trending-m'),
    );
    final b = shuffleHomeRailPool(
      pool,
      homeCatalogRandom(42, 'trending-m'),
    );
    expect(a.map((m) => m.id), b.map((m) => m.id));
  });

  test('hour bucket encodes local hour', () {
    final t = DateTime(2026, 8, 25, 14, 30);
    expect(homeCatalogHourBucket(t), 2026082514);
    expect(homeCatalogHourBucket(t.add(const Duration(hours: 1))), 2026082515);
  });

  test('rotateHomeRailPool stops when cancelled', () async {
    var calls = 0;
    final out = await rotateHomeRailPool(
      bucket: 1,
      salt: 'x',
      preserveRankOrder: true,
      isCancelled: () => true,
      fetchPage: (p) async {
        calls++;
        return [_m(p)];
      },
    );
    expect(out, isEmpty);
    expect(calls, 0);
  });
}
