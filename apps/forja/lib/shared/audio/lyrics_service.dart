import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';

class LyricLine {
  final Duration startTime;
  final String text;

  LyricLine({required this.startTime, required this.text});

  Map<String, dynamic> toJson() => {
        'startTimeMs': startTime.inMilliseconds,
        'text': text,
      };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        startTime: Duration(milliseconds: json['startTimeMs'] as int),
        text: json['text'] as String,
      );
}

class LyricsService {
  Future<List<LyricLine>?> getSyncedLyrics({
    required String trackName,
    required String artistName,
    required String albumName,
    required int durationSeconds,
  }) async {
    try {
      final decoded = await metadataRequest({
        'action': 'synced_lyrics',
        'track_name': trackName,
        'artist_name': artistName,
        'album_name': albumName,
        'duration_seconds': durationSeconds,
      });
      final lines = decoded['lines'] as List<dynamic>? ?? [];
      if (lines.isEmpty) return null;
      return lines
          .map(
            (e) => LyricLine(
              startTime: Duration(
                milliseconds: (e['start_time_ms'] as num?)?.toInt() ?? 0,
              ),
              text: e['text'] as String? ?? '',
            ),
          )
          .where((l) => l.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('LyricsService: Error fetching lyrics: $e');
      return null;
    }
  }

  Future<void> saveLyrics(MusicTrack track, List<LyricLine> lyrics) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final lyricsDir = Directory('${dir.path}/lyrics');
      if (!await lyricsDir.exists()) await lyricsDir.create(recursive: true);

      final file = File('${lyricsDir.path}/${track.id}.json');
      final data = lyrics.map((l) => l.toJson()).toList();
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('LyricsService: Error saving local lyrics: $e');
    }
  }

  Future<List<LyricLine>?> getLocalLyrics(MusicTrack track) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lyrics/${track.id}.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = json.decode(content) as List;
        return list
            .map((item) => LyricLine.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('LyricsService: Error reading local lyrics: $e');
    }
    return null;
  }
}
