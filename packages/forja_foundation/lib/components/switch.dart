import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Forja on/off switch — flat pill track, circular thumb, no outline.
///
/// Hover / focus / [emphasized] → white thumb.
class Switch extends StatefulWidget {
  const Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
    this.emphasized = false,
  });

  /// Extra uniform scale on top of [SettingsTokens] geometry.
  static const double settingsScale = 1.0;

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;

  /// Force white thumb (when outer wrapper owns hover/focus).
  final bool emphasized;

  @override
  State<Switch> createState() => _SwitchState();
}

class _SwitchState extends State<Switch> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final trackW = SettingsTokens.switchTrackWidthOf(context) * scale;
    final trackH = SettingsTokens.switchTrackHeightOf(context) * scale;
    final thumb = SettingsTokens.switchThumbSizeOf(context) * scale;
    final inset = (trackH - thumb) / 2;
    final on = widget.value;
    final interactive = widget.onChanged != null;
    final thumbWhite = widget.emphasized || _hovered;

    return MouseRegion(
      onEnter: (_) {
        if (_hovered) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!_hovered) return;
        setState(() => _hovered = false);
      },
      cursor:
          interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive
            ? () {
                HapticFeedback.selectionClick();
                widget.onChanged!(!on);
              }
            : null,
        child: Semantics(
          toggled: on,
          enabled: interactive,
          button: true,
          // Full brand colors even when onChanged is null (IgnorePointer chrome
          // in packs / TV — parent owns the tap; do not wash out green).
          child: SizedBox(
            width: trackW,
            height: trackH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: on
                    ? ForjaShellColors.brandGreen
                    : const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(trackH / 2),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.all(inset),
                  child: SizedBox(
                    width: thumb,
                    height: thumb,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: thumbWhite
                            ? Colors.white
                            : ForjaShellColors.surfaceElevated,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme data matching [Switch] colors — for any Material [SwitchListTile] leftovers.
SwitchThemeData get forjaSwitchThemeData => SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: forjaSwitchThumbColor,
      trackColor: forjaSwitchTrackColor,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: forjaSwitchOverlayColor,
    );

final WidgetStateProperty<Color?> forjaSwitchThumbColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused) ||
      states.contains(WidgetState.pressed)) {
    return Colors.white;
  }
  return ForjaShellColors.surfaceElevated;
});

final WidgetStateProperty<Color?> forjaSwitchTrackColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.selected)) {
    return ForjaShellColors.brandGreen;
  }
  return const Color(0xFF3A3A3A);
});

const WidgetStateProperty<Color?> forjaSwitchOverlayColor =
    WidgetStatePropertyAll<Color?>(Colors.transparent);
