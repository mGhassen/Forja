import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class EztvScraper extends BaseScraper {
  @override
  String get name => 'EZTV';
  
  static const String baseUrl = 'https://eztvx.to';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final cleanQuery = query.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      final searchUrl = '$baseUrl/search/$cleanQuery';
      
      final htmlContent = await postHtml(
        searchUrl,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': searchUrl,
        },
        body: 'layout=def_wlinks',
      );
      
      final document = html_parser.parse(htmlContent);
      final results = <Map<String, dynamic>>[];
      
      final rows = document.querySelectorAll('tr[name="hover"]');
      
      for (final row in rows) {
        final titleElem = row.querySelector('a.epinfo');
        final magnetElem = row.querySelector('a.magnet');
        
        if (titleElem == null || magnetElem == null) continue;
        
        final title = titleElem.text.trim();
        final magnetLink = magnetElem.attributes['href'];
        
        if (magnetLink == null || magnetLink.isEmpty) continue;
        
        final cells = row.querySelectorAll('td');
        final size = cells.length > 3 ? cells[3].text.trim() : 'Unknown';
        
        final seedersElem = row.querySelector('td font[color="green"]');
        final seeders = seedersElem?.text.trim() ?? 'Unknown';
        
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
