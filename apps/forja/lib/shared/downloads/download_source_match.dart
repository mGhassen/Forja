import 'dart:io';

import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';

/// How a Sources stream row paints download chrome.
enum SourceDownloadChrome { none, downloading, offline }

/// Extract a durable HTTP(S) play URL from a catalog/stream map, if any.
String? streamHttpUrlForDownload(Map<String, dynamic> stream) {
  for (final key in ['url', 'ytId']) {
    final u = stream[key]?.toString().trim() ?? '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
  }
  return null;
}

String mediaIdForDownloadMovie({required String? imdbId, required Object id}) {
  final imdb = imdbId?.trim();
  if (imdb != null && imdb.isNotEmpty) return imdb;
  return id.toString();
}

SourceDownloadChrome chromeForDownloadTask(DownloadTask? task) {
  if (task == null) return SourceDownloadChrome.none;
  if (task.isCompleted) return SourceDownloadChrome.offline;
  if (task.isActive) return SourceDownloadChrome.downloading;
  return SourceDownloadChrome.none;
}

DownloadTask? downloadTaskForStream({
  required String mediaId,
  int? season,
  int? episode,
  required Map<String, dynamic> stream,
}) {
  final sourceName =
      (stream['_addonName'] ?? stream['name'] ?? stream['title'] ?? '')
          .toString();
  return DownloadService.instance.findTaskForStream(
    mediaId: mediaId,
    season: season,
    episode: episode,
    streamUrl: streamHttpUrlForDownload(stream),
    sourceName: sourceName.isEmpty ? null : sourceName,
  );
}

/// A finished download rewritten as a local play map, or why it cannot play.
class OfflineLocalPlay {
  const OfflineLocalPlay._({this.stream, this.error});

  final Map<String, dynamic>? stream;
  final String? error;

  bool get ok => stream != null;
}

/// When [task] is a finished download, play that file. Null means the row is
/// not saved, so the caller keeps the remote stream.
Future<OfflineLocalPlay?> offlineLocalPlayForTask({
  required Map<String, dynamic> stream,
  required DownloadTask? task,
}) async {
  if (task == null || !task.isCompleted) return null;
  final path = task.targetFilePath.trim();
  if (path.isEmpty) {
    return const OfflineLocalPlay._(error: kOfflineDownloadMissingMessage);
  }
  final file = File(
    path.startsWith('file://') ? Uri.parse(path).toFilePath() : path,
  );
  if (!await file.exists()) {
    return const OfflineLocalPlay._(error: kOfflineDownloadMissingMessage);
  }
  try {
    final raf = await file.open();
    try {
      final head = await raf.read(512);
      if (!looksLikeMediaContainerBytes(head)) {
        return const OfflineLocalPlay._(
          error: kOfflineDownloadUnplayableMessage,
        );
      }
    } finally {
      await raf.close();
    }
  } catch (_) {
    return const OfflineLocalPlay._(error: kOfflineDownloadUnreadableMessage);
  }
  final fileUrl = path.startsWith('file://')
      ? path
      : Uri.file(file.path).toString();
  final copy = Map<String, dynamic>.from(stream);
  copy['url'] = fileUrl;
  copy.remove('headers');
  final hints = copy['behaviorHints'];
  if (hints is Map) {
    final next = Map<String, dynamic>.from(hints);
    next.remove('proxyHeaders');
    copy['behaviorHints'] = next;
  }
  return OfflineLocalPlay._(stream: copy);
}

/// Marker on a Sources row built from a download, before provider search.
const kOfflinePinnedStreamKey = '_offlinePinned';

/// Playable Sources row for a saved or in-progress download.
///
/// Shown immediately so Sources does not wait for provider search. The remote
/// URL stays on the row when we have one (Cloud play, and later dedupe against
/// the provider result). Tap still opens the file once the download is finished.
Map<String, dynamic>? offlinePinnedStream(DownloadTask task) {
  if (!task.isActive && !task.isCompleted) return null;
  final name = task.sourceName.trim().isEmpty
      ? 'Download'
      : task.sourceName.trim();
  // Keep the remote URL when we have one so the row matches the provider
  // stream later and Cloud play can use it. Tap still opens the file via
  // [offlineLocalPlayForTask] once the download is finished.
  var url = task.rawUrl?.trim() ?? '';
  if (url.isEmpty && task.isCompleted) {
    final path = task.targetFilePath.trim();
    if (path.isNotEmpty) {
      url = path.startsWith('file://') ? path : Uri.file(path).toString();
    }
  }
  if (url.isEmpty) return null;
  return {
    'url': url,
    'name': name,
    'title': name,
    '_addonName': name,
    '_downloadTaskId': task.id,
    kOfflinePinnedStreamKey: true,
    if (task.totalBytes > 0) 'size': DownloadTask.formatBytes(task.totalBytes),
  };
}

/// True when [stream] is a provider row that already represents [task].
bool providerStreamCoversDownloadTask(
  Map<String, dynamic> stream,
  DownloadTask task,
) {
  if (stream[kOfflinePinnedStreamKey] == true) return false;
  if (task.mediaId.isEmpty) return false;
  final url = streamHttpUrlForDownload(stream) ?? '';
  final taskUrl = task.rawUrl?.trim() ?? '';
  if (url.isNotEmpty && taskUrl.isNotEmpty && url == taskUrl) return true;
  final name = (stream['_addonName'] ?? stream['name'] ?? stream['title'] ?? '')
      .toString()
      .trim();
  final source = task.sourceName.trim();
  return name.isNotEmpty &&
      source.isNotEmpty &&
      name.toLowerCase() == source.toLowerCase();
}

/// Active and completed downloads for this title that are not already a row
/// in [visibleProviderStreams].
List<Map<String, dynamic>> offlineStreamsAheadOfProviderSearch({
  required Iterable<DownloadTask> tasks,
  required String mediaId,
  int? season,
  int? episode,
  required Iterable<Map<String, dynamic>> visibleProviderStreams,
}) {
  if (mediaId.isEmpty) return const [];
  final out = <Map<String, dynamic>>[];
  for (final task in tasks) {
    if (task.mediaId != mediaId) continue;
    if (task.season != season || task.episode != episode) continue;
    if (!task.isActive && !task.isCompleted) continue;
    final covered = visibleProviderStreams.any(
      (stream) => providerStreamCoversDownloadTask(stream, task),
    );
    if (covered) continue;
    final pinned = offlinePinnedStream(task);
    if (pinned != null) out.add(pinned);
  }
  return out;
}

/// Filter ids for Sources → Filters → Offline.
const kSourcesOfflineFilterId = 'offline';
const kSourcesOnlineFilterId = 'online';

bool streamMatchesOfflineFilter({
  required Set<String> offlineFilters,
  required DownloadTask? task,
}) {
  if (offlineFilters.isEmpty) return true;
  final wantOffline = offlineFilters.contains(kSourcesOfflineFilterId);
  final wantOnline = offlineFilters.contains(kSourcesOnlineFilterId);
  if (wantOffline && wantOnline) return true;
  final isOffline = task != null && (task.isCompleted || task.isActive);
  if (wantOffline) return isOffline;
  if (wantOnline) return !isOffline;
  return true;
}
