import '../../domain/source_domain.dart';

/// Optional known-id hints for Settings / panel domain heuristics.
///
/// Movie/TV embed sniff profiles were removed — engine plugins are not listed
/// here. Unknown ids use [fallback] (score 1 on every domain).
abstract final class ProviderProfiles {
  static const _animeOrder = <String>[
    'megaplay',
    'anikoto',
    'vidnest:hianime',
    'vidnest:animepahe',
    'allanime:Default',
    'allanime:Yt-mp4',
    'allanime:S-mp4',
    'allanime:Luf-Mp4',
    'miruro:bee',
    'miruro:zoro',
    'miruro:kiwi',
    'miruro:ally',
    'miruro:hop',
    'miruro:bonk',
    'miruro:moo',
    'miruro:animedunya',
    'miruro:arc',
    'miruro:jet',
    'miruro:bun',
    'miruro:kuz',
    'miruro:telli',
    'watchhentai',
    'hentaini',
  ];

  static final Map<String, ProviderProfile> catalog = {
    ..._profilesFromOrder(_animeOrder, SourceDomain.anime, start: 100),
    ..._profilesFromOrder(
      const [
        'kisskh.co',
        'kisskh.nl',
        'kisskh.ovh',
        'kisskh.la',
        'kisskh.do',
        'kisskh.is',
        'kisskh.id',
      ],
      SourceDomain.asianDrama,
      start: 99,
    ),
    'kisskh': const ProviderProfile(
      id: 'kisskh',
      priority: {SourceDomain.asianDrama: 99, SourceDomain.anime: 40},
    ),
    'xtream': const ProviderProfile(
      id: 'xtream',
      priority: {SourceDomain.iptv: 95},
    ),
    'm3u': const ProviderProfile(id: 'm3u', priority: {SourceDomain.iptv: 80}),
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
      out[id] = ProviderProfile(id: id, priority: {domain: score});
    }
    return out;
  }

  static ProviderProfile? of(String id) => catalog[id];

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
