/// YouTube trailer embed helpers.
///
/// YouTube returns **Error 153 — Video player configuration error** when the
/// embedded player cannot verify the request origin (missing/invalid Referer).
/// WebView2 on Windows is especially strict: iframes created by the IFrame API
/// may not send Referer even with [InAppWebViewInitialData.baseUrl].
///
/// Fix: pre-build the embed `<iframe>` with `referrerpolicy` and attach the
/// IFrame API to that element instead of letting `YT.Player` create one.
/// See https://developers.google.com/youtube/terms/required-minimum-functionality
const kYoutubeEmbedOrigin = 'https://com.forja.app';

/// nocookie embed URL with origin + widget_referrer for WebView Referer policy.
String youtubeNocookieEmbedSrc({
  required String videoId,
  required Map<String, Object> playerVars,
}) {
  final params = playerVars.map((key, value) => MapEntry(key, value.toString()));
  params['origin'] = kYoutubeEmbedOrigin;
  params['widget_referrer'] = kYoutubeEmbedOrigin;
  return Uri(
    scheme: 'https',
    host: 'www.youtube-nocookie.com',
    path: '/embed/$videoId',
    queryParameters: params,
  ).toString();
}

/// Pre-built iframe markup — keeps Referer on Windows WebView2 / Error 153 fix.
String youtubeEmbedIframeHtml({required String embedSrc}) {
  return '''
<iframe
  id="player"
  referrerpolicy="strict-origin-when-cross-origin"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
  frameborder="0"
  width="100%"
  height="100%"
  src="$embedSrc"
></iframe>''';
}

/// Ensures any iframe under `#player` keeps strict-origin referrer policy.
const youtubeIframeReferrerPatchJs = '''
function patchYoutubeIframeReferrer(el) {
  if (!el) return;
  var iframe = el.tagName === 'IFRAME' ? el : el.querySelector('iframe');
  if (!iframe) return;
  if (iframe.getAttribute('referrerpolicy') !== 'strict-origin-when-cross-origin') {
    iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
  }
}
patchYoutubeIframeReferrer(document.getElementById('player'));
''';
