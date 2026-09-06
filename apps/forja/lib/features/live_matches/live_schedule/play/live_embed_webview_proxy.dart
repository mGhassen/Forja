/// Turn relative playlist lines / URI="…" into absolute URLs.
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
      out.writeln(
        line.replaceAllMapped(
          RegExp(r'URI="([^"]+)"', caseSensitive: false),
          (m) {
            final rawUri = m.group(1) ?? '';
            if (rawUri.isEmpty ||
                rawUri.startsWith('http://') ||
                rawUri.startsWith('https://') ||
                rawUri.startsWith('data:')) {
              return m.group(0)!;
            }
            return 'URI="${base.resolve(rawUri)}"';
          },
        ),
      );
      continue;
    }
    out.writeln(base.resolve(trimmed).toString());
  }
  return out.toString();
}

/// After absolutes: point every `http(s)` media URI at the local WebView proxy.
String liveEmbedRewriteM3u8ThroughProxy(
  String body, {
  required String proxyPrefix,
}) {
  String wrap(String raw) {
    final t = raw.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) {
      return '$proxyPrefix${Uri.encodeComponent(t)}';
    }
    return raw;
  }

  final out = StringBuffer();
  for (final raw in body.split('\n')) {
    final line = raw.replaceAll('\r', '');
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      out.writeln(line);
      continue;
    }
    if (trimmed.startsWith('#')) {
      out.writeln(
        line.replaceAllMapped(
          RegExp(r'URI="([^"]+)"', caseSensitive: false),
          (m) {
            final u = m.group(1) ?? '';
            if (u.startsWith('http://') || u.startsWith('https://')) {
              return 'URI="${wrap(u)}"';
            }
            return m.group(0)!;
          },
        ),
      );
      continue;
    }
    out.writeln(wrap(trimmed));
  }
  return out.toString();
}
