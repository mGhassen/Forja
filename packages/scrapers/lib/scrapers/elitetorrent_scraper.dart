import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'base_scraper.dart';

class EliteTorrentScraper extends BaseScraper {
  @override
  String get name => 'EliteTorrent';
  
  static const String baseUrl = 'https://www.elitetorrent.wf';
  
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final searchUrl = '$baseUrl/?s=${Uri.encodeComponent(query)}&x=0&y=0';
      
      final htmlContent = await fetchHtml(searchUrl);
      final document = html_parser.parse(htmlContent);
      
      final torrentFutures = <Future<Map<String, dynamic>?>>[];
      
      final items = document.querySelectorAll('ul.miniboxs li');
      
      for (final item in items) {
        final linkElem = item.querySelector('a.nombre');
        if (linkElem == null) continue;
        
        final link = linkElem.attributes['href'];
        final title = linkElem.attributes['title'] ?? linkElem.text.trim();
        
        if (link == null || link.isEmpty) continue;
        
        final sizeElem = item.querySelector('.voto1 .dig1');
        final size = sizeElem?.text.trim() ?? '';
        
        final qualityElem = item.querySelector('.marca.estreno i');
        final quality = qualityElem?.text.trim() ?? '';
        
        final imageElem = item.querySelector('img.brighten');
        final image = imageElem?.attributes['data-src'] ?? '';
        
        torrentFutures.add(_fetchTorrentDetails(link, title, size, quality, image));
      }
      
      final results = await Future.wait(torrentFutures);
      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('$name scraper error: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>?> _fetchTorrentDetails(String url, String title, String sizeFromSearch, String quality, String image) async {
    try {
      final htmlContent = await fetchHtml(url);
      final document = html_parser.parse(htmlContent);
      
      final magnetElem = document.querySelector('a[href^="magnet:"]');
      final magnetLink = magnetElem?.attributes['href'];
      
      final torrentElem = document.querySelector('a.enlace_torrent[href\$=".torrent"]');
      final torrentLink = torrentElem?.attributes['href'];
      
      if (magnetLink == null && torrentLink == null) {
        return null;
      }
      
      String size = sizeFromSearch;
      
      final descripElem = document.querySelector('p.descrip');
      if (descripElem != null) {
        final descripHtml = descripElem.innerHtml;
        final sizeMatch = RegExp(r'<b>Tamaño:</b>\s*([^<]+)', caseSensitive: false).firstMatch(descripHtml);
        if (sizeMatch != null) {
          size = sizeMatch.group(1)!.trim();
        }
      }
      
      return {
        'name': title,
        'magnet': magnetLink ?? '',
        'seeders': 'Unknown',
        'size': size.isNotEmpty ? size : 'Unknown',
        'source': name,
      };
    } catch (e) {
      debugPrint('$name error fetching $url: $e');
      return null;
    }
  }
}
