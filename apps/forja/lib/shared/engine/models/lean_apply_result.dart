/// Diff from a cloud lean apply (profile pack list vs device).
class LeanPackDelta {
  const LeanPackDelta({required this.manifestUrl, this.name});

  final String manifestUrl;
  final String? name;
}

class LeanApplyResult {
  const LeanApplyResult({
    this.added = const [],
    this.removed = const [],
  });

  static const empty = LeanApplyResult();

  final List<LeanPackDelta> added;
  final List<LeanPackDelta> removed;

  bool get isEmpty => added.isEmpty && removed.isEmpty;
}
