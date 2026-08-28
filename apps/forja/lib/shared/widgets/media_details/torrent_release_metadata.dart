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
    this.container,
  });

  final String? quality;
  final List<String> languageCodes;
  final List<String> audioTags;
  final List<String> techTags;
  final List<String> sourceTags;
  final String? videoCodec;
  final String? container;

  static const qualityFilters = ['4K', '1080p', '720p', '480p'];
  static const techFilters = [
    'HDR',
    'DV',
    'REMUX',
    'WEB-DL',
    'WEBRip',
    'BluRay',
    '10bit',
  ];

  /// Preset size ranges for Sources filters (multi-select OR).
  static const sizeFilters = ['<1 GB', '1–3 GB', '3–8 GB', '8–20 GB', '20 GB+'];

  static const _gb = 1024.0 * 1024.0 * 1024.0;

  /// Video sources below this are bogus scraper noise (e.g. 4096 → "4 KB").
  static const _minDisplaySizeBytes = 1024 * 1024;

  // Kilobytes require kb/kib — bare "k" false-matches "4K" resolution tags.
  static final _sizeToken = RegExp(
    r'(\d+(?:\.\d+)?)\s*(tib|tb|t|gib|gb|g|mib|mb|m|kib|kb)\b',
    caseSensitive: false,
  );

  static final _qualitySizeFalsePositive = RegExp(
    r'^(4K|UHD|2160P|\d{3,4}P)$',
    caseSensitive: false,
  );

  /// Parses a human size string (`1.4 GB`, `850 MB`) or the first size token
  /// found inside a longer title/description. Returns `0` when unknown.
  static double parseSizeBytes(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 0;
    final match = _sizeToken.firstMatch(s);
    if (match == null) return 0;
    final value = double.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toLowerCase();
    if (unit.startsWith('ti') || unit == 't' || unit == 'tb') {
      return value * _gb * 1024;
    }
    if (unit.startsWith('gi') || unit == 'g' || unit == 'gb') {
      return value * _gb;
    }
    if (unit.startsWith('mi') || unit == 'm' || unit == 'mb') {
      return value * 1024 * 1024;
    }
    if (unit.startsWith('ki') || unit == 'kb') {
      return value * 1024;
    }
    return value;
  }

  static String? _labelFromSizeMatch(RegExpMatch match) {
    final value = match.group(1)!;
    final unit = match.group(2)!.toLowerCase();
    final String normalized;
    if (unit.startsWith('ti') || unit == 't' || unit == 'tb') {
      normalized = 'TB';
    } else if (unit.startsWith('gi') || unit == 'g' || unit == 'gb') {
      normalized = 'GB';
    } else if (unit.startsWith('mi') || unit == 'm' || unit == 'mb') {
      normalized = 'MB';
    } else if (unit.startsWith('ki') || unit == 'kb') {
      normalized = 'KB';
    } else {
      normalized = unit.toUpperCase();
    }
    return '$value $normalized';
  }

  static bool _isDisplayableSizeBytes(double bytes) =>
      bytes >= _minDisplaySizeBytes;

  static String? _labelFromSizeMatchIfDisplayable(RegExpMatch match) {
    final bytes = parseSizeBytes(match.group(0)!);
    if (!_isDisplayableSizeBytes(bytes)) return null;
    return _labelFromSizeMatch(match);
  }

  /// Display label for source tiles. Never returns a non-size string (avoids
  /// showing truncated titles in the size slot). Prefers [sizeText], then the
  /// first size token in [fallbackText]. Omits impossible video sizes (< 1 MB).
  static String? resolveSizeLabel({String? sizeText, String? fallbackText}) {
    final primary = sizeText?.trim() ?? '';
    if (primary.isNotEmpty &&
        primary.toLowerCase() != 'unknown' &&
        primary != '0') {
      if (_qualitySizeFalsePositive.hasMatch(primary)) return null;
      final match = _sizeToken.firstMatch(primary);
      if (match != null) return _labelFromSizeMatchIfDisplayable(match);
      // Raw byte count from scrapers / Torrentio behaviorHints.videoSize.
      final asBytes = double.tryParse(primary.replaceAll(',', ''));
      if (asBytes != null && _isDisplayableSizeBytes(asBytes)) {
        return formatBytes(asBytes);
      }
      final parsed = parseSizeBytes(primary);
      if (_isDisplayableSizeBytes(parsed)) return primary;
    }
    final fallback = fallbackText?.trim() ?? '';
    if (fallback.isEmpty) return null;
    final match = _sizeToken.firstMatch(fallback);
    if (match == null) return null;
    return _labelFromSizeMatchIfDisplayable(match);
  }

  /// Human size for scraper / Stremio byte counts (`1234567890` → `1.15 GB`).
  static String formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes;
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final digits = v >= 100 || i == 0 ? 0 : (v >= 10 ? 1 : 2);
    return '${v.toStringAsFixed(digits)} ${units[i]}';
  }

  /// Size label from a Stremio/Torrentio/Nuvio stream map.
  /// Prefers explicit `size`, then `behaviorHints.videoSize` (bytes), then
  /// size tokens in title/description (Torrentio often embeds `💾 1.2 GB`).
  static String? resolveStreamSizeLabel(Map<String, dynamic> stream) {
    final explicit = stream['size']?.toString();
    final fromExplicit = resolveSizeLabel(sizeText: explicit);
    if (fromExplicit != null) return fromExplicit;

    final hints = stream['behaviorHints'];
    if (hints is Map) {
      final videoSize = hints['videoSize'] ?? hints['video_size'];
      if (videoSize != null) {
        final fromHint = resolveSizeLabel(sizeText: videoSize.toString());
        if (fromHint != null) return fromHint;
      }
    }

    final blob =
        '${stream['title'] ?? stream['name'] ?? ''} ${stream['description'] ?? ''}';
    return resolveSizeLabel(fallbackText: blob);
  }

  static String? sizeRangeForBytes(double bytes) {
    if (bytes <= 0) return null;
    final gb = bytes / _gb;
    if (gb < 1) return '<1 GB';
    if (gb < 3) return '1–3 GB';
    if (gb < 8) return '3–8 GB';
    if (gb < 20) return '8–20 GB';
    return '20 GB+';
  }

  /// Multi-select OR: keep if size falls in any selected range.
  /// Unknown size fails when any size filter is active.
  static bool matchesSizeFilters(double bytes, Set<String> sizeFilters) {
    if (sizeFilters.isEmpty) return true;
    final range = sizeRangeForBytes(bytes);
    return range != null && sizeFilters.contains(range);
  }

  static TorrentReleaseMetadata parse(String name) {
    final n = name.toUpperCase();
    return TorrentReleaseMetadata(
      quality: _detectQuality(n),
      languageCodes: _detectLanguages(n),
      audioTags: detectAudioTags(name),
      techTags: _detectTech(n),
      sourceTags: _detectSource(n),
      videoCodec: _detectCodec(n),
      container: _detectContainer(n),
    );
  }

  String get flags => StreamProviderDisplay.flagsDisplayForCodes(languageCodes);

  List<String> get badgeLabels => [
        ?quality,
        ?container,
        ?videoCodec,
        ...audioTags.take(2),
        ...techTags,
        ...sourceTags.take(1),
      ];

  /// Single-line meta for list tiles - flags + key tags, no pill chrome.
  String get compactMetaLine {
    final parts = <String>[];
    final f = flags.trim();
    if (f.isNotEmpty) parts.add(f);
    if (quality != null) parts.add(quality!);
    if (container != null) parts.add(container!);
    if (videoCodec != null) parts.add(videoCodec!);
    if (audioTags.isNotEmpty) parts.add(audioTags.first);
    for (final t in techTags) {
      if (parts.length >= 5) break;
      parts.add(t);
    }
    if (sourceTags.isNotEmpty && parts.length < 5) parts.add(sourceTags.first);
    return parts.join(' · ');
  }

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
        (n.contains(' DD ') ||
            n.contains('AC3') ||
            n.contains('DOLBY DIGITAL'))) {
      found.add('DD');
    }
    if (n.contains('AAC')) found.add('AAC');
    if (n.contains('7.1')) found.add('7.1');
    if (!found.contains('7.1') && n.contains('5.1')) found.add('5.1');
    if (n.contains(' 2.0') || n.contains('.2.0')) found.add('2.0');
    return found;
  }

  static String? _detectQuality(String n) {
    if (n.contains('2160') || n.contains('4K') || n.contains('UHD')) {
      return '4K';
    }
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

  static String? _detectContainer(String n) {
    if (RegExp(r'(\.MKV\b|\bMKV\b)').hasMatch(n)) return 'MKV';
    if (RegExp(r'(\.MP4\b|\bMP4\b)').hasMatch(n)) return 'MP4';
    if (RegExp(r'(\.WEBM\b|\bWEBM\b)').hasMatch(n)) return 'WebM';
    return null;
  }

  static List<String> _detectTech(String n) {
    final out = <String>[];
    if (n.contains('DOLBY VISION') ||
        n.contains('DOVI') ||
        n.contains('.DV.')) {
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

    if (n.contains('MULTI') ||
        n.contains('DUAL AUDIO') ||
        n.contains('DUAL-AUDIO')) {
      add('multi');
    }

    const patterns = <String, List<String>>{
      'en': ['ENGLISH', ' ENG ', '.ENG.', '[EN]', '-EN-', '.EN.'],
      'fr': [
        'FRENCH',
        'VOSTFR',
        'SUBFRENCH',
        'TRUEFRENCH',
        ' VF ',
        '.FR.',
        '[FR]',
      ],
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
  Set<String> sizeFilters = const {},
}) {
  return results.where((r) {
    if (!TorrentReleaseMetadata.parse(r.name).matchesFiltersForName(
      r.name,
      searchQuery: searchQuery,
      qualityFilters: qualityFilters,
      languageFilters: languageFilters,
      techFilters: techFilters,
      audioFilters: audioFilters,
    )) {
      return false;
    }
    return TorrentReleaseMetadata.matchesSizeFilters(
      r.sizeInBytes > 0
          ? r.sizeInBytes
          : TorrentReleaseMetadata.parseSizeBytes(r.size),
      sizeFilters,
    );
  }).toList();
}

Set<String> collectSizeRanges(Iterable<double> sizesInBytes) {
  final out = <String>{};
  for (final bytes in sizesInBytes) {
    final range = TorrentReleaseMetadata.sizeRangeForBytes(bytes);
    if (range != null) out.add(range);
  }
  return out;
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
