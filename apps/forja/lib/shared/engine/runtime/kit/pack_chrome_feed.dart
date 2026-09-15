import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/chrome/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

/// True when kind chips re-query the pack (Live Sports schedule).
/// IPTV category rail filters in paint — no horizon menu.
bool packChromeKindReloadsFeed(Map<String, dynamic> listSpec) {
  final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
  final horizonMenu = (listSpec['horizonMenu'] ?? '').toString().trim();
  return kindMenu.isNotEmpty && horizonMenu.isNotEmpty;
}

/// Merge layout chrome selections + PackChromeScope into opaque feed params.
Map<String, dynamic> packChromeFeedParams(
  BuildContext context, {
  required Map<String, dynamic> baseParams,
  required Map<String, dynamic> listSpec,
  String? tabId,
  required String pluginId,
}) {
  final scope = LayoutScope.maybeOf(context);
  final chrome = PackChromeScope.maybeOf(context);
  final params = <String, dynamic>{
    ...baseParams,
    'page': tabId ?? baseParams['page'],
  };
  final kindReloadsFeed = packChromeKindReloadsFeed(listSpec);

  void injectMenu(String key, String paramKey, {String? asAlso}) {
    final menuId = (listSpec[key] ?? '').toString().trim();
    if (menuId.isEmpty) return;
    final selected = scope?.selectedId(menuId);
    if (selected == null || selected.isEmpty) return;
    params[paramKey] = selected;
    if (asAlso != null) params[asAlso] = selected;
  }

  final statusTab = (listSpec['statusTab'] ?? '').toString().trim();
  if (statusTab.isNotEmpty) {
    params['status'] = scope?.selectedId(statusTab) ??
        listSpec['default']?.toString() ??
        params['status'] ??
        'plantowatch';
    params['listStatus'] = params['status'];
  }

  // Live Sports (horizonMenu): kind → feed sportFilter (schedule re-query).
  // IPTV / My List: kind is client-side only in paint_tree — do not pass
  // categoryId/kind into feed (that re-ran feed + EPG on every cat flip).
  if (kindReloadsFeed) {
    final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
    final kind = scope?.selectedId(kindMenu);
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      params['kind'] = kind;
      params['categoryId'] = kind;
      params['sport'] = kind;
      params['sportFilter'] = kind;
    }
  }

  injectMenu('catalogMenu', 'catalogFilter', asAlso: 'section');
  // IPTV search/sort filter painted items — do not re-fetch catalog.
  if (kindReloadsFeed) {
    injectMenu('sortMenu', 'sort');
  }
  injectMenu('horizonMenu', 'horizon');

  // View (cards / guide / list) is paint-only — do not put it in feed params
  // (that re-fetched IPTV catalog on every Cards↔EPG flip).

  final q = (chrome?.eventQuery ?? '').trim();
  if (q.isNotEmpty && kindReloadsFeed) params['q'] = q;

  // Live category lists from host store cache (Favorites / pins / order).
  final liveLists = CategoryBarActionHost.cachedLiveListParams;
  if (liveLists.isNotEmpty) {
    params.addAll(liveLists);
  }

  // Do NOT put force/refresh here. refreshEpoch already busts PackLoadedPaint's
  // selection epoch; a permanent force:true wiped live_sports.feed on every
  // sport/horizon change after the user tapped Refresh once.

  final filters = catalogChromeFilters(tabId: tabId, pluginId: pluginId);
  return catalogParamsWithFilters(params, filters: filters);
}

/// Epoch string so [PackLoadedPaint] reloads when chrome affecting feed changes.
String packChromeSelectionEpoch(
  BuildContext context, {
  required Map<String, dynamic> listSpec,
  String? tabId,
}) {
  final scope = LayoutScope.maybeOf(context);
  final chrome = PackChromeScope.maybeOf(context);
  final kindReloadsFeed = packChromeKindReloadsFeed(listSpec);

  String sel(String key) {
    final id = (listSpec[key] ?? '').toString().trim();
    if (id.isEmpty) return '';
    return scope?.selectedId(id) ?? '';
  }

  final statusTab = (listSpec['statusTab'] ?? '').toString();
  final status = statusTab.isEmpty
      ? ''
      : (scope?.selectedId(statusTab) ??
          listSpec['default']?.toString() ??
          'plantowatch');

  final horizonId = (listSpec['horizonMenu'] ?? '').toString().trim();

  return [
    status,
    // Sport chips reload feed; IPTV category rail filters in paint only.
    horizonId.isNotEmpty ? sel('kindMenu') : '',
    sel('catalogMenu'),
    // Live Sports sort re-queries; IPTV sort is paint-only.
    kindReloadsFeed ? sel('sortMenu') : '',
    sel('horizonMenu'),
    // View is paint-only (cards↔EPG) — omit so PackLoadedPaint keeps items.
    // IPTV search is paint-only; Live Sports search reloads schedule.
    kindReloadsFeed ? (chrome?.eventQuery ?? '') : '',
    '${chrome?.refreshEpoch ?? 0}',
    catalogChromeFilterEpoch(tabId),
    // Fav/pin lists: paint filters Favorites/Watched; pin order is rail-only.
    // Do not bust catalog feed when lists warm or a star toggles.
  ].join('|');
}
