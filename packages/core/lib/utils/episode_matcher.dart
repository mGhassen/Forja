/// Season/episode filename matching — Rust engine only.
library;

/// Optional Rust backend hooks. Set by `packages/rust` at startup.
abstract final class EpisodeMatcherBackend {
  static bool Function(String filename, int season, int episode)? matches;
  static int? Function(
    List<Map<String, dynamic>> files,
    int season,
    int episode,
  )? pickEpisodeIndex;
  static int? Function(List<Map<String, dynamic>> files)? pickLargestVideoIndex;
}

class EpisodeMatcher {
  static bool matches(String filename, int season, int episode) {
    final backend = EpisodeMatcherBackend.matches;
    if (backend != null) return backend(filename, season, episode);
    throw StateError(
      'EpisodeMatcherBackend.matches not wired — call ForjaEngine.init()',
    );
  }

  static T? pickEpisode<T>(
    List<T> files,
    int season,
    int episode, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    final backend = EpisodeMatcherBackend.pickEpisodeIndex;
    if (backend == null) {
      throw StateError(
        'EpisodeMatcherBackend.pickEpisodeIndex not wired — call ForjaEngine.init()',
      );
    }
    final entries = [
      for (final f in files) {'name': name(f), 'size': size(f)},
    ];
    final idx = backend(entries, season, episode);
    if (idx == null || idx < 0 || idx >= files.length) return null;
    return files[idx];
  }

  static T? pickLargestVideo<T>(
    List<T> files, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    final backend = EpisodeMatcherBackend.pickLargestVideoIndex;
    if (backend == null) {
      throw StateError(
        'EpisodeMatcherBackend.pickLargestVideoIndex not wired — call ForjaEngine.init()',
      );
    }
    final entries = [
      for (final f in files) {'name': name(f), 'size': size(f)},
    ];
    final idx = backend(entries);
    if (idx == null || idx < 0 || idx >= files.length) return null;
    return files[idx];
  }
}
