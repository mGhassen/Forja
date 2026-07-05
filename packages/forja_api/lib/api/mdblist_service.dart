import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// MDBlist integration — API-key auth, ratings aggregation, list management.
/// Register at https://mdblist.com/ to get an API key.
class MdblistService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final MdblistService _instance = MdblistService._internal();
  factory MdblistService() => _instance;
  MdblistService._internal();

  // ── Constants ──────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://api.mdblist.com';

  // ── Secure Storage Key ─────────────────────────────────────────────────
  static const String _keyApiKey = 'mdblist_api_key';

  // ── Runtime state ──────────────────────────────────────────────────────
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _cachedApiKey;

  // ═══════════════════════════════════════════════════════════════════════
  //  A U T H   ( A P I   K E Y )
  // ═══════════════════════════════════════════════════════════════════════

  /// Save API key.
  Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _keyApiKey, value: apiKey);
    _cachedApiKey = apiKey;
    debugPrint('[MDBlist] API key saved.');
  }

  /// Get stored API key.
  Future<String?> getApiKey() async {
    _cachedApiKey ??= await _storage.read(key: _keyApiKey);
    return _cachedApiKey;
  }

  /// Check if API key is configured.
  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Remove API key (log out).
  Future<void> logout() async {
    await _storage.delete(key: _keyApiKey);
    _cachedApiKey = null;
    debugPrint('[MDBlist] API key removed.');
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  U S E R   I N F O
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user info / validate API key.
  Future<Map<String, dynamic>?> getUserInfo() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/user?apikey=$apiKey'),
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      debugPrint('[MDBlist] User info failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('[MDBlist] User info error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  R A T I N G S   L O O K U P
  // ═══════════════════════════════════════════════════════════════════════

  /// Get aggregated ratings for a title by IMDb ID.
  /// Returns ratings from IMDb, TMDB, Trakt, Letterboxd, RT, Metacritic, etc.
  Future<Map<String, dynamic>?> getRatingsByImdb(String imdbId) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/?apikey=$apiKey&i=$imdbId'),
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[MDBlist] Get ratings error: $e');
    }
    return null;
  }

  /// Get aggregated ratings for a title by TMDB ID + media type.
  Future<Map<String, dynamic>?> getRatingsByTmdb(int tmdbId, String mediaType) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;

    final type = (mediaType == 'tv' || mediaType == 'series') ? 'show' : 'movie';
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/?apikey=$apiKey&tm=$tmdbId&m=$type'),
      );
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[MDBlist] Get ratings by TMDB error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  L I S T S
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all of the user's lists.
  Future<List<Map<String, dynamic>>> getUserLists() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/lists/user?apikey=$apiKey'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[MDBlist] Get lists error: $e');
    }
    return [];
  }

  /// Get items in a specific list by list ID.
  Future<List<Map<String, dynamic>>> getListItems(int listId) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/lists/$listId/items?apikey=$apiKey'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[MDBlist] Get list items error: $e');
    }
    return [];
  }

  /// Remove an item from a user list.
  Future<bool> removeFromList({
    required int listId,
    String? imdbId,
    int? tmdbId,
    String? mediaType,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return false;
    if (imdbId == null && tmdbId == null) return false;

    final body = <String, dynamic>{};
    if (imdbId != null) body['imdb_id'] = imdbId;
    if (tmdbId != null) body['tmdb_id'] = tmdbId;
    if (mediaType != null) {
      body['mediatype'] = (mediaType == 'tv' || mediaType == 'series') ? 'show' : 'movie';
    }

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/lists/$listId/items/remove?apikey=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode([body]),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[MDBlist] Remove from list error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  T O P   L I S T S   ( P U B L I C )
  // ═══════════════════════════════════════════════════════════════════════

  /// Get top/popular lists from MDBlist.
  Future<List<Map<String, dynamic>>> getTopLists() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/lists/top?apikey=$apiKey'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[MDBlist] Get top lists error: $e');
    }
    return [];
  }
}
