import 'package:flutter/material.dart';
import 'package:forja/features/live_matches/streams/live_sports_hub_page.dart';
import 'package:forja/features/live_matches/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_panel_host.dart';
import 'package:forja/shared/design/design.dart';

/// Live Sports streams panel offered to kit via [CatalogHostListRegistry].
final class LiveSportsStreamsPanelHost implements CatalogKitPanelHost {
  const LiveSportsStreamsPanelHost();

  static const instance = LiveSportsStreamsPanelHost();

  @override
  String get listSourceId => LiveSportsHost.listSourceId;

  @override
  Widget buildSidePanel({
    required BuildContext context,
    required CatalogKitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required bool shellTabVisible,
    required int refreshEpoch,
    VoidCallback? onClosed,
  }) {
    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: ForjaShellColors.borderSubtle),
          ),
        ),
        child: LiveSportsHubPage(
          key: ValueKey('live-panel-${entry.meta.id}'),
          layoutWidgets: layoutWidgets,
          parentShellVisible: shellTabVisible,
          refreshEpoch: refreshEpoch,
          panelOnly: true,
          kitPanelRow: entry.legacyRow,
          onPanelClosed: onClosed,
        ),
      ),
    );
  }
}
