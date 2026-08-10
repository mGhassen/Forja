import 'package:rust/rust.dart';

/// Playback selection — normalize and rank stream sources.
abstract final class PlaybackSelection {
  static final _failedUrls = <String>{};

  static void recordFailedUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty) _failedUrls.add(trimmed);
  }

  static void clearFailedUrls() => _failedUrls.clear();

  static List<String> get failedUrls => List.unmodifiable(_failedUrls);

  /// Rank legacy stream sources for a provider.
  static Future<List<PlayableSource>> rankLegacySources({
    required List<StreamSource> sources,
    required String providerId,
    int providerRank = 0,
    DevicePlaybackCapabilities? device,
  }) async {
    final caps = device ?? await DeviceCapabilitiesService.detect();
    return rankStreamSources(
      sources: sources,
      providerId: providerId,
      providerRank: providerRank,
      device: caps,
      blocklist: _failedUrls.toList(),
    );
  }

  static Future<List<StreamSource>> rankAndDedupe({
    required List<StreamSource> sources,
    required String providerId,
    int providerRank = 0,
    DevicePlaybackCapabilities? device,
  }) async {
    final ranked = await rankLegacySources(
      sources: sources,
      providerId: providerId,
      providerRank: providerRank,
      device: device,
    );
    final mapped = playableSourcesToStreamSources(ranked);
    final qualityByUrl = <String, List<StreamQualityOption>>{};
    for (final s in sources) {
      final q = s.qualities;
      if (q != null && q.isNotEmpty) qualityByUrl[s.url] = q;
    }
    final restored = [
      for (final s in mapped)
        qualityByUrl.containsKey(s.url)
            ? s.copyWith(qualities: qualityByUrl[s.url])
            : s,
    ];
    return collapseStreamQualityVariants(restored);
  }
}

/// Device-aware dedupe — prefer over sync [dedupeStreamSources].
Future<List<StreamSource>> dedupeStreamSourcesAsync(
  List<StreamSource> sources, {
  required String providerId,
  int providerRank = 0,
}) => PlaybackSelection.rankAndDedupe(
  sources: sources,
  providerId: providerId,
  providerRank: providerRank,
);
