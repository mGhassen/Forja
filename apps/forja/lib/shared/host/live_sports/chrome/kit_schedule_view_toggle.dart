import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forja/shared/host/live_sports/schedule/kit_schedule_layout.dart';
import 'package:forja/shared/host/live_sports/schedule/kit_schedule_prefs.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
/// Icon-only list/cards toggle for kit.topBar `action: scheduleView`.
class KitScheduleViewToggle extends ConsumerStatefulWidget {
  const KitScheduleViewToggle({
    super.key,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  ConsumerState<KitScheduleViewToggle> createState() =>
      _KitScheduleViewToggleState();
}

class _KitScheduleViewToggleState extends ConsumerState<KitScheduleViewToggle> {
  static const _size = 40.0;

  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isCards =
        ref.watch(kitScheduleLayoutProvider) == KitSchedulePrefs.styleCards;
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    final tv = policy.useFocusableMoodChips;
    final tvFocused = tv && _focused;
    final tip = isCards ? 'Cards view' : 'List view';
    final icon = isCards ? Icons.grid_view_rounded : Icons.view_list_rounded;

    return shellFocusableTap(
      context: context,
      onTap: () {
        ref.read(kitScheduleLayoutProvider.notifier).toggleStyle();
      },
      borderRadius: _size / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onUpEdge: () {},
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: Tooltip(
        message: tip,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: active || tvFocused ? 0.16 : 0.08,
            ),
            borderRadius: BorderRadius.circular(_size / 2),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: tvFocused
                    ? 0.45
                    : active
                        ? 0.28
                        : 0.12,
              ),
              width: tvFocused ? 1.5 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: active || tvFocused ? Colors.white : Colors.white60,
            size: 20,
          ),
        ),
      ),
    );
  }
}
