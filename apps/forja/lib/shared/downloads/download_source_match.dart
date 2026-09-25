import 'dart:io';

import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/playback/probe/playback_stream_guards.dart';

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

List<String> streamDownloadNames(Map<String, dynamic> stream) {
  final out = <String>[];
  for (final key in ['_addonName', 'name', 'title']) {
    final value = stream[key]?.toString().trim() ?? '';
    if (value.isEmpty) continue;
    if (out.any((n) => n.toLowerCase() == value.toLowerCase())) continue;
    out.add(value);
  }
  return out;
}

/// Provider chip for a Sources row (`engine:castle`, `nuvio:id`).
List<String> streamDownloadPluginKeys(Map<String, dynamic> stream) {
  final out = <String>[];
  void add(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    if (!downloadLabelIsPluginChip(value)) return;
    if (out.any((n) => n.toLowerCase() == value.toLowerCase())) return;
    out.add(value);
  }

  final engineId = stream['_enginePluginId']?.toString() ?? '';
  if (engineId.trim().isNotEmpty) add('engine:${engineId.trim()}');
  final nuvioId = stream['_nuvioScraperId']?.toString() ?? '';
  if (nuvioId.trim().isNotEmpty) add('nuvio:${nuvioId.trim()}');
  add(stream['_addonBaseUrl']?.toString() ?? '');
  return out;
}

DownloadTask? downloadTaskForStream({
  required String mediaId,
  int? season,
  int? episode,
  required Map<String, dynamic> stream,
}) {
  final names = streamDownloadNames(stream);
  return DownloadService.instance.findTaskForStream(
    mediaId: mediaId,
    season: season,
    episode: episode,
    streamUrl: streamHttpUrlForDownload(stream),
    sourceName: names.isEmpty ? null : names.first,
    taskId: stream['_downloadTaskId']?.toString(),
    names: names,
    pluginKeys: streamDownloadPluginKeys(stream),
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
  final catalogUrl = streamHttpUrlForDownload(stream);
  final rowKey = catalogStreamRowProgressKey(stream);
  final copy = Map<String, dynamic>.from(stream);
  copy['url'] = fileUrl;
  if (catalogUrl != null) copy[kOfflinePlayCatalogUrlKey] = catalogUrl;
  if (rowKey.isNotEmpty) copy[kOfflinePlayRowKeyKey] = rowKey;
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
  final names = streamDownloadNames(stream);
  return downloadTaskMatchRank(
        task: task,
        mediaId: task.mediaId,
        season: task.season,
        episode: task.episode,
        streamUrl: streamHttpUrlForDownload(stream),
        sourceName: names.isEmpty ? null : names.first,
        names: names,
        pluginKeys: streamDownloadPluginKeys(stream),
      ) !=
      DownloadTaskMatchRank.none;
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

/// True when [url] is a completed download file on this device.
///
/// [tasks] overrides the live queue (tests). Cloud URLs and in-progress
/// downloads stay false.
bool isOfflineDownloadPlayUrl(
  String? url, {
  Iterable<DownloadTask>? tasks,
}) {
  final path = localFilePathFromPlayUrl(url);
  if (path == null || path.isEmpty) return false;
  final list = tasks ?? DownloadService.instance.tasksNotifier.value;
  for (final task in list) {
    if (!task.isCompleted) continue;
    final raw = task.targetFilePath.trim();
    if (raw.isEmpty) continue;
    final target = localFilePathFromPlayUrl(raw) ?? raw;
    if (_sameLocalPath(path, target)) return true;
  }
  return false;
}

/// Completed download whose file is [url], if any.
DownloadTask? downloadTaskForLocalPlayUrl(
  String? url, {
  Iterable<DownloadTask>? tasks,
}) {
  final path = localFilePathFromPlayUrl(url);
  if (path == null || path.isEmpty) return null;
  final list = tasks ?? DownloadService.instance.tasksNotifier.value;
  for (final task in list) {
    if (!task.isCompleted) continue;
    final raw = task.targetFilePath.trim();
    if (raw.isEmpty) continue;
    final target = localFilePathFromPlayUrl(raw) ?? raw;
    if (_sameLocalPath(path, target)) return task;
  }
  return null;
}

/// Sources row for the saved file [playUrl] is playing.
///
/// Used when the player only has the local path (Downloads → Play). An open
/// session that still has the remote catalog URL matches through that URL
/// instead, so quality rows stay distinct.
bool streamMatchesPlayingOfflineDownload(
  Map<String, dynamic> stream, {
  required String? playUrl,
  Iterable<DownloadTask>? tasks,
}) {
  final task = downloadTaskForLocalPlayUrl(playUrl, tasks: tasks);
  if (task == null) return false;
  final rowTaskId = stream['_downloadTaskId']?.toString() ?? '';
  if (rowTaskId.isNotEmpty && rowTaskId == task.id) return true;
  final taskUrl = task.rawUrl?.trim() ?? '';
  final streamUrl = streamHttpUrlForDownload(stream) ?? '';
  if (taskUrl.isNotEmpty && streamUrl == taskUrl) return true;
  final rowPath = localFilePathFromPlayUrl(stream['url']?.toString());
  final playPath = localFilePathFromPlayUrl(playUrl);
  if (rowPath != null &&
      playPath != null &&
      _sameLocalPath(rowPath, playPath)) {
    return true;
  }
  return false;
}

/// Absolute path for a `file://` play URL or a raw filesystem path.
String? localFilePathFromPlayUrl(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('file:')) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'file') return null;
    try {
      return uri.toFilePath();
    } catch (_) {
      return null;
    }
  }
  if (raw.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(raw)) {
    return raw;
  }
  return null;
}

bool _sameLocalPath(String a, String b) {
  String norm(String p) =>
      p.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final left = norm(a);
  final right = norm(b);
  if (Platform.isWindows) return left.toLowerCase() == right.toLowerCase();
  return left == right;
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
