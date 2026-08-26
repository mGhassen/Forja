import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:rust/rust.dart';

Movie movieFromWatchHistory(Map<String, dynamic> item) {
  final season = item['season'] as int?;
  final mediaType =
      item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
  return Movie(
    id: item['tmdbId'] as int,
    title: item['title'] as String,
    posterPath: item['posterPath'] as String,
    backdropPath: item['backdropPath'] as String? ?? '',
    overview: '',
    releaseDate: '',
    voteAverage: 0,
    mediaType: mediaType,
    genres: [],
    imdbId: item['imdbId'],
  );
}

String _displayTitle(Movie movie, {int? season, int? episode}) {
  final isTv = movie.mediaType == 'tv';
  if (isTv && season != null && episode != null) {
    return '${movie.title} - S$season E$episode';
  }
  return movie.title;
}

Future<void> _openResolvedStreamPlayer(
  BuildContext context, {
  required Movie movie,
  required String providerId,
  required StreamProviderResolveResult resolved,
  int? season,
  int? episode,
  required Duration startPosition,
}) async {
  final isTv = movie.mediaType == 'tv';
  final sources = resolved.sources ?? <StreamSource>[];
  final ranked = sources.isNotEmpty
      ? await PlaybackSelection.rankLegacySources(
          sources: sources,
          providerId: providerId,
          providerRank: 0,
        ).then(playableSourcesToStreamSources)
      : null;

  await AppRouter.openPlayer(
    context,
    streamUrl: resolved.streamUrl,
    audioUrl: resolved.audioUrl,
    title: _displayTitle(movie, season: season, episode: episode),
    headers: resolved.headers,
    movie: movie,
    providers: StreamProviders.providers,
    activeProvider: providerId,
    selectedSeason: isTv ? season : null,
    selectedEpisode: isTv ? episode : null,
    startPosition: startPosition,
    sources: ranked,
    externalSubtitles: resolved.subtitles,
    fadeTransition: true,
  );
}

Future<bool> _resumeWebStreamProvider(
  BuildContext context, {
  required Map<String, dynamic> item,
  required Movie movie,
  required String providerId,
  required Duration startPosition,
}) async {
  final season = item['season'] as int? ?? 1;
  final episode = item['episode'] as int? ?? 1;
  final cacheKey = WebstreamingStreamCache.cacheKeyFromProgress(
    tmdbId: movie.id,
    mediaType: movie.mediaType,
    season: season,
    episode: episode,
  );

  final cached = await WebstreamingStreamCache.readLive(
    cacheKey,
    probe: probeStreamSourceUrl,
  );
  if (cached != null && cached.sources.isNotEmpty) {
    if (!context.mounted) return false;
    final activeProvider = cached.providerId.isNotEmpty
        ? cached.providerId
        : providerId;
    debugPrint(
      '[Resume] webstreaming cache hit $cacheKey '
      '($activeProvider, ${cached.sources.length})',
    );
    final providerSourcesCache =
        ValueNotifier<Map<String, List<StreamSource>>>({
      activeProvider: cached.sources,
    });
    try {
      await AppRouter.openPlayer(
        context,
        streamUrl: cached.sources.first.url,
        title: _displayTitle(movie, season: season, episode: episode),
        headers: cached.sources.first.headers,
        movie: movie,
        providers: StreamProviders.providers,
        activeProvider: activeProvider,
        selectedSeason: movie.mediaType == 'tv' ? season : null,
        selectedEpisode: movie.mediaType == 'tv' ? episode : null,
        startPosition: startPosition,
        sources: cached.sources,
        providerSourcesCache: providerSourcesCache,
        pinSource: true,
        fadeTransition: true,
      );
    } finally {
      providerSourcesCache.dispose();
    }
    return true;
  }

  final savedStreamUrl = item['streamUrl'] as String?;
  if (savedStreamUrl != null &&
      savedStreamUrl.trim().isNotEmpty &&
      !isTorrentStreamUrl(savedStreamUrl) &&
      !isUnplayableCachedStreamUrl(savedStreamUrl) &&
      await probeStreamSourceUrl(savedStreamUrl, null)) {
    if (!context.mounted) return false;
    debugPrint('[Resume] watch-history streamUrl hit $cacheKey');
    if (isWebStreamProviderId(providerId)) {
      await WebstreamingStreamCache.write(
        cacheKey,
        WebstreamingCacheHit(
          providerId: providerId,
          sources: [
            StreamSource(
              url: savedStreamUrl,
              title: providerId,
              type: savedStreamUrl.contains('.m3u8') ? 'hls' : 'video',
            ),
          ],
        ),
      );
    }
    await AppRouter.openPlayer(
      context,
      streamUrl: savedStreamUrl,
      title: _displayTitle(movie, season: season, episode: episode),
      movie: movie,
      providers: StreamProviders.providers,
      activeProvider: providerId.isNotEmpty ? providerId : 'stream',
      selectedSeason: movie.mediaType == 'tv' ? season : null,
      selectedEpisode: movie.mediaType == 'tv' ? episode : null,
      startPosition: startPosition,
      pinSource: true,
      fadeTransition: true,
    );
    return true;
  }

  final hit = await PlaybackService.resolveWebstreaming(
    movie: movie,
    providers: StreamProviders.providers,
    season: season,
    episode: episode,
    preferredProvider: providerId,
  );
  if (hit == null || hit.streamUrl.isEmpty || !context.mounted) {
    return false;
  }

  final sources = hit.streamSources;
  await WebstreamingStreamCache.write(
    cacheKey,
    WebstreamingCacheHit(providerId: providerId, sources: sources),
  );
  await _openResolvedStreamPlayer(
    context,
    movie: movie,
    providerId: providerId,
    resolved: StreamProviderResolveResult(
      streamUrl: hit.streamUrl,
      audioUrl: hit.audioUrl,
      headers: hit.headers,
      sources: sources,
      subtitles: hit.subtitles,
    ),
    season: season,
    episode: episode,
    startPosition: startPosition,
  );
  return true;
}

Future<bool> _resumeAmriStream(
  BuildContext context, {
  required Map<String, dynamic> item,
  required Movie movie,
  required Duration startPosition,
}) async {
  final isTv = movie.mediaType == 'tv';
  final season = item['season'] as int?;
  final episode = item['episode'] as int?;
  final result = await StreamExtractor().extractWithAmri(
    tmdbId: movie.id.toString(),
    isMovie: !isTv,
    season: isTv ? season : null,
    episode: isTv ? episode : null,
  );
  if (result == null || result.url.isEmpty || !context.mounted) return false;

  await AppRouter.openPlayer(
    context,
    streamUrl: result.url,
    title: _displayTitle(movie, season: season, episode: episode),
    headers: result.headers.isNotEmpty ? result.headers : null,
    movie: movie,
    activeProvider: 'amri',
    selectedSeason: isTv ? season : null,
    selectedEpisode: isTv ? episode : null,
    startPosition: startPosition,
    fadeTransition: true,
  );
  return true;
}

Future<bool> _resumeStremioDirectStream(
  BuildContext context, {
  required Map<String, dynamic> item,
  required Movie movie,
  required Duration startPosition,
}) async {
  final addonBaseUrl = item['stremioAddonBaseUrl'] as String?;
  final stremioId = item['stremioId'] as String? ?? movie.imdbId;
  if (addonBaseUrl == null || addonBaseUrl.isEmpty || stremioId == null) {
    return false;
  }

  final isTv = movie.mediaType == 'tv';
  final season = item['season'] as int?;
  final episode = item['episode'] as int?;
  final type = isTv ? 'series' : 'movie';
  final id = isTv ? '$stremioId:$season:$episode' : stremioId;
  final savedUrl = item['sourceId'] as String? ?? item['streamUrl'] as String?;

  final streams = await StremioService().getStreams(
    baseUrl: addonBaseUrl,
    type: type,
    id: id,
  );
  if (streams.isEmpty || !context.mounted) return false;

  Map<String, dynamic>? matched;
  if (savedUrl != null && savedUrl.isNotEmpty) {
    for (final raw in streams) {
      if (raw is! Map) continue;
      final stream = Map<String, dynamic>.from(raw);
      if (stream['url']?.toString() == savedUrl) {
        matched = stream;
        break;
      }
    }
  }
  matched ??= streams.first is Map
      ? Map<String, dynamic>.from(streams.first as Map)
      : null;
  if (matched == null) return false;

  final profile = PlatformPlayback.capabilities;
  final settings = SettingsService();
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  final precheck = classifyStremioStream(
    matched,
    profile,
    useDebrid: useDebrid,
    debridService: debridService,
  );
  if (precheck == null) {
    if (!context.mounted) return false;
    if (!await ensureLanP2pPlayback(context)) {
      return false;
    }
    if (!context.mounted) return false;
  }
  final resolved = await resolveStremioStream(
    stream: matched,
    profile: profile,
    settings: settings,
    season: season,
    episode: episode,
  );

  if (!context.mounted) return false;
  if (resolved is StremioExternalLink) {
    ForjaToast.info('This stream opens in an external app.');
    return false;
  }
  if (resolved is StremioResolveFailure) {
    if (resolved.message.isNotEmpty) ForjaToast.info(resolved.message);
    return false;
  }
  if (resolved is! StremioPlayable) return false;

  await AppRouter.openPlayer(
    context,
    streamUrl: resolved.streamUrl,
    title: _displayTitle(movie, season: season, episode: episode),
    headers: resolved.headers.isNotEmpty ? resolved.headers : null,
    movie: movie,
    selectedSeason: isTv ? season : null,
    selectedEpisode: isTv ? episode : null,
    startPosition: startPosition,
    activeProvider: 'stremio_direct',
    magnetLink: resolved.magnetLink,
    fileIndex: resolved.fileIndex,
    stremioId: stremioId,
    stremioAddonBaseUrl: addonBaseUrl,
    fadeTransition: true,
  );
  return true;
}

Future<bool> _resumeTorrentStream(
  BuildContext context, {
  required Map<String, dynamic> item,
  required Movie movie,
  required Duration startPosition,
}) async {
  final season = item['season'] as int?;
  final episode = item['episode'] as int?;
  final magnetLink = item['magnetLink'] as String?;
  var fileIndex = item['fileIndex'] as int?;
  if (magnetLink == null || magnetLink.isEmpty) {
    throw Exception('No magnet link saved for this torrent');
  }

  final useDebridSetting = await SettingsService().useDebridForStreams();
  final debridService = await SettingsService().getDebridService();
  final useDebrid = useDebridSetting && debridService != 'None';
  if (!context.mounted) return false;
  if (!await ensureLanP2pPlayback(context)) {
    return false;
  }
  if (!context.mounted) return false;

  final playback = await resolveMagnetForPlayback(
    magnet: magnetLink,
    useDebrid: useDebrid,
    debridService: debridService,
    localTorrentEngine: PlatformPlayback.capabilities.localTorrentEngine,
    season: season,
    episode: episode,
    fileIdx: fileIndex,
  );
  if (playback == null || !context.mounted) return false;

  fileIndex = playback.fileIndex ?? fileIndex;
  final ranked = await PlaybackSelection.rankAndDedupe(
    sources: [
      PlaybackNormalize.fromTorrentUrl(playback.url).toStreamSource(),
    ],
    providerId: 'torrent',
  );

  await AppRouter.openPlayer(
    context,
    streamUrl: ranked.first.url,
    title: _displayTitle(movie, season: season, episode: episode),
    movie: movie,
    selectedSeason: season,
    selectedEpisode: episode,
    magnetLink: magnetLink,
    fileIndex: fileIndex,
    activeProvider: 'torrent',
    startPosition: startPosition,
    sources: ranked,
  );
  return true;
}

Future<void> _openDetailsFallback(
  BuildContext context, {
  required Map<String, dynamic> item,
  required Movie movie,
  required Duration startPosition,
  bool autoPlay = false,
}) async {
  final stremioItemId = item['stremioId'] as String?;
  final stremioAddonBase = item['stremioAddonBaseUrl'] as String?;
  Map<String, dynamic>? stremioItem;
  if (stremioItemId != null &&
      stremioAddonBase != null &&
      !stremioItemId.startsWith('tt')) {
    stremioItem = {
      'id': stremioItemId,
      '_addonBaseUrl': stremioAddonBase,
      'type': item['stremioType'] ?? (item['season'] != null ? 'series' : 'movie'),
      'name': movie.title,
    };
  }

  await AppRouter.openDetails(
    context,
    movie: movie,
    stremioItem: stremioItem,
    initialSeason: item['season'] as int?,
    initialEpisode: item['episode'] as int?,
    startPosition: startPosition,
    autoPlay: autoPlay,
  );
}

/// Same contract as details green Play / Resume when Webstreaming is off:
/// Forja Auto if enabled, otherwise open details (Sources).
Future<void> _resumeLikeGreenPlay(
  BuildContext context, {
  required Map<String, dynamic> item,
  required Movie movie,
  required Duration startPosition,
}) async {
  if (await engineAutoPlayEnabled()) {
    if (!context.mounted) return;
    final isTv = movie.mediaType == 'tv';
    final season = item['season'] as int?;
    final episode = item['episode'] as int?;
    final s = isTv ? (season ?? 1) : null;
    final e = isTv ? (episode ?? 1) : null;
    await runEngineAutoPlay(
      context: context,
      movie: movie,
      engineCategory:
          EngineCategories.panelCategoryFor(mediaType: movie.mediaType),
      season: s,
      episode: e,
      startPosition: startPosition,
      stremioId: movie.imdbId,
      loadingSubtitle: s != null && e != null
          ? 'S${s.toString().padLeft(2, '0')}E${e.toString().padLeft(2, '0')}'
          : null,
    );
    return;
  }
  if (!context.mounted) return;
  await _openDetailsFallback(
    context,
    item: item,
    movie: movie,
    startPosition: startPosition,
    autoPlay: true,
  );
}

/// Details-screen fallback when direct resume fails.
Future<bool> resumeSavedWebStreamProvider({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> progress,
  Duration? startPosition,
}) {
  final providerId = progress['sourceId'] as String? ?? '';
  if (!isWebStreamProviderId(providerId)) return Future.value(false);
  final pos = startPosition ?? resumeStartPositionFromProgress(progress);
  return _resumeWebStreamProvider(
    context,
    item: progress,
    movie: movie,
    providerId: providerId,
    startPosition: pos,
  );
}

/// Details-screen fallback when direct Amri resume fails.
Future<bool> resumeSavedAmriStream({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> progress,
  Duration? startPosition,
}) {
  final pos = startPosition ?? resumeStartPositionFromProgress(progress);
  return _resumeAmriStream(
    context,
    item: progress,
    movie: movie,
    startPosition: pos,
  );
}

/// Details-screen direct resume for a saved torrent magnet.
Future<bool> resumeSavedTorrentStream({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> progress,
  Duration? startPosition,
}) {
  final pos = startPosition ?? resumeStartPositionFromProgress(progress);
  return _resumeTorrentStream(
    context,
    item: progress,
    movie: movie,
    startPosition: pos,
  );
}

/// Details-screen direct resume for a saved Stremio direct stream.
Future<bool> resumeSavedStremioDirectStream({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> progress,
  Duration? startPosition,
}) {
  final pos = startPosition ?? resumeStartPositionFromProgress(progress);
  return _resumeStremioDirectStream(
    context,
    item: progress,
    movie: movie,
    startPosition: pos,
  );
}

/// Resumes or replays a title from a watch-history entry (Continue Watching, hero Watch Now).
Future<void> resumePlaybackFromHistory(
  BuildContext context,
  Map<String, dynamic> item,
) async {
  try {
    final method = item['method'] as String;
    final movie = movieFromWatchHistory(item);
    // ≥90% (incl. false early-EOF “finished”) must restart from 0 - raw
    // position seeks into credits and looks like play is broken.
    final startPos = resumeStartPositionFromProgress(item);

    switch (method) {
      case 'torrent':
        final ok = await _resumeTorrentStream(
          context,
          item: item,
          movie: movie,
          startPosition: startPos,
        );
        if (!ok && context.mounted) {
          ForjaToast.error('Failed to load video');
        }
        return;
      case 'stream':
        final sourceId = item['sourceId'] as String? ?? '';
        // Green Play owns web sniff only while Webstreaming is on.
        if (await PlaySourceEffective.webstreaming() &&
            isWebStreamProviderId(sourceId)) {
          final ok = await _resumeWebStreamProvider(
            context,
            item: item,
            movie: movie,
            providerId: sourceId,
            startPosition: startPos,
          );
          if (!ok && context.mounted) {
            await _resumeLikeGreenPlay(
              context,
              item: item,
              movie: movie,
              startPosition: startPos,
            );
          }
          return;
        }
        if (context.mounted) {
          await _resumeLikeGreenPlay(
            context,
            item: item,
            movie: movie,
            startPosition: startPos,
          );
        }
        return;
      case 'amri':
        if (await PlaySourceEffective.webstreaming()) {
          final ok = await _resumeAmriStream(
            context,
            item: item,
            movie: movie,
            startPosition: startPos,
          );
          if (ok || !context.mounted) return;
        }
        if (context.mounted) {
          await _resumeLikeGreenPlay(
            context,
            item: item,
            movie: movie,
            startPosition: startPos,
          );
        }
        return;
      case 'stremio_direct':
        final ok = await _resumeStremioDirectStream(
          context,
          item: item,
          movie: movie,
          startPosition: startPos,
        );
        if (!ok && context.mounted) {
          await _openDetailsFallback(
            context,
            item: item,
            movie: movie,
            startPosition: startPos,
            autoPlay: true,
          );
        }
        return;
      case 'trakt_import':
        if (context.mounted) {
          await _openDetailsFallback(
            context,
            item: item,
            movie: movie,
            startPosition: startPos,
          );
        }
        return;
      default:
        if (context.mounted) ForjaToast.error('Failed to load video');
    }
  } catch (e) {
    debugPrint('[Resume] Error: $e');
    if (context.mounted) {
      ForjaToast.error('Error: $e');
    }
  }
}
