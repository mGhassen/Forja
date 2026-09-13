import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/host/lists_ui/external_list_providers.dart';
import 'package:rust/rust.dart';

/// Bumps when [BookmarkStore.changeNotifier] changes.
final bookmarkRevisionProvider = NotifierProvider<BookmarkRevisionNotifier, int>(
  BookmarkRevisionNotifier.new,
);

class BookmarkRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = BookmarkStore.changeNotifier;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// Explicit bump after bookmark writes — My List feed must rebuild past EngineCache.
final listFeedEpochProvider = NotifierProvider<ListFeedEpochNotifier, int>(
  ListFeedEpochNotifier.new,
);

class ListFeedEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// After a local bookmark write — bust EngineCache `feed` + list providers.
/// Pin updates from [BookmarkStore] immediately; the grid must not keep a
/// stale composed feed until pull-to-refresh.
void invalidateListHubFeeds(ProviderContainer? container) {
  EngineCache.instance.wipeAction('feed');
  if (container == null) return;
  try {
    container.invalidate(simklWatchlistProvider);
    container.read(listFeedEpochProvider.notifier).bump();
  } catch (_) {}
}

/// Local bookmark rows (persist engine).
final bookmarkItemsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(bookmarkRevisionProvider);
  return BookmarkStore().items;
});

/// Keys hidden from a list grid until Simkl refetch catches up after a local
/// remove (e.g. `tmdb_movie_123`, `open:anime:123`).
final bookmarkHiddenKeysProvider =
    NotifierProvider<BookmarkHiddenKeysNotifier, Set<String>>(
      BookmarkHiddenKeysNotifier.new,
    );

class BookmarkHiddenKeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void addAll(Iterable<String> keys) {
    final next = {...state};
    var changed = false;
    for (final k in keys) {
      if (k.isEmpty) continue;
      if (next.add(k)) changed = true;
    }
    if (changed) state = next;
  }

  /// Keep hides only for ids still present in [cards] (Simkl lag).
  void retainOnlyPresentIn(Iterable<Map<String, dynamic>> cards) {
    if (state.isEmpty) return;
    final present = <String>{};
    for (final c in cards) {
      present.addAll(bookmarkItemHideKeys(c));
    }
    final next = state.intersection(present);
    if (next.length != state.length) state = next;
  }
}

/// Stable identity keys for a bookmark / Simkl card row.
Set<String> bookmarkItemHideKeys(Map<String, dynamic> item) {
  final keys = <String>{};
  final open = item['metaOpen'] ?? item['open'] ?? item['catalogOpen'];
  if (open is Map) {
    final surface = open['surface']?.toString().trim() ?? '';
    final id = open['id']?.toString().trim() ?? '';
    if (surface.isNotEmpty && id.isNotEmpty) {
      keys.add('open:$surface:$id');
    }
  }
  final tmdb = item['tmdbId'];
  if (tmdb is int) {
    final mt = item['mediaType']?.toString() ?? 'movie';
    if (mt == 'asian_drama') {
      final tmt = item['tmdbMediaType']?.toString() ?? 'tv';
      keys.add(BookmarkStore.movieId(tmdb, tmt == 'movie' ? 'movie' : 'tv'));
    } else if (mt == 'anime') {
      // Anime cards are keyed by open surface; skip bare tmdb.
    } else {
      final norm = (mt == 'tv' || mt == 'series' || mt == 'shows')
          ? 'tv'
          : 'movie';
      keys.add(BookmarkStore.movieId(tmdb, norm));
    }
  }
  return keys;
}
