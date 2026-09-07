import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_panel_host.dart';
import 'package:forja/shared/catalog/services/host_list_registry.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shell/app_router.dart';

/// Generic kit entry details — full-page host for a [CatalogKitPanelHost] body.
///
/// Packs set `kit.list { open: "details" }`. No product-named screens.
class CatalogKitEntryDetailsPage extends StatelessWidget {
  const CatalogKitEntryDetailsPage({
    super.key,
    required this.entry,
    required this.listSourceId,
    required this.layoutWidgets,
    this.refreshEpoch = 0,
  });

  final CatalogKitListEntry entry;
  final String listSourceId;
  final List<Map<String, dynamic>> layoutWidgets;
  final int refreshEpoch;

  static Future<void> open(
    BuildContext context, {
    required CatalogKitListEntry entry,
    required String listSourceId,
    required List<Map<String, dynamic>> layoutWidgets,
    int refreshEpoch = 0,
  }) {
    return Navigator.of(context).push<void>(
      AppRouter.slideShellRoute<void>(
        (_) => CatalogKitEntryDetailsPage(
          entry: entry,
          listSourceId: listSourceId,
          layoutWidgets: layoutWidgets,
          refreshEpoch: refreshEpoch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = CatalogHostListRegistry.resolvePanel(listSourceId);
    final title = entry.meta.name.trim().isEmpty ? 'Details' : entry.meta.name;

    return Scaffold(
      backgroundColor: ForjaShellColors.surfaceElevated,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                ShellTokens.compactChromeLeadingInset(context),
                8,
                ShellTokens.bodyHorizontalPadding,
                8,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    color: ForjaShellColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ForjaShellColors.borderSubtle),
            Expanded(
              child: host == null
                  ? const Center(
                      child: Text(
                        'No details panel for this list',
                        style: TextStyle(color: ForjaShellColors.textSecondary),
                      ),
                    )
                  : host.buildSidePanel(
                      context: context,
                      entry: entry,
                      layoutWidgets: layoutWidgets,
                      shellTabVisible: true,
                      refreshEpoch: refreshEpoch,
                      onClosed: () => Navigator.of(context).maybePop(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
