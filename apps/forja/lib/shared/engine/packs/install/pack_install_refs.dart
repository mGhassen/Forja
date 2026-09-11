/// Split a pasted Add-pack blob into distinct manifest URLs / local paths.
///
/// Accepts newlines, commas, semicolons, and (when paste flattens newlines)
/// space-separated absolute paths / `http(s):` / `file://` tokens.
List<String> parsePackInstallRefs(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  final pieces = <String>[];
  for (final line in trimmed.split(RegExp(r'[\r\n]+'))) {
    for (final piece in line.split(RegExp(r'[,;]+'))) {
      final t = piece.trim();
      if (t.isEmpty) continue;
      pieces.add(t);
    }
  }

  final tokens = pieces.length == 1 ? _extractPathLikeTokens(pieces.first) : pieces;
  final out = <String>[];
  final seen = <String>{};
  for (final token in tokens) {
    final normalized = normalizePackInstallRef(token);
    if (normalized == null || !seen.add(normalized)) continue;
    out.add(normalized);
  }
  return out;
}

/// Trim quotes and map a local pack folder to `…/manifest.json`.
String? normalizePackInstallRef(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return null;
  if ((t.startsWith('"') && t.endsWith('"')) ||
      (t.startsWith("'") && t.endsWith("'"))) {
    t = t.substring(1, t.length - 1).trim();
  }
  if (t.isEmpty) return null;

  if (_looksLikeLocalCheckout(t) && !_endsWithManifestJson(t)) {
    while (t.endsWith('/') || t.endsWith(r'\')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.isEmpty) return null;
    final sep = t.startsWith('file://')
        ? '/'
        : (t.contains(r'\') && !t.contains('/'))
            ? r'\'
            : '/';
    t = '$t${sep}manifest.json';
  }
  return t;
}

/// Short label for the install picker (folder / last path segment).
String packInstallRefDisplayName(String ref) {
  var t = ref.trim();
  if (t.isEmpty) return ref;
  final lower = t.toLowerCase();
  if (lower.endsWith('/manifest.json') || lower.endsWith(r'\manifest.json')) {
    t = t.substring(0, t.length - 'manifest.json'.length - 1);
  } else if (lower.endsWith('manifest.json') && t.length > 'manifest.json'.length) {
    t = t.substring(0, t.length - 'manifest.json'.length);
  }
  while (t.endsWith('/') || t.endsWith(r'\')) {
    t = t.substring(0, t.length - 1);
  }
  final slash = t.contains('/') ? t.lastIndexOf('/') : -1;
  final back = t.contains(r'\') ? t.lastIndexOf(r'\') : -1;
  final i = slash > back ? slash : back;
  if (i >= 0 && i < t.length - 1) return t.substring(i + 1);
  return t;
}

List<String> _extractPathLikeTokens(String blob) {
  final re = RegExp(
    r'''(?:https?://[^\s,;]+|file://[^\s,;]+|/[^\s,;]+|[A-Za-z]:\\[^\s,;]+)''',
  );
  final matches = re.allMatches(blob).map((m) => m.group(0)!.trim()).toList();
  if (matches.length > 1) return matches;
  return [blob];
}

bool _looksLikeLocalCheckout(String t) {
  if (t.startsWith('file://')) return true;
  if (t.startsWith('/')) return true;
  if (RegExp(r'^[A-Za-z]:\\').hasMatch(t)) return true;
  return false;
}

bool _endsWithManifestJson(String t) {
  final lower = t.toLowerCase();
  return lower.endsWith('/manifest.json') ||
      lower.endsWith(r'\manifest.json') ||
      lower.endsWith('manifest.json');
}
