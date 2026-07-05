/// Dart reference episode filename matcher — Rust-off fallback and parity tests.
abstract final class EpisodeMatcherDart {
  static final List<RegExp> _seasonEpisodePatterns = [
    RegExp(r's0*(\d{1,3})[\s._\-]*e0*(\d{1,4})'),
    RegExp(r'(?<![a-z0-9])0*(\d{1,3})x0*(\d{1,4})(?![a-z0-9])'),
    RegExp(r'season\s*0*(\d{1,3})\s*(?:episode|ep)\s*0*(\d{1,4})'),
  ];

  static final List<RegExp> _episodeOnlyPatterns = [
    RegExp(r'(?<![a-z0-9])e(?:p|pisode)?[\s._\-]*0*(\d{1,4})(?![a-z0-9])'),
    RegExp(r'^\s*0*(\d{1,4})\s*[-._]\s*'),
  ];

  static bool matches(String filename, int season, int episode) {
    final base = _basename(filename);
    if (base.isEmpty) return false;

    for (final p in _seasonEpisodePatterns) {
      for (final m in p.allMatches(base)) {
        final s = int.tryParse(m.group(1)!);
        final e = int.tryParse(m.group(2)!);
        if (s == season && e == episode) return true;
      }
    }
    return false;
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

  static String _basename(String filename) {
    if (filename.isEmpty) return '';
    return filename.toLowerCase().split(RegExp(r'[\\/]')).last;
  }
}
