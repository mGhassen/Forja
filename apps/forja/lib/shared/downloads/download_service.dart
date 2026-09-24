import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:forja/shared/downloads/download_speed_sampler.dart';
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
  Completer<void>? _initCompleter;

  /// Progress ticks only schedule a write; status changes flush immediately.
  static const Duration _progressPersistInterval = Duration(seconds: 5);
  Timer? _progressPersistTimer;

  final Map<String, HttpClientRequest> _httpRequests = {};
  final Map<String, StreamSubscription<List<int>>> _httpSubscriptions = {};
  final Map<String, IOSink> _httpFileSinks = {};
  final Set<String> _canceledOrPausedTaskIds = {};
  /// Prevents overlapping HTTP writers for the same task (resume vs reconnect).
  final Set<String> _httpExecutors = {};

  /// Loads persisted tasks once. Concurrent callers await the same load so a
  /// late finish cannot wipe an enqueue that already wrote to [tasksNotifier].
  Future<void> initialize() async {
    if (_isInitialized) return;
    final inFlight = _initCompleter;
    if (inFlight != null) {
      await inFlight.future;
      return;
    }
    final completer = Completer<void>();
    _initCompleter = completer;
    try {
      await _loadPersistedTasks();
      _isInitialized = true;
      completer.complete();
    } catch (e, st) {
      _initCompleter = null;
      completer.completeError(e, st);
      rethrow;
    }
  }

  /// Settings → Downloads: if memory is empty after a race, surface disk rows.
  ///
  /// In-progress transfers on disk become **paused** (no executor attached).
  Future<void> ensureQueueVisible() async {
    await initialize();
    if (tasksNotifier.value.isNotEmpty) return;
    await _loadPersistedTasks();
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

  void _persistTasksNow() {
    _progressPersistTimer?.cancel();
    _progressPersistTimer = null;
    unawaited(_persistTasks());
  }

  void _scheduleProgressPersist() {
    if (_progressPersistTimer?.isActive ?? false) return;
    _progressPersistTimer = Timer(_progressPersistInterval, () {
      _progressPersistTimer = null;
      unawaited(_persistTasks());
    });
  }

  void _updateTask(DownloadTask updated) {
    final current = List<DownloadTask>.from(tasksNotifier.value);
    final idx = current.indexWhere((t) => t.id == updated.id);
    final prev = idx != -1 ? current[idx] : null;
    final statusChanged = prev == null || prev.status != updated.status;
    // Byte progress while downloading — keep UI live, throttle disk JSON.
    final progressOnly =
        !statusChanged && updated.status == DownloadStatus.downloading;

    if (idx != -1) {
      current[idx] = updated;
      tasksNotifier.value = current;
      if (progressOnly) {
        _scheduleProgressPersist();
      } else {
        _persistTasksNow();
      }
    } else if (updated.isActive || updated.isFailed) {
      // Recover when a concurrent init load wiped the in-memory row while the
      // HTTP/HLS transfer was still running.
      current.insert(0, updated);
      tasksNotifier.value = current;
      _persistTasksNow();
      debugPrint(
        '[DownloadService] Re-attached orphaned task ${updated.id} '
        '(${updated.status.name})',
      );
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

  /// Match a Sources-panel stream row to a download task (URL first, then name).
  DownloadTask? findTaskForStream({
    required String mediaId,
    int? season,
    int? episode,
    String? streamUrl,
    String? sourceName,
  }) {
    final url = streamUrl?.trim() ?? '';
    final name = sourceName?.trim() ?? '';
    DownloadTask? byName;
    for (final t in tasksNotifier.value) {
      if (t.mediaId != mediaId) continue;
      if (t.season != season || t.episode != episode) continue;
      if (!(t.isActive || t.isCompleted)) continue;
      final taskUrl = t.rawUrl?.trim() ?? '';
      if (url.isNotEmpty && taskUrl.isNotEmpty && taskUrl == url) {
        return t;
      }
      if (name.isNotEmpty &&
          t.sourceName.trim().isNotEmpty &&
          t.sourceName.trim().toLowerCase() == name.toLowerCase()) {
        byName ??= t;
      }
    }
    return byName;
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
    final urlLower = rawUrl.toLowerCase();
    if (urlLower.contains('.mkv')) {
      targetExt = '.mkv';
    } else if (urlLower.contains('.webm')) {
      targetExt = '.webm';
    } else if (urlLower.contains('.avi')) {
      targetExt = '.avi';
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

    if (attempt == 1 && !_httpExecutors.add(task.id)) {
      debugPrint(
        '[DownloadService] Skipping overlapping HTTP executor for ${task.id}',
      );
      return;
    }
    var releaseExecutor = attempt == 1;

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
      if (releaseExecutor) _httpExecutors.remove(task.id);
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
          if (releaseExecutor) _httpExecutors.remove(task.id);
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
          if (releaseExecutor) _httpExecutors.remove(task.id);
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
        if (releaseExecutor) _httpExecutors.remove(task.id);
        return;
      }
      if (contentType.contains('mpegurl') ||
          contentType.contains('x-mpegurl') ||
          contentType.contains('apple.mpegurl')) {
        response.listen((_) {}).cancel();
        _cleanupHttpTask(task.id);
        if (releaseExecutor) {
          _httpExecutors.remove(task.id);
          releaseExecutor = false;
        }
        await _executeHlsDownload(task);
        return;
      }

      // Prefer real container extension from the server (pixeldrain → .mkv).
      final dispExt = extensionFromContentDisposition(
        response.headers.value('content-disposition'),
      );
      final typeExt = extensionFromContentType(contentType);
      final preferredExt = dispExt ?? typeExt;
      var activeTask = task;
      var activePart = partFile;
      if (preferredExt != null &&
          !task.targetFilePath.toLowerCase().endsWith(preferredExt)) {
        final renamed = await _retargetDownloadExtension(task, preferredExt);
        if (renamed != null) {
          activeTask = renamed;
          activePart = File('${renamed.targetFilePath}.part');
          if (activePart.path != partFile.path && await partFile.exists()) {
            if (!await activePart.exists()) {
              await partFile.rename(activePart.path);
            }
          }
        }
      }

      final totalContentLength = response.contentLength;
      var totalBytes = activeTask.totalBytes;
      final rangeHeader = response.headers.value('content-range');
      final rangeStart = parseContentRangeStart(rangeHeader);
      final rangeTotal = parseContentRangeTotal(rangeHeader);

      // Disk may have shrunk under us (overlapping writer / lost flush). Always
      // re-stat before appending so Range offset matches EOF.
      final diskNow =
          await activePart.exists() ? await activePart.length() : 0;

      if (isPartial) {
        final expectedStart = rangeStart ?? existingBytes;
        if (diskNow != expectedStart) {
          debugPrint(
            '[DownloadService] Resume mismatch: disk=$diskNow '
            'rangeStart=$expectedStart existing=$existingBytes — realigning',
          );
          response.listen((_) {}).cancel();
          _cleanupHttpTask(activeTask.id);
          if (expectedStart >= 0 && diskNow > expectedStart) {
            // Keep the valid prefix; never FileMode.write (that zeros the file).
            final raf = await activePart.open(mode: FileMode.append);
            try {
              await raf.truncate(expectedStart);
            } finally {
              await raf.close();
            }
          } else if (expectedStart > diskNow) {
            // Gap we cannot fill from this response — restart clean.
            try {
              if (await activePart.exists()) await activePart.delete();
            } catch (_) {}
          }
          if (releaseExecutor) {
            _httpExecutors.remove(activeTask.id);
            releaseExecutor = false;
          }
          await _executeHttpDownload(
            activeTask.copyWith(totalBytes: rangeTotal ?? totalBytes),
            attempt: attempt + 1,
          );
          return;
        }
        existingBytes = diskNow;
        if (rangeTotal != null && rangeTotal > 0) {
          totalBytes = rangeTotal;
        } else {
          totalBytes =
              existingBytes + (totalContentLength > 0 ? totalContentLength : 0);
        }
      } else if (isOk) {
        // 200 after a Range request: full body replace (not a silent remainder).
        existingBytes = 0;
        totalBytes = totalContentLength > 0
            ? totalContentLength
            : (rangeTotal ?? 0);
      }

      final enoughSpace = await StorageSpaceHelper.hasEnoughSpace(
        activePart.parent.path,
        totalBytes > 0 ? (totalBytes - existingBytes) : 1024 * 1024 * 500,
      );
      if (!enoughSpace) {
        throw Exception('Insufficient free disk space on target partition');
      }

      final mode =
          (existingBytes > 0 && isPartial) ? FileMode.append : FileMode.write;
      final sink = activePart.openWrite(mode: mode);
      _httpFileSinks[activeTask.id] = sink;
      task = activeTask;
      final outFile = activePart;

      var receivedSoFar = existingBytes;
      final speedSampler = DownloadSpeedSampler();
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
                    if (await outFile.exists()) await outFile.delete();
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
              speedSampler.addBytes(headBuffer.length);
              headBuffer.clear();
              return;
            }
            return;
          }

          sink.add(chunk);
          receivedSoFar += chunk.length;
          final windowClosed = speedSampler.addBytes(chunk.length);
          if (!windowClosed) return;

          final speed = speedSampler.speedBytesPerSec;
          final remaining =
              totalBytes > receivedSoFar ? totalBytes - receivedSoFar : 0;
          final eta = speedSampler.etaSecondsFor(remaining);

          _updateTask(task.copyWith(
            status: DownloadStatus.downloading,
            receivedBytes: receivedSoFar,
            totalBytes: totalBytes > 0 ? totalBytes : receivedSoFar,
            speedBytesPerSec: speed,
            etaSeconds: eta,
            error: null,
          ));
        },
        onDone: () async {
          if (abortAfterSniff) {
            if (releaseExecutor) _httpExecutors.remove(task.id);
            return;
          }
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          _httpFileSinks.remove(task.id);
          _httpSubscriptions.remove(task.id);
          _httpRequests.remove(task.id);

          if (_canceledOrPausedTaskIds.contains(task.id)) {
            if (releaseExecutor) _httpExecutors.remove(task.id);
            return;
          }

          // Tiny response that never filled the sniff buffer.
          if (!sniffedHead && headBuffer.isNotEmpty) {
            if (looksLikeManifestBytes(headBuffer)) {
              try {
                if (await outFile.exists()) await outFile.delete();
              } catch (_) {}
              final head = String.fromCharCodes(headBuffer).trimLeft();
              if (head.startsWith('#EXTM3U') ||
                  head.toLowerCase().startsWith('#extm3u')) {
                if (releaseExecutor) {
                  _httpExecutors.remove(task.id);
                  releaseExecutor = false;
                }
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
              if (releaseExecutor) _httpExecutors.remove(task.id);
              return;
            }
            try {
              await outFile.writeAsBytes(headBuffer);
              receivedSoFar = headBuffer.length;
            } catch (_) {}
          }

          // Prefer on-disk length over in-memory counters (lost flush / race).
          final diskBytes =
              await outFile.exists() ? await outFile.length() : receivedSoFar;

          if (totalBytes > 0 &&
              diskBytes < (totalBytes - 256) &&
              attempt < 5) {
            debugPrint(
              '[DownloadService] Stream closed prematurely '
              '($diskBytes / $totalBytes bytes). Auto-reconnecting '
              'attempt ${attempt + 1}...',
            );
            _updateTask(task.copyWith(
              status: DownloadStatus.downloading,
              receivedBytes: diskBytes,
              totalBytes: totalBytes,
              error: 'Reconnecting remaining data (attempt $attempt)...',
              speedBytesPerSec: 0.0,
            ));
            await Future.delayed(Duration(seconds: attempt));
            if (!_canceledOrPausedTaskIds.contains(task.id)) {
              await _executeHttpDownload(
                task.copyWith(
                  receivedBytes: diskBytes,
                  totalBytes: totalBytes,
                ),
                attempt: attempt + 1,
              );
            } else if (releaseExecutor) {
              _httpExecutors.remove(task.id);
            }
            return;
          }

          await _finalizeDownloadedFile(
            task.copyWith(
              receivedBytes: diskBytes,
              totalBytes: totalBytes > 0 ? totalBytes : diskBytes,
            ),
            outFile,
          );
          if (releaseExecutor) _httpExecutors.remove(task.id);
        },
        onError: (err) async {
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          _httpFileSinks.remove(task.id);
          _httpSubscriptions.remove(task.id);
          _httpRequests.remove(task.id);

          if (_canceledOrPausedTaskIds.contains(task.id)) {
            if (releaseExecutor) _httpExecutors.remove(task.id);
            return;
          }

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
            } else if (releaseExecutor) {
              _httpExecutors.remove(task.id);
            }
            return;
          }

          _updateTask(task.copyWith(
            status: DownloadStatus.failed,
            error: err.toString(),
            speedBytesPerSec: 0.0,
          ));
          if (releaseExecutor) _httpExecutors.remove(task.id);
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
            if (releaseExecutor) {
              _httpExecutors.remove(task.id);
              releaseExecutor = false;
            }
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
      if (releaseExecutor) _httpExecutors.remove(task.id);
    }
  }

  /// Point [task] at the same basename with [ext] (e.g. `.mkv` from Disposition).
  Future<DownloadTask?> _retargetDownloadExtension(
    DownloadTask task,
    String ext,
  ) async {
    final dir = p.dirname(task.targetFilePath);
    final base = p.basenameWithoutExtension(task.targetFilePath);
    final nextPath = p.join(dir, '$base$ext');
    if (nextPath == task.targetFilePath) return task;
    final updated = task.copyWith(targetFilePath: nextPath);
    _updateTask(updated);
    return updated;
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

      final partBytes = await partFile.length();
      if (task.totalBytes > 0 && partBytes < task.totalBytes - 256) {
        _updateTask(task.copyWith(
          status: DownloadStatus.failed,
          error: 'Download incomplete — delete and try again',
          receivedBytes: partBytes,
          speedBytesPerSec: 0.0,
        ));
        return;
      }

      final peekLen = partBytes.clamp(0, 512);
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
          if (!looksLikeMediaContainerBytes(head)) {
            try {
              await partFile.delete();
            } catch (_) {}
            _updateTask(task.copyWith(
              status: DownloadStatus.failed,
              error: 'Downloaded file is not a playable video',
              speedBytesPerSec: 0.0,
            ));
            return;
          }
        } finally {
          await raf.close();
        }
      }

      // Guard against tiny junk that slipped past sniff (real episodes are MBs).
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
