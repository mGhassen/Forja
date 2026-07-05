import 'package:flutter/foundation.dart';
import 'package:forja_rust/src/reference/scrapers_dart_parse.dart';
import 'base_scraper.dart';
import 'scraper_parse.dart';

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
      final rust = ScraperParseBackend.parseKnaben;
      if (rust != null) {
        return rust(htmlContent).map(normalizeTorrentRow).toList();
      }

      return ScrapersDartParse.parseKnaben(htmlContent, source: name)
          .map(normalizeTorrentRow)
          .toList();
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
}
