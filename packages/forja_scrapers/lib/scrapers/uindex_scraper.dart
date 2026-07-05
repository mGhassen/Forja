import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class UindexScraper extends BaseScraper {
  @override
  String get name => 'UIndex';
  
  static const String baseUrl = 'https://uindex.org';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final searchUrl = '$baseUrl/search.php?search=${Uri.encodeComponent(query)}&c=0';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final results = <Map<String, dynamic>>[];
      
      final rows = document.querySelectorAll('table tr');
      
      for (final row in rows) {
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
