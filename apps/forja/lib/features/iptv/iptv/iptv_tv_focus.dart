import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
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

/// TV D-pad focus — green highlight like player chrome controls.
bool iptvTvFocused(BuildContext context, {required bool focused}) =>
    iptvUseTvFocus(context) && focused;

/// Idle tint → brand green on TV focus, white on hover (matches player chrome).
Color iptvFocusFg(
  Color idle, {
  required bool active,
  required bool tvFocused,
}) {
  if (tvFocused) return ForjaShellColors.brandGreen;
  if (active) return Colors.white;
  return idle;
}

Color iptvFocusSurfaceColor({
  required bool active,
  required bool tvFocused,
  double idleAlpha = 0.08,
  double hoverAlpha = 0.14,
  bool subtle = false,
}) {
  if (tvFocused) return ForjaShellColors.brandGreen.withValues(alpha: 0.14);
  if (active) return Colors.white.withValues(alpha: subtle ? 0.14 : hoverAlpha);
  return Colors.white.withValues(alpha: idleAlpha);
}

Color iptvFocusOutlineColor({
  required bool active,
  required bool tvFocused,
  double idleAlpha = 0.12,
  double hoverAlpha = 0.22,
  Color? idleOverride,
}) {
  if (tvFocused) return ForjaShellColors.brandGreen;
  if (active) return Colors.white.withValues(alpha: hoverAlpha);
  return idleOverride ?? Colors.white.withValues(alpha: idleAlpha);
}

/// Button/chip surface when D-pad focused — matches player chrome controls.
BoxDecoration iptvFocusButtonDecoration({
  required bool active,
  required bool tvFocused,
  required double borderRadius,
  Color? idleBg,
  Color? idleBorder,
  bool subtle = false,
}) {
  final radius = BorderRadius.circular(borderRadius);
  if (tvFocused) {
    return BoxDecoration(
      color: ForjaShellColors.brandGreen.withValues(alpha: 0.14),
      borderRadius: radius,
      border: Border.all(color: ForjaShellColors.brandGreen, width: 1.5),
    );
  }
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

/// Border colors for IPTV share-code cells (boxed OTP style).
Color iptvDialogFieldBorderColor({required bool focused}) =>
    Colors.white.withValues(alpha: focused ? 0.35 : 0.12);

/// Underline field chrome for portal URL / username / password (not card outlines).
InputDecoration iptvDialogFieldDecoration({
  required bool focused,
  String? hintText,
  TextStyle? hintStyle,
  Widget? suffixIcon,
}) {
  final idle = BorderSide(
    color: Colors.white.withValues(alpha: 0.16),
  );
  final active = BorderSide(
    color: focused ? ForjaShellColors.brandGreen : Colors.white.withValues(alpha: 0.4),
    width: focused ? 1.5 : 1,
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: hintStyle,
    isDense: true,
    filled: false,
    contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 32),
    border: UnderlineInputBorder(borderSide: idle),
    enabledBorder: UnderlineInputBorder(borderSide: idle),
    focusedBorder: UnderlineInputBorder(borderSide: active),
    disabledBorder: UnderlineInputBorder(borderSide: idle),
  );
}

/// Focus a registered IPTV row item (restores last index when [index] is null).
bool iptvFocusRowItem(String rowId, [int? index]) {
  final handle = ShellTvFocusCoordinator.rowHandle('iptv', rowId);
  if (handle == null || handle.itemCount <= 0) return false;
  final idx = (index ?? handle.lastFocusedIndex).clamp(0, handle.itemCount - 1);
  return ShellTvFocusCoordinator.focusRowItem('iptv', rowId, idx);
}

/// D-pad focus index for a stream's group in [IptvController.browserSidebarCategories].
int iptvBrowserCategoryIndexFor(IptvController ctrl, String categoryId) {
  final idx = ctrl.browserSidebarCategories
      .indexWhere((c) => c.id == categoryId);
  return idx >= 0 ? idx : 0;
}

/// Left from a channel tile → that channel's group row in the sidebar.
/// When browsing Favorites / Already watched, return to that synthetic row.
VoidCallback iptvStreamLeftEdge(IptvController ctrl, IptvStream stream) {
  final selected = ctrl.browserSelectedCategoryId;
  final groupId = selected != null && IptvLiveCatalog.isSyntheticId(selected)
      ? selected
      : stream.categoryId;
  return () => iptvFocusRowItem(
        'browser-categories',
        iptvBrowserCategoryIndexFor(ctrl, groupId),
      );
}

bool iptvFocusBrowserCategories(IptvController ctrl) =>
    iptvFocusRowItem('browser-categories', ctrl.browserCategoryFocusIndex);

/// First catalog group row (sidebar) — preferred TV landing focus.
bool iptvFocusCatalogGroupRow([int index = 0]) =>
    iptvFocusRowItem('browser-categories', index);

/// Shelf index for the active Live / Movies / Series tab.
int iptvActiveSectionShelfIndex(IptvController ctrl) {
  switch (ctrl.activeSection) {
    case IptvSection.live:
      return 0;
    case IptvSection.vod:
      return 1;
    case IptvSection.series:
      return 2;
    default:
      return 0;
  }
}

/// Up from a channel tile: right column → portal tool; else → active shelf tab.
VoidCallback iptvStreamUpEdge(
  IptvController ctrl, {
  required int index,
  required int columns,
}) {
  return () {
    if (columns > 1 && index % columns == columns - 1) {
      iptvFocusRowItem('iptv-top-tools', 1);
    } else {
      iptvFocusRowItem(
        'iptv-sections',
        iptvActiveSectionShelfIndex(ctrl),
      );
    }
  };
}

/// Restore IPTV catalog focus when returning from the nav rail (RIGHT / Enter).
bool iptvRestoreCatalogFocus({int? portalIndex}) {
  if (iptvFocusCatalogGroupRow(0)) return true;
  if (iptvFocusRowItem('iptv-sections', 0)) return true;
  if (iptvFocusRowItem('iptv-top-tools', 0)) return true;
  if (iptvFocusRowItem('iptv-top-tools', 1)) return true;
  if (iptvFocusRowItem('portals', portalIndex ?? 0)) return true;
  if (iptvFocusRowItem('browser-streams', 0)) return true;
  if (iptvFocusRowItem('iptv-open-portal', 0)) return true;
  return false;
}

/// Nav Enter on IPTV — land on the first group row once catalog is ready.
void iptvEnterFromNav(IptvController ctrl) {
  if (ctrl.activePortal == null) {
    iptvFocusRowItem('iptv-open-portal', 0);
    return;
  }
  if (!ctrl.isLoading) {
    iptvFocusCatalogGroupRow(0);
  }
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
  FocusNode? focusNode,
  String? tvRowId,
  int? tvItemIndex,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  VoidCallback? onLeftEdge,
  VoidCallback? onRightEdge,
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
      focusNode: focusNode,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
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
    this.focusNode,
    this.tvRowId,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color idleColor;
  final double size;
  final double hitSize;
  final double borderRadius;
  final String? tooltip;
  final FocusNode? focusNode;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_IptvFocusIconTap> createState() => _IptvFocusIconTapState();
}

class _IptvFocusIconTapState extends State<_IptvFocusIconTap> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  bool get _tvFocused =>
      iptvTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: iptvFocusFg(
        widget.idleColor,
        active: _active,
        tvFocused: _tvFocused,
      ),
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
      focusNode: widget.focusNode,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
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

  bool get _tvFocused =>
      iptvTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final idle = widget.color ?? IptvShellStyle.accent;
    final fg = iptvFocusFg(idle, active: _active, tvFocused: _tvFocused);
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

  bool get _tvFocused =>
      iptvTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final idle = widget.color ?? IptvShellStyle.accent;
    final fg = iptvFocusFg(idle, active: _active, tvFocused: _tvFocused);
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
              Text(widget.label, style: GoogleFonts.plusJakartaSans(color: fg)),
            ],
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: widget.onPressed,
      icon: Icon(widget.icon, color: idle, size: 18),
      label: Text(widget.label, style: GoogleFonts.plusJakartaSans(color: idle)),
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
  final bool dense;

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
    this.dense = false,
  });

  @override
  State<IptvPrimaryButton> createState() => _IptvPrimaryButtonState();
}

class _IptvPrimaryButtonState extends State<IptvPrimaryButton> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  bool get _tvFocused =>
      iptvTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final tv = iptvUseTvFocus(context);
    final decoration = tv
        ? iptvFocusButtonDecoration(
            active: _active,
            tvFocused: _tvFocused,
            borderRadius: 14,
            subtle: widget.subtle,
          )
        : IptvShellStyle.primaryButtonDecoration(subtle: widget.subtle);
    final fg = _tvFocused ? ForjaShellColors.brandGreen : Colors.white;

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
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: widget.dense ? 10 : 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                else
                  Icon(widget.icon, color: fg, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: fg,
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

class IptvRoundIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool big;
  final String? tvRowId;
  final int? tvItemIndex;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const IptvRoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.big = false,
    this.tvRowId,
    this.tvItemIndex,
    this.focusNode,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<IptvRoundIcon> createState() => _IptvRoundIconState();
}

class _IptvRoundIconState extends State<IptvRoundIcon> {
  bool _focused = false;

  bool get _tvFocused =>
      iptvTvFocused(context, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 56.0 : 44.0;
    final fg = _tvFocused ? ForjaShellColors.brandGreen : Colors.white;
    final shape = CircleBorder(
      side: _tvFocused
          ? const BorderSide(color: ForjaShellColors.brandGreen, width: 1.5)
          : BorderSide.none,
    );
    final child = SizedBox(
      width: size,
      height: size,
      child: Icon(widget.icon, color: fg, size: widget.big ? 32 : 22),
    );
    if (iptvUseTvFocus(context)) {
      return Material(
        color: _tvFocused
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.12),
        shape: shape,
        child: iptvTap(
          context: context,
          onTap: widget.onTap,
          borderRadius: size / 2,
          focusNode: widget.focusNode,
          tvRowId: widget.tvRowId,
          tvItemIndex: widget.tvItemIndex,
          onUpEdge: widget.onUpEdge,
          onDownEdge: widget.onDownEdge,
          onLeftEdge: widget.onLeftEdge,
          onRightEdge: widget.onRightEdge,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: child,
        ),
      );
    }
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}
