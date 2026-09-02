import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/episode_torrent_resolver.dart';
import 'package:rust/rust.dart';

export 'episode_torrent_resolver.dart' show catalogOpenTorrentEp;

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
  final current = currentProvider ?? activeProvider;
  if (current == 'stremio_direct') return const ['stremio_direct'];
  if (current == 'torrent' ||
      (magnetLink != null &&
          magnetLink.isNotEmpty &&
          (current == null || current.isEmpty))) {
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
  bool torrentEp = false,
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
        if (isTorrentStreamUrl(url)) {
          final settings = SettingsService();
          final playback = await resolveMagnetForPlayback(
            magnet: url,
            useDebrid: await settings.useDebridForStreams(),
            debridService: await settings.getDebridService(),
            localTorrentEngine:
                PlatformPlayback.capabilities.localTorrentEngine,
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
              magnetLink: url,
              fileIndex: playback.fileIndex,
              sources: ranked,
              activeProvider: 'torrent',
            );
          }
          continue;
        }
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
          fileIdx: stremioStreamFileIdx(stream),
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
    if (magnetLink != null && magnetLink.isNotEmpty) {
      try {
        final settings = SettingsService();
        final playback = await resolveMagnetForPlayback(
          magnet: magnetLink,
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
            magnetLink: magnetLink,
            fileIndex: playback.fileIndex,
            sources: ranked,
            activeProvider: 'torrent',
          );
        }
      } catch (e) {
        if (e is DebridAuthException) rethrow;
      }
    }
    final playback = await resolveEpisodeTorrentPlayback(
      title: movie.title,
      season: season,
      episode: episode,
      imdbId: movie.imdbId,
      torrentEp: torrentEp,
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

  return null;
}
