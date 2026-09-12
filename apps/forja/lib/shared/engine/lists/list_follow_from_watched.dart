import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/lists/external_list_providers.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart';

/// Bumps bookmark + Simkl list buckets from episode watched marks / movie play.
///
/// History sync stays in [syncEpisodeWatchedToTrackers] /
/// [ListFollow.syncEpisodeWatched]. This only moves list status:
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
    await BookmarkStore().ensureLoaded();
    final uid = BookmarkStore.movieId(movie.id, movie.mediaType);
    final current = BookmarkStore().contains(uid)
        ? BookmarkStore().statusOf(uid)
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
    required ListFollowTarget target,
    required int watchedCount,
    required int totalEpisodes,
    required bool episodeNowWatched,
    ProviderContainer? container,
  }) async {
    await BookmarkStore().ensureLoaded();
    final uid = target.uniqueId;
    final current = BookmarkStore().contains(uid)
        ? BookmarkStore().statusOf(uid)
        : null;
    final to = nextStatus(
      current: current,
      watchedCount: watchedCount,
      totalEpisodes: totalEpisodes,
      episodeNowWatched: episodeNowWatched,
    );
    if (to == null) return;
    await ListFollow.setStatus(target, to, container: container);
  }

  /// Same watched/total math as details hero progress — keeps the pin in sync.
  static Future<void> reconcileHub({
    required ListFollowTarget target,
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

  /// Movie play start — same rules as [ListFollow.markWatchingOnPlay].
  static Future<void> markMovieWatchingOnPlay(
    Movie movie, {
    ProviderContainer? container,
  }) async {
    if (movie.mediaType != 'movie') return;
    await BookmarkStore().ensureLoaded();
    final uid = BookmarkStore.movieId(movie.id, movie.mediaType);
    if (BookmarkStore().contains(uid)) {
      final status = BookmarkStore().statusOf(uid);
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
    await BookmarkStore().ensureLoaded();
    final uid = BookmarkStore.movieId(movie.id, movie.mediaType);
    if (BookmarkStore().contains(uid) &&
        BookmarkStore().statusOf(uid) == 'completed') {
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

  static Future<bool> _setTmdbStatus(
    Movie movie,
    String to, {
    ProviderContainer? container,
  }) async {
    if (to.isEmpty) return false;
    await BookmarkStore().upsertMovie(
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
    required ListFollowTarget target,
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
