import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart';

export 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart'
    show FilterSheetOption;

/// Host TV/focus wrapper over [FilterSheetOption].
class KitFilterSheetOption extends StatelessWidget {
  const KitFilterSheetOption({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
    required this.tvTabId,
    this.subtitle,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final String tvTabId;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    return FilterSheetOption(
      label: label,
      subtitle: subtitle,
      selected: selected,
      icon: icon,
      onSelected: onSelected,
      focusNode: focusNode,
      scaleOnHover: policy.scaleOnHover,
      tvFocus: policy.useFocusableMoodChips,
      interactiveBuilder: policy.useFocusableMoodChips
          ? ({
              required child,
              required onTap,
              onFocusChange,
              onHoverChange,
              focusNode,
            }) =>
              shellFocusableTap(
                context: context,
                onTap: onTap,
                borderRadius: 12,
                scaleOnFocus: 1.0,
                showFocusBorder: false,
                showFocusFill: false,
                navLeftAlways: true,
                focusNode: focusNode,
                listIndex: tvItemIndex,
                tvTabId: tvTabId,
                tvRowId: tvRowId,
                tvItemIndex: tvItemIndex,
                tvZone: ShellTvZone.row,
                onFocusChange: onFocusChange,
                onHoverChange: onHoverChange,
                child: child,
              )
          : null,
    );
  }
}
