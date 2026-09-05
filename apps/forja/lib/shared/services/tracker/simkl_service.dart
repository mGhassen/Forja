import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_list_item.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How list buckets sync when the user connects or taps Sync Now.
enum SimklListSyncMode {
  /// Push device My List statuses to Simkl. Do not mirror Simkl-only titles
  /// into the local cache (they still appear in My List while connected).
  keepLocal,

  /// Overwrite local My List statuses from Simkl. No list export.
  useSimkl,

  /// Push local titles, then pull Simkl into local. Same title, different
  /// status → device wins.
  merge,
}

class SimklSyncResult {
  const SimklSyncResult({
    this.mode,
    required this.watchlistImported,
    required this.watchlistExported,
    required this.watchingImported,
    required this.moviesImported,
    required this.episodesImported,
    required this.episodesExported,
  });

  final SimklListSyncMode? mode;
  final int watchlistImported;
  final int watchlistExported;
  final int watchingImported;
  final int moviesImported;
  final int episodesImported;
  final int episodesExported;
}

/// Full Simkl integration - PIN-based auth, watchlist sync,
/// scrobble, history, ratings, and two-way import/export.
class SimklService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final SimklService _instance = SimklService._internal();
  factory SimklService() => _instance;
  SimklService._internal();

  // ── Constants ──────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://api.simkl.com';

  // Injected at build time via --dart-define or .env
  static const String _clientId =
      String.fromEnvironment('SIMKL_CLIENT_ID');
  // ignore: unused_field
  static const String _clientSecret =
      String.fromEnvironment('SIMKL_CLIENT_SECRET');

  /// False when this build has no `SIMKL_CLIENT_ID` dart-define.
  static bool get isConfigured => _clientId.trim().isNotEmpty;

  // ── Secure Storage Keys ────────────────────────────────────────────────
  static const String _keyAccessToken = 'simkl_access_token';
  static const String _keyLastActivity = 'simkl_last_activity';
  static const String _keyLastSyncMs = 'simkl_last_sync_ms';

  /// Max synthetic continue-watching seeds per background sync (newest first).
  static const int _resumeImportCap = 20;

  /// Skip background fullSync if we synced this recently (Simkl guidance).
  static const Duration _minSyncInterval = Duration(minutes: 15);

  // ── Runtime state ──────────────────────────────────────────────────────
  Future<String?> _secureRead(String key) =>
      ForjaPlatformSecureStore.read(key);

  Future<void> _secureWrite(String key, String value) =>
      ForjaPlatformSecureStore.write(key, value);

  Future<void> _secureDelete(String key) =>
      ForjaPlatformSecureStore.delete(key);

  bool _initialSyncDone = false;
  Future<void>? _syncInProgress;

  // ═══════════════════════════════════════════════════════════════════════
  //  A U T H   -   P I N   F L O W
  // ═══════════════════════════════════════════════════════════════════════

  /// Step 1: Request a PIN code from Simkl.
  /// Returns {"user_code": "ABCD1234", "verification_url": "https://simkl.com/pin/ABCD1234", "expires_in": 900, "interval": 5}
  Future<Map<String, dynamic>?> requestPin() async {
    if (!isConfigured) {
      debugPrint('[Simkl] Request PIN skipped: SIMKL_CLIENT_ID not set');
      return null;
    }
    try {
      final resp = await engineHttp('GET', '$_baseUrl/oauth/pin?client_id=$_clientId&redirect=', headers: _publicHeaders, maxRetries: 0);
      if (resp.status == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      debugPrint('[Simkl] Request PIN failed: ${resp.status} ${resp.body}');
    } catch (e) {
      debugPrint('[Simkl] Request PIN error: $e');
    }
    return null;
  }

  /// Step 2: Poll for the token after user enters the PIN on simkl.com.
  /// Returns the access token string or null if not ready/failed.
  Future<String?> pollForToken(String userCode) async {
    try {
      final resp = await engineHttp(
        'GET',
        '$_baseUrl/oauth/pin/$userCode?client_id=$_clientId',
        headers: _publicHeaders,
        maxRetries: 0,
      );
      if (resp.status == 200) {
        final data = json.decode(resp.body);
        final result = data['result'];
        if (result == 'OK' && data['access_token'] != null) {
          final token = data['access_token'] as String;
          await _secureWrite(_keyAccessToken, token);
          debugPrint('[Simkl] Token saved.');
          return token;
        }
        // result == "KO" means user hasn't entered PIN yet
      }
    } catch (e) {
      debugPrint('[Simkl] Poll token error: $e');
    }
    return null;
  }

  /// Check if the user is logged in.
  Future<bool> isLoggedIn() async {
    final token = await _secureRead(_keyAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// Log out - delete stored token.
  Future<void> logout() async {
    await _secureDelete(_keyAccessToken);
    await _secureDelete(_keyLastActivity);
    await _secureDelete(_keyLastSyncMs);
    _initialSyncDone = false;
    _syncInProgress = null;
    debugPrint('[Simkl] Logged out.');
  }

  /// Handle 401 unauthorized - token revoked server-side.
  void _handleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      debugPrint('[Simkl] 401 Unauthorized - token revoked, clearing auth');
      _secureDelete(_keyAccessToken);
      _secureDelete(_keyLastActivity);
      _secureDelete(_keyLastSyncMs);
      _initialSyncDone = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  U S E R   P R O F I L E
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserProfile() async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return null;

    try {
      final resp = await engineHttp('GET', '$_baseUrl/users/settings', headers: _authHeaders(token), maxRetries: 0);
      if (resp.status == 200) {
        final data = json.decode(resp.body);
        return data['user'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[Simkl] Get profile error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  S Y N C   A C T I V I T I E S
  // ═══════════════════════════════════════════════════════════════════════

  /// Get last activity timestamps (for smart incremental sync).
  Future<Map<String, dynamic>?> _getLastActivities() async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return null;

    try {
      final resp = await engineHttp('GET', '$_baseUrl/sync/activities', headers: _authHeaders(token), maxRetries: 0);
      _handleUnauthorized(resp.status);
      if (resp.status == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Simkl] Get activities error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  A D D   T O   L I S T
  // ═══════════════════════════════════════════════════════════════════════

  /// Add items to the user's Simkl list.
  /// [shows], [movies], [anime] should be lists of maps with at least 'ids' key.
  Future<bool> _addToList({
    List<Map<String, dynamic>> shows = const [],
    List<Map<String, dynamic>> movies = const [],
    List<Map<String, dynamic>> anime = const [],
  }) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (anime.isNotEmpty) body['anime'] = anime;
    if (body.isEmpty) return false;

    try {
      final resp = await engineHttp('POST', '$_baseUrl/sync/add-to-list', headers: _authHeaders(token), body: json.encode(body), maxRetries: 0);
      debugPrint('[Simkl] Add to list: ${resp.status}');
      return resp.status == 200 || resp.status == 201;
    } catch (e) {
      debugPrint('[Simkl] Add to list error: $e');
      return false;
    }
  }

  /// Remove items from the user's Simkl list.
  Future<bool> _removeFromList({
    List<Map<String, dynamic>> shows = const [],
    List<Map<String, dynamic>> movies = const [],
    List<Map<String, dynamic>> anime = const [],
  }) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (anime.isNotEmpty) body['anime'] = anime;
    if (body.isEmpty) return false;

    try {
      final resp = await engineHttp('POST', '$_baseUrl/sync/remove-from-list', headers: _authHeaders(token), body: json.encode(body), maxRetries: 0);
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Simkl] Remove from list error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  W A T C H L I S T   -   C O N V E N I E N C E
  // ═══════════════════════════════════════════════════════════════════════

  /// Add a single item to watchlist (plan to watch).
  Future<bool> addToWatchlist({
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    required String mediaType,
  }) async {
    return setListStatus(
      tmdbId: tmdbId,
      imdbId: imdbId,
      anilistId: anilistId,
      mediaType: mediaType,
      to: 'plantowatch',
    );
  }

  /// Remove a single item from watchlist.
  Future<bool> removeFromWatchlist({
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    required String mediaType,
  }) async {
    if (mediaType == 'anime') {
      if (anilistId == null) return false;
      return _removeFromList(anime: [
        {
          'ids': {'anilist': anilistId},
        },
      ]);
    }

    if (tmdbId == null && imdbId == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final item = {'ids': ids};
    final type =
        (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    return _removeFromList(
      shows: type == 'shows' ? [item] : [],
      movies: type == 'movies' ? [item] : [],
    );
  }

  /// Move a title into a Simkl list bucket (`plantowatch`, `watching`, `hold`,
  /// `completed`, `dropped`). Movies also get history add/remove so Completed
  /// matches watched state.
  Future<bool> setListStatus({
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    required String mediaType,
    required String to,
  }) async {
    if (mediaType == 'anime') {
      if (anilistId == null) return false;
      final item = {
        'ids': {'anilist': anilistId},
        'to': to,
      };
      return _addToList(anime: [item]);
    }

    if (tmdbId == null && imdbId == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final item = {'ids': ids, 'to': to};
    final hist = {'ids': ids};
    final type =
        (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    final ok = await _addToList(
      shows: type == 'shows' ? [item] : [],
      movies: type == 'movies' ? [item] : [],
    );
    if (!ok) return false;

    if (type == 'movies') {
      if (to == 'completed') {
        await addToHistory(movies: [hist]);
      } else {
        await removeFromHistory(movies: [hist]);
      }
    }
    return true;
  }

  /// Current Simkl list status for a TMDB title, or null if not in the library.
  Future<String?> getListStatus({
    int? tmdbId,
    int? anilistId,
    required String mediaType,
  }) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return null;
    final type = mediaType == 'anime'
        ? 'anime'
        : (mediaType == 'tv' || mediaType == 'series')
            ? 'shows'
            : 'movies';
    try {
      for (final item in await _allItems(token, type, status: 'all')) {
        final ids = _ids(_media(item));
        if (type == 'anime') {
          if (anilistId != null && _asInt(ids['anilist']) == anilistId) {
            return item['status']?.toString();
          }
        } else if (tmdbId != null && _asInt(ids['tmdb']) == tmdbId) {
          return item['status']?.toString();
        }
      }
    } catch (e) {
      debugPrint('[Simkl] getListStatus error: $e');
    }
    return null;
  }

  /// Drop watched history (and Completed list status for movies) after local
  /// progress trash.
  Future<bool> clearWatched({
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    if (mediaType == 'anime' && anilistId != null) {
      final ids = <String, dynamic>{'anilist': anilistId};
      if (episode != null) {
        return removeFromHistory(anime: [
          {
            'ids': ids,
            'episodes': [
              {'number': episode},
            ],
          }
        ]);
      }
      final hist = {'ids': ids};
      await removeFromHistory(anime: [hist]);
      return _removeFromList(anime: [hist]);
    }

    if (tmdbId == null) return false;
    final ids = <String, dynamic>{'tmdb': tmdbId};
    if (imdbId != null && imdbId.isNotEmpty) ids['imdb'] = imdbId;

    if (mediaType == 'tv' && season != null && episode != null) {
      return removeFromHistory(shows: [
        {
          'ids': ids,
          'seasons': [
            {
              'number': season,
              'episodes': [
                {'number': episode},
              ],
            }
          ],
        }
      ]);
    }

    final hist = {'ids': ids};
    final type =
        (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    final ok = await removeFromHistory(
      shows: type == 'shows' ? [hist] : [],
      movies: type == 'movies' ? [hist] : [],
    );
    if (type == 'movies') {
      final status = await getListStatus(tmdbId: tmdbId, mediaType: mediaType);
      if (status == 'completed') {
        await _removeFromList(movies: [hist]);
      }
    }
    return ok;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  H I S T O R Y
  // ═══════════════════════════════════════════════════════════════════════

  /// Add items to watched history.
  Future<bool> addToHistory({
    List<Map<String, dynamic>> shows = const [],
    List<Map<String, dynamic>> movies = const [],
    List<Map<String, dynamic>> anime = const [],
  }) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (anime.isNotEmpty) body['anime'] = anime;
    if (body.isEmpty) return false;

    try {
      final resp = await engineHttp('POST', '$_baseUrl/sync/history', headers: _authHeaders(token), body: json.encode(body), maxRetries: 0);
      return resp.status == 200 || resp.status == 201;
    } catch (e) {
      debugPrint('[Simkl] Add to history error: $e');
      return false;
    }
  }

  /// Remove items from watched history.
  Future<bool> removeFromHistory({
    List<Map<String, dynamic>> shows = const [],
    List<Map<String, dynamic>> movies = const [],
    List<Map<String, dynamic>> anime = const [],
  }) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (anime.isNotEmpty) body['anime'] = anime;
    if (body.isEmpty) return false;

    try {
      final resp = await engineHttp('POST', '$_baseUrl/sync/history/remove', headers: _authHeaders(token), body: json.encode(body), maxRetries: 0);
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Simkl] Remove from history error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  R A T I N G S
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all user ratings.
  Future<List<Map<String, dynamic>>> getRatings() async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return [];

    try {
      final resp = await engineHttp('GET', '$_baseUrl/sync/ratings', headers: _authHeaders(token), maxRetries: 0);
      if (resp.status == 200) {
        final data = json.decode(resp.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[Simkl] Get ratings error: $e');
    }
    return [];
  }

  /// Add/update a rating. Rating scale: 1-10.
  Future<bool> addRating({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
    required int rating,
  }) async {
    if (tmdbId == null && imdbId == null) return false;
    if (rating < 1 || rating > 10) return false;
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    try {
      final resp = await engineHttp(
        'POST',
        '$_baseUrl/sync/ratings',
        headers: _authHeaders(token),
        body: json.encode({
          type: [
            {'ids': ids, 'rating': rating}
          ]
        }),
        maxRetries: 0,
      );
      return resp.status == 200 || resp.status == 201;
    } catch (e) {
      debugPrint('[Simkl] Add rating error: $e');
      return false;
    }
  }

  /// Remove a rating.
  Future<bool> removeRating({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    try {
      final resp = await engineHttp(
        'POST',
        '$_baseUrl/sync/ratings/remove',
        headers: _authHeaders(token),
        body: json.encode({
          type: [
            {'ids': ids}
          ]
        }),
        maxRetries: 0,
      );
      return resp.status == 200;
    } catch (e) {
      debugPrint('[Simkl] Remove rating error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  S C R O B B L E
  // ═══════════════════════════════════════════════════════════════════════

  /// Start scrobbling (user starts watching).
  Future<bool> scrobbleStart({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) =>
      _scrobble('start', tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode);

  /// Pause scrobbling.
  Future<bool> scrobblePause({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) =>
      _scrobble('pause', tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode);

  /// Stop scrobbling (user finished watching).
  Future<bool> scrobbleStop({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) =>
      _scrobble('stop', tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode);

  // ═══════════════════════════════════════════════════════════════════════
  //  I M P O R T   -   W A T C H L I S T   >   M Y   L I S T
  // ═══════════════════════════════════════════════════════════════════════

  /// Mirror Simkl list buckets onto local My List (backup if Simkl is removed).
  Future<int> importWatchlistToMyList() async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return 0;

    const statuses = [
      'plantowatch',
      'watching',
      'hold',
      'completed',
      'dropped',
    ];
    var imported = 0;
    for (final status in statuses) {
      for (final type in ['movies', 'shows']) {
        try {
          final items = await _allItems(token, type, status: status);
          for (final item in items) {
            final show = _media(item);
            final ids = _ids(show);
            final tmdbId = _asInt(ids['tmdb']);
            final imdbId = ids['imdb']?.toString();
            final title = show['title']?.toString() ?? 'Unknown';
            final mediaType = type == 'shows' ? 'tv' : 'movie';
            if (tmdbId == null) continue;
            await MyListService().upsertMovie(
              tmdbId: tmdbId,
              imdbId: imdbId,
              title: title,
              posterPath: '',
              mediaType: mediaType,
              listStatus: status,
            );
            imported++;
          }
        } catch (e) {
          debugPrint('[Simkl] Import My List ($type/$status) error: $e');
        }
      }
    }
    debugPrint('[Simkl] Mirrored $imported items to local My List');
    return imported;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  F U L L   S Y N C
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> fullSync({bool force = false}) async {
    if (!force && _initialSyncDone) return;
    if (_syncInProgress != null) {
      await _syncInProgress;
      return;
    }
    final completer = Completer<void>();
    _syncInProgress = completer.future;

    try {
      final loggedIn = await isLoggedIn();
      if (!loggedIn) return;

      if (!force && await _syncedRecently()) {
        _initialSyncDone = true;
        debugPrint('[Simkl] Synced recently, skipping');
        return;
      }

      debugPrint('[Simkl] Starting smart sync...');
      final activities = await _getLastActivities();
      final lastAll = activities?['all']?.toString() ?? '';
      final savedAll = await _secureRead(_keyLastActivity);

      int moviesImported = 0, watchingImported = 0, episodesImported = 0;

      if (force || savedAll != lastAll) {
        // First connect / force = full library. Later stamp bumps = date_from
        // delta. List buckets stay Sync Now / connect only.
        final dateFrom = (!force &&
                savedAll != null &&
                savedAll.isNotEmpty &&
                savedAll != lastAll)
            ? savedAll
            : null;
        if (dateFrom != null) {
          debugPrint('[Simkl] Delta sync from $dateFrom');
        } else {
          debugPrint('[Simkl] Full library sync');
        }
        watchingImported = await importWatchingProgress(dateFrom: dateFrom);
        moviesImported = await importCompletedMovies(dateFrom: dateFrom);
        episodesImported = await importWatchedEpisodes(dateFrom: dateFrom);
        if (lastAll.isNotEmpty) {
          await _secureWrite(_keyLastActivity, lastAll);
        }
        await _secureWrite(
          _keyLastSyncMs,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } else {
        debugPrint('[Simkl] No activity changes, skipping sync');
        await _secureWrite(
          _keyLastSyncMs,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      _initialSyncDone = true;
      debugPrint(
        '[Simkl] Smart sync done - watching: $watchingImported, '
        'movies: $moviesImported, episodes: $episodesImported',
      );
    } finally {
      _syncInProgress = null;
      completer.complete();
    }
  }

  Future<bool> _syncedRecently() async {
    final raw = await _secureRead(_keyLastSyncMs);
    final lastMs = int.tryParse(raw ?? '') ?? 0;
    if (lastMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch - lastMs <
        _minSyncInterval.inMilliseconds;
  }

  /// Push local My List buckets to Simkl with each item's real [listStatus].
  Future<int> exportMyListToWatchlist() async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return 0;

    await MyListService().ensureLoaded();
    final items = MyListService().items;
    if (items.isEmpty) return 0;

    final movies = <Map<String, dynamic>>[];
    final shows = <Map<String, dynamic>>[];
    final anime = <Map<String, dynamic>>[];

    for (final item in items) {
      final status =
          item['listStatus']?.toString() ?? MyListService.defaultStatus;
      final mt = item['mediaType']?.toString() ?? 'movie';

      if (mt == 'anime') {
        final anilist = item['anilistId'] as int?;
        if (anilist == null) continue;
        anime.add({
          'ids': {'anilist': anilist},
          'to': status,
        });
        continue;
      }

      final ids = <String, dynamic>{};
      final tmdb = item['tmdbId'] as int?;
      final imdb = item['imdbId']?.toString();
      if (tmdb != null) ids['tmdb'] = tmdb;
      if (imdb != null && imdb.isNotEmpty) ids['imdb'] = imdb;
      if (ids.isEmpty) continue;

      final entry = {'ids': ids, 'to': status};
      if (mt == 'tv' || mt == 'series' || mt == 'asian_drama') {
        shows.add(entry);
      } else {
        movies.add(entry);
      }
    }

    if (movies.isEmpty && shows.isEmpty && anime.isEmpty) return 0;

    final ok = await _addToList(movies: movies, shows: shows, anime: anime);
    final total = movies.length + shows.length + anime.length;
    debugPrint('[Simkl] Exported $total items: ${ok ? 'success' : 'failed'}');
    return ok ? total : 0;
  }

  /// List + history sync for connect / Sync Now after the user picks a mode.
  Future<SimklSyncResult> syncWithMode(SimklListSyncMode mode) async {
    var watchlistImported = 0;
    var watchlistExported = 0;

    switch (mode) {
      case SimklListSyncMode.useSimkl:
        watchlistImported = await importWatchlistToMyList();
      case SimklListSyncMode.keepLocal:
        watchlistExported = await exportMyListToWatchlist();
      case SimklListSyncMode.merge:
        watchlistExported = await exportMyListToWatchlist();
        watchlistImported = await importWatchlistToMyList();
    }

    final history = await syncHistoryOnly();
    return SimklSyncResult(
      mode: mode,
      watchlistImported: watchlistImported,
      watchlistExported: watchlistExported,
      watchingImported: history.watchingImported,
      moviesImported: history.moviesImported,
      episodesImported: history.episodesImported,
      episodesExported: history.episodesExported,
    );
  }

  /// Progress / completed / episodes only (no My List bucket push/pull).
  Future<SimklSyncResult> syncHistoryOnly() async {
    final watchingImported = await importWatchingProgress();
    final moviesImported = await importCompletedMovies();
    final episodesImported = await importWatchedEpisodes();
    final episodesExported = await exportWatchedEpisodes();
    await _markSyncComplete();
    return SimklSyncResult(
      watchlistImported: 0,
      watchlistExported: 0,
      watchingImported: watchingImported,
      moviesImported: moviesImported,
      episodesImported: episodesImported,
      episodesExported: episodesExported,
    );
  }

  Future<void> _markSyncComplete() async {
    final activities = await _getLastActivities();
    final lastAll = activities?['all']?.toString() ?? '';
    if (lastAll.isNotEmpty) {
      await _secureWrite(_keyLastActivity, lastAll);
    }
    await _secureWrite(
      _keyLastSyncMs,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _initialSyncDone = true;
  }

  /// Movies + shows + anime for one status. Simkl `all-items` has no page param.
  Future<List<Map<String, dynamic>>> getWatchlistStatus(String status) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return const [];

    final out = <Map<String, dynamic>>[];
    for (final type in ['movies', 'shows', 'anime']) {
      try {
        final items = await _allItems(token, type, status: status);
        for (final item in items) {
          out.add({...item, '_simklType': type});
        }
      } catch (e) {
        debugPrint('[Simkl] Library fetch ($type/$status) error: $e');
      }
    }
    return out;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  W A T C H E D   E P I S O D E S   S Y N C
  // ═══════════════════════════════════════════════════════════════════════

  /// Import completed TV + anime episodes into local watched marks.
  Future<int> importWatchedEpisodes({String? dateFrom}) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return 0;

    final q = _withDateFrom(
      '?extended=full&include_all_episodes=yes&episode_watched_at=yes',
      dateFrom,
    );
    var imported = 0;
    try {
      for (final item in await _allItems(token, 'shows', status: 'completed', query: q)) {
        imported += await _markShowEpisodes(item);
      }
      for (final item in await _allItems(token, 'anime', status: 'completed', query: q)) {
        imported += await _markAnimeEpisodes(item);
      }
      debugPrint('[Simkl] Imported $imported watched episodes');
    } catch (e) {
      debugPrint('[Simkl] Import watched episodes error: $e');
    }
    return imported;
  }

  /// Completed movies → local watch history (finished, so Home CW hides them).
  Future<int> importCompletedMovies({String? dateFrom}) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return 0;

    var imported = 0;
    try {
      for (final item in await _allItems(
        token,
        'movies',
        status: 'completed',
        query: _withDateFrom('', dateFrom),
      )) {
        final movie = _media(item);
        final ids = _ids(movie);
        final tmdbId = _asInt(ids['tmdb']);
        if (tmdbId == null) continue;
        if (await WatchHistoryService().getProgress(tmdbId) != null) continue;

        final art = await _resolveArt(tmdbId, 'movie', movie);
        final durationMs = art.durationMs;
        await WatchHistoryService().saveProgress(
          tmdbId: tmdbId,
          imdbId: ids['imdb']?.toString(),
          title: movie['title']?.toString() ?? 'Unknown',
          posterPath: art.poster,
          backdropPath: art.backdrop,
          method: 'simkl_import',
          sourceId: 'simkl',
          position: durationMs,
          duration: durationMs,
          mediaType: 'movie',
        );
        imported++;
      }
      debugPrint('[Simkl] Imported $imported completed movies');
    } catch (e) {
      debugPrint('[Simkl] Import completed movies error: $e');
    }
    return imported;
  }

  /// In-progress Simkl watching → Home / Anime continue watching.
  ///
  /// Episode marks apply to every returned row. Synthetic CW resumes are
  /// newest-first and capped — Home only shows a short row.
  Future<int> importWatchingProgress({String? dateFrom}) async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return 0;

    final q = _withDateFrom(
      '?extended=full&next_watch_info=yes&episode_watched_at=yes',
      dateFrom,
    );
    var imported = 0;
    try {
      final shows =
          await _allItems(token, 'shows', status: 'watching', query: q);
      final anime =
          await _allItems(token, 'anime', status: 'watching', query: q);

      for (final item in shows) {
        await _markShowEpisodes(item);
      }
      for (final item in anime) {
        await _markAnimeEpisodes(item);
      }

      final candidates = <({Map<String, dynamic> item, bool anime, DateTime? at})>[
        for (final item in shows)
          (item: item, anime: false, at: _parseSimklTime(item['last_watched_at'])),
        for (final item in anime)
          (item: item, anime: true, at: _parseSimklTime(item['last_watched_at'])),
      ];
      candidates.sort((a, b) {
        final am = a.at?.millisecondsSinceEpoch ?? 0;
        final bm = b.at?.millisecondsSinceEpoch ?? 0;
        return bm.compareTo(am);
      });

      for (final c in candidates) {
        if (imported >= _resumeImportCap) break;
        final n = c.anime
            ? await _importAnimeResume(c.item)
            : await _importShowResume(c.item);
        imported += n;
      }
      debugPrint('[Simkl] Imported $imported watching resume items');
    } catch (e) {
      debugPrint('[Simkl] Import watching error: $e');
    }
    return imported;
  }

  /// Export all locally marked watched episodes to Simkl history.
  Future<int> exportWatchedEpisodes() async {
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return 0;

    final cache = await _getEpisodeWatchedCache();
    if (cache.isEmpty) return 0;

    // Group by tmdbId
    final Map<int, List<Map<String, int>>> grouped = {};
    for (final key in cache.keys) {
      if (cache[key] != true) continue;
      final match = RegExp(r'^(\d+)_S(\d+)_E(\d+)$').firstMatch(key);
      if (match == null) continue;
      final tmdbId = int.parse(match.group(1)!);
      final season = int.parse(match.group(2)!);
      final episode = int.parse(match.group(3)!);
      grouped.putIfAbsent(tmdbId, () => []);
      grouped[tmdbId]!.add({'season': season, 'episode': episode});
    }

    int exported = 0;
    final shows = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      final Map<int, List<int>> seasonEps = {};
      for (final ep in entry.value) {
        seasonEps.putIfAbsent(ep['season']!, () => []);
        seasonEps[ep['season']!]!.add(ep['episode']!);
      }

      shows.add({
        'ids': {'tmdb': entry.key},
        'seasons': seasonEps.entries.map((se) => {
          'number': se.key,
          'episodes': se.value.map((e) => {'number': e}).toList(),
        }).toList(),
      });
      exported += entry.value.length;
    }

    if (shows.isEmpty) return 0;
    final ok = await addToHistory(shows: shows);
    debugPrint('[Simkl] Exported $exported watched episodes: ${ok ? 'success' : 'failed'}');
    return ok ? exported : 0;
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

  // ═══════════════════════════════════════════════════════════════════════
  //  I N T E R N A L   H E L P E R S
  // ═══════════════════════════════════════════════════════════════════════

  Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
        'simkl-api-key': _clientId,
      };

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'simkl-api-key': _clientId,
        'Authorization': 'Bearer $token',
      };

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> _media(Map<String, dynamic> item) {
    final raw = item['show'] ?? item['movie'] ?? item['anime'] ?? item;
    return raw is Map<String, dynamic> ? raw : item;
  }

  Map<String, dynamic> _ids(Map<String, dynamic> media) {
    final raw = media['ids'];
    return raw is Map<String, dynamic> ? raw : const {};
  }

  List<Map<String, dynamic>> _entries(dynamic decoded, String key) {
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded[key] is List) {
      return (decoded[key] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _allItems(
    String token,
    String type, {
    String? status,
    String query = '',
  }) async {
    final path = status == null
        ? '/sync/all-items/$type$query'
        : '/sync/all-items/$type/$status$query';
    final resp = await engineHttp(
      'GET',
      '$_baseUrl$path',
      headers: _authHeaders(token),
      maxRetries: 0,
    );
    if (resp.status != 200) {
      debugPrint('[Simkl] GET $path → ${resp.status}');
      return const [];
    }
    return _entries(json.decode(resp.body), type);
  }

  /// Simkl `last_watched` / `next_to_watch`: `S08E02` or anime `E20`.
  ({int season, int episode})? _parseEpisodeCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final se = RegExp(r'^S(\d+)E(\d+)$', caseSensitive: false).firstMatch(code);
    if (se != null) {
      return (season: int.parse(se.group(1)!), episode: int.parse(se.group(2)!));
    }
    final ep = RegExp(r'^E(\d+)$', caseSensitive: false).firstMatch(code);
    if (ep != null) {
      return (season: 1, episode: int.parse(ep.group(1)!));
    }
    return null;
  }

  List<({int season, int episode, String? watchedAt})> _episodeRows(
    Map<String, dynamic> item, {
    required bool flattenToSeason1,
  }) {
    final seasons = item['seasons'] as List? ?? [];
    final rows = <({int season, int episode, String? watchedAt})>[];
    final usable = <Map<String, dynamic>>[];
    for (final raw in seasons) {
      if (raw is! Map<String, dynamic>) continue;
      if ((_asInt(raw['number']) ?? 0) == 0) continue;
      usable.add(raw);
    }
    var abs = 0;
    for (final s in usable) {
      final sNum = _asInt(s['number']) ?? 1;
      final episodes = s['episodes'] as List? ?? [];
      for (final raw in episodes) {
        if (raw is! Map<String, dynamic>) continue;
        final eNum = _asInt(raw['number']) ?? 0;
        if (eNum == 0) continue;
        abs++;
        final season = flattenToSeason1 ? 1 : sNum;
        final episode = flattenToSeason1
            ? (usable.length <= 1 ? eNum : abs)
            : eNum;
        rows.add((
          season: season,
          episode: episode,
          watchedAt: raw['watched_at']?.toString(),
        ));
      }
    }
    return rows;
  }

  Future<int> _markShowEpisodes(Map<String, dynamic> item) async {
    final tmdbId = _asInt(_ids(_media(item))['tmdb']);
    if (tmdbId == null) return 0;
    var imported = 0;
    var rows = _episodeRows(item, flattenToSeason1: false);
    if (rows.isEmpty) {
      final n = _asInt(item['watched_episodes_count']) ?? 0;
      rows = [
        for (var i = 1; i <= n; i++)
          (season: 1, episode: i, watchedAt: item['last_watched_at']?.toString()),
      ];
    }
    for (final row in rows) {
      final already =
          await EpisodeWatchedService().isWatched(tmdbId, row.season, row.episode);
      if (already) continue;
      await EpisodeWatchedService().setWatchedLocalWithTimestamp(
        tmdbId,
        row.season,
        row.episode,
        true,
        row.watchedAt,
      );
      imported++;
    }
    return imported;
  }

  Future<int> _markAnimeEpisodes(Map<String, dynamic> item) async {
    final anilistId = _asInt(_ids(_media(item))['anilist']);
    if (anilistId == null) return 0;
    var imported = 0;
    var rows = _episodeRows(item, flattenToSeason1: true);
    if (rows.isEmpty) {
      final n = _asInt(item['watched_episodes_count']) ?? 0;
      rows = [
        for (var i = 1; i <= n; i++)
          (season: 1, episode: i, watchedAt: item['last_watched_at']?.toString()),
      ];
    }
    for (final row in rows) {
      final already = await EpisodeWatchedService().isWatched(
        anilistId,
        1,
        row.episode,
        catalog: EpisodeWatchedService.catalogAnilist,
      );
      if (already) continue;
      await EpisodeWatchedService().setWatchedLocalWithTimestamp(
        anilistId,
        1,
        row.episode,
        true,
        row.watchedAt,
        catalog: EpisodeWatchedService.catalogAnilist,
      );
      imported++;
    }
    return imported;
  }

  ({int season, int episode})? _resumePoint(Map<String, dynamic> item) {
    final info = item['next_to_watch_info'];
    if (info is Map<String, dynamic>) {
      final s = _asInt(info['season']) ?? 1;
      final e = _asInt(info['episode']);
      if (e != null && e > 0) return (season: s, episode: e);
    }
    return _parseEpisodeCode(item['next_to_watch']?.toString()) ??
        _parseEpisodeCode(item['last_watched']?.toString());
  }

  Future<int> _importShowResume(Map<String, dynamic> item) async {
    final media = _media(item);
    final ids = _ids(media);
    final tmdbId = _asInt(ids['tmdb']);
    final point = _resumePoint(item);
    if (tmdbId == null || point == null) return 0;

    final art = await _resolveArt(tmdbId, 'tv', media);
    final durationMs = art.durationMs;
    final positionMs = (durationMs * 0.05).round().clamp(1, durationMs - 1);
    final title = media['title']?.toString() ?? 'Unknown';
    final imdbId = ids['imdb']?.toString();

    var imported = 0;
    final existing = await WatchHistoryService().getProgress(
      tmdbId,
      season: point.season,
      episode: point.episode,
    );
    if (existing == null) {
      await WatchHistoryService().saveProgress(
        tmdbId: tmdbId,
        imdbId: imdbId,
        title: title,
        posterPath: art.poster,
        backdropPath: art.backdrop,
        method: 'simkl_import',
        sourceId: 'simkl',
        position: positionMs,
        duration: durationMs,
        season: point.season,
        episode: point.episode,
        mediaType: 'tv',
      );
      imported++;
    }

    if (await _seedDramaHubContinueFromSimkl(
      tmdbId: tmdbId,
      imdbId: imdbId,
      title: title,
      posterPath: art.poster,
      backdropPath: art.backdrop,
      episode: point.episode,
      positionMs: positionMs,
      durationMs: durationMs,
    )) {
      imported++;
    }
    return imported > 0 ? 1 : 0;
  }

  /// Simkl TV resumes → Asian Drama hub CW (KissKh extract uses TMDB id).
  Future<bool> _seedDramaHubContinueFromSimkl({
    required int tmdbId,
    String? imdbId,
    required String title,
    required String posterPath,
    required String backdropPath,
    required int episode,
    required int positionMs,
    required int durationMs,
  }) async {
    final hubPlugin =
        await PluginNavRegistry.pluginIdForEngineType('drama') ?? '';
    if (hubPlugin.isEmpty) return false;

    final existing = await CatalogWatchHistory.getAll(hubPlugin);
    final already = existing.any((entry) {
      if (entry['metaId']?.toString() == '$hubPlugin:$tmdbId') return true;
      final meta = CatalogWatchHistory.metaFromEntry(entry);
      return meta?.numericId('tmdb') == tmdbId;
    });
    if (already) return false;

    try {
      final meta = catalogMetaFromLegacyListItem({
        'pluginId': hubPlugin,
        'tmdbId': tmdbId,
        'imdbId': ?imdbId,
        'mediaType': 'asian_drama',
        'title': title,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
      });
      await CatalogWatchHistory.record(
        pluginId: hubPlugin,
        meta: meta,
        episodeNumber: episode,
        position: Duration(milliseconds: positionMs),
        duration: Duration(milliseconds: durationMs),
      );
      return true;
    } catch (e) {
      debugPrint('[Simkl] Drama resume $tmdbId failed: $e');
      return false;
    }
  }

  Future<int> _importAnimeResume(Map<String, dynamic> item) async {
    final media = _media(item);
    final anilistId = _asInt(_ids(media)['anilist']);
    final point = _resumePoint(item);
    if (anilistId == null || point == null) return 0;
    final hubPlugin =
        await PluginNavRegistry.pluginIdForEngineType('anime') ?? '';
    if (hubPlugin.isEmpty) return 0;
    final existing = await CatalogWatchHistory.getAll(hubPlugin);
    if (existing.any((e) => e['metaId'] == '$hubPlugin:$anilistId')) return 0;
    try {
      final title = (media['title'] as String?)?.trim() ?? 'Anime';
      final meta = catalogMetaFromLegacyListItem({
        ...item,
        'pluginId': hubPlugin,
        'anilistId': anilistId,
        'mediaType': 'anime',
        'title': title,
      });
      final runtimeMin = _asInt(media['runtime']) ?? 24;
      final duration = Duration(minutes: runtimeMin);
      await CatalogWatchHistory.record(
        pluginId: hubPlugin,
        meta: meta,
        episodeNumber: point.episode,
        position: Duration(
          milliseconds: (duration.inMilliseconds * 0.05).round(),
        ),
        duration: duration,
      );
      return 1;
    } catch (e) {
      debugPrint('[Simkl] Anime resume $anilistId failed: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _fetchTmdbInfo(int tmdbId, String mediaType) async {
    try {
      final type = mediaType == 'tv' ? 'tv' : 'movie';
      final raw = await runTmdbGetJson('$type/$tmdbId');
      final data = json.decode(raw);
      if (data is Map<String, dynamic> && data['error'] == null) {
        final poster = data['poster_path']?.toString() ?? '';
        final backdrop = data['backdrop_path']?.toString() ?? '';
        var runtimeMs = 6000000;
        if (type == 'movie' && data['runtime'] is int && (data['runtime'] as int) > 0) {
          runtimeMs = (data['runtime'] as int) * 60000;
        } else if (type == 'tv') {
          final epRuntimes = data['episode_run_time'] as List?;
          if (epRuntimes != null && epRuntimes.isNotEmpty) {
            runtimeMs = ((_asInt(epRuntimes.first) ?? 100) * 60000);
          }
        }
        return {'poster': poster, 'backdrop': backdrop, 'runtimeMs': runtimeMs};
      }
    } catch (e) {
      debugPrint('[Simkl] TMDB info fetch failed for $tmdbId: $e');
    }
    return {'poster': '', 'backdrop': '', 'runtimeMs': 6000000};
  }

  /// Prefer Simkl poster + runtime; TMDB only when art or duration is missing.
  Future<({String poster, String backdrop, int durationMs})> _resolveArt(
    int tmdbId,
    String mediaType,
    Map<String, dynamic> media,
  ) async {
    var poster = _simklPosterUrl(media['poster']?.toString());
    final runtimeMin = _asInt(media['runtime']);
    var durationMs =
        (runtimeMin != null && runtimeMin > 0) ? runtimeMin * 60000 : 0;
    var backdrop = '';

    if (poster.isEmpty || durationMs <= 0) {
      final info = await _fetchTmdbInfo(tmdbId, mediaType);
      if (poster.isEmpty) poster = info['poster'] as String? ?? '';
      backdrop = info['backdrop'] as String? ?? '';
      if (durationMs <= 0) {
        durationMs = info['runtimeMs'] as int? ?? 6000000;
      }
    }
    if (durationMs <= 0) durationMs = 6000000;
    return (poster: poster, backdrop: backdrop, durationMs: durationMs);
  }

  String _simklPosterUrl(String? poster) {
    if (poster == null || poster.isEmpty) return '';
    if (poster.startsWith('http')) return poster;
    return 'https://simkl.in/posters/${poster}_c.jpg';
  }

  DateTime? _parseSimklTime(dynamic raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Append `date_from` for continuous sync. Empty [query] → `?date_from=…`.
  String _withDateFrom(String query, String? dateFrom) {
    if (dateFrom == null || dateFrom.isEmpty) return query;
    final enc = Uri.encodeQueryComponent(dateFrom);
    if (query.isEmpty) return '?date_from=$enc';
    final sep = query.contains('?') ? '&' : '?';
    return '$query${sep}date_from=$enc';
  }

  Future<bool> _scrobble(
    String action, {
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    if (tmdbId <= 0) return false;
    if (mediaType != 'movie' &&
        mediaType != 'tv' &&
        mediaType != 'series') {
      return false;
    }
    final token = await _secureRead(_keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
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
      final resp = await engineHttp('POST', '$_baseUrl/scrobble/$action', headers: _authHeaders(token), body: json.encode(body), maxRetries: 0);
      _handleUnauthorized(resp.status);
      debugPrint('[Simkl] Scrobble $action (tmdb:$tmdbId): ${resp.status}');
      return resp.status == 200 || resp.status == 201;
    } catch (e) {
      debugPrint('[Simkl] Scrobble $action error: $e');
      return false;
    }
  }
}
