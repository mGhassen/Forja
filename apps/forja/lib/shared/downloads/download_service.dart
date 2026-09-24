import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/downloads/hls_download_engine.dart';
import 'package:forja/shared/downloads/storage_space_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Host-owned VOD offline download manager (Phase 1 — HTTP Range + HLS).
///
/// No P2P / debrid / magnet. Empty or non-downloadable URLs are rejected.
class DownloadService {
  static final DownloadService instance = DownloadService._internal();
  factory DownloadService() => instance;
  DownloadService._internal();

  final ValueNotifier<List<DownloadTask>> tasksNotifier =
      ValueNotifier<List<DownloadTask>>([]);
  bool _isInitialized = false;

  final Map<String, HttpClientRequest> _httpRequests = {};
  final Map<String, StreamSubscription<List<int>>> _httpSubscriptions = {};
  final Map<String, IOSink> _httpFileSinks = {};
  final Set<String> _canceledOrPausedTaskIds = {};

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadPersistedTasks();
    _isInitialized = true;
  }

  static const String _storageFilename = 'forja_download_tasks.json';

  Future<File> _getStorageFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File(p.join(docDir.path, _storageFilename));
  }

  Future<void> _loadPersistedTasks() async {
    try {
      final file = await _getStorageFile();
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(content);
      final tasks = <DownloadTask>[];

      for (final item in jsonList) {
        if (item is Map) {
          var task = DownloadTask.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.queued) {
            task = task.copyWith(status: DownloadStatus.paused);
          }
          if (task.status == DownloadStatus.completed) {
            final f = File(task.targetFilePath);
            if (!f.existsSync()) {
              task = task.copyWith(
                status: DownloadStatus.failed,
                error: 'File was moved or deleted from disk',
              );
            }
          }
          tasks.add(task);
        }
      }

      tasksNotifier.value = tasks;
      _updateWakelockState();
    } catch (e) {
      debugPrint('[DownloadService] Failed to load persisted tasks: $e');
    }
  }

  Future<void> _persistTasks() async {
    try {
      final file = await _getStorageFile();
      final jsonList = tasksNotifier.value.map((t) => t.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(encoded);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('[DownloadService] Failed to persist tasks: $e');
    }
  }

  void _updateTask(DownloadTask updated) {
    final current = List<DownloadTask>.from(tasksNotifier.value);
    final idx = current.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      current[idx] = updated;
      tasksNotifier.value = current;
      _persistTasks();
    }
    _updateWakelockState();
  }

  void _updateWakelockState() {
    final hasActive = tasksNotifier.value
        .any((t) => t.status == DownloadStatus.downloading);
    if (hasActive) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  /// Sum of on-disk bytes for completed (and in-progress received) tasks.
  int get totalUsedBytes {
    var total = 0;
    for (final t in tasksNotifier.value) {
      if (t.status == DownloadStatus.completed) {
        total += t.totalBytes > 0 ? t.totalBytes : t.receivedBytes;
      } else if (t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.paused) {
        total += t.receivedBytes;
      }
    }
    return total;
  }

  /// Completed task for this media (and optional season/episode), if any.
  DownloadTask? findCompletedFor(String mediaId, int? season, int? episode) {
    for (final t in tasksNotifier.value) {
      if (!t.isCompleted) continue;
      if (t.mediaId != mediaId) continue;
      if (t.season != season || t.episode != episode) continue;
      return t;
    }
    return null;
  }

  /// Active (queued/downloading/paused) or completed task for dedup.
  DownloadTask? findActiveOrCompleted({
    required String mediaId,
    int? season,
    int? episode,
  }) {
    for (final t in tasksNotifier.value) {
      if (t.mediaId != mediaId) continue;
      if (t.season != season || t.episode != episode) continue;
      if (t.isActive || t.isCompleted) return t;
    }
    return null;
  }

  /// Starts an HTTP or HLS download. [url] and [headers] are required.
  Future<DownloadTask> startDownload({
    required String title,
    required String mediaId,
    required String type, // 'movie', 'series', 'anime'
    int? season,
    int? episode,
    String? episodeTitle,
    String? posterUrl,
    String? backdropUrl,
    String? year,
    required String url,
    required Map<String, String> headers,
    String? sourceName,
    String? addonName,
    String? customDownloadDir,
  }) async {
    await initialize();

    final rawUrl = url.trim();
    if (rawUrl.isEmpty) {
      throw ArgumentError('Empty download URL');
    }
    if (!isDownloadableHttpUrl(rawUrl, headers: headers)) {
      final reason = offlineDownloadRejectReason(rawUrl, headers: headers) ??
          'URL is not a downloadable HTTP(S) stream';
      throw ArgumentError(reason);
    }

    final existing = findActiveOrCompleted(
      mediaId: mediaId,
      season: season,
      episode: episode,
    );
    if (existing != null) {
      if (existing.isCompleted ||
          existing.isDownloading ||
          existing.status == DownloadStatus.queued) {
        return existing;
      }
      if (existing.isPaused || existing.isFailed) {
        await resumeDownload(existing.id);
        return findActiveOrCompleted(
              mediaId: mediaId,
              season: season,
              episode: episode,
            ) ??
            existing;
      }
    }

    final downloadDir =
        customDownloadDir ?? await DownloadPathHelper.getDownloadsDirectoryPath();
    final now = DateTime.now();
    final taskId =
        'dl_${mediaId}_${season ?? 0}_${episode ?? 0}_${now.millisecondsSinceEpoch}';

    final safeTitle = DownloadPathHelper.sanitizeFilename(title);
    final epSuffix = (season != null && episode != null)
        ? '_S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
        : '';
    final baseFilename = '$safeTitle$epSuffix';

    var targetExt = '.mp4';
    if (rawUrl.toLowerCase().contains('.mkv')) {
      targetExt = '.mkv';
    }

    final targetPath = p.join(downloadDir, '$baseFilename$targetExt');

    final task = DownloadTask(
      id: taskId,
      title: (season != null && episode != null)
          ? '$title - S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
          : title,
      mediaId: mediaId,
      type: type,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      sourceType: DownloadSourceType.http,
      sourceName: sourceName ?? 'Stream',
      addonName: addonName,
      rawUrl: rawUrl,
      headers: Map<String, String>.from(headers),
      targetFilePath: targetPath,
      status: DownloadStatus.queued,
      createdAt: now,
    );

    final current = List<DownloadTask>.from(tasksNotifier.value);
    // Drop stale failed/canceled rows for the same media slot.
    current.removeWhere(
      (t) =>
          t.mediaId == mediaId &&
          t.season == season &&
          t.episode == episode &&
          (t.isFailed || t.status == DownloadStatus.canceled),
    );
    current.insert(0, task);
    tasksNotifier.value = current;
    await _persistTasks();

    _executeDownload(task);
    return task;
  }

  Future<void> _executeDownload(DownloadTask task) async {
    _canceledOrPausedTaskIds.remove(task.id);
    _updateTask(task.copyWith(status: DownloadStatus.downloading, error: null));

    if (HlsDownloadEngine.isHlsUrl(task.rawUrl)) {
      await _executeHlsDownload(task);
    } else {
      await _executeHttpDownload(task);
    }
  }

  Future<void> _executeHlsDownload(DownloadTask task) async {
    try {
      await HlsDownloadEngine.downloadHlsStream(
        task: task,
        onProgress: (updated) => _updateTask(updated),
        isPausedOrCanceled: () => _canceledOrPausedTaskIds.contains(task.id),
      );
    } catch (e) {
      if (!_canceledOrPausedTaskIds.contains(task.id)) {
        _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        ));
      }
    }
  }

  Future<void> _executeHttpDownload(
    DownloadTask task, {
    int attempt = 1,
  }) async {
    final urlStr = task.rawUrl;
    if (urlStr == null || urlStr.isEmpty) {
      _updateTask(
        task.copyWith(status: DownloadStatus.failed, error: 'Empty download URL'),
      );
      return;
    }

    final partFilePath = '${task.targetFilePath}.part';
    final partFile = File(partFilePath);
    if (!await partFile.parent.exists()) {
      await partFile.parent.create(recursive: true);
    }

    var existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }

    if (task.totalBytes > 0 && existingBytes >= task.totalBytes) {
      await _finalizeDownloadedFile(task, partFile);
      return;
    }

    try {
      final uri = Uri.parse(urlStr);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 25);

      final request = await client.getUrl(uri);
      _httpRequests[task.id] = request;

      if (task.headers != null) {
        task.headers!.forEach((k, v) => request.headers.set(k, v));
      }
      if (task.headers == null || !task.headers!.containsKey('User-Agent')) {
        request.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        );
      }

      if (existingBytes > 0) {
        request.headers.set('Range', 'bytes=$existingBytes-');
      }

      final response = await request.close();
      final isPartial = response.statusCode == HttpStatus.partialContent;
      final isOk = response.statusCode == HttpStatus.ok;

      if (!isPartial && !isOk) {
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
            existingBytes > 0) {
          await _finalizeDownloadedFile(task, partFile);
          return;
        }
        final code = response.statusCode;
        final phrase = response.reasonPhrase;
        // Auth / gone — retrying the same URL never helps (expired Referer, …).
        if (code == HttpStatus.unauthorized ||
            code == HttpStatus.forbidden ||
            code == HttpStatus.notFound ||
            code == HttpStatus.gone) {
          _cleanupHttpTask(task.id);
          _updateTask(task.copyWith(
            status: DownloadStatus.failed,
            error: code == HttpStatus.forbidden ||
                    code == HttpStatus.unauthorized
                ? kOfflineDownloadExpiredMessage
                : 'Server returned HTTP $code: $phrase',
            speedBytesPerSec: 0.0,
          ));
          return;
        }
        throw Exception(
          'Server returned HTTP $code: $phrase',
        );
      }

      final contentType =
          (response.headers.contentType?.mimeType ?? '').toLowerCase();
      if (contentType.contains('dash+xml') ||
          contentType.contains('application/dash')) {
        response.listen((_) {}).cancel();
        _cleanupHttpTask(task.id);
        _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          error: "DASH streams can't be saved offline yet",
          speedBytesPerSec: 0.0,
        ));
        return;
      }
      if (contentType.contains('mpegurl') ||
          contentType.contains('x-mpegurl') ||
          contentType.contains('apple.mpegurl')) {
        response.listen((_) {}).cancel();
        _cleanupHttpTask(task.id);
        await _executeHlsDownload(task);
        return;
      }

      final totalContentLength = response.contentLength;
      var totalBytes = task.totalBytes;

      if (isPartial) {
        totalBytes =
            existingBytes + (totalContentLength > 0 ? totalContentLength : 0);
      } else if (isOk) {
        existingBytes = 0;
        totalBytes = totalContentLength > 0 ? totalContentLength : 0;
      }

      final enoughSpace = await StorageSpaceHelper.hasEnoughSpace(
        partFile.parent.path,
        totalBytes > 0 ? (totalBytes - existingBytes) : 1024 * 1024 * 500,
      );
      if (!enoughSpace) {
        throw Exception('Insufficient free disk space on target partition');
      }

      final mode =
          (existingBytes > 0 && isPartial) ? FileMode.append : FileMode.write;
      final sink = partFile.openWrite(mode: mode);
      _httpFileSinks[task.id] = sink;

      var receivedSoFar = existingBytes;
      var bytesInLastSecond = 0;
      var lastSpeedCalc = DateTime.now();
      var sniffedHead = existingBytes > 0;
      var abortAfterSniff = false;
      final headBuffer = <int>[];

      late final StreamSubscription<List<int>> subscription;
      subscription = response.listen(
        (chunk) {
          if (abortAfterSniff) return;
          if (!sniffedHead) {
            headBuffer.addAll(chunk);
            if (headBuffer.length >= 64 ||
                (totalContentLength > 0 &&
                    headBuffer.length >= totalContentLength)) {
              sniffedHead = true;
              if (looksLikeManifestBytes(headBuffer)) {
                abortAfterSniff = true;
                final head = String.fromCharCodes(
                  headBuffer.sublist(
                    0,
                    headBuffer.length < 16 ? headBuffer.length : 16,
                  ),
                ).trimLeft();
                unawaited(() async {
                  try {
                    await subscription.cancel();
                  } catch (_) {}
                  try {
                    await sink.flush();
                    await sink.close();
                  } catch (_) {}
                  _cleanupHttpTask(task.id);
                  try {
                    if (await partFile.exists()) await partFile.delete();
                  } catch (_) {}
                  if (_canceledOrPausedTaskIds.contains(task.id)) return;
                  if (head.startsWith('#EXTM3U') ||
                      head.toLowerCase().startsWith('#extm3u')) {
                    await _executeHlsDownload(task);
                    return;
                  }
                  _updateTask(task.copyWith(
                    status: DownloadStatus.failed,
                    error: head.toLowerCase().contains('mpd')
                        ? "DASH streams can't be saved offline yet"
                        : 'Server returned a playlist/page, not a video file',
                    speedBytesPerSec: 0.0,
                  ));
                }());
                return;
              }
              // Flush buffered head into the file once.
              sink.add(headBuffer);
              receivedSoFar += headBuffer.length;
              bytesInLastSecond += headBuffer.length;
              headBuffer.clear();
              return;
            }
            return;
          }

          sink.add(chunk);
          receivedSoFar += chunk.length;
          bytesInLastSecond += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedCalc).inMilliseconds;

          if (elapsed >= 1000) {
            final speed = bytesInLastSecond / (elapsed / 1000.0);
            bytesInLastSecond = 0;
            lastSpeedCalc = now;

            int? eta;
            if (speed > 0 && totalBytes > receivedSoFar) {
              eta = ((totalBytes - receivedSoFar) / speed).ceil();
            }

            _updateTask(task.copyWith(
              status: DownloadStatus.downloading,
              receivedBytes: receivedSoFar,
              totalBytes: totalBytes > 0 ? totalBytes : receivedSoFar,
              speedBytesPerSec: speed,
              etaSeconds: eta,
              error: null,
            ));
          }
        },
        onDone: () async {
          if (abortAfterSniff) return;
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          _httpFileSinks.remove(task.id);
          _httpSubscriptions.remove(task.id);
          _httpRequests.remove(task.id);

          if (_canceledOrPausedTaskIds.contains(task.id)) return;

          // Tiny response that never filled the sniff buffer.
          if (!sniffedHead && headBuffer.isNotEmpty) {
            if (looksLikeManifestBytes(headBuffer)) {
              try {
                if (await partFile.exists()) await partFile.delete();
              } catch (_) {}
              final head = String.fromCharCodes(headBuffer).trimLeft();
              if (head.startsWith('#EXTM3U') ||
                  head.toLowerCase().startsWith('#extm3u')) {
                await _executeHlsDownload(task);
                return;
              }
              _updateTask(task.copyWith(
                status: DownloadStatus.failed,
                error: head.toLowerCase().contains('mpd')
                    ? "DASH streams can't be saved offline yet"
                    : 'Server returned a playlist/page, not a video file',
                speedBytesPerSec: 0.0,
              ));
              return;
            }
            try {
              await partFile.writeAsBytes(headBuffer);
              receivedSoFar = headBuffer.length;
            } catch (_) {}
          }

          if (totalBytes > 0 &&
              receivedSoFar < (totalBytes - 2048) &&
              attempt < 5) {
            debugPrint(
              '[DownloadService] Stream closed prematurely '
              '($receivedSoFar / $totalBytes bytes). Auto-reconnecting '
              'attempt ${attempt + 1}...',
            );
            _updateTask(task.copyWith(
              status: DownloadStatus.downloading,
              error: 'Reconnecting remaining data (attempt $attempt)...',
              speedBytesPerSec: 0.0,
            ));
            await Future.delayed(Duration(seconds: attempt));
            if (!_canceledOrPausedTaskIds.contains(task.id)) {
              await _executeHttpDownload(
                task.copyWith(
                  receivedBytes: receivedSoFar,
                  totalBytes: totalBytes,
                ),
                attempt: attempt + 1,
              );
            }
            return;
          }

          await _finalizeDownloadedFile(
            task.copyWith(
              receivedBytes: receivedSoFar,
              totalBytes: totalBytes > 0 ? totalBytes : receivedSoFar,
            ),
            partFile,
          );
        },
        onError: (err) async {
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          _httpFileSinks.remove(task.id);
          _httpSubscriptions.remove(task.id);
          _httpRequests.remove(task.id);

          if (_canceledOrPausedTaskIds.contains(task.id)) return;

          if (attempt < 5) {
            debugPrint(
              '[DownloadService] Download network error: $err. '
              'Auto-reconnecting attempt ${attempt + 1}...',
            );
            _updateTask(task.copyWith(
              status: DownloadStatus.downloading,
              error: 'Reconnecting (attempt $attempt)...',
              speedBytesPerSec: 0.0,
            ));
            await Future.delayed(Duration(seconds: attempt * 2));
            if (!_canceledOrPausedTaskIds.contains(task.id)) {
              await _executeHttpDownload(
                task.copyWith(
                  receivedBytes: receivedSoFar,
                  totalBytes: totalBytes,
                ),
                attempt: attempt + 1,
              );
            }
            return;
          }

          _updateTask(task.copyWith(
            status: DownloadStatus.failed,
            error: err.toString(),
            speedBytesPerSec: 0.0,
          ));
        },
        cancelOnError: true,
      );

      _httpSubscriptions[task.id] = subscription;
    } catch (e) {
      _cleanupHttpTask(task.id);
      if (!_canceledOrPausedTaskIds.contains(task.id)) {
        if (attempt < 5) {
          debugPrint(
            '[DownloadService] Exception in HTTP download: $e. '
            'Auto-reconnecting attempt ${attempt + 1}...',
          );
          _updateTask(task.copyWith(
            status: DownloadStatus.downloading,
            error: 'Reconnecting (attempt $attempt)...',
            speedBytesPerSec: 0.0,
          ));
          await Future.delayed(Duration(seconds: attempt * 2));
          if (!_canceledOrPausedTaskIds.contains(task.id)) {
            await _executeHttpDownload(task, attempt: attempt + 1);
            return;
          }
        }
        _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
          speedBytesPerSec: 0.0,
        ));
      }
    }
  }

  Future<void> _finalizeDownloadedFile(DownloadTask task, File partFile) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));

      if (!await partFile.exists()) {
        _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          error: 'Download file missing',
        ));
        return;
      }

      final peekLen = (await partFile.length()).clamp(0, 512);
      if (peekLen > 0) {
        final raf = await partFile.open();
        try {
          final head = await raf.read(peekLen);
          if (looksLikeManifestBytes(head)) {
            try {
              await partFile.delete();
            } catch (_) {}
            final text = String.fromCharCodes(head).trimLeft().toLowerCase();
            _updateTask(task.copyWith(
              status: DownloadStatus.failed,
              error: text.contains('mpd')
                  ? "DASH streams can't be saved offline yet"
                  : 'Server returned a playlist/page, not a video file',
              speedBytesPerSec: 0.0,
            ));
            return;
          }
        } finally {
          await raf.close();
        }
      }

      // Guard against tiny junk that slipped past sniff (real episodes are MBs).
      final partBytes = await partFile.length();
      if (partBytes > 0 && partBytes < 256 * 1024) {
        try {
          await partFile.delete();
        } catch (_) {}
        _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          error: 'Download too small to be a video file',
          speedBytesPerSec: 0.0,
        ));
        return;
      }

      final finalFile = File(task.targetFilePath);
      if (await finalFile.exists()) {
        try {
          await finalFile.delete();
        } catch (_) {}
      }

      try {
        await partFile.rename(task.targetFilePath);
      } catch (e) {
        debugPrint(
          '[DownloadService] Rename failed, using fallback copy: $e',
        );
        await partFile.copy(task.targetFilePath);
        try {
          await partFile.delete();
        } catch (_) {}
      }

      final completedBytes = await File(task.targetFilePath).length();

      _updateTask(task.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: completedBytes,
        totalBytes: completedBytes,
        speedBytesPerSec: 0.0,
        etaSeconds: 0,
        completedAt: DateTime.now(),
        error: null,
      ));
    } catch (e) {
      debugPrint('[DownloadService] Error finalizing downloaded file: $e');
      _updateTask(task.copyWith(
        status: DownloadStatus.failed,
        error: 'Failed to save final file: $e',
      ));
    }
  }

  void _cleanupHttpTask(String taskId) {
    _httpSubscriptions[taskId]?.cancel();
    _httpSubscriptions.remove(taskId);
    _httpRequests[taskId]?.abort();
    _httpRequests.remove(taskId);
    try {
      _httpFileSinks[taskId]?.close();
    } catch (_) {}
    _httpFileSinks.remove(taskId);
  }

  DownloadTask? _taskById(String taskId) {
    for (final t in tasksNotifier.value) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  Future<void> pauseDownload(String taskId) async {
    _canceledOrPausedTaskIds.add(taskId);
    final task = _taskById(taskId);
    if (task == null) return;

    _cleanupHttpTask(taskId);

    _updateTask(task.copyWith(
      status: DownloadStatus.paused,
      speedBytesPerSec: 0.0,
      etaSeconds: null,
    ));
  }

  Future<void> resumeDownload(String taskId) async {
    _canceledOrPausedTaskIds.remove(taskId);
    final task = _taskById(taskId);
    if (task == null) return;

    _updateTask(task.copyWith(
      status: DownloadStatus.queued,
      error: null,
    ));
    _executeDownload(task);
  }

  Future<void> cancelDownload(String taskId) async {
    final task = _taskById(taskId);
    if (task == null) return;

    await pauseDownload(taskId);

    final partFile = File('${task.targetFilePath}.part');
    if (await partFile.exists()) {
      try {
        await partFile.delete();
      } catch (_) {}
    }
    final metaFile = File('${task.targetFilePath}.hls_meta.json');
    if (await metaFile.exists()) {
      try {
        await metaFile.delete();
      } catch (_) {}
    }

    _updateTask(task.copyWith(status: DownloadStatus.canceled));
  }

  Future<void> deleteDownload(String taskId) async {
    final task = _taskById(taskId);
    if (task == null) return;

    await cancelDownload(taskId);

    final targetFile = File(task.targetFilePath);
    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    final current = List<DownloadTask>.from(tasksNotifier.value)
      ..removeWhere((t) => t.id == taskId);
    tasksNotifier.value = current;
    await _persistTasks();
    _updateWakelockState();
  }

  /// Removes every completed task and its on-disk file.
  Future<void> deleteAllCompleted() async {
    final ids = [
      for (final t in tasksNotifier.value)
        if (t.isCompleted) t.id,
    ];
    for (final id in ids) {
      await deleteDownload(id);
    }
  }
}
