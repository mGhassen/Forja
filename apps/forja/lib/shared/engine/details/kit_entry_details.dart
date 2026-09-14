import 'package:flutter/material.dart';
import 'package:forja/shared/engine/details/kit_list_entry.dart';
import 'package:forja/shared/player/sources/kit_panel_host.dart';
import 'package:forja/shared/player/sources/resolve_panel_host.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja_foundation/blocks/details/details_block.dart';

/// Generic kit entry details — resolve panel host when source matches.
class KitEntryDetailsPage extends StatelessWidget {
  const KitEntryDetailsPage({
    super.key,
    required this.entry,
    required this.listSourceId,
    required this.layoutWidgets,
    this.refreshEpoch = 0,
  });

  final KitListEntry entry;
  final String listSourceId;
  final List<Map<String, dynamic>> layoutWidgets;
  final int refreshEpoch;

  static KitPanelHost? _hostFor(String listSourceId) {
    final id = listSourceId.trim();
    if (id == KitResolvePanelHost.instance.listSourceId) {
      return KitResolvePanelHost.instance;
    }
    return null;
  }

  static Future<void> open(
    BuildContext context, {
    required KitListEntry entry,
    required String listSourceId,
    required List<Map<String, dynamic>> layoutWidgets,
    int refreshEpoch = 0,
    String? shellTabId,
  }) {
    final host = _hostFor(listSourceId);
    final custom = host?.buildDetailsPage(
      context: context,
      entry: entry,
      layoutWidgets: layoutWidgets,
      refreshEpoch: refreshEpoch,
    );
    return pushShellRoute<void>(
      context,
      AppRouter.slideShellRoute<void>(
        (_) => custom ??
            KitEntryDetailsPage(
              entry: entry,
              listSourceId: listSourceId,
              layoutWidgets: layoutWidgets,
              refreshEpoch: refreshEpoch,
            ),
        settings: RouteSettings(
          name: '${shellTabId ?? listSourceId}_kit_entry_details',
        ),
      ),
      shellTabId: shellTabId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = _hostFor(listSourceId);
    final title = entry.meta.name.trim().isEmpty ? 'Details' : entry.meta.name;

    return EntryDetails(
      title: title,
      onBack: () => maybePopShellOverlay(),
      body: host == null
          ? null
          : host.buildSidePanel(
              context: context,
              entry: entry,
              layoutWidgets: layoutWidgets,
              shellTabVisible: true,
              refreshEpoch: refreshEpoch,
              onClosed: () => maybePopShellOverlay(),
            ),
    );
  }
}
