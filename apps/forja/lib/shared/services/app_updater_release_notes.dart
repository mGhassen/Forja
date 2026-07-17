/// Pure helpers for aggregating GitHub Release bodies between the installed
/// version and the latest. Used by [AppUpdaterService] and unit-tested without
/// HTTP.
class AppUpdaterReleaseNotes {
  AppUpdaterReleaseNotes._();

  static final _fullChangelogOnly = RegExp(
    r'^\s*Full Changelog:\s*\S+\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  static final _leadingH1 = RegExp(r'^#\s+[^\n]+\n*');

  /// True when [candidate] is strictly newer than [current] (semver triple).
  static bool isNewerVersion(String current, String candidate) {
    final currentParts = _semverParts(current);
    final candidateParts = _semverParts(candidate);

    for (var i = 0; i < 3; i++) {
      final a = i < currentParts.length ? currentParts[i] : 0;
      final b = i < candidateParts.length ? candidateParts[i] : 0;
      if (b > a) return true;
      if (b < a) return false;
    }
    return false;
  }

  /// Compare two semver strings: negative if [a] < [b], 0 if equal, positive if [a] > [b].
  static int compareVersions(String a, String b) {
    final aParts = _semverParts(a);
    final bParts = _semverParts(b);
    for (var i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  /// Strip GitHub auto "Full Changelog" lines and a leading `# Title` H1.
  /// Returns empty when nothing user-facing remains.
  static String cleanBody(String? raw) {
    if (raw == null) return '';
    var text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return '';

    text = text.replaceAll(_fullChangelogOnly, '').trim();
    if (text.isEmpty) return '';

    // Drop a single leading H1 (release title); we re-add version headers when
    // aggregating multiple releases.
    if (text.startsWith('# ') && !text.startsWith('##')) {
      text = text.replaceFirst(_leadingH1, '').trim();
    }

    // Ignore bodies that only have headings and no bullets.
    final hasBullet = text
        .split('\n')
        .any((line) => RegExp(r'^[-*•]\s+').hasMatch(line.trim()));
    if (!hasBullet) return '';

    return text;
  }

  /// Build dialog markdown for every stable release newer than [currentVersion].
  ///
  /// Newest first. Skips drafts, prereleases, and empty/auto-only bodies.
  /// When more than one version contributes notes, each block is prefixed with
  /// `# X.Y.Z`. A single contributing release keeps its cleaned body without an
  /// extra version H1 (dialog already shows the target version).
  static String aggregate({
    required String currentVersion,
    required List<ReleaseNotesEntry> releases,
  }) {
    final newer = releases
        .where((r) => !r.draft && !r.prerelease)
        .where((r) => isNewerVersion(currentVersion, r.version))
        .toList()
      ..sort((a, b) => compareVersions(b.version, a.version));

    final blocks = <({String version, String body})>[];
    for (final release in newer) {
      final cleaned = cleanBody(release.body);
      if (cleaned.isEmpty) continue;
      blocks.add((version: release.version, body: cleaned));
    }

    if (blocks.isEmpty) return '';

    if (blocks.length == 1) {
      return blocks.first.body;
    }

    return blocks
        .map((b) => '# ${b.version}\n\n${b.body}')
        .join('\n\n');
  }

  static List<int> _semverParts(String version) {
    final core = version.split('+').first.split('-').first;
    return core
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
  }
}

class ReleaseNotesEntry {
  const ReleaseNotesEntry({
    required this.version,
    required this.body,
    this.prerelease = false,
    this.draft = false,
  });

  final String version;
  final String? body;
  final bool prerelease;
  final bool draft;
}
