class StreamProviders {
  static final Map<String, dynamic> providers = {
    // 111477.xyz direct file index — highest priority. Resolved via
    // Site111477Service (TMDB title → file URL) and streamed through the
    // local seekable proxy. Movie/tv URL lambdas are intentionally null;
    // the player layer special-cases this provider and looks up the URL
    // from the Movie object instead of a static template.
    'service111477': {
      'name': '111477.xyz',
      'movie': null,
      'tv': null,
    },
    // WebStreamr (local on-device port). Special-cased like service111477.
    'webstreamr': {
      'name': 'WebStreamr',
      'movie': null,
      'tv': null,
    },
    'vidlink': {
      'name': 'VidLink',
      'movie': (tmdbId) => 'https://vidlink.pro/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://vidlink.pro/tv/$tmdbId/$s/$e',
    },
    'vixsrc': {
      'name': 'VixSrc',
      'movie': (tmdbId) => 'https://vixsrc.to/movie/$tmdbId/',
      'tv': (tmdbId, s, e) => 'https://vixsrc.to/tv/$tmdbId/$s/$e/',
    },
    'vidnest': {
      'name': 'VidNest',
      'movie': (tmdbId) => 'https://vidnest.fun/movie/$tmdbId',
      'tv': (tmdbId, s, e) => 'https://vidnest.fun/tv/$tmdbId/$s/$e',
    },
    // Videasy (player.videasy.net) — uses a dedicated extractor that hooks
    // into the page's own WASM-based decryption pipeline. Special-cased in
    // the player screens like service111477/webstreamr.
    'videasy': {
      'name': 'Videasy',
      'movie': null,
      'tv': null,
    },
    // Vidsrc (vsembed.ru / vidsrc-embed.ru) — outer embed wraps an inner
    // cloudnestra iframe that the generic web sniffer can crack. Special-
    // cased so the player layer calls VidsrcExtractor instead of feeding
    // the embed URL straight to StreamExtractor.
    'vidsrc': {
      'name': 'Vidsrc',
      'movie': null,
      'tv': null,
    },
  };
}
