import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Extractor for hentaini.com.
///
/// hentaini.com is a Nuxt 3 SPA backed by a public Strapi v4 API at
/// admin.hentaini.com. Each episode entity carries a JSON-encoded
/// `players` array with multiple sources, including a direct HLS m3u8
/// hosted on the site's own CDN (vs1.yesterdaymail.com).
///
/// Pipeline:
///   1. GET admin.hentaini.com/api/series?filters[title][$containsi]={q}
///      → JSON list of series (id, title, title_english, url, ...).
///   2. Score each candidate by Jaccard token-set similarity vs every
///      input title (with stopword filtering). Threshold 0.45.
///   3. GET admin.hentaini.com/api/series?filters[id]={id}&populate=episodes
///      → episodes list, each with `episode_number` + `players` (JSON string).
///   4. Find the requested episode_number, parse `players`, prefer HLS,
///      fall back to any direct `.mp4` URL among recognized hosts.
class HentainiResult {
  final String url;
  final String referer;
  final String origin;
  HentainiResult({required this.url, required this.referer, required this.origin});
}

class _HSeries {
  final int id;
  final String title;
  final String titleEnglish;
  final String url;
  _HSeries(this.id, this.title, this.titleEnglish, this.url);
}

class HentainiExtractor {
  static const _site = 'https://hentaini.com';
  static const _api = 'https://admin.hentaini.com/api';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  // Same stopword set as WatchHentai — these tokens don't carry identity
  // and only inflate token counts during Jaccard scoring.
  static const _stopwords = <String>{
    'a', 'an', 'the', 'of', 'and', 'or', 'to', 'in', 'on', 'at',
    'for', 'with', 'by', 'from', 'is', 'it',
    'no', 'wa', 'ga', 'ni', 'o', 'wo', 'de', 'mo', 'ka', 'ya',
    'na', 'e', 'he', 'te', 'ne',
    'animation', 'anime', 'motion', 'ova', 'ona', 'tv', 'special',
    'version', 'edition', 'dubbed', 'subbed', 'sub', 'dub',
    'uncensored', 'censored', 'episode', 'ep', 'season',
    'side', 'part', 'arc', 'chapter', 'vol', 'volume',
  };

  final HttpClient _http = HttpClient()
    ..userAgent = _ua
    ..connectionTimeout = const Duration(seconds: 15);

  void _setHeaders(HttpClientRequest req, {String? referer, bool json = false}) {
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept', json ? 'application/json' : '*/*');
    req.headers.set('Accept-Language', 'en-US,en;q=0.9');
    if (referer != null) req.headers.set('Referer', referer);
  }

  Future<String?> _get(String url, {String? referer, bool json = false}) async {
    try {
      final req = await _http.getUrl(Uri.parse(url));
      _setHeaders(req, referer: referer, json: json);
      final resp = await req.close().timeout(const Duration(seconds: 25));
      if (resp.statusCode != 200) {
        debugPrint('[Hentaini] $url HTTP ${resp.statusCode}');
        await resp.drain<void>();
        return null;
      }
      return await resp.transform(const Utf8Decoder()).join();
    } catch (e) {
      debugPrint('[Hentaini] GET $url error: $e');
      return null;
    }
  }

  Set<String> _tokens(String s) {
    final lower = s.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopwords.contains(t))
        .toSet();
  }

  /// Generate trimmed forms of a title (subtitle splits, decoration strip,
  /// short-prefix fallbacks). Same approach as WatchHentai — Strapi's
  /// `$containsi` is a literal substring match, so long noisy titles often
  /// return zero hits.
  List<String> _titleVariants(String t) {
    final out = <String>{t.trim()};
    for (final pat in [
      RegExp(r'[:\u2013\u2014]'),       // colon, en/em dash
      RegExp(r'\s+~'),
      RegExp(r'\s+-\s+'),
      RegExp(r'\s*\('),
      RegExp(r'\s*/'),
      RegExp(r'\s+(?:side|part|arc)\s+', caseSensitive: false),
    ]) {
      final m = pat.firstMatch(t);
      if (m != null && m.start > 0) {
        out.add(t.substring(0, m.start).trim());
      }
    }
    final decoStripped = t.replaceAll(
      RegExp(
        r'\s+(?:the\s+)?(?:animation|motion\s+anime|anime|ova|ona|special)\s*$',
        caseSensitive: false,
      ),
      '',
    );
    if (decoStripped != t) out.add(decoStripped.trim());

    final words = t.trim().split(RegExp(r'\s+'));
    if (words.length > 2) out.add(words.take(2).join(' '));
    if (words.length > 3) out.add(words.take(3).join(' '));

    return out.where((s) => s.isNotEmpty).toList();
  }

  List<_HSeries> _parseSeriesList(String body) {
    try {
      final j = jsonDecode(body);
      final data = j is Map ? j['data'] : null;
      if (data is! List) return const [];
      final out = <_HSeries>[];
      for (final e in data) {
        if (e is! Map) continue;
        final id = e['id'];
        final title = e['title']?.toString() ?? '';
        final titleEn = e['title_english']?.toString() ?? '';
        final url = e['url']?.toString() ?? '';
        if (id is int && url.isNotEmpty) {
          out.add(_HSeries(id, title, titleEn, url));
        }
      }
      return out;
    } catch (e) {
      debugPrint('[Hentaini] series parse: $e');
      return const [];
    }
  }

  double _scoreSeries(_HSeries s, List<Set<String>> queries) {
    final candidates = <Set<String>>[];
    if (s.title.isNotEmpty) candidates.add(_tokens(s.title));
    if (s.titleEnglish.isNotEmpty) candidates.add(_tokens(s.titleEnglish));
    candidates.add(_tokens(s.url.replaceAll('-', ' ')));
    double best = 0;
    for (final r in candidates) {
      if (r.isEmpty) continue;
      for (final q in queries) {
        if (q.isEmpty) continue;
        final inter = r.intersection(q).length;
        if (inter == 0) continue;
        final union = r.length + q.length - inter;
        final j = inter / union;
        if (j > best) best = j;
      }
    }
    return best;
  }

  Future<_HSeries?> _findSeries(List<String> titles) async {
    final allVariants = <String>{};
    for (final t in titles) {
      for (final v in _titleVariants(t)) {
        if (v.isNotEmpty) allVariants.add(v);
      }
    }
    if (allVariants.isEmpty) return null;
    final orderedVariants = allVariants.toList()
      ..sort((a, b) => a.length.compareTo(b.length));

    final qSets = orderedVariants.map(_tokens).where((s) => s.isNotEmpty).toList();
    if (qSets.isEmpty) return null;

    final tried = <String>{};
    final allHits = <_HSeries>[];
    for (final q in orderedVariants.take(4)) {
      final key = q.toLowerCase();
      if (!tried.add(key)) continue;
      final url =
          '$_api/series?filters%5Btitle%5D%5B%24containsi%5D=${Uri.encodeQueryComponent(q)}'
          '&pagination%5Blimit%5D=20';
      final body = await _get(url, json: true, referer: '$_site/');
      if (body == null) continue;
      final hits = _parseSeriesList(body);
      // Also search title_english — Strapi $containsi is per-field.
      final url2 =
          '$_api/series?filters%5Btitle_english%5D%5B%24containsi%5D=${Uri.encodeQueryComponent(q)}'
          '&pagination%5Blimit%5D=20';
      final body2 = await _get(url2, json: true, referer: '$_site/');
      final hits2 = body2 == null ? const <_HSeries>[] : _parseSeriesList(body2);
      debugPrint('[Hentaini] search "$q" -> ${hits.length}+${hits2.length} hits');
      for (final h in [...hits, ...hits2]) {
        if (allHits.any((x) => x.id == h.id)) continue;
        allHits.add(h);
      }
      if (allHits.isNotEmpty) {
        final s = _scoreSeries(allHits.first, qSets);
        if (s >= 0.99) break;
      }
    }
    if (allHits.isEmpty) return null;

    _HSeries? best;
    double bestScore = -1;
    for (final h in allHits) {
      final s = _scoreSeries(h, qSets);
      if (s > bestScore) {
        bestScore = s;
        best = h;
      }
    }
    debugPrint('[Hentaini] best: "${best!.title}" (id=${best.id}) '
        'score=${bestScore.toStringAsFixed(2)}');
    if (bestScore < 0.45) {
      debugPrint('[Hentaini] best below threshold, no match');
      return null;
    }
    return best;
  }

  /// Pick a playable URL from the `players` JSON array.
  ///
  /// Preference order:
  ///   1. `name == "HLS"` (direct m3u8 on site CDN — works without iframe).
  ///   2. Any URL ending in `.mp4` with no embed wrapper.
  ///   3. null — all sources are iframe embeds we don't extract here.
  String? _pickPlayer(String playersJson) {
    try {
      final list = jsonDecode(playersJson);
      if (list is! List) return null;
      String? hls;
      String? mp4;
      for (final p in list) {
        if (p is! Map) continue;
        final name = (p['name'] ?? '').toString().toUpperCase();
        final url = (p['url'] ?? '').toString();
        if (url.isEmpty) continue;
        if (name == 'HLS' && url.endsWith('.m3u8')) {
          hls ??= url;
        } else if (RegExp(r'\.mp4($|\?)').hasMatch(url) &&
            !url.contains('/embed')) {
          mp4 ??= url;
        }
      }
      return hls ?? mp4;
    } catch (e) {
      debugPrint('[Hentaini] players parse: $e');
      return null;
    }
  }

  Future<HentainiResult?> extract({
    required List<String> titleCandidates,
    required int episode,
  }) async {
    final series = await _findSeries(titleCandidates);
    if (series == null) return null;

    final url =
        '$_api/series?filters%5Bid%5D=${series.id}&populate=episodes';
    final body = await _get(url, json: true, referer: '$_site/');
    if (body == null) return null;

    Map<String, dynamic>? targetEp;
    try {
      final j = jsonDecode(body);
      final data = j['data'];
      if (data is! List || data.isEmpty) return null;
      final episodes = data.first['episodes'];
      if (episodes is! List) return null;
      for (final e in episodes) {
        if (e is Map && e['episode_number'] == episode) {
          targetEp = Map<String, dynamic>.from(e);
          break;
        }
      }
    } catch (e) {
      debugPrint('[Hentaini] episodes parse: $e');
      return null;
    }
    if (targetEp == null) {
      debugPrint('[Hentaini] no episode $episode in series ${series.url}');
      return null;
    }

    final players = targetEp['players']?.toString() ?? '';
    if (players.isEmpty) return null;
    final stream = _pickPlayer(players);
    if (stream == null) {
      debugPrint('[Hentaini] no playable HLS/MP4 in episode $episode');
      return null;
    }
    debugPrint('[Hentaini] stream: $stream');
    return HentainiResult(
      url: stream,
      referer: '$_site/',
      origin: _site,
    );
  }

  void dispose() {
    _http.close(force: true);
  }
}
