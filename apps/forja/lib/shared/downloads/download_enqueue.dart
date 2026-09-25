import 'dart:async';

import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_size_probe.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/downloads/open_settings_downloads.dart';
import 'package:forja/shared/downloads/storage_space_helper.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:rust/rust.dart';

/// Row label for a saved file. Prefer the Sources name (`Castle · Shared`).
/// A provider chip (`engine:castle`) is the fallback when the player has no
/// row label — Sources then binds every row of that provider to this file.
String downloadSourceLabel({String? catalogName, String? providerId}) {
  final label = catalogName?.trim() ?? '';
  if (label.isNotEmpty && !downloadLabelIsPluginChip(label)) return label;
  final pid = providerId?.trim() ?? '';
  if (pid.isNotEmpty) return pid;
  return 'Stream';
}

String _mediaIdForDownload(Movie movie) {
  final imdb = movie.imdbId?.trim();
  if (imdb != null && imdb.isNotEmpty) return imdb;
  return movie.id.toString();
}

/// Inline Sources-card download confirm payload (portal delete / share style).
class SourceDownloadPrep {
  const SourceDownloadPrep({
    required this.sizeLabel,
    required this.canConfirm,
    required this.commit,
    this.detailLine,
    this.blockReason,
  });

  /// e.g. `1.20 GB`, `~420 MB`, or `Size unknown`.
  final String sizeLabel;

  /// Free space or source name under the size line.
  final String? detailLine;

  /// False when DASH / not downloadable / not enough space.
  final bool canConfirm;

  final String? blockReason;

  /// Starts the transfer after the user taps Yes on the card.
  final Future<void> Function() commit;
}

/// Probe + build [SourceDownloadPrep] for a Sources-panel stream row.
Future<SourceDownloadPrep?> prepareStremioStreamDownload({
  required Movie movie,
  required Map<String, dynamic> stream,
  int? season,
  int? episode,
}) async {
  if (!PlatformInfo.offlineDownloadsEnabled) return null;
  final profile = PlatformPlayback.capabilities;
  final precheck = classifyStremioStream(stream, profile);

  if (precheck is StremioResolveFailure) {
    ForjaToast.info(precheck.message);
    return null;
  }

  if (precheck is StremioExternalLink) {
    ForjaToast.info('External links can’t be saved offline');
    return null;
  }

  if (precheck is! StremioPlayable) {
    ForjaToast.info("Torrents aren't available for offline download yet");
    return null;
  }

  final url = precheck.streamUrl.trim();
  final sourceName = (stream['_addonName'] ??
          stream['name'] ??
          stream['title'] ??
          'Stream')
      .toString();
  final providerId = catalogHttpPlayProviderId(stream);
  final resolved = resolvePlaybackHttpHeaders(
    precheck.headers,
    streamUrl: url,
    providerId: providerId,
  );

  final reject = offlineDownloadRejectReason(url, headers: resolved);
  if (reject != null) {
    ForjaToast.error(reject, duration: const Duration(seconds: 4));
    return null;
  }

  final probe = await probeDownloadSize(url: url, headers: resolved);
  final err = (probe.error ?? '').toLowerCase();
  if (err == 'dash') {
    return SourceDownloadPrep(
      sizeLabel: "DASH streams can't be saved offline yet",
      canConfirm: false,
      blockReason: 'dash',
      commit: () async {},
    );
  }
  if (err == 'not downloadable') {
    return SourceDownloadPrep(
      sizeLabel: 'This stream can’t be saved offline',
      canConfirm: false,
      blockReason: 'blocked',
      commit: () async {},
    );
  }

  String? freeLine;
  var enough = true;
  try {
    final dir = await DownloadPathHelper.getDownloadsDirectoryPath();
    final space = await StorageSpaceHelper.getAvailableSpace(dir);
    if (space != null) {
      freeLine = 'Free ${space.freeFormatted}';
      if (probe.hasSize) {
        enough = await StorageSpaceHelper.hasEnoughSpace(dir, probe.bytes);
      }
    }
  } catch (_) {}

  if (!enough) {
    return SourceDownloadPrep(
      sizeLabel: probe.sizeLabel,
      detailLine: freeLine,
      canConfirm: false,
      blockReason: 'space',
      commit: () async {},
    );
  }

  final detailParts = <String>[
    if (sourceName.trim().isNotEmpty) sourceName.trim(),
    ?freeLine,
  ];

  return SourceDownloadPrep(
    sizeLabel: probe.sizeLabel,
    detailLine: detailParts.isEmpty ? null : detailParts.join(' · '),
    canConfirm: true,
    commit: () async {
      await enqueueVodDownload(
        title: movie.title,
        mediaId: _mediaIdForDownload(movie),
        type: downloadTypeForMovie(movie),
        season: season,
        episode: episode,
        posterUrl: movie.posterPath.isNotEmpty ? movie.posterPath : null,
        backdropUrl: movie.backdropPath.isNotEmpty ? movie.backdropPath : null,
        year: movie.releaseDate.isNotEmpty
            ? movie.releaseDate.split('-').first
            : null,
        overview: movie.overview.trim().isEmpty ? null : movie.overview.trim(),
        url: url,
        headers: resolved,
        sourceName: sourceName,
        providerId: providerId,
        headersAlreadyResolved: true,
      );
    },
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
  String? overview,
  required String url,
  Map<String, String>? headers,
  String? sourceName,
  String? providerId,
  String? addonName,
  bool headersAlreadyResolved = false,
}) async {
  if (!PlatformInfo.offlineDownloadsEnabled) return null;
  final rawUrl = url.trim();

  try {
    final resolved = headersAlreadyResolved
        ? Map<String, String>.from(headers ?? const {})
        : resolvePlaybackHttpHeaders(
            headers,
            streamUrl: rawUrl,
            providerId: providerId,
          );
    final reject = offlineDownloadRejectReason(rawUrl, headers: resolved);
    if (reject != null) {
      ForjaToast.error(reject, duration: const Duration(seconds: 4));
      return null;
    }
    // One offline slot per title (season/episode). A second Sources tap must
    // not pretend a new transfer started when HdHub (etc.) is already going.
    final existing = DownloadService.instance.findActiveOrCompleted(
      mediaId: mediaId,
      season: season,
      episode: episode,
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
      addonName: addonName ?? providerId,
    );
    final sameSlot = existing != null && existing.id == task.id;
    if (sameSlot && existing.isCompleted) {
      ForjaToast.info(
        'Already saved offline',
        duration: const Duration(seconds: 5),
        actionLabel: 'View',
        onAction: openSettingsDownloads,
      );
    } else if (sameSlot &&
        (existing.isDownloading ||
            existing.status == DownloadStatus.queued)) {
      ForjaToast.info(
        'Already downloading $title',
        duration: const Duration(seconds: 5),
        actionLabel: 'View',
        onAction: openSettingsDownloads,
      );
    } else {
      ForjaToast.success(
        'Downloading $title',
        duration: const Duration(seconds: 5),
        actionLabel: 'View',
        onAction: openSettingsDownloads,
      );
    }
    unawaited(
      DownloadPageStore.capture(
        mediaId: mediaId,
        type: type,
        title: title,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        year: year,
        overview: overview,
      ),
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
