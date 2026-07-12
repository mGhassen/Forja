import 'package:rust/rust.dart';

/// Domain adapters — normalize domain-specific hits to [PlayableSource].
abstract final class PlaybackNormalize {
  static List<PlayableSource> fromStreamSources(
    List<StreamSource> sources, {
    required String providerId,
    int providerRank = 0,
  }) =>
      normalizeLegacyStreamSources(
        sources: sources,
        providerId: providerId,
        providerRank: providerRank,
      );

  static Future<List<PlayableSource>> rankFromStreamSources({
    required List<StreamSource> sources,
    required String providerId,
    int providerRank = 0,
  }) =>
      PlaybackSelection.rankLegacySources(
        sources: sources,
        providerId: providerId,
        providerRank: providerRank,
      );

  /// KissKH / anime / arabic: list of legacy sources with provider tag.
  static Future<List<PlayableSource>> fromDomainSources({
    required List<StreamSource> sources,
    required String domainProviderId,
    int providerRank = 0,
  }) =>
      PlaybackSelection.rankLegacySources(
        sources: sources,
        providerId: domainProviderId,
        providerRank: providerRank,
      );

  /// Stremio direct URL.
  static PlayableSource fromStremioUrl(
    String url, {
    Map<String, String>? headers,
    int providerRank = 0,
  }) =>
      PlayableSource(
        url: url,
        title: 'Stremio',
        container: url.contains('.m3u8') ? 'hls' : 'mp4',
        headers: headers ?? {},
        providerId: 'stremio_direct',
        providerRank: providerRank,
      );

  /// Torrent / debrid local HTTP URL.
  static PlayableSource fromTorrentUrl(
    String url, {
    int providerRank = 0,
  }) =>
      PlayableSource(
        url: url,
        title: 'Torrent',
        container: 'torrent',
        providerId: 'torrent',
        providerRank: providerRank,
      );
}
