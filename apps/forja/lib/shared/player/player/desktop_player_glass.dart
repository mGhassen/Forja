part of 'desktop_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLASSY WIDGET PRIMITIVES  (MPVEx-style frosted black glass)
// ─────────────────────────────────────────────────────────────────────────────

/// A rounded glassy container – the visual base for every button / chip.
/// [hovered] brightens the glass slightly for Windows hover feedback.
class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool hovered;

  const _Glass({
    required this.child,
    this.radius = 12,
    this.padding,
    this.tint,
    this.hovered = false,
  });

  @override
  Widget build(BuildContext context) {
    // Base fill: 0.55 so the glass reads clearly even on pure black.
    // On hover bump to 0.72 for a crisp lift effect.
    final fillOpacity = hovered ? 0.72 : 0.55;
    final borderOpacity = hovered ? 0.30 : 0.16;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (tint ?? const Color(0xFF1C1C1E)).withValues(alpha: fillOpacity),
              (tint ?? Colors.black).withValues(alpha: fillOpacity - 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? 0.55 : 0.35),
              blurRadius: hovered ? 12 : 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Glassy icon button with hover + press feedback (Windows-friendly).
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool active;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 18,
    this.iconColor,
    this.active = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _tint {
    if (widget.active) return const Color(0xFF6A0DAD);
    if (_pressed) return const Color(0xFF2A2A2E);
    return const Color(0xFF1C1C1E);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: _Glass(
            radius: widget.size / 2,
            tint: _tint,
            hovered: _hovered,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color:
                    widget.iconColor ??
                    (widget.active
                        ? Colors.white
                        : _hovered
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.80)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassy pill / chip button with hover + press feedback.
class GlassPillButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color? accent;

  const GlassPillButton({
    super.key,
    required this.text,
    required this.onTap,
    this.accent,
  });

  @override
  State<GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<GlassPillButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: _Glass(
            radius: 20,
            tint: widget.accent ?? const Color(0xFF1C1C1E),
            hovered: _hovered,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.accent != null
                    ? Colors.white
                    : _hovered
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Center play/pause big button with hover + press feedback.
class _GlassPlayPause extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  const _GlassPlayPause({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  @override
  State<_GlassPlayPause> createState() => _GlassPlayPauseState();
}

class _GlassPlayPauseState extends State<_GlassPlayPause> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isBuffering) {
      return _Glass(
        radius: 40,
        hovered: false,
        child: const SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : (_hovered ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 100),
          child: _Glass(
            radius: 40,
            hovered: _hovered,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Icon(
                widget.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient overlay at top or bottom of the video
class _OverlayGradient extends StatelessWidget {
  final bool isTop;
  const _OverlayGradient({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HARDWARE DECODE MODE
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

  _HwDecMode get next => switch (this) {
    _HwDecMode.autoSafe => _HwDecMode.autoCopy,
    _HwDecMode.autoCopy => _HwDecMode.software,
    _HwDecMode.software => _HwDecMode.autoSafe,
  };

  Color get accent => switch (this) {
    _HwDecMode.autoSafe => const Color(0xFF7C3AED),
    _HwDecMode.autoCopy => const Color(0xFF0EA5E9),
    _HwDecMode.software => Colors.white24,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  DESKTOP PLAYER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

