import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class ThePirateBayScraper extends BaseScraper {
  @override
  String get name => 'ThePirateBay';
  
  static const String baseUrl = 'https://1.piratebays.to';
  static const int maxPages = 10;
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final allResults = <Map<String, dynamic>>[];
      
      for (int page = 1; page <= maxPages; page++) {
        final pageUrl = page == 1
            ? '$baseUrl/s/?q=${Uri.encodeComponent(query)}&video=on&category=0'
            : '$baseUrl/s/page/$page/?q=${Uri.encodeComponent(query)}&video=on&category=0';
        
        try {
          final htmlContent = await fetchHtml(pageUrl);
          final document = html_parser.parse(htmlContent);
          
          int pageResults = 0;
          final rows = document.querySelectorAll('table tr');
          
          for (final row in rows) {
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
            
            allResults.add({
              'name': title,
              'magnet': magnet,
              'seeders': seeders,
              'size': size,
              'source': name,
            });
            
            pageResults++;
          }
          
          if (pageResults == 0) break;
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
}
