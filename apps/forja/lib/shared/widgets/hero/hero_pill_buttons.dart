import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:google_fonts/google_fonts.dart';

const double _kHeroPillHeight = 40;
const double _kHeroPillIconSize = 20;

BoxDecoration _heroPillDecoration({required bool hover}) {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: hover ? 0.55 : 0.42),
    borderRadius: BorderRadius.circular(_kHeroPillHeight / 2),
    border: Border.all(
      color: Colors.white.withValues(alpha: hover ? 0.38 : 0.24),
    ),
  );
}

BoxDecoration _heroPlayDecoration({required bool hover}) {
  return BoxDecoration(
    color: hover
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.92)
        : ForjaShellColors.brandGreen,
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

/// Primary hero CTA — pill with icon + label (Play, Watch Now, Resume).
class HeroPillPlayButton extends StatelessWidget {
  const HeroPillPlayButton({
    super.key,
    required this.label,
    this.icon = Icons.play_arrow_rounded,
    this.onTap,
    this.primary = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? const Color(0xFF111827) : Colors.white;

    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.03,
      pressScale: 0.97,
      builder: (hover, pressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: _kHeroPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: primary
              ? _heroPlayDecoration(hover: hover)
              : _heroPillDecoration(hover: hover),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _kHeroPillIconSize, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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

/// Secondary hero actions grouped in one pill (info | add, etc.).
class HeroPillIconGroup extends StatelessWidget {
  const HeroPillIconGroup({super.key, required this.slots});

  final List<HeroPillIconSlot> slots;

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
                ? Colors.white.withValues(alpha: pressed ? 0.12 : 0.08)
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
  });

  final HeroPillIconSlot slot;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final content = slot.child ??
        Icon(
          slot.icon,
          size: _kHeroPillIconSize,
          color: Colors.white,
        );

    final button = ForjaInteractive(
      onTap: slot.onTap,
      hoverScale: 1.06,
      pressScale: 0.94,
      builder: (hover, pressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: _kHeroPillHeight,
          height: _kHeroPillHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (hover || pressed)
                ? Colors.white.withValues(alpha: pressed ? 0.12 : 0.08)
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
      return Tooltip(message: slot.tooltip!, child: button);
    }
    return button;
  }
}
