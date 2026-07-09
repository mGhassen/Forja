import 'package:rust/rust.dart';

/// Parsed scene / release name metadata for source list badges and filters.
class TorrentReleaseMetadata {
  const TorrentReleaseMetadata({
    required this.quality,
    required this.languageCodes,
    required this.audioTags,
    required this.techTags,
    required this.sourceTags,
    this.videoCodec,
  });

  final String? quality;
  final List<String> languageCodes;
  final List<String> audioTags;
  final List<String> techTags;
  final List<String> sourceTags;
  final String? videoCodec;

  static const qualityFilters = ['4K', '1080p', '720p', '480p'];
  static const techFilters = ['HDR', 'DV', 'REMUX', 'WEB-DL', 'WEBRip', 'BluRay', '10bit'];

  static TorrentReleaseMetadata parse(String name) {
    final n = name.toUpperCase();
    return TorrentReleaseMetadata(
      quality: _detectQuality(n),
      languageCodes: _detectLanguages(n),
      audioTags: detectAudioTags(name),
      techTags: _detectTech(n),
      sourceTags: _detectSource(n),
      videoCodec: _detectCodec(n),
    );
  }

  String get flags => languageCodes
      .map(StreamProviderDisplay.flagForCountry)
      .where((f) => f.isNotEmpty)
      .join(' ');

  List<String> get badgeLabels => [
        if (quality != null) quality!,
        if (videoCodec != null) videoCodec!,
        ...audioTags.take(2),
        ...techTags,
        ...sourceTags.take(1),
      ];

  static bool nameContains({required String name, required String query}) {
    if (query.trim().isEmpty) return true;
    return name.toLowerCase().contains(query.trim().toLowerCase());
  }

  bool matchesFiltersForName(
    String name, {
    String searchQuery = '',
    Set<String> qualityFilters = const {},
    Set<String> languageFilters = const {},
    Set<String> techFilters = const {},
    Set<String> audioFilters = const {},
  }) {
    if (!nameContains(name: name, query: searchQuery)) return false;
    final meta = parse(name);
    if (qualityFilters.isNotEmpty &&
        (meta.quality == null || !qualityFilters.contains(meta.quality))) {
      return false;
    }
    if (languageFilters.isNotEmpty &&
        !meta.languageCodes.any(languageFilters.contains)) {
      return false;
    }
    if (techFilters.isNotEmpty &&
        !meta.techTags.any(techFilters.contains) &&
        !meta.sourceTags.any(techFilters.contains)) {
      return false;
    }
    if (audioFilters.isNotEmpty && !meta.audioTags.any(audioFilters.contains)) {
      return false;
    }
    return true;
  }

  static List<String> detectAudioTags(String name) {
    final n = name.toUpperCase();
    final found = <String>[];
    if (n.contains('ATMOS')) found.add('Atmos');
    if (n.contains('TRUEHD')) found.add('TrueHD');
    if (n.contains('DTS:X') || n.contains('DTSX')) found.add('DTS:X');
    if (!found.contains('DTS:X') &&
        (n.contains('DTS-HD') || n.contains('DTSHD'))) {
      found.add('DTS-HD');
    }
    if (!found.contains('DTS:X') &&
        !found.contains('DTS-HD') &&
        n.contains('DTS')) {
      found.add('DTS');
    }
    if (n.contains('DD+') ||
        n.contains('EAC3') ||
        n.contains('E-AC-3') ||
        n.contains('DDPLUS')) {
      found.add('DD+');
    }
    if (!found.contains('DD+') &&
        (n.contains(' DD ') || n.contains('AC3') || n.contains('DOLBY DIGITAL'))) {
      found.add('DD');
    }
    if (n.contains('AAC')) found.add('AAC');
    if (n.contains('7.1')) found.add('7.1');
    if (!found.contains('7.1') && n.contains('5.1')) found.add('5.1');
    if (n.contains(' 2.0') || n.contains('.2.0')) found.add('2.0');
    return found;
  }

  static String? _detectQuality(String n) {
    if (n.contains('2160') || n.contains('4K') || n.contains('UHD')) return '4K';
    if (n.contains('1080')) return '1080p';
    if (n.contains('720')) return '720p';
    if (n.contains('480')) return '480p';
    return null;
  }

  static String? _detectCodec(String n) {
    if (n.contains('HEVC') || n.contains('X265') || n.contains('H.265')) {
      return 'HEVC';
    }
    if (n.contains('X264') ||
        n.contains('H.264') ||
        n.contains('H264') ||
        n.contains('AVC')) {
      return 'h264';
    }
    if (n.contains('AV1')) return 'AV1';
    if (n.contains('VP9')) return 'VP9';
    return null;
  }

  static List<String> _detectTech(String n) {
    final out = <String>[];
    if (n.contains('DOLBY VISION') || n.contains('DOVI') || n.contains('.DV.')) {
      out.add('DV');
    }
    if (n.contains('HDR10+')) out.add('HDR10+');
    if (n.contains('HDR10') || n.contains('HDR')) out.add('HDR');
    if (n.contains('10BIT') || n.contains('10-BIT')) out.add('10bit');
    return out;
  }

  static List<String> _detectSource(String n) {
    final out = <String>[];
    if (n.contains('REMUX')) out.add('REMUX');
    if (n.contains('WEB-DL') || n.contains('WEBDL') || n.contains('WEB DL')) {
      out.add('WEB-DL');
    }
    if (n.contains('WEBRIP') || n.contains('WEB-RIP')) out.add('WEBRip');
    if (n.contains('BLURAY') || n.contains('BLU-RAY') || n.contains('BDRIP')) {
      out.add('BluRay');
    }
    if (n.contains('HDTV')) out.add('HDTV');
    return out;
  }

  static List<String> _detectLanguages(String n) {
    final out = <String>[];
    void add(String code) {
      if (!out.contains(code)) out.add(code);
    }

    if (n.contains('MULTI') || n.contains('DUAL AUDIO') || n.contains('DUAL-AUDIO')) {
      add('multi');
    }

    const patterns = <String, List<String>>{
      'en': ['ENGLISH', ' ENG ', '.ENG.', '[EN]', '-EN-', '.EN.'],
      'fr': ['FRENCH', 'VOSTFR', 'SUBFRENCH', 'TRUEFRENCH', ' VF ', '.FR.', '[FR]'],
      'de': ['GERMAN', ' GER ', '.GER.', '[DE]', 'GERMAN DL'],
      'es': ['SPANISH', ' CASTELLAN', ' LATINO', '.ES.', '[ES]'],
      'it': ['ITALIAN', ' ITA ', '.ITA.', '[IT]'],
      'pt': ['PORTUGUESE', ' PT-BR', ' PTBR', '.PT.', '[PT]'],
      'ru': ['RUSSIAN', ' RUS ', '.RUS.', '[RU]'],
      'ja': ['JAPANESE', ' JPN ', '.JPN.', '[JA]'],
      'ko': ['KOREAN', ' KOR ', '.KOR.', '[KO]'],
      'zh': ['CHINESE', ' CHI ', '.CHI.', '[ZH]', 'MANDARIN'],
      'ar': ['ARABIC', ' ARA ', '.ARA.', '[AR]'],
      'hi': ['HINDI', ' HIN ', '.HIN.', '[HI]'],
      'tr': ['TURKISH', ' TUR ', '.TUR.', '[TR]'],
      'pl': ['POLISH', ' POL ', '.POL.', '[PL]'],
      'nl': ['DUTCH', ' DUT ', '.DUT.', '[NL]'],
      'sv': ['SWEDISH', ' SWE ', '.SWE.', '[SV]'],
      'no': ['NORWEGIAN', ' NOR ', '.NOR.', '[NO]'],
      'da': ['DANISH', ' DAN ', '.DAN.', '[DA]'],
      'fi': ['FINNISH', ' FIN ', '.FIN.', '[FI]'],
      'th': ['THAI', ' THA ', '.THA.', '[TH]'],
      'vi': ['VIETNAMESE', ' VIE ', '.VIE.', '[VI]'],
    };

    for (final entry in patterns.entries) {
      for (final token in entry.value) {
        if (n.contains(token)) {
          add(entry.key);
          break;
        }
      }
    }

    return out.take(3).toList();
  }
}

List<TorrentResult> filterTorrentResults(
  List<TorrentResult> results, {
  String searchQuery = '',
  Set<String> qualityFilters = const {},
  Set<String> languageFilters = const {},
  Set<String> techFilters = const {},
  Set<String> audioFilters = const {},
}) {
  return results
      .where(
        (r) => TorrentReleaseMetadata.parse(r.name).matchesFiltersForName(
          r.name,
          searchQuery: searchQuery,
          qualityFilters: qualityFilters,
          languageFilters: languageFilters,
          techFilters: techFilters,
          audioFilters: audioFilters,
        ),
      )
      .toList();
}

Set<String> collectQualities(Iterable<String> names) {
  final out = <String>{};
  for (final name in names) {
    final q = TorrentReleaseMetadata.parse(name).quality;
    if (q != null) out.add(q);
  }
  return out;
}

Set<String> collectLanguages(Iterable<String> names) {
  final out = <String>{};
  for (final name in names) {
    out.addAll(TorrentReleaseMetadata.parse(name).languageCodes);
  }
  return out;
}

Set<String> collectTechTags(Iterable<String> names) {
  final out = <String>{};
  for (final name in names) {
    final meta = TorrentReleaseMetadata.parse(name);
    out.addAll(meta.techTags);
    out.addAll(meta.sourceTags);
  }
  return out;
}
