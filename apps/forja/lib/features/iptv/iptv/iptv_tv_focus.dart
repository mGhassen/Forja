import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

bool iptvUseTvFocus(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null) return policy.useFocusableMoodChips;
  return resolveShellProfile(context) == ShellProfile.tv;
}

/// D-pad / hover active state for IPTV focusable controls.
bool iptvFocusActive(
  BuildContext context, {
  required bool hovered,
  required bool focused,
}) =>
    ShellInputPolicy.interactiveActive(
      ShellScope.inputPolicyOf(context),
      hovered: hovered,
      focused: focused,
    );

/// Idle tint → white when focused/hovered (no scale).
Color iptvFocusFg(Color idle, bool active) => active ? Colors.white : idle;

/// Button/chip surface when D-pad focused — matches top-bar portal hover.
BoxDecoration iptvFocusButtonDecoration({
  required bool active,
  required double borderRadius,
  Color? idleBg,
  Color? idleBorder,
  bool subtle = false,
}) {
  final radius = BorderRadius.circular(borderRadius);
  if (!active) {
    return BoxDecoration(
      color: idleBg ??
          (subtle ? IptvShellStyle.surfaceMuted : IptvShellStyle.chipSelectedBg),
      borderRadius: radius,
      border: Border.all(
        color: idleBorder ??
            (subtle
                ? Colors.white.withValues(alpha: 0.15)
                : IptvShellStyle.chipSelectedBorder),
      ),
    );
  }
  return BoxDecoration(
    color: Colors.white.withValues(alpha: subtle ? 0.14 : 0.18),
    borderRadius: radius,
    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
  );
}

/// Outline border colors for IPTV dialog text fields (share code, URL, etc.).
Color iptvDialogFieldBorderColor({required bool focused}) =>
    Colors.white.withValues(alpha: focused ? 0.35 : 0.12);

InputDecoration iptvDialogFieldDecoration({
  required bool focused,
  String? hintText,
  TextStyle? hintStyle,
  Widget? suffixIcon,
}) {
  const radius = 8.0;
  final borderRadius = BorderRadius.circular(radius);
  final idle = BorderSide(color: iptvDialogFieldBorderColor(focused: false));
  final active = BorderSide(
    color: iptvDialogFieldBorderColor(focused: true),
    width: 1.5,
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: hintStyle,
    isDense: true,
    filled: true,
    fillColor: Colors.white.withValues(alpha: focused ? 0.08 : 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    border: OutlineInputBorder(borderRadius: borderRadius, borderSide: idle),
    enabledBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: idle),
    focusedBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: active),
    disabledBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: idle),
  );
}

/// Focus a registered IPTV row item (restores last index when [index] is null).
bool iptvFocusRowItem(String rowId, [int? index]) {
  final handle = ShellTvFocusCoordinator.rowHandle('iptv', rowId);
  if (handle == null || handle.itemCount <= 0) return false;
  final idx = (index ?? handle.lastFocusedIndex).clamp(0, handle.itemCount - 1);
  return ShellTvFocusCoordinator.focusRowItem('iptv', rowId, idx);
}

/// Restore IPTV catalog focus when returning from the nav rail (RIGHT / Enter).
bool iptvRestoreCatalogFocus({int? portalIndex}) {
  if (iptvFocusRowItem('portals', portalIndex ?? 0)) return true;
  if (iptvFocusRowItem('iptv-sections', 0)) return true;
  if (iptvFocusRowItem('iptv-top-tools', 1)) return true;
  if (iptvFocusRowItem('iptv-top-tools', 0)) return true;
  if (iptvFocusRowItem('browser-categories', 0)) return true;
  if (iptvFocusRowItem('browser-streams', 0)) return true;
  if (iptvFocusRowItem('iptv-open-portal', 0)) return true;
  return false;
}

Widget iptvTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double? scaleOnFocus,
  int? listIndex,
  int? gridIndex,
  int? gridColumns,
  bool navLeftAlways = false,
  String? tvRowId,
  int? tvItemIndex,
  ShellTvZone? tvZone,
  FocusNode? focusNode,
  VoidCallback? onLeftEdge,
  VoidCallback? onRightEdge,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  ValueChanged<bool>? onFocusChange,
  ValueChanged<bool>? onHoverChange,
  bool showFocusBorder = false,
  bool suppressInkHover = false,
}) {
  if (onTap == null) return child;
  final resolvedScale = scaleOnFocus ??
      (iptvUseTvFocus(context) ? 1.0 : ShellTokens.focusActiveScale);
  return shellFocusableTap(
    context: context,
    onTap: onTap,
    borderRadius: borderRadius,
    scaleOnFocus: resolvedScale,
    listIndex: listIndex,
    gridIndex: gridIndex,
    gridColumns: gridColumns,
    navLeftAlways: navLeftAlways,
    tvTabId: 'iptv',
    tvRowId: tvRowId,
    tvItemIndex: tvItemIndex ?? listIndex ?? gridIndex,
    tvZone: tvZone ?? (tvRowId != null ? ShellTvZone.row : null),
    focusNode: focusNode,
    onLeftEdge: onLeftEdge,
    onRightEdge: onRightEdge,
    onUpEdge: onUpEdge,
    onDownEdge: onDownEdge,
    onFocusChange: onFocusChange,
    onHoverChange: onHoverChange,
    showFocusBorder: showFocusBorder,
    suppressInkHover: suppressInkHover,
    child: child,
  );
}

/// Registers an IPTV row with the TV coordinator.
void iptvSyncRow({
  required String rowId,
  required int sortOrder,
  required int itemCount,
  VoidCallback? onFocusUp,
  ShellTvRowOrientation orientation = ShellTvRowOrientation.horizontal,
}) {
  if (itemCount <= 0) {
    shellTvUnregisterRow(tabId: 'iptv', rowId: rowId);
    return;
  }
  shellTvRegisterRow(
    tabId: 'iptv',
    rowId: rowId,
    sortOrder: sortOrder,
    itemCount: itemCount,
    onFocusUp: onFocusUp,
    orientation: orientation,
  );
}

Widget iptvBackButton(
  BuildContext context, {
  required VoidCallback? onTap,
  Color color = Colors.white70,
  double size = 22,
  String tooltip = 'Back',
}) {
  if (onTap == null) return const SizedBox.shrink();
  if (iptvUseTvFocus(context)) {
    return _IptvFocusIconTap(
      icon: Icons.arrow_back_rounded,
      onTap: onTap,
      idleColor: color,
      size: size,
      hitSize: size + 12,
      borderRadius: 22,
      tooltip: tooltip,
    );
  }
  return ForjaPlainIcon(
    icon: Icons.arrow_back_rounded,
    onTap: onTap,
    color: color,
    size: size,
    hoverScale: 1.15,
    tooltip: tooltip,
  );
}

Widget iptvCloseButton(
  BuildContext context, {
  required VoidCallback? onTap,
  Color? color,
  double size = 18,
  double hitSize = 32,
}) {
  if (onTap == null) return const SizedBox.shrink();
  final idle = color ?? Colors.white54;
  if (iptvUseTvFocus(context)) {
    return _IptvFocusIconTap(
      icon: Icons.close_rounded,
      onTap: onTap,
      idleColor: idle,
      size: size,
      hitSize: hitSize,
      borderRadius: hitSize / 2,
    );
  }
  return ForjaCloseButton.compact(
    tooltip: null,
    color: idle,
    size: size,
    hitSize: hitSize,
    onTap: onTap,
  );
}

class _IptvFocusIconTap extends StatefulWidget {
  const _IptvFocusIconTap({
    required this.icon,
    required this.onTap,
    required this.idleColor,
    required this.size,
    required this.hitSize,
    required this.borderRadius,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color idleColor;
  final double size;
  final double hitSize;
  final double borderRadius;
  final String? tooltip;

  @override
  State<_IptvFocusIconTap> createState() => _IptvFocusIconTapState();
}

class _IptvFocusIconTapState extends State<_IptvFocusIconTap> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: iptvFocusFg(widget.idleColor, _active),
    );
    final child = SizedBox(
      width: widget.hitSize,
      height: widget.hitSize,
      child: Center(child: icon),
    );
    final tap = iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: child,
    );
    if (widget.tooltip == null) return tap;
    return Tooltip(message: widget.tooltip!, child: tap);
  }
}

class IptvIconAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final String? tvRowId;
  final int? tvItemIndex;
  final ShellTvZone? tvZone;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const IptvIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.iconSize = 24,
    this.tvRowId,
    this.tvItemIndex,
    this.tvZone,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<IptvIconAction> createState() => _IptvIconActionState();
}

class _IptvIconActionState extends State<IptvIconAction> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final idle = widget.color ?? IptvShellStyle.accent;
    final fg = iptvFocusFg(idle, _active);
    if (iptvUseTvFocus(context)) {
      return iptvTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 24,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.tvItemIndex,
        tvZone: widget.tvZone,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) => setState(() => _hovered = hovered),
        child: Tooltip(
          message: widget.tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(widget.icon, color: fg, size: widget.iconSize),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.onPressed,
      icon: Icon(widget.icon, color: idle, size: widget.iconSize),
    );
  }
}

class IptvTextAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const IptvTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  State<IptvTextAction> createState() => _IptvTextActionState();
}

class _IptvTextActionState extends State<IptvTextAction> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final idle = widget.color ?? IptvShellStyle.accent;
    final fg = iptvFocusFg(idle, _active);
    if (iptvUseTvFocus(context)) {
      return iptvTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 8,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) => setState(() => _hovered = hovered),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: fg, size: 18),
              const SizedBox(width: 6),
              Text(widget.label, style: GoogleFonts.poppins(color: fg)),
            ],
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: widget.onPressed,
      icon: Icon(widget.icon, color: idle, size: 18),
      label: Text(widget.label, style: GoogleFonts.poppins(color: idle)),
    );
  }
}

class IptvPrimaryButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool subtle;
  final String? tvRowId;
  final int? tvItemIndex;
  final FocusNode? focusNode;

  const IptvPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.subtle = false,
    this.tvRowId,
    this.tvItemIndex,
    this.focusNode,
  });

  @override
  State<IptvPrimaryButton> createState() => _IptvPrimaryButtonState();
}

class _IptvPrimaryButtonState extends State<IptvPrimaryButton> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final tv = iptvUseTvFocus(context);
    final decoration = tv
        ? iptvFocusButtonDecoration(
            active: _active,
            borderRadius: 14,
            subtle: widget.subtle,
          )
        : IptvShellStyle.primaryButtonDecoration(subtle: widget.subtle);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: decoration,
        child: iptvTap(
          context: context,
          onTap: widget.busy ? null : widget.onPressed,
          borderRadius: 14,
          tvRowId: widget.tvRowId,
          tvItemIndex: widget.tvItemIndex,
          focusNode: widget.focusNode,
          onFocusChange: tv
              ? (focused) => setState(() => _focused = focused)
              : null,
          onHoverChange: tv
              ? (hovered) => setState(() => _hovered = hovered)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IptvRoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool big;
  final String? tvRowId;
  final int? tvItemIndex;

  const IptvRoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.big = false,
    this.tvRowId,
    this.tvItemIndex,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 44.0;
    final child = SizedBox(
      width: size,
      height: size,
      child: Icon(icon, color: Colors.white, size: big ? 32 : 22),
    );
    if (iptvUseTvFocus(context)) {
      return Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: size / 2,
          tvRowId: tvRowId,
          tvItemIndex: tvItemIndex,
          child: child,
        ),
      );
    }
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
