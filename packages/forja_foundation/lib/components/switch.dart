import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Forja on/off switch — flat track, compact thumb (desktop + TV settings density).
class Switch extends StatefulWidget {
  const Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
    this.emphasized = false,
  });

  /// Extra scale on top of [SettingsTokens] switch geometry.
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
    final w = SettingsTokens.switchTrackWidthOf(context) * scale;
    final h = SettingsTokens.switchTrackHeightOf(context) * scale;
    final thumb = SettingsTokens.switchThumbSizeOf(context) * scale;
    final inset = (h - thumb) / 2;
    final on = widget.value;
    final enabled = widget.onChanged != null;
    final thumbWhite = widget.emphasized || _hovered;

    return Semantics(
      toggled: on,
      enabled: enabled,
      button: true,
      child: MouseRegion(
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onChanged!(!on);
                }
              : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: SizedBox(
              width: w,
              height: h,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: on
                      ? ForjaShellColors.brandGreen
                      : const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(h / 2),
                  border: on
                      ? null
                      : Border.all(color: ForjaShellColors.borderSubtle),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment:
                      on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(inset),
                    child: Container(
                      width: thumb,
                      height: thumb,
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
      trackOutlineColor: forjaSwitchTrackOutlineColor,
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

final WidgetStateProperty<Color?> forjaSwitchTrackOutlineColor =
    WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.selected)) {
    return Colors.transparent;
  }
  return ForjaShellColors.borderSubtle;
});

const WidgetStateProperty<Color?> forjaSwitchOverlayColor =
    WidgetStatePropertyAll<Color?>(Colors.transparent);
