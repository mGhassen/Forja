/// Maps ISO-639 codes (and common English aliases) to native endonyms.
/// Used by audio/subtitle pickers so each language renders in its own script.
const Map<String, String> _kLanguageNames = {
  // English
  'en': 'English',
  'eng': 'English',
  'english': 'English',
  // Spanish
  'es': 'Español',
  'spa': 'Español',
  'esp': 'Español',
  'spanish': 'Español',
  'español': 'Español',
  'espanol': 'Español',
  // French
  'fr': 'Français',
  'fra': 'Français',
  'fre': 'Français',
  'french': 'Français',
  'francais': 'Français',
  'français': 'Français',
  // German
  'de': 'Deutsch',
  'deu': 'Deutsch',
  'ger': 'Deutsch',
  'german': 'Deutsch',
  'deutsch': 'Deutsch',
  // Italian
  'it': 'Italiano',
  'ita': 'Italiano',
  'italian': 'Italiano',
  'italiano': 'Italiano',
  // Portuguese
  'pt': 'Português',
  'por': 'Português',
  'portuguese': 'Português',
  'português': 'Português',
  'portugues': 'Português',
  'pt-br': 'Português (Brasil)',
  'pt-pt': 'Português (Portugal)',
  // Russian
  'ru': 'Русский',
  'rus': 'Русский',
  'russian': 'Русский',
  // Japanese
  'ja': '日本語',
  'jpn': '日本語',
  'jap': '日本語',
  'japanese': '日本語',
  // Korean
  'ko': '한국어',
  'kor': '한국어',
  'korean': '한국어',
  // Chinese
  'zh': '中文',
  'zho': '中文',
  'chi': '中文',
  'chinese': '中文',
  'zh-cn': '中文（简体）',
  'zh-hans': '中文（简体）',
  'chs': '中文（简体）',
  'zh-tw': '中文（繁體）',
  'zh-hant': '中文（繁體）',
  'zh-hk': '中文（繁體）',
  'cht': '中文（繁體）',
  // Arabic
  'ar': 'العربية',
  'ara': 'العربية',
  'arabic': 'العربية',
  // Turkish
  'tr': 'Türkçe',
  'tur': 'Türkçe',
  'turkish': 'Türkçe',
  'turkce': 'Türkçe',
  'türkçe': 'Türkçe',
  // Polish
  'pl': 'Polski',
  'pol': 'Polski',
  'polish': 'Polski',
  // Dutch
  'nl': 'Nederlands',
  'nld': 'Nederlands',
  'dut': 'Nederlands',
  'dutch': 'Nederlands',
  // Swedish
  'sv': 'Svenska',
  'swe': 'Svenska',
  'swedish': 'Svenska',
  // Danish
  'da': 'Dansk',
  'dan': 'Dansk',
  'danish': 'Dansk',
  // Norwegian
  'no': 'Norsk',
  'nor': 'Norsk',
  'norwegian': 'Norsk',
  'nb': 'Norsk Bokmål',
  'nob': 'Norsk Bokmål',
  'nn': 'Norsk Nynorsk',
  'nno': 'Norsk Nynorsk',
  // Finnish
  'fi': 'Suomi',
  'fin': 'Suomi',
  'finnish': 'Suomi',
  // Czech
  'cs': 'Čeština',
  'ces': 'Čeština',
  'cze': 'Čeština',
  'czech': 'Čeština',
  // Greek
  'el': 'Ελληνικά',
  'ell': 'Ελληνικά',
  'gre': 'Ελληνικά',
  'greek': 'Ελληνικά',
  // Hebrew
  'he': 'עברית',
  'heb': 'עברית',
  'iw': 'עברית',
  'hebrew': 'עברית',
  // Hindi
  'hi': 'हिन्दी',
  'hin': 'हिन्दी',
  'hindi': 'हिन्दी',
  // Indonesian
  'id': 'Bahasa Indonesia',
  'ind': 'Bahasa Indonesia',
  'in': 'Bahasa Indonesia',
  'indonesian': 'Bahasa Indonesia',
  // Vietnamese
  'vi': 'Tiếng Việt',
  'vie': 'Tiếng Việt',
  'vietnamese': 'Tiếng Việt',
  // Thai
  'th': 'ไทย',
  'tha': 'ไทย',
  'thai': 'ไทย',
  // Romanian
  'ro': 'Română',
  'ron': 'Română',
  'rum': 'Română',
  'romanian': 'Română',
  // Hungarian
  'hu': 'Magyar',
  'hun': 'Magyar',
  'hungarian': 'Magyar',
  // Ukrainian
  'uk': 'Українська',
  'ukr': 'Українська',
  'ukrainian': 'Українська',
  // Bulgarian
  'bg': 'Български',
  'bul': 'Български',
  'bulgarian': 'Български',
  // Croatian
  'hr': 'Hrvatski',
  'hrv': 'Hrvatski',
  'croatian': 'Hrvatski',
  // Serbian
  'sr': 'Српски',
  'srp': 'Српски',
  'serbian': 'Српски',
  // Slovak
  'sk': 'Slovenčina',
  'slk': 'Slovenčina',
  'slovak': 'Slovenčina',
  // Slovenian
  'sl': 'Slovenščina',
  'slv': 'Slovenščina',
  'slovenian': 'Slovenščina',
  // Estonian
  'et': 'Eesti',
  'est': 'Eesti',
  'estonian': 'Eesti',
  // Latvian
  'lv': 'Latviešu',
  'lav': 'Latviešu',
  'latvian': 'Latviešu',
  // Lithuanian
  'lt': 'Lietuvių',
  'lit': 'Lietuvių',
  'lithuanian': 'Lietuvių',
  // Malay
  'ms': 'Bahasa Melayu',
  'msa': 'Bahasa Melayu',
  'may': 'Bahasa Melayu',
  'malay': 'Bahasa Melayu',
  // Persian
  'fa': 'فارسی',
  'fas': 'فارسی',
  'per': 'فارسی',
  'persian': 'فارسی',
  'farsi': 'فارسی',
  // Bengali
  'bn': 'বাংলা',
  'ben': 'বাংলা',
  'bengali': 'বাংলা',
  // Tamil
  'ta': 'தமிழ்',
  'tam': 'தமிழ்',
  'tamil': 'தமிழ்',
  // Telugu
  'te': 'తెలుగు',
  'tel': 'తెలుగు',
  'telugu': 'తెలుగు',
  // Urdu
  'ur': 'اردو',
  'urd': 'اردو',
  'urdu': 'اردو',
  // Javanese
  'jv': 'Basa Jawa',
  'jav': 'Basa Jawa',
  'jw': 'Basa Jawa',
  'javanese': 'Basa Jawa',
  // Catalan
  'ca': 'Català',
  'cat': 'Català',
  'catalan': 'Català',
  // Basque
  'eu': 'Euskara',
  'eus': 'Euskara',
  'basque': 'Euskara',
  // Galician
  'gl': 'Galego',
  'glg': 'Galego',
  'galician': 'Galego',
  // Albanian
  'sq': 'Shqip',
  'sqi': 'Shqip',
  'alb': 'Shqip',
  'albanian': 'Shqip',
  // Macedonian
  'mk': 'Македонски',
  'mkd': 'Македонски',
  'mac': 'Македонски',
  'macedonian': 'Македонски',
  // Bosnian
  'bs': 'Bosanski',
  'bos': 'Bosanski',
  'bosnian': 'Bosanski',
  // Icelandic
  'is': 'Íslenska',
  'isl': 'Íslenska',
  'ice': 'Íslenska',
  'icelandic': 'Íslenska',
  // Maltese
  'mt': 'Malti',
  'mlt': 'Malti',
  'maltese': 'Malti',
  // Irish
  'ga': 'Gaeilge',
  'gle': 'Gaeilge',
  'irish': 'Gaeilge',
  // Welsh
  'cy': 'Cymraeg',
  'cym': 'Cymraeg',
  'welsh': 'Cymraeg',
  // Afrikaans
  'af': 'Afrikaans',
  'afr': 'Afrikaans',
  'afrikaans': 'Afrikaans',
  // Swahili
  'sw': 'Kiswahili',
  'swa': 'Kiswahili',
  'swahili': 'Kiswahili',
  // Filipino / Tagalog
  'fil': 'Filipino',
  'tl': 'Tagalog',
  'tgl': 'Tagalog',
  'tagalog': 'Tagalog',
  'filipino': 'Filipino',
  // Burmese
  'my': 'မြန်မာ',
  'mya': 'မြန်မာ',
  'bur': 'မြန်မာ',
  'burmese': 'မြန်မာ',
  // Khmer
  'km': 'ខ្មែរ',
  'khm': 'ខ្មែរ',
  'khmer': 'ខ្មែរ',
  // Lao
  'lo': 'ລາວ',
  'lao': 'ລາວ',
  // Mongolian
  'mn': 'Монгол',
  'mon': 'Монгол',
  'mongolian': 'Монгол',
  // Nepali
  'ne': 'नेपाली',
  'nep': 'नेपाली',
  'nepali': 'नेपाली',
  // Sinhala
  'si': 'සිංහල',
  'sin': 'සිංහල',
  'sinhala': 'සිංහල',
  // Amharic
  'am': 'አማርኛ',
  'amh': 'አማርኛ',
  'amharic': 'አማርኛ',
  // Azerbaijani
  'az': 'Azərbaycan',
  'aze': 'Azərbaycan',
  'azerbaijani': 'Azərbaycan',
  // Belarusian
  'be': 'Беларуская',
  'bel': 'Беларуская',
  'belarusian': 'Беларуская',
  // Georgian
  'ka': 'ქართული',
  'kat': 'ქართული',
  'geo': 'ქართული',
  'georgian': 'ქართული',
  // Armenian
  'hy': 'Հայերեն',
  'hye': 'Հայերեն',
  'arm': 'Հայերեն',
  'armenian': 'Հայերեն',
  // Kazakh
  'kk': 'Қазақ',
  'kaz': 'Қазақ',
  'kazakh': 'Қазақ',
  // Uzbek
  'uz': 'Oʻzbek',
  'uzb': 'Oʻzbek',
  'uzbek': 'Oʻzbek',
  // Kyrgyz
  'ky': 'Кыргызча',
  'kir': 'Кыргызча',
  'kyrgyz': 'Кыргызча',
  // Tajik
  'tg': 'Тоҷикӣ',
  'tgk': 'Тоҷикӣ',
  'tajik': 'Тоҷикӣ',
  // Turkmen
  'tk': 'Türkmen',
  'tuk': 'Türkmen',
  'turkmen': 'Türkmen',
  // Punjabi
  'pa': 'ਪੰਜਾਬੀ',
  'pan': 'ਪੰਜਾਬੀ',
  'punjabi': 'ਪੰਜਾਬੀ',
  // Gujarati
  'gu': 'ગુજરાતી',
  'guj': 'ગુજરાતી',
  'gujarati': 'ગુજરાતੀ',
  // Kannada
  'kn': 'ಕನ್ನಡ',
  'kan': 'ಕನ್ನಡ',
  'kannada': 'ಕನ್ನಡ',
  // Malayalam
  'ml': 'മലയാളം',
  'mal': 'മലയാളം',
  'malayalam': 'മലയാളം',
  // Marathi
  'mr': 'मराठी',
  'mar': 'मराठी',
  'marathi': 'मराठी',
  // Odia
  'or': 'ଓଡ଼ିଆ',
  'ori': 'ଓଡ଼ିଆ',
  'odia': 'ଓଡ଼ିଆ',
  // Assamese
  'as': 'অসমীয়া',
  'asm': 'অসমীয়া',
  'assamese': 'অসমীয়া',
  // Pashto
  'ps': 'پښتو',
  'pus': 'پښتو',
  'pashto': 'پښتو',
  // Sindhi
  'sd': 'سنڌي',
  'snd': 'سنڌي',
  'sindhi': 'سنڌي',
  // Kurdish
  'ku': 'Kurdî',
  'kur': 'Kurdî',
  'kurdish': 'Kurdî',
  // Yiddish
  'yi': 'ייִדיש',
  'yid': 'ייִדיש',
  'yiddish': 'ייִדיש',
  // Latin / constructed
  'la': 'Latina',
  'lat': 'Latina',
  'latin': 'Latina',
  'eo': 'Esperanto',
  'epo': 'Esperanto',
  'esperanto': 'Esperanto',
  // Unknown
  'und': 'Unknown',
  'unknown': 'Unknown',
};

/// Lookup only - returns null when [code] is not a known language token.
String? languageEndonym(String? code) {
  if (code == null || code.trim().isEmpty) return null;
  final c = code.trim().toLowerCase();
  final hit = _kLanguageNames[c];
  if (hit != null) return hit;
  final dash = c.indexOf(RegExp(r'[-_]'));
  if (dash > 0) {
    final hit2 = _kLanguageNames[c.substring(0, dash)];
    if (hit2 != null) return hit2;
  }
  return null;
}

/// Returns the native endonym for the given code/string.
/// Falls back to a Title-Cased version of the input, or 'Unknown' if empty.
String languageDisplayName(String? code) {
  if (code == null || code.trim().isEmpty) return 'Unknown';
  final hit = languageEndonym(code);
  if (hit != null) return hit;
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
