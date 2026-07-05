import 'package:flutter/foundation.dart';
import 'base_scraper.dart';
import 'scraper_parse.dart';

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
          final parsed =
              ScraperParseBackend.parseTpb!(htmlContent, name);
          allResults.addAll(parsed.map(normalizeTorrentRow));
          if (parsed.isEmpty) break;
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
