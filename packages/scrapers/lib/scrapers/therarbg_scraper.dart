import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class TheRarbgScraper extends BaseScraper {
  @override
  String get name => 'TheRARBG';
  
  static const String baseUrl = 'https://therarbg.to';
  static const int maxPages = 3;
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final allResults = <Map<String, dynamic>>[];
      
      final categories = ['Movies', 'TV'];
      
      for (final category in categories) {
        for (int page = 1; page <= maxPages; page++) {
          final pageUrl = page == 1
              ? '$baseUrl/get-posts/category:$category:keywords:${Uri.encodeComponent(query)}/'
              : '$baseUrl/get-posts/category:$category:keywords:${Uri.encodeComponent(query)}/?page=$page';
          
          try {
            final htmlContent = await fetchHtml(pageUrl);
            final document = html_parser.parse(htmlContent);
            
            final rows = document.querySelectorAll('tr.list-entry');
            final torrentFutures = <Future<Map<String, dynamic>?>>[];
            
            for (final row in rows) {
              final titleLink = row.querySelector('td.cellName a');
              if (titleLink == null) continue;
              
              final title = titleLink.text.trim();
              final detailPath = titleLink.attributes['href'];
              
              if (detailPath == null || detailPath.isEmpty) continue;
              
              final sizeElem = row.querySelector('td.sizeCell');
              final size = sizeElem?.text.trim() ?? 'Unknown';
              
              final seederElem = row.querySelector('td[style*="color: green"]');
              final seeders = seederElem?.text.trim() ?? 'Unknown';
              
              torrentFutures.add(_fetchTorrentMagnet(baseUrl + detailPath, title, seeders, size));
            }
            
            if (torrentFutures.isEmpty) break;
            
            final results = await Future.wait(torrentFutures);
            allResults.addAll(results.whereType<Map<String, dynamic>>());
          } catch (e) {
            debugPrint('$name $category page $page error: $e');
            break;
          }
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
      
      final magnetElem = document.querySelector('a.magnet-btn[href^="magnet:"]');
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
