import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/engine/lists/list_open_binding.dart';
import 'package:forja/shared/engine/lists/list_open_title_rank.dart';
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

Future<List<MetaItem>> _listOpenSearchOnce({
  required String pluginId,
  required String query,
}) async {
  final env = await MetaRuntime.instance.run(
    pluginId: pluginId,
    action: 'search',
    params: {'query': query, 'limit': 24},
  );
  if (!env.ok) return const [];
  return env.items;
}

/// Hub `search` by title, ranked so exact / near-exact names come first.
Future<List<MetaItem>> listOpenSearchHub({
  required String pluginId,
  required String query,
  String? yearHint,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];

  var hits = await _listOpenSearchOnce(pluginId: pluginId, query: q);

  // Year in the title often kills AniList / KissKH search — retry bare name.
  if (hits.isEmpty) {
    final stripped = q
        .replaceAll(RegExp(r'\s*[\(\[\{]\s*\d{4}\s*[\)\]\}]\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isNotEmpty && stripped != q) {
      hits = await _listOpenSearchOnce(pluginId: pluginId, query: stripped);
    }
  }

  // "Title: Season 2" / "Title — Part 1" → try the head.
  if (hits.isEmpty) {
    final cut = q.split(RegExp(r'[:：\-–—]')).first.trim();
    if (cut.length >= 3 && cut.toLowerCase() != q.toLowerCase()) {
      hits = await _listOpenSearchOnce(pluginId: pluginId, query: cut);
    }
  }

  final queryYear = listOpenParseYear(yearHint) ?? listOpenParseYear(q);
  return listOpenRankByTitle(
    q,
    hits,
    nameOf: (m) => m.name,
    releaseOf: (m) => m.releaseInfo.isNotEmpty ? m.releaseInfo : m.premiereDate,
    queryYear: queryYear,
  );
}

Future<void> listOpenShowEmptySearchToast(String hubLabel) {
  ForjaToast.info('No matches in $hubLabel');
  return Future.value();
}
