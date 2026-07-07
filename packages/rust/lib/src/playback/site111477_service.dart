import 'package:rust/rust.dart';

/// Scraper + fuzzy matcher for the 111477.xyz file index (Rust engine).
/// Seekable playback proxy: `site111477_proxy.dart` / `crates/proxy/seek111477`.
class Site111477Service {
  static final Site111477Service _instance = Site111477Service._();
  factory Site111477Service() => _instance;
  Site111477Service._();

  Future<Site111477Match?> findMovie({
    required String title,
    String? year,
  }) async {
    final list = await findMovieSources(title: title, year: year);
    return list.isEmpty ? null : list.first;
  }

  Future<Site111477Match?> findEpisode({
    required String showTitle,
    required int season,
    required int episode,
  }) async {
    final list = await findEpisodeSources(
      showTitle: showTitle,
      season: season,
      episode: episode,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<List<Site111477Match>> findMovieSources({
    required String title,
    String? year,
  }) async {
    final cacheDir = await site111477CacheDir();
    return site111477IndexRequest({
      'action': 'find_movie_sources',
      'title': title,
      if (year != null) 'year': year,
      'cache_dir': cacheDir,
    });
  }

  Future<List<Site111477Match>> findEpisodeSources({
    required String showTitle,
    required int season,
    required int episode,
  }) async {
    final cacheDir = await site111477CacheDir();
    return site111477IndexRequest({
      'action': 'find_episode_sources',
      'show_title': showTitle,
      'season': season,
      'episode': episode,
      'cache_dir': cacheDir,
    });
  }

  static List<StreamSource> toStreamSources(List<Site111477Match> matches) {
    return [
      for (final m in matches)
        StreamSource(
          url: m.fileUrl,
          title: m.fileName,
          type: _describeMatch(m),
        ),
    ];
  }

  static String _describeMatch(Site111477Match m) {
    final q = qualityTagFor(m.fileName);
    final s = m.sizeBytes > 0 ? humanSize(m.sizeBytes) : '';
    if (q.isEmpty && s.isEmpty) return '111477';
    if (q.isEmpty) return '111477 • $s';
    if (s.isEmpty) return '$q • 111477';
    return '$q • $s';
  }

  static String qualityTagFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('2160p') || n.contains('4k')) return '2160P';
    if (n.contains('1080p')) return '1080P';
    if (n.contains('720p')) return '720P';
    if (n.contains('480p')) return '480P';
    if (n.contains('360p')) return '360P';
    return '';
  }

  static String humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }
}
