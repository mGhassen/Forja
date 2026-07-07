import 'dart:convert';

import 'isolate_runner.dart';

Future<Map<String, dynamic>> musicRequest(Map<String, dynamic> payload) async {
  final raw = await runMusicRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
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
