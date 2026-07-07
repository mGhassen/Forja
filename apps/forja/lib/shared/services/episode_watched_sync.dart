import 'package:api/api/simkl_service.dart';
import 'package:api/api/trakt_service.dart';

void syncEpisodeWatchedToTrackers(
  int tmdbId,
  int season,
  int episode,
  bool watched,
) {
  TraktService().isLoggedIn().then((loggedIn) {
    if (!loggedIn) return;
    if (watched) {
      TraktService().addToHistory(
        tmdbId: tmdbId,
        mediaType: 'tv',
        season: season,
        episode: episode,
      );
    } else {
      TraktService().removeFromHistory(
        tmdbId: tmdbId,
        mediaType: 'tv',
        season: season,
        episode: episode,
      );
    }
  });

  SimklService().isLoggedIn().then((loggedIn) {
    if (!loggedIn) return;
    final show = {
      'ids': {'tmdb': tmdbId},
      'seasons': [
        {
          'number': season,
          'episodes': [
            {'number': episode}
          ]
        }
      ]
    };
    if (watched) {
      SimklService().addToHistory(shows: [show]);
    } else {
      SimklService().removeFromHistory(shows: [show]);
    }
  });
}
