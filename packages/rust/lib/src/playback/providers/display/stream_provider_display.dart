/// Player-facing labels for built-in web stream providers.
///
/// Settings, extraction, and the in-player Servers menu all use real provider
/// names (no region flags on server rows). [flagForCountry] / [flagsForText]
/// are for torrent filters and **stream** row language badges.
class StreamProviderDisplay {
  const StreamProviderDisplay._();

  static const _labels = <String, String>{
    'videasy': 'Videasy',
    'vidsrc': 'VSEmbed',
    'vidsrcwin': 'VidSrc',
    'vidnest': 'Vidnest',
    'vidlink': 'VidLink',
    'vixsrc': 'VixSrc',
    'vidzee': 'Vidzee',
    'vidrock': 'VidRock',
    'vidfast': 'VidFast',
    '2embed': '2Embed',
    'autoembed': 'AutoEmbed',
    'vidlove': 'VidLove',
    'vidsrcsbs': 'VidSrc.sbs',
    '111movies': '111Movies',
    'moviesapi': 'MoviesAPI',
    'vidapi': 'VidAPI',
    'service111477': '111477',
    'webstreamr': 'WebStreamr',
    'stremio_direct': 'Stremio Direct',
    'amri': 'Amri',
    'arabic': 'Arabic',
    'kisskh': 'KissKH',
    'kisskh.co': 'KissKH',
    'kisskh.nl': 'kisskh.nl',
    'kisskh.ovh': 'kisskh.ovh',
    'kisskh.la': 'kisskh.la',
    'kisskh.do': 'kisskh.do',
    'torrent': 'Torrent',
  };

  /// Language/country flag emoji keyed by country/language code.
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
    'latino': 'mx',
    'fr': 'fr',
    'french': 'fr',
    'vostfr': 'fr',
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

  static final RegExp _flagEmojiRe = RegExp(
    r'(?:🌐|[\u{1F1E6}-\u{1F1FF}]{2})',
    unicode: true,
  );

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

  /// Flags already present in [text] (globe / regional-indicator pairs).
  static List<String> extractFlagEmojis(String text) {
    final out = <String>[];
    for (final m in _flagEmojiRe.allMatches(text)) {
      final f = m.group(0)!;
      if (!out.contains(f)) out.add(f);
    }
    return out;
  }

  /// Country codes inferred from language tokens in [text].
  static List<String> languageCodesFromText(String text) {
    final n = ' ${text.toUpperCase()} ';
    final out = <String>[];
    void add(String code) {
      if (!out.contains(code)) out.add(code);
    }

    if (n.contains('MULTI') ||
        n.contains('DUAL AUDIO') ||
        n.contains('DUAL-AUDIO')) {
      add('multi');
    }

    for (final entry in _languageToCountry.entries) {
      final token = entry.key.toUpperCase();
      if (token.length <= 2) {
        // Short codes: require word-ish boundaries.
        if (n.contains(' $token ') ||
            n.contains('.$token.') ||
            n.contains('[$token]') ||
            n.contains('-$token-')) {
          add(entry.value);
        }
      } else if (n.contains(token)) {
        add(entry.value);
      }
      if (out.length >= 3) break;
    }
    return out;
  }

  /// Flag emoji string for a stream title — prefers emoji already in the text,
  /// otherwise maps detected language tokens via [flagForCountry].
  static String flagsForText(String text) {
    final existing = extractFlagEmojis(text);
    if (existing.isNotEmpty) return existing.join(' ');
    return languageCodesFromText(
      text,
    ).map(flagForCountry).where((f) => f.isNotEmpty).join(' ');
  }

  /// Server list label — name only (flags belong on stream rows).
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
