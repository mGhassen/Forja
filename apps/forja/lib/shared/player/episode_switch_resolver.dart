import 'dart:convert';

import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/playback/host_provider_adapter.dart';
import 'package:forja/shared/player/episode_torrent_resolver.dart';
import 'package:rust/rust.dart';

class EpisodeSwitchResult {
  final String streamUrl;
  final String? magnetLink;
  final int? fileIndex;
  final Map<String, String>? headers;
  final List<StreamSource>? sources;
  final String activeProvider;

  const EpisodeSwitchResult({
    required this.streamUrl,
    this.magnetLink,
    this.fileIndex,
    this.headers,
    this.sources,
    required this.activeProvider,
  });
}

List<String> episodeProviderChain({
  Map<String, dynamic>? providers,
  String? activeProvider,
  String? currentProvider,
  String? magnetLink,
}) {
  if (providers != null && providers.isNotEmpty) {
    final keys = providers.keys.toList();
    final current = currentProvider ?? activeProvider;
    if (current != null) {
      final idx = keys.indexOf(current);
      if (idx > 0) {
        return [...keys.sublist(idx), ...keys.sublist(0, idx)];
      }
    }
    return keys;
  }
  if (activeProvider == 'stremio_direct') return const ['stremio_direct'];
  if (magnetLink != null && activeProvider != 'stremio_direct') {
    return const ['torrent'];
  }
  if (activeProvider != null && activeProvider.isNotEmpty) {
    return [activeProvider];
  }
  return const [];
}

Future<EpisodeSwitchResult?> resolveEpisodeForProvider({
  required String providerKey,
  required Movie movie,
  required int season,
  required int episode,
  Map<String, dynamic>? providers,
  String? magnetLink,
  String? stremioId,
  String? stremioAddonBaseUrl,
}) async {
  if (providerKey == 'stremio_direct' && stremioAddonBaseUrl != null) {
    final stremio = StremioService();
    final id = stremioId ?? movie.imdbId;
    if (id == null) return null;

    final streams = await stremio.getStreams(
      baseUrl: stremioAddonBaseUrl,
      type: 'series',
      id: '$id:$season:$episode',
    );
    if (streams.isEmpty) return null;

    for (final raw in streams) {
      if (raw is! Map<String, dynamic>) continue;
      final stream = raw;

      if (stream['url'] != null) {
        Map<String, String>? headers;
        final proxyHeaders = stream['behaviorHints']?['proxyHeaders']?['request'];
        if (proxyHeaders is Map) {
          headers = Map<String, String>.from(proxyHeaders);
        }
        final url = stream['url'] as String;
        final ranked = await PlaybackSelection.rankAndDedupe(
          sources: [
            PlaybackNormalize.fromStremioUrl(url, headers: headers)
                .toStreamSource(),
          ],
          providerId: 'stremio_direct',
        );
        return EpisodeSwitchResult(
          streamUrl: ranked.first.url,
          headers: headers,
          sources: ranked,
          activeProvider: 'stremio_direct',
        );
      }

      if (stream['infoHash'] != null) {
        final infoHash = stream['infoHash'] as String;
        final streamTitle = (stream['title'] ?? stream['name'] ?? '').toString();
        final dn =
            streamTitle.isNotEmpty ? '&dn=${Uri.encodeComponent(streamTitle)}' : '';
        final sourcesList = stream['sources'];
        final trackerParams = StringBuffer();
        if (sourcesList is List) {
          for (final src in sourcesList) {
            if (src is String && src.startsWith('tracker:')) {
              trackerParams
                  .write('&tr=${Uri.encodeComponent(src.substring(8))}');
            }
          }
        }
        final resolvedMagnet =
            'magnet:?xt=urn:btih:$infoHash$dn$trackerParams';

        final settings = SettingsService();
        final playback = await resolveMagnetForPlayback(
          magnet: resolvedMagnet,
          useDebrid: await settings.useDebridForStreams(),
          debridService: await settings.getDebridService(),
          localTorrentEngine: PlatformPlayback.capabilities.localTorrentEngine,
          season: season,
          episode: episode,
        );
        if (playback != null) {
          final ranked = await PlaybackSelection.rankAndDedupe(
            sources: [
              PlaybackNormalize.fromTorrentUrl(playback.url).toStreamSource(),
            ],
            providerId: 'torrent',
          );
          return EpisodeSwitchResult(
            streamUrl: ranked.first.url,
            magnetLink: resolvedMagnet,
            fileIndex: playback.fileIndex,
            sources: ranked,
            activeProvider: 'torrent',
          );
        }
      }
    }
    return null;
  }

  if (providerKey == 'torrent') {
    final playback = await resolveEpisodeTorrentPlayback(
      title: movie.title,
      season: season,
      episode: episode,
    );
    if (playback == null) return null;
    final ranked = await PlaybackSelection.rankAndDedupe(
      sources: [
        PlaybackNormalize.fromTorrentUrl(playback.url).toStreamSource(),
      ],
      providerId: 'torrent',
    );
    return EpisodeSwitchResult(
      streamUrl: ranked.first.url,
      magnetLink: playback.magnet,
      fileIndex: playback.fileIndex,
      sources: ranked,
      activeProvider: 'torrent',
    );
  }

  if (providerKey == 'amri') {
    final result = await StreamExtractor().extractWithAmri(
      tmdbId: movie.id.toString(),
      isMovie: false,
      season: season,
      episode: episode,
    );
    if (result == null) return null;
    return EpisodeSwitchResult(
      streamUrl: result.url,
      headers: result.headers.isNotEmpty ? result.headers : null,
      activeProvider: 'amri',
    );
  }

  if (providers != null && providers.containsKey(providerKey)) {
    final sourcesJson = await HostProviderAdapter.resolveToSourcesJson(
      providerId: providerKey,
      payloadJson: '{}',
      movie: movie,
      providers: providers,
      season: season,
      episode: episode,
    );
    if (sourcesJson == null) return null;
    return _episodeFromSourcesJson(sourcesJson, providerKey, providers);
  }

  if (providerKey.startsWith('nuvio:') ||
      _builtinProviderKeys.contains(providerKey)) {
    final sourcesJson = await HostProviderAdapter.resolveToSourcesJson(
      providerId: providerKey,
      payloadJson: '{}',
      movie: movie,
      providers: const {},
      season: season,
      episode: episode,
    );
    if (sourcesJson == null) return null;
    return _episodeFromSourcesJson(sourcesJson, providerKey, const {});
  }

  final provider = StreamProviders.providers[providerKey];
  if (provider == null || provider['tv'] == null) return null;

  final providerUrl = provider['tv'](movie.id.toString(), season, episode);
  final profile = EmbedExtractProfiles.resolve(providerKey);
  final result = await StreamExtractor().extract(
    providerUrl,
    profile: profile,
    timeout: const Duration(seconds: 20),
    referer: providerUrl,
    providerId: providerKey,
  );
  if (result == null || result.url.isEmpty) return null;
  return EpisodeSwitchResult(
    streamUrl: result.url,
    headers: result.headers.isNotEmpty ? result.headers : null,
    sources: await _rankEpisodeSources(result.sources, providerKey, 0),
    activeProvider: providerKey,
  );
}

Future<EpisodeSwitchResult?> _episodeFromSourcesJson(
  String sourcesJson,
  String providerKey,
  Map<String, dynamic> providers,
) async {
  final decoded = jsonDecode(sourcesJson);
  if (decoded is! List || decoded.isEmpty) return null;
  final first = decoded.first;
  if (first is! Map) return null;
  final url = first['url']?.toString() ?? '';
  if (url.isEmpty) return null;
  final sources = decoded
      .whereType<Map>()
      .map(
        (m) => StreamSource(
          url: m['url']?.toString() ?? '',
          title: m['title']?.toString() ?? 'Stream',
          type: m['container']?.toString() ?? 'hls',
          headers: m['headers'] is Map
              ? Map<String, String>.from(m['headers'] as Map)
              : null,
        ),
      )
      .where((s) => s.url.isNotEmpty)
      .toList();
  final ranked = await _rankEpisodeSources(
    sources,
    providerKey,
    providers.keys.toList().indexOf(providerKey),
  );
  return EpisodeSwitchResult(
    streamUrl: url,
    headers: first['headers'] is Map
        ? Map<String, String>.from(first['headers'] as Map)
        : null,
    sources: ranked,
    activeProvider: providerKey,
  );
}

Future<List<StreamSource>?> _rankEpisodeSources(
  List<StreamSource>? sources,
  String providerId,
  int providerRank,
) async {
  if (sources == null || sources.isEmpty) return sources;
  final ranked = await PlaybackSelection.rankLegacySources(
    sources: sources,
    providerId: providerId,
    providerRank: providerRank,
  );
  return playableSourcesToStreamSources(ranked);
}

const _builtinProviderKeys = {
  'service111477',
  'webstreamr',
  'videasy',
  'vidsrc',
  'vidlink',
  'vixsrc',
  'vidnest',
  'vidzee',
  'vidrock',
  'vidfast',
  '2embed',
  'superembed',
  'autoembed',
  'vidlove',
  'vidsrcsbs',
  '111movies',
  'moviesapi',
  'smashystream',
  'primewire',
};
