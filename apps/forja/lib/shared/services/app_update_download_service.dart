import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_update_download_storage.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

enum AppUpdateDownloadPhase { idle, downloading, completed, failed }

class AppUpdateDownloadState {
  const AppUpdateDownloadState({
    required this.phase,
    this.updateInfo,
    this.progress = 0,
    this.filePath,
    this.error,
    this.isBackground = false,
  });

  const AppUpdateDownloadState.idle()
    : this(phase: AppUpdateDownloadPhase.idle);

  final AppUpdateDownloadPhase phase;
  final UpdateInfo? updateInfo;
  final double progress;
  final String? filePath;
  final Object? error;
  final bool isBackground;

  AppUpdateDownloadState copyWith({
    AppUpdateDownloadPhase? phase,
    double? progress,
    String? filePath,
    Object? error,
    bool? isBackground,
  }) {
    return AppUpdateDownloadState(
      phase: phase ?? this.phase,
      updateInfo: updateInfo,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      isBackground: isBackground ?? this.isBackground,
    );
  }
}

/// Process-wide desktop update download that survives closing the update UI.
class AppUpdateDownloadService {
  AppUpdateDownloadService._();

  static final AppUpdateDownloadService instance = AppUpdateDownloadService._();

  final ValueNotifier<AppUpdateDownloadState> state = ValueNotifier(
    const AppUpdateDownloadState.idle(),
  );

  /// When true, the sticky background progress banner stays hidden until the
  /// next [continueInBackground] (or a new background download).
  final ValueNotifier<bool> progressBannerDismissed = ValueNotifier(false);

  bool get isDownloading =>
      state.value.phase == AppUpdateDownloadPhase.downloading;

  bool get shouldShowProgressBanner {
    final current = state.value;
    return current.isBackground &&
        current.phase == AppUpdateDownloadPhase.downloading &&
        !progressBannerDismissed.value;
  }

  bool isDownloadingVersion(String version) =>
      isDownloading && state.value.updateInfo?.latestVersion == version;

  void continueInBackground() {
    if (!isDownloading) return;
    progressBannerDismissed.value = false;
    state.value = state.value.copyWith(isBackground: true);
  }

  void dismissProgressBanner() {
    progressBannerDismissed.value = true;
  }

  /// Drop in-memory completion after Settings clears installers from disk.
  void resetAfterCacheClear() {
    if (isDownloading) return;
    progressBannerDismissed.value = false;
    state.value = const AppUpdateDownloadState.idle();
  }

  /// True only when a completed installer for [updateInfo] still exists on disk.
  Future<bool> hasUsableCachedInstaller(UpdateInfo updateInfo) async {
    final current = state.value;
    if (current.phase == AppUpdateDownloadPhase.completed &&
        current.updateInfo?.latestVersion == updateInfo.latestVersion &&
        current.filePath != null) {
      try {
        final file = File(current.filePath!);
        if (await file.exists() && await file.length() > 0) {
          return true;
        }
      } catch (_) {}
    }

    final cached = await AppUpdateDownloadStorage.findDownloadedFile(
      version: updateInfo.latestVersion,
      downloadUrl: updateInfo.downloadUrl,
    );
    if (cached == null) {
      if (current.phase == AppUpdateDownloadPhase.completed &&
          current.updateInfo?.latestVersion == updateInfo.latestVersion) {
        state.value = const AppUpdateDownloadState.idle();
      }
      return false;
    }

    state.value = AppUpdateDownloadState(
      phase: AppUpdateDownloadPhase.completed,
      updateInfo: updateInfo,
      progress: 1,
      filePath: cached.path,
    );
    return true;
  }

  Future<bool> restoreCached(UpdateInfo updateInfo) async {
    if (isDownloading) return false;
    return hasUsableCachedInstaller(updateInfo);
  }

  Future<void> start(UpdateInfo updateInfo) async {
    if (isDownloadingVersion(updateInfo.latestVersion)) return;
    if (isDownloading) {
      throw StateError('Another update is already downloading');
    }

    if (await hasUsableCachedInstaller(updateInfo)) return;

    String? filePath;
    try {
      final dir =
          await AppUpdateDownloadStorage.resolveWritableDownloadDirectory();
      final fileName = AppUpdateDownloadStorage.fileNameFor(
        version: updateInfo.latestVersion,
        downloadUrl: updateInfo.downloadUrl,
      );
      filePath = path.join(dir.path, fileName);
      final file = File(filePath);

      state.value = AppUpdateDownloadState(
        phase: AppUpdateDownloadPhase.downloading,
        updateInfo: updateInfo,
      );

      final response = await http.Request(
        'GET',
        Uri.parse(updateInfo.downloadUrl),
      ).send();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      var lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (contentLength > 0 &&
              (now - lastUpdateTime > 100 ||
                  downloadedBytes == contentLength)) {
            lastUpdateTime = now;
            state.value = state.value.copyWith(
              progress: downloadedBytes / contentLength,
            );
          }
        }
      } finally {
        await sink.close();
      }

      final completedInBackground = state.value.isBackground;
      state.value = AppUpdateDownloadState(
        phase: AppUpdateDownloadPhase.completed,
        updateInfo: updateInfo,
        progress: 1,
        filePath: filePath,
        isBackground: completedInBackground,
      );
      if (completedInBackground) {
        ForjaToast.success(
          'Forja ${updateInfo.latestVersion} is ready to install.',
          duration: const Duration(seconds: 15),
          actionLabel: 'Install',
          onAction: installCompletedUpdate,
        );
      }
    } catch (error) {
      if (filePath != null) {
        try {
          final partial = File(filePath);
          if (await partial.exists()) await partial.delete();
        } catch (_) {}
      }
      state.value = AppUpdateDownloadState(
        phase: AppUpdateDownloadPhase.failed,
        updateInfo: updateInfo,
        error: error,
      );
      final canOpenDirectUrl = Platform.isWindows || Platform.isMacOS;
      ForjaToast.error(
        'Download failed: $error',
        duration: canOpenDirectUrl
            ? const Duration(seconds: 12)
            : const Duration(seconds: 4),
        actionLabel: canOpenDirectUrl ? 'Open download URL' : null,
        onAction: canOpenDirectUrl
            ? () => AppUpdaterService().openDownloadPage(updateInfo.downloadUrl)
            : null,
      );
    }
  }

  Future<void> installCompletedUpdate() async {
    final filePath = state.value.filePath;
    if (filePath == null || !await File(filePath).exists()) {
      ForjaToast.error('The downloaded update file is no longer available.');
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.start('open', [
          filePath,
        ], mode: ProcessStartMode.detached);
        exit(0);
      } else if (Platform.isWindows) {
        await Process.start(
          filePath,
          const [],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [
          filePath,
        ], mode: ProcessStartMode.detached);
      }
    } catch (error) {
      ForjaToast.error('Could not open the update: $error');
    }
  }
}
