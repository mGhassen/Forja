import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as hp;
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class BookResult {
  final String title;
  final String series;
  final String author;
  final String publisher;
  final String year;
  final String language;
  final String pages;
  final String size;
  final String format;
  final String isbn;
  final String editionId;
  final String editionUrl;
  final String fileId;
  final List<Map<String, String>> downloadLinks;

  const BookResult({
    required this.title,
    required this.series,
    required this.author,
    required this.publisher,
    required this.year,
    required this.language,
    required this.pages,
    required this.size,
    required this.format,
    required this.isbn,
    required this.editionId,
    required this.editionUrl,
    required this.fileId,
    required this.downloadLinks,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'series': series,
    'author': author,
    'publisher': publisher,
    'year': year,
    'language': language,
    'pages': pages,
    'size': size,
    'format': format,
    'isbn': isbn,
    'editionId': editionId,
    'editionUrl': editionUrl,
    'fileId': fileId,
    'downloadLinks': downloadLinks,
  };

  factory BookResult.fromJson(Map<String, dynamic> json) => BookResult(
    title: json['title'] ?? '',
    series: json['series'] ?? '',
    author: json['author'] ?? '',
    publisher: json['publisher'] ?? '',
    year: json['year'] ?? '',
    language: json['language'] ?? '',
    pages: json['pages'] ?? '',
    size: json['size'] ?? '',
    format: json['format'] ?? '',
    isbn: json['isbn'] ?? '',
    editionId: json['editionId'] ?? '',
    editionUrl: json['editionUrl'] ?? '',
    fileId: json['fileId'] ?? '',
    downloadLinks: (json['downloadLinks'] as List<dynamic>?)
        ?.map((e) => Map<String, String>.from(e as Map))
        .toList() ?? [],
  );
}

class BookEditionDetails {
  final String editionId;
  final String md5;
  final String adsUrl;
  final String? size;
  final String? extension;
  final String? pages;

  const BookEditionDetails({
    required this.editionId,
    required this.md5,
    required this.adsUrl,
    this.size,
    this.extension,
    this.pages,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class BooksService {
  static const String _base = 'https://libgen.li';

  static final _client = http.Client();

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  // ── Search ─────────────────────────────────────────────────────────────────
  // Equivalent to: GET /libgen/search/:query
  // Only returns epub files (mirrors the JS filter).

  Future<List<BookResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
        '$_base/index.php?req=${Uri.encodeComponent(query)}&curtab=f',
      );
      debugPrint('[LibGen] search: $url');

      final response = await _client.get(url, headers: _headers);
      if (response.statusCode != 200) {
        debugPrint('[LibGen] search HTTP ${response.statusCode}');
        return [];
      }

      final document = hp.parse(response.body);
      final results = <BookResult>[];

      // libgen uses multiple table structures; select all tr
      final rows = document.querySelectorAll('table tbody tr, table tr');

      for (final row in rows) {
        final tds = row.querySelectorAll('td');
        if (tds.length < 8) continue;

        final firstTd = tds[0];

        // Title link — must have edition.php href
        final titleLink = firstTd.querySelector('a[href*="edition.php"]');
        if (titleLink == null) continue;

        final title = titleLink.text.trim();
        if (title.isEmpty) continue;

        final editionHref = titleLink.attributes['href'] ?? '';
        final editionIdMatch = RegExp(r'id=(\d+)').firstMatch(editionHref);
        final editionId = editionIdMatch?.group(1);
        if (editionId == null || editionId.isEmpty) continue;

        final series = firstTd.querySelector('b')?.text.trim() ?? '';
        final isbn =
            firstTd.querySelector('font[color="green"]')?.text.trim() ?? '';
        final fileId =
            firstTd.querySelector('.badge-secondary')?.text.trim() ?? '';

        final author    = tds[1].text.trim();
        final publisher = tds[2].text.trim();
        final year      = tds[3].text.trim();
        final language  = tds[4].text.trim();
        final pages     = tds[5].text.trim();

        // size td may have a nested <a>
        final sizeTd = tds[6];
        final size = sizeTd.querySelector('a')?.text.trim().isNotEmpty == true
            ? sizeTd.querySelector('a')!.text.trim()
            : sizeTd.text.trim();

        final format = tds[7].text.trim();

        // Only epub
        if (format.toLowerCase() != 'epub') continue;

        // Download links from td[8] if present
        final downloadLinks = <Map<String, String>>[];
        if (tds.length > 8) {
          final dlTd = tds[8];
          for (final a in dlTd.querySelectorAll('a')) {
            final href = a.attributes['href'] ?? '';
            if (href.isEmpty) continue;
            final linkTitle = a.attributes['data-original-title'] ??
                a.querySelector('.badge')?.text.trim() ??
                '';
            downloadLinks.add({'title': linkTitle, 'href': href});
          }
        }

        results.add(BookResult(
          title: title,
          series: series,
          author: author,
          publisher: publisher,
          year: year,
          language: language,
          pages: pages,
          size: size,
          format: format,
          isbn: isbn,
          editionId: editionId,
          editionUrl: '$_base/edition.php?id=$editionId',
          fileId: fileId,
          downloadLinks: downloadLinks,
        ));
      }

      debugPrint('[LibGen] found ${results.length} epub results');
      return results;
    } catch (e, st) {
      debugPrint('[LibGen] search error: $e\n$st');
      return [];
    }
  }

  // ── Edition details → MD5 ──────────────────────────────────────────────────
  // Equivalent to: GET /libgen/edition/:editionId

  Future<BookEditionDetails?> getEditionDetails(String editionId) async {
    try {
      final url = Uri.parse('$_base/edition.php?id=$editionId');
      debugPrint('[LibGen] edition: $url');

      final response = await _client.get(url, headers: _headers);
      if (response.statusCode != 200) return null;

      final document = hp.parse(response.body);

      // Extract MD5 from ads.php?md5=... link
      final adsLink = document
          .querySelector('a[href^="ads.php?md5="]')
          ?.attributes['href'];
      final md5Match = RegExp(r'md5=([a-f0-9]+)').firstMatch(adsLink ?? '');
      final md5 = md5Match?.group(1);
      if (md5 == null || md5.isEmpty) {
        debugPrint('[LibGen] MD5 not found for edition $editionId');
        return null;
      }

      // Extract additional file info from #tablelibgen
      String? size, extension, pages;
      for (final row
          in document.querySelectorAll('table#tablelibgen tr')) {
        final tds = row.querySelectorAll('td');
        if (tds.length < 2) continue;
        final text = tds[1].text;

        final sizeMatch = RegExp(r'Size:\s*([^\n]+)').firstMatch(text);
        if (sizeMatch != null) size = sizeMatch.group(1)?.trim();

        final extMatch = RegExp(r'Extension:\s*(\w+)').firstMatch(text);
        if (extMatch != null) extension = extMatch.group(1)?.trim();

        final pagesMatch = RegExp(r'Pages:\s*(\d+)').firstMatch(text);
        if (pagesMatch != null) pages = pagesMatch.group(1)?.trim();
      }

      debugPrint('[LibGen] MD5: $md5');
      return BookEditionDetails(
        editionId: editionId,
        md5: md5,
        adsUrl: '$_base/ads.php?md5=$md5',
        size: size,
        extension: extension,
        pages: pages,
      );
    } catch (e) {
      debugPrint('[LibGen] edition details error: $e');
      return null;
    }
  }

  // ── Download link from MD5 ─────────────────────────────────────────────────
  // Equivalent to: GET /libgen/download/:md5

  Future<String?> getDownloadUrl(String md5) async {
    try {
      final adsUrl = Uri.parse('$_base/ads.php?md5=$md5');
      debugPrint('[LibGen] ads page: $adsUrl');

      final response = await _client.get(adsUrl, headers: _headers);
      if (response.statusCode != 200) return null;

      final document = hp.parse(response.body);

      // Extract get.php link from #main table
      final getLink = document
          .querySelector('table#main a[href^="get.php"]')
          ?.attributes['href'];

      if (getLink == null || getLink.isEmpty) {
        debugPrint('[LibGen] get.php link not found for md5 $md5');
        return null;
      }

      final fullUrl = '$_base/$getLink';
      debugPrint('[LibGen] download URL: $fullUrl');
      return fullUrl;
    } catch (e) {
      debugPrint('[LibGen] download url error: $e');
      return null;
    }
  }

  // ── Convenience: full resolution in one call ───────────────────────────────
  // editionId → MD5 → download URL

  Future<String?> resolveDownloadUrl(String editionId) async {
    final details = await getEditionDetails(editionId);
    if (details == null) return null;
    return getDownloadUrl(details.md5);
  }
}
