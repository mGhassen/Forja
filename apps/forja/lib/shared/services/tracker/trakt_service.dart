import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rust/rust.dart';

/// Full Trakt.tv integration — OAuth device-code auth, watchlist sync,
/// scrobble, playback progress, and two-way import/export.
class TraktService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final TraktService _instance = TraktService._internal();
  factory TraktService() => _instance;
  TraktService._internal();

  // ── Constants ──────────────────────────────────────────────────────────

  // Injected at build time via --dart-define or .env
  static const String _clientId =
      String.fromEnvironment('TRAKT_CLIENT_ID');
  static const String _clientSecret =
      String.fromEnvironment('TRAKT_CLIENT_SECRET');

  // ── Secure Storage Keys ────────────────────────────────────────────────
  static const String _keyAccessToken = 'trakt_access_token';
  static const String _keyRefreshToken = 'trakt_refresh_token';
  static const String _keyExpiresAt = 'trakt_expires_at';

  final _storage = const FlutterSecureStorage();

  /// Fires when login state changes so the UI can rebuild.
  static final ValueNotifier<bool> loginNotifier = ValueNotifier<bool>(false);

  // Track whether we've already done an initial sync this session
  bool _initialSyncDone = false;
  Future<void>? _syncInProgress;

  // ═══════════════════════════════════════════════════════════════════════
  //  A U T H   —   D E V I C E   C O D E   F L O W
  // ═══════════════════════════════════════════════════════════════════════

  /// Step 1 — request a device code + user_code.
  /// Returns the API response map or null on failure.
  Future<Map<String, dynamic>?> startDeviceAuth() async {
    try {
      final response = await _postPublic('/oauth/device/code', body: json.encode({'client_id': _clientId}));
      if (response.status == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[Trakt] Device code request failed: ${response.status}');
    } catch (e) {
      debugPrint('[Trakt] Device code error: $e');
    }
    return null;
  }

  /// Step 2 — poll for the token after user enters the code.
  /// Returns:
  ///   'success'  — tokens saved, good to go
  ///   'pending'  — user hasn't authorized yet
  ///   'expired'  — code expired
  ///   'denied'   — user denied
  ///   'error'    — unexpected failure
  Future<String> pollForToken(String deviceCode) async {
    try {
      final response = await _postPublic('/oauth/device/token', body: json.encode({
          'code': deviceCode,
          'client_id': _clientId,
          'client_secret': _clientSecret,
        }));
      switch (response.status) {
        case 200:
          final data = json.decode(response.body) as Map<String, dynamic>;
          await _saveTokens(data);
          loginNotifier.value = true;
          return 'success';
        case 400:
          return 'pending';
        case 404:
        case 409:
        case 410:
          return 'expired';
        case 418:
          return 'denied';
        case 429:
          return 'pending'; // slow down — caller already uses interval
        default:
          debugPrint('[Trakt] Poll unexpected status: ${response.status}');
          return 'error';
      }
    } catch (e) {
      debugPrint('[Trakt] Poll error: $e');
      return 'error';
    }
  }

  /// Refresh the access token using the saved refresh token.
  Future<bool> _refreshToken() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) return false;

    try {
      final response = await _postPublic('/oauth/token', body: json.encode({
          'refresh_token': refreshToken,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
          'grant_type': 'refresh_token',
        }));
      if (response.status == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await _saveTokens(data);
        debugPrint('[Trakt] Token refreshed successfully');
        return true;
      }
      debugPrint('[Trakt] Token refresh failed: ${response.status}');
    } catch (e) {
      debugPrint('[Trakt] Token refresh error: $e');
    }
    return false;
  }

  /// Revoke the current token and clear storage.
  Future<void> logout() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token != null) {
      try {
        await _postPublic('/oauth/revoke', body: json.encode({
            'token': token,
            'client_id': _clientId,
            'client_secret': _clientSecret,
          }));
      } catch (_) {} // best-effort
    }
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiresAt);
    _initialSyncDone = false;
    _syncInProgress = null;
    loginNotifier.value = false;
    debugPrint('[Trakt] Logged out');
  }

  /// Whether the user is currently logged in.
  Future<bool> isLoggedIn() async {
    final token = await _getValidToken();
    return token != null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  W A T C H L I S T   ↔   M Y   L I S T
  // ═══════════════════════════════════════════════════════════════════════

  /// Pull the user's Trakt watchlist and merge into local My List.
  Future<int> importWatchlistToMyList() async {
    final token = await _getValidToken();
    if (token == null) return 0;

    int imported = 0;

    try {
      // Fetch movies watchlist
      final moviesResp = await _get(token, '/sync/watchlist/movies?extended=full');
      if (moviesResp.status == 200) {
        final List movies = json.decode(moviesResp.body);
        for (final entry in movies) {
          final movie = entry['movie'] as Map<String, dynamic>?;
          if (movie == null) continue;
          final ids = movie['ids'] as Map<String, dynamic>? ?? {};
          final tmdbId = ids['tmdb'] as int?;
          if (tmdbId == null) continue;

          final uid = MyListService.movieId(tmdbId, 'movie');
          if (!MyListService().contains(uid)) {
            final poster = await _fetchTmdbPoster(tmdbId, 'movie');
            await MyListService().addMovie(
              tmdbId: tmdbId,
              imdbId: ids['imdb']?.toString(),
              title: movie['title']?.toString() ?? 'Unknown',
              posterPath: poster,
              mediaType: 'movie',
              voteAverage: (movie['rating'] as num?)?.toDouble() ?? 0,
              releaseDate: movie['released']?.toString() ?? '',
            );
            imported++;
          }
        }
      }

      // Fetch shows watchlist
      final showsResp = await _get(token, '/sync/watchlist/shows?extended=full');
      if (showsResp.status == 200) {
        final List shows = json.decode(showsResp.body);
        for (final entry in shows) {
          final show = entry['show'] as Map<String, dynamic>?;
          if (show == null) continue;
          final ids = show['ids'] as Map<String, dynamic>? ?? {};
          final tmdbId = ids['tmdb'] as int?;
          if (tmdbId == null) continue;

          final uid = MyListService.movieId(tmdbId, 'tv');
          if (!MyListService().contains(uid)) {
            final poster = await _fetchTmdbPoster(tmdbId, 'tv');
            await MyListService().addMovie(
              tmdbId: tmdbId,
              imdbId: ids['imdb']?.toString(),
              title: show['title']?.toString() ?? 'Unknown',
              posterPath: poster,
              mediaType: 'tv',
              voteAverage: (show['rating'] as num?)?.toDouble() ?? 0,
              releaseDate: show['first_aired']?.toString().split('T').first ?? '',
            );
            imported++;
          }
        }
      }

      debugPrint('[Trakt] Imported $imported items from watchlist');
    } catch (e) {
      debugPrint('[Trakt] Watchlist import error: $e');
    }
    return imported;
  }

  /// Push a local My List item to the Trakt watchlist.
  Future<bool> addToWatchlist({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;
    final token = await _getValidToken();
    if (token == null) return false;

    final type = mediaType == 'tv' || mediaType == 'series' ? 'shows' : 'movies';
    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;
    try {
      final resp = await _post(token, '/sync/watchlist', body: json.encode({
          type: [
            {'ids': ids}
          ]
        }));
      debugPrint('[Trakt] Add to watchlist ($type ids:$ids): ${resp.status}');
      return resp.status == 201 || resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Add to watchlist error: $e');
      return false;
    }
  }

  /// Remove an item from the Trakt watchlist.
  Future<bool> removeFromWatchlist({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;
    final token = await _getValidToken();
    if (token == null) return false;

    final type = mediaType == 'tv' || mediaType == 'series' ? 'shows' : 'movies';
    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;
    try {
      final resp = await _post(token, '/sync/watchlist/remove', body: json.encode({
          type: [
            {'ids': ids}
          ]
        }));
      debugPrint('[Trakt] Remove from watchlist ($type ids:$ids): ${resp.status}');
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Remove from watchlist error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  S C R O B B L E   —   R E A L - T I M E   T R A C K I N G
  // ═══════════════════════════════════════════════════════════════════════

  /// POST /scrobble/start — call when playback begins.
  Future<bool> scrobbleStart({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    required double progressPercent,
  }) async {
    return _scrobble('start',
        tmdbId: tmdbId, mediaType: mediaType,
        season: season, episode: episode,
        progressPercent: progressPercent);
  }

  /// POST /scrobble/pause — call when playback pauses.
  Future<bool> scrobblePause({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    required double progressPercent,
  }) async {
    return _scrobble('pause',
        tmdbId: tmdbId, mediaType: mediaType,
        season: season, episode: episode,
        progressPercent: progressPercent);
  }

  /// POST /scrobble/stop — call when playback stops.
  /// If progress >= 80 %, Trakt marks it as watched automatically.
  Future<bool> scrobbleStop({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    required double progressPercent,
  }) async {
    return _scrobble('stop',
        tmdbId: tmdbId, mediaType: mediaType,
        season: season, episode: episode,
        progressPercent: progressPercent);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  H I S T O R Y   —   M A R K   A S   W A T C H E D
  // ═══════════════════════════════════════════════════════════════════════

  /// Explicitly add an item to history (watched).
  Future<bool> addToHistory({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    DateTime? watchedAt,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final body = <String, dynamic>{};
    final at = (watchedAt ?? DateTime.now()).toUtc().toIso8601String();

    if (mediaType == 'tv' && season != null && episode != null) {
      body['episodes'] = [
        {
          'watched_at': at,
          'ids': {'tmdb': tmdbId},
          // Trakt can find the episode from show tmdbId + S/E numbers
        }
      ];
      // Alternative: send show + seasons array for absolute correctness
      body['shows'] = [
        {
          'ids': {'tmdb': tmdbId},
          'seasons': [
            {
              'number': season,
              'episodes': [
                {'number': episode, 'watched_at': at}
              ]
            }
          ]
        }
      ];
      // Remove the flat episodes since we're using the nested shows format
      body.remove('episodes');
    } else {
      body['movies'] = [
        {
          'watched_at': at,
          'ids': {'tmdb': tmdbId},
        }
      ];
    }

    try {
      final resp = await _post(token, '/sync/history', body: json.encode(body));
      debugPrint('[Trakt] Add to history: ${resp.status}');
      return resp.status == 201 || resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Add to history error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  P L A Y B A C K   P R O G R E S S   ( R E S U M E )
  // ═══════════════════════════════════════════════════════════════════════

  /// Remove a playback progress item from Trakt.
  /// Looks up the Trakt playback ID by matching tmdbId (+ season/episode),
  /// then calls DELETE /sync/playback/{id}.
  Future<bool> removePlaybackProgress({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    try {
      // First, fetch current playback items to find the Trakt playback ID
      final playbackItems = await _getPlaybackProgress();
      int? playbackId;

      for (final item in playbackItems) {
        final type = item['type']?.toString();
        if (type == 'movie' && (mediaType == 'movie' || mediaType == 'movies')) {
          final movie = item['movie'] as Map<String, dynamic>? ?? {};
          final ids = movie['ids'] as Map<String, dynamic>? ?? {};
          if (ids['tmdb'] == tmdbId) {
            playbackId = item['id'] as int?;
            break;
          }
        } else if (type == 'episode' && (mediaType == 'tv' || mediaType == 'series')) {
          final show = item['show'] as Map<String, dynamic>? ?? {};
          final showIds = show['ids'] as Map<String, dynamic>? ?? {};
          final ep = item['episode'] as Map<String, dynamic>? ?? {};
          if (showIds['tmdb'] == tmdbId &&
              ep['season'] == season &&
              ep['number'] == episode) {
            playbackId = item['id'] as int?;
            break;
          }
        }
      }

      if (playbackId == null) {
        debugPrint('[Trakt] No matching playback item found for tmdb:$tmdbId S:$season E:$episode');
        return false;
      }

      final resp = await _delete(token, '/sync/playback/$playbackId');
      debugPrint('[Trakt] Remove playback (id:$playbackId tmdb:$tmdbId): ${resp.status}');
      return resp.status == 204 || resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Remove playback error: $e');
      return false;
    }
  }

  /// GET /sync/playback — items the user is still in the middle of.
  /// Returns raw Trakt response list.
  Future<List<Map<String, dynamic>>> _getPlaybackProgress() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final results = <Map<String, dynamic>>[];

    try {
      // Movies in progress
      final moviesResp = await _get(token, '/sync/playback/movies');
      if (moviesResp.status == 200) {
        final List items = json.decode(moviesResp.body);
        for (final item in items) {
          results.add(Map<String, dynamic>.from(item as Map));
        }
      }

      // Episodes in progress
      final episodesResp = await _get(token, '/sync/playback/episodes');
      if (episodesResp.status == 200) {
        final List items = json.decode(episodesResp.body);
        for (final item in items) {
          results.add(Map<String, dynamic>.from(item as Map));
        }
      }

      debugPrint('[Trakt] Got ${results.length} playback progress items');
    } catch (e) {
      debugPrint('[Trakt] Get playback error: $e');
    }
    return results;
  }

  /// Import Trakt playback progress → local Continue Watching.
  /// Only imports items not already in local history.
  Future<int> importPlaybackToWatchHistory() async {
    final traktItems = await _getPlaybackProgress();
    if (traktItems.isEmpty) return 0;

    int imported = 0;

    for (final item in traktItems) {
      try {
        final progress = (item['progress'] as num?)?.toDouble() ?? 0;
        final type = item['type']?.toString(); // 'movie' or 'episode'

        int? tmdbId;
        String? imdbId;
        String title = 'Unknown';
        String posterPath = '';
        String mediaType = 'movie';
        int? season;
        int? episode;
        String? episodeTitle;

        if (type == 'movie') {
          final movie = item['movie'] as Map<String, dynamic>? ?? {};
          final ids = movie['ids'] as Map<String, dynamic>? ?? {};
          tmdbId = ids['tmdb'] as int?;
          imdbId = ids['imdb']?.toString();
          title = movie['title']?.toString() ?? 'Unknown';
          mediaType = 'movie';
        } else if (type == 'episode') {
          final ep = item['episode'] as Map<String, dynamic>? ?? {};
          final show = item['show'] as Map<String, dynamic>? ?? {};
          final showIds = show['ids'] as Map<String, dynamic>? ?? {};
          tmdbId = showIds['tmdb'] as int?;
          imdbId = showIds['imdb']?.toString();
          title = show['title']?.toString() ?? 'Unknown';
          season = ep['season'] as int?;
          episode = ep['number'] as int?;
          episodeTitle = ep['title']?.toString();
          mediaType = 'tv';
        }

        if (tmdbId == null) continue;

        // Check if dismissed locally
        final uniqueId = season != null && episode != null 
            ? '${tmdbId}_S${season}_E$episode' 
            : '$tmdbId';
            
        if (await WatchHistoryService().isDismissed(uniqueId)) {
          debugPrint('[Trakt] Skipping dismissed item: $title ($uniqueId)');
          continue;
        }

        // Fetch poster + runtime from TMDB
        final tmdbInfo = await _fetchTmdbInfo(tmdbId, mediaType);
        posterPath = tmdbInfo['poster'] as String;
        final durationMs = tmdbInfo['runtimeMs'] as int;

        // Check if already in local history
        final existing = await WatchHistoryService().getProgress(
          tmdbId,
          season: season,
          episode: episode,
        );
        if (existing != null) continue;

        // Derive position from Trakt progress % + real TMDB runtime.
        final estimatedPositionMs = (progress / 100 * durationMs).round();

        await WatchHistoryService().saveProgress(
          tmdbId: tmdbId,
          imdbId: imdbId,
          title: title,
          posterPath: posterPath,
          method: 'trakt_import',
          sourceId: 'trakt',
          position: estimatedPositionMs,
          duration: durationMs,
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
          mediaType: mediaType,
        );
        imported++;
      } catch (e) {
        debugPrint('[Trakt] Import playback item error: $e');
      }
    }

    debugPrint('[Trakt] Imported $imported playback items to watch history');
    return imported;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  R A T I N G S
  // ═══════════════════════════════════════════════════════════════════════

  /// Rate an item on Trakt (1-10 scale).
  Future<bool> rateItem({
    required int tmdbId,
    required String mediaType,
    required int rating,
  }) async {
    if (rating < 1 || rating > 10) return false;
    final token = await _getValidToken();
    if (token == null) return false;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    try {
      final resp = await _post(token, '/sync/ratings', body: json.encode({
          type: [
            {
              'ids': {'tmdb': tmdbId},
              'rating': rating,
              'rated_at': DateTime.now().toUtc().toIso8601String(),
            }
          ]
        }));
      debugPrint('[Trakt] Rate item (tmdb:$tmdbId $rating/10): ${resp.status}');
      return resp.status == 201 || resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Rate item error: $e');
      return false;
    }
  }

  /// Remove rating from an item.
  Future<bool> removeRating({
    required int tmdbId,
    required String mediaType,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    try {
      final resp = await _post(token, '/sync/ratings/remove', body: json.encode({
          type: [
            {'ids': {'tmdb': tmdbId}}
          ]
        }));
      debugPrint('[Trakt] Remove rating (tmdb:$tmdbId): ${resp.status}');
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Remove rating error: $e');
      return false;
    }
  }

  /// Get all user ratings from Trakt.
  Future<Map<String, dynamic>> getAllRatings() async {
    final token = await _getValidToken();
    if (token == null) return {};

    final result = <String, dynamic>{'movies': [], 'shows': []};
    try {
      for (final type in ['movies', 'shows']) {
        final resp = await _get(token, '/sync/ratings/$type');
        if (resp.status == 200) {
          result[type] = json.decode(resp.body);
        }
      }
      debugPrint('[Trakt] Got ratings: ${(result['movies'] as List).length} movies, ${(result['shows'] as List).length} shows');
    } catch (e) {
      debugPrint('[Trakt] Get ratings error: $e');
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  C O L L E C T I O N   —   O W N E D   M E D I A
  // ═══════════════════════════════════════════════════════════════════════

  /// Add an item to the user's collection.
  Future<bool> addToCollection({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;
    final token = await _getValidToken();
    if (token == null) return false;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;
    try {
      final resp = await _post(token, '/sync/collection', body: json.encode({
          type: [
            {
              'ids': ids,
              'collected_at': DateTime.now().toUtc().toIso8601String(),
            }
          ]
        }));
      debugPrint('[Trakt] Add to collection ($type ids:$ids): ${resp.status}');
      return resp.status == 201 || resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Add to collection error: $e');
      return false;
    }
  }

  /// Remove an item from the user's collection.
  Future<bool> removeFromCollection({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;
    final token = await _getValidToken();
    if (token == null) return false;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;
    try {
      final resp = await _post(token, '/sync/collection/remove', body: json.encode({
          type: [
            {'ids': ids}
          ]
        }));
      debugPrint('[Trakt] Remove from collection: ${resp.status}');
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Remove from collection error: $e');
      return false;
    }
  }

  /// Get the user's full collection.
  Future<Map<String, dynamic>> getCollection() async {
    final token = await _getValidToken();
    if (token == null) return {};

    final result = <String, dynamic>{'movies': [], 'shows': []};
    try {
      for (final type in ['movies', 'shows']) {
        final resp = await _get(token, '/sync/collection/$type?extended=metadata');
        if (resp.status == 200) {
          result[type] = json.decode(resp.body);
        }
      }
    } catch (e) {
      debugPrint('[Trakt] Get collection error: $e');
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  H I S T O R Y   M A N A G E M E N T
  // ═══════════════════════════════════════════════════════════════════════

  /// Remove an item from history.
  Future<bool> removeFromHistory({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (mediaType == 'tv' && season != null && episode != null) {
      body['shows'] = [
        {
          'ids': {'tmdb': tmdbId},
          'seasons': [
            {
              'number': season,
              'episodes': [
                {'number': episode}
              ]
            }
          ]
        }
      ];
    } else {
      final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
      body[type] = [
        {'ids': {'tmdb': tmdbId}}
      ];
    }

    try {
      final resp = await _post(token, '/sync/history/remove', body: json.encode(body));
      debugPrint('[Trakt] Remove from history: ${resp.status}');
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Remove from history error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  U S E R   L I S T S
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all custom lists created by the user.
  Future<List<Map<String, dynamic>>> getUserLists() async {
    final token = await _getValidToken();
    if (token == null) return [];

    try {
      final resp = await _get(token, '/users/me/lists');
      if (resp.status == 200) {
        final List items = json.decode(resp.body);
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[Trakt] Get lists error: $e');
    }
    return [];
  }

  /// Get items in a specific list.
  Future<List<Map<String, dynamic>>> getListItems(String listId) async {
    final token = await _getValidToken();
    if (token == null) return [];

    try {
      final resp = await _get(token, '/users/me/lists/$listId/items');
      if (resp.status == 200) {
        final List items = json.decode(resp.body);
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[Trakt] Get list items error: $e');
    }
    return [];
  }

  /// Create a new custom list.
  Future<Map<String, dynamic>?> createList({
    required String name,
    String? description,
    String privacy = 'private',
    bool allowComments = true,
    String sortBy = 'rank',
    String sortHow = 'asc',
  }) async {
    final token = await _getValidToken();
    if (token == null) return null;

    try {
      final resp = await _post(token, '/users/me/lists', body: json.encode({
          'name': name,
          'description': ?description,
          'privacy': privacy,
          'allow_comments': allowComments,
          'sort_by': sortBy,
          'sort_how': sortHow,
        }));
      if (resp.status == 201) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Trakt] Create list error: $e');
    }
    return null;
  }

  /// Add items to a custom list.
  Future<bool> addToList({
    required String listId,
    List<Map<String, dynamic>> movies = const [],
    List<Map<String, dynamic>> shows = const [],
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    try {
      final resp = await _post(token, '/users/me/lists/$listId/items', body: json.encode({
          if (movies.isNotEmpty) 'movies': movies,
          if (shows.isNotEmpty) 'shows': shows,
        }));
      return resp.status == 201;
    } catch (e) {
      debugPrint('[Trakt] Add to list error: $e');
      return false;
    }
  }

  /// Remove items from a custom list.
  Future<bool> removeFromList({
    required String listId,
    List<Map<String, dynamic>> movies = const [],
    List<Map<String, dynamic>> shows = const [],
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    try {
      final resp = await _post(token, '/users/me/lists/$listId/items/remove', body: json.encode({
          if (movies.isNotEmpty) 'movies': movies,
          if (shows.isNotEmpty) 'shows': shows,
        }));
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Trakt] Remove from list error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  R E C O M M E N D A T I O N S
  // ═══════════════════════════════════════════════════════════════════════

  /// Get personalized recommendations.
  Future<List<Map<String, dynamic>>> getRecommendations(String type) async {
    final token = await _getValidToken();
    if (token == null) return [];

    try {
      final resp = await _get(token, '/recommendations/$type?extended=full&limit=30');
      if (resp.status == 200) {
        final List items = json.decode(resp.body);
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[Trakt] Get recommendations error: $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  C A L E N D A R
  // ═══════════════════════════════════════════════════════════════════════

  /// Get the user's calendar shows (upcoming episodes for shows they watch).
  Future<List<Map<String, dynamic>>> getCalendarShows({int days = 14}) async {
    final token = await _getValidToken();
    if (token == null) return [];

    final startDate = DateTime.now().toIso8601String().split('T').first;
    try {
      final resp = await _get(token, '/calendars/my/shows/$startDate/$days');
      if (resp.status == 200) {
        final List items = json.decode(resp.body);
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[Trakt] Get calendar shows error: $e');
    }
    return [];
  }

  /// Get the user's calendar movies (upcoming movies).
  Future<List<Map<String, dynamic>>> getCalendarMovies({int days = 30}) async {
    final token = await _getValidToken();
    if (token == null) return [];

    final startDate = DateTime.now().toIso8601String().split('T').first;
    try {
      final resp = await _get(token, '/calendars/my/movies/$startDate/$days');
      if (resp.status == 200) {
        final List items = json.decode(resp.body);
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[Trakt] Get calendar movies error: $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  C H E C K I N
  // ═══════════════════════════════════════════════════════════════════════

  /// Check in to a movie or episode (for manual "watching now" tracking).
  Future<bool> checkin({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    String? message,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (message != null) body['message'] = message;

    if (mediaType == 'tv' && season != null && episode != null) {
      body['show'] = {
        'ids': {'tmdb': tmdbId}
      };
      body['episode'] = {
        'season': season,
        'number': episode,
      };
    } else {
      body['movie'] = {
        'ids': {'tmdb': tmdbId}
      };
    }

    try {
      final resp = await _post(token, '/checkin', body: json.encode(body));
      debugPrint('[Trakt] Checkin (tmdb:$tmdbId): ${resp.status}');
      return resp.status == 201;
    } catch (e) {
      debugPrint('[Trakt] Checkin error: $e');
      return false;
    }
  }

  /// Cancel any active check-in.
  Future<bool> cancelCheckin() async {
    final token = await _getValidToken();
    if (token == null) return false;

    try {
      final resp = await _delete(token, '/checkin');
      return resp.status == 204;
    } catch (e) {
      debugPrint('[Trakt] Cancel checkin error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  W A T C H   S T A T S
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user watch statistics.
  Future<Map<String, dynamic>?> getUserStats() async {
    final token = await _getValidToken();
    if (token == null) return null;

    try {
      final resp = await _get(token, '/users/me/stats');
      if (resp.status == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Trakt] Get stats error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  L A S T   A C T I V I T I E S   ( for smart sync )
  // ═══════════════════════════════════════════════════════════════════════

  /// Get last activity timestamps to determine what needs syncing.
  Future<Map<String, dynamic>?> _getLastActivities() async {
    final token = await _getValidToken();
    if (token == null) return null;

    try {
      final resp = await _get(token, '/sync/last_activities');
      _handleUnauthorized(resp.status);
      if (resp.status == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Trakt] Get last activities error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  F U L L   S Y N C   ( called after login / app start )
  // ═══════════════════════════════════════════════════════════════════════

  /// Run a full import from Trakt to local data.
  /// Uses getLastActivities to skip unchanged data (smart sync).
  /// Safe to call multiple times — only runs once per session unless forced.
  Future<void> fullSync({bool force = false}) async {
    if (!force && _initialSyncDone) return;
    // Prevent concurrent sync — piggyback on existing run
    if (_syncInProgress != null) {
      await _syncInProgress;
      return;
    }
    final completer = Completer<void>();
    _syncInProgress = completer.future;

    try {
      final loggedIn = await isLoggedIn();
      if (!loggedIn) return;

      debugPrint('[Trakt] Starting smart sync...');
      final activities = await _getLastActivities();
      final lastWatchlist = activities?['watchlist']?['updated_at']?.toString() ?? '';
      final lastEpisodeScrobble = activities?['episodes']?['paused_at']?.toString() ?? '';
      final lastMovieScrobble = activities?['movies']?['paused_at']?.toString() ?? '';
      final lastScrobble = '${lastEpisodeScrobble}_$lastMovieScrobble';
      final lastWatched = activities?['episodes']?['watched_at']?.toString() ?? '';

      final savedWatchlist = await _storage.read(key: 'trakt_last_watchlist');
      final savedScrobble = await _storage.read(key: 'trakt_last_scrobble');
      final savedWatched = await _storage.read(key: 'trakt_last_watched');

      int watchlistCount = 0, playbackCount = 0, episodesImported = 0;

      if (force || savedWatchlist != lastWatchlist) {
        watchlistCount = await importWatchlistToMyList();
        if (lastWatchlist.isNotEmpty) await _storage.write(key: 'trakt_last_watchlist', value: lastWatchlist);
      } else {
        debugPrint('[Trakt] Watchlist unchanged, skipping');
      }

      if (force || savedScrobble != lastScrobble) {
        playbackCount = await importPlaybackToWatchHistory();
        if (lastScrobble.isNotEmpty) await _storage.write(key: 'trakt_last_scrobble', value: lastScrobble);
      } else {
        debugPrint('[Trakt] Playback unchanged, skipping');
      }

      if (force || savedWatched != lastWatched) {
        episodesImported = await importWatchedEpisodes();
        if (lastWatched.isNotEmpty) await _storage.write(key: 'trakt_last_watched', value: lastWatched);
      } else {
        debugPrint('[Trakt] Watched episodes unchanged, skipping');
      }

      _initialSyncDone = true;
      debugPrint('[Trakt] Smart sync done — watchlist: $watchlistCount, playback: $playbackCount, episodes: $episodesImported');
    } finally {
      _syncInProgress = null;
      completer.complete();
    }
  }

  /// Import watched shows/episodes from Trakt into EpisodeWatchedService.
  Future<int> importWatchedEpisodes() async {
    final token = await _getValidToken();
    if (token == null) return 0;

    int imported = 0;
    try {
      final resp = await _get(token, '/sync/watched/shows?extended=noseasons');
      if (resp.status != 200) return 0;

      // Also fetch full watched data with seasons for timestamp extraction
      final fullResp = await _get(token, '/sync/watched/shows');
      if (fullResp.status != 200) return 0;

      final List shows = json.decode(fullResp.body);
      for (final show in shows) {
        final showData = show['show'] as Map<String, dynamic>? ?? {};
        final ids = showData['ids'] as Map<String, dynamic>? ?? {};
        final tmdbId = ids['tmdb'] as int?;
        if (tmdbId == null) continue;

        final seasons = show['seasons'] as List? ?? [];
        for (final s in seasons) {
          final sNum = s['number'] as int? ?? 0;
          if (sNum == 0) continue; // skip specials
          final episodes = s['episodes'] as List? ?? [];
          for (final ep in episodes) {
            final eNum = ep['number'] as int? ?? 0;
            if (eNum == 0) continue;
            final watchedAt = ep['last_watched_at']?.toString();
            final already = await EpisodeWatchedService().isWatched(tmdbId, sNum, eNum);
            if (!already) {
              await EpisodeWatchedService().setWatchedLocalWithTimestamp(
                tmdbId, sNum, eNum, true, watchedAt,
              );
              imported++;
            }
          }
        }
      }
      debugPrint('[Trakt] Imported $imported watched episodes');
    } catch (e) {
      debugPrint('[Trakt] Import watched episodes error: $e');
    }
    return imported;
  }

  /// Export locally-watched episodes to Trakt history.
  /// 
  /// Safe & idempotent: fetches Trakt's current watched state first,
  /// only pushes episodes that Trakt doesn't already have, and always
  /// includes an explicit `watched_at` timestamp.
  ///
  /// Set [dryRun] to true to log what would be sent without making any
  /// write calls.
  Future<int> exportWatchedEpisodes({bool dryRun = false}) async {
    final token = await _getValidToken();
    if (token == null) return 0;

    // ── Step 1: Fetch what Trakt already has ──────────────────────────────
    final Set<String> traktHas = {}; // "tmdbId_S_E"
    try {
      final resp = await _get(token, '/sync/watched/shows');
      if (resp.status == 200) {
        final List shows = json.decode(resp.body);
        for (final show in shows) {
          final ids = (show['show'] as Map?)?['ids'] as Map? ?? {};
          final tmdbId = ids['tmdb'] as int?;
          if (tmdbId == null) continue;
          for (final s in (show['seasons'] as List? ?? [])) {
            final sNum = s['number'] as int? ?? 0;
            for (final ep in (s['episodes'] as List? ?? [])) {
              final eNum = ep['number'] as int? ?? 0;
              traktHas.add('${tmdbId}_S${sNum}_E$eNum');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Trakt] Failed to fetch existing watched state: $e');
      // Abort — we can't safely deduplicate
      return 0;
    }
    debugPrint('[Trakt] Trakt already has ${traktHas.length} watched episodes');

    // ── Step 2: Load local cache and filter ───────────────────────────────
    final cache = await _getEpisodeWatchedCache();
    if (cache.isEmpty) return 0;

    // Read timestamps from the enhanced cache
    final timestampCache = await EpisodeWatchedService().getAllTimestamps();

    final Map<int, List<Map<String, dynamic>>> grouped = {};
    int skipped = 0;
    for (final key in cache.keys) {
      if (cache[key] != true) continue;
      final match = RegExp(r'^(\d+)_S(\d+)_E(\d+)$').firstMatch(key);
      if (match == null) continue;
      final tmdbId = int.parse(match.group(1)!);
      final season = int.parse(match.group(2)!);
      final episode = int.parse(match.group(3)!);

      // Skip if Trakt already has this episode
      if (traktHas.contains(key)) {
        skipped++;
        continue;
      }

      final watchedAt = timestampCache[key] ??
          DateTime.now().toUtc().toIso8601String();

      grouped.putIfAbsent(tmdbId, () => []);
      grouped[tmdbId]!.add({
        'season': season,
        'episode': episode,
        'watched_at': watchedAt,
      });
    }

    final totalToSync = grouped.values.fold<int>(0, (s, v) => s + v.length);
    debugPrint('[Trakt] Export: $totalToSync new, $skipped already on Trakt');

    if (totalToSync == 0) return 0;

    // ── Step 3: Dry-run gate ──────────────────────────────────────────────
    if (dryRun) {
      for (final entry in grouped.entries) {
        for (final ep in entry.value) {
          debugPrint('[Trakt DRY-RUN] Would sync: tmdb=${entry.key} '
              'S${ep['season']}E${ep['episode']} watched_at=${ep['watched_at']}');
        }
      }
      debugPrint('[Trakt DRY-RUN] Total: $totalToSync episodes (not sent)');
      return totalToSync;
    }

    // ── Step 4: Push in batches ───────────────────────────────────────────
    int exported = 0;
    const batchSize = 100;
    for (final entry in grouped.entries) {
      final allEps = entry.value;

      // Chunk the episodes list into batches of batchSize
      for (var i = 0; i < allEps.length; i += batchSize) {
        final batch = allEps.sublist(
          i, (i + batchSize).clamp(0, allEps.length),
        );

        // Group batch by season
        final Map<int, List<Map<String, dynamic>>> seasonEps = {};
        for (final ep in batch) {
          final s = ep['season'] as int;
          seasonEps.putIfAbsent(s, () => []);
          seasonEps[s]!.add({
            'number': ep['episode'],
            'watched_at': ep['watched_at'],
          });
        }

        final seasons = seasonEps.entries.map((se) => {
          'number': se.key,
          'episodes': se.value,
        }).toList();

        try {
          final resp = await _post(token, '/sync/history', body: json.encode({
              'shows': [
                {
                  'ids': {'tmdb': entry.key},
                  'seasons': seasons,
                }
              ]
            }));
          if (resp.status == 200 || resp.status == 201) {
            exported += batch.length;
          } else if (resp.status == 429) {
            // Rate limited — wait and retry
            final retryAfter = resp.retryAfter ?? 2;
            debugPrint('[Trakt] Rate limited, waiting ${retryAfter}s');
            await Future.delayed(Duration(seconds: retryAfter));
            i -= batchSize; // retry this batch
          }
        } catch (e) {
          debugPrint('[Trakt] Export watched episodes error: $e');
        }

        // Small delay between batches to avoid rate limiting
        if (i + batchSize < allEps.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    debugPrint('[Trakt] Exported $exported watched episodes');
    return exported;
  }

  Future<Map<String, bool>> _getEpisodeWatchedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('episodes_watched');
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return {};
    }
  }

  /// Push the entire local My List to Trakt watchlist (bulk export).
  Future<int> exportMyListToWatchlist() async {
    final token = await _getValidToken();
    if (token == null) return 0;

    final items = MyListService().items;
    final movies = <Map<String, dynamic>>[];
    final shows = <Map<String, dynamic>>[];

    for (final item in items) {
      final tmdbId = item['tmdbId'] as int?;
      final imdbId = item['imdbId']?.toString();
      if (tmdbId == null && imdbId == null) continue;
      final mediaType = item['mediaType']?.toString() ?? 'movie';
      final ids = <String, dynamic>{};
      if (tmdbId != null) ids['tmdb'] = tmdbId;
      if (imdbId != null) ids['imdb'] = imdbId;
      final entry = {'ids': ids};
      if (mediaType == 'tv' || mediaType == 'series') {
        shows.add(entry);
      } else {
        movies.add(entry);
      }
    }

    if (movies.isEmpty && shows.isEmpty) return 0;

    try {
      final resp = await _post(token, '/sync/watchlist', body: json.encode({
          if (movies.isNotEmpty) 'movies': movies,
          if (shows.isNotEmpty) 'shows': shows,
        }));
      final total = movies.length + shows.length;
      debugPrint('[Trakt] Exported $total items to watchlist: ${resp.status}');
      return resp.status == 201 || resp.status == 200 ? total : 0;
    } catch (e) {
      debugPrint('[Trakt] Export watchlist error: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  U S E R   P R O F I L E
  // ═══════════════════════════════════════════════════════════════════════

  /// Get the logged-in user's profile (username, vip status, etc.)
  Future<Map<String, dynamic>?> getUserProfile() async {
    final token = await _getValidToken();
    if (token == null) return null;

    try {
      final resp = await _get(token, '/users/me');
      if (resp.status == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Trakt] Get profile error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  I N T E R N A L   H E L P E R S
  // ═══════════════════════════════════════════════════════════════════════

  Future<({int status, String body, int? retryAfter})> _traktRequest({
    required String method,
    required String path,
    String? accessToken,
    String? body,
    int timeoutSecs = 15,
  }) async {
    final payload = <String, dynamic>{
      'client_id': _clientId,
      'method': method,
      'path': path,
      'timeout_secs': timeoutSecs,
      if (accessToken != null) 'access_token': accessToken,
      if (body != null) 'body': body,
    };
    final raw = await runTraktRequestJson(json.encode(payload));
    final decoded = json.decode(raw) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw Exception(decoded['error']);
    }
    final status = decoded['status'] as int;
    if (accessToken != null) {
      _handleUnauthorized(status);
    }
    return (
      status: status,
      body: decoded['body'] as String? ?? '',
      retryAfter: decoded['retry_after'] as int?,
    );
  }

  Future<({int status, String body, int? retryAfter})> _get(String token, String path) =>
      _traktRequest(method: 'GET', path: path, accessToken: token);

  Future<({int status, String body, int? retryAfter})> _post(
    String token,
    String path, {
    required String body,
  }) =>
      _traktRequest(
        method: 'POST',
        path: path,
        accessToken: token,
        body: body,
      );

  Future<({int status, String body, int? retryAfter})> _delete(String token, String path) =>
      _traktRequest(method: 'DELETE', path: path, accessToken: token);

  Future<({int status, String body, int? retryAfter})> _postPublic(String path, {required String body}) =>
      _traktRequest(method: 'POST', path: path, body: body);

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(key: _keyAccessToken, value: data['access_token']);
    await _storage.write(key: _keyRefreshToken, value: data['refresh_token']);
    final expiresIn = data['expires_in'] as int? ?? 7776000; // ~90 days
    final expiresAt = DateTime.now()
        .add(Duration(seconds: expiresIn))
        .toIso8601String();
    await _storage.write(key: _keyExpiresAt, value: expiresAt);
    debugPrint('[Trakt] Tokens saved, expires in ${expiresIn ~/ 86400} days');
  }

  /// Get a valid access token, refreshing if near expiry.
  Future<String?> _getValidToken() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return null;

    final expiresAtStr = await _storage.read(key: _keyExpiresAt);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null &&
          DateTime.now().isAfter(expiresAt.subtract(const Duration(days: 7)))) {
        // Token expires within 7 days — refresh it
        debugPrint('[Trakt] Token nearing expiry, refreshing...');
        final refreshed = await _refreshToken();
        if (refreshed) {
          return await _storage.read(key: _keyAccessToken);
        }
        // If refresh failed but token isn't actually expired yet, use it
        if (DateTime.now().isBefore(expiresAt)) return token;
        return null;
      }
    }
    return token;
  }

  /// Handle 401 unauthorized — token revoked server-side.
  void _handleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      debugPrint('[Trakt] 401 Unauthorized — token revoked, clearing auth');
      _storage.delete(key: _keyAccessToken);
      _storage.delete(key: _keyRefreshToken);
      _storage.delete(key: _keyExpiresAt);
      _initialSyncDone = false;
      loginNotifier.value = false;
    }
  }

  Future<bool> _scrobble(
    String action, {
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    required double progressPercent,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final body = <String, dynamic>{
      'progress': progressPercent.clamp(0, 100),
    };

    if (mediaType == 'tv' && season != null && episode != null) {
      body['show'] = {
        'ids': {'tmdb': tmdbId}
      };
      body['episode'] = {
        'season': season,
        'number': episode,
      };
    } else {
      body['movie'] = {
        'ids': {'tmdb': tmdbId}
      };
    }

    try {
      final resp = await _post(token, '/scrobble/$action', body: json.encode(body));
      _handleUnauthorized(resp.status);
      debugPrint('[Trakt] Scrobble $action (tmdb:$tmdbId S:$season E:$episode ${progressPercent.toStringAsFixed(1)}%): ${resp.status}');
      // 429 = rate limited — wait and retry once
      if (resp.status == 429) {
        final retryAfter = resp.retryAfter ?? 1;
        debugPrint('[Trakt] Rate limited, retrying after ${retryAfter}s');
        await Future.delayed(Duration(seconds: retryAfter));
        final retry = await _post(token, '/scrobble/$action', body: json.encode(body));
        _handleUnauthorized(retry.status);
        return retry.status == 200 || retry.status == 201 || retry.status == 409;
      }
      // 200 = success, 409 = already scrobbled (OK), 422 = progress too low
      return resp.status == 200 || resp.status == 201 || resp.status == 409;
    } catch (e) {
      debugPrint('[Trakt] Scrobble error: $e');
      return false;
    }
  }

  // ── TMDB poster resolution ─────────────────────────────────────────────
  /// Fetch the TMDB poster_path for a given TMDB ID.
  /// Returns the relative path (e.g. "/abc123.jpg") or empty string.
  Future<String> _fetchTmdbPoster(int tmdbId, String mediaType) async {
    final info = await _fetchTmdbInfo(tmdbId, mediaType);
    return info['poster'] as String;
  }

  /// Fetch poster + runtime (in ms) from TMDB in a single call.
  Future<Map<String, dynamic>> _fetchTmdbInfo(int tmdbId, String mediaType) async {
    try {
      final type = (mediaType == 'tv' || mediaType == 'series') ? 'tv' : 'movie';
      final raw = await runTmdbGetJson('$type/$tmdbId');
      final data = json.decode(raw);
      if (data is Map<String, dynamic> && data['error'] == null) {
        final poster = data['poster_path']?.toString() ?? '';
        // runtime in minutes → milliseconds
        int runtimeMs = 6000000; // fallback 100 min
        if (type == 'movie' && data['runtime'] is int && (data['runtime'] as int) > 0) {
          runtimeMs = (data['runtime'] as int) * 60000;
        } else if (type == 'tv') {
          final epRuntimes = data['episode_run_time'] as List?;
          if (epRuntimes != null && epRuntimes.isNotEmpty) {
            runtimeMs = ((epRuntimes.first as int?) ?? 100) * 60000;
          }
        }
        return {'poster': poster, 'runtimeMs': runtimeMs};
      }
    } catch (e) {
      debugPrint('[Trakt] TMDB info fetch failed for $tmdbId: $e');
    }
    return {'poster': '', 'runtimeMs': 6000000};
  }
}
