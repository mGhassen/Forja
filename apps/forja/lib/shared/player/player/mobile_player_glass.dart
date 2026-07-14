part of 'mobile_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FLAT PLAYER CHROME SURFACES  (RFC-026 R26-C06 — no glass / BackdropFilter)
// ─────────────────────────────────────────────────────────────────────────────

/// Flat elevated surface for transient player chrome (seek tooltip, volume pill).
class _PlayerChromeSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  const _PlayerChromeSurface({
    required this.child,
    this.radius = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HARDWARE DECODE MODE  (3-mode cycle)
// ─────────────────────────────────────────────────────────────────────────────

enum _HwDecMode { autoSafe, autoCopy, software }

extension _HwDecModeX on _HwDecMode {
  /// The mpv property value for this mode.
  String get mpvValue => switch (this) {
    _HwDecMode.autoSafe => 'auto-safe',
    _HwDecMode.autoCopy => 'auto-copy',
    _HwDecMode.software => 'no',
  };

  /// Short label shown on the badge pill.
  String get label => switch (this) {
    _HwDecMode.autoSafe => 'HW+',
    _HwDecMode.autoCopy => 'COPY',
    _HwDecMode.software => 'SW',
  };

  String get description => switch (this) {
    _HwDecMode.autoSafe => 'Hardware Decoding: ON (GPU, safe)',
    _HwDecMode.autoCopy => 'Hardware Decoding: ON (copy-back)',
    _HwDecMode.software => 'Hardware Decoding: OFF (CPU)',
  };
}
