import 'package:html/parser.dart' as html_parser;

/// Dart reference scraper HTML parsers — Rust-off fallback and parity tests.
abstract final class ScrapersDartParse {
  static List<Map<String, dynamic>> parseKnaben(String html, {String source = 'Knaben'}) {
    final document = html_parser.parse(html);
    final results = <Map<String, dynamic>>[];

    for (final row in document.querySelectorAll('tbody tr')) {
      final titleLink = row.querySelector('td.text-wrap a[href^="magnet:"]');
      if (titleLink == null) continue;

      final title = titleLink.attributes['title'] ?? titleLink.text.trim();
      final magnetLink = titleLink.attributes['href'];
      if (magnetLink == null || magnetLink.isEmpty) continue;

      final cells = row.querySelectorAll('td');
      final size = cells.length >= 2 ? cells[1].text.trim() : 'Unknown';
      final seeders = cells.length >= 4 ? cells[3].text.trim() : 'Unknown';

      results.add({
        'name': title,
        'magnet': magnetLink,
        'seeders': seeders,
        'size': size,
        'source': source,
      });
    }

    return results;
  }

  static List<Map<String, dynamic>> parseTpb(String html, String source) {
    final document = html_parser.parse(html);
    final results = <Map<String, dynamic>>[];

    for (final row in document.querySelectorAll('table tr')) {
      if (row.querySelectorAll('th').isNotEmpty) continue;

      final titleLink = row.querySelector('a.detLink');
      final magnetLink = row.querySelector('a[href^="magnet:"]');
      if (titleLink == null || magnetLink == null) continue;

      final title = titleLink.text.trim();
      final magnet = magnetLink.attributes['href'];
      if (magnet == null || magnet.isEmpty) continue;

      final cells = row.querySelectorAll('td');
      final size = cells.length > 4 ? cells[4].text.trim() : 'Unknown';
      final seeders = cells.length > 5 ? cells[5].text.trim() : 'Unknown';

      results.add({
        'name': title,
        'magnet': magnet,
        'seeders': seeders,
        'size': size,
        'source': source,
      });
    }

    return results;
  }

  static List<Map<String, dynamic>> parseUindex(String html, {String source = 'UIndex'}) {
    final document = html_parser.parse(html);
    final results = <Map<String, dynamic>>[];

    for (final row in document.querySelectorAll('table tr')) {
      if (row.querySelectorAll('th').isNotEmpty) continue;

      final cells = row.querySelectorAll('td');
      if (cells.length < 5) continue;

      final titleCell = cells[1];
      final magnetElem = titleCell.querySelector('a[href^="magnet:"]');
      final magnetLink = magnetElem?.attributes['href'];
      final titleElem = titleCell.querySelector('a[href*="/details.php"]');
      final title = titleElem?.text.trim() ?? '';

      if (title.isEmpty || magnetLink == null || magnetLink.isEmpty) continue;

      final size = cells[2].text.trim();
      final seederSpan = cells[3].querySelector('span.g');
      final seeders = (seederSpan?.text.trim() ?? cells[3].text.trim())
          .replaceAll(',', '');

      results.add({
        'name': title,
        'magnet': magnetLink,
        'seeders': seeders.isNotEmpty ? seeders : 'Unknown',
        'size': size.isNotEmpty ? size : 'Unknown',
        'source': source,
      });
    }

    return results;
  }

  static List<Map<String, dynamic>> dedupTorrents(
    List<Map<String, dynamic>> aggregated,
  ) {
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];

    for (final torrent in aggregated) {
      final magnet = torrent['magnet'] as String?;
      if (magnet == null || magnet.isEmpty) continue;

      final match = RegExp(
        r'btih:([a-fA-F0-9]+)',
        caseSensitive: false,
      ).firstMatch(magnet);
      if (match != null) {
        final infohash = match.group(1)!.toUpperCase();
        if (seen.contains(infohash)) continue;
        seen.add(infohash);
      }

      unique.add(torrent);
    }

    return unique;
  }
}
