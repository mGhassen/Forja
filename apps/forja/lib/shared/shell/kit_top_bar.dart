import 'package:flutter/material.dart';

import 'package:forja/shared/shell/kit_menu_widget.dart';
import 'package:forja/shared/shell/kit_tabs_widget.dart';
import 'package:forja/shared/engine/hub/kit_top_menu_registry.dart';
import 'package:forja_foundation/widgets/chrome/kit_layout_scope.dart';

/// Shell top bar for pack-declared `kit.menu` + `kit.tabs` (same slot as
/// [KitChromeTopBar] on browse hubs).
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

        return SafeArea(
          bottom: false,
          left: false,
          right: false,
          child: SizedBox(
            height: barHeight,
            child: KitLayoutScope(
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
