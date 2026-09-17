import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

const double kHeroPillHeight = DetailsTokens.heroPillHeight;
const double kHeroPillIconSize = DetailsTokens.heroPillIconSize;
const Color kHeroPillForegroundDark = Color(0xFF111827);

double heroPillHeightOf(BuildContext context, {bool? tvDensity}) {
  final tv = tvDensity ?? ShellPaintScope.usesTvDensityOf(context);
  return tv ? DetailsTokens.heroPillHeightTv : DetailsTokens.heroPillHeight;
}

double heroPillIconSizeOf(BuildContext context, {bool? tvDensity}) {
  final tv = tvDensity ?? ShellPaintScope.usesTvDensityOf(context);
  return tv ? DetailsTokens.heroPillIconSizeTv : DetailsTokens.heroPillIconSize;
}

Color heroPillHoverFill({required bool pressed}) =>
    Colors.white.withValues(alpha: pressed ? 0.24 : 0.18);

BoxDecoration heroGlassDecoration(BuildContext context, {bool? tvDensity}) {
  final height = heroPillHeightOf(context, tvDensity: tvDensity);
  return BoxDecoration(
    color: Colors.black.withValues(alpha: 0.42),
    borderRadius: BorderRadius.circular(height / 2),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.24),
    ),
  );
}

BoxDecoration heroFilledDecoration(
  BuildContext context, {
  required Color color,
  bool? tvDensity,
}) {
  final height = heroPillHeightOf(context, tvDensity: tvDensity);
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(height / 2),
  );
}

BorderRadius heroPillSlotBorderRadius(
  BuildContext context, {
  required bool isFirst,
  required bool isLast,
  bool? tvDensity,
}) {
  final radius = Radius.circular(heroPillHeightOf(context, tvDensity: tvDensity) / 2);
  if (isFirst && isLast) return const BorderRadius.all(radius);
  if (isFirst) return const BorderRadius.horizontal(left: radius);
  if (isLast) return const BorderRadius.horizontal(right: radius);
  return BorderRadius.zero;
}

/// Hero CTA chrome - primary green, streaming white, secondary glass.
enum HeroPillPlayTone { primary, secondary, streaming }

class HeroPillStyle {
  const HeroPillStyle({
    required this.tone,
    required this.foreground,
    required this.compactIconColor,
    required this.expandedFill,
  });

  final HeroPillPlayTone tone;
  final Color foreground;
  final Color compactIconColor;
  final Color expandedFill;

  static HeroPillStyle forTone(HeroPillPlayTone tone) {
    switch (tone) {
      case HeroPillPlayTone.primary:
        return const HeroPillStyle(
          tone: HeroPillPlayTone.primary,
          foreground: kHeroPillForegroundDark,
          compactIconColor: Colors.white,
          expandedFill: ForjaShellColors.brandGreen,
        );
      case HeroPillPlayTone.streaming:
        return const HeroPillStyle(
          tone: HeroPillPlayTone.streaming,
          foreground: kHeroPillForegroundDark,
          compactIconColor: Colors.white,
          expandedFill: Colors.white,
        );
      case HeroPillPlayTone.secondary:
        return const HeroPillStyle(
          tone: HeroPillPlayTone.secondary,
          foreground: Colors.white,
          compactIconColor: Colors.white,
          expandedFill: Colors.transparent,
        );
    }
  }

  BoxDecoration decoration(BuildContext context, {bool? tvDensity}) {
    if (tone == HeroPillPlayTone.secondary) {
      return heroGlassDecoration(context, tvDensity: tvDensity);
    }
    return heroFilledDecoration(
      context,
      color: expandedFill,
      tvDensity: tvDensity,
    );
  }
}

class HeroPillGlassShell extends StatelessWidget {
  const HeroPillGlassShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pillHeight = heroPillHeightOf(context);
    return Container(
      height: pillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: heroGlassDecoration(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class HeroPillSlotDivider extends StatelessWidget {
  const HeroPillSlotDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white.withValues(alpha: 0.22),
    );
  }
}

/// Expanding play CTA paint. Host wraps with [ForjaInteractive].
class HeroPillPlaySurface extends StatefulWidget {
  const HeroPillPlaySurface({
    super.key,
    required this.style,
    required this.active,
    required this.pressed,
    required this.expanded,
    required this.label,
    required this.leading,
  });

  final HeroPillStyle style;
  final bool active;
  final bool pressed;
  final bool expanded;
  final String label;
  final Widget? leading;

  @override
  State<HeroPillPlaySurface> createState() => _HeroPillPlaySurfaceState();
}

class _HeroPillPlaySurfaceState extends State<HeroPillPlaySurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;
  late final Animation<double> _labelOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ForjaMotionTheme.defaults.heroPillExpand.duration,
    );
    _expand = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: Curves.easeOutCubic),
    );
    _labelOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.9, curve: Curves.easeOut),
    );
    _syncController(animate: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final d = ForjaMotionTheme.of(context).heroPillExpand.duration;
    if (_controller.duration != d) _controller.duration = d;
  }

  @override
  void didUpdateWidget(covariant HeroPillPlaySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _syncController(animate: true);
    }
  }

  void _syncController({required bool animate}) {
    final target = widget.expanded ? 1.0 : 0.0;
    if (!animate) {
      _controller.value = target;
      return;
    }
    if (target == 0) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    final pillHeight = heroPillHeightOf(context);
    return Container(
      height: pillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: widget.style.decoration(context),
      foregroundDecoration: widget.active
          ? BoxDecoration(
              color: heroPillHoverFill(pressed: widget.pressed),
              borderRadius: BorderRadius.circular(pillHeight / 2),
            )
          : null,
      child: child,
    );
  }

  Widget _buildPillContent(
    BuildContext context, {
    required double morph,
    required double labelOpacity,
  }) {
    final pillHeight = heroPillHeightOf(context);
    final iconSize = heroPillIconSizeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: pillHeight,
          height: pillHeight,
          child: Center(
            child: widget.leading == null
                ? null
                : IconTheme(
                    data: IconThemeData(
                      size: iconSize,
                      color: widget.style.foreground,
                    ),
                    child: widget.leading!,
                  ),
          ),
        ),
        if (widget.label.isNotEmpty)
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: morph,
              child: Opacity(
                opacity: labelOpacity,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: GoogleFonts.plusJakartaSans(
                      color: widget.style.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return _buildShell(
          context,
          child: _buildPillContent(
            context,
            morph: _expand.value,
            labelOpacity: _labelOpacity.value,
          ),
        );
      },
    );
  }
}

/// Simple magnet glyph for torrent CTAs (Material Icons has no magnet).
class HeroMagnetIcon extends StatelessWidget {
  const HeroMagnetIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? kHeroPillIconSize;
    final resolvedColor = color ?? iconTheme.color ?? kHeroPillForegroundDark;
    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: CustomPaint(
        painter: _MagnetIconPainter(color: resolvedColor),
      ),
    );
  }
}

class _MagnetIconPainter extends CustomPainter {
  _MagnetIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.16;
    final bottom = h * 0.86;
    final left = w * 0.28;
    final right = w * 0.72;
    final midY = top + (bottom - top) * 0.52;
    final tipH = h * 0.14;
    final tipW = w * 0.18;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(left, top + tipH * 0.35)
      ..lineTo(left, midY)
      ..cubicTo(left, bottom, right, bottom, right, midY)
      ..lineTo(right, top + tipH * 0.35);
    canvas.drawPath(path, stroke);

    final tip = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(left, top + tipH * 0.35),
          width: tipW,
          height: tipH,
        ),
        Radius.circular(w * 0.04),
      ),
      tip,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(right, top + tipH * 0.35),
          width: tipW,
          height: tipH,
        ),
        Radius.circular(w * 0.04),
      ),
      tip,
    );
  }

  @override
  bool shouldRepaint(covariant _MagnetIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class HeroPillGroupedSlotSurface extends StatefulWidget {
  const HeroPillGroupedSlotSurface({
    super.key,
    required this.label,
    required this.active,
    required this.pressed,
    required this.compact,
    required this.isFirst,
    required this.isLast,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool active;
  final bool pressed;
  final bool compact;
  final bool isFirst;
  final bool isLast;

  @override
  State<HeroPillGroupedSlotSurface> createState() =>
      _HeroPillGroupedSlotSurfaceState();
}

class _HeroPillGroupedSlotSurfaceState extends State<HeroPillGroupedSlotSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;
  late final Animation<double> _labelOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ForjaMotionTheme.defaults.heroPillLabel.duration,
    );
    _expand = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: Curves.easeOutCubic),
    );
    _labelOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
    );
    _syncController(animate: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final d = ForjaMotionTheme.of(context).heroPillLabel.duration;
    if (_controller.duration != d) _controller.duration = d;
  }

  @override
  void didUpdateWidget(covariant HeroPillGroupedSlotSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact != oldWidget.compact) {
      _syncController(animate: true);
    }
  }

  void _syncController({required bool animate}) {
    final target = widget.compact ? 0.0 : 1.0;
    if (!animate) {
      _controller.value = target;
      return;
    }
    if (target == 0) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget? _leading(BuildContext context) {
    final iconSize = heroPillIconSizeOf(context);
    return widget.iconWidget ??
        (widget.icon != null
            ? Icon(widget.icon, size: iconSize, color: Colors.white)
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final pillHeight = heroPillHeightOf(context);
    final iconSize = heroPillIconSizeOf(context);
    final leading = _leading(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: pillHeight,
          decoration: BoxDecoration(
            color: widget.active
                ? heroPillHoverFill(pressed: widget.pressed)
                : Colors.transparent,
            borderRadius: heroPillSlotBorderRadius(
              context,
              isFirst: widget.isFirst,
              isLast: widget.isLast,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: pillHeight,
                height: pillHeight,
                child: Center(
                  child: leading == null
                      ? null
                      : IconTheme(
                          data: IconThemeData(
                            size: iconSize,
                            color: Colors.white,
                          ),
                          child: leading,
                        ),
                ),
              ),
              if (widget.label.isNotEmpty)
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _expand.value,
                    child: Opacity(
                      opacity: _labelOpacity.value,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class HeroPillSegmentSurface extends StatelessWidget {
  const HeroPillSegmentSurface({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.lit,
    required this.pressed,
    required this.isFirst,
    required this.isLast,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool lit;
  final bool pressed;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final pillHeight = heroPillHeightOf(context);
    final iconSize = heroPillIconSizeOf(context);
    final foreground = lit || selected
        ? ForjaShellColors.brandGreen
        : Colors.white.withValues(alpha: 0.55);
    return AnimatedContainer(
      duration: ForjaMotionTheme.of(context).heroPillHover.duration,
      curve: ForjaMotionTheme.of(context).heroPillHover.resolvedCurve,
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lit
            ? ForjaShellColors.brandGreen
                .withValues(alpha: pressed ? 0.28 : 0.18)
            : Colors.transparent,
        borderRadius: heroPillSlotBorderRadius(
          context,
          isFirst: isFirst,
          isLast: isLast,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
