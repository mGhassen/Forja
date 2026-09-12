import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/engine/lists/list_open_binding.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Pick a details hub (nav label). Returns null if cancelled.
Future<ListOpenCandidate?> showListOpenHubPicker(
  BuildContext context, {
  required List<ListOpenCandidate> candidates,
  String title = 'Open with',
}) {
  if (candidates.isEmpty) return Future.value(null);
  return showDialog<ListOpenCandidate>(
    context: context,
    builder: (ctx) {
      return ShellScope.rehost(
        context,
        AlertDialog(
          backgroundColor: ForjaShellColors.cinematic.menuSurface,
          title: Text(
            title,
            style: const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 360,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: ForjaShellColors.borderSubtle,
              ),
              itemBuilder: (context, i) {
                final c = candidates[i];
                final subtitle = c.needsSearch
                    ? 'Search by title'
                    : (c.types.isEmpty ? null : c.types.join(' · '));
                return ListTile(
                  title: Text(
                    c.label,
                    style: const TextStyle(color: ForjaShellColors.textPrimary),
                  ),
                  subtitle: subtitle == null
                      ? null
                      : Text(
                          subtitle,
                          style: const TextStyle(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                  onTap: () => Navigator.of(ctx).pop(c),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: ForjaShellColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Pick a search hit after choosing a hub that needs title match.
Future<MetaItem?> showListOpenSearchHitPicker(
  BuildContext context, {
  required List<MetaItem> hits,
  required String hubLabel,
}) {
  if (hits.isEmpty) return Future.value(null);
  return showDialog<MetaItem>(
    context: context,
    builder: (ctx) {
      return ShellScope.rehost(
        context,
        AlertDialog(
          backgroundColor: ForjaShellColors.cinematic.menuSurface,
          title: Text(
            'Match in $hubLabel',
            style: const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 400,
            height: 360,
            child: ListView.separated(
              itemCount: hits.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: ForjaShellColors.borderSubtle,
              ),
              itemBuilder: (context, i) {
                final hit = hits[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: ShellTokens.bodyHorizontalPadding / 2,
                    vertical: 4,
                  ),
                  title: Text(
                    hit.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ForjaShellColors.textPrimary),
                  ),
                  subtitle: hit.releaseInfo.trim().isEmpty
                      ? null
                      : Text(
                          hit.releaseInfo,
                          style: const TextStyle(
                            color: ForjaShellColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                  onTap: () => Navigator.of(ctx).pop(hit),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: ForjaShellColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<List<MetaItem>> listOpenSearchHub({
  required String pluginId,
  required String query,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final env = await MetaRuntime.instance.run(
    pluginId: pluginId,
    action: 'search',
    params: {'query': q, 'limit': 24},
  );
  if (!env.ok) return const [];
  return env.items;
}

Future<void> listOpenShowEmptySearchToast(String hubLabel) {
  ForjaToast.info('No matches in $hubLabel');
  return Future.value();
}
