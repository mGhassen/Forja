import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:rust/rust.dart';

/// Bumps My List + Simkl list buckets from episode watched marks.
///
/// History sync stays in [syncEpisodeWatchedToTrackers] /
/// [HubListFollow.syncEpisodeWatched]. This only moves list status:
/// - first mark (or Plan to Watch) → Watching
/// - all episodes marked → Completed
/// - unmark while Completed → Watching
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
    final current =
        MyListService().contains(uid) ? MyListService().statusOf(uid) : null;
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
    final current =
        MyListService().contains(uid) ? MyListService().statusOf(uid) : null;
    final to = nextStatus(
      current: current,
      watchedCount: watchedCount,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: episodeNowWatched,
    );
    if (to == null) return;
    await HubListFollow.setStatus(target, to, container: container);
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
