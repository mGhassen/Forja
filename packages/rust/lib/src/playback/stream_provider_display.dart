/// Player-facing labels for built-in web stream providers.
///
/// Settings and extraction still use real provider ids; only the in-player
/// Servers menu shows disguised names plus real region flags.
class StreamProviderDisplay {
  const StreamProviderDisplay._();

  static const _profiles = <String, ({String label, List<String> countries})>{
    'videasy': (label: 'Lumen', countries: ['multi']),
    'vidsrc': (label: 'Prism', countries: ['multi']),
    'vidnest': (label: 'Atlas', countries: ['multi']),
    'vidlink': (label: 'Echo', countries: ['multi']),
    'vixsrc': (label: 'Nova', countries: ['multi']),
    'vidzee': (label: 'Pulse', countries: ['multi']),
    'vidrock': (label: 'Summit', countries: ['multi']),
    'service111477': (label: 'Axis', countries: ['en']),
    'webstreamr': (label: 'Orbit', countries: ['multi']),
    'vidfast': (label: 'Quasar', countries: ['multi']),
    'stremio_direct': (label: 'Relay', countries: ['multi']),
    'amri': (label: 'Mirage', countries: ['multi']),
    'arabic': (label: 'Oasis', countries: ['ar']),
    'kisskh': (label: 'Jade', countries: ['ko']),
    'torrent': (label: 'Forge', countries: ['multi']),
  };

  static const _disguisedPool = <String>[
    'Aurora', 'Beacon', 'Canyon', 'Delta', 'Ember', 'Fjord', 'Glacier',
    'Harbor', 'Iris', 'Juniper', 'Kestrel', 'Lagoon', 'Meadow', 'Nimbus',
    'Opal', 'Pioneer', 'Quartz', 'River', 'Sage', 'Timber', 'Umber',
    'Violet', 'Willow', 'Zenith', 'Breeze', 'Coral', 'Dune', 'Elm',
    'Falcon', 'Grove', 'Haven', 'Indigo', 'Jasper', 'Kite', 'Lotus',
    'Mist', 'North', 'Olive', 'Pine', 'Quest', 'Ridge', 'Stone', 'Tide',
    'Union', 'Vale', 'Wave', 'Yarrow', 'Zephyr', 'Ash', 'Brook', 'Cedar',
    'Drift', 'Echo Bay', 'Flint', 'Glen', 'Haze', 'Ivory', 'Jade Gate',
    'Knoll', 'Lark', 'Marble', 'Nest', 'Orchid',
  ];

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
    if (providerId.startsWith('nuvio:')) {
      return _disguisedLabel(canonical);
    }
    return fallbackName ?? providerId;
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

  static String _disguisedLabel(String id) {
    var sum = 0;
    for (final unit in id.codeUnits) {
      sum = (sum + unit) % 100000;
    }
    return _disguisedPool[sum % _disguisedPool.length];
  }
}
