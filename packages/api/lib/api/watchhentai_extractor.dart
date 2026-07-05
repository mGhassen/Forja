import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Extractor for watchhentai.net.
///
/// Pipeline:
///   1. GET /?s=<title>          → parse <div class="result-item"> entries
///                                  scoped to the csearch...sidebar region
///                                  (avoids related-posts sidebar noise).
///   2. Score each (title, url) result vs every candidate title using
///      a stopword-filtered Jaccard similarity. Best score wins;
///      threshold 0.50 to reject WordPress's body-content false matches.
///   3. GET `/series/<slug>/`      → find `/videos/<slug>-episode-N-…`
///   4. GET `/videos/<ep-slug>/`   → regex jwplayer iframe → direct MP4
class WatchHentaiResult {
  final String url;
  final String referer;
  final String origin;
  WatchHentaiResult({required this.url, required this.referer, required this.origin});
}

class _SearchHit {
  final String url;
  final String title;
  _SearchHit(this.url, this.title);
}

class WatchHentaiExtractor {
  static const _origin = 'https://watchhentai.net';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  // Tokens stripped before scoring — they don't carry identity.
  // Includes English articles/prepositions, common Japanese particles
  // that survive romanization, and edition/decoration markers.
  static const _stopwords = <String>{
    'a', 'an', 'the', 'of', 'and', 'or', 'to', 'in', 'on', 'at',
    'for', 'with', 'by', 'from', 'is', 'it',
    'no', 'wa', 'ga', 'ni', 'o', 'wo', 'de', 'mo', 'ka', 'ya',
    'na', 'e', 'he', 'te', 'ne',
    'animation', 'anime', 'motion', 'ova', 'ona', 'tv', 'special',
    'version', 'edition', 'dubbed', 'subbed', 'sub', 'dub',
    'uncensored', 'censored', 'episode', 'ep', 'season',
    // Japanese sub-title markers ("X side Y" = "X from Y's POV";
    // "X part Y" = arc marker). Source usually drops these.
    'side', 'part', 'arc', 'chapter', 'vol', 'volume',
  };

  final HttpClient _http = HttpClient()
    ..userAgent = _ua
    ..connectionTimeout = const Duration(seconds: 15);

  void _setHeaders(HttpClientRequest req, {String? referer}) {
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept',
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8');
    req.headers.set('Accept-Language', 'en-US,en;q=0.9');
    req.headers.set('Cache-Control', 'no-cache');
    if (referer != null) req.headers.set('Referer', referer);
  }

  Future<String?> _get(String url, {String? referer}) async {
    try {
      final req = await _http.getUrl(Uri.parse(url));
      _setHeaders(req, referer: referer);
      final resp = await req.close().timeout(const Duration(seconds: 25));
      if (resp.statusCode != 200) {
        debugPrint('[WatchHentai] $url HTTP ${resp.statusCode}');
        await resp.drain<void>();
        return null;
      }
      return await resp.transform(const SystemEncoding().decoder).join();
    } catch (e) {
      debugPrint('[WatchHentai] GET $url error: $e');
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

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&#8217;', '\u2019')
      .replaceAll('&#8220;', '\u201C')
      .replaceAll('&#8221;', '\u201D')
      .replaceAll('&#8211;', '\u2013')
      .replaceAll('&#8212;', '\u2014')
      .replaceAll('&#8230;', '\u2026')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  /// Generate trimmed forms of a title.
  /// AniList/MAL titles are often verbose ("Foo!: Bar de Baz the Animation")
  /// while watchhentai uses the short form ("Foo!"). We need both for search
  /// (WordPress returns 0 hits on long queries) and for scoring.
  List<String> _titleVariants(String t) {
    final out = <String>{t.trim()};
    // Split on punctuation/separators that mark a subtitle.
    for (final pat in [
      RegExp(r'[:–—]'),    // colon, en/em dash
      RegExp(r'\s+~'),          // space + tilde
      RegExp(r'\s+-\s+'),       // " - "
      RegExp(r'\s*\('),         // parenthesis
      RegExp(r'\s*/'),          // slash
      // " side " / " part " / " arc " subtitle markers (case-insensitive).
      RegExp(r'\s+(?:side|part|arc)\s+', caseSensitive: false),
    ]) {
      final m = pat.firstMatch(t);
      if (m != null && m.start > 0) {
        out.add(t.substring(0, m.start).trim());
      }
    }
    // Strip trailing decoration: "the animation", "the motion anime", etc.
    final decoStripped = t.replaceAll(
      RegExp(
        r'\s+(?:the\s+)?(?:animation|motion\s+anime|anime|ova|ona|special)\s*$',
        caseSensitive: false,
      ),
      '',
    );
    if (decoStripped != t) out.add(decoStripped.trim());

    // Last-resort variants: just the first 2 / 3 words. Helps WordPress
    // search when the full title returns 0 hits (it does fuzzy matching
    // poorly on long phrases).
    final words = t.trim().split(RegExp(r'\s+'));
    if (words.length > 2) out.add(words.take(2).join(' '));
    if (words.length > 3) out.add(words.take(3).join(' '));

    return out.where((s) => s.isNotEmpty).toList();
  }

  List<_SearchHit> _parseHits(String html) {
    final start = html.indexOf('csearch');
    if (start < 0) return const [];
    final end = html.indexOf('class="sidebar', start);
    if (end < 0 || end <= start) return const [];
    final region = html.substring(start, end);
    final rx = RegExp(
      r'<div class="result-item"><article>.*?<div class="title">\s*<a href="([^"]+)">([^<]+)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final hits = <_SearchHit>[];
    for (final m in rx.allMatches(region)) {
      hits.add(_SearchHit(m.group(1)!, _decodeEntities(m.group(2)!.trim())));
    }
    return hits;
  }

  double _scoreHit(_SearchHit hit, List<Set<String>> queries) {
    final r = _tokens(hit.title);
    if (r.isEmpty) return 0;
    double best = 0;
    for (final q in queries) {
      if (q.isEmpty) continue;
      final inter = r.intersection(q).length;
      if (inter == 0) continue;
      final union = r.length + q.length - inter;
      final j = inter / union;
      if (j > best) best = j;
    }
    return best;
  }

  Future<String?> _findSeries(List<String> titles) async {
    // Expand every input title into its short-form variants. The shortest
    // variants are essential because WordPress returns 0 hits for long
    // queries ("amanee tomodachinchi de konna koto ni naru nante").
    final allVariants = <String>{};
    for (final t in titles) {
      for (final v in _titleVariants(t)) {
        if (v.isNotEmpty) allVariants.add(v);
      }
    }
    if (allVariants.isEmpty) return null;

    // Sort variants shortest-first so the most search-friendly query goes first.
    final orderedVariants = allVariants.toList()
      ..sort((a, b) => a.length.compareTo(b.length));

    // Pre-tokenize ALL variants for scoring.
    final qSets = orderedVariants.map(_tokens).where((s) => s.isNotEmpty).toList();
    if (qSets.isEmpty) return null;

    final triedQueries = <String>{};
    final allHits = <_SearchHit>[];
    // Try up to 4 variants — stop early on a perfect match.
    for (final q in orderedVariants.take(4)) {
      final key = q.toLowerCase();
      if (!triedQueries.add(key)) continue;
      final html = await _get('$_origin/?s=${Uri.encodeQueryComponent(q)}');
      if (html == null) continue;
      final hits = _parseHits(html);
      debugPrint('[WatchHentai] search "$q" -> ${hits.length} hits');
      for (final h in hits) {
        if (allHits.any((x) => x.url == h.url)) continue;
        allHits.add(h);
      }
      if (hits.isNotEmpty) {
        final s = _scoreHit(hits.first, qSets);
        if (s >= 0.99) break;
      }
    }
    if (allHits.isEmpty) return null;

    _SearchHit? best;
    double bestScore = -1;
    int bestLen = 1 << 30;
    for (final h in allHits) {
      final s = _scoreHit(h, qSets);
      final len = _tokens(h.title).length;
      if (s > bestScore || (s == bestScore && len < bestLen)) {
        bestScore = s;
        best = h;
        bestLen = len;
      }
    }

    debugPrint('[WatchHentai] best: "${best!.title}" score=${bestScore.toStringAsFixed(2)}');
    if (bestScore < 0.50) {
      debugPrint('[WatchHentai] best score below threshold, no match');
      return null;
    }
    return best.url;
  }

  String? _pickEpisode(String seriesHtml, int ep) {
    final all = RegExp(r'/videos/([a-z0-9\-]+-episode-(\d+)[a-z0-9\-]*)/?',
            caseSensitive: false)
        .allMatches(seriesHtml)
        .map((m) => '/videos/${m.group(1)!}/')
        .toSet()
        .toList();
    final epStr = ep.toString();
    final matching = all.where((u) {
      final m = RegExp(r'-episode-(\d+)').firstMatch(u);
      return m != null && m.group(1) == epStr;
    }).toList();
    if (matching.isEmpty) {
      debugPrint('[WatchHentai] no episode $ep in series');
      return null;
    }
    matching.sort((a, b) {
      int score(String u) {
        var s = 0;
        if (u.contains('dubbed')) s -= 100;
        if (u.contains('uncensored')) s -= 10;
        return s;
      }
      return score(a).compareTo(score(b));
    });
    return '$_origin${matching.first}';
  }

  String? _extractStreamUrl(String videoHtml) {
    final m = RegExp(
      r'''(?:data-litespeed-src|src)\s*=\s*['"](https?://watchhentai\.net/jwplayer/\?source=[^'"]+)''',
      caseSensitive: false,
    ).firstMatch(videoHtml);
    if (m == null) return null;
    return _decodeEntities(m.group(1)!);
  }

  /// Parse the jwplayer iframe page for the real `sources:` array.
  /// The `?source=...mp4` URL on the wrapper iframe is a placeholder
  /// (returns 404 on hstorage.xyz). The actual playable URLs sit in
  /// a JS array inside /jwplayer/?source=… and use `_1080p`/`_720p`/
  /// `_480p` underscore suffixes:
  ///
  ///     sources: [
  ///       file: "https://hstorage.xyz/.../foo-episode-1_1080p.mp4",
  ///       file: "https://hstorage.xyz/.../foo-episode-1_720p.mp4",
  ///       ...
  ///     ]
  String? _pickBestSource(String jwHtml) {
    final all = RegExp(r'''file\s*:\s*["'](https?://[^"']+\.mp4)["']''',
            caseSensitive: false)
        .allMatches(jwHtml)
        .map((m) => m.group(1)!)
        .toList();
    if (all.isEmpty) return null;

    // If multiple sources are listed, prefer ones with explicit quality
    // suffixes (`_1080p.mp4`, `_720p.mp4`, …). The bare URL alongside them
    // is a placeholder that 404s on hstorage.xyz.
    final qualified = all
        .where((u) => RegExp(r'_(\d+)p\.mp4$').hasMatch(u))
        .toList();
    if (qualified.isNotEmpty) {
      qualified.sort((a, b) {
        int q(String u) => int.tryParse(
                RegExp(r'_(\d+)p\.mp4$').firstMatch(u)?.group(1) ?? '0') ??
            0;
        return q(b).compareTo(q(a));
      });
      return qualified.first;
    }

    // No quality variants — series ships a single bare .mp4 that DOES work.
    return all.first;
  }

  Future<WatchHentaiResult?> extract({
    required List<String> titleCandidates,
    required int episode,
  }) async {
    final seriesUrl = await _findSeries(titleCandidates);
    if (seriesUrl == null) return null;
    debugPrint('[WatchHentai] series: $seriesUrl');

    final seriesHtml = await _get(seriesUrl);
    if (seriesHtml == null) return null;
    final videoUrl = _pickEpisode(seriesHtml, episode);
    if (videoUrl == null) return null;
    debugPrint('[WatchHentai] ep=$episode -> $videoUrl');

    final videoHtml = await _get(videoUrl, referer: _origin);
    if (videoHtml == null) return null;
    final jwUrl = _extractStreamUrl(videoHtml);
    if (jwUrl == null) {
      debugPrint('[WatchHentai] no jwplayer iframe in $videoUrl');
      return null;
    }

    // Fetch the jwplayer wrapper page to read the real sources array.
    final jwHtml = await _get(jwUrl, referer: videoUrl);
    if (jwHtml == null) {
      debugPrint('[WatchHentai] jwplayer page failed: $jwUrl');
      return null;
    }
    final stream = _pickBestSource(jwHtml);
    if (stream == null) {
      debugPrint('[WatchHentai] no playable source in jwplayer page');
      return null;
    }
    debugPrint('[WatchHentai] stream: $stream');
    return WatchHentaiResult(
      url: stream,
      referer: '$_origin/',
      origin: _origin,
    );
  }

  void dispose() {
    _http.close(force: true);
  }
}
