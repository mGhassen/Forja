import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';
import 'package:forja/shared/engine/hub/host_list_registry.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja_foundation/widgets/details/entry_details.dart';

/// Generic kit entry details — host wires list registry into [EntryDetails].
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

  static Future<void> open(
    BuildContext context, {
    required KitListEntry entry,
    required String listSourceId,
    required List<Map<String, dynamic>> layoutWidgets,
    int refreshEpoch = 0,
    String? shellTabId,
  }) {
    final host = HostListRegistry.resolvePanel(listSourceId);
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
    final host = HostListRegistry.resolvePanel(listSourceId);
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
