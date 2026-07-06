import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rust/rust.dart';
import 'package:api/services/my_list_service.dart';
import 'package:api/services/episode_watched_service.dart';

/// Full Simkl integration — PIN-based auth, watchlist sync,
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

  // ── Secure Storage Keys ────────────────────────────────────────────────
  static const String _keyAccessToken = 'simkl_access_token';

  // ── Runtime state ──────────────────────────────────────────────────────
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _initialSyncDone = false;
  Future<void>? _syncInProgress;

  // ═══════════════════════════════════════════════════════════════════════
  //  A U T H   —   P I N   F L O W
  // ═══════════════════════════════════════════════════════════════════════

  /// Step 1: Request a PIN code from Simkl.
  /// Returns {"user_code": "ABCD1234", "verification_url": "https://simkl.com/pin/ABCD1234", "expires_in": 900, "interval": 5}
  Future<Map<String, dynamic>?> requestPin() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/oauth/pin?client_id=$_clientId&redirect='),
        headers: _publicHeaders,
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      debugPrint('[Simkl] Request PIN failed: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[Simkl] Request PIN error: $e');
    }
    return null;
  }

  /// Step 2: Poll for the token after user enters the PIN on simkl.com.
  /// Returns the access token string or null if not ready/failed.
  Future<String?> pollForToken(String userCode) async {
    try {
      final resp = await http.get(
        Uri.parse(
          '$_baseUrl/oauth/pin/$userCode?client_id=$_clientId',
        ),
        headers: _publicHeaders,
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final result = data['result'];
        if (result == 'OK' && data['access_token'] != null) {
          final token = data['access_token'] as String;
          await _storage.write(key: _keyAccessToken, value: token);
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
    final token = await _storage.read(key: _keyAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// Log out — delete stored token.
  Future<void> logout() async {
    await _storage.delete(key: _keyAccessToken);
    _initialSyncDone = false;
    _syncInProgress = null;
    debugPrint('[Simkl] Logged out.');
  }

  /// Handle 401 unauthorized — token revoked server-side.
  void _handleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      debugPrint('[Simkl] 401 Unauthorized — token revoked, clearing auth');
      _storage.delete(key: _keyAccessToken);
      _initialSyncDone = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  U S E R   P R O F I L E
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserProfile() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/users/settings'),
        headers: _authHeaders(token),
      );
      if (resp.statusCode == 200) {
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
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/sync/activities'),
        headers: _authHeaders(token),
      );
      _handleUnauthorized(resp.statusCode);
      if (resp.statusCode == 200) {
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
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (anime.isNotEmpty) body['anime'] = anime;
    if (body.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sync/add-to-list'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );
      debugPrint('[Simkl] Add to list: ${resp.statusCode}');
      return resp.statusCode == 200 || resp.statusCode == 201;
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
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (anime.isNotEmpty) body['anime'] = anime;
    if (body.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sync/remove-from-list'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[Simkl] Remove from list error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  W A T C H L I S T   —   C O N V E N I E N C E
  // ═══════════════════════════════════════════════════════════════════════

  /// Add a single item to watchlist (plan to watch).
  Future<bool> addToWatchlist({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final item = {'ids': ids, 'to': 'plantowatch'};
    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    return _addToList(
      shows: type == 'shows' ? [item] : [],
      movies: type == 'movies' ? [item] : [],
    );
  }

  /// Remove a single item from watchlist.
  Future<bool> removeFromWatchlist({
    int? tmdbId,
    String? imdbId,
    required String mediaType,
  }) async {
    if (tmdbId == null && imdbId == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final item = {'ids': ids};
    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    return _removeFromList(
      shows: type == 'shows' ? [item] : [],
      movies: type == 'movies' ? [item] : [],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  H I S T O R Y
  // ═══════════════════════════════════════════════════════════════════════

  /// Add items to watched history.
  Future<bool> addToHistory({
    List<Map<String, dynamic>> shows = const [],
    List<Map<String, dynamic>> movies = const [],
  }) async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (body.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sync/history'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('[Simkl] Add to history error: $e');
      return false;
    }
  }

  /// Remove items from watched history.
  Future<bool> removeFromHistory({
    List<Map<String, dynamic>> shows = const [],
    List<Map<String, dynamic>> movies = const [],
  }) async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;

    final body = <String, dynamic>{};
    if (shows.isNotEmpty) body['shows'] = shows;
    if (movies.isNotEmpty) body['movies'] = movies;
    if (body.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sync/history/remove'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );
      return resp.statusCode == 200;
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
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return [];

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/sync/ratings'),
        headers: _authHeaders(token),
      );
      if (resp.statusCode == 200) {
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
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sync/ratings'),
        headers: _authHeaders(token),
        body: json.encode({
          type: [
            {'ids': ids, 'rating': rating}
          ]
        }),
      );
      return resp.statusCode == 200 || resp.statusCode == 201;
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
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;

    final ids = <String, dynamic>{};
    if (tmdbId != null) ids['tmdb'] = tmdbId;
    if (imdbId != null) ids['imdb'] = imdbId;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'shows' : 'movies';
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sync/ratings/remove'),
        headers: _authHeaders(token),
        body: json.encode({
          type: [
            {'ids': ids}
          ]
        }),
      );
      return resp.statusCode == 200;
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
  //  I M P O R T   —   W A T C H L I S T   >   M Y   L I S T
  // ═══════════════════════════════════════════════════════════════════════

  /// Import the user's Simkl "plan to watch" list into the local My List.
  Future<int> importWatchlistToMyList() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return 0;

    int imported = 0;
    for (final type in ['movies', 'shows']) {
      try {
        final resp = await http.get(
          Uri.parse('$_baseUrl/sync/all-items/$type/plantowatch'),
          headers: _authHeaders(token),
        );
        if (resp.statusCode != 200) continue;

        final data = json.decode(resp.body);
        final List items = data is List
            ? data
            : (data is Map && data.containsKey(type) ? data[type] as List : []);

        for (final raw in items) {
          final item = raw as Map<String, dynamic>;
          final show = item['show'] ?? item['movie'] ?? item;
          final ids = show['ids'] as Map<String, dynamic>? ?? {};
          final tmdbId = ids['tmdb'] as int?;
          final imdbId = ids['imdb']?.toString();
          final title = show['title']?.toString() ?? 'Unknown';
          final mediaType = type == 'shows' ? 'tv' : 'movie';

          if (tmdbId == null && imdbId == null) continue;
          final uid = tmdbId != null
              ? MyListService.movieId(tmdbId, mediaType)
              : 'stremio_${type == 'shows' ? 'series' : 'movie'}_$imdbId';

          if (!MyListService().contains(uid)) {
            if (tmdbId != null) {
              await MyListService().addMovie(
                tmdbId: tmdbId,
                imdbId: imdbId,
                title: title,
                posterPath: '',
                mediaType: mediaType,
              );
            } else {
              await MyListService().addStremioItem({
                'imdb_id': imdbId,
                'name': title,
                'type': mediaType == 'tv' ? 'series' : 'movie',
                'poster': '',
              });
            }
            imported++;
          }
        }
      } catch (e) {
        debugPrint('[Simkl] Import watchlist ($type) error: $e');
      }
    }
    debugPrint('[Simkl] Imported $imported items to My List');
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

      debugPrint('[Simkl] Starting smart sync...');
      final activities = await _getLastActivities();
      final lastAll = activities?['all']?.toString() ?? '';

      final savedAll = await _storage.read(key: 'simkl_last_activity');

      int watchlistCount = 0, episodesImported = 0;

      if (force || savedAll != lastAll) {
        watchlistCount = await importWatchlistToMyList();
        episodesImported = await importWatchedEpisodes();
        if (lastAll.isNotEmpty) await _storage.write(key: 'simkl_last_activity', value: lastAll);
      } else {
        debugPrint('[Simkl] No activity changes, skipping sync');
      }

      _initialSyncDone = true;
      debugPrint('[Simkl] Smart sync done — watchlist: $watchlistCount, episodes: $episodesImported');
    } finally {
      _syncInProgress = null;
      completer.complete();
    }
  }

  /// Push the entire local My List to Simkl watchlist.
  Future<int> exportMyListToWatchlist() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return 0;

    final items = MyListService().items;
    if (items.isEmpty) return 0;

    final movies = <Map<String, dynamic>>[];
    final shows = <Map<String, dynamic>>[];

    for (final item in items) {
      final ids = <String, dynamic>{};
      final tmdb = item['tmdbId'] as int?;
      final imdb = item['imdbId']?.toString();
      if (tmdb != null) ids['tmdb'] = tmdb;
      if (imdb != null) ids['imdb'] = imdb;
      if (ids.isEmpty) continue;

      final entry = {'ids': ids, 'to': 'plantowatch'};
      final mt = item['mediaType']?.toString() ?? 'movie';
      if (mt == 'tv' || mt == 'series') {
        shows.add(entry);
      } else {
        movies.add(entry);
      }
    }

    if (movies.isEmpty && shows.isEmpty) return 0;

    final ok = await _addToList(movies: movies, shows: shows);
    final total = movies.length + shows.length;
    debugPrint('[Simkl] Exported $total items: ${ok ? 'success' : 'failed'}');
    return ok ? total : 0;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  W A T C H E D   E P I S O D E S   S Y N C
  // ═══════════════════════════════════════════════════════════════════════

  /// Import completed shows/episodes from Simkl into EpisodeWatchedService.
  Future<int> importWatchedEpisodes() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return 0;

    int imported = 0;
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/sync/all-items/shows/completed'),
        headers: _authHeaders(token),
      );
      if (resp.statusCode != 200) return 0;

      final data = json.decode(resp.body);
      final List shows = data is List
          ? data
          : (data is Map && data.containsKey('shows') ? data['shows'] as List : []);

      for (final raw in shows) {
        final item = raw as Map<String, dynamic>;
        final show = item['show'] ?? item;
        final ids = show['ids'] as Map<String, dynamic>? ?? {};
        final tmdbId = ids['tmdb'] as int?;
        if (tmdbId == null) continue;

        final seasons = item['seasons'] as List? ?? [];
        for (final s in seasons) {
          final sNum = s['number'] as int? ?? 0;
          if (sNum == 0) continue;
          final episodes = s['episodes'] as List? ?? [];
          for (final ep in episodes) {
            final eNum = ep['number'] as int? ?? 0;
            if (eNum == 0) continue;
            final already = await EpisodeWatchedService().isWatched(tmdbId, sNum, eNum);
            if (!already) {
              await EpisodeWatchedService().setWatchedLocal(tmdbId, sNum, eNum, true);
              imported++;
            }
          }
        }
      }
      debugPrint('[Simkl] Imported $imported watched episodes');
    } catch (e) {
      debugPrint('[Simkl] Import watched episodes error: $e');
    }
    return imported;
  }

  /// Export all locally marked watched episodes to Simkl history.
  Future<int> exportWatchedEpisodes() async {
    final token = await _storage.read(key: _keyAccessToken);
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

  Future<bool> _scrobble(
    String action, {
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    final token = await _storage.read(key: _keyAccessToken);
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
      final resp = await http.post(
        Uri.parse('$_baseUrl/scrobble/$action'),
        headers: _authHeaders(token),
        body: json.encode(body),
      );
      _handleUnauthorized(resp.statusCode);
      debugPrint('[Simkl] Scrobble $action (tmdb:$tmdbId): ${resp.statusCode}');
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('[Simkl] Scrobble $action error: $e');
      return false;
    }
  }
}
