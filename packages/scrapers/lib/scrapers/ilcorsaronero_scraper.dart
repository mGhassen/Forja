import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class IlCorsaroNeroScraper extends BaseScraper {
  @override
  String get name => 'IlCorsaroNero';
  
  static const String baseUrl = 'https://ilcorsaronero.link';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = '$baseUrl/search?q=$encodedQuery&sort=seeders&order=desc';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final torrentFutures = <Future<Map<String, dynamic>?>>[];
      
      final rows = document.querySelectorAll('tbody tr');
      
      for (final row in rows) {
        final titleLink = row.querySelector('th a.hover\\:underline');
        if (titleLink == null) continue;
        
        final title = titleLink.text.trim();
        final torrentPath = titleLink.attributes['href'];
        
        if (torrentPath == null || torrentPath.isEmpty) continue;
        
        final seederElem = row.querySelector('td.text-green-500');
        final seeders = seederElem?.text.trim() ?? 'Unknown';
        
        final cells = row.querySelectorAll('td');
        final size = cells.length > 4 ? cells[4].text.trim() : 'Unknown';
        
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
