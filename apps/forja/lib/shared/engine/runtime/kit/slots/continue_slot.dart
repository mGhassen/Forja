import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/continue_section.dart';

/// Hub `continue` slot — opaque [WatchHistory] rows → [ContinueSection].
class PackContinueSlot extends StatelessWidget {
  const PackContinueSlot({
    super.key,
    required this.pluginId,
  });

  final String pluginId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WatchHistory.revision,
      builder: (context, _, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: WatchHistory.getAll(pluginId),
          builder: (context, snap) {
            final rows = snap.data ?? const [];
            if (rows.isEmpty) return const SizedBox.shrink();
            final byId = {
              for (final e in rows) (e['metaId'] ?? '').toString(): e,
            };
            return ContinueSection(
              entries: [for (final e in rows) ContinueEntry.fromMap(e)],
              titlePadding: EdgeInsets.fromLTRB(
                ShellTokens.homeSectionHorizontalPadding,
                12,
                ShellTokens.homeSectionHorizontalPadding,
                8,
              ),
              listPadding: EdgeInsets.symmetric(
                horizontal: ShellTokens.homeSectionHorizontalPadding,
              ),
              onResume: (entry) => _open(context, byId[entry.metaId]),
              onInfo: (entry) => _open(context, byId[entry.metaId]),
              onRemove: (entry) {
                WatchHistory.remove(pluginId, entry.metaId);
              },
            );
          },
        );
      },
    );
  }

  void _open(BuildContext context, Map<String, dynamic>? row) {
    if (row == null) return;
    final meta = WatchHistory.metaFromEntry(row);
    if (meta == null) return;
    openMetaItem(context, pluginId: pluginId, item: meta);
  }
}
