import 'package:flutter/foundation.dart';

import '../music_http.dart';

class MusicService {
  final Map<String, String> _videoIdCache = {};
  final Map<String, String> _streamUrlCache = {};

  Future<List<MusicTrack>> searchTracks(String query) async {
    try {
      final decoded = await musicRequest({'action': 'search_tracks', 'q': query});
      return parseMusicTracks(decoded);
    } catch (e) {
      debugPrint('MusicService: searchTracks failed: $e');
      return [];
    }
  }

  Future<List<MusicTrack>> getTrendingTracks({
    int index = 0,
    int limit = 20,
  }) async {
    try {
      final decoded = await musicRequest({
        'action': 'trending_tracks',
        'index': index,
        'limit': limit,
      });
      return parseMusicTracks(decoded);
    } catch (e) {
      debugPrint('MusicService: getTrendingTracks failed: $e');
      return [];
    }
  }

  Future<List<MusicAlbum>> searchAlbums(String query) async {
    try {
      final decoded = await musicRequest({'action': 'search_albums', 'q': query});
      return parseMusicAlbums(decoded);
    } catch (e) {
      debugPrint('MusicService: searchAlbums failed: $e');
      return [];
    }
  }

  Future<List<MusicTrack>> getAlbumTracks(String albumId) async {
    try {
      final decoded = await musicRequest({
        'action': 'album_tracks',
        'album_id': albumId,
      });
      return parseMusicTracks(decoded);
    } catch (e) {
      debugPrint('MusicService: getAlbumTracks failed: $e');
      return [];
    }
  }

  Future<List<MusicTrack>> getRelatedTracks(String trackId) async {
    try {
      final decoded = await musicRequest({
        'action': 'related_tracks',
        'track_id': trackId,
      });
      return parseMusicTracks(decoded);
    } catch (e) {
      debugPrint('MusicService: getRelatedTracks failed: $e');
      return [];
    }
  }

  Future<String?> getYoutubeVideoId(String title, String artist) async {
    final cacheKey = '$title|$artist';
    final cached = _videoIdCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final decoded = await musicRequest({
        'action': 'youtube_search_video_id',
        'title': title,
        'artist': artist,
      });
      final id = decoded['video_id'] as String?;
      if (id != null && id.isNotEmpty) {
        _videoIdCache[cacheKey] = id;
      }
      return id;
    } catch (e) {
      debugPrint('MusicService: getYoutubeVideoId failed: $e');
      return null;
    }
  }

  Future<String?> getYoutubeStreamUrl(String videoId) async {
    final cached = _streamUrlCache[videoId];
    if (cached != null) {
      return cached;
    }

    try {
      final decoded = await musicRequest({
        'action': 'youtube_audio_url',
        'video_id': videoId,
      });
      final url = decoded['url'] as String?;
      if (url != null && url.isNotEmpty) {
        _streamUrlCache[videoId] = url;
      }
      return url;
    } catch (e) {
      debugPrint('MusicService: getYoutubeStreamUrl failed: $e');
      return null;
    }
  }

  void dispose() {}
}
