/// Player-facing labels for built-in web stream providers.
///
/// Settings, extraction, and the in-player Servers menu all use real provider
/// names. Region flags still come from profiles / contentLanguage.
class StreamProviderDisplay {
  const StreamProviderDisplay._();

  static const _profiles = <String, ({String label, List<String> countries})>{
    'videasy': (label: 'Videasy', countries: ['multi']),
    'vidsrc': (label: 'Vidsrc', countries: ['multi']),
    'vidnest': (label: 'Vidnest', countries: ['multi']),
    'vidlink': (label: 'VidLink', countries: ['multi']),
    'vixsrc': (label: 'VixSrc', countries: ['multi']),
    'vidzee': (label: 'Vidzee', countries: ['multi']),
    'vidrock': (label: 'VidRock', countries: ['multi']),
    'service111477': (label: '111477', countries: ['en']),
    'webstreamr': (label: 'WebStreamr', countries: ['multi']),
    'vidfast': (label: 'VidFast', countries: ['multi']),
    'stremio_direct': (label: 'Stremio Direct', countries: ['multi']),
    'amri': (label: 'Amri', countries: ['multi']),
    'arabic': (label: 'Arabic', countries: ['ar']),
    'kisskh': (label: 'KissKH', countries: ['ko']),
    'torrent': (label: 'Torrent', countries: ['multi']),
  };

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

  static const _languageToCountry = <String, String>{
    'multi': 'multi',
    'en': 'en',
    'english': 'en',
    'es': 'es',
    'spanish': 'es',
    'fr': 'fr',
    'french': 'fr',
    'de': 'de',
    'german': 'de',
    'it': 'it',
    'ita': 'it',
    'italian': 'it',
    'ja': 'ja',
    'japanese': 'ja',
    'ko': 'ko',
    'korean': 'ko',
    'zh': 'zh',
    'ch': 'zh',
    'chinese': 'zh',
    'hi': 'hi',
    'hindi': 'hi',
    'ta': 'hi',
    'te': 'hi',
    'ml': 'hi',
    'pa': 'hi',
    'gu': 'hi',
    'ba': 'hi',
    'ar': 'ar',
    'arabic': 'ar',
    'pt': 'pt',
    'portuguese': 'pt',
    'ru': 'ru',
    'russian': 'ru',
    'th': 'th',
    'thai': 'th',
  };

  static String canonicalId(String providerId) {
    if (providerId.startsWith('nuvio:')) {
      return providerId.substring(6);
    }
    return providerId;
  }

  static bool hasProfile(String providerId) =>
      _profiles.containsKey(canonicalId(providerId));

  static String playerLabel(
    String providerId, {
    String? fallbackName,
    List<String>? contentLanguage,
  }) {
    final canonical = canonicalId(providerId);
    final profile = _profiles[canonical];
    if (profile != null) return profile.label;
    if (fallbackName != null && fallbackName.isNotEmpty) return fallbackName;
    return _titleCaseId(canonical);
  }

  static List<String> countryCodes(
    String providerId, {
    List<String>? contentLanguage,
  }) {
    final canonical = canonicalId(providerId);
    final profile = _profiles[canonical];
    if (profile != null) return profile.countries;
    final fromLang = _countriesFromLanguages(contentLanguage);
    if (fromLang.isNotEmpty) return fromLang;
    return const ['multi'];
  }

  static String countryFlags(
    String providerId, {
    List<String>? contentLanguage,
  }) {
    return countryCodes(providerId, contentLanguage: contentLanguage)
        .map(flagForCountry)
        .where((f) => f.isNotEmpty)
        .join(' ');
  }

  static String flagForCountry(String code) => _flags[code] ?? '';

  static String playerListLabel(
    String providerId, {
    String? fallbackName,
    List<String>? contentLanguage,
  }) {
    final flags = countryFlags(providerId, contentLanguage: contentLanguage);
    final label = playerLabel(
      providerId,
      fallbackName: fallbackName,
      contentLanguage: contentLanguage,
    );
    if (flags.isEmpty) return label;
    return '$flags $label';
  }

  static List<String> _countriesFromLanguages(List<String>? languages) {
    if (languages == null || languages.isEmpty) return const [];
    final out = <String>[];
    for (final raw in languages) {
      final cc = _languageToCountry[raw.toLowerCase()];
      if (cc == null || out.contains(cc)) continue;
      out.add(cc);
      if (out.length >= 3) break;
    }
    return out;
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
