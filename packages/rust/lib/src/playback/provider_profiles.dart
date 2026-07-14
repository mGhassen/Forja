import 'source_domain.dart';

/// Built-in provider profiles — domain priority tables.
///
/// Settings order is a tiebreak only; cross-domain providers never compete.
abstract final class ProviderProfiles {
  /// Mirrors `AnimeStreamProviders.defaultOrder` in the host app.
  static const _animeOrder = <String>[
    'miruro:bee',
    'allanime:Default',
    'allanime:S-mp4',
    'megaplay',
    'vidwish',
    'miruro:zoro',
    'animerealms:hianime',
    'miruro:kiwi',
    'animerealms:animepahe',
    'allanime:Yt-mp4',
    'allanime:Luf-Mp4',
    'allanime:Uv-mp4',
    'miruro:ally',
    'animerealms:allmanga',
    'miruro:hop',
    'miruro:bonk',
    'animerealms:gogoanime',
    'miruro:moo',
    'animerealms:zencloud',
    'animerealms:animekai',
    'animerealms:animez',
    'animerealms:kickassanime',
    'animerealms:anizone',
    'animerealms:febbox',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    'animerealms:hanime-tv',
    'watchhentai',
    'hentaini',
  ];

  static final Map<String, ProviderProfile> catalog = {
    // ── Movie / series webstreaming ───────────────────────────────────────
    'videasy': const ProviderProfile(
      id: 'videasy',
      priority: {
        SourceDomain.movies: 95,
        SourceDomain.series: 90,
      },
    ),
    'vidlink': const ProviderProfile(
      id: 'vidlink',
      priority: {
        SourceDomain.movies: 80,
        SourceDomain.series: 92,
      },
    ),
    'vidsrc': const ProviderProfile(
      id: 'vidsrc',
      priority: {
        SourceDomain.movies: 70,
        SourceDomain.series: 70,
      },
    ),
    'vixsrc': const ProviderProfile(
      id: 'vixsrc',
      priority: {
        SourceDomain.movies: 75,
        SourceDomain.series: 75,
      },
    ),
    'vidnest': const ProviderProfile(
      id: 'vidnest',
      priority: {
        SourceDomain.movies: 65,
        SourceDomain.series: 65,
      },
    ),
    'vidzee': const ProviderProfile(
      id: 'vidzee',
      priority: {
        SourceDomain.movies: 60,
        SourceDomain.series: 60,
      },
    ),
    'vidrock': const ProviderProfile(
      id: 'vidrock',
      priority: {
        SourceDomain.movies: 55,
        SourceDomain.series: 55,
      },
    ),
    'vidfast': const ProviderProfile(
      id: 'vidfast',
      priority: {
        SourceDomain.movies: 58,
        SourceDomain.series: 58,
      },
    ),
    '2embed': const ProviderProfile(
      id: '2embed',
      priority: {
        SourceDomain.movies: 57,
        SourceDomain.series: 57,
      },
    ),
    'superembed': const ProviderProfile(
      id: 'superembed',
      priority: {
        SourceDomain.movies: 56,
        SourceDomain.series: 56,
      },
    ),
    'autoembed': const ProviderProfile(
      id: 'autoembed',
      priority: {
        SourceDomain.movies: 55,
        SourceDomain.series: 55,
      },
    ),
    'vidlove': const ProviderProfile(
      id: 'vidlove',
      priority: {
        SourceDomain.movies: 54,
        SourceDomain.series: 54,
      },
    ),
    'vidsrcsbs': const ProviderProfile(
      id: 'vidsrcsbs',
      priority: {
        SourceDomain.movies: 52,
        SourceDomain.series: 52,
      },
    ),
    '111movies': const ProviderProfile(
      id: '111movies',
      priority: {
        SourceDomain.movies: 54,
        SourceDomain.series: 54,
      },
    ),
    'moviesapi': const ProviderProfile(
      id: 'moviesapi',
      priority: {
        SourceDomain.movies: 53,
        SourceDomain.series: 53,
      },
    ),
    'smashystream': const ProviderProfile(
      id: 'smashystream',
      priority: {
        SourceDomain.movies: 46,
        SourceDomain.series: 62,
      },
    ),
    'primewire': const ProviderProfile(
      id: 'primewire',
      priority: {
        SourceDomain.movies: 48,
        SourceDomain.series: 48,
      },
    ),
    'service111477': const ProviderProfile(
      id: 'service111477',
      priority: {
        SourceDomain.movies: 85,
        SourceDomain.series: 85,
      },
    ),
    'webstreamr': const ProviderProfile(
      id: 'webstreamr',
      priority: {
        SourceDomain.movies: 50,
        SourceDomain.series: 50,
      },
    ),

    // ── Anime ─────────────────────────────────────────────────────────────
    ..._profilesFromOrder(_animeOrder, SourceDomain.anime, start: 100),

    // ── Asian drama ───────────────────────────────────────────────────────
    'kisskh': const ProviderProfile(
      id: 'kisskh',
      priority: {
        SourceDomain.asianDrama: 99,
        SourceDomain.anime: 40,
      },
    ),

    // ── IPTV / torrent ────────────────────────────────────────────────────
    'xtream': const ProviderProfile(
      id: 'xtream',
      priority: {SourceDomain.iptv: 95},
    ),
    'm3u': const ProviderProfile(
      id: 'm3u',
      priority: {SourceDomain.iptv: 80},
    ),
    'stalker': const ProviderProfile(
      id: 'stalker',
      priority: {SourceDomain.iptv: 70},
    ),
    'torrent': const ProviderProfile(
      id: 'torrent',
      priority: {SourceDomain.torrent: 100},
    ),
  };

  static Map<String, ProviderProfile> _profilesFromOrder(
    List<String> order,
    SourceDomain domain, {
    required int start,
  }) {
    final out = <String, ProviderProfile>{};
    for (var i = 0; i < order.length; i++) {
      final id = order[i];
      final score = (start - i).clamp(1, start);
      out[id] = ProviderProfile(
        id: id,
        priority: {domain: score},
      );
    }
    return out;
  }

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
