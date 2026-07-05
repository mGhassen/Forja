import 'package:flutter/foundation.dart';
import 'package:forja_core/models/torrent_result.dart';

/// Optional Rust backend hooks. Set from app bootstrap when [ForjaEngine] loads.
abstract final class TorrentFilterBackend {
  static String Function(String title)? normalizeTitle;
  static Map<String, dynamic> Function(String title)? parseSceneInfo;
}

class TorrentFilter {
  static String normalizeTitle(String title) {
    return TorrentFilterBackend.normalizeTitle!(title);
  }

  static Map<String, dynamic> parseSceneInfo(String title) {
    return TorrentFilterBackend.parseSceneInfo!(title);
  }

  static bool isVideoFile(String fileName) {
    final t = fileName.toLowerCase();
    const videoExtensions = [
      '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', 
      '.m4v', '.mpg', '.mpeg', '.m2ts', '.ts', '.vob', '.ogv', 
      '.3gp', '.3g2', '.f4v', '.asf', '.rm', '.rmvb', '.divx'
    ];
    return videoExtensions.any((ext) => t.endsWith(ext));
  }

  static bool isFileMatch(String fileName, int season, int episode) {
    final t = fileName.toLowerCase();
    
    if (!isVideoFile(t)) return false;
    
    // Strict SXXEYY match
    final sXe = RegExp('s0*$season[ ._-]*e0*$episode\\b', caseSensitive: false);
    final anySxE = RegExp(r's\d+[ ._-]*e\d+\b', caseSensitive: false);
    
    if (anySxE.hasMatch(t)) {
      return sXe.hasMatch(t); // If it has SxxEyy format, it MUST match the requested season/episode exactly.
    }

    // Strict [S]x[E] match (e.g. 1x01)
    final xMatch = RegExp('\\b0*$season[ ._-]*x[ ._-]*0*$episode\\b', caseSensitive: false);
    final anyXMatch = RegExp(r'\b\d+[ ._-]*x[ ._-]*\d+\b', caseSensitive: false);

    if (anyXMatch.hasMatch(t)) {
      return xMatch.hasMatch(t);
    }

    // Check for "season 2" when we want season 1
    final wrongSeason = RegExp('\\bseason[ ._-]*(?!0*$season\\b)\\d+\\b', caseSensitive: false);
    final rightSeason = RegExp('\\bseason[ ._-]*0*$season\\b', caseSensitive: false);
    if (wrongSeason.hasMatch(t) && !rightSeason.hasMatch(t)) {
      return false; // Explicitly in a different season's folder or named wrong season
    }

    // Fallbacks if no explicit season/episode format is found.
    final eOnly = RegExp('\\be[ ._-]*0*$episode\\b', caseSensitive: false);
    if (eOnly.hasMatch(t)) return true;

    final epOnlyStr = RegExp('\\bep(isode)?[ ._-]*0*$episode\\b', caseSensitive: false);
    if (epOnlyStr.hasMatch(t)) return true;

    final epOnly = RegExp('\\b0*$episode\\b');
    if (epOnly.hasMatch(t)) return true;

    return false;
  }

  // Wrapper for background compute
  static Future<List<TorrentResult>> filterTorrentsAsync(
    List<TorrentResult> items, 
    String showTitle, 
    {int? requiredSeason, int? requiredEpisode}
  ) async {
    return await compute(_filterTorrentsWorker, {
      'items': items,
      'showTitle': showTitle,
      'requiredSeason': requiredSeason,
      'requiredEpisode': requiredEpisode,
    });
  }

  static List<TorrentResult> _filterTorrentsWorker(Map<String, dynamic> params) {
    return filterTorrents(
      params['items'] as List<TorrentResult>,
      params['showTitle'] as String,
      requiredSeason: params['requiredSeason'] as int?,
      requiredEpisode: params['requiredEpisode'] as int?,
    );
  }

  static List<TorrentResult> filterTorrents(
    List<TorrentResult> items, 
    String showTitle, 
    {int? requiredSeason, int? requiredEpisode}
  ) {
    if (items.isEmpty) return [];
    if (showTitle.isEmpty) return items;

    final normShowTitle = normalizeTitle(showTitle);
    
    return items.where((item) {
      String cleanTitle = item.name.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');
      
      final info = parseSceneInfo(cleanTitle);
      String titlePart;
      
      if (info['matchIndex'] > -1) {
        titlePart = cleanTitle.substring(0, info['matchIndex']);
      } else {
        titlePart = cleanTitle;
      }

      final normTitlePart = normalizeTitle(titlePart);
      
      if (!normTitlePart.startsWith(normShowTitle)) return false;
      
      if (requiredSeason != null) {
        String suffix = normTitlePart.substring(normShowTitle.length).trim();
        
        final noiseWords = ['complete', 'series', 'season', 'multi', 'bluray', 'webrip', 'web', 'dl', 'hdtv', 'x264', 'x265', 'h264', 'h265', 'hevc', '1080p', '720p', '4k', 'uhd'];
        for (var word in noiseWords) {
          suffix = suffix.replaceAll(word, '').trim();
        }

        if (suffix.isNotEmpty) {
          final yearMatch = RegExp(r'^\d{4}$').hasMatch(suffix);
          if (!yearMatch && suffix.isNotEmpty) return false; 
        }
      }

      if (requiredSeason != null && requiredEpisode != null) {
        if (info['season'] != requiredSeason) return false;
        if (info['episode'] != requiredEpisode) return false;
        return true;
      }
      
      if (requiredSeason != null && requiredEpisode == null) {
        if (info['season'] != null && info['season'] != requiredSeason) {
          final rangeMatch = RegExp(r's(\d+)\s*-\s*s?(\d+)', caseSensitive: false).firstMatch(cleanTitle.toLowerCase());
          if (rangeMatch != null) {
            int start = int.parse(rangeMatch.group(1)!);
            int end = int.parse(rangeMatch.group(2)!);
            if (requiredSeason < start || requiredSeason > end) return false;
          } else {
            return false;
          }
        }
        return info['isSeasonPack'] || info['isMultiSeason'] || (info['season'] != null && info['episode'] == null);
      }
      
      return true;
    }).toList();
  }

  /// Sorts torrents in a background isolate to prevent UI lag
  static Future<List<TorrentResult>> sortTorrentsAsync(List<TorrentResult> items, String preference) async {
    return compute(_sortWorker, {'items': items, 'preference': preference});
  }

  static List<TorrentResult> _sortWorker(Map<String, dynamic> params) {
    final List<TorrentResult> items = params['items'] as List<TorrentResult>;
    final String preference = params['preference'] as String;
    
    switch (preference) {
      case 'Seeders (High to Low)':
        items.sort((a, b) => _parseSeeds(b.seeders).compareTo(_parseSeeds(a.seeders)));
        break;
      case 'Seeders (Low to High)':
        items.sort((a, b) => _parseSeeds(a.seeders).compareTo(_parseSeeds(b.seeders)));
        break;
      case 'Quality (High to Low)':
        items.sort((a, b) {
          final qCmp = _getQualityScore(b.name).compareTo(_getQualityScore(a.name));
          if (qCmp != 0) return qCmp;
          return _parseSeeds(b.seeders).compareTo(_parseSeeds(a.seeders));
        });
        break;
      case 'Quality (Low to High)':
        items.sort((a, b) {
          final qCmp = _getQualityScore(a.name).compareTo(_getQualityScore(b.name));
          if (qCmp != 0) return qCmp;
          return _parseSeeds(b.seeders).compareTo(_parseSeeds(a.seeders));
        });
        break;
      case 'Size (High to Low)':
        items.sort((a, b) => b.sizeInBytes.compareTo(a.sizeInBytes));
        break;
      case 'Size (Low to High)':
        items.sort((a, b) => a.sizeInBytes.compareTo(b.sizeInBytes));
        break;
    }
    return items;
  }

  static int _parseSeeds(String seeds) {
    return int.tryParse(seeds.replaceAll(',', '')) ?? 0;
  }

  static int _getQualityScore(String name) {
    name = name.toLowerCase();
    if (name.contains('2160p') || name.contains('4k') || name.contains('uhd')) return 400;
    if (name.contains('1080p') || name.contains('fhd')) return 300;
    if (name.contains('720p') || name.contains('hd')) return 200;
    if (name.contains('480p') || name.contains('sd')) return 100;
    return 0;
  }
}
