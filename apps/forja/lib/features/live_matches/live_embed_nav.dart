import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Main-frame navigation policy for the Live Matches embed WebView.
///
/// Wrapper mode loads HTML via `loadData(baseUrl: catalog)` so `document.referrer`
/// matches streamed.pk / ppv.is. WKWebView reports that catalog **origin root**
/// (`https://streamed.pk/`, `https://ppv.is/`) as a main-frame navigation.
/// Cancelling it leaves a blank white player and can kill the WKWebView process
/// (`Lost connection to device`). Always allow that root; still cancel deeper
/// catalog SPA paths and unrelated ad hosts after the wrapper is up.
bool liveEmbedAllowsMainFrameNavigation({
  required String url,
  required String embedUrl,
  required bool allowEmbedHostAsMainFrame,
  String? wrapperReferer,
}) {
  if (url.isEmpty ||
      url.startsWith('about:') ||
      url.startsWith('data:') ||
      url.startsWith('blob:')) {
    return true;
  }
  // loadData(baseUrl) - never cancel. Also covers a rare post-commit reload of
  // the same root; SPA hijacks use deeper paths (/watch/…) and stay blocked.
  if (wrapperReferer != null &&
      liveEmbedIsCatalogOriginRoot(url: url, wrapperReferer: wrapperReferer)) {
    return true;
  }
  if (!allowEmbedHostAsMainFrame) return false;
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  final embedHost = Uri.tryParse(embedUrl)?.host.toLowerCase() ?? '';
  if (host.isEmpty || embedHost.isEmpty) return false;
  return host == embedHost || host.endsWith('.$embedHost');
}

/// Whether [url] is same-site as the iframe-wrapper catalog [wrapperReferer].
bool liveEmbedIsWrapperCatalogUrl({
  required String url,
  required String wrapperReferer,
}) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  final refererHost = Uri.tryParse(wrapperReferer)?.host.toLowerCase() ?? '';
  if (host.isEmpty || refererHost.isEmpty) return false;
  return host == refererHost ||
      host.endsWith('.$refererHost') ||
      refererHost.endsWith('.$host');
}

/// Catalog origin with empty or `/` path - the `loadData` baseUrl shape.
bool liveEmbedIsCatalogOriginRoot({
  required String url,
  required String wrapperReferer,
}) {
  if (!liveEmbedIsWrapperCatalogUrl(url: url, wrapperReferer: wrapperReferer)) {
    return false;
  }
  final path = Uri.tryParse(url)?.path ?? '';
  return path.isEmpty || path == '/';
}

/// PPV `embedindia.st` JW Player keeps tokenised HLS in the embed browsing
/// context. Prefer Android native handoff with Referer/Cookie proxy (same as
/// Streamed) — in-page WebView hits CORS / host-lock UI on System WebView.
bool liveEmbedRequiresWebViewPlayback(String embedUrl) {
  final host = Uri.tryParse(embedUrl)?.host.toLowerCase() ?? '';
  return host.contains('embedindia.st');
}

/// Which Live catalog family owns this embed — techniques must not cross.
///
/// PPV and Streamed fail differently (JW + `indianservers` vs HLS.js +
/// `strmd.st`). Android handoff settings are chosen **only** from this kind;
/// never apply a PPV-only hook to Streamed (or the reverse).
enum LiveEmbedProviderKind {
  /// `embedindia.st` under ppv.is
  ppv,

  /// Streamed / embedsports-style under streamed.pk
  streamed,
}

LiveEmbedProviderKind liveEmbedProviderKind(String embedUrl) {
  if (liveEmbedRequiresWebViewPlayback(embedUrl)) {
    return LiveEmbedProviderKind.ppv;
  }
  return LiveEmbedProviderKind.streamed;
}

/// Turn relative playlist lines / URI="…" into absolute URLs so a local
/// `file://` master can still fetch CDN segments (Streamed capture handoff).
String liveEmbedRewriteM3u8Absolute(String body, String playlistUrl) {
  final base = Uri.tryParse(playlistUrl);
  if (base == null) return body;
  final out = StringBuffer();
  for (final raw in body.split('\n')) {
    final line = raw.replaceAll('\r', '');
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      out.writeln(line);
      continue;
    }
    if (trimmed.startsWith('#')) {
      out.writeln(_liveEmbedRewriteM3u8TagUris(line, base));
      continue;
    }
    out.writeln(base.resolve(trimmed).toString());
  }
  return out.toString();
}

String _liveEmbedRewriteM3u8TagUris(String line, Uri base) {
  return line.replaceAllMapped(
    RegExp(r'URI="([^"]+)"', caseSensitive: false),
    (m) {
      final raw = m.group(1) ?? '';
      if (raw.isEmpty ||
          raw.startsWith('http://') ||
          raw.startsWith('https://') ||
          raw.startsWith('data:')) {
        return m.group(0)!;
      }
      return 'URI="${base.resolve(raw)}"';
    },
  );
}

/// Per-provider Android sniff → native handoff profile.
///
/// Shared: black cover, Cookie harvest, Exo open, abandon/exit.
/// Streamed: capture `#EXTM3U` body from WebView → local file (no `/hls-proxy`).
/// PPV: Cookie + `/hls-proxy` probe (embedindia CDN).
class LiveEmbedAndroidHandoffProfile {
  const LiveEmbedAndroidHandoffProfile._({
    required this.kind,
    required this.topLevelEmbedLoad,
    required this.allowEmbedHostAsMainFrame,
    required this.maxSoftRecover,
    required this.cookieSettle,
    required this.maxProbeAttempts,
    required this.logLabel,
  });

  final LiveEmbedProviderKind kind;

  /// PPV: load embedindia as the main frame (no ppv.is iframe).
  /// Streamed: keep catalog `loadData` iframe wrapper (host lock).
  final bool topLevelEmbedLoad;

  final bool allowEmbedHostAsMainFrame;

  /// Extra probe→re-sniff attempts before abandon (Streamed cookie settle).
  final int maxSoftRecover;

  /// Wait after sniff before Cookie harvest / probe.
  final Duration cookieSettle;

  final int maxProbeAttempts;

  final String logLabel;

  bool get isPpv => kind == LiveEmbedProviderKind.ppv;
  bool get isStreamed => kind == LiveEmbedProviderKind.streamed;

  factory LiveEmbedAndroidHandoffProfile.forEmbed(String embedUrl) {
    switch (liveEmbedProviderKind(embedUrl)) {
      case LiveEmbedProviderKind.ppv:
        return const LiveEmbedAndroidHandoffProfile._(
          kind: LiveEmbedProviderKind.ppv,
          topLevelEmbedLoad: true,
          allowEmbedHostAsMainFrame: true,
          maxSoftRecover: 0,
          cookieSettle: Duration(milliseconds: 450),
          maxProbeAttempts: 3,
          logLabel: 'ppv/embedindia',
        );
      case LiveEmbedProviderKind.streamed:
        return const LiveEmbedAndroidHandoffProfile._(
          kind: LiveEmbedProviderKind.streamed,
          topLevelEmbedLoad: false,
          allowEmbedHostAsMainFrame: false,
          // Soft recover unused on Streamed capture path; probe used as fallback.
          maxSoftRecover: 0,
          cookieSettle: Duration(milliseconds: 450),
          maxProbeAttempts: 3,
          logLabel: 'streamed',
        );
    }
  }
}

/// Android System WebView cannot play Streamed / PPV embeds in-page
/// (CORS + red host-lock UI). Sniff HLS and hand off to the native IPTV player.
bool liveEmbedAndroidNativeHandoff(String embedUrl) {
  // All Android Live embeds use sniff → native; WebView-only is a dead end on
  // System WebView (red “Remove sandbox attributes…” / Uncaught play promise).
  return embedUrl.trim().isNotEmpty;
}

/// Streamed catalog URLs that often wrap `embedindia.st` in a nested iframe
/// (e.g. Rally TV → `embed.st` → `embedindia.st/embed-noads/…`). Nested
/// embedindia shows the red “Remove sandbox attributes…” lock under System
/// WebView; peel to the inner player so Android uses PPV sniff→Exo.
bool liveEmbedMayNestEmbedIndia(String embedUrl) {
  final host = Uri.tryParse(embedUrl)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  if (host.contains('embedindia')) return false;
  return host == 'embed.st' ||
      host.endsWith('.embed.st') ||
      host.contains('embedsports');
}

/// First `embedindia.st` iframe `src` in [html], if any.
String? liveEmbedExtractNestedEmbedIndiaUrl(String html) {
  final re = RegExp(
    r'''src\s*=\s*["'](https?://[^"']*embedindia\.st[^"']*)["']''',
    caseSensitive: false,
  );
  final m = re.firstMatch(html);
  final url = m?.group(1)?.trim();
  if (url == null || url.isEmpty) return null;
  return url;
}

/// If [embedUrl] is a Streamed wrapper that nests embedindia, return the
/// inner player URL; otherwise return [embedUrl] unchanged.
Future<String> liveEmbedResolveNestedPlayerUrl(
  String embedUrl, {
  String? catalogReferer,
}) async {
  final trimmed = embedUrl.trim();
  if (trimmed.isEmpty || !liveEmbedMayNestEmbedIndia(trimmed)) {
    return trimmed;
  }
  HttpClient? client;
  try {
    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    final req = await client.getUrl(Uri.parse(trimmed));
    final referer = (catalogReferer ?? '').trim();
    if (referer.isNotEmpty) {
      req.headers.set('Referer', referer);
    }
    final resp = await req.close().timeout(const Duration(seconds: 8));
    if (resp.statusCode >= 400) return trimmed;
    final body = await resp.transform(utf8.decoder).join();
    final nested = liveEmbedExtractNestedEmbedIndiaUrl(body);
    if (nested != null) {
      debugPrint('[LiveMatches] peeled nested embedindia: $nested');
      return nested;
    }
  } catch (e) {
    debugPrint('[LiveMatches] nest peel failed: $e');
  } finally {
    client?.close(force: true);
  }
  return trimmed;
}
