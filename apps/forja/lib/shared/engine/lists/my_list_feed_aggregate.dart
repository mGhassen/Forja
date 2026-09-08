import 'package:forja/shared/foundation/services/follow/my_list_merge.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart';

/// Query for [aggregateMyListFeed] — status tab + optional Simkl hide keys.
class MyListFeedQuery {
  const MyListFeedQuery({
    this.status = 'plantowatch',
    this.hiddenKeys = const {},
  });

  final String status;
  final Set<String> hiddenKeys;

  factory MyListFeedQuery.fromHostParams(Map<String, dynamic>? params) {
    final p = params ?? const {};
    final statusRaw = (p['status'] ?? p['listStatus'] ?? 'plantowatch')
        .toString()
        .trim();
    final status = statusRaw.isEmpty ? 'plantowatch' : statusRaw;
    final keysRaw = p['hiddenKeys'] ?? p['hidden_keys'];
    final hidden = <String>{};
    if (keysRaw is List) {
      for (final k in keysRaw) {
        final s = k.toString().trim();
        if (s.isNotEmpty) hidden.add(s);
      }
    } else if (keysRaw is String && keysRaw.trim().isNotEmpty) {
      for (final part in keysRaw.split(',')) {
        final s = part.trim();
        if (s.isNotEmpty) hidden.add(s);
      }
    }
    return MyListFeedQuery(status: status, hiddenKeys: hidden);
  }
}

/// Merge local bookmarks (+ Simkl when logged in) into opaque list row maps.
///
/// Called from `ctx.host.myList.load` (hub feed owns composition) — not from a
/// Dart KitListSource merge god path.
Future<List<Map<String, dynamic>>> aggregateMyListFeed(
  MyListFeedQuery query, {
  SimklService? simkl,
  MyListService? myList,
}) async {
  final list = myList ?? MyListService();
  await list.ensureLoaded();
  final allLocal = [
    for (final e in list.items) Map<String, dynamic>.from(e),
  ];
  final localForStatus = [
    for (final e in allLocal)
      if ((e['listStatus']?.toString() ?? 'plantowatch') == query.status)
        e,
  ];

  final simklSvc = simkl ?? SimklService();
  final loggedIn = await simklSvc.isLoggedIn();
  if (!loggedIn) return localForStatus;

  List<Map<String, dynamic>> simklRaw;
  try {
    simklRaw = await simklSvc.getWatchlistStatus(query.status);
  } catch (_) {
    return localForStatus;
  }
  final simklItems = [
    for (final raw in simklRaw) simklCardItem(raw),
  ].whereType<Map<String, dynamic>>().toList();
  final filteredSimkl = filterSimklByLocal(
    simklItems,
    allLocal,
    query.status,
    query.hiddenKeys,
  );
  return mergeLocalHubs(filteredSimkl, localForStatus);
}
