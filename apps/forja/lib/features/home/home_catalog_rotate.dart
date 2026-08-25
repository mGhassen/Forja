import 'dart:math' as math;

import 'package:rust/rust.dart';

import 'package:forja/features/home/home_rail_dedupe.dart';

/// Hourly catalog mix — same hour ⇒ same pages/shuffle; next hour ⇒ new mix.
int homeCatalogHourBucket([DateTime? now]) {
  final t = now ?? DateTime.now();
  return t.year * 1000000 + t.month * 10000 + t.day * 100 + t.hour;
}

/// Deterministic RNG for a bucket + rail salt (stable within the hour).
math.Random homeCatalogRandom(int bucket, String salt) {
  return math.Random(Object.hash(bucket, salt));
}

/// Pick [count] distinct TMDB pages in `1..maxPage` (always includes variety).
List<int> homeCatalogFetchPages(
  math.Random rng, {
  int count = kHomeRailFetchPages,
  int maxPage = 5,
}) {
  final pages = List<int>.generate(maxPage, (i) => i + 1)..shuffle(rng);
  final picked = pages.take(count).toList()..sort();
  return picked;
}

List<Movie> shuffleHomeRailPool(List<Movie> pool, math.Random rng) {
  if (pool.length < 2) return pool;
  final out = List<Movie>.of(pool)..shuffle(rng);
  return out;
}

/// Fetch pages for this hour's mix, merge, then shuffle for display order.
Future<List<Movie>> rotateHomeRailPool({
  required int bucket,
  required String salt,
  required Future<List<Movie>> Function(int page) fetchPage,
  List<Movie>? page1Cache,
  /// Popular / ranked rankings stay TMDB order (no random pages / shuffle).
  bool preserveRankOrder = false,
}) async {
  final rng = homeCatalogRandom(bucket, salt);
  final pageNums = preserveRankOrder
      ? List<int>.generate(kHomeRailFetchPages, (i) => i + 1)
      : homeCatalogFetchPages(rng);

  Future<List<Movie>> one(int p) =>
      fetchPage(p).catchError((_) => <Movie>[]);

  final List<List<Movie>> chunks;
  if (page1Cache != null && pageNums.contains(1)) {
    chunks = await Future.wait([
      for (final p in pageNums)
        if (p == 1) Future.value(page1Cache) else one(p),
    ]);
  } else if (page1Cache != null) {
    chunks = [
      page1Cache,
      ...await Future.wait([for (final p in pageNums) one(p)]),
    ];
  } else {
    chunks = await Future.wait([for (final p in pageNums) one(p)]);
  }

  final merged = mergeHomeRailPages(chunks);
  if (preserveRankOrder) return merged;
  return shuffleHomeRailPool(merged, rng);
}
