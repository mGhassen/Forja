/// VegaMovies — Hindi-English dual audio movies & series.
///
/// Workflow:
///   1. Search by IMDb id (or fallback to title) via /search.php (Typesense
///      proxy). Hits provide a `permalink` to the post page.
///   2. Fetch the post page. Each download button links to nexdrive.pro.
///   3. Fetch each nexdrive page. It exposes 3 mirrors per quality:
///        - fastdl.zip   (G-Direct)
///        - vcloud.zip   (V-Cloud, identical engine to HubCloud)
///        - filebee.xyz  (Filepress)
///      We surface the vcloud.zip URL and let the HubCloud extractor finish
///      it (vcloud uses the same `gamerxyt.com/hubcloud.php` endpoint).
library;

import 'package:html/parser.dart' as html_parser;

import '../types.dart';
import '../utils/fetcher.dart';
import '../utils/id.dart';
import '../utils/resolution.dart';
import '../utils/tmdb.dart';
import 'source.dart';

class VegaMoviesSource extends Source {
  VegaMoviesSource(super.fetcher);

  @override
  String get id => 'vegamovies';
  @override
  String get label => 'VegaMovies';
  @override
  List<String> get contentTypes => const ['movie', 'series'];
  @override
  List<CountryCode> get countryCodes => const [
        CountryCode.multi,
        CountryCode.hi,
        CountryCode.en,
      ];
  @override
  String get baseUrl => 'https://vegamovies.market';

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final imdbId = await getImdbId(ctx, fetcher, id);
    final pageUrls = await _searchByImdb(ctx, imdbId);
    if (pageUrls.isEmpty) return const [];

    final lists = await Future.wait(
        pageUrls.map((u) => _handlePage(ctx, u, imdbId)));
    return lists.expand((e) => e).toList();
  }

  /// True if [text] references the requested [season]. Matches
  /// `Season N`, `Season NN`, `S0N`, and ranges like `Seasons 1 - 10`.
  static bool _seasonMatches(String text, int season) {
    final s = season.toString();
    if (RegExp(r'\bSeason\s*0*' + s + r'\b', caseSensitive: false)
        .hasMatch(text)) {
      return true;
    }
    if (RegExp(r'\bS0?' + s + r'\b', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    final rangeRe =
        RegExp(r'Seasons?\s+(\d{1,2})\s*[-\u2013\u2014]\s*(\d{1,2})',
            caseSensitive: false);
    for (final m in rangeRe.allMatches(text)) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      if (season >= a && season <= b) return true;
    }
    return false;
  }

  Future<List<Uri>> _searchByImdb(Context ctx, ImdbId imdbId) async {
    final searchUrl = Uri.parse(
        '$baseUrl/search.php?q=${Uri.encodeComponent(imdbId.id)}&page=1');
    final resp = await fetcher.json(ctx, searchUrl,
        FetcherRequestConfig(headers: {'Referer': baseUrl})) as Map<String, dynamic>;

    final hits = (resp['hits'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final out = <Uri>[];
    for (final hit in hits) {
      final doc = hit['document'] as Map<String, dynamic>;
      if (doc['imdb_id'] != imdbId.id) continue;
      final postTitle = doc['post_title'] as String? ?? '';
      // Skip trailer / news posts.
      final lower = postTitle.toLowerCase();
      if (lower.contains('trailer') || lower.contains('coming soon')) continue;

      if (imdbId.season != null) {
        if (!_seasonMatches(postTitle, imdbId.season!)) continue;
      } else {
        // For movies, drop posts that look like series.
        if (postTitle.contains('Season ') || RegExp(r'\bS\d{1,2}\b').hasMatch(postTitle)) {
          continue;
        }
      }
      final permalink = doc['permalink'] as String;
      out.add(Uri.parse(permalink).hasScheme
          ? Uri.parse(permalink)
          : Uri.parse(baseUrl).resolve(permalink));
    }
    return out;
  }

  Future<List<SourceResult>> _handlePage(
      Context ctx, Uri pageUrl, ImdbId imdbId) async {
    final html = await fetcher.text(ctx, pageUrl,
        FetcherRequestConfig(headers: {'Referer': baseUrl}));
    final doc = html_parser.parse(html);

    // VegaMovies posts are dual-audio Hindi-English. Tag accordingly.
    final meta = Meta(
      countryCodes: <CountryCode>{
        CountryCode.multi,
        CountryCode.hi,
        CountryCode.en,
      }.toList(),
      referer: pageUrl.toString(),
    );

    // Collect (nexdrive_url, quality_label) pairs to resolve.
    final targets = <_NexTarget>[];

    if (imdbId.episode == null && imdbId.season == null) {
      // Movie: take every nexdrive link with its preceding header.
      _collectNexdriveTargets(doc.body, targets, null);
    } else {
      // Series. First try episode-specific anchors on the post page itself
      // (rare — most posts only group by season).
      if (imdbId.episode != null) {
        final epStr = '${imdbId.episode}';
        final epPad = epStr.padLeft(2, '0');
        _collectEpisodeTargets(doc.body, epStr, epPad, targets);
      }
      // Then collect every nexdrive link whose nearest preceding header
      // mentions the requested season. Episode filtering happens inside
      // _resolveNexdrive (the nexdrive page lists per-episode links).
      _collectNexdriveTargets(doc.body, targets, imdbId.season);
    }

    final lists = await Future.wait(targets.map((t) => _resolveNexdrive(
        ctx, t.url, t.label, pageUrl, meta, imdbId.episode)));
    return lists.expand((e) => e).toList();
  }

  void _collectNexdriveTargets(
      dynamic root, List<_NexTarget> out, int? season) {
    if (root == null) return;
    final seen = out.map((t) => t.url.toString()).toSet();
    for (final a in root.querySelectorAll('a[href*="nexdrive."]')) {
      final href = a.attributes['href'];
      if (href == null || !seen.add(href)) continue;
      // Try to find the nearest preceding header for a quality label.
      String label = '';
      var p = a.parent;
      while (p != null) {
        var sib = p.previousElementSibling;
        while (sib != null) {
          final tag = sib.localName ?? '';
          if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
            label = sib.text.trim();
            break;
          }
          sib = sib.previousElementSibling;
        }
        if (label.isNotEmpty) break;
        p = p.parent;
      }
      // For series, restrict to nexdrive links whose preceding header
      // references the requested season.
      if (season != null && !_seasonMatches(label, season)) continue;
      // When fetching a single episode skip explicit batch / zip packs.
      final anchorText = a.text.toString().toLowerCase();
      if (season != null &&
          (anchorText.contains('batch') ||
              anchorText.contains('zip') ||
              anchorText.contains('complete'))) {
        continue;
      }
      out.add(_NexTarget(Uri.parse(href), label));
    }
  }

  void _collectEpisodeTargets(
      dynamic root, String epStr, String epPad, List<_NexTarget> out) {
    if (root == null) return;
    final seen = <String>{};
    final headers = root.querySelectorAll('h1, h2, h3, h4, h5, h6');
    for (final h in headers) {
      final t = h.text;
      final hasEp = t.contains('Episode $epStr') ||
          t.contains('Episode $epPad') ||
          t.contains('EPISODE $epStr') ||
          t.contains('EPISODE $epPad') ||
          t.contains('EPiSODE $epStr') ||
          t.contains('EPiSODE $epPad');
      if (!hasEp) continue;
      final label = h.text.trim();
      var n = h.nextElementSibling;
      while (n != null) {
        final tag = n.localName ?? '';
        if (RegExp(r'^h[1-6]$').hasMatch(tag) || tag == 'hr') break;
        for (final a in n.querySelectorAll('a[href*="nexdrive."]')) {
          final href = a.attributes['href'];
          if (href == null || !seen.add(href)) continue;
          out.add(_NexTarget(Uri.parse(href), label));
        }
        n = n.nextElementSibling;
      }
    }
  }

  Future<List<SourceResult>> _resolveNexdrive(Context ctx, Uri nexUrl,
      String label, Uri refererUrl, Meta meta, int? episode) async {
    try {
      final html = await fetcher.text(ctx, nexUrl,
          FetcherRequestConfig(headers: {'Referer': refererUrl.toString()}));
      // If targeting a specific episode, narrow the HTML window to the
      // matching `-:Episode(s): N:-` section before pulling vcloud links.
      String scope = html;
      if (episode != null) {
        scope = _episodeSlice(html, episode) ?? '';
        if (scope.isEmpty) return const [];
      }
      // Pull all vcloud.zip mirrors. Prefer those — they map to the HubCloud
      // engine. fastdl/filebee are skipped (no standalone extractors yet).
      final out = <SourceResult>[];
      final seen = <String>{};
      for (final m
          in RegExp(r'href="(https?://[^"]*vcloud[^"]+)"').allMatches(scope)) {
        final href = m.group(1)!;
        if (!seen.add(href)) continue;
        final m2 = meta.clone();
        m2.referer = nexUrl.toString();
        // Tag with quality from header text if available.
        final h = findHeight(label);
        if (h != null) m2.height = h;
        if (label.isNotEmpty) m2.title = label;
        out.add(SourceResult(url: Uri.parse(href), meta: m2));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Extract the HTML between the `-:Episode(s): N:-` header for [episode]
  /// and the next episode header (or end-of-document). Returns null when no
  /// such section exists.
  static String? _episodeSlice(String html, int episode) {
    // Match "Episode" or "Episodes" followed by the number (with or without
    // a leading zero) framed by colons / dashes.
    final headerRe = RegExp(
        r'(?:-\s*:|:)\s*Episodes?\s*:?\s*0*(\d{1,3})\s*:?\s*-?',
        caseSensitive: false);
    final matches = headerRe.allMatches(html).toList();
    for (var i = 0; i < matches.length; i++) {
      final n = int.tryParse(matches[i].group(1) ?? '');
      if (n != episode) continue;
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : html.length;
      return html.substring(start, end);
    }
    return null;
  }
}

class _NexTarget {
  final Uri url;
  final String label;
  _NexTarget(this.url, this.label);
}
