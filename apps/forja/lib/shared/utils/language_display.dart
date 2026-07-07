/// Maps short ISO-639 language codes (and a few common variants) to a
/// human-readable display name. Used by the subtitle picker to render
/// language "folders".
const Map<String, String> _kLanguageNames = {
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'pt-br': 'Portuguese (Brazil)',
  'ru': 'Russian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'zh': 'Chinese',
  'zh-cn': 'Chinese (Simplified)',
  'zh-tw': 'Chinese (Traditional)',
  'ar': 'Arabic',
  'tr': 'Turkish',
  'pl': 'Polish',
  'nl': 'Dutch',
  'sv': 'Swedish',
  'da': 'Danish',
  'no': 'Norwegian',
  'nb': 'Norwegian Bokmål',
  'nn': 'Norwegian Nynorsk',
  'fi': 'Finnish',
  'cs': 'Czech',
  'el': 'Greek',
  'he': 'Hebrew',
  'iw': 'Hebrew',
  'hi': 'Hindi',
  'id': 'Indonesian',
  'in': 'Indonesian',
  'vi': 'Vietnamese',
  'th': 'Thai',
  'ro': 'Romanian',
  'hu': 'Hungarian',
  'uk': 'Ukrainian',
  'bg': 'Bulgarian',
  'hr': 'Croatian',
  'sr': 'Serbian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'et': 'Estonian',
  'lv': 'Latvian',
  'lt': 'Lithuanian',
  'ms': 'Malay',
  'fa': 'Persian',
  'bn': 'Bengali',
  'ta': 'Tamil',
  'te': 'Telugu',
  'ur': 'Urdu',
  'jv': 'Javanese',
  'jw': 'Javanese',
  'ca': 'Catalan',
  'eu': 'Basque',
  'gl': 'Galician',
  'sq': 'Albanian',
  'mk': 'Macedonian',
  'bs': 'Bosnian',
  'is': 'Icelandic',
  'mt': 'Maltese',
  'ga': 'Irish',
  'cy': 'Welsh',
  'af': 'Afrikaans',
  'sw': 'Swahili',
  'fil': 'Filipino',
  'tl': 'Tagalog',
  'my': 'Burmese',
  'km': 'Khmer',
  'lo': 'Lao',
  'mn': 'Mongolian',
  'ne': 'Nepali',
  'si': 'Sinhala',
  'am': 'Amharic',
  'az': 'Azerbaijani',
  'be': 'Belarusian',
  'ka': 'Georgian',
  'hy': 'Armenian',
  'kk': 'Kazakh',
  'uz': 'Uzbek',
  'ky': 'Kyrgyz',
  'tg': 'Tajik',
  'tk': 'Turkmen',
  'pa': 'Punjabi',
  'gu': 'Gujarati',
  'kn': 'Kannada',
  'ml': 'Malayalam',
  'mr': 'Marathi',
  'or': 'Odia',
  'as': 'Assamese',
  'ps': 'Pashto',
  'sd': 'Sindhi',
  'ku': 'Kurdish',
  'yi': 'Yiddish',
  'la': 'Latin',
  'eo': 'Esperanto',
  'und': 'Unknown',
};

/// Returns a human-readable language name for the given code/string.
/// Falls back to a Title-Cased version of the input, or 'Unknown' if empty.
String languageDisplayName(String? code) {
  if (code == null || code.trim().isEmpty) return 'Unknown';
  final c = code.trim().toLowerCase();
  final hit = _kLanguageNames[c];
  if (hit != null) return hit;
  // Try base before region (e.g. en-US -> en)
  final dash = c.indexOf(RegExp(r'[-_]'));
  if (dash > 0) {
    final base = c.substring(0, dash);
    final hit2 = _kLanguageNames[base];
    if (hit2 != null) return hit2;
  }
  // Capitalize first letter of each word as fallback
  return code
      .split(RegExp(r'[\s_-]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
      .join(' ');
}

/// Normalizes a language code for use as a grouping key.
String languageGroupKey(String? code) {
  if (code == null || code.trim().isEmpty) return 'unknown';
  return code.trim().toLowerCase();
}

/// Preferred display order for the subtitle language picker. Languages
/// listed here appear first (in this order); everything else follows
/// alphabetically by display name.
const List<String> _kLanguagePriority = [
  'en',
  'ar',
  'es',
  'fr',
  'de',
  'it',
  'pt',
  'pt-br',
  'ru',
  'tr',
  'nl',
  'pl',
  'ja',
  'ko',
  'zh',
  'zh-cn',
  'zh-tw',
  'hi',
  'id',
  'th',
  'vi',
  'sv',
  'da',
  'no',
  'fi',
  'cs',
  'el',
  'he',
  'ro',
  'hu',
  'uk',
];

/// Compare function that sorts language codes by the preferred priority
/// list first, then alphabetically by their display name.
int compareLanguageCodes(String a, String b) {
  final ai = _kLanguagePriority.indexOf(a);
  final bi = _kLanguagePriority.indexOf(b);
  if (ai != -1 && bi != -1) return ai.compareTo(bi);
  if (ai != -1) return -1;
  if (bi != -1) return 1;
  return languageDisplayName(a).compareTo(languageDisplayName(b));
}
