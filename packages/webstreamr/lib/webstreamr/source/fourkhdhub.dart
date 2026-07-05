/// Port of webstreamr/src/source/FourKHDHub.ts
library;

import 'package:html/parser.dart' as html_parser;

import '../types.dart';
import '../utils/hd_hub_helper.dart';
import '../utils/id.dart';
import '../utils/tmdb.dart';
import '../webstreamr_parse.dart';
import 'source.dart';

int _levenshtein(String a, String b) {
  final s = a.toLowerCase();
  final t = b.toLowerCase();
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;
  final prev = List<int>.generate(t.length + 1, (i) => i);
  final cur = List<int>.filled(t.length + 1, 0);
  for (var i = 0; i < s.length; i++) {
    cur[0] = i + 1;
    for (var j = 0; j < t.length; j++) {
      final cost = s.codeUnitAt(i) == t.codeUnitAt(j) ? 0 : 1;
      cur[j + 1] =
          [cur[j] + 1, prev[j + 1] + 1, prev[j] + cost].reduce((a, b) => a < b ? a : b);
    }
    for (var k = 0; k <= t.length; k++) {
      prev[k] = cur[k];
    }
  }
  return prev[t.length];
}

class FourKHDHubSource extends Source {
  FourKHDHubSource(super.fetcher);

  @override
  String get id => '4khdhub';
  @override
  String get label => '4KHDHub';
  @override
  List<String> get contentTypes => const ['movie', 'series'];
  @override
  List<CountryCode> get countryCodes => const [
        CountryCode.multi,
        CountryCode.hi,
        CountryCode.ta,
        CountryCode.te,
      ];
  @override
  String get baseUrl => 'https://4khdhub.dad';

  Uri? _resolvedBase;
  DateTime? _resolvedAt;
  Future<Uri> _getBaseUrl(Context ctx) async {
    final now = DateTime.now();
    if (_resolvedBase != null &&
        _resolvedAt != null &&
        now.difference(_resolvedAt!) < const Duration(hours: 1)) {
      return _resolvedBase!;
    }
    _resolvedBase = await fetcher.getFinalRedirectUrl(ctx, Uri.parse(baseUrl));
    _resolvedAt = now;
    return _resolvedBase!;
  }

  @override
  Future<List<SourceResult>> handleInternal(
      Context ctx, String type, Id id) async {
    final tmdbId = await getTmdbId(ctx, fetcher, id);
    final pageUrl = await _fetchPageUrl(ctx, tmdbId);
    if (pageUrl == null) return const [];

    final html = await fetcher.text(ctx, pageUrl);

    final rust = requireRustParseSourceHtml(
      this.id,
      html,
      referer: pageUrl.toString(),
      isSeries: tmdbId.season != null,
      season: tmdbId.season,
      episode: tmdbId.episode,
    );
    final out = <SourceResult>[];
    for (final r in rust) {
      final resolved = await resolveRedirectUrl(ctx, fetcher, r.url);
      out.add(SourceResult(url: resolved, meta: r.meta));
    }
    return out;
  }

  Future<Uri?> _fetchPageUrl(Context ctx, TmdbId tmdbId) async {
    final ny = await getTmdbNameAndYear(ctx, fetcher, tmdbId);
    final name = ny[0] as String;
    final year = ny[1] as int;
    final base = await _getBaseUrl(ctx);
    final searchUrl =
        Uri.parse('$base?s=${Uri.encodeComponent(name)}');
    final html = await fetcher.text(ctx, searchUrl);
    final doc = html_parser.parse(html);

    final wantSeries = tmdbId.season != null;

    for (final card in doc.querySelectorAll('.movie-card')) {
      final fmt = card.querySelector('.movie-card-format')?.text ?? '';
      if (wantSeries && !fmt.contains('Series')) continue;
      if (!wantSeries && !fmt.contains('Movies')) continue;

      final cardYear =
          int.tryParse(card.querySelector('.movie-card-meta')?.text ?? '');
      if (cardYear == null || (cardYear - year).abs() > 1) continue;

      final cardTitle = (card.querySelector('.movie-card-title')?.text ?? '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();
      final diff = _levenshtein(cardTitle, name);
      final ok = diff < 5 || (cardTitle.contains(name) && diff < 16);
      if (!ok) continue;

      final href = card.attributes['href'];
      if (href == null) continue;
      return Uri.parse(href).hasScheme ? Uri.parse(href) : base.resolve(href);
    }
    return null;
  }
}
