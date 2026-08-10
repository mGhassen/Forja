class StreamQualityOption {
  final String label;
  final String url;
  final int? height;
  final bool isAuto;

  const StreamQualityOption({
    required this.label,
    required this.url,
    this.height,
    this.isAuto = false,
  });

  factory StreamQualityOption.fromJson(Map<String, dynamic> json) {
    return StreamQualityOption(
      label: (json['label'] ?? json['title'] ?? 'Auto').toString(),
      url: (json['url'] ?? '').toString(),
      height: (json['height'] as num?)?.toInt(),
      isAuto: json['isAuto'] == true || json['is_auto'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
        if (height != null) 'height': height,
        if (isAuto) 'isAuto': true,
      };
}

class StreamSource {
  final String url;
  final String title;
  final String type;
  final Map<String, String>? headers;

  /// Anime / provider identity (e.g. `megaplay`, `miruro:kiwi`). Used for
  /// Referer policy and PNG-strip — not CDN hostname matching (RFC-044).
  final String? providerId;

  /// Pre-proxy catalog URL when [url] is a local `/hls-proxy` play endpoint.
  final String? catalogUrl;

  /// Discrete height ladder for this logical stream (Sources = one row).
  /// Player Quality menu lists these; not HLS master ABR variants.
  final List<StreamQualityOption>? qualities;

  StreamSource({
    required this.url,
    required this.title,
    required this.type,
    this.headers,
    this.providerId,
    this.catalogUrl,
    this.qualities,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    final rawHeaders = json['headers'];
    if (rawHeaders is Map) {
      headers = rawHeaders.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }
    final pid = (json['providerId'] as String?)?.trim();
    final catalog = (json['catalogUrl'] as String?)?.trim();
    List<StreamQualityOption>? qualities;
    final rawQualities = json['qualities'];
    if (rawQualities is List) {
      qualities = [
        for (final q in rawQualities)
          if (q is Map)
            StreamQualityOption.fromJson(Map<String, dynamic>.from(q)),
      ];
      if (qualities.isEmpty) qualities = null;
    }
    return StreamSource(
      url: json['url'] ?? json['file'] ?? json['src'] ?? '',
      title: json['title'] ?? json['label'] ?? json['quality'] ?? 'Unknown',
      type: json['type'] ?? 'video',
      headers: headers,
      providerId: (pid != null && pid.isNotEmpty) ? pid : null,
      catalogUrl: (catalog != null && catalog.isNotEmpty) ? catalog : null,
      qualities: qualities,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'type': type,
        if (headers != null) 'headers': headers,
        if (providerId != null && providerId!.isNotEmpty)
          'providerId': providerId,
        if (catalogUrl != null && catalogUrl!.isNotEmpty)
          'catalogUrl': catalogUrl,
        if (qualities != null && qualities!.isNotEmpty)
          'qualities': qualities!.map((q) => q.toJson()).toList(),
      };

  StreamSource copyWith({
    String? url,
    String? title,
    String? type,
    Map<String, String>? headers,
    String? providerId,
    String? catalogUrl,
    List<StreamQualityOption>? qualities,
    bool clearHeaders = false,
    bool clearQualities = false,
  }) {
    return StreamSource(
      url: url ?? this.url,
      title: title ?? this.title,
      type: type ?? this.type,
      headers: clearHeaders ? null : (headers ?? this.headers),
      providerId: providerId ?? this.providerId,
      catalogUrl: catalogUrl ?? this.catalogUrl,
      qualities: clearQualities ? null : (qualities ?? this.qualities),
    );
  }
}

int streamSourcePlayPriority(StreamSource source) {
  final url = source.url.toLowerCase();
  if (url.contains('.m3u8')) return 0;
  if (url.contains('h265') || url.contains('hevc') || url.contains('/h265/')) {
    return 2;
  }
  return 1;
}

/// Collapse duplicate playable URLs and prefer HLS / non-HEVC first.
/// Also merges same-mirror height ladders into one row + qualities.
/// Sync fallback — use [dedupeStreamSourcesAsync] when device profile is available.
List<StreamSource> dedupeStreamSources(List<StreamSource> sources) {
  final seen = <String>{};
  final out = <StreamSource>[];
  for (final source in sources) {
    final url = source.url.trim();
    if (url.isEmpty || !seen.add(url)) continue;
    out.add(source);
  }
  out.sort((a, b) => streamSourcePlayPriority(a).compareTo(
        streamSourcePlayPriority(b),
      ));
  return collapseStreamQualityVariants(out);
}

/// Height tokens only — CDN labels like `playhq` / `Vimeos` stay as own rows.
final _streamHeightTokenRe = RegExp(
  r'(?:^|[\s·\-–—|/_,.(])((?:2160|1080|720|480|360|240)p?|4k|uhd|fhd)(?=$|[\s·\-–—|/_,.)])',
  caseSensitive: false,
);

/// Numeric / named height from a stream title (`1080p`, `4K`, …), else null.
String? streamHeightLabelFromTitle(String title) {
  final line = title.split('\n').first.trim();
  final match = _streamHeightTokenRe.firstMatch(line);
  if (match == null) return null;
  final raw = match.group(1)!.toLowerCase();
  if (raw == '4k' || raw == 'uhd' || raw == '2160' || raw == '2160p') {
    return '2160p';
  }
  if (raw == 'fhd' || raw == '1080' || raw == '1080p') return '1080p';
  if (raw == '720' || raw == '720p') return '720p';
  if (raw == '480' || raw == '480p') return '480p';
  if (raw == '360' || raw == '360p') return '360p';
  if (raw == '240' || raw == '240p') return '240p';
  return match.group(1);
}

int streamHeightRank(String? label) {
  if (label == null) return -1;
  final t = label.toLowerCase();
  if (t.contains('2160') || t.contains('4k') || t.contains('uhd')) return 6;
  if (t.contains('1080') || t.contains('fhd')) return 5;
  if (t.contains('720')) return 4;
  if (t.contains('480')) return 3;
  if (t.contains('360')) return 2;
  if (t.contains('240')) return 1;
  return 0;
}

int? streamHeightPx(String? label) {
  if (label == null) return null;
  final m = RegExp(r'(\d{3,4})').firstMatch(label);
  if (m != null) return int.tryParse(m.group(1)!);
  final t = label.toLowerCase();
  if (t.contains('4k') || t.contains('uhd')) return 2160;
  if (t.contains('fhd')) return 1080;
  return null;
}

String streamHeightFamilyKey(String title) {
  var line = title.split('\n').first.trim();
  line = line.replaceAll(_streamHeightTokenRe, ' ');
  line = line.replaceAll(RegExp(r'[\s·\-–—|/_,.]+'), ' ').trim();
  return line.toLowerCase();
}

String streamHeightFamilyTitle(String title) {
  var line = title.split('\n').first.trim();
  line = line.replaceAll(_streamHeightTokenRe, ' ');
  line = line
      .replaceAll(RegExp(r'[\s·\-–—|/_,.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (line.isEmpty) return title.split('\n').first.trim();
  return line;
}

/// Collapse same-mirror height ladders into one row + [StreamSource.qualities].
///
/// Only groups rows with an explicit height token (`1080p`, `720p`, …).
/// Leaves CDN-named singles (`Breach · playhq`) alone. Never drops URLs.
List<StreamSource> collapseStreamQualityVariants(List<StreamSource> sources) {
  if (sources.length < 2) return sources;

  final groups = <String, List<StreamSource>>{};
  final order = <String>[];
  final singles = <StreamSource>[];

  for (final source in sources) {
    final height = streamHeightLabelFromTitle(source.title);
    final family = streamHeightFamilyKey(source.title);
    if (height == null || family.isEmpty) {
      singles.add(source);
      continue;
    }
    final list = groups.putIfAbsent(family, () {
      order.add(family);
      return <StreamSource>[];
    });
    list.add(source);
  }

  final out = <StreamSource>[];
  for (final key in order) {
    final group = groups[key]!;
    if (group.length < 2) {
      out.addAll(group);
      continue;
    }

    // Best height first; HLS preferred on ties.
    group.sort((a, b) {
      final hr = streamHeightRank(streamHeightLabelFromTitle(b.title)).compareTo(
        streamHeightRank(streamHeightLabelFromTitle(a.title)),
      );
      if (hr != 0) return hr;
      return streamSourcePlayPriority(a).compareTo(streamSourcePlayPriority(b));
    });

    final primary = group.first;
    final options = <StreamQualityOption>[
      StreamQualityOption(
        label: 'Auto',
        url: primary.url,
        height: streamHeightPx(streamHeightLabelFromTitle(primary.title)),
        isAuto: true,
      ),
    ];
    final seenLabels = <String>{'auto'};
    for (final s in group) {
      final label = streamHeightLabelFromTitle(s.title) ?? 'Stream';
      final lk = label.toLowerCase();
      if (!seenLabels.add(lk)) continue;
      options.add(
        StreamQualityOption(
          label: label,
          url: s.url,
          height: streamHeightPx(label),
        ),
      );
    }

    out.add(
      primary.copyWith(
        title: streamHeightFamilyTitle(primary.title),
        qualities: options,
      ),
    );
  }

  out.addAll(singles);
  out.sort((a, b) {
    final pr =
        streamSourcePlayPriority(a).compareTo(streamSourcePlayPriority(b));
    if (pr != 0) return pr;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return out;
}

class StreamResult {
  final List<StreamSource> sources;
  final String provider;
  final bool isRateLimited;
  final String? primaryUrl;
  final Map<String, String>? headers;

  StreamResult({
    required this.sources,
    required this.provider,
    this.isRateLimited = false,
    this.primaryUrl,
    this.headers,
  });

  String get url => primaryUrl ?? (sources.isNotEmpty ? sources.first.url : '');
}
