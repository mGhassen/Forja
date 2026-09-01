import 'package:flutter/material.dart';

import 'catalog_kit_menu_widget.dart';
import 'catalog_kit_tabs_widget.dart';
import 'catalog_kit_top_menu_registry.dart';
import 'catalog_layout_scope.dart';

/// Shell top bar for pack-declared `kit.menu` + `kit.tabs` (same slot as
/// [CatalogTopBar] on browse hubs).
class CatalogKitTopBar extends StatelessWidget {
  const CatalogKitTopBar({super.key, required this.tabId});

  final String tabId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CatalogKitTopMenuRegistry.revision,
      builder: (context, _) {
        final handle = CatalogKitTopMenuRegistry.handleFor(tabId);
        if (handle == null) return const SizedBox.shrink();

        final menuSpec = handle.menuSpec;
        final tabsSpec = handle.tabsSpec;
        final barHeight = CatalogKitTopMenuRegistry.bodyTopInset(context, tabId);

        return SafeArea(
          bottom: false,
          left: false,
          right: false,
          child: SizedBox(
            height: barHeight,
            child: CatalogLayoutScope(
              selections: handle.selections,
              onSelect: handle.onSelect,
              widgetSpecs: handle.widgetSpecs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (menuSpec != null)
                    CatalogKitMenuWidget(
                      tabId: tabId,
                      spec: menuSpec,
                      sortOrder: 0,
                      inShellTopBar: true,
                    ),
                  if (tabsSpec != null)
                    CatalogKitTabsWidget(
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
