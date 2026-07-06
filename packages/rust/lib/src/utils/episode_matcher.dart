import 'dart:convert';

import '../engine.dart';

class EpisodeMatcher {
  static bool matches(String filename, int season, int episode) {
    if (!RustLib.isInitialized) {
      throw StateError('Engine not initialized');
    }
    return RustLib.instance.episodeMatches(filename, season, episode);
  }

  static T? pickEpisode<T>(
    List<T> files,
    int season,
    int episode, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    if (!RustLib.isInitialized) {
      throw StateError('Engine not initialized');
    }
    final entries = [
      for (final f in files) {'name': name(f), 'size': size(f)},
    ];
    final idx = RustLib.instance.pickEpisodeIndexJson(
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
    if (!RustLib.isInitialized) {
      throw StateError('Engine not initialized');
    }
    final entries = [
      for (final f in files) {'name': name(f), 'size': size(f)},
    ];
    final idx =
        RustLib.instance.pickLargestVideoIndexJson(jsonEncode(entries));
    if (idx < 0 || idx >= files.length) return null;
    return files[idx];
  }
}
