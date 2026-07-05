import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// SubtitleCat scraper.
///
/// Mirrors the behaviour of subtitlecat.com:
///   - Search:   `https://www.subtitlecat.com/index.php?search=<query>`
///   - Detail:   `https://www.subtitlecat.com/subs/<id>/<name>.html`
///   - Direct download: `<a id="download_<lang>" href="/subs/<id>/<name>-<lang>.srt">`
///   - Missing language → translate the orig SRT via Google Translate
///     (`translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=<lang>&dt=t&q=<text>`)
///     and reassemble. Replicates `translate_from_server_folder` from
///     `/js/translate.js`.
class SubtitleCatService {
  SubtitleCatService._();
  static final SubtitleCatService instance = SubtitleCatService._();

  static const String _origin = 'https://www.subtitlecat.com';
  static const Map<String, String> _hdrs = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // ── In-memory caches ──────────────────────────────────────────────────────
  final Map<String, List<_SearchHit>> _searchCache = {};
  final Map<String, _DetailPage> _detailCache = {};
  final Map<String, String> _translationCache = {}; // key = origUrl|lang
  final Map<String, Future<String>> _translationInflight = {};

  // ── Public ────────────────────────────────────────────────────────────────

  /// Build the search query that subtitlecat expects.
  /// Movies: "Title Year"  e.g. "Inception 2010"
  /// Shows:  "Title SxxEyy" e.g. "The walking dead S02E12"
  static String buildQuery({
    required String title,
    int? year,
    int? season,
    int? episode,
  }) {
    final cleanTitle = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (season != null && episode != null) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      return '$cleanTitle S${s}E$e';
    }
    if (year != null && year > 0) return '$cleanTitle $year';
    return cleanTitle;
  }

  /// Perform a search and return the enriched subtitle entries that the
  /// SubtitleApi pipeline expects:
  ///   { url, display, language, sourceName }
  ///
  /// [translateBaseUrl] is the localhost base of LocalServerService. When
  /// supplied, missing-language entries are exposed as on-demand translation
  /// URLs pointing to `<translateBaseUrl>/subtitlecat-translate`.
  Future<List<Map<String, dynamic>>> fetchAll({
    required String title,
    int? year,
    int? season,
    int? episode,
    String? translateBaseUrl,
    int maxResults = 8,
  }) async {
    final query = buildQuery(
      title: title,
      year: year,
      season: season,
      episode: episode,
    );

    try {
      final hits = await _search(query);
      if (hits.isEmpty) return [];

      // Best-match heuristic: keep the first N hits in document order.
      // Subtitle Cat's search ranks reasonably well for "Title Year"
      // and "Title SxxEyy" queries — but a single movie/episode can have
      // several different releases (BluRay, WEB, HDRip, etc.), each with
      // its own subtitle file, so we surface all of them.
      final picks = hits.take(maxResults).toList();

      final List<Map<String, dynamic>> out = [];
      final Set<String> seenDirect = {}; // dedupe direct downloads by url
      final Set<String> translatedLangs = {}; // emit each translation once

      // Fetch all chosen detail pages in parallel; null entries = failed fetch.
      final details = await Future.wait(picks.map((h) async {
        try {
          return await _fetchDetail(h.detailUrl);
        } catch (e) {
          debugPrint('[SubtitleCat] detail page failed (${h.detailUrl}): $e');
          return null;
        }
      }));

      for (var i = 0; i < details.length; i++) {
        final detail = details[i];
        if (detail == null) continue;

        // Direct downloads — surface every distinct URL across all hits.
        for (final ln in detail.directLanguages) {
          if (!seenDirect.add(ln.url)) continue;
          out.add({
            'url': ln.url,
            'display':
                '${ln.label} ${i + 1} - subtitlecat',
            'language': ln.code,
            'sourceName': 'subtitlecat',
          });
        }

        // Translation entries — accept from any hit, but only emit the
        // first (best) translation per language so we don't waste time
        // running the same Google-Translate batch multiple times.
        if (translateBaseUrl != null) {
          for (final ln in detail.translatableLanguages) {
            if (translatedLangs.contains(ln.code)) continue;
            // Skip languages that we already have a direct download for.
            if (detail.directLanguages.any((d) => d.code == ln.code)) {
              continue;
            }
            translatedLangs.add(ln.code);

            final origUrl =
                '$_origin${detail.folder}${detail.origFilename}';
            final tUrl = Uri.parse('$translateBaseUrl/subtitlecat-translate')
                .replace(queryParameters: {
              'orig': origUrl,
              'tl': ln.code,
              'name': detail.baseName,
            }).toString();

            out.add({
              'url': tUrl,
              'display': '${ln.label} (translated) - subtitlecat',
              'language': ln.code,
              'sourceName': 'subtitlecat',
              'translated': true,
            });
          }
        }
      }

      return out;
    } catch (e) {
      debugPrint('[SubtitleCat] fetchAll error: $e');
      return [];
    }
  }

  /// Translate the orig SRT at [origUrl] into [targetLang] and return the
  /// assembled SRT text. Uses Google Translate's free `translate_a/single`
  /// endpoint, exactly like subtitlecat's /js/translate.js.
  Future<String> translateSrt({
    required String origUrl,
    required String targetLang,
  }) async {
    final key = '$origUrl|$targetLang';
    final cached = _translationCache[key];
    if (cached != null) return cached;

    final inflight = _translationInflight[key];
    if (inflight != null) return inflight;

    final fut = _translateSrtInternal(origUrl: origUrl, targetLang: targetLang);
    _translationInflight[key] = fut;
    try {
      final res = await fut;
      _translationCache[key] = res;
      return res;
    } finally {
      _translationInflight.remove(key);
    }
  }

  // ── Internal: search ──────────────────────────────────────────────────────

  Future<List<_SearchHit>> _search(String query) async {
    final cached = _searchCache[query];
    if (cached != null) return cached;

    final url = Uri.parse('$_origin/index.php')
        .replace(queryParameters: {'search': query})
        .toString();

    final res = await http.get(Uri.parse(url), headers: _hdrs);
    if (res.statusCode != 200) {
      throw HttpException('search ${res.statusCode}');
    }
    final hits = _parseSearchResults(res.body);
    _searchCache[query] = hits;
    return hits;
  }

  static List<_SearchHit> _parseSearchResults(String html) {
    // Anchor pattern: <a href="subs/<id>/<name>.html"
    final re = RegExp(
      r'<a\s+href="(subs/(\d+)/([^"]+\.html))"[^>]*>([^<]*)</a>',
      caseSensitive: false,
    );
    final out = <_SearchHit>[];
    final seen = <String>{};
    for (final m in re.allMatches(html)) {
      final relPath = m.group(1)!;
      if (!seen.add(relPath)) continue;
      out.add(_SearchHit(
        detailUrl: '$_origin/$relPath',
        title: _stripHtml(m.group(4) ?? ''),
      ));
    }
    return out;
  }

  // ── Internal: detail page ─────────────────────────────────────────────────

  Future<_DetailPage> _fetchDetail(String detailUrl) async {
    final cached = _detailCache[detailUrl];
    if (cached != null) return cached;

    final res = await http.get(Uri.parse(detailUrl), headers: _hdrs);
    if (res.statusCode != 200) {
      throw HttpException('detail ${res.statusCode}');
    }
    final parsed = _parseDetailPage(res.body);
    _detailCache[detailUrl] = parsed;
    return parsed;
  }

  static _DetailPage _parseDetailPage(String html) {
    // Direct downloads:
    //   <a id="download_<code>" ... href="/subs/<id>/<name>-<code>.srt" ...>
    final dlRe = RegExp(
      r'<a\s+id="download_([A-Za-z0-9-]+)"[^>]*href="(/subs/\d+/[^"]+\.srt)"',
      caseSensitive: false,
    );
    final directs = <_LangEntry>[];
    final directCodes = <String>{};
    for (final m in dlRe.allMatches(html)) {
      final code = m.group(1)!;
      final href = m.group(2)!;
      directs.add(_LangEntry(
        code: _normalizeLang(code),
        label: _languageLabel(code),
        url: '$_origin$href',
      ));
      directCodes.add(_normalizeLang(code));
    }

    // Translatable languages + the orig file/folder used by every Translate
    // button on the page:
    //   onclick="translate_from_server_folder('<code>', '<file-orig.srt>', '<folder>')"
    final trRe = RegExp(
      r"translate_from_server_folder\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*\)",
      caseSensitive: false,
    );
    final translatables = <_LangEntry>[];
    String folder = '';
    String origFilename = '';
    for (final m in trRe.allMatches(html)) {
      final code = m.group(1)!;
      origFilename = m.group(2)!;
      folder = m.group(3)!; // already starts and ends with '/'
      final norm = _normalizeLang(code);
      if (directCodes.contains(norm)) continue;
      translatables.add(_LangEntry(
        code: norm,
        label: _languageLabel(code),
      ));
    }

    // If we have direct downloads but never saw a Translate button, derive
    // folder/filename from the first direct .srt URL so on-demand translation
    // can still work for additional languages.
    if (folder.isEmpty && directs.isNotEmpty) {
      final href = Uri.parse(directs.first.url).path; // /subs/<id>/<name>-en.srt
      final lastSlash = href.lastIndexOf('/');
      folder = '${href.substring(0, lastSlash)}/';
      final fname = href.substring(lastSlash + 1);
      // Strip "-<lang>.srt" → "<base>"
      final dashLang = RegExp(r'-([A-Za-z0-9-]+)\.srt$');
      final base = fname.replaceFirst(dashLang, '');
      origFilename = '$base-orig.srt';
    }

    final baseName = origFilename.replaceFirst(RegExp(r'-orig\.srt$'), '');
    return _DetailPage(
      directLanguages: directs,
      translatableLanguages: translatables,
      folder: folder,
      origFilename: origFilename,
      baseName: baseName,
    );
  }

  // ── Internal: translation pipeline ────────────────────────────────────────

  Future<String> _translateSrtInternal({
    required String origUrl,
    required String targetLang,
  }) async {
    final res = await http.get(Uri.parse(origUrl), headers: _hdrs);
    if (res.statusCode != 200) {
      throw HttpException('orig ${res.statusCode}');
    }
    // SubtitleCat serves SRT as latin-1 / utf-8 mixed; let the bytes become
    // a String using utf8 with malformed-allowed for safety.
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);

    final srcLines = const LineSplitter().convert(body);
    final translated = List<String>.filled(srcLines.length, '');

    // Build translation batches just like translate_file() in /js/translate.js.
    const int charsPerBatch = 500;
    final List<String> batches = [];
    final List<List<int>> linesInBatch = [];

    final numRe = RegExp(r'^[0-9 \r]*$');
    final tsRe = RegExp(r'^[0-9,: ]*-->[0-9,: \r]*$');

    String curBatch = '';
    int curChars = 0;
    List<int> curIndices = [];

    void flush() {
      if (curIndices.isEmpty && curBatch.isEmpty) return;
      batches.add(curBatch);
      linesInBatch.add(curIndices);
      curBatch = '';
      curChars = 0;
      curIndices = [];
    }

    for (var i = 0; i < srcLines.length; i++) {
      final line = srcLines[i];
      if (numRe.hasMatch(line) || tsRe.hasMatch(line)) {
        translated[i] = line;
        continue;
      }
      final cleaned = line
          .replaceAll(RegExp(r'<font[^>]*>', caseSensitive: false), '')
          .replaceAll(RegExp(r'</font>', caseSensitive: false), '')
          .replaceAll('&', 'and');
      if (curChars + cleaned.length + 1 < charsPerBatch) {
        if (curBatch.isEmpty) {
          curBatch = cleaned;
        } else {
          curBatch = '$curBatch\n$cleaned';
        }
        curChars += cleaned.length + 1;
        curIndices.add(i);
      } else {
        flush();
        curBatch = cleaned;
        curChars = cleaned.length + 1;
        curIndices.add(i);
      }
    }
    flush();

    debugPrint(
      '[SubtitleCat] translating 1 SRT (${srcLines.length} lines, '
      '${batches.length} chunks) → $targetLang',
    );

    // Process batches with bounded concurrency. Google's gtx endpoint is
    // happy with ~6-8 in-flight requests; running them serially makes long
    // SRTs hang for minutes.
    const int parallel = 8;
    int nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final b = nextIndex;
        if (b >= batches.length) return;
        nextIndex++;
        final batch = batches[b];
        final indices = linesInBatch[b];
        if (indices.isEmpty) continue;
        try {
          final translatedLines = await _translateBatch(batch, targetLang);
          if (translatedLines.length == indices.length) {
            for (var k = 0; k < indices.length; k++) {
              translated[indices[k]] = translatedLines[k];
            }
          } else {
            // Mismatch fallback: translate each non-empty line individually.
            final origPieces = batch.split('\n');
            for (var k = 0; k < indices.length; k++) {
              final src = k < origPieces.length ? origPieces[k] : '';
              if (src.trim().isEmpty) {
                translated[indices[k]] = src;
                continue;
              }
              try {
                final one = await _translateBatch(src, targetLang);
                translated[indices[k]] =
                    one.isNotEmpty ? one.join('\n') : src;
              } catch (_) {
                translated[indices[k]] = src;
              }
            }
          }
        } catch (e) {
          debugPrint('[SubtitleCat] batch $b failed: $e');
          // Leave originals on failure rather than aborting the whole job.
          final origPieces = batch.split('\n');
          for (var k = 0; k < indices.length; k++) {
            translated[indices[k]] =
                k < origPieces.length ? origPieces[k] : '';
          }
        }
      }
    }

    await Future.wait(List.generate(parallel, (_) => worker()));

    return '${translated.join('\n')}\n';
  }

  Future<List<String>> _translateBatch(String text, String tl) async {
    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single',
    ).replace(queryParameters: {
      'client': 'gtx',
      'sl': 'auto',
      'tl': tl,
      'dt': 't',
      'q': text,
    });

    final res = await http.get(uri, headers: const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
      'Accept': '*/*',
    });
    if (res.statusCode != 200) {
      throw HttpException('gtx ${res.statusCode}');
    }
    // Response: [[["translated\n",...],...], null, "en"]
    final dynamic root = json.decode(res.body);
    if (root is! List || root.isEmpty || root[0] is! List) return const [];
    final segments = root[0] as List;
    final buf = StringBuffer();
    for (final seg in segments) {
      if (seg is List && seg.isNotEmpty && seg[0] is String) {
        buf.write(seg[0] as String);
      }
    }
    final assembled = buf.toString();
    return assembled.split('\n');
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  /// Map subtitlecat's lang codes to a normalized form. SC uses several
  /// non-standard codes (e.g. iw=he, jw=jv, zh-CN, zh-TW). Keep them as the
  /// upstream code (we already pass them to Google Translate verbatim).
  static String _normalizeLang(String code) {
    final c = code.toLowerCase();
    const remap = {'iw': 'he', 'jw': 'jv', 'in': 'id'};
    return remap[c] ?? c;
  }

  static String _languageLabel(String code) {
    const map = {
      'af': 'Afrikaans', 'ak': 'Akan', 'sq': 'Albanian', 'am': 'Amharic',
      'ar': 'Arabic', 'hy': 'Armenian', 'az': 'Azerbaijani', 'eu': 'Basque',
      'be': 'Belarusian', 'bem': 'Bemba', 'bn': 'Bengali', 'bh': 'Bihari',
      'bs': 'Bosnian', 'br': 'Breton', 'bg': 'Bulgarian', 'km': 'Cambodian',
      'ca': 'Catalan', 'ceb': 'Cebuano', 'chr': 'Cherokee', 'ny': 'Chichewa',
      'zh-cn': 'Chinese (S)', 'zh-tw': 'Chinese (T)', 'co': 'Corsican',
      'hr': 'Croatian', 'cs': 'Czech', 'da': 'Danish', 'nl': 'Dutch',
      'en': 'English', 'eo': 'Esperanto', 'et': 'Estonian', 'ee': 'Ewe',
      'fo': 'Faroese', 'tl': 'Filipino', 'fi': 'Finnish', 'fr': 'French',
      'fy': 'Frisian', 'gaa': 'Ga', 'gl': 'Galician', 'ka': 'Georgian',
      'de': 'German', 'el': 'Greek', 'gn': 'Guarani', 'gu': 'Gujarati',
      'ht': 'Haitian', 'ha': 'Hausa', 'haw': 'Hawaiian', 'iw': 'Hebrew',
      'he': 'Hebrew', 'hi': 'Hindi', 'hmn': 'Hmong', 'hu': 'Hungarian',
      'is': 'Icelandic', 'ig': 'Igbo', 'id': 'Indonesian', 'in': 'Indonesian',
      'ia': 'Interlingua', 'ga': 'Irish', 'it': 'Italian', 'ja': 'Japanese',
      'jw': 'Javanese', 'jv': 'Javanese', 'kn': 'Kannada', 'kk': 'Kazakh',
      'rw': 'Kinyarwanda', 'rn': 'Kirundi', 'kg': 'Kongo', 'ko': 'Korean',
      'kri': 'Krio', 'ku': 'Kurdish', 'ckb': 'Kurdish (Sorani)', 'ky': 'Kyrgyz',
      'lo': 'Laothian', 'la': 'Latin', 'lv': 'Latvian', 'ln': 'Lingala',
      'lt': 'Lithuanian', 'loz': 'Lozi', 'lg': 'Luganda', 'ach': 'Luo',
      'lb': 'Luxembourgish', 'mk': 'Macedonian', 'mg': 'Malagasy',
      'ms': 'Malay', 'ml': 'Malayalam', 'mt': 'Maltese', 'mi': 'Maori',
      'mr': 'Marathi', 'mfe': 'Mauritian Creole', 'mo': 'Moldavian',
      'mn': 'Mongolian', 'sr-me': 'Montenegrin', 'my': 'Burmese',
      'ne': 'Nepali', 'pcm': 'Nigerian Pidgin', 'nso': 'Northern Sotho',
      'no': 'Norwegian', 'nn': 'Norwegian Nynorsk', 'oc': 'Occitan',
      'or': 'Oriya', 'om': 'Oromo', 'ps': 'Pashto', 'fa': 'Persian',
      'pl': 'Polish', 'pt': 'Portuguese', 'pt-br': 'Portuguese (BR)',
      'pt-pt': 'Portuguese (PT)', 'pa': 'Punjabi', 'qu': 'Quechua',
      'ro': 'Romanian', 'rm': 'Romansh', 'nyn': 'Runyakitara', 'ru': 'Russian',
      'gd': 'Scots Gaelic', 'sr': 'Serbian', 'sh': 'Serbo-Croatian',
      'st': 'Sesotho', 'tn': 'Setswana', 'crs': 'Seychellois Creole',
      'sn': 'Shona', 'sd': 'Sindhi', 'si': 'Sinhalese', 'sk': 'Slovak',
      'sl': 'Slovenian', 'so': 'Somali', 'es': 'Spanish',
      'es-419': 'Spanish (LatAm)', 'su': 'Sundanese', 'sw': 'Swahili',
      'sv': 'Swedish', 'tg': 'Tajik', 'ta': 'Tamil', 'tt': 'Tatar',
      'te': 'Telugu', 'th': 'Thai', 'ti': 'Tigrinya', 'to': 'Tonga',
      'lua': 'Tshiluba', 'tum': 'Tumbuka', 'tr': 'Turkish', 'tk': 'Turkmen',
      'tw': 'Twi', 'ug': 'Uighur', 'uk': 'Ukrainian', 'ur': 'Urdu',
      'uz': 'Uzbek', 'vi': 'Vietnamese', 'cy': 'Welsh', 'wo': 'Wolof',
      'xh': 'Xhosa', 'yi': 'Yiddish', 'yo': 'Yoruba', 'zu': 'Zulu',
    };
    final c = code.toLowerCase();
    return map[c] ?? code;
  }
}

class _SearchHit {
  final String detailUrl;
  final String title;
  _SearchHit({required this.detailUrl, required this.title});
}

class _LangEntry {
  final String code;
  final String label;
  final String url; // empty for translatable-only
  _LangEntry({required this.code, required this.label, this.url = ''});
}

class _DetailPage {
  final List<_LangEntry> directLanguages;
  final List<_LangEntry> translatableLanguages;
  final String folder; // e.g. "/subs/28/"
  final String origFilename; // e.g. "Inception.2010.1080p.BrRip.x264.YIFY-orig.srt"
  final String baseName;
  _DetailPage({
    required this.directLanguages,
    required this.translatableLanguages,
    required this.folder,
    required this.origFilename,
    required this.baseName,
  });
}
