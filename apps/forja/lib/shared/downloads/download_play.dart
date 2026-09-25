import 'package:flutter/widgets.dart';
import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:rust/rust.dart';

/// Opens a finished download in the player.
Future<void> playCompletedDownloadTask(
  BuildContext context,
  DownloadTask task, {
  Movie? movie,
}) async {
  final pinned = offlinePinnedStream(task);
  if (pinned == null) {
    ForjaToast.error(kOfflineDownloadMissingMessage);
    return;
  }
  final local = await offlineLocalPlayForTask(stream: pinned, task: task);
  if (local == null || !local.ok || local.stream == null) {
    ForjaToast.error(local?.error ?? kOfflineDownloadUnplayableMessage);
    return;
  }
  if (!context.mounted) return;
  final url = local.stream!['url']?.toString() ?? '';
  if (url.isEmpty) {
    ForjaToast.error(kOfflineDownloadMissingMessage);
    return;
  }
  final playMovie = movie ??
      Movie(
        id: int.tryParse(task.mediaId) ?? 0,
        title: task.title,
        mediaType: task.type == 'series' || task.type == 'drama'
            ? 'tv'
            : task.type,
        posterPath: task.posterUrl ?? '',
        backdropPath: task.backdropUrl ?? '',
        voteAverage: 0,
        releaseDate: task.year ?? '',
      );
  await AppRouter.openPlayer(
    context,
    streamUrl: url,
    title: task.episodeTitle?.trim().isNotEmpty == true
        ? task.episodeTitle!.trim()
        : task.title,
    movie: playMovie,
    selectedSeason: task.season,
    selectedEpisode: task.episode,
    activeProvider: 'offline',
    streamsPrevalidated: true,
    pinSource: true,
  );
}
