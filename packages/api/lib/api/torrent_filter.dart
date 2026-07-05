import 'package:core/models/torrent_result.dart';
import 'package:rust/rust.dart';

class TorrentFilter {
  static bool isVideoFile(String fileName) {
    final t = fileName.toLowerCase();
    const videoExtensions = [
      '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm',
      '.m4v', '.mpg', '.mpeg', '.m2ts', '.ts', '.vob', '.ogv',
      '.3gp', '.3g2', '.f4v', '.asf', '.rm', '.rmvb', '.divx',
    ];
    return videoExtensions.any((ext) => t.endsWith(ext));
  }

  static Future<List<TorrentResult>> filterTorrentsAsync(
    List<TorrentResult> items,
    String showTitle, {
    int? requiredSeason,
    int? requiredEpisode,
  }) async {
    final rows = items.map((i) => i.toJson()).toList();
    final filtered = ForjaEngine.filterTorrents(
      rows.cast<Map<String, dynamic>>(),
      showTitle,
      requiredSeason: requiredSeason,
      requiredEpisode: requiredEpisode,
    );
    return filtered.map(TorrentResult.fromJson).toList();
  }

  static Future<List<TorrentResult>> sortTorrentsAsync(
    List<TorrentResult> items,
    String preference,
  ) async {
    return _sortWorker({'items': items, 'preference': preference});
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
    if (name.contains('2160p') || name.contains('4k') || name.contains('uhd')) {
      return 400;
    }
    if (name.contains('1080p') || name.contains('fhd')) return 300;
    if (name.contains('720p') || name.contains('hd')) return 200;
    if (name.contains('480p') || name.contains('sd')) return 100;
    return 0;
  }
}
