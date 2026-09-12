import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/lists/external_list_providers.dart';
import 'package:forja/shared/engine/lists/list_providers.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/tracker_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Generic list-follow target — keyed by hub [pluginId] + opaque [open].
class ListFollowTarget {
  const ListFollowTarget({
    required this.pluginId,
    required this.open,
    required this.title,
    required this.posterPath,
    this.voteAverage = 0,
    this.releaseDate = '',
    this.tmdbId,
    this.tmdbMediaType,
    this.mediaType,
  });

  final String pluginId;
  final MetaOpen open;
  final String title;
  final String posterPath;
  final double voteAverage;
  final String releaseDate;
  final int? tmdbId;
  final String? tmdbMediaType;
  final String? mediaType;

  String get resolvedMediaType =>
      mediaType ?? open.effectiveExtract.panelCategory;

  String get uniqueId => BookmarkStore.catalogEntryId(pluginId, open.id);

  int? get mediaIdInt => open.idInt;

  ListFollowTarget copyWith({int? tmdbId, String? tmdbMediaType}) {
    return ListFollowTarget(
      pluginId: pluginId,
      open: open,
      title: title,
      posterPath: posterPath,
      voteAverage: voteAverage,
      releaseDate: releaseDate,
      tmdbId: tmdbId ?? this.tmdbId,
      tmdbMediaType: tmdbMediaType ?? this.tmdbMediaType,
      mediaType: mediaType,
    );
  }

  static ListFollowTarget? fromMeta({
    required String pluginId,
    required MetaItem meta,
  }) {
    final open = meta.open;
    if (open == null) return null;
    return ListFollowTarget(
      pluginId: pluginId,
      open: open,
      title: meta.name,
      posterPath: meta.poster,
      voteAverage: meta.rating ?? 0,
      releaseDate: meta.releaseInfo,
      tmdbId: meta.numericId('tmdb'),
      tmdbMediaType: meta.tmdbMediaType,
      mediaType: meta.type,
    );
  }
}

class ListFollow {
  ListFollow._();

  /// Drama rows may lack TMDB on browse cards; reuse a stored match after details.
  @visibleForTesting
  static ListFollowTarget resolveSimklTarget(ListFollowTarget t) {
    if (t.tmdbId != null) return t;
    if (t.resolvedMediaType != 'drama') return t;
    final stored = BookmarkStore().itemOf(t.uniqueId);
    final storedTmdb = stored?['tmdbId'] as int?;
    if (storedTmdb == null) return t;
    return t.copyWith(
      tmdbId: storedTmdb,
      tmdbMediaType: stored?['tmdbMediaType']?.toString(),
    );
  }

  static Future<bool> setStatus(
    ListFollowTarget raw,
    String to, {
    ProviderContainer? container,
  }) async {
    await BookmarkStore().ensureLoaded();
    final t = raw;
    if (to.isEmpty) {
      final sync = resolveSimklTarget(t);
      final keys = <String>{t.uniqueId};
      if (sync.tmdbId != null) {
        keys.add(
          BookmarkStore.movieId(sync.tmdbId!, sync.tmdbMediaType ?? 'tv'),
        );
      }
      container?.read(bookmarkHiddenKeysProvider.notifier).addAll(keys);
      await BookmarkStore().remove(t.uniqueId);
      var ok = true;
      if (await SimklService().isLoggedIn()) {
        if (sync.resolvedMediaType == 'anime' && sync.mediaIdInt != null) {
          ok = await SimklService().removeFromWatchlist(
            anilistId: sync.mediaIdInt,
            mediaType: 'anime',
          );
        } else if (sync.tmdbId != null) {
          ok = await SimklService().removeFromWatchlist(
            tmdbId: sync.tmdbId,
            mediaType: sync.tmdbMediaType ?? 'tv',
          );
        }
      }
      _invalidate(container);
      return ok;
    }
    await BookmarkStore().upsertCatalog(
      pluginId: t.pluginId,
      open: t.open.toJson(),
      uniqueId: t.uniqueId,
      mediaType: t.resolvedMediaType,
      title: t.title,
      posterPath: t.posterPath,
      listStatus: to,
      tmdbId: t.tmdbId,
      tmdbMediaType: t.tmdbMediaType,
      voteAverage: t.voteAverage,
      releaseDate: t.releaseDate,
    );

    final sync = resolveSimklTarget(t);
    var ok = true;
    if (await SimklService().isLoggedIn()) {
      if (sync.resolvedMediaType == 'anime' && sync.mediaIdInt != null) {
        ok = await SimklService().setListStatus(
          anilistId: sync.mediaIdInt,
          mediaType: 'anime',
          to: to,
        );
      } else if (sync.tmdbId != null) {
        ok = await SimklService().setListStatus(
          tmdbId: sync.tmdbId,
          mediaType: sync.tmdbMediaType ?? 'tv',
          to: to,
        );
      }
    }
    _invalidate(container);
    return ok;
  }

  static Future<void> markWatchingOnPlay(ListFollowTarget raw) async {
    await BookmarkStore().ensureLoaded();
    final uid = raw.uniqueId;
    if (BookmarkStore().contains(uid)) {
      final status = BookmarkStore().statusOf(uid);
      if (status != 'plantowatch') return;
    }
    await setStatus(raw, 'watching');
  }

  static Future<void> syncEpisodeWatched(
    ListFollowTarget raw, {
    required int episode,
    bool watched = true,
  }) async {
    await syncSeasonWatched(raw, episodes: [episode], watched: watched);
  }

  static Future<void> syncSeasonWatched(
    ListFollowTarget raw, {
    required List<int> episodes,
    bool watched = true,
  }) async {
    if (episodes.isEmpty) return;
    var t = resolveSimklTarget(raw);

    if (t.resolvedMediaType == 'anime' && t.mediaIdInt != null) {
      if (!await SimklService().isLoggedIn()) return;
      final item = {
        'ids': {'anilist': t.mediaIdInt},
        'episodes': [
          for (final n in episodes) {'number': n},
        ],
      };
      if (watched) {
        await SimklService().addToHistory(anime: [item]);
      } else {
        await SimklService().removeFromHistory(anime: [item]);
      }
      return;
    }

    if (t.tmdbId == null) return;
    final mt = t.tmdbMediaType ?? 'tv';
    if (mt == 'movie') {
      if (!await SimklService().isLoggedIn()) return;
      final hist = {
        'ids': {'tmdb': t.tmdbId},
      };
      if (watched) {
        await SimklService().addToHistory(movies: [hist]);
      } else {
        await SimklService().removeFromHistory(movies: [hist]);
      }
      return;
    }

    if (await SimklService().isLoggedIn()) {
      final show = {
        'ids': {'tmdb': t.tmdbId},
        'seasons': [
          {
            'number': 1,
            'episodes': [
              for (final n in episodes) {'number': n},
            ],
          },
        ],
      };
      if (watched) {
        await SimklService().addToHistory(shows: [show]);
      } else {
        await SimklService().removeFromHistory(shows: [show]);
      }
    }
    for (final ep in episodes) {
      syncEpisodeWatchedToTrackers(t.tmdbId!, 1, ep, watched);
    }
  }

  static Future<void> clearProgress(ListFollowTarget raw) async {
    if (!await SimklService().isLoggedIn()) return;
    if (raw.resolvedMediaType == 'anime' && raw.mediaIdInt != null) {
      await SimklService().clearWatched(
        anilistId: raw.mediaIdInt,
        mediaType: 'anime',
      );
      return;
    }
    final stored = BookmarkStore().itemOf(raw.uniqueId);
    final tmdbId = raw.tmdbId ?? stored?['tmdbId'] as int?;
    final mt =
        raw.tmdbMediaType ?? stored?['tmdbMediaType']?.toString() ?? 'tv';
    if (tmdbId == null) return;
    await SimklService().clearWatched(tmdbId: tmdbId, mediaType: mt);
    syncProgressClearedToTrackers(tmdbId: tmdbId, mediaType: mt);
  }

  static void _invalidate(ProviderContainer? container) {
    final c = container;
    if (c == null) return;
    try {
      c.invalidate(simklWatchlistProvider);
    } catch (_) {}
  }
}
