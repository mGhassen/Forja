import 'package:flutter/material.dart';

import 'package:forja/shared/shell/kit_menu_widget.dart';
import 'package:forja/shared/shell/kit_tabs_widget.dart';
import 'package:forja/shared/engine/hub/kit_top_menu_registry.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/top_bar.dart';

export 'package:forja_foundation/widgets/chrome/top_bar.dart' show TopBar;

/// Shell top bar for pack-declared `kit.menu` + `kit.tabs`.
class KitTopBar extends StatelessWidget {
  const KitTopBar({super.key, required this.tabId});

  final String tabId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KitTopMenuRegistry.revision,
      builder: (context, _) {
        final handle = KitTopMenuRegistry.handleFor(tabId);
        if (handle == null) return const SizedBox.shrink();

        final menuSpec = handle.menuSpec;
        final tabsSpec = handle.tabsSpec;
        final barHeight = KitTopMenuRegistry.bodyTopInset(context, tabId);

        return TopBar(
          height: barHeight,
          child: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: LayoutScope(
              selections: handle.selections,
              onSelect: handle.onSelect,
              widgetSpecs: handle.widgetSpecs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (menuSpec != null)
                    KitMenuWidget(
                      tabId: tabId,
                      spec: menuSpec,
                      sortOrder: 0,
                      inShellTopBar: true,
                    ),
                  if (tabsSpec != null)
                    KitTabsWidget(
                      tabId: tabId,
                      spec: tabsSpec,
                      sortOrder: 1,
                      inShellTopBar: true,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
