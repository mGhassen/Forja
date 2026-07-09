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

/// Primary hero CTA — pill with icon + label (Play, Watch Now, Resume).
class HeroPillPlayButton extends StatelessWidget {
  const HeroPillPlayButton({
    super.key,
    required this.label,
    this.icon = Icons.play_arrow_rounded,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
          decoration: _heroPillDecoration(hover: hover),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _kHeroPillIconSize, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
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
            _HeroPillIconSlotButton(slot: slots[i]),
          ],
        ],
      ),
    );
  }
}

class _HeroPillIconSlotButton extends StatelessWidget {
  const _HeroPillIconSlotButton({required this.slot});

  final HeroPillIconSlot slot;

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
          color: hover ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
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
