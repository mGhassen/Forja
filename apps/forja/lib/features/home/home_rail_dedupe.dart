import 'package:rust/rust.dart';

/// How many posters a discovery rail aims to show after claim + backfill.
const kHomeRailDisplayCap = 20;

/// Hero carousel length — only these trending titles are claimed from the pool.
const kHomeHeroClaimCount = 5;

/// TMDB pages to fetch per rail on first paint (one page ≈ 20 titles).
const kHomeRailFetchPages = 1;

/// Extra TMDB page loaded when the row scroller approaches the end.
const kHomeRailLoadMorePage = 2;

String homeMediaKey(Movie movie) => '${movie.mediaType}:${movie.id}';

String homeMediaKeyParts(String mediaType, int id) => '$mediaType:$id';

/// TMDB keys for titles currently in Continue Watching (claim so they don't
/// reappear in lower discovery rails).
Set<String> homeContinueWatchingKeys(
  Iterable<Map<String, dynamic>> history,
) {
  final keys = <String>{};
  for (final item in history) {
    final id = item['tmdbId'];
    if (id is! int) continue;
    final mediaType = item['mediaType']?.toString() ??
        (item['season'] != null ? 'tv' : 'movie');
    final type =
        (mediaType == 'tv' || mediaType == 'series') ? 'tv' : 'movie';
    keys.add(homeMediaKeyParts(type, id));
  }
  return keys;
}

enum HomeRailClaimMode {
  /// Skip already-claimed titles; claim what we show (discovery rails).
  exclusive,

  /// Always show; still claim keys (Continue Watching).
  overlayClaim,

  /// Always show; do not claim (Trakt calendars).
  overlayIgnore,
}

class HomeRailSpec {
  const HomeRailSpec({
    required this.id,
    this.pool = const [],
    this.keysOnly,
    this.cap = kHomeRailDisplayCap,
    this.mode = HomeRailClaimMode.exclusive,
  });

  /// Rail id used in the result map (`hero`, `featured`, …).
  final String id;

  /// Candidate titles in preference order (already over-fetched).
  final List<Movie> pool;

  /// When set, only add these keys to [claimed] (no display list). Used for CW.
  final Set<String>? keysOnly;

  final int cap;
  final HomeRailClaimMode mode;
}

/// Walk rails in visual priority order. Each exclusive rail backfills from its
/// pool until [cap] or the pool is exhausted.
Map<String, List<Movie>> claimHomeRails(Iterable<HomeRailSpec> rails) {
  final claimed = <String>{};
  final out = <String, List<Movie>>{};

  for (final rail in rails) {
    final keysOnly = rail.keysOnly;
    if (keysOnly != null) {
      if (rail.mode != HomeRailClaimMode.overlayIgnore) {
        claimed.addAll(keysOnly);
      }
      out[rail.id] = const [];
      continue;
    }

    final selected = <Movie>[];
    for (final movie in rail.pool) {
      if (selected.length >= rail.cap) break;
      final key = homeMediaKey(movie);
      if (rail.mode == HomeRailClaimMode.exclusive && claimed.contains(key)) {
        continue;
      }
      selected.add(movie);
      if (rail.mode != HomeRailClaimMode.overlayIgnore) {
        claimed.add(key);
      }
    }
    out[rail.id] = selected;
  }

  return out;
}

/// No cross-rail claim — each rail takes up to [HomeRailSpec.cap] from its own
/// pool. Used when Categories forces every rail onto the same genre discover.
Map<String, List<Movie>> fillHomeRailsIndependently(
  Iterable<HomeRailSpec> rails,
) {
  final out = <String, List<Movie>>{};
  for (final rail in rails) {
    if (rail.keysOnly != null) {
      out[rail.id] = const [];
      continue;
    }
    out[rail.id] = rail.pool.take(rail.cap).toList();
  }
  return out;
}

/// Merge page results preserving first-seen order.
List<Movie> mergeHomeRailPages(List<List<Movie>> pages) {
  final out = <Movie>[];
  final seen = <String>{};
  for (final page in pages) {
    for (final movie in page) {
      if (seen.add(homeMediaKey(movie))) out.add(movie);
    }
  }
  return out;
}
