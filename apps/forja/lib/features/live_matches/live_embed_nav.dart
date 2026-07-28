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

/// Per-provider Android sniff → native handoff profile.
///
/// Shared: black cover, Cookie harvest, `/hls-proxy`, Exo open, abandon/exit.
/// Split: how the WebView loads, main-frame policy, proxy Referer, timing.
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

  /// Wait after sniff before Cookie harvest / probe (Streamed is usually warm).
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
          // One Cookie settle retry — do not slow the happy path.
          maxSoftRecover: 1,
          cookieSettle: Duration(milliseconds: 120),
          maxProbeAttempts: 2,
          logLabel: 'streamed',
        );
    }
  }
}

/// Android System WebView cannot play Streamed / many PPV embeds in-page
/// (CORS + host lock UI). Sniff HLS and hand off to the native IPTV player.
bool liveEmbedAndroidNativeHandoff(String embedUrl) {
  // All Android Live embeds use sniff → native; WebView-only is a dead end on
  // System WebView (red lock / Uncaught play promise).
  return embedUrl.trim().isNotEmpty;
}
