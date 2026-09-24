import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';

/// How a Sources stream row paints download chrome.
enum SourceDownloadChrome {
  none,
  downloading,
  offline,
}

/// Extract a durable HTTP(S) play URL from a catalog/stream map, if any.
String? streamHttpUrlForDownload(Map<String, dynamic> stream) {
  for (final key in ['url', 'ytId']) {
    final u = stream[key]?.toString().trim() ?? '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
  }
  return null;
}

String mediaIdForDownloadMovie({
  required String? imdbId,
  required Object id,
}) {
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
  final sourceName = (stream['_addonName'] ??
          stream['name'] ??
          stream['title'] ??
          '')
      .toString();
  return DownloadService.instance.findTaskForStream(
    mediaId: mediaId,
    season: season,
    episode: episode,
    streamUrl: streamHttpUrlForDownload(stream),
    sourceName: sourceName.isEmpty ? null : sourceName,
  );
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
  final isOffline =
      task != null && (task.isCompleted || task.isActive);
  if (wantOffline) return isOffline;
  if (wantOnline) return !isOffline;
  return true;
}
