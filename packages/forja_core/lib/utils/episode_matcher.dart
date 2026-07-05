/// Robust season/episode → filename matcher.
///
/// Handles the common scene/release naming schemes:
///   * `Show.S03E07.1080p.mkv`        — SxxExx (zero-padded or not)
///   * `Show.s3e7.WEB-DL.mkv`         — lowercase
///   * `Show.S03.E07.mkv`             — separator between S and E
///   * `Show.S03 E07.mkv`             — space separator
///   * `Show.3x07.HDTV.mkv`           — old-school NxNN
///   * `Show.Season 3 Episode 7.mkv`  — verbose
///
/// Also offers helpers to pick the best video file from a torrent payload:
/// `pickEpisode` for TV (matches season/episode, falls back to largest video,
/// excludes samples/extras), and `pickLargestVideo` for movies.
library;

/// Optional Rust backend hook. Set by `forja_rust` at startup.
abstract final class EpisodeMatcherBackend {
  static bool Function(String filename, int season, int episode)? matches;
}

class EpisodeMatcher {
  static bool matches(String filename, int season, int episode) {
    final backend = EpisodeMatcherBackend.matches;
    if (backend != null) return backend(filename, season, episode);
    throw StateError(
      'EpisodeMatcherBackend.matches not wired — call ForjaEngine.init()',
    );
  }

  static bool matchesEpisodeOnly(String filename, int episode) {
    final base = _basename(filename);
    if (base.isEmpty) return false;
    for (final p in _episodeOnlyPatterns) {
      for (final m in p.allMatches(base)) {
        final e = int.tryParse(m.group(1)!);
        if (e == episode) return true;
      }
    }
    return false;
  }

  static final List<RegExp> _episodeOnlyPatterns = [
    RegExp(r'(?<![a-z0-9])e(?:p|pisode)?[\s._\-]*0*(\d{1,4})(?![a-z0-9])'),
    RegExp(r'^\s*0*(\d{1,4})\s*[-._]\s*'),
  ];

  static final List<RegExp> _seasonEpisodePatterns = [
    RegExp(r's0*(\d{1,3})[\s._\-]*e0*(\d{1,4})'),
    RegExp(r'(?<![a-z0-9])0*(\d{1,3})x0*(\d{1,4})(?![a-z0-9])'),
    RegExp(r'season\s*0*(\d{1,3})\s*(?:episode|ep)\s*0*(\d{1,4})'),
  ];

  static const _videoExts = {
    '.mkv', '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v',
    '.ts', '.mpg', '.mpeg', '.m2ts', '.divx', '.vob', '.ogv',
  };

  static String _basename(String filename) {
    if (filename.isEmpty) return '';
    return filename.toLowerCase().split(RegExp(r'[\\/]')).last;
  }

  static T? pickEpisode<T>(
    List<T> files,
    int season,
    int episode, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    final videos = _onlyVideos(files, name);
    if (videos.isEmpty) return null;

    final strong =
        videos.where((f) => matches(name(f), season, episode)).toList();
    if (strong.isNotEmpty) {
      strong.sort((a, b) => size(b).compareTo(size(a)));
      return strong.first;
    }

    final hasAnyStrongMarker = videos.any((f) {
      final base = _basename(name(f));
      return _seasonEpisodePatterns.any((p) => p.hasMatch(base));
    });
    if (!hasAnyStrongMarker) {
      final epOnly =
          videos.where((f) => matchesEpisodeOnly(name(f), episode)).toList();
      if (epOnly.isNotEmpty) {
        epOnly.sort((a, b) => size(b).compareTo(size(a)));
        return epOnly.first;
      }
    }

    videos.sort((a, b) => size(b).compareTo(size(a)));
    return videos.first;
  }

  static T? pickLargestVideo<T>(
    List<T> files, {
    required String Function(T) name,
    required int Function(T) size,
  }) {
    final videos = _onlyVideos(files, name);
    if (videos.isEmpty) return null;
    videos.sort((a, b) => size(b).compareTo(size(a)));
    return videos.first;
  }

  static List<T> _onlyVideos<T>(List<T> files, String Function(T) name) {
    return files.where((f) {
      final n = name(f).toLowerCase();
      if (!_videoExts.any(n.endsWith)) return false;
      if (n.contains('sample')) return false;
      if (n.contains('featurette')) return false;
      if (n.contains('behind.the.scenes') || n.contains('behind-the-scenes')) {
        return false;
      }
      if (n.contains('/extras/') || n.contains(r'\extras\')) return false;
      return true;
    }).toList();
  }
}
