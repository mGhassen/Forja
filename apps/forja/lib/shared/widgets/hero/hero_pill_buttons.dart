import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:google_fonts/google_fonts.dart';

const double _kHeroPillHeight = 40;
const double _kHeroPillIconSize = 20;
const Color _kHeroPillForegroundDark = Color(0xFF111827);

Color _heroPillHoverFill({required bool pressed}) =>
    Colors.white.withValues(alpha: pressed ? 0.24 : 0.18);

BoxDecoration _heroGlassDecoration() {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: 0.42),
    borderRadius: BorderRadius.circular(_kHeroPillHeight / 2),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.24),
    ),
  );
}

BoxDecoration _heroFilledDecoration({
  required Color color,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(_kHeroPillHeight / 2),
  );
}

BorderRadius _heroPillSlotBorderRadius({
  required bool isFirst,
  required bool isLast,
}) {
  const radius = Radius.circular(_kHeroPillHeight / 2);
  if (isFirst && isLast) return const BorderRadius.all(radius);
  if (isFirst) return const BorderRadius.horizontal(left: radius);
  if (isLast) return const BorderRadius.horizontal(right: radius);
  return BorderRadius.zero;
}

/// Hero CTA chrome — primary green, streaming white, secondary glass.
enum HeroPillPlayTone { primary, secondary, streaming }

class _HeroPillStyle {
  const _HeroPillStyle({
    required this.tone,
    required this.foreground,
    required this.compactIconColor,
    required this.expandedFill,
  });

  final HeroPillPlayTone tone;
  final Color foreground;
  final Color compactIconColor;
  final Color expandedFill;

  static _HeroPillStyle forTone(HeroPillPlayTone tone) {
    switch (tone) {
      case HeroPillPlayTone.primary:
        return const _HeroPillStyle(
          tone: HeroPillPlayTone.primary,
          foreground: _kHeroPillForegroundDark,
          compactIconColor: Colors.white,
          expandedFill: ForjaShellColors.brandGreen,
        );
      case HeroPillPlayTone.streaming:
        return const _HeroPillStyle(
          tone: HeroPillPlayTone.streaming,
          foreground: _kHeroPillForegroundDark,
          compactIconColor: Colors.white,
          expandedFill: Colors.white,
        );
      case HeroPillPlayTone.secondary:
        return const _HeroPillStyle(
          tone: HeroPillPlayTone.secondary,
          foreground: Colors.white,
          compactIconColor: Colors.white,
          expandedFill: Colors.transparent,
        );
    }
  }
}

_HeroPillStyle _styleForTone(HeroPillPlayTone tone) =>
    _HeroPillStyle.forTone(tone);

BoxDecoration _decorationFor({
  required _HeroPillStyle style,
  required double morph,
}) {
  if (style.tone == HeroPillPlayTone.secondary) {
    return _heroGlassDecoration();
  }
  final glass = _heroGlassDecoration();
  final filled = _heroFilledDecoration(color: style.expandedFill);
  if (morph <= 0) return glass;
  if (morph >= 1) return filled;
  return BoxDecoration.lerp(glass, filled, morph) ?? filled;
}

/// Primary hero CTA — pill with optional icon + label (Play, Watch Now, Resume).
class HeroPillPlayButton extends StatelessWidget {
  const HeroPillPlayButton({
    super.key,
    required this.label,
    this.icon = Icons.play_arrow_rounded,
    this.iconWidget,
    this.onTap,
    this.primary = true,
    this.tone,
    this.autoFocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.tvTabId,
    this.onUpEdge,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final bool primary;
  final HeroPillPlayTone? tone;
  final bool autoFocus;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final String? tvTabId;
  final VoidCallback? onUpEdge;

  HeroPillPlayTone get _tone =>
      tone ?? (primary ? HeroPillPlayTone.primary : HeroPillPlayTone.secondary);

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final resolvedTone = _tone;
    final style = _styleForTone(resolvedTone);
    final leading = iconWidget ??
        (icon != null ? Icon(icon, size: _kHeroPillIconSize) : null);
    final useTvCompact = policy.useFocusableMoodChips;
    final tvMeta = tvTabId != null && useTvCompact
        ? ShellTvFocusMeta(tabId: tvTabId!, zone: ShellTvZone.hero)
        : null;
    final effectiveOnKey = onUpEdge != null || onKeyEvent != null
        ? (FocusNode node, KeyEvent event) {
            if (onUpEdge != null) {
              final up = ShellTvFocus.onArrowUp(event, () {
                onUpEdge!();
                return true;
              });
              if (up == KeyEventResult.handled) return up;
            }
            return onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
          }
        : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: ForjaInteractive(
        onTap: onTap,
        autoFocus: autoFocus,
        focusNode: focusNode,
        onKeyEvent: effectiveOnKey,
        tvMeta: tvMeta,
        hoverScale: 1.03,
        pressScale: 0.97,
        builder: (active, pressed) {
          return _HeroPillPlaySurface(
            style: style,
            active: active,
            pressed: pressed,
            compact: useTvCompact && !active,
            useTvCompact: useTvCompact,
            label: label,
            leading: leading,
          );
        },
      ),
    );
  }
}

class _HeroPillPlaySurface extends StatefulWidget {
  const _HeroPillPlaySurface({
    required this.style,
    required this.active,
    required this.pressed,
    required this.compact,
    required this.useTvCompact,
    required this.label,
    required this.leading,
  });

  final _HeroPillStyle style;
  final bool active;
  final bool pressed;
  final bool compact;
  final bool useTvCompact;
  final String label;
  final Widget? leading;

  @override
  State<_HeroPillPlaySurface> createState() => _HeroPillPlaySurfaceState();
}

class _HeroPillPlaySurfaceState extends State<_HeroPillPlaySurface>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 480);

  late final AnimationController _controller;
  late final Animation<double> _expand;
  late final Animation<double> _labelOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
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
  void didUpdateWidget(covariant _HeroPillPlaySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact != oldWidget.compact ||
        widget.useTvCompact != oldWidget.useTvCompact) {
      _syncController(animate: true);
    }
  }

  void _syncController({required bool animate}) {
    final target = widget.useTvCompact && widget.compact ? 0.0 : 1.0;
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

  double get _morph =>
      widget.useTvCompact ? _expand.value : 1.0;

  Color _iconColor(double morph) {
    if (!widget.useTvCompact || morph >= 1) return widget.style.foreground;
    return Color.lerp(widget.style.compactIconColor, widget.style.foreground, morph) ??
        widget.style.foreground;
  }

  Widget _buildShell({
    required double morph,
    required double labelOpacity,
    required Widget child,
  }) {
    return Container(
      height: _kHeroPillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: _decorationFor(style: widget.style, morph: morph),
      foregroundDecoration: widget.active
          ? BoxDecoration(
              color: _heroPillHoverFill(pressed: widget.pressed),
              borderRadius: BorderRadius.circular(_kHeroPillHeight / 2),
            )
          : null,
      child: child,
    );
  }

  Widget _buildPillContent({
    required double morph,
    required double labelOpacity,
    required bool showLabel,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.useTvCompact ? _kHeroPillHeight : _kHeroPillIconSize,
          height: _kHeroPillHeight,
          child: Center(
            child: widget.leading == null
                ? null
                : IconTheme(
                    data: IconThemeData(
                      size: _kHeroPillIconSize,
                      color: _iconColor(morph),
                    ),
                    child: widget.leading!,
                  ),
          ),
        ),
        if (showLabel)
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: widget.useTvCompact ? morph : 1,
              child: Opacity(
                opacity: widget.useTvCompact ? labelOpacity : 1,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.useTvCompact ? 0 : 8,
                    right: 18,
                  ),
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
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
    if (!widget.useTvCompact) {
      return _buildShell(
        morph: 1,
        labelOpacity: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _buildPillContent(
            morph: 1,
            labelOpacity: 1,
            showLabel: true,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return _buildShell(
          morph: _morph,
          labelOpacity: _labelOpacity.value,
          child: _buildPillContent(
            morph: _morph,
            labelOpacity: _labelOpacity.value,
            showLabel: true,
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
    final resolvedSize = size ?? iconTheme.size ?? _kHeroPillIconSize;
    final resolvedColor = color ?? iconTheme.color ?? _kHeroPillForegroundDark;
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

class HeroPillIconSlot {
  const HeroPillIconSlot({
    this.icon,
    this.iconWidget,
    this.onTap,
    this.tooltip,
    this.label,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? label;

  String get resolvedLabel => label ?? tooltip ?? '';
}

/// Horizontal hero CTA cluster — ordered left→right on TV, no escape to catalog.
class HeroPillActionRow extends StatelessWidget {
  const HeroPillActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return row;
    }
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: row,
    );
  }
}

/// Secondary hero actions in one sliced glass pill — focused slot expands right.
class HeroPillIconGroup extends StatelessWidget {
  const HeroPillIconGroup({
    super.key,
    required this.slots,
    this.tvFocusOrderStart,
    this.tvTabId,
    this.onUpEdge,
  });

  final List<HeroPillIconSlot> slots;
  final int? tvFocusOrderStart;
  final String? tvTabId;
  final VoidCallback? onUpEdge;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();

    final useTvCompact = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    return Container(
      height: _kHeroPillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: _heroGlassDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 18,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            _HeroPillGroupedSlot(
              label: slots[i].resolvedLabel,
              icon: slots[i].icon,
              iconWidget: slots[i].iconWidget,
              onTap: slots[i].onTap,
              isFirst: i == 0,
              isLast: i == slots.length - 1,
              useTvCompact: useTvCompact,
              tvTabId: tvTabId,
              onUpEdge: onUpEdge,
              focusOrder: tvFocusOrderStart != null
                  ? NumericFocusOrder((tvFocusOrderStart! + i).toDouble())
                  : null,
              onKeyEvent: i == slots.length - 1
                  ? (node, event) => shellTrapTvFocusHorizontalEdge(
                        node,
                        event,
                        trapRight: true,
                      )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class HeroPillSegment<T> {
  const HeroPillSegment({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// Segmented hero pill (e.g. SUB | DUB) — glass shell, white hover on segment.
class HeroPillSegmentedChoice<T> extends StatelessWidget {
  const HeroPillSegmentedChoice({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  final List<HeroPillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      height: _kHeroPillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: _heroGlassDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 18,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            _HeroPillSegmentButton<T>(
              segment: segments[i],
              selected: segments[i].value == selected,
              isFirst: i == 0,
              isLast: i == segments.length - 1,
              onTap: () => onSelected(segments[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPillSegmentButton<T> extends StatelessWidget {
  const _HeroPillSegmentButton({
    required this.segment,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final HeroPillSegment<T> segment;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.55);

    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.03,
      pressScale: 0.97,
      builder: (hover, pressed) {
        final active = selected || hover || pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: _kHeroPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? _heroPillHoverFill(pressed: pressed)
                : Colors.transparent,
            borderRadius: _heroPillSlotBorderRadius(
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(segment.icon, size: _kHeroPillIconSize, color: foreground),
              const SizedBox(width: 6),
              Text(
                segment.label,
                style: GoogleFonts.inter(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroPillGroupedSlot extends StatelessWidget {
  const _HeroPillGroupedSlot({
    required this.label,
    required this.isFirst,
    required this.isLast,
    required this.useTvCompact,
    this.icon,
    this.iconWidget,
    this.onTap,
    this.focusOrder,
    this.onKeyEvent,
    this.tvTabId,
    this.onUpEdge,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool useTvCompact;
  final FocusOrder? focusOrder;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final String? tvTabId;
  final VoidCallback? onUpEdge;

  Widget _wrapOrder(Widget child) {
    final order = focusOrder;
    if (order == null) return child;
    return FocusTraversalOrder(order: order, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final tvMeta = tvTabId != null && useTvCompact
        ? ShellTvFocusMeta(tabId: tvTabId!, zone: ShellTvZone.hero)
        : null;
    final effectiveOnKey = onUpEdge != null || onKeyEvent != null
        ? (FocusNode node, KeyEvent event) {
            if (onUpEdge != null) {
              final up = ShellTvFocus.onArrowUp(event, () {
                onUpEdge!();
                return true;
              });
              if (up == KeyEventResult.handled) return up;
            }
            return onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
          }
        : null;

    return _wrapOrder(
      ForjaInteractive(
        onTap: onTap,
        onKeyEvent: effectiveOnKey,
        tvMeta: tvMeta,
        hoverScale: 1,
        pressScale: 1,
        builder: (active, pressed) {
          return _HeroPillGroupedSlotSurface(
            label: label,
            icon: icon,
            iconWidget: iconWidget,
            active: active,
            pressed: pressed,
            compact: useTvCompact && !active,
            useTvCompact: useTvCompact,
            isFirst: isFirst,
            isLast: isLast,
          );
        },
      ),
    );
  }
}

class _HeroPillGroupedSlotSurface extends StatefulWidget {
  const _HeroPillGroupedSlotSurface({
    required this.label,
    required this.active,
    required this.pressed,
    required this.compact,
    required this.useTvCompact,
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
  final bool useTvCompact;
  final bool isFirst;
  final bool isLast;

  @override
  State<_HeroPillGroupedSlotSurface> createState() =>
      _HeroPillGroupedSlotSurfaceState();
}

class _HeroPillGroupedSlotSurfaceState extends State<_HeroPillGroupedSlotSurface>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 480);

  late final AnimationController _controller;
  late final Animation<double> _expand;
  late final Animation<double> _labelOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
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
  void didUpdateWidget(covariant _HeroPillGroupedSlotSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact != oldWidget.compact ||
        widget.useTvCompact != oldWidget.useTvCompact) {
      _syncController(animate: true);
    }
  }

  void _syncController({required bool animate}) {
    final target = widget.useTvCompact && widget.compact ? 0.0 : 1.0;
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

  Widget? _leading() {
    return widget.iconWidget ??
        (widget.icon != null
            ? Icon(widget.icon, size: _kHeroPillIconSize, color: Colors.white)
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final leading = _leading();

    return SizedBox(
      height: _kHeroPillHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.active
                    ? _heroPillHoverFill(pressed: widget.pressed)
                    : Colors.transparent,
                borderRadius: _heroPillSlotBorderRadius(
                  isFirst: widget.isFirst,
                  isLast: widget.isLast,
                ),
              ),
            ),
          ),
          if (widget.useTvCompact)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return _groupedSlotRow(
                  leading: leading,
                  morph: _expand.value,
                  labelOpacity: _labelOpacity.value,
                );
              },
            )
          else
            SizedBox(
              width: _kHeroPillHeight,
              child: Center(child: leading),
            ),
        ],
      ),
    );
  }

  Widget _groupedSlotRow({
    required Widget? leading,
    required double morph,
    required double labelOpacity,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _kHeroPillHeight,
          height: _kHeroPillHeight,
          child: Center(child: leading),
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
                    style: GoogleFonts.inter(
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
    );
  }
}
