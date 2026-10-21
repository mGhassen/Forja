/// Log redaction for stream / portal / handoff addresses.
///
/// Keeps scheme, host, port, and path shape so a log line still identifies
/// the stream, while masking everything that grants access:
/// `user:pass@` userinfo, query values whose key names a credential
/// (`password`, `pass`, `pwd`, `token`, `key`, `secret`, `auth`, `sig`,
/// `username`, `user`), and Xtream-style `/live|movie|series|timeshift/`
/// `user/pass/…` or bare `/user/pass/id` path segments.
library;

const _mask = '***';

final RegExp _credentialQueryKey = RegExp(
  r'(pass|pwd|token|key|secret|auth|sig|user|login|session|credential)',
  caseSensitive: false,
);

final RegExp _xtreamPrefixed = RegExp(
  r'^/(live|movie|movies|series|timeshift|streaming)/([^/]+)/([^/]+)(/.*)?$',
  caseSensitive: false,
);

final RegExp _xtreamBare = RegExp(
  r'^/([^/]+)/([^/]+)/(\d+(?:\.[A-Za-z0-9]+)?)$',
);

/// True when a query key or header name carries a credential.
bool isCredentialKey(String key) => _credentialQueryKey.hasMatch(key.trim());

/// Mask credentials in one URL (or raw path). Returns a non-URL input
/// unchanged except for a `user:pass@` prefix, which is still masked.
String redactUrlCredentials(String? raw) {
  final input = raw?.trim() ?? '';
  if (input.isEmpty) return '';
  final uri = Uri.tryParse(input);
  if (uri == null || !uri.hasScheme) {
    return _redactQueryText(_redactPathText(input));
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'magnet' || scheme == 'data' || scheme == 'javascript') {
    return '$scheme:$_mask';
  }
  final out = uri.replace(
    userInfo: uri.userInfo.isEmpty ? '' : _mask,
    path: _redactPathText(uri.path),
    query: uri.hasQuery ? _redactQuery(uri.query) : null,
    fragment: uri.hasFragment ? _mask : null,
  );
  return out.toString();
}

/// Masks credential values in a header map; names stay, values become
/// `(<n> chars)` for credential headers and the raw value otherwise.
Map<String, String> redactHeaderValues(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return const {};
  return {
    for (final e in headers.entries)
      e.key: _isSensitiveHeader(e.key)
          ? '($_mask ${e.value.length} chars)'
          : redactUrlCredentials(e.value),
  };
}

/// Header names only — for log lines that must not print any value.
String describeHeaderNames(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return '(none)';
  return headers.keys.join(', ');
}

bool _isSensitiveHeader(String name) {
  final n = name.trim().toLowerCase();
  return n == 'authorization' ||
      n == 'proxy-authorization' ||
      n == 'cookie' ||
      n == 'set-cookie' ||
      n == 'x-api-key' ||
      n.contains('token') ||
      n.contains('secret') ||
      n.contains('session');
}

String _redactQuery(String query) {
  if (query.isEmpty) return query;
  return query
      .split('&')
      .map((pair) {
        final eq = pair.indexOf('=');
        if (eq < 0) return pair;
        final key = pair.substring(0, eq);
        if (isCredentialKey(Uri.decodeQueryComponent(key))) {
          return '$key=$_mask';
        }
        return pair;
      })
      .join('&');
}

String _redactQueryText(String text) {
  final q = text.indexOf('?');
  if (q < 0) return text;
  return '${text.substring(0, q + 1)}${_redactQuery(text.substring(q + 1))}';
}

String _redactPathText(String path) {
  if (path.isEmpty) return path;
  final m1 = _xtreamPrefixed.firstMatch(path);
  if (m1 != null) {
    return '/${m1.group(1)}/$_mask/$_mask${m1.group(4) ?? ''}';
  }
  final m2 = _xtreamBare.firstMatch(path);
  if (m2 != null) {
    return '/$_mask/$_mask/${m2.group(3)}';
  }
  return path;
}
