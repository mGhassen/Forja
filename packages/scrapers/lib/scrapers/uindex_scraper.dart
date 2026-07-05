import 'package:flutter/foundation.dart';
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
      return ScraperParseBackend.parseUindex!(htmlContent)
          .map(normalizeTorrentRow)
          .toList();
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
}
