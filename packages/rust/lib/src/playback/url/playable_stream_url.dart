/// Stream address allowlist shared by the resolver, the sources probe, the
/// Android player bridge, and the external player launcher.
///
/// Allowed: `http://` / `https://` (any host, so LAN and loopback servers
/// work), and `file://` only under a registered local media root (the
/// downloads folder). Everything else — `content:`, `intent:`, `javascript:`,
/// `data:`, `rtmp:`, bare paths — is refused. Pure function; no I/O.
library;

/// A stream address outside the allowlist reached a player. User-facing
/// [message]; the player surfaces it as-is.
class UnsupportedStreamAddressException implements Exception {
  const UnsupportedStreamAddressException(this.url);

  final String url;

  String get message => 'Unsupported stream address';

  @override
  String toString() => message;
}

/// Local folders whose files may be opened as `file://` streams.
///
/// The host registers the downloads folder at boot and again when the user
/// picks a custom one. Empty set → no `file://` stream is playable.
abstract final class PlayableStreamFileRoots {
  static final Set<String> _roots = <String>{};

  static Iterable<String> get roots => _roots;

  static void set(Iterable<String> paths) {
    _roots
      ..clear()
      ..addAll(paths.map(_normalizeDir).where((p) => p.isNotEmpty));
  }

  static void add(String path) {
    final n = _normalizeDir(path);
    if (n.isNotEmpty) _roots.add(n);
  }

  static void clear() => _roots.clear();

  static String _normalizeDir(String raw) {
    var t = raw.trim().replaceAll('\\', '/');
    if (t.isEmpty) return '';
    while (t.length > 1 && t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }
}

bool _isLoopbackHost(String host) {
  final h = host.toLowerCase();
  return h == '127.0.0.1' || h == 'localhost' || h == '::1' || h == '[::1]';
}

/// True when [url] is a loopback `http://` address (local proxy / torrent /
/// LAN relay). Any port.
bool isLoopbackStreamUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  return _isLoopbackHost(uri.host);
}

/// Absolute file path for a `file://` URL, or `null`.
String? _filePathOf(Uri uri) {
  try {
    final path = uri.toFilePath(windows: false);
    return path.isEmpty ? null : path;
  } catch (_) {
    try {
      final path = uri.toFilePath(windows: true);
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }
}

/// Collapse `.`/`..` segments so `downloads/../etc/passwd` is judged by where
/// it actually lands.
String _normalizePath(String raw) {
  final windows = RegExp(r'^[A-Za-z]:').hasMatch(raw);
  final unified = raw.replaceAll('\\', '/');
  final out = <String>[];
  for (final seg in unified.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(seg);
  }
  final joined = out.join('/');
  if (windows) return joined;
  return '/$joined';
}

bool _isUnderRoot(String path, String root) {
  final p = _normalizePath(path);
  final r = _normalizePath(root);
  if (r == '/' || r.isEmpty) return false;
  if (p == r) return false; // a directory itself is not a stream
  return p.startsWith('$r/');
}

/// Whether a player may open [url].
///
/// [allowedFileRoots] defaults to [PlayableStreamFileRoots.roots].
bool isPlayableStreamUrl(String? url, {Iterable<String>? allowedFileRoots}) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return false;
  switch (uri.scheme.toLowerCase()) {
    case 'http':
    case 'https':
      return uri.host.isNotEmpty;
    case 'file':
      final path = _filePathOf(uri);
      if (path == null) return false;
      final roots = allowedFileRoots ?? PlayableStreamFileRoots.roots;
      for (final root in roots) {
        if (_isUnderRoot(path, root)) return true;
      }
      return false;
    default:
      return false;
  }
}

/// Throws [UnsupportedStreamAddressException] when [url] is not playable.
void assertPlayableStreamUrl(String url, {Iterable<String>? allowedFileRoots}) {
  if (!isPlayableStreamUrl(url, allowedFileRoots: allowedFileRoots)) {
    throw UnsupportedStreamAddressException(url);
  }
}
