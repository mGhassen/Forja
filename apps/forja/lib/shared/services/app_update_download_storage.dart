import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Where in-app desktop update installers are saved and cleared.
abstract final class AppUpdateDownloadStorage {
  static const supportUpdatesSubdir = 'updates';

  static final _updateFilePattern = RegExp(
    r'^Forja-\d+\.\d+.*\.(dmg|exe|AppImage|appimage)$',
    caseSensitive: false,
  );

  static Future<Directory> supportUpdatesDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, supportUpdatesSubdir));
  }

  static Future<List<Directory>> candidateDirectories() async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const [];
    }

    final dirs = <Directory>[];
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        dirs.add(downloads);
      }
    } catch (_) {}

    if (Platform.isMacOS) {
      dirs.add(await supportUpdatesDirectory());
    }

    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}

    return dirs;
  }

  static Future<Directory> resolveWritableDownloadDirectory() async {
    for (final dir in await candidateDirectories()) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (await _canWriteToDirectory(dir)) {
        return dir;
      }
    }

    throw Exception('No writable download folder');
  }

  static String fileNameFor({
    required String version,
    required String downloadUrl,
  }) {
    final assetExtension = path.extension(Uri.parse(downloadUrl).path);
    final extension = assetExtension.isNotEmpty
        ? assetExtension
        : Platform.isWindows
        ? '.exe'
        : Platform.isMacOS
        ? '.dmg'
        : '.AppImage';
    return 'Forja-$version$extension';
  }

  static Future<File?> findDownloadedFile({
    required String version,
    required String downloadUrl,
  }) async {
    final fileName = fileNameFor(version: version, downloadUrl: downloadUrl);
    for (final dir in await candidateDirectories()) {
      final file = File(path.join(dir.path, fileName));
      try {
        if (await file.exists() && await file.length() > 0) {
          return file;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Deletes saved update installers from Downloads, app support, and temp.
  static Future<int> clearDownloadedFiles() async {
    var removed = 0;
    final seen = <String>{};

    for (final dir in await candidateDirectories()) {
      if (!await dir.exists()) continue;

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        if (!_updateFilePattern.hasMatch(name)) continue;

        final filePath = entity.path;
        if (seen.contains(filePath)) continue;
        seen.add(filePath);

        await entity.delete();
        removed++;
      }
    }

    return removed;
  }

  static Future<bool> _canWriteToDirectory(Directory dir) async {
    final probe = File(path.join(dir.path, '.forja_write_probe'));
    try {
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      try {
        if (await probe.exists()) {
          await probe.delete();
        }
      } catch (_) {}
      return false;
    }
  }
}
