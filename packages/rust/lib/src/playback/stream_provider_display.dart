/// Player-facing labels for built-in web stream providers.
///
/// Settings, extraction, and the in-player Servers menu all use real provider
/// names. [flagForCountry] remains for torrent language filters only.
class StreamProviderDisplay {
  const StreamProviderDisplay._();

  static const _labels = <String, String>{
    'videasy': 'Videasy',
    'vidsrc': 'Vidsrc',
    'vidnest': 'Vidnest',
    'vidlink': 'VidLink',
    'vixsrc': 'VixSrc',
    'vidzee': 'Vidzee',
    'vidrock': 'VidRock',
    'vidfast': 'VidFast',
    '2embed': '2Embed',
    'superembed': 'SuperEmbed',
    'autoembed': 'AutoEmbed',
    '111movies': '111Movies',
    'moviesapi': 'MoviesAPI',
    'smashystream': 'SmashyStream',
    'primewire': 'PrimeWire',
    'service111477': '111477',
    'webstreamr': 'WebStreamr',
    'stremio_direct': 'Stremio Direct',
    'amri': 'Amri',
    'arabic': 'Arabic',
    'kisskh': 'KissKH',
    'torrent': 'Torrent',
  };

  /// Language/country flags for torrent release metadata — not server labels.
  static const _flags = <String, String>{
    'multi': '🌐',
    'al': '🇦🇱',
    'ar': '🇸🇦',
    'de': '🇩🇪',
    'en': '🇺🇸',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'hi': '🇮🇳',
    'it': '🇮🇹',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'mx': '🇲🇽',
    'pt': '🇧🇷',
    'ru': '🇷🇺',
    'th': '🇹🇭',
    'zh': '🇨🇳',
  };

  static String canonicalId(String providerId) {
    if (providerId.startsWith('nuvio:')) {
      return providerId.substring(6);
    }
    return providerId;
  }

  static bool hasProfile(String providerId) =>
      _labels.containsKey(canonicalId(providerId));

  static String playerLabel(
    String providerId, {
    String? fallbackName,
    List<String>? contentLanguage,
  }) {
    final canonical = canonicalId(providerId);
    final label = _labels[canonical];
    if (label != null) return label;
    if (fallbackName != null && fallbackName.isNotEmpty) return fallbackName;
    return _titleCaseId(canonical);
  }

  static String flagForCountry(String code) => _flags[code] ?? '';

  static String playerListLabel(
    String providerId, {
    String? fallbackName,
    List<String>? contentLanguage,
  }) {
    return playerLabel(
      providerId,
      fallbackName: fallbackName,
      contentLanguage: contentLanguage,
    );
  }

  static String _titleCaseId(String id) {
    if (id.isEmpty) return id;
    return id
        .split(RegExp(r'[-_]'))
        .where((p) => p.isNotEmpty)
        .map((part) {
          if (part.toLowerCase() == 'tv') return 'TV';
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }
}
