import 'dart:convert';

import '../engine.dart';

class EpisodeMatcher {
  static bool matches(String filename, int season, int episode) {
    if (!ForjaRust.isInitialized) {
      throw StateError('ForjaEngine not initialized');
    }
    return ForjaRust.instance.episodeMatches(filename, season, episode);
  }

  static T? pickEpisode<T>(
    List<T> files,
    int season,
    int episode, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    if (!ForjaRust.isInitialized) {
      throw StateError('ForjaEngine not initialized');
    }
    final entries = [
      for (final f in files) {'name': name(f), 'size': size(f)},
    ];
    final idx = ForjaRust.instance.pickEpisodeIndexJson(
      jsonEncode(entries),
      season,
      episode,
    );
    if (idx < 0 || idx >= files.length) return null;
    return files[idx];
  }

  static T? pickLargestVideo<T>(
    List<T> files, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    if (!ForjaRust.isInitialized) {
      throw StateError('ForjaEngine not initialized');
    }
    final entries = [
      for (final f in files) {'name': name(f), 'size': size(f)},
    ];
    final idx =
        ForjaRust.instance.pickLargestVideoIndexJson(jsonEncode(entries));
    if (idx < 0 || idx >= files.length) return null;
    return files[idx];
  }
}
