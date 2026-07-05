import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class LimeTorrentsScraper extends BaseScraper {
  @override
  String get name => 'LimeTorrents';
  
  static const String baseUrl = 'https://www.limetorrents.fun';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = '$baseUrl/search/all/$encodedQuery/';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final torrentFutures = <Future<Map<String, dynamic>?>>[];
      
      final rows = document.querySelectorAll('table.table2 tr');
      
      for (final row in rows) {
        if (row.querySelectorAll('th').isNotEmpty) continue;
        
        final titleLink = row.querySelector('.tt-name a[href*="-torrent-"]');
        if (titleLink == null) continue;
        
        final title = titleLink.text.trim();
        final torrentPath = titleLink.attributes['href'];
        
        if (torrentPath == null || torrentPath.isEmpty) continue;
        
        final seederElem = row.querySelector('.tdseed');
        final seeders = seederElem?.text.trim().replaceAll(',', '') ?? 'Unknown';
        
        torrentFutures.add(_fetchTorrentMagnet(baseUrl + torrentPath, title, seeders));
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
  
  Future<Map<String, dynamic>?> _fetchTorrentMagnet(String url, String title, String seeders) async {
    try {
      final htmlContent = await fetchHtml(url);
      final document = html_parser.parse(htmlContent);
      
      final magnetElem = document.querySelector('a[href^="magnet:"]');
      final magnetLink = magnetElem?.attributes['href'];
      
      String size = 'Unknown';
      final infoRows = document.querySelectorAll('.torrentinfo table tr');
      for (final row in infoRows) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 2) {
          final label = cells[0].text.trim();
          if (label == 'Torrent Size:') {
            size = cells[1].text.trim();
            break;
          }
        }
      }
      
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
