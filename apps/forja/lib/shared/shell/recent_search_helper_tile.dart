import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/widgets/chrome/recent_search_helper_tile.dart'
    as foundation;

/// Host TV/focus wrapper over foundation [RecentSearchHelperTile].
class RecentSearchHelperTile extends StatelessWidget {
  const RecentSearchHelperTile({
    super.key,
    required this.title,
    required this.selected,
    required this.listIndex,
    required this.tvTabId,
    required this.tvRowId,
    required this.onSelect,
    required this.onRemove,
    this.titleFocusNode,
    this.onUpEdge,
    this.onDownEdge,
    this.onRightPastRemove,
    this.onFocusChange,
    this.titleFontSize = 16,
    this.titleFontSizeSelected = 18,
    this.verticalPadding = 4,
  });

  final String title;
  final bool selected;
  final int listIndex;
  final String tvTabId;
  final String tvRowId;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final FocusNode? titleFocusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightPastRemove;
  final ValueChanged<bool>? onFocusChange;
  final double titleFontSize;
  final double titleFontSizeSelected;
  final double verticalPadding;

  String get _removeRowId => '$tvRowId-remove';

  void _focusTitle() {
    final node = titleFocusNode;
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    ShellTvFocusCoordinator.focusRowItem(tvTabId, tvRowId, listIndex);
  }

  @override
  Widget build(BuildContext context) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

    return foundation.RecentSearchHelperTile(
      title: title,
      selected: selected,
      onSelect: onSelect,
      onRemove: onRemove,
      titleFocusNode: titleFocusNode,
      scaleOnHover: policy.scaleOnHover,
      titleFontSize: titleFontSize,
      titleFontSizeSelected: titleFontSizeSelected,
      verticalPadding: verticalPadding,
      onFocusChange: onFocusChange,
      titleInteractiveBuilder: ({
        required child,
        required onTap,
        onFocusChange,
        focusNode,
      }) =>
          shellFocusableTap(
            context: context,
            onTap: onTap,
            borderRadius: 4,
            scaleOnFocus: 1.0,
            navLeftAlways: true,
            listIndex: listIndex,
            tvTabId: tvTabId,
            tvRowId: tvRowId,
            tvZone: ShellTvZone.chipStrip,
            tvItemIndex: listIndex,
            focusNode: focusNode,
            onUpEdge: onUpEdge,
            onDownEdge: onDownEdge,
            onRightEdge: () {
              ShellTvFocusCoordinator.focusRowItem(
                tvTabId,
                _removeRowId,
                listIndex,
              );
            },
            ensureVisibleMode: ShellTvEnsureVisibleMode.row,
            onFocusChange: onFocusChange,
            suppressInkHover: true,
            child: child,
          ),
      removeInteractiveBuilder: ({
        required child,
        required onTap,
        onFocusChange,
        focusNode,
      }) =>
          shellFocusableTap(
            context: context,
            onTap: onTap,
            borderRadius: 4,
            scaleOnFocus: 1.0,
            tvTabId: tvTabId,
            tvRowId: _removeRowId,
            tvZone: ShellTvZone.chipStrip,
            tvItemIndex: listIndex,
            focusNode: focusNode,
            onUpEdge: onUpEdge,
            onDownEdge: onDownEdge,
            onLeftEdge: _focusTitle,
            onRightEdge: onRightPastRemove,
            ensureVisibleMode: ShellTvEnsureVisibleMode.row,
            onFocusChange: onFocusChange,
            suppressInkHover: true,
            child: child,
          ),
    );
  }
}
