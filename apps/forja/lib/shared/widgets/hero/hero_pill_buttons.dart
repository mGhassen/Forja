import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:google_fonts/google_fonts.dart';

const double _kHeroPillHeight = 40;
const double _kHeroPillIconSize = 20;

Color _heroPillSlotActiveFill({required bool pressed}) =>
    Colors.white.withValues(alpha: pressed ? 0.24 : 0.18);

BoxDecoration _heroPillDecoration({required bool hover}) {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: hover ? 0.62 : 0.42),
    borderRadius: BorderRadius.circular(_kHeroPillHeight / 2),
    border: Border.all(
      color: Colors.white.withValues(alpha: hover ? 0.48 : 0.24),
    ),
  );
}

BoxDecoration _heroPlayDecoration({
  required bool hover,
  required Color color,
}) {
  return BoxDecoration(
    color: hover ? color.withValues(alpha: 0.92) : color,
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

/// Hero play CTA tone — [primary] brand green, [streaming] white fill.
enum HeroPillPlayTone { primary, secondary, streaming }

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

  HeroPillPlayTone get _tone =>
      tone ?? (primary ? HeroPillPlayTone.primary : HeroPillPlayTone.secondary);

  bool _tvCompactUnfocused(ShellInputPolicy policy, bool focused) {
    if (!policy.useFocusableMoodChips || focused) return false;
    return _tone == HeroPillPlayTone.primary ||
        _tone == HeroPillPlayTone.streaming;
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final resolved = _tone;
    final Color foreground;
    late final BoxDecoration Function(bool hover) decoration;
    switch (resolved) {
      case HeroPillPlayTone.primary:
        foreground = const Color(0xFF111827);
        decoration = (hover) => _heroPlayDecoration(
              hover: hover,
              color: ForjaShellColors.brandGreen,
            );
      case HeroPillPlayTone.streaming:
        foreground = const Color(0xFF111827);
        decoration = (hover) => _heroPlayDecoration(
              hover: hover,
              color: Colors.white,
            );
      case HeroPillPlayTone.secondary:
        foreground = Colors.white;
        decoration = (hover) => _heroPillDecoration(hover: hover);
    }

    final leading = iconWidget ??
        (icon != null
            ? Icon(icon, size: _kHeroPillIconSize, color: foreground)
            : null);

    return ForjaInteractive(
      onTap: onTap,
      autoFocus: autoFocus,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      hoverScale: 1.03,
      pressScale: 0.97,
      builder: (focused, pressed) {
        final compact = _tvCompactUnfocused(policy, focused);

        if (compact) {
          final compactIcon = iconWidget ??
              (icon != null
                  ? Icon(icon, size: _kHeroPillIconSize, color: Colors.white)
                  : null);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: _kHeroPillHeight,
            height: _kHeroPillHeight,
            decoration: _heroPillDecoration(hover: false),
            alignment: Alignment.center,
            child: compactIcon,
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: _kHeroPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: decoration(focused),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                SizedBox(
                  width: _kHeroPillIconSize,
                  height: _kHeroPillIconSize,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(
                        size: _kHeroPillIconSize,
                        color: foreground,
                      ),
                      child: leading,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  height: 1.0,
                ),
              ),
            ],
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
    final resolvedColor = color ?? iconTheme.color ?? Colors.black;
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
    // Keep the horseshoe optically centered in the icon box.
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
    this.onTap,
    this.tooltip,
    this.child,
  });

  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget? child;
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

/// Secondary hero actions grouped in one pill (info | add, etc.).
class HeroPillIconGroup extends StatelessWidget {
  const HeroPillIconGroup({
    super.key,
    required this.slots,
    this.tvFocusOrderStart,
  });

  final List<HeroPillIconSlot> slots;
  /// When set (TV), pins D-pad order for each slot starting at this index.
  final int? tvFocusOrderStart;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();

    return Container(
      height: _kHeroPillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: _heroPillDecoration(hover: false),
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
            _HeroPillIconSlotButton(
              slot: slots[i],
              isFirst: i == 0,
              isLast: i == slots.length - 1,
              focusOrder: tvFocusOrderStart != null
                  ? NumericFocusOrder((tvFocusOrderStart! + i).toDouble())
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

/// Segmented hero pill (e.g. SUB | DUB) — matches [HeroPillIconGroup] chrome.
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
      decoration: _heroPillDecoration(hover: false),
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
      hoverScale: 1.06,
      pressScale: 0.94,
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
                ? _heroPillSlotActiveFill(pressed: pressed)
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

class _HeroPillIconSlotButton extends StatelessWidget {
  const _HeroPillIconSlotButton({
    required this.slot,
    required this.isFirst,
    required this.isLast,
    this.focusOrder,
  });

  final HeroPillIconSlot slot;
  final bool isFirst;
  final bool isLast;
  final FocusOrder? focusOrder;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (isLast) {
      return shellTrapTvFocusHorizontalEdge(node, event, trapRight: true);
    }
    return KeyEventResult.ignored;
  }

  Widget _wrapOrder(Widget child) {
    final order = focusOrder;
    if (order == null) return child;
    return FocusTraversalOrder(order: order, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final content = slot.child ??
        Icon(
          slot.icon,
          size: _kHeroPillIconSize,
          color: Colors.white,
        );

    if (slot.child != null && slot.onTap == null) {
      return _wrapOrder(
        SizedBox(
          width: _kHeroPillHeight,
          height: _kHeroPillHeight,
          child: ClipRRect(
            borderRadius: _heroPillSlotBorderRadius(
              isFirst: isFirst,
              isLast: isLast,
            ),
            child: Center(child: content),
          ),
        ),
      );
    }

    if (slot.onTap == null) {
      return _wrapOrder(
        SizedBox(
          width: _kHeroPillHeight,
          height: _kHeroPillHeight,
          child: Center(child: content),
        ),
      );
    }

    final button = ForjaInteractive(
      onTap: slot.onTap,
      hoverScale: 1.06,
      pressScale: 0.94,
      onKeyEvent: _onKeyEvent,
      builder: (hover, pressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: _kHeroPillHeight,
          height: _kHeroPillHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (hover || pressed)
                ? _heroPillSlotActiveFill(pressed: pressed)
                : Colors.transparent,
            borderRadius: _heroPillSlotBorderRadius(
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          child: content,
        );
      },
    );

    if (slot.tooltip != null) {
      return _wrapOrder(Tooltip(message: slot.tooltip!, child: button));
    }
    return _wrapOrder(button);
  }
}
