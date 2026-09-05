import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Bumps when [MyListService.changeNotifier] changes.
final myListRevisionProvider = NotifierProvider<MyListRevisionNotifier, int>(
  MyListRevisionNotifier.new,
);

class MyListRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = MyListService.changeNotifier;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// My List tab items (backend remains [MyListService]).
final myListItemsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(myListRevisionProvider);
  return MyListService().items;
});

/// Keys hidden from the My List grid until Simkl refetch catches up after a
/// local remove (e.g. `tmdb_movie_123`, `anilist_456`, `kisskh_789`).
final myListHiddenKeysProvider =
    NotifierProvider<MyListHiddenKeysNotifier, Set<String>>(
      MyListHiddenKeysNotifier.new,
    );

class MyListHiddenKeysNotifier extends Notifier<Set<String>> {
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

  /// Keep hides only for ids still present in [cards] (Simkl lag). Drop the
  /// rest — Simkl confirmed the remove.
  void retainOnlyPresentIn(Iterable<Map<String, dynamic>> cards) {
    if (state.isEmpty) return;
    final present = <String>{};
    for (final c in cards) {
      present.addAll(myListItemHideKeys(c));
    }
    final next = state.intersection(present);
    if (next.length != state.length) state = next;
  }
}

/// Stable identity keys for a My List / Simkl card row.
Set<String> myListItemHideKeys(Map<String, dynamic> item) {
  final keys = <String>{};
  final anilist = item['anilistId'];
  if (anilist is int) keys.add('anilist_$anilist');
  final kisskh = item['kisskhId'];
  if (kisskh is int) keys.add('kisskh_$kisskh');
  final open = item['catalogOpen'];
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
      keys.add(MyListService.movieId(tmdb, tmt == 'movie' ? 'movie' : 'tv'));
    } else if (mt == 'anime') {
      // Anime cards are keyed by AniList; skip tmdb.
    } else {
      final norm = (mt == 'tv' || mt == 'series' || mt == 'shows')
          ? 'tv'
          : 'movie';
      keys.add(MyListService.movieId(tmdb, norm));
    }
  }
  return keys;
}
