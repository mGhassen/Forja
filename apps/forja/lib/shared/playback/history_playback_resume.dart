import 'package:flutter/material.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
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

  if (!context.mounted) return false;
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

/// Details-screen fallback when direct resume fails.
Future<bool> resumeSavedWebStreamProvider({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> progress,
  Duration? startPosition,
}) =>
    Future.value(false);

/// Details-screen fallback when direct Amri resume fails.
Future<bool> resumeSavedAmriStream({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> progress,
  Duration? startPosition,
}) =>
    Future.value(false);

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

/// Resumes or replays a title from a watch-history entry (Home Continue Watching).
///
/// Always opens **details** first (then auto-plays when applicable) so Back from
/// the player lands on that title — never straight onto Home.
Future<void> resumePlaybackFromHistory(
  BuildContext context,
  Map<String, dynamic> item,
) async {
  try {
    final method = item['method'] as String?;
    final movie = movieFromWatchHistory(item);
    final startPos = resumeStartPositionFromProgress(item);
    if (!context.mounted) return;

    switch (method) {
      case 'torrent':
      case 'stream':
      case 'amri':
      case 'stremio_direct':
        await _openDetailsFallback(
          context,
          item: item,
          movie: movie,
          startPosition: startPos,
          autoPlay: true,
        );
        return;
      case 'trakt_import':
        await _openDetailsFallback(
          context,
          item: item,
          movie: movie,
          startPosition: startPos,
        );
        return;
      default:
        ForjaToast.error('Failed to load video');
    }
  } catch (e) {
    debugPrint('[Resume] Error: $e');
    if (context.mounted) {
      ForjaToast.error('Error: $e');
    }
  }
}
