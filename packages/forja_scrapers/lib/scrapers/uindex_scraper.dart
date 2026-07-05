import 'package:flutter/foundation.dart';
import 'package:forja_rust/src/reference/scrapers_dart_parse.dart';
import 'base_scraper.dart';
import 'scraper_parse.dart';

class UindexScraper extends BaseScraper {
  @override
  String get name => 'UIndex';
  
  static const String baseUrl = 'https://uindex.org';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final searchUrl = '$baseUrl/search.php?search=${Uri.encodeComponent(query)}&c=0';
      
      final htmlContent = await fetchHtml(searchUrl);
      final rust = ScraperParseBackend.parseUindex;
      if (rust != null) {
        return rust(htmlContent).map(normalizeTorrentRow).toList();
      }

      return ScrapersDartParse.parseUindex(htmlContent, source: name)
          .map(normalizeTorrentRow)
          .toList();
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
}
