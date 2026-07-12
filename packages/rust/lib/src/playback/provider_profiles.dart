import 'source_domain.dart';

/// Built-in provider profiles — domain priority tables.
///
/// Settings order is a tiebreak only; cross-domain providers never compete.
abstract final class ProviderProfiles {
  static const Map<String, ProviderProfile> catalog = {
    // ── Movie / series webstreaming ───────────────────────────────────────
    'videasy': ProviderProfile(
      id: 'videasy',
      priority: {
        SourceDomain.movies: 95,
        SourceDomain.series: 90,
      },
    ),
    'vidlink': ProviderProfile(
      id: 'vidlink',
      priority: {
        SourceDomain.movies: 80,
        SourceDomain.series: 92,
      },
    ),
    'vidsrc': ProviderProfile(
      id: 'vidsrc',
      priority: {
        SourceDomain.movies: 70,
        SourceDomain.series: 70,
      },
    ),
    'vixsrc': ProviderProfile(
      id: 'vixsrc',
      priority: {
        SourceDomain.movies: 75,
        SourceDomain.series: 75,
      },
    ),
    'vidnest': ProviderProfile(
      id: 'vidnest',
      priority: {
        SourceDomain.movies: 65,
        SourceDomain.series: 65,
      },
    ),
    'vidzee': ProviderProfile(
      id: 'vidzee',
      priority: {
        SourceDomain.movies: 60,
        SourceDomain.series: 60,
      },
    ),
    'vidrock': ProviderProfile(
      id: 'vidrock',
      priority: {
        SourceDomain.movies: 55,
        SourceDomain.series: 55,
      },
    ),
    'service111477': ProviderProfile(
      id: 'service111477',
      priority: {
        SourceDomain.movies: 85,
        SourceDomain.series: 85,
      },
    ),
    'webstreamr': ProviderProfile(
      id: 'webstreamr',
      priority: {
        SourceDomain.movies: 50,
        SourceDomain.series: 50,
      },
    ),

    // ── Anime (keys match AnimeStreamProviders) ────────────────────────────
    'miruro:bee': ProviderProfile(
      id: 'miruro:bee',
      priority: {SourceDomain.anime: 100},
    ),
    'allanime:Default': ProviderProfile(
      id: 'allanime:Default',
      priority: {SourceDomain.anime: 95},
    ),
    'allanime:S-mp4': ProviderProfile(
      id: 'allanime:S-mp4',
      priority: {SourceDomain.anime: 93},
    ),
    'megaplay': ProviderProfile(
      id: 'megaplay',
      priority: {SourceDomain.anime: 90},
    ),
    'vidwish': ProviderProfile(
      id: 'vidwish',
      priority: {SourceDomain.anime: 88},
    ),
    'miruro:zoro': ProviderProfile(
      id: 'miruro:zoro',
      priority: {SourceDomain.anime: 85},
    ),
    'animerealms:hianime': ProviderProfile(
      id: 'animerealms:hianime',
      priority: {SourceDomain.anime: 84},
    ),
    'miruro:kiwi': ProviderProfile(
      id: 'miruro:kiwi',
      priority: {SourceDomain.anime: 82},
    ),
    'animerealms:animepahe': ProviderProfile(
      id: 'animerealms:animepahe',
      priority: {SourceDomain.anime: 80},
    ),

    // ── Asian drama ───────────────────────────────────────────────────────
    'kisskh': ProviderProfile(
      id: 'kisskh',
      priority: {
        SourceDomain.asianDrama: 99,
        SourceDomain.anime: 40,
      },
    ),

    // ── IPTV / torrent ────────────────────────────────────────────────────
    'xtream': ProviderProfile(
      id: 'xtream',
      priority: {SourceDomain.iptv: 95},
    ),
    'm3u': ProviderProfile(
      id: 'm3u',
      priority: {SourceDomain.iptv: 80},
    ),
    'stalker': ProviderProfile(
      id: 'stalker',
      priority: {SourceDomain.iptv: 70},
    ),
    'torrent': ProviderProfile(
      id: 'torrent',
      priority: {SourceDomain.torrent: 100},
    ),
  };

  static ProviderProfile? of(String id) => catalog[id];

  /// Unknown ids still participate if present in the candidate map —
  /// default priority uses settings order only (score 1).
  static ProviderProfile fallback(String id) => ProviderProfile(
        id: id,
        priority: {
          SourceDomain.movies: 1,
          SourceDomain.series: 1,
          SourceDomain.anime: 1,
          SourceDomain.asianDrama: 1,
          SourceDomain.iptv: 1,
          SourceDomain.torrent: 1,
        },
      );

  static ProviderProfile resolve(String id) => of(id) ?? fallback(id);
}
