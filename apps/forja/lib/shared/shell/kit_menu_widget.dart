import 'package:flutter/material.dart';
import 'package:forja/shared/shell/focus_edge.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_underline_tab.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/widgets/chrome/catalog_menu.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

export 'package:forja_foundation/widgets/chrome/catalog_menu.dart'
    show CatalogMenu;

/// Host TV wrapper over [CatalogMenu].
class KitMenuWidget extends StatelessWidget {
  const KitMenuWidget({
    super.key,
    required this.tabId,
    required this.spec,
    this.sortOrder = 0,
    this.count,
    this.firstFocusNode,
    this.inShellTopBar = false,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final int sortOrder;
  final int? count;
  final FocusNode? firstFocusNode;
  final bool inShellTopBar;

  String get _widgetId => (spec['id'] ?? 'menu').toString();

  @override
  Widget build(BuildContext context) {
    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tabGap = useTv
        ? 28.0
        : MediaQuery.sizeOf(context).width < 560
            ? 20.0
            : 36.0;
    final focusDown = kitFocusEdge(tabId, spec['focusDown']?.toString());
    final focusLeft = kitFocusSide(tabId, spec['focusLeft']);
    final focusRight = kitFocusSide(tabId, spec['focusRight']);
    final items = layoutItemsFromSpec(spec);

    return CatalogMenu(
      spec: spec,
      count: count,
      firstFocusNode: firstFocusNode,
      inShellTopBar: inShellTopBar,
      tabGap: tabGap,
      tabBuilder: ({
        required index,
        required label,
        required isActive,
        required onTap,
        focusNode,
      }) {
        return ForjaUnderlineTab(
          label: label,
          isActive: isActive,
          onTap: onTap,
          tvFocus: useTv,
          tabId: tabId,
          rowId: _widgetId,
          listIndex: index,
          onDownEdge: focusDown ?? () {},
          onLeftEdge: index == 0 ? focusLeft : null,
          onRightEdge: index == items.length - 1 ? focusRight : null,
          focusNode: focusNode,
        );
      },
      wrapRow: useTv
          ? (child) => TvKitRow(
                tabId: tabId,
                rowId: _widgetId,
                sortOrder: sortOrder,
                itemCount: items.length,
                onFocusUp: kitFocusEdge(
                      tabId,
                      spec['focusUp']?.toString(),
                      last: true,
                    ) ??
                    () {},
                child: child,
              )
          : null,
    );
  }
}
