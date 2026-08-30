import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/home/home_rail_dedupe.dart';
import 'package:rust/rust.dart';

Movie _m(int id) => Movie(
      id: id,
      title: 'Title $id',
      mediaType: 'movie',
      posterPath: '',
      backdropPath: '',
      voteAverage: 0,
      releaseDate: '',
    );

void main() {
  test('mergeHomeRailPages keeps first-seen order', () {
    final merged = mergeHomeRailPages([
      [_m(1), _m(2)],
      [_m(2), _m(3)],
    ]);
    expect(merged.map((m) => m.id).toList(), [1, 2, 3]);
  });
}
