import 'package:flutter_riverpod/flutter_riverpod.dart';
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
