import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/downloads/open_settings_downloads.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:rust/rust.dart';

String _downloadTypeForMovie(Movie movie) {
  final mt = movie.mediaType.toLowerCase();
  if (mt == 'tv' || mt == 'series') return 'series';
  if (mt == 'anime') return 'anime';
  return 'movie';
}

String _mediaIdForDownload(Movie movie) {
  final imdb = movie.imdbId?.trim();
  if (imdb != null && imdb.isNotEmpty) return imdb;
  return movie.id.toString();
}

/// Enqueue offline download for a Sources-panel Stremio/Nuvio/engine row.
Future<DownloadTask?> enqueueStremioStreamDownload({
  required Movie movie,
  required Map<String, dynamic> stream,
  int? season,
  int? episode,
}) async {
  final profile = PlatformPlayback.capabilities;
  final precheck = classifyStremioStream(stream, profile);

  if (precheck is StremioResolveFailure) {
    ForjaToast.info(precheck.message);
    return null;
  }

  if (precheck is StremioPlayable) {
    final url = precheck.streamUrl.trim();
    final reject = offlineDownloadRejectReason(url);
    if (reject != null) {
      ForjaToast.error(reject, duration: const Duration(seconds: 4));
      return null;
    }
    return enqueueVodDownload(
      title: movie.title,
      mediaId: _mediaIdForDownload(movie),
      type: _downloadTypeForMovie(movie),
      season: season,
      episode: episode,
      posterUrl: movie.posterPath.isNotEmpty ? movie.posterPath : null,
      backdropUrl: movie.backdropPath.isNotEmpty ? movie.backdropPath : null,
      year: movie.releaseDate.isNotEmpty
          ? movie.releaseDate.split('-').first
          : null,
      url: url,
      headers: precheck.headers,
      sourceName: (stream['_addonName'] ??
              stream['name'] ??
              stream['title'] ??
              'Stream')
          .toString(),
      providerId: catalogHttpPlayProviderId(stream),
    );
  }

  if (precheck is StremioExternalLink) {
    ForjaToast.info('External links can’t be saved offline');
    return null;
  }

  ForjaToast.info("Torrents aren't available for offline download yet");
  return null;
}

/// Enqueues the stream currently playing in a VOD player.
Future<DownloadTask?> enqueuePlayerCurrentDownload({
  required String url,
  Map<String, String>? headers,
  Movie? movie,
  required String fallbackTitle,
  int? season,
  int? episode,
  String? sourceName,
  String? providerId,
}) {
  final title = movie?.title.trim().isNotEmpty == true
      ? movie!.title
      : fallbackTitle;
  final mediaId = movie?.imdbId?.trim().isNotEmpty == true
      ? movie!.imdbId!.trim()
      : (movie?.id.toString() ?? title);
  final mt = (movie?.mediaType ?? 'movie').toLowerCase();
  final type = (mt == 'tv' || mt == 'series')
      ? 'series'
      : (mt == 'anime' ? 'anime' : 'movie');
  return enqueueVodDownload(
    title: title,
    mediaId: mediaId,
    type: type,
    season: season,
    episode: episode,
    posterUrl: movie?.posterPath.isNotEmpty == true ? movie!.posterPath : null,
    backdropUrl:
        movie?.backdropPath.isNotEmpty == true ? movie!.backdropPath : null,
    year: movie?.releaseDate.isNotEmpty == true
        ? movie!.releaseDate.split('-').first
        : null,
    url: url,
    headers: headers,
    sourceName: sourceName,
    providerId: providerId,
  );
}

/// Enqueues an HTTP/HLS VOD download and toasts with a View → Downloads action.
Future<DownloadTask?> enqueueVodDownload({
  required String title,
  required String mediaId,
  required String type,
  int? season,
  int? episode,
  String? episodeTitle,
  String? posterUrl,
  String? backdropUrl,
  String? year,
  required String url,
  Map<String, String>? headers,
  String? sourceName,
  String? providerId,
}) async {
  final rawUrl = url.trim();
  final reject = offlineDownloadRejectReason(rawUrl);
  if (reject != null) {
    ForjaToast.error(reject, duration: const Duration(seconds: 4));
    return null;
  }

  try {
    final resolved = resolvePlaybackHttpHeaders(
      headers,
      streamUrl: rawUrl,
      providerId: providerId,
    );
    final task = await DownloadService.instance.startDownload(
      title: title,
      mediaId: mediaId,
      type: type,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      url: rawUrl,
      headers: resolved,
      sourceName: sourceName,
    );
    ForjaToast.success(
      'Downloading $title',
      duration: const Duration(seconds: 5),
      actionLabel: 'View',
      onAction: openSettingsDownloads,
    );
    return task;
  } catch (e) {
    ForjaToast.error(
      'Download failed to start',
      duration: const Duration(seconds: 4),
    );
    return null;
  }
}
