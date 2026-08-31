import 'package:flutter/foundation.dart';

import '../forja_platform_secure_store.dart';
import '../metadata_http.dart';

/// MDBlist integration — API-key auth, ratings aggregation, list management.
/// HTTP engine: `media-metadata/mdblist` via `metadataRequest`. API key stays in host secure storage.
class MdblistService {
  static final MdblistService _instance = MdblistService._internal();
  factory MdblistService() => _instance;
  MdblistService._internal();

  static const String _keyApiKey = 'mdblist_api_key';

  String? _cachedApiKey;

  Future<void> setApiKey(String apiKey) async {
    await ForjaPlatformSecureStore.write(_keyApiKey, apiKey);
    _cachedApiKey = apiKey;
    debugPrint('[MDBlist] API key saved.');
  }

  Future<String?> getApiKey() async {
    _cachedApiKey ??= await ForjaPlatformSecureStore.read(_keyApiKey);
    return _cachedApiKey;
  }

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> logout() async {
    await ForjaPlatformSecureStore.delete(_keyApiKey);
    _cachedApiKey = null;
    debugPrint('[MDBlist] API key removed.');
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_user_info',
        'api_key': apiKey,
      });
      return decoded['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[MDBlist] User info error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRatingsByImdb(String imdbId) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_ratings_by_imdb',
        'api_key': apiKey,
        'imdb_id': imdbId,
      });
      return decoded['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[MDBlist] Get ratings error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRatingsByTmdb(
    int tmdbId,
    String mediaType,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_ratings_by_tmdb',
        'api_key': apiKey,
        'tmdb_id': tmdbId,
        'media_type': mediaType,
      });
      return decoded['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[MDBlist] Get ratings by TMDB error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserLists() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_user_lists',
        'api_key': apiKey,
      });
      final items = decoded['items'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[MDBlist] Get lists error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getListItems(int listId) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_list_items',
        'api_key': apiKey,
        'list_id': listId,
      });
      final items = decoded['items'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[MDBlist] Get list items error: $e');
      return [];
    }
  }

  Future<bool> removeFromList({
    required int listId,
    String? imdbId,
    int? tmdbId,
    String? mediaType,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return false;
    if (imdbId == null && tmdbId == null) return false;
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_remove_from_list',
        'api_key': apiKey,
        'list_id': listId,
        'imdb_id': ?imdbId,
        'tmdb_id': ?tmdbId,
        'media_type': ?mediaType,
      });
      return decoded['ok'] == true;
    } catch (e) {
      debugPrint('[MDBlist] Remove from list error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTopLists() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];
    try {
      final decoded = await metadataRequest({
        'action': 'mdblist_top_lists',
        'api_key': apiKey,
      });
      final items = decoded['items'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[MDBlist] Get top lists error: $e');
      return [];
    }
  }
}
