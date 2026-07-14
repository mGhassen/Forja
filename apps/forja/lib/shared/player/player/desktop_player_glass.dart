part of 'desktop_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HARDWARE DECODE MODE  (RFC-026 R26-C06 — flat chrome; glass primitives removed)
// ─────────────────────────────────────────────────────────────────────────────

enum _HwDecMode {
  /// auto-safe: whitelisted GPU decoders, safe fallback chain. Best for most users.
  autoSafe,

  /// auto-copy: GPU decodes → copies back to RAM. Compatible with video filters.
  autoCopy,

  /// no: pure software/CPU decoding. Always works, highest CPU, most compatible.
  software,
}

extension _HwDecModeX on _HwDecMode {
  String get mpvValue => switch (this) {
    _HwDecMode.autoSafe => 'auto-safe',
    _HwDecMode.autoCopy => 'auto-copy',
    _HwDecMode.software => 'no',
  };

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
