import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:path_provider/path_provider.dart';

/// embed.st GOAT decrypt bridge for live-streamed.js (`ctx.live.goatUnlock`).
class LiveGoatUnlock {
  LiveGoatUnlock._();

  static const _assetRoot = 'assets/providers/live/goat';
  static String? _cachedDir;
  static Future<void>? _prepareFuture;

  static Future<String?> unlock({
    required Map<String, dynamic> slot,
    required String goat,
    required String bodyHex,
  }) async {
    if (goat.isEmpty || bodyHex.isEmpty) return null;
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;
    final embedOrigin = (slot['origin'] ?? 'https://embed.st').toString();
    debugPrint(
      '[LiveGoatUnlock] path=$path goat=${goat.length} body=${bodyHex.length ~/ 2}B',
    );

    final node = await _findNodeBinary();
    if (node != null) {
      try {
        final dir = await _ensureGoatDir(node);
        final url = await _runNodeUnlock(
          node: node,
          dir: dir,
          slot: slot,
          goat: goat,
          bodyHex: bodyHex,
          embedOrigin: embedOrigin,
        );
        if (url != null && url.isNotEmpty) return url;
      } catch (e) {
        debugPrint('[LiveGoatUnlock] node unlock failed: $e');
      }
    } else {
      debugPrint('[LiveGoatUnlock] node not found — sniff fallback');
    }

    final origin = embedOrigin.endsWith('/')
        ? embedOrigin.substring(0, embedOrigin.length - 1)
        : embedOrigin;
    return sniffEmbed(
      embedUrl: '$origin/embed/$path',
      referer: '$origin/',
    );
  }

  static Future<String?> sniffEmbed({
    required String embedUrl,
    String? referer,
  }) async {
    final url = embedUrl.trim();
    if (url.isEmpty) return null;
    final ref = (referer ?? url).trim();
    try {
      final extracted = await StreamExtractor().extract(
        url,
        referer: ref,
        iframeWrapperBaseUrl: ref.endsWith('/') ? ref : '$ref/',
        timeout: const Duration(seconds: 35),
      );
      final out = extracted?.url.trim() ?? '';
      return out.isEmpty ? null : out;
    } catch (e) {
      debugPrint('[LiveSniffEmbed] failed: $e');
      return null;
    }
  }

  static Future<String?> _findNodeBinary() async {
    const candidates = [
      'node',
      '/opt/homebrew/bin/node',
      '/usr/local/bin/node',
    ];
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--version']);
        if (result.exitCode == 0) return c;
      } catch (_) {}
    }
    try {
      final which = await Process.run('which', ['node']);
      if (which.exitCode == 0) {
        final path = which.stdout.toString().trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> _ensureGoatDir(String node) async {
    if (_cachedDir != null) {
      final ready = File('${_cachedDir!}/node_modules/happy-dom/package.json');
      if (await ready.exists()) return _cachedDir!;
    }
    _prepareFuture ??= _prepareGoatDir(node);
    await _prepareFuture;
    final dir = _cachedDir;
    if (dir == null) {
      throw StateError('GOAT unlock runtime failed to initialize');
    }
    return dir;
  }

  static Future<void> _prepareGoatDir(String node) async {
    final cached = _cachedDir;
    if (cached != null) {
      final ready = File('$cached/node_modules/happy-dom/package.json');
      if (await ready.exists()) return;
    }

    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/live-goat');
    await dir.create(recursive: true);

    await _writeAsset('$_assetRoot/unlock.mjs', File('${dir.path}/unlock.mjs'));
    await _writeAsset(
      '$_assetRoot/package.json',
      File('${dir.path}/package.json'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/lock.wasm',
      File('${dir.path}/vendor/lock.wasm'),
    );
    await _writeAsset(
      '$_assetRoot/vendor/lock-esm.mjs',
      File('${dir.path}/vendor/lock-esm.mjs'),
    );

    final npm = await _findNpmBinary();
    if (npm == null) {
      throw StateError('npm not found (needed once for GOAT unlock deps)');
    }
    final install = await Process.run(
      npm,
      [
        'install',
        'happy-dom@17',
        'big-integer@1.6.52',
        '--no-fund',
        '--no-audit',
        '--prefer-offline',
      ],
      workingDirectory: dir.path,
    ).timeout(const Duration(minutes: 2));
    if (install.exitCode != 0) {
      throw StateError(
        'npm install failed: ${install.stderr.toString().trim()}',
      );
    }

    _cachedDir = dir.path;
  }

  static Future<String?> _findNpmBinary() async {
    const candidates = ['npm', '/opt/homebrew/bin/npm', '/usr/local/bin/npm'];
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--version']);
        if (result.exitCode == 0) return c;
      } catch (_) {}
    }
    try {
      final which = await Process.run('which', ['npm']);
      if (which.exitCode == 0) {
        final path = which.stdout.toString().trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeAsset(String assetPath, File out) async {
    await out.parent.create(recursive: true);
    final data = await rootBundle.load(assetPath);
    await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  static Future<String?> _runNodeUnlock({
    required String node,
    required String dir,
    required Map<String, dynamic> slot,
    required String goat,
    required String bodyHex,
    required String embedOrigin,
  }) async {
    final payload = jsonEncode({
      'slot': slot,
      'goat': goat,
      'bodyHex': bodyHex,
      'embedOrigin': embedOrigin,
    });
    final proc = await Process.start(
      node,
      ['unlock.mjs'],
      workingDirectory: dir,
      runInShell: false,
    );
    proc.stdin.write(payload);
    await proc.stdin.close();
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exit = await proc.exitCode.timeout(const Duration(seconds: 45));
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final raw = stdout.trim();
    if (exit != 0 || raw.isEmpty) {
      debugPrint('[LiveGoatUnlock] exit=$exit stdout=$raw stderr=$stderr');
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    if (decoded['ok'] == true) {
      return (decoded['url'] ?? '').toString().trim();
    }
    debugPrint('[LiveGoatUnlock] ${decoded['error']}');
    return null;
  }
}
