import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class KnabenScraper extends BaseScraper {
  @override
  String get name => 'Knaben';
  
  static const String baseUrl = 'https://knaben.org';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = '$baseUrl/search/$encodedQuery/0/1/seeders';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final results = <Map<String, dynamic>>[];
      
      final rows = document.querySelectorAll('tbody tr');
      
      for (final row in rows) {
        final titleLink = row.querySelector('td.text-wrap a[href^="magnet:"]');
        if (titleLink == null) continue;
        
        final title = titleLink.attributes['title'] ?? titleLink.text.trim();
        final magnetLink = titleLink.attributes['href'];
        
        if (magnetLink == null || magnetLink.isEmpty) continue;
        
        final cells = row.querySelectorAll('td');
        
        String size = 'Unknown';
        final titleCell = row.querySelector('td.text-wrap');
        if (titleCell != null) {
          final sizeCell = titleCell.nextElementSibling;
          if (sizeCell != null) {
            size = sizeCell.text.trim();
          }
        }
        
        final seeders = cells.length >= 3 
            ? cells[cells.length - 3].text.trim() 
            : 'Unknown';
        
        results.add({
          'name': title,
          'magnet': magnetLink,
          'seeders': seeders,
          'size': size,
          'source': name,
        });
      }
      
      return results;
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
}
