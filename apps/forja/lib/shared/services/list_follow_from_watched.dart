import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/catalog_details_fetch.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:rust/rust.dart';

/// Bumps My List + Simkl list buckets from episode watched marks / movie play.
///
/// History sync stays in [syncEpisodeWatchedToTrackers] /
/// [HubListFollow.syncEpisodeWatched]. This only moves list status:
/// - first mark (or Plan to Watch) → Watching
/// - all episodes marked → Completed
/// - unmark while Completed → Watching
/// - movie play (new / Plan to Watch) → Watching
/// - movie ≥ [watchFinishedThreshold] → Completed
class ListFollowFromWatched {
  ListFollowFromWatched._();

  /// Next list status, or null when nothing should change.
  static String? nextStatus({
    required String? current,
    required int watchedCount,
    required int totalEpisodes,
    required bool episodeNowWatched,
  }) {
    if (totalEpisodes > 0 && watchedCount >= totalEpisodes) {
      if (current == 'completed') return null;
      return 'completed';
    }
    if (episodeNowWatched) {
      if (current == null || current == 'plantowatch') return 'watching';
      return null;
    }
    if (current == 'completed') return 'watching';
    return null;
  }

  static Future<void> applyTmdb({
    required Movie movie,
    required int watchedCount,
    required int totalEpisodes,
    required bool episodeNowWatched,
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'tv') return;
    await MyListService().ensureLoaded();
    final uid = MyListService.movieId(movie.id, movie.mediaType);
    final current = MyListService().contains(uid)
        ? MyListService().statusOf(uid)
        : null;
    final to = nextStatus(
      current: current,
      watchedCount: watchedCount,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: episodeNowWatched,
    );
    if (to == null) return;
    await _setTmdbStatus(movie, to, container: container);
  }

  static Future<void> applyHub({
    required HubListFollowTarget target,
    required int watchedCount,
    required int totalEpisodes,
    required bool episodeNowWatched,
    ProviderContainer? container,
  }) async {
    await MyListService().ensureLoaded();
    final uid = target.uniqueId;
    final current = MyListService().contains(uid)
        ? MyListService().statusOf(uid)
        : null;
    final to = nextStatus(
      current: current,
      watchedCount: watchedCount,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: episodeNowWatched,
    );
    if (to == null) return;
    await HubListFollow.setStatus(target, to, container: container);
  }

  /// Same watched/total math as details hero progress — keeps the pin in sync.
  static Future<void> reconcileHub({
    required HubListFollowTarget target,
    required int watchedCount,
    required int totalEpisodes,
    ProviderContainer? container,
  }) async {
    if (totalEpisodes <= 0 || watchedCount <= 0) return;
    await applyHub(
      target: target,
      watchedCount: watchedCount,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: watchedCount >= totalEpisodes || watchedCount == 1,
      container: container,
    );
  }

  static Future<void> reconcileTmdb({
    required Movie movie,
    required int watchedCount,
    required int totalEpisodes,
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'tv') return;
    if (totalEpisodes <= 0 || watchedCount <= 0) return;
    await applyTmdb(
      movie: movie,
      watchedCount: watchedCount,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: watchedCount >= totalEpisodes || watchedCount == 1,
      container: container,
    );
  }

  /// Movie play start — same rules as [HubListFollow.markWatchingOnPlay].
  static Future<void> markMovieWatchingOnPlay(
    Movie movie, {
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'movie') return;
    await MyListService().ensureLoaded();
    final uid = MyListService.movieId(movie.id, movie.mediaType);
    if (MyListService().contains(uid)) {
      final status = MyListService().statusOf(uid);
      if (status != 'plantowatch') return;
    }
    await _setTmdbStatus(movie, 'watching', container: container);
  }

  /// Movie reached finished threshold — set Completed (local + Simkl).
  static Future<void> markMovieCompletedIfFinished(
    Movie movie, {
    required int positionMs,
    required int durationMs,
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'movie') return;
    if (!isWatchFinished(positionMs, durationMs)) return;
    await MyListService().ensureLoaded();
    final uid = MyListService.movieId(movie.id, movie.mediaType);
    if (MyListService().contains(uid) &&
        MyListService().statusOf(uid) == 'completed') {
      return;
    }
    await _setTmdbStatus(movie, 'completed', container: container);
  }

  /// Details open with saved progress — pin catches up without re-play.
  static Future<void> reconcileMovieFromProgress(
    Movie movie, {
    required Map<String, dynamic>? progress,
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'movie' || progress == null) return;
    final pos = watchHistoryInt(progress['position']);
    final dur = watchHistoryInt(progress['duration']);
    if (dur <= 0 || pos < 10000) return;
    if (isWatchFinished(pos, dur)) {
      await markMovieCompletedIfFinished(
        movie,
        positionMs: pos,
        durationMs: dur,
        container: container,
      );
    } else {
      await markMovieWatchingOnPlay(movie, container: container);
    }
  }

  static bool _staleMyListReconciled = false;

  /// Watch marks / movie progress already say Completed, but My List still
  /// shows Watching until details open — catch up without visiting each title.
  static Future<int> reconcileStaleMyList({
    ProviderContainer? container,
    bool force = false,
  }) async {
    if (_staleMyListReconciled && !force) return 0;
    _staleMyListReconciled = true;
    await MyListService().ensureLoaded();
    var bumped = 0;
    final items = List<Map<String, dynamic>>.from(MyListService().items);
    for (final item in items) {
      final status = item['listStatus']?.toString() ?? '';
      if (status == 'completed' || status == 'dropped' || status == 'hold') {
        continue;
      }
      try {
        if (await _reconcileStaleItem(item, container: container)) {
          bumped++;
        }
      } catch (e) {
        debugPrint('[ListFollow] stale reconcile skip ${item['uniqueId']}: $e');
      }
    }
    if (bumped > 0) {
      debugPrint('[ListFollow] Stale My List → Completed: $bumped');
      container?.invalidate(simklWatchlistProvider);
    }
    return bumped;
  }

  static Future<bool> _reconcileStaleItem(
    Map<String, dynamic> item, {
    ProviderContainer? container,
  }) async {
    final mt = item['mediaType']?.toString() ?? '';
    if (mt == 'movie') {
      final tmdbId = item['tmdbId'] as int?;
      if (tmdbId == null) return false;
      final progress = await WatchHistoryService().getProgress(tmdbId);
      if (progress == null) return false;
      final pos = watchHistoryInt(progress['position']);
      final dur = watchHistoryInt(progress['duration']);
      if (!isWatchFinished(pos, dur)) return false;
      final before = MyListService().statusOf(
        MyListService.movieId(tmdbId, 'movie'),
      );
      await markMovieCompletedIfFinished(
        _movieFromListItem(item, tmdbId),
        positionMs: pos,
        durationMs: dur,
        container: container,
      );
      return before != 'completed';
    }

    if (mt == 'tv' || mt == 'series') {
      final tmdbId = item['tmdbId'] as int?;
      if (tmdbId == null) return false;
      final watched = (await EpisodeWatchedService().getWatchedSet(
        tmdbId,
      )).length;
      if (watched <= 0) return false;
      final details = await TmdbApi().getTvDetails(tmdbId);
      final total = details.numberOfEpisodes;
      if (total <= 0 || watched < total) return false;
      final uid = MyListService.movieId(tmdbId, 'tv');
      final before = MyListService().contains(uid)
          ? MyListService().statusOf(uid)
          : null;
      await applyTmdb(
        movie: details,
        watchedCount: watched,
        totalEpisodes: total,
        episodeNowWatched: true,
        container: container,
      );
      return before != 'completed';
    }

    if (mt == 'anime') {
      final anilistId = item['anilistId'] as int?;
      if (anilistId == null) return false;
      final pluginId =
          item['pluginId']?.toString() ??
          await PluginNavRegistry.pluginIdForTab('anime') ??
          '';
      if (pluginId.isEmpty) return false;
      final watched = (await EpisodeWatchedService().getWatchedSet(
        anilistId,
        catalog: pluginId,
      )).length;
      if (watched <= 0) return false;
      final meta = await fetchCatalogMetaDetails(
        pluginId: pluginId,
        metaId: item['metaId']?.toString() ?? '$pluginId:$anilistId',
      );
      final total =
          meta?.episodes ?? (item['totalEpisodes'] as num?)?.toInt() ?? 0;
      if (total <= 0 || watched < total) return false;
      final open =
          CatalogOpen.fromJson(item['catalogOpen']) ??
          CatalogOpen(
            surface: 'anime',
            id: anilistId.toString(),
            extract: CatalogOpenExtract(
              resolveType: 'anime',
              panelCategory: 'anime',
              ctx: {'anilistId': anilistId},
            ),
          );
      final target = CatalogListFollowTarget(
        pluginId: pluginId,
        open: open,
        title: item['title']?.toString() ?? meta?.name ?? '',
        posterPath: item['posterPath']?.toString() ?? meta?.poster ?? '',
        voteAverage:
            (item['voteAverage'] as num?)?.toDouble() ?? (meta?.rating ?? 0),
        releaseDate: item['releaseDate']?.toString() ?? meta?.releaseInfo ?? '',
        mediaType: 'anime',
      );
      final before = MyListService().contains(target.uniqueId)
          ? MyListService().statusOf(target.uniqueId)
          : null;
      await reconcileHub(
        target: target,
        watchedCount: watched,
        totalEpisodes: total,
        container: container,
      );
      return before != 'completed';
    }

    if (mt == 'asian_drama') {
      final kisskhId = item['kisskhId'] as int?;
      if (kisskhId == null) return false;
      final pluginId =
          item['pluginId']?.toString() ??
          await PluginNavRegistry.pluginIdForTab('asian_drama') ??
          '';
      if (pluginId.isEmpty) return false;
      final watched = (await EpisodeWatchedService().getWatchedSet(
        kisskhId,
        catalog: pluginId,
      )).length;
      if (watched <= 0) return false;
      final meta = await fetchCatalogMetaDetails(
        pluginId: pluginId,
        metaId: item['metaId']?.toString() ?? '$pluginId:$kisskhId',
      );
      final total = (meta?.videos.isNotEmpty ?? false)
          ? meta!.videos.length
          : (meta?.episodes ?? (item['totalEpisodes'] as num?)?.toInt() ?? 0);
      if (total <= 0 || watched < total) return false;
      final open =
          CatalogOpen.fromJson(item['catalogOpen']) ??
          CatalogOpen(
            surface: 'drama',
            id: kisskhId.toString(),
            extract: CatalogOpenExtract(
              resolveType: 'drama',
              panelCategory: 'drama',
              ctx: {'kisskhId': kisskhId},
            ),
          );
      final target = CatalogListFollowTarget(
        pluginId: pluginId,
        open: open,
        title: item['title']?.toString() ?? meta?.name ?? '',
        posterPath: item['posterPath']?.toString() ?? meta?.poster ?? '',
        tmdbId: item['tmdbId'] as int? ?? meta?.open?.idInt,
        tmdbMediaType: item['tmdbMediaType']?.toString() ?? meta?.tmdbMediaType,
        releaseDate: item['releaseDate']?.toString() ?? meta?.releaseInfo ?? '',
        mediaType: 'asian_drama',
      );
      final before = MyListService().contains(target.uniqueId)
          ? MyListService().statusOf(target.uniqueId)
          : null;
      await reconcileHub(
        target: target,
        watchedCount: watched,
        totalEpisodes: total,
        container: container,
      );
      return before != 'completed';
    }

    return false;
  }

  static Movie _movieFromListItem(Map<String, dynamic> item, int tmdbId) {
    return Movie(
      id: tmdbId,
      imdbId: item['imdbId']?.toString(),
      title: item['title']?.toString() ?? '',
      posterPath: item['posterPath']?.toString() ?? '',
      backdropPath: '',
      voteAverage: (item['voteAverage'] as num?)?.toDouble() ?? 0,
      releaseDate: item['releaseDate']?.toString() ?? '',
      overview: '',
      genres: const [],
      runtime: 0,
      mediaType: 'movie',
    );
  }

  static Future<bool> _setTmdbStatus(
    Movie movie,
    String to, {
    ProviderContainer? container,
  }) async {
    if (to.isEmpty) return false;
    await MyListService().upsertMovie(
      tmdbId: movie.id,
      imdbId: movie.imdbId,
      title: movie.title,
      posterPath: movie.posterPath,
      mediaType: movie.mediaType,
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
      listStatus: to,
    );
    var ok = true;
    if (await SimklService().isLoggedIn()) {
      ok = await SimklService().setListStatus(
        tmdbId: movie.id,
        imdbId: movie.imdbId,
        mediaType: movie.mediaType,
        to: to,
      );
    }
    if ((to == 'plantowatch' || to == 'watching') &&
        await TraktService().isLoggedIn()) {
      await TraktService().addToWatchlist(
        tmdbId: movie.id,
        imdbId: movie.imdbId,
        mediaType: movie.mediaType,
      );
    }
    container?.invalidate(simklWatchlistProvider);
    return ok;
  }

  /// After [EpisodeWatchedService.markWatchedIfFinished] returns true for TMDB TV.
  static Future<void> applyTmdbAfterAutoMark({
    required Movie movie,
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'tv') return;
    final set = await EpisodeWatchedService().getWatchedSet(movie.id);
    await applyTmdb(
      movie: movie,
      watchedCount: set.length,
      totalEpisodes: movie.numberOfEpisodes,
      episodeNowWatched: true,
      container: container,
    );
  }

  /// After hub auto-mark returns true.
  static Future<void> applyHubAfterAutoMark({
    required HubListFollowTarget target,
    required int mediaId,
    required String catalog,
    required int totalEpisodes,
    ProviderContainer? container,
  }) async {
    final set = await EpisodeWatchedService().getWatchedSet(
      mediaId,
      catalog: catalog,
    );
    await applyHub(
      target: target,
      watchedCount: set.length,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: true,
      container: container,
    );
  }
}
