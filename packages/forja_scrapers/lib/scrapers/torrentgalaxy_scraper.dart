import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class TorrentGalaxyScraper extends BaseScraper {
  @override
  String get name => 'TorrentGalaxy';
  
  static const String baseUrl = 'https://torrentgalaxy.one';
  static const int maxPages = 3;
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final allResults = <Map<String, dynamic>>[];
      
      for (int page = 1; page <= maxPages; page++) {
        final pageUrl = page == 1
            ? '$baseUrl/get-posts/keywords:${Uri.encodeComponent(query)}'
            : '$baseUrl/get-posts/keywords:${Uri.encodeComponent(query)}?page=$page';
        
        try {
          final htmlContent = await fetchHtml(pageUrl);
          final document = html_parser.parse(htmlContent);
          
          final rows = document.querySelectorAll('div.tgxtablerow');
          final torrentFutures = <Future<Map<String, dynamic>?>>[];
          
          for (final row in rows) {
            final titleLink = row.querySelector('div.tgxtablecell a[href*="/post-detail/"]');
            if (titleLink == null) continue;
            
            final titleBold = titleLink.querySelector('b');
            final title = titleBold?.text.trim() ?? titleLink.attributes['title'] ?? '';
            final detailPath = titleLink.attributes['href'];
            
            if (detailPath == null || detailPath.isEmpty) continue;
            
            String size = 'Unknown';
            final badges = row.querySelectorAll('span.badge');
            for (final badge in badges) {
              final text = badge.text.trim();
              if (RegExp(r'\d+(\.\d+)?\s*(GB|MB|GiB|MiB|KB|KiB)', caseSensitive: false).hasMatch(text)) {
                size = text;
                break;
              }
            }
            
            String seeders = 'Unknown';
            final seederSpans = row.querySelectorAll('span[title="Seeders/Leechers"]');
            for (final span in seederSpans) {
              final html = span.innerHtml;
              final match = RegExp(r'<font\s+color="green"><b>(\d+)</b></font>', caseSensitive: false).firstMatch(html);
              if (match != null) {
                seeders = match.group(1)!;
                break;
              }
            }
            
            torrentFutures.add(_fetchTorrentMagnet(baseUrl + detailPath, title, seeders, size));
          }
          
          if (torrentFutures.isEmpty) break;
          
          final results = await Future.wait(torrentFutures);
          allResults.addAll(results.whereType<Map<String, dynamic>>());
        } catch (e) {
          debugPrint('$name page $page error: $e');
          break;
        }
      }
      
      return allResults;
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>?> _fetchTorrentMagnet(String url, String title, String seeders, String size) async {
    try {
      final htmlContent = await fetchHtml(url);
      final document = html_parser.parse(htmlContent);
      
      final magnetElem = document.querySelector('a[href^="magnet:"]');
      final magnetLink = magnetElem?.attributes['href'];
      
      if (magnetLink != null && magnetLink.isNotEmpty) {
        return {
          'name': title,
          'magnet': magnetLink,
          'seeders': seeders,
          'size': size,
          'source': name,
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('$name error fetching $url: $e');
      return null;
    }
  }
}
