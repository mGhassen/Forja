import 'base_scraper.dart';
import 'package:flutter/foundation.dart';
import 'package:forja_rust/src/reference/scrapers_dart_parse.dart';
import 'knaben_scraper.dart';
import 'thepiratebay_scraper.dart';
import 'uindex_scraper.dart';
import 'scraper_parse.dart';

class ScraperAggregator {
  static final List<BaseScraper> _scrapers = [
    // EliteTorrentScraper(),
    // EztvScraper(),
    // IlCorsaroNeroScraper(),
    KnabenScraper(),
    // LimeTorrentsScraper(),
    // MegapeerScraper(),
    // OxTorrentScraper(),
    ThePirateBayScraper(),
    // TheRarbgScraper(),
    // TorrentGalaxyScraper(),
    UindexScraper(),
    // YtsScraper(),
  ];
  
  static Future<List<Map<String, dynamic>>> searchAll(String query) async {
    debugPrint('[ScraperAggregator] Starting search for: $query');
    
    // Run enabled scrapers in parallel with a timeout to prevent hanging
    final results = await Future.wait(
      _scrapers.map((scraper) async {
        try {
          debugPrint('[ScraperAggregator] Running ${scraper.name}...');
          final scraperResults = await scraper.search(query).timeout(const Duration(seconds: 15));
          debugPrint('[ScraperAggregator] ${scraper.name} found ${scraperResults.length} results');
          return scraperResults;
        } catch (e) {
          debugPrint('[ScraperAggregator] ${scraper.name} failed or timed out: $e');
          return <Map<String, dynamic>>[];
        }
      }),
    );
    
    // Flatten all results
    final aggregated = <Map<String, dynamic>>[];
    for (final result in results) {
      aggregated.addAll(result);
    }
    
    debugPrint('[ScraperAggregator] Total results before deduplication: ${aggregated.length}');

    final dedupBackend = ScraperParseBackend.dedupTorrents;
    final unique = dedupBackend != null
        ? dedupBackend(aggregated)
        : ScrapersDartParse.dedupTorrents(aggregated);
    
    // Sort by seeders (highest to lowest)
    unique.sort((a, b) {
      final seedersA = _parseSeeders(a['seeders'] as String?);
      final seedersB = _parseSeeders(b['seeders'] as String?);
      return seedersB.compareTo(seedersA);
    });
    
    debugPrint('[ScraperAggregator] Unique results after deduplication: ${unique.length}');
    
    return unique;
  }
  
  static int _parseSeeders(String? seeders) {
    if (seeders == null || seeders == 'Unknown') return -1;
    final cleaned = seeders.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? -1;
  }
}
