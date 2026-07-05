import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class OxTorrentScraper extends BaseScraper {
  @override
  String get name => 'OxTorrent';
  
  static const String baseUrl = 'https://www.oxtorrent.co';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final searchUrl = '$baseUrl/search_torrent';
      
      final htmlContent = await postHtml(
        searchUrl,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'torrentSearch=${Uri.encodeComponent(query)}',
      );
      
      final document = html_parser.parse(htmlContent);
      
      final torrentFutures = <Future<Map<String, dynamic>?>>[];
      
      final rows = document.querySelectorAll('table.table-hover tbody tr');
      
      for (final row in rows) {
        final titleLink = row.querySelector('a[href*="/torrent/"]');
        if (titleLink == null) continue;
        
        final title = titleLink.text.trim();
        final torrentPath = titleLink.attributes['href'];
        
        if (torrentPath == null || torrentPath.isEmpty) continue;
        
        final cells = row.querySelectorAll('td');
        final size = cells.length > 1 ? cells[1].text.trim() : 'Unknown';
        final seeders = cells.length > 2 ? cells[2].text.trim() : 'Unknown';
        
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
      
      final magnetElem = document.querySelector('.btn-magnet a[href^="magnet:"]');
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
