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

/// Android System WebView cannot play Streamed / many PPV embeds in-page
/// (CORS + host lock UI). Sniff HLS and hand off to the native IPTV player.
bool liveEmbedAndroidNativeHandoff(String embedUrl) {
  // All Android Live embeds use sniff → native; WebView-only is a dead end on
  // System WebView (red lock / Uncaught play promise).
  return embedUrl.trim().isNotEmpty;
}
