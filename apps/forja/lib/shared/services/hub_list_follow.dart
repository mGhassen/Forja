import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/features/my_list/providers/my_list_providers.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Generic list-follow target — keyed by hub [pluginId] + opaque [open].
class CatalogListFollowTarget {
  const CatalogListFollowTarget({
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
  final CatalogOpen open;
  final String title;
  final String posterPath;
  final double voteAverage;
  final String releaseDate;
  final int? tmdbId;
  final String? tmdbMediaType;
  final String? mediaType;

  String get resolvedMediaType =>
      mediaType ?? open.effectiveExtract.panelCategory;

  String get uniqueId => MyListService.catalogEntryId(pluginId, open.id);

  int? get mediaIdInt => open.idInt;

  CatalogListFollowTarget copyWith({int? tmdbId, String? tmdbMediaType}) {
    return CatalogListFollowTarget(
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

  static CatalogListFollowTarget? fromMeta({
    required String pluginId,
    required CatalogMetaItem meta,
  }) {
    final open = meta.open;
    if (open == null) return null;
    return CatalogListFollowTarget(
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

/// Back-compat alias — migrate imports to [CatalogListFollowTarget].
typedef HubListFollowTarget = CatalogListFollowTarget;

class HubListFollow {
  HubListFollow._();

  static Future<bool> setStatus(
    CatalogListFollowTarget raw,
    String to, {
    ProviderContainer? container,
  }) async {
    final t = raw;
    if (to.isEmpty) {
      final keys = <String>{t.uniqueId};
      if (t.tmdbId != null) {
        keys.add(MyListService.movieId(t.tmdbId!, t.tmdbMediaType ?? 'tv'));
      }
      container?.read(myListHiddenKeysProvider.notifier).addAll(keys);
      await MyListService().remove(t.uniqueId);
      var ok = true;
      if (await SimklService().isLoggedIn()) {
        if (t.resolvedMediaType == 'anime' && t.mediaIdInt != null) {
          ok = await SimklService().removeFromWatchlist(
            anilistId: t.mediaIdInt,
            mediaType: 'anime',
          );
        } else if (t.tmdbId != null) {
          ok = await SimklService().removeFromWatchlist(
            tmdbId: t.tmdbId,
            mediaType: t.tmdbMediaType ?? 'tv',
          );
        }
      }
      _invalidate(container);
      return ok;
    }
    await MyListService().upsertCatalog(
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

    var ok = true;
    if (await SimklService().isLoggedIn()) {
      if (t.resolvedMediaType == 'anime' && t.mediaIdInt != null) {
        ok = await SimklService().setListStatus(
          anilistId: t.mediaIdInt,
          mediaType: 'anime',
          to: to,
        );
      } else if (t.tmdbId != null) {
        ok = await SimklService().setListStatus(
          tmdbId: t.tmdbId,
          mediaType: t.tmdbMediaType ?? 'tv',
          to: to,
        );
      } else {
        ok = false;
      }
    }
    if (t.tmdbId != null &&
        (to == 'plantowatch' || to == 'watching') &&
        await TraktService().isLoggedIn()) {
      await TraktService().addToWatchlist(
        tmdbId: t.tmdbId,
        mediaType: t.tmdbMediaType ?? 'tv',
      );
    }
    _invalidate(container);
    return ok;
  }

  static Future<void> markWatchingOnPlay(CatalogListFollowTarget raw) async {
    await MyListService().ensureLoaded();
    final uid = raw.uniqueId;
    if (MyListService().contains(uid)) {
      final status = MyListService().statusOf(uid);
      if (status != 'plantowatch') return;
    }
    await setStatus(raw, 'watching');
  }

  static Future<void> syncEpisodeWatched(
    CatalogListFollowTarget raw, {
    required int episode,
    bool watched = true,
  }) async {
    await syncSeasonWatched(raw, episodes: [episode], watched: watched);
  }

  static Future<void> syncSeasonWatched(
    CatalogListFollowTarget raw, {
    required List<int> episodes,
    bool watched = true,
  }) async {
    if (episodes.isEmpty) return;
    var t = raw;
    if (t.resolvedMediaType == 'drama' && t.tmdbId == null) {
      final stored = MyListService().itemOf(t.uniqueId);
      final storedTmdb = stored?['tmdbId'] as int?;
      final storedType = stored?['tmdbMediaType']?.toString();
      if (storedTmdb != null) {
        t = t.copyWith(tmdbId: storedTmdb, tmdbMediaType: storedType);
      }
    }

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

  static Future<void> clearProgress(CatalogListFollowTarget raw) async {
    if (!await SimklService().isLoggedIn()) return;
    if (raw.resolvedMediaType == 'anime' && raw.mediaIdInt != null) {
      await SimklService().clearWatched(
        anilistId: raw.mediaIdInt,
        mediaType: 'anime',
      );
      return;
    }
    final stored = MyListService().itemOf(raw.uniqueId);
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
