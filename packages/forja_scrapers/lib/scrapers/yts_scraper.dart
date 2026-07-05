import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class YtsScraper extends BaseScraper {
  @override
  String get name => 'YTS';
  
  static const String baseUrl = 'https://yts.bz';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final searchUrl = '$baseUrl/browse-movies/${Uri.encodeComponent(query)}/all/all/0/latest/0/all';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final movieCards = document.querySelectorAll('div.browse-movie-wrap');
      final movieUrls = <String>[];
      
      for (final card in movieCards) {
        final link = card.querySelector('a.browse-movie-link');
        final movieUrl = link?.attributes['href'];
        if (movieUrl != null && movieUrl.isNotEmpty) {
          movieUrls.add(movieUrl);
        }
      }
      
      final allTorrents = <Map<String, dynamic>>[];
      
      for (final url in movieUrls) {
        try {
          final torrents = await _fetchMovieTorrents(url);
          allTorrents.addAll(torrents);
        } catch (e) {
          debugPrint('$name error fetching $url: $e');
        }
      }
      
      return allTorrents;
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
  
  Future<List<Map<String, dynamic>>> _fetchMovieTorrents(String url) async {
    final htmlContent = await fetchHtml(url);
    final document = html_parser.parse(htmlContent);
    
    final urlParts = url.split('/');
    final movieSlug = urlParts.last;
    
    final torrents = <Map<String, dynamic>>[];
    
    final modalTorrents = document.querySelectorAll('.modal-torrent');
    
    for (final torrent in modalTorrents) {
      final qualityElem = torrent.querySelector('.modal-quality span');
      final quality = qualityElem?.text.trim() ?? '';
      
      final qualitySizeElems = torrent.querySelectorAll('p.quality-size');
      final type = qualitySizeElems.isNotEmpty ? qualitySizeElems[0].text.trim() : '';
      final size = qualitySizeElems.length > 1 ? qualitySizeElems[1].text.trim() : 'Unknown';
      
      final magnetElem = torrent.querySelector('a.magnet-download[href^="magnet:"]');
      final magnetLink = magnetElem?.attributes['href'];
      
      if (magnetLink != null && magnetLink.isNotEmpty && quality.isNotEmpty) {
        final movieName = '$movieSlug yts $quality $type'.trim();
        
        torrents.add({
          'name': movieName,
          'magnet': magnetLink,
          'seeders': 'Unknown',
          'size': size,
          'source': name,
        });
      }
    }
    
    return torrents;
  }
}
