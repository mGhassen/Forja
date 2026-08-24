/// YouTube trailer embed helpers.
///
/// YouTube returns **Error 153 - Video player configuration error** when the
/// embedded player cannot verify the request origin (missing/invalid Referer).
/// WebView2 on Windows is especially strict: iframes created by the IFrame API
/// may not send Referer even with [InAppWebViewInitialData.baseUrl].
///
/// Fix: pre-build the embed `<iframe>` with `referrerpolicy` and attach the
/// IFrame API to that element instead of letting `YT.Player` create one.
/// See https://developers.google.com/youtube/terms/required-minimum-functionality
const kYoutubeEmbedOrigin = 'https://com.forjahq.app';

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

/// Pre-built iframe markup - keeps Referer on Windows WebView2 / Error 153 fix.
String youtubeEmbedIframeHtml({required String embedSrc}) {
  return '''
<iframe
  id="player"
  referrerpolicy="strict-origin-when-cross-origin"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
  allowfullscreen
  frameborder="0"
  width="100%"
  height="100%"
  src="$embedSrc"
></iframe>''';
}

/// Fullscreen trailer player embed — used when native googlevideo resolve hits
/// YouTube age-gate (`Sign in to confirm your age`). Same nocookie + Referer
/// path as the details-hero ambient trailer; YouTube's player handles +18
/// without account sign-in (Forja is +18).
String youtubeFullscreenTrailerEmbedHtml(
  String videoId, {
  String? languageCode,
}) {
  final lang = languageCode?.trim();
  final hasLang = lang != null && lang.isNotEmpty;
  final playerVars = <String, Object>{
    'autoplay': 1,
    'mute': 0,
    'controls': 1,
    'modestbranding': 1,
    'rel': 0,
    'playsinline': 1,
    'fs': 1,
    'iv_load_policy': 3,
    'enablejsapi': 1,
  };
  if (hasLang) {
    playerVars['hl'] = lang;
    playerVars['cc_lang_pref'] = lang;
  }
  final embedSrc = youtubeNocookieEmbedSrc(
    videoId: videoId,
    playerVars: playerVars,
  );
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    #player { position: absolute; inset: 0; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  ${youtubeEmbedIframeHtml(embedSrc: embedSrc)}
  <script>$youtubeIframeReferrerPatchJs</script>
</body>
</html>''';
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
