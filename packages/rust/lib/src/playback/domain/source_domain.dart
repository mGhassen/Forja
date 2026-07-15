/// Content ecosystems — providers compete only inside one domain.
enum SourceDomain {
  movies,
  series,
  anime,
  asianDrama,
  iptv,
  torrent;

  String get id => switch (this) {
    SourceDomain.movies => 'movies',
    SourceDomain.series => 'series',
    SourceDomain.anime => 'anime',
    SourceDomain.asianDrama => 'asian_drama',
    SourceDomain.iptv => 'iptv',
    SourceDomain.torrent => 'torrent',
  };

  static SourceDomain? tryParse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'movies':
      case 'movie':
        return SourceDomain.movies;
      case 'series':
      case 'tv':
      case 'show':
        return SourceDomain.series;
      case 'anime':
        return SourceDomain.anime;
      case 'asian_drama':
      case 'asian':
      case 'drama':
        return SourceDomain.asianDrama;
      case 'iptv':
        return SourceDomain.iptv;
      case 'torrent':
        return SourceDomain.torrent;
      default:
        return null;
    }
  }

  /// TMDB-style media type → movie/series domain.
  static SourceDomain fromMediaType(String? mediaType) {
    final t = (mediaType ?? '').toLowerCase();
    if (t == 'tv' || t == 'series' || t == 'show') {
      return SourceDomain.series;
    }
    return SourceDomain.movies;
  }
}

/// Domain-scoped priority for one scraper/provider.
/// Priority `0` (or missing) = unsupported in that domain.
class ProviderProfile {
  const ProviderProfile({required this.id, required this.priority});

  final String id;

  /// Higher = preferred within that domain.
  final Map<SourceDomain, int> priority;

  bool supports(SourceDomain domain) => (priority[domain] ?? 0) > 0;

  int scoreFor(SourceDomain domain) => priority[domain] ?? 0;
}
