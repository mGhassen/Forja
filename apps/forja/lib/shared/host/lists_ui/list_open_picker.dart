import 'package:forja/shared/engine/runtime/plugin_actions.dart';
import 'package:forja/shared/engine/store/list_open_title_rank.dart';
import 'package:forja_foundation/protocol/protocol.dart';

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
