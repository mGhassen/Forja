part of 'desktop_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HARDWARE DECODE MODE  (RFC-026 R26-C06 - flat chrome; glass primitives removed)
// ─────────────────────────────────────────────────────────────────────────────

enum _HwDecMode {
  /// auto-safe: whitelisted GPU decoders, safe fallback chain. Best for most users.
  autoSafe,

  /// auto-copy: GPU decodes → copies back to RAM. Compatible with video filters.
  autoCopy,

  /// no: CPU decode + soft texture (TextureSW). Highest CPU; clears HW chroma glitches.
  software,
}

extension _HwDecModeX on _HwDecMode {
  String get mpvValue => switch (this) {
    _HwDecMode.autoSafe => 'auto-safe',
    _HwDecMode.autoCopy => 'auto-copy',
    _HwDecMode.software => 'no',
  };

  /// media_kit TextureHW vs TextureSW — SW must flip this, not only `hwdec`.
  /// macOS TextureHW (TextureGL) mis-maps chroma on some streams → pink/green;
  /// same soft display as desktop PiP.
  bool get enableHardwareAcceleration {
    if (Platform.isMacOS) return false;
    return this != _HwDecMode.software;
  }

  bool get softTexture => !enableHardwareAcceleration;

  String get label => switch (this) {
    _HwDecMode.autoSafe => 'HW+',
    _HwDecMode.autoCopy => 'COPY',
    _HwDecMode.software => 'SW',
  };

  String get description => switch (this) {
    _HwDecMode.autoSafe => 'Hardware Decoding: ON (GPU, safe)',
    _HwDecMode.autoCopy => 'Hardware Decoding: ON (copy-back)',
    _HwDecMode.software => 'Software decode + soft display (CPU)',
  };

  /// With soft TextureSW, `auto-safe` zero-copy is useless — use copy-back.
  String get effectiveHwdec {
    if (softTexture && this == _HwDecMode.autoSafe) return 'auto-copy';
    return mpvValue;
  }

  VideoControllerConfiguration get videoControllerConfiguration =>
      VideoControllerConfiguration(
        enableHardwareAcceleration: enableHardwareAcceleration,
        hwdec: effectiveHwdec,
      );
}
