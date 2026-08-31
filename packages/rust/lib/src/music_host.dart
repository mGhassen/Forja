// Music tab archived (`crates/archive/music`) — models + [MusicService] kept for
// shared MPV/audio_handler wiring. Rust `music_request` FFI removed; YouTube resolve
// returns null until the crate is restored.

import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> _archivedMusicRequest(
  Map<String, dynamic> payload,
) async {
  throw UnimplementedError(
    'music crate archived — restore crates/archive/music + ffi_music_request_json',
  );
}

List<MusicTrack> parseMusicTracks(Map<String, dynamic> decoded) {
  final tracks = decoded['tracks'] as List<dynamic>? ?? [];
  return tracks
      .map((e) => MusicTrack.fromEngineJson(e as Map<String, dynamic>))
      .toList();
}

List<MusicAlbum> parseMusicAlbums(Map<String, dynamic> decoded) {
  final albums = decoded['albums'] as List<dynamic>? ?? [];
  return albums
      .map((e) => MusicAlbum.fromEngineJson(e as Map<String, dynamic>))
      .toList();
}

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String cover;
  final int duration;
  final String? localPath;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.cover,
    required this.duration,
    this.localPath,
  });

  factory MusicTrack.fromEngineJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? '',
      cover: json['cover'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      localPath: json['localPath'] as String?,
    );
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('artist') && json['artist'] is String) {
      return MusicTrack.fromEngineJson(json);
    }
    final artistObj = json['artist'];
    final albumObj = json['album'];

    String artistName = 'Unknown Artist';
    if (artistObj is Map) {
      artistName = artistObj['name'] ?? 'Unknown Artist';
    } else if (artistObj is String) {
      artistName = artistObj;
    }

    String albumTitle = '';
    String coverUrl = '';
    if (albumObj is Map) {
      albumTitle = albumObj['title'] ?? '';
      coverUrl = albumObj['cover_xl'] ??
          albumObj['cover_big'] ??
          albumObj['cover_medium'] ??
          albumObj['cover_small'] ??
          '';
    } else if (albumObj is String) {
      albumTitle = albumObj;
      coverUrl = json['cover'] ?? '';
    }

    return MusicTrack(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown Title',
      artist: artistName,
      album: albumTitle,
      cover: coverUrl.isNotEmpty ? coverUrl : (json['cover'] ?? ''),
      duration: json['duration'] ?? 0,
      localPath: json['localPath'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'cover': cover,
        'duration': duration,
        'localPath': localPath,
      };
}

class MusicAlbum {
  final String id;
  final String title;
  final String artist;
  final String cover;
  final int? nbTracks;

  MusicAlbum({
    required this.id,
    required this.title,
    required this.artist,
    required this.cover,
    this.nbTracks,
  });

  factory MusicAlbum.fromEngineJson(Map<String, dynamic> json) {
    return MusicAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      cover: json['cover'] as String? ?? '',
      nbTracks: (json['nb_tracks'] as num?)?.toInt(),
    );
  }

  factory MusicAlbum.fromJson(Map<String, dynamic> json) {
    final artistObj = json['artist'] ?? {};

    return MusicAlbum(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      artist: artistObj['name'] ?? 'Unknown Artist',
      cover: json['cover_xl'] ??
          json['cover_big'] ??
          json['cover_medium'] ??
          json['cover_small'] ??
          '',
      nbTracks: json['nb_tracks'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'cover': cover,
        'nbTracks': nbTracks,
      };
}

class MusicService {
  final Map<String, String> _videoIdCache = {};
  final Map<String, String> _streamUrlCache = {};

  Future<List<MusicTrack>> searchTracks(String query) async {
    try {
      final decoded = await _archivedMusicRequest({
        'action': 'search_tracks',
        'q': query,
      });
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
      final decoded = await _archivedMusicRequest({
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
      final decoded = await _archivedMusicRequest({
        'action': 'search_albums',
        'q': query,
      });
      return parseMusicAlbums(decoded);
    } catch (e) {
      debugPrint('MusicService: searchAlbums failed: $e');
      return [];
    }
  }

  Future<List<MusicTrack>> getAlbumTracks(String albumId) async {
    try {
      final decoded = await _archivedMusicRequest({
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
      final decoded = await _archivedMusicRequest({
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
      final decoded = await _archivedMusicRequest({
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
      final decoded = await _archivedMusicRequest({
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
