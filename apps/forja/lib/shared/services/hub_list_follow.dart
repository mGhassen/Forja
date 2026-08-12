import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

class HubListFollowTarget {
  const HubListFollowTarget.anime({
    required this.anilistId,
    required this.title,
    required this.posterPath,
    this.voteAverage = 0,
    this.releaseDate = '',
  })  : kisskhId = null,
        tmdbId = null,
        tmdbMediaType = null,
        kissKhType = null,
        mediaType = 'anime';

  const HubListFollowTarget.drama({
    required this.kisskhId,
    required this.title,
    required this.posterPath,
    this.tmdbId,
    this.tmdbMediaType,
    this.releaseDate = '',
    this.kissKhType,
    this.voteAverage = 0,
  })  : anilistId = null,
        mediaType = 'asian_drama';

  final String mediaType;
  final int? anilistId;
  final int? kisskhId;
  final int? tmdbId;
  final String? tmdbMediaType;
  final String title;
  final String posterPath;
  final double voteAverage;
  final String releaseDate;
  final String? kissKhType;

  String get uniqueId => mediaType == 'anime'
      ? MyListService.anilistId(anilistId!)
      : MyListService.kisskhId(kisskhId!);

  HubListFollowTarget copyWith({
    int? tmdbId,
    String? tmdbMediaType,
  }) {
    if (mediaType == 'anime') return this;
    return HubListFollowTarget.drama(
      kisskhId: kisskhId!,
      title: title,
      posterPath: posterPath,
      tmdbId: tmdbId ?? this.tmdbId,
      tmdbMediaType: tmdbMediaType ?? this.tmdbMediaType,
      releaseDate: releaseDate,
      kissKhType: kissKhType,
      voteAverage: voteAverage,
    );
  }
}

class HubListFollow {
  HubListFollow._();

  static Future<HubListFollowTarget> _withDramaTmdb(
    HubListFollowTarget t,
  ) async {
    if (t.mediaType != 'asian_drama' || t.tmdbId != null) return t;
    final match = await KissKhTmdbMatch.resolve(
      title: t.title,
      year: t.releaseDate,
      kissKhType: t.kissKhType,
    );
    if (match == null) return t;
    final mt = match.mediaType == 'movie' || match.mediaType == 'tv'
        ? match.mediaType
        : KissKhTmdbMatch.preferMovie(t.kissKhType)
            ? 'movie'
            : 'tv';
    return t.copyWith(tmdbId: match.id, tmdbMediaType: mt);
  }

  static Future<bool> setStatus(
    HubListFollowTarget raw,
    String to, {
    ProviderContainer? container,
  }) async {
    var t = await _withDramaTmdb(raw);
    await MyListService().upsertHub(
      uniqueId: t.uniqueId,
      mediaType: t.mediaType,
      title: t.title,
      posterPath: t.posterPath,
      listStatus: to,
      anilistId: t.anilistId,
      kisskhId: t.kisskhId,
      tmdbId: t.tmdbId,
      tmdbMediaType: t.tmdbMediaType,
      voteAverage: t.voteAverage,
      releaseDate: t.releaseDate,
      kissKhType: t.kissKhType,
    );

    var ok = true;
    if (await SimklService().isLoggedIn()) {
      if (t.mediaType == 'anime' && t.anilistId != null) {
        ok = await SimklService().setListStatus(
          anilistId: t.anilistId,
          mediaType: 'anime',
          to: to,
        );
      } else if (t.tmdbId != null) {
        ok = await SimklService().setListStatus(
          tmdbId: t.tmdbId,
          mediaType: t.tmdbMediaType ?? 'tv',
          to: to,
        );
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

  static Future<void> markWatchingOnPlay(HubListFollowTarget raw) async {
    await MyListService().ensureLoaded();
    final uid = raw.uniqueId;
    if (MyListService().contains(uid)) {
      final status = MyListService().statusOf(uid);
      if (status != 'plantowatch') return;
    }
    await setStatus(raw, 'watching');
  }

  static Future<void> syncEpisodeWatched(
    HubListFollowTarget raw, {
    required int episode,
    bool watched = true,
  }) async {
    if (!await SimklService().isLoggedIn()) return;
    var t = raw;
    if (t.mediaType == 'asian_drama' && t.tmdbId == null) {
      final stored = MyListService().itemOf(t.uniqueId);
      final storedTmdb = stored?['tmdbId'] as int?;
      final storedType = stored?['tmdbMediaType']?.toString();
      if (storedTmdb != null) {
        t = t.copyWith(tmdbId: storedTmdb, tmdbMediaType: storedType);
      } else {
        t = await _withDramaTmdb(t);
      }
    }

    if (t.mediaType == 'anime' && t.anilistId != null) {
      final item = {
        'ids': {'anilist': t.anilistId},
        'episodes': [
          {'number': episode},
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
    syncEpisodeWatchedToTrackers(t.tmdbId!, 1, episode, watched);
  }

  static Future<void> clearProgress(HubListFollowTarget raw) async {
    if (!await SimklService().isLoggedIn()) return;
    if (raw.mediaType == 'anime' && raw.anilistId != null) {
      await SimklService().clearWatched(
        anilistId: raw.anilistId,
        mediaType: 'anime',
      );
      return;
    }
    final stored = MyListService().itemOf(raw.uniqueId);
    final tmdbId = raw.tmdbId ?? stored?['tmdbId'] as int?;
    final mt = raw.tmdbMediaType ?? stored?['tmdbMediaType']?.toString() ?? 'tv';
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
