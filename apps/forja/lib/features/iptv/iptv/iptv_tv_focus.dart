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

/// Focus a registered IPTV row item (restores last index when [index] is null).
bool iptvFocusRowItem(String rowId, [int? index]) {
  final handle = ShellTvFocusCoordinator.rowHandle('iptv', rowId);
  if (handle == null || handle.itemCount <= 0) return false;
  final idx = (index ?? handle.lastFocusedIndex).clamp(0, handle.itemCount - 1);
  return ShellTvFocusCoordinator.focusRowItem('iptv', rowId, idx);
}

Widget iptvTap({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius = 12,
  double scaleOnFocus = ShellTokens.focusActiveScale,
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
}) {
  if (onTap == null) return child;
  return shellFocusableTap(
    context: context,
    onTap: onTap,
    borderRadius: borderRadius,
    scaleOnFocus: scaleOnFocus,
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
    return iptvTap(
      context: context,
      onTap: onTap,
      borderRadius: 22,
      scaleOnFocus: 1.0,
      child: ForjaPlainIcon(
        icon: Icons.arrow_back_rounded,
        color: color,
        size: size,
        hoverScale: 1.15,
        tooltip: tooltip,
      ),
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
  final btn = ForjaCloseButton.compact(
    tooltip: null,
    color: color ?? Colors.white54,
    size: size,
    hitSize: hitSize,
    onTap: iptvUseTvFocus(context) ? null : onTap,
  );
  if (onTap == null) return btn;
  if (!iptvUseTvFocus(context)) return btn;
  return iptvTap(
    context: context,
    onTap: onTap,
    borderRadius: hitSize / 2,
    scaleOnFocus: 1.0,
    child: btn,
  );
}

class IptvIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;

  const IptvIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? IptvShellStyle.accent;
    if (iptvUseTvFocus(context)) {
      return iptvTap(
        context: context,
        onTap: onPressed,
        borderRadius: 24,
        scaleOnFocus: 1.0,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: resolvedColor, size: iconSize),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: resolvedColor, size: iconSize),
    );
  }
}

class IptvTextAction extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fg = color ?? IptvShellStyle.accent;
    if (iptvUseTvFocus(context)) {
      return iptvTap(
        context: context,
        onTap: onPressed,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(color: fg)),
            ],
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: fg, size: 18),
      label: Text(label, style: GoogleFonts.poppins(color: fg)),
    );
  }
}

class IptvPrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: subtle ? IptvShellStyle.surfaceMuted : IptvShellStyle.chipSelectedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: subtle
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
        ),
        child: iptvTap(
          context: context,
          onTap: busy ? null : onPressed,
          borderRadius: 14,
          tvRowId: tvRowId,
          tvItemIndex: tvItemIndex,
          focusNode: focusNode,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
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
          scaleOnFocus: 1.08,
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
