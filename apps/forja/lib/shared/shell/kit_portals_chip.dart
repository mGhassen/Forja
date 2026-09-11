import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/widgets/chrome/portals_chip.dart';

export 'package:forja_foundation/widgets/chrome/portals_chip.dart' show PortalsChip;

/// Host TV/focus wrapper over [PortalsChip].
class KitPortalsChip extends StatelessWidget {
  const KitPortalsChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.hasPortal = false,
    this.checking = false,
    this.healthy,
    this.seatsUsed,
    this.seatsMax,
    this.compact = false,
    this.accentColor,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.tvZone = ShellTvZone.topBar,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
    this.onFocusChange,
    this.onHoverChange,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool hasPortal;
  final bool checking;
  final bool? healthy;
  final String? seatsUsed;
  final String? seatsMax;
  final bool compact;
  final Color? accentColor;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final ShellTvZone? tvZone;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    return PortalsChip(
      label: label,
      onTap: onTap,
      selected: selected,
      hasPortal: hasPortal,
      checking: checking,
      healthy: healthy,
      seatsUsed: seatsUsed,
      seatsMax: seatsMax,
      compact: compact,
      accentColor: accentColor,
      tvFocus: policy.useFocusableMoodChips,
      onFocusChange: onFocusChange,
      onHoverChange: onHoverChange,
      interactiveBuilder: ({
        required child,
        required onTap,
        onFocusChange,
        onHoverChange,
      }) =>
          shellFocusableTap(
            context: context,
            onTap: onTap,
            borderRadius: 8,
            tvZone: tvZone,
            tvTabId: tvTabId,
            tvRowId: tvRowId,
            tvItemIndex: tvItemIndex,
            onLeftEdge: onLeftEdge,
            onRightEdge: onRightEdge,
            onUpEdge: onUpEdge,
            onDownEdge: onDownEdge,
            onFocusChange: onFocusChange,
            onHoverChange: onHoverChange,
            child: child,
          ),
    );
  }
}
