import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:rust/rust.dart';

/// Resolve a third-party embed URL to playable media (PACKER HTTP, then WebView).
/// Host-generic — not tied to any catalog pack / scraper id.
abstract final class EmbedStreamResolve {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  static const _webViewBlacklist = ['mixdrop', 'm1xdrop', 'dsvplay'];
  static const _packerSkipHosts = ['ramadan-series.site', 'watch-rmdan.shop'];

  static Future<ExtractedMedia?> resolve(String embedUrl) async {
    final host = Uri.tryParse(embedUrl)?.host ?? '';

    if (!_packerSkipHosts.any((d) => host.contains(d))) {
      final directUrl = await _tryPackerOrDirect(embedUrl);
      if (directUrl != null) {
        final uri = Uri.tryParse(embedUrl);
        final origin = uri != null ? '${uri.scheme}://${uri.host}' : '';
        final headers = {
          'User-Agent': _userAgent,
          'Referer': origin.isNotEmpty ? '$origin/' : embedUrl,
          'Origin': origin,
        };
        final proxyUrl = LocalServerService().getHlsProxyUrl(
          directUrl,
          headers,
        );
        return ExtractedMedia(url: proxyUrl, headers: {});
      }
    } else {
      debugPrint('[EmbedStreamResolve] Skipping PACKER for $host — WebView');
    }

    if (_webViewBlacklist.any((d) => host.contains(d))) return null;

    try {
      final result = await StreamExtractor().extract(
        embedUrl,
        timeout: const Duration(seconds: 15),
      );
      if (result == null) return null;
      if (result.headers.isNotEmpty) {
        final proxyUrl = LocalServerService().getHlsProxyUrl(
          result.url,
          result.headers,
        );
        return ExtractedMedia(
          url: proxyUrl,
          audioUrl: result.audioUrl,
          headers: {},
        );
      }
      return result;
    } catch (e) {
      debugPrint('[EmbedStreamResolve] WebView extract failed: $e');
      return null;
    }
  }

  static Future<String?> _tryPackerOrDirect(String embedUrl) async {
    try {
      final uri = Uri.tryParse(embedUrl);
      final origin = uri != null ? '${uri.scheme}://${uri.host}' : '';
      final res = await animeHttp(
        'GET',
        embedUrl,
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': origin.isNotEmpty ? '$origin/' : embedUrl,
        },
        maxRetries: 0,
      );
      if (res.status != 200) return null;
      final html = res.body;

      final packed = RegExp(
        r"eval\(function\(p,a,c,k,e,d\)\{.*?\}\('(.+)',(\d+),(\d+),'(.+?)'\.split\('\|'\)",
        dotAll: true,
      ).firstMatch(html);

      if (packed != null) {
        final url = _unpackAndFindStream(
          packed.group(1)!,
          int.parse(packed.group(2)!),
          int.parse(packed.group(3)!),
          packed.group(4)!,
        );
        if (url != null) return url;
      }

      final direct = RegExp(
        r'file\s*:\s*"(https?://[^"]+\.(?:m3u8|mp4)[^"]*)"',
      ).firstMatch(html);
      return direct?.group(1);
    } catch (e) {
      debugPrint('[EmbedStreamResolve] PACKER error for $embedUrl: $e');
      return null;
    }
  }

  static String? _unpackAndFindStream(String p, int a, int c, String keywords) {
    final kw = keywords.split('|');
    const chars =
        '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

    String toBase(int n, int radix) {
      if (n == 0) return '0';
      final buf = StringBuffer();
      var val = n;
      while (val > 0) {
        buf.write(chars[val % radix]);
        val = val ~/ radix;
      }
      return buf.toString().split('').reversed.join();
    }

    var result = p;
    for (var i = c - 1; i >= 0; i--) {
      if (i < kw.length && kw[i].isNotEmpty) {
        final token = toBase(i, a);
        result = result.replaceAll(RegExp('\\b$token\\b'), kw[i]);
      }
    }

    final m3u8 = RegExp(r'https?://[^\s"]+\.m3u8[^\s"]*').firstMatch(result);
    if (m3u8 != null) return m3u8.group(0);
    final mp4 = RegExp(r'https?://[^\s"]+\.mp4[^\s"]*').firstMatch(result);
    return mp4?.group(0);
  }
}
