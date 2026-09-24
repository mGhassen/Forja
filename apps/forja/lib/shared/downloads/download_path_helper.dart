import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the on-disk folder for VOD offline downloads.
class DownloadPathHelper {
  static const String _customPathKey = 'forja_custom_downloads_directory';

  /// Returns the configured downloads directory path.
  ///
  /// Prefer public `Downloads/Forja` on desktop/Android when available,
  /// otherwise `Documents/ForjaDownloads`.
  static Future<String> getDownloadsDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_customPathKey);
    if (custom != null && custom.isNotEmpty) {
      final customDir = Directory(custom);
      if (await customDir.exists() || await _tryCreate(customDir)) {
        return custom;
      }
    }

    final defaultPath = await getDefaultDownloadsDirectoryPath();
    final defaultDir = Directory(defaultPath);
    if (!await defaultDir.exists()) {
      await defaultDir.create(recursive: true);
    }
    return defaultPath;
  }

  /// Sets a custom user downloads directory (Settings → Downloads).
  static Future<void> setCustomDownloadsDirectoryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPathKey, path);
  }

  /// Platform default: public Downloads/Forja, else Documents/ForjaDownloads.
  static Future<String> getDefaultDownloadsDirectoryPath() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final publicDownload =
            Directory('/storage/emulated/0/Download/Forja');
        if (await publicDownload.exists() ||
            await _tryCreate(publicDownload)) {
          return publicDownload.path;
        }

        final extDirs =
            await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty) {
          final target = Directory(p.join(extDirs.first.path, 'Forja'));
          if (await target.exists() || await _tryCreate(target)) {
            return target.path;
          }
        }
      } catch (_) {}
    }

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final target = Directory(p.join(downloadsDir.path, 'Forja'));
          if (await target.exists() || await _tryCreate(target)) {
            return target.path;
          }
        }
      } catch (_) {}
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final fallback = Directory(p.join(appDocDir.path, 'ForjaDownloads'));
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback.path;
  }

  static Future<bool> _tryCreate(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sanitizes a filename removing forbidden filesystem characters.
  static String sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
