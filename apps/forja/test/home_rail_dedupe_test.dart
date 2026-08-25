import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/home/home_rail_dedupe.dart';
import 'package:rust/rust.dart';

Movie _m(int id, {String type = 'movie'}) => Movie(
      id: id,
      title: 'T$id',
      posterPath: '/p$id.jpg',
      backdropPath: '',
      voteAverage: 7,
      releaseDate: '2024-01-01',
      mediaType: type,
    );

void main() {
  test('exclusive rails backfill and never reuse a claimed title', () {
    final displays = claimHomeRails([
      HomeRailSpec(id: 'hero', pool: [_m(1), _m(2), _m(3)], cap: 2),
      HomeRailSpec(
        id: 'featured',
        pool: [_m(1), _m(2), _m(4), _m(5), _m(6)],
        cap: 3,
      ),
      HomeRailSpec(
        id: 'popular',
        pool: [_m(2), _m(4), _m(5), _m(7), _m(8)],
        cap: 3,
      ),
    ]);

    expect(displays['hero']!.map((m) => m.id), [1, 2]);
    expect(displays['featured']!.map((m) => m.id), [4, 5, 6]);
    expect(displays['popular']!.map((m) => m.id), [7, 8]);
  });

  test('continue watching claims without filtering its own row', () {
    final displays = claimHomeRails([
      HomeRailSpec(id: 'hero', pool: [_m(1)], cap: 1),
      HomeRailSpec(
        id: 'continue',
        keysOnly: {'movie:1', 'movie:9'},
        mode: HomeRailClaimMode.overlayClaim,
      ),
      HomeRailSpec(id: 'popular', pool: [_m(1), _m(9), _m(10)], cap: 2),
    ]);

    expect(displays['popular']!.map((m) => m.id), [10]);
  });

  test('calendar overlayIgnore does not claim', () {
    final displays = claimHomeRails([
      HomeRailSpec(
        id: 'upcoming',
        pool: [_m(1)],
        mode: HomeRailClaimMode.overlayIgnore,
      ),
      HomeRailSpec(id: 'popular', pool: [_m(1), _m(2)], cap: 2),
    ]);

    expect(displays['popular']!.map((m) => m.id), [1, 2]);
  });

  test('independent fill keeps full slots per rail (genre mode)', () {
    final pool = [_m(1), _m(2), _m(3), _m(4)];
    final displays = fillHomeRailsIndependently([
      HomeRailSpec(id: 'hero', pool: pool, cap: 2),
      HomeRailSpec(id: 'popular', pool: pool, cap: 3),
    ]);

    expect(displays['hero']!.map((m) => m.id), [1, 2]);
    expect(displays['popular']!.map((m) => m.id), [1, 2, 3]);
  });

  test('mergeHomeRailPages keeps first-seen order', () {
    final merged = mergeHomeRailPages([
      [_m(1), _m(2)],
      [_m(2), _m(3)],
    ]);
    expect(merged.map((m) => m.id), [1, 2, 3]);
  });
}
