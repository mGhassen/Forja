// Shared scrub helpers for Sentry + PostHog (RFC-043).

String scrubText(String input) {
  var out = input;
  out = out.replaceAllMapped(
    RegExp(r'''magnet:\?[^\s"']+''', caseSensitive: false),
    (_) => 'magnet:[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'''https?://[^\s"']+''', caseSensitive: false),
    (m) => scrubUrl(m.group(0)!),
  );
  out = out.replaceAllMapped(
    RegExp(
      r'(authorization|cookie|token|api[_-]?key|password|jwt)\s*[:=]\s*\S.*',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}:[redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    (_) => '[jwt-redacted]',
  );
  return out;
}

String scrubUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return '[url-redacted]';
  if (uri.hasScheme && uri.host.isNotEmpty) {
    return '${uri.scheme}://${uri.host}/[redacted]';
  }
  return '[url-redacted]';
}

bool sensitiveHeader(String key) {
  final k = key.toLowerCase();
  return k == 'authorization' ||
      k == 'cookie' ||
      k == 'set-cookie' ||
      k == 'x-api-key' ||
      k.contains('token');
}

bool sensitiveKey(String key) {
  final k = key.toLowerCase();
  return k.contains('token') ||
      k.contains('password') ||
      k.contains('secret') ||
      k.contains('cookie') ||
      k.contains('magnet') ||
      k.contains('url');
}
