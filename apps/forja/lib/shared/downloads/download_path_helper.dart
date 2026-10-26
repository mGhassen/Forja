import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart' show LocalDataScope, PlayableStreamFileRoots;
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the on-disk folder for VOD offline downloads.
///
/// Device root (`Downloads/Forja` or a user-picked folder) is shared; the
/// library itself lives under `accounts/<accountId>/<profileId>/` so identities
/// never see each other's files or task index.
class DownloadPathHelper {
  static const String _customPathKey = 'forja_custom_downloads_directory';

  /// `accounts/<accountId>/<profileId>` under the device root.
  static String identityRelativePath({String? accountId, String? profileId}) {
    final account = (accountId ?? LocalDataScope.accountId).trim();
    final profile = (profileId ?? LocalDataScope.profileId).trim();
    return p.join(
      'accounts',
      account.isEmpty ? LocalDataScope.guestAccountId : account,
      profile.isEmpty ? LocalDataScope.guestProfileId : profile,
    );
  }

  /// Device root only (no identity segment). Settings “Change” picks this.
  static Future<String> getDownloadsRootPath() async {
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

  /// Active identity’s library folder (files + `forja_download_tasks.json`).
  static Future<String> getDownloadsDirectoryPath() async {
    return getDownloadsDirectoryPathFor(
      accountId: LocalDataScope.accountId,
      profileId: LocalDataScope.profileId,
    );
  }

  /// Library folder for a specific identity (used when flushing before switch).
  static Future<String> getDownloadsDirectoryPathFor({
    required String accountId,
    required String profileId,
  }) async {
    final root = await getDownloadsRootPath();
    final scoped = Directory(
      p.join(
        root,
        identityRelativePath(accountId: accountId, profileId: profileId),
      ),
    );
    if (!await scoped.exists()) {
      await scoped.create(recursive: true);
    }
    return scoped.path;
  }

  /// Sets a custom user downloads **root** (Settings → Downloads).
  static Future<void> setCustomDownloadsDirectoryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPathKey, path);
    // Files under the new folder become playable `file://` streams too.
    PlayableStreamFileRoots.add(await getDownloadsDirectoryPath());
  }

  /// Clears a custom folder so the next resolve uses the platform default.
  static Future<void> clearCustomDownloadsDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customPathKey);
  }

  /// Whether Settings has a user-picked downloads folder (may be stale on disk).
  static Future<bool> hasCustomDownloadsDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_customPathKey);
    return custom != null && custom.isNotEmpty;
  }

  /// Platform default root: public Downloads/Forja, else Documents/ForjaDownloads.
  static Future<String> getDefaultDownloadsDirectoryPath() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final publicDownload = Directory('/storage/emulated/0/Download/Forja');
        if (await publicDownload.exists() || await _tryCreate(publicDownload)) {
          return publicDownload.path;
        }

        final extDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
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
