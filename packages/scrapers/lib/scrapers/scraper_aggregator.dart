import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

class ScraperAggregator {
  static Future<List<Map<String, dynamic>>> searchAll(String query) async {
    debugPrint('[ScraperAggregator] Engine search for: $query');
    try {
      final results = ForjaEngine.searchTorrents(query);
      debugPrint('[ScraperAggregator] ${results.length} results');
      return results;
    } catch (e) {
      debugPrint('[ScraperAggregator] failed: $e');
      return [];
    }
  }
}
