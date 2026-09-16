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
    this.turnedOn = const [],
    this.turnedOff = const [],
  });

  static const empty = LeanApplyResult();

  final List<LeanPackDelta> added;
  final List<LeanPackDelta> removed;

  /// Existing packs whose master switch flipped to on from cloud.
  final List<LeanPackDelta> turnedOn;

  /// Existing packs whose master switch flipped to off from cloud.
  final List<LeanPackDelta> turnedOff;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      turnedOn.isEmpty &&
      turnedOff.isEmpty;
}
