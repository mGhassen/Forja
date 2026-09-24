import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/downloads/download_speed_sampler.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:pointycastle/export.dart' as pc;

class HlsDownloadEngine {
  /// Checks whether a given URL points to an HLS (.m3u8) playlist.
  static bool isHlsUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('/playlist/') ||
        lower.contains('/hls/');
  }

  /// Downloads an HLS stream by parsing the playlist, resolving master variants,
  /// downloading all chunks sequentially, and concatenating into a playable file.
  static Future<void> downloadHlsStream({
    required DownloadTask task,
    required void Function(DownloadTask) onProgress,
    required bool Function() isPausedOrCanceled,
  }) async {
    final rawUrl = task.rawUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw Exception('Empty HLS stream URL');
    }

    final partFilePath = '${task.targetFilePath}.part';
    final metaFilePath = '${task.targetFilePath}.hls_meta.json';
    final partFile = File(partFilePath);
    final metaFile = File(metaFilePath);

    if (!await partFile.parent.exists()) {
      await partFile.parent.create(recursive: true);
    }

    final initialUri = Uri.parse(rawUrl);
    final headers = Map<String, String>.from(task.headers ?? {});
    if (!headers.containsKey('User-Agent')) {
      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }

    final initialManifestText = await _fetchText(initialUri, headers);
    if (!initialManifestText.contains('#EXTM3U')) {
      throw Exception('URL did not return a valid HLS #EXTM3U manifest');
    }

    var mediaPlaylistUri = initialUri;
    var mediaManifestText = initialManifestText;

    if (initialManifestText.contains('#EXT-X-STREAM-INF')) {
      final bestVariantUri =
          _selectBestVariantUri(initialUri, initialManifestText);
      if (bestVariantUri != null) {
        mediaPlaylistUri = bestVariantUri;
        mediaManifestText = await _fetchText(bestVariantUri, headers);
      }
    }

    final parsedPlaylist = await _parseMediaPlaylist(
      mediaPlaylistUri,
      mediaManifestText,
      headers,
    );
    final segments = parsedPlaylist.segments;
    if (segments.isEmpty) {
      throw Exception('HLS playlist contains 0 media segments');
    }

    var startSegmentIndex = 0;
    var totalBytesWritten = 0;

    if (await metaFile.exists() && await partFile.exists()) {
      try {
        final metaJson = jsonDecode(await metaFile.readAsString());
        startSegmentIndex = metaJson['lastSegmentIndex'] as int? ?? 0;
        totalBytesWritten = await partFile.length();
      } catch (_) {}
    }

    final mode = (startSegmentIndex > 0 && await partFile.exists())
        ? FileMode.append
        : FileMode.write;
    final sink = partFile.openWrite(mode: mode);

    if (startSegmentIndex == 0 && parsedPlaylist.initSegmentUri != null) {
      final initBytes =
          await _fetchBytes(parsedPlaylist.initSegmentUri!, headers);
      sink.add(initBytes);
      totalBytesWritten += initBytes.length;
    }

    final speedSampler = DownloadSpeedSampler();
    var lastMetaWrite = DateTime.fromMillisecondsSinceEpoch(0);
    var segmentsSinceMeta = 0;

    try {
      for (var i = startSegmentIndex; i < segments.length; i++) {
        if (isPausedOrCanceled()) {
          await sink.flush();
          await sink.close();
          // Persist resume cursor on pause/cancel.
          try {
            await metaFile.writeAsString(jsonEncode({
              'lastSegmentIndex': i,
              'totalSegments': segments.length,
              'bytesWritten': totalBytesWritten,
            }));
          } catch (_) {}
          return;
        }

        final segment = segments[i];
        var chunkBytes = await _fetchBytesWithRetry(
          segment.uri,
          headers,
          isPausedOrCanceled: isPausedOrCanceled,
        );

        if (segment.encryptionKey != null) {
          chunkBytes = _decryptAes128(
            chunkBytes,
            segment.encryptionKey!,
            segment.iv,
          );
        }

        sink.add(chunkBytes);
        totalBytesWritten += chunkBytes.length;
        speedSampler.addBytes(chunkBytes.length);

        final avgChunkSize = totalBytesWritten / (i + 1);
        final estimatedTotalBytes = (avgChunkSize * segments.length).round();
        final speed = speedSampler.speedBytesPerSec;
        final remaining = estimatedTotalBytes > totalBytesWritten
            ? estimatedTotalBytes - totalBytesWritten
            : 0;
        final eta = speedSampler.etaSecondsFor(remaining);

        segmentsSinceMeta++;
        final now = DateTime.now();
        final metaDue = segmentsSinceMeta >= 5 ||
            now.difference(lastMetaWrite).inMilliseconds >= 2000;
        if (metaDue) {
          await metaFile.writeAsString(jsonEncode({
            'lastSegmentIndex': i + 1,
            'totalSegments': segments.length,
            'bytesWritten': totalBytesWritten,
          }));
          lastMetaWrite = now;
          segmentsSinceMeta = 0;
        }

        // Always report progress; sampler holds last rate between 1s windows
        // so speed/ETA do not flash back to 0 after every segment.
        onProgress(task.copyWith(
          status: DownloadStatus.downloading,
          receivedBytes: totalBytesWritten,
          totalBytes: estimatedTotalBytes,
          speedBytesPerSec: speed,
          etaSeconds: eta,
          error: null,
        ));
      }

      await sink.flush();
      await sink.close();

      await Future.delayed(const Duration(milliseconds: 200));

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
          '[HlsDownloadEngine] Rename failed, using fallback copy: $e',
        );
        await partFile.copy(task.targetFilePath);
        try {
          await partFile.delete();
        } catch (_) {}
      }

      if (await metaFile.exists()) {
        try {
          await metaFile.delete();
        } catch (_) {}
      }

      final completedBytes = await File(task.targetFilePath).length();

      onProgress(task.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: completedBytes,
        totalBytes: completedBytes,
        speedBytesPerSec: 0.0,
        etaSeconds: 0,
        completedAt: DateTime.now(),
        error: null,
      ));
    } catch (e) {
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}
      rethrow;
    }
  }

  static Uri? _selectBestVariantUri(Uri baseUri, String manifestText) {
    final lines = manifestText.split('\n');
    var highestBandwidth = -1;
    Uri? bestUri;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        var bandwidth = 0;
        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        if (bwMatch != null) {
          bandwidth = int.tryParse(bwMatch.group(1) ?? '') ?? 0;
        }

        for (var j = i + 1; j < lines.length; j++) {
          final subLine = lines[j].trim();
          if (subLine.isNotEmpty && !subLine.startsWith('#')) {
            if (bandwidth > highestBandwidth || bestUri == null) {
              highestBandwidth = bandwidth;
              bestUri = baseUri.resolve(subLine);
            }
            break;
          }
        }
      }
    }
    return bestUri;
  }

  static Future<_ParsedMediaPlaylist> _parseMediaPlaylist(
    Uri baseUri,
    String manifestText,
    Map<String, String> headers,
  ) async {
    final lines = manifestText.split('\n');
    final segments = <_HlsSegment>[];
    Uri? initSegmentUri;

    Uint8List? currentKeyBytes;
    Uint8List? currentIv;
    var sequence = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        final seqStr = line.replaceFirst('#EXT-X-MEDIA-SEQUENCE:', '').trim();
        sequence = int.tryParse(seqStr) ?? 0;
      } else if (line.startsWith('#EXT-X-MAP:')) {
        final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(line);
        if (uriMatch != null) {
          initSegmentUri = baseUri.resolve(uriMatch.group(1)!);
        }
      } else if (line.startsWith('#EXT-X-KEY:')) {
        if (line.contains('METHOD=AES-128')) {
          final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(line);
          if (uriMatch != null) {
            final keyUri = baseUri.resolve(uriMatch.group(1)!);
            try {
              currentKeyBytes = await _fetchBytes(keyUri, headers);
            } catch (e) {
              debugPrint('[HlsDownloadEngine] Failed fetching AES-128 key: $e');
            }
          }

          final ivMatch = RegExp(r'IV=0x([0-9a-fA-F]+)').firstMatch(line);
          if (ivMatch != null) {
            currentIv = _hexToBytes(ivMatch.group(1)!);
          }
        } else if (line.contains('METHOD=NONE')) {
          currentKeyBytes = null;
          currentIv = null;
        }
      } else if (line.startsWith('#EXTINF:')) {
        for (var j = i + 1; j < lines.length; j++) {
          final subLine = lines[j].trim();
          if (subLine.isNotEmpty && !subLine.startsWith('#')) {
            final segUri = baseUri.resolve(subLine);

            var segIv = currentIv;
            if (currentKeyBytes != null && segIv == null) {
              segIv = Uint8List(16);
              final bd = ByteData.view(segIv.buffer);
              bd.setUint64(8, sequence, Endian.big);
            }

            segments.add(_HlsSegment(
              uri: segUri,
              encryptionKey: currentKeyBytes,
              iv: segIv,
              sequenceNumber: sequence,
            ));
            sequence++;
            i = j;
            break;
          }
        }
      }
    }

    return _ParsedMediaPlaylist(
      segments: segments,
      initSegmentUri: initSegmentUri,
    );
  }

  static Future<String> _fetchText(Uri uri, Map<String, String> headers) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(uri);
      headers.forEach((k, v) => req.headers.set(k, v));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw Exception('Failed to fetch manifest: HTTP ${res.statusCode}');
      }
      final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      client.close();
    }
  }

  static Future<Uint8List> _fetchBytesWithRetry(
    Uri uri,
    Map<String, String> headers, {
    int maxRetries = 4,
    required bool Function() isPausedOrCanceled,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      if (isPausedOrCanceled()) throw Exception('Download paused or canceled');
      try {
        return await _fetchBytes(uri, headers);
      } catch (e) {
        if (attempt == maxRetries || isPausedOrCanceled()) rethrow;
        debugPrint(
          '[HlsDownloadEngine] Chunk fetch failed ($e), retrying attempt '
          '$attempt of $maxRetries in ${600 * attempt}ms...',
        );
        await Future.delayed(Duration(milliseconds: 600 * attempt));
      }
    }
    throw Exception('Failed to fetch segment after $maxRetries attempts');
  }

  static Future<Uint8List> _fetchBytes(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(uri);
      headers.forEach((k, v) => req.headers.set(k, v));
      final res = await req.close();
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception(
          'Failed to fetch segment ${uri.path}: HTTP ${res.statusCode}',
        );
      }
      final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }

  static Uint8List _decryptAes128(
    Uint8List encrypted,
    Uint8List key,
    Uint8List? iv,
  ) {
    try {
      final effectiveIv = iv ?? Uint8List(16);
      final cipher = pc.CBCBlockCipher(pc.AESEngine());
      final params = pc.ParametersWithIV(pc.KeyParameter(key), effectiveIv);
      cipher.init(false, params);

      final padded = pc.PaddedBlockCipherImpl(pc.PKCS7Padding(), cipher);
      final paddedParams = pc.PaddedBlockCipherParameters(params, null);
      padded.init(false, paddedParams);

      return padded.process(encrypted);
    } catch (_) {
      try {
        final cipher = pc.CBCBlockCipher(pc.AESEngine());
        final params =
            pc.ParametersWithIV(pc.KeyParameter(key), iv ?? Uint8List(16));
        cipher.init(false, params);
        final out = Uint8List(encrypted.length);
        for (var offset = 0; offset < encrypted.length; offset += 16) {
          if (offset + 16 <= encrypted.length) {
            cipher.processBlock(encrypted, offset, out, offset);
          }
        }
        return out;
      } catch (e) {
        debugPrint('[HlsDownloadEngine] AES-128 decryption error: $e');
        return encrypted;
      }
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}

class _HlsSegment {
  final Uri uri;
  final Uint8List? encryptionKey;
  final Uint8List? iv;
  final int sequenceNumber;

  const _HlsSegment({
    required this.uri,
    this.encryptionKey,
    this.iv,
    required this.sequenceNumber,
  });
}

class _ParsedMediaPlaylist {
  final List<_HlsSegment> segments;
  final Uri? initSegmentUri;

  const _ParsedMediaPlaylist({
    required this.segments,
    this.initSegmentUri,
  });
}
