import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class MegapeerScraper extends BaseScraper {
  @override
  String get name => 'Megapeer';
  
  static const String baseUrl = 'https://megapeer.vip';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final encodedQuery = query.replaceAll(RegExp(r'\s+'), '+');
      final searchUrl = '$baseUrl/browse.php?search=$encodedQuery';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final torrentFutures = <Future<Map<String, dynamic>?>>[];
      
      final rows = document.querySelectorAll('tr.table_fon');
      
      for (final row in rows) {
        final titleLink = row.querySelector('a.url');
        if (titleLink == null) continue;
        
        final title = titleLink.text.trim();
        final torrentPath = titleLink.attributes['href'];
        
        if (torrentPath == null || torrentPath.isEmpty) continue;
        
        final sizeElem = row.querySelector('td[align="right"]');
        final size = sizeElem?.text.trim() ?? 'Unknown';
        
        final seedImg = row.querySelector('img[src="/pic/seed.gif"]');
        String seeders = 'Unknown';
        if (seedImg != null) {
          final nextFont = seedImg.nextElementSibling;
          if (nextFont != null && nextFont.localName == 'font') {
            seeders = nextFont.text.trim();
          }
        }
        
        torrentFutures.add(_fetchTorrentMagnet(baseUrl + torrentPath, title, seeders, size));
      }
      
      // Limit to first 50 to avoid overwhelming
      final limitedFutures = torrentFutures.take(50).toList();
      final results = await Future.wait(limitedFutures);
      
      return results.whereType<Map<String, dynamic>>().toList();
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
