import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/components/layout/kit_panel_host.dart';
import 'package:forja/shared/foundation/services/registry/host_list_registry.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';

/// Generic kit entry details — full-page host for a [KitPanelHost] body.
///
/// Packs set `kit.list { open: "details" }`. Prefer [KitPanelHost.buildDetailsPage]
/// when the feature owns cinematic chrome (Live Sports cards).
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
    // Shell overlay keeps the nav rail — never push on a root/tab navigator.
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
                    onPressed: () => maybePopShellOverlay(),
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
                      onClosed: () => maybePopShellOverlay(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
