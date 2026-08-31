import 'package:forja/shared/services/tracker/simkl_service.dart';

void syncEpisodeWatchedToTrackers(
  int tmdbId,
  int season,
  int episode,
  bool watched,
) {
  SimklService().isLoggedIn().then((loggedIn) {
    if (!loggedIn) return;
    final show = {
      'ids': {'tmdb': tmdbId},
      'seasons': [
        {
          'number': season,
          'episodes': [
            {'number': episode},
          ],
        },
      ],
    };
    if (watched) {
      SimklService().addToHistory(shows: [show]);
    } else {
      SimklService().removeFromHistory(shows: [show]);
    }
  });
}

void syncMyListAddToTrackers(int? tmdbId, String? imdbId, String mediaType) {
  if (tmdbId == null && imdbId == null) return;
  SimklService().isLoggedIn().then((loggedIn) {
    if (!loggedIn) return;
    SimklService().addToWatchlist(
      tmdbId: tmdbId,
      imdbId: imdbId,
      mediaType: mediaType,
    );
  });
}

void syncMyListRemoveFromTrackers(
  int? tmdbId,
  String? imdbId,
  String mediaType,
) {
  if (tmdbId == null && imdbId == null) return;
  SimklService().isLoggedIn().then((loggedIn) {
    if (!loggedIn) return;
    SimklService().removeFromWatchlist(
      tmdbId: tmdbId,
      imdbId: imdbId,
      mediaType: mediaType,
    );
  });
}

/// Details trash / clear progress — drop tracker history so Completed does not stick.
void syncProgressClearedToTrackers({
  required int tmdbId,
  String? imdbId,
  required String mediaType,
  int? season,
  int? episode,
}) {
  SimklService().isLoggedIn().then((loggedIn) {
    if (!loggedIn) return;
    SimklService().clearWatched(
      tmdbId: tmdbId,
      imdbId: imdbId,
      mediaType: mediaType,
      season: season,
      episode: episode,
    );
  });
}
