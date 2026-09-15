import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/chrome/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

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

  injectMenu('kindMenu', 'kind');
  // Kind selection → categoryId for any kindMenu list (IPTV cats, etc.).
  // sport / sportFilter only when this list is Live Sports (has horizonMenu).
  final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
  if (kindMenu.isNotEmpty) {
    final kind = scope?.selectedId(kindMenu);
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      params['categoryId'] = kind;
      final horizonMenu = (listSpec['horizonMenu'] ?? '').toString().trim();
      if (horizonMenu.isNotEmpty) {
        params['sport'] = kind;
        params['sportFilter'] = kind;
      }
    }
  }

  injectMenu('catalogMenu', 'catalogFilter', asAlso: 'section');
  injectMenu('sortMenu', 'sort');
  injectMenu('horizonMenu', 'horizon');

  final viewMenu = (listSpec['viewMenu'] ?? 'view').toString().trim();
  final viewFromScope = viewMenu.isEmpty ? null : scope?.selectedId(viewMenu);
  final view = (viewFromScope ?? chrome?.viewStyle ?? '').trim();
  if (view.isNotEmpty) params['view'] = view;

  final q = (chrome?.eventQuery ?? '').trim();
  if (q.isNotEmpty) params['q'] = q;

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

  return [
    status,
    sel('kindMenu'),
    sel('catalogMenu'),
    sel('sortMenu'),
    sel('horizonMenu'),
    sel('viewMenu').isNotEmpty ? sel('viewMenu') : (chrome?.viewStyle ?? ''),
    chrome?.eventQuery ?? '',
    '${chrome?.refreshEpoch ?? 0}',
    catalogChromeFilterEpoch(tabId),
    '${CategoryBarActionHost.cachedLiveListParams['favorites']}',
    '${CategoryBarActionHost.cachedLiveListParams['pinnedCats']}',
    '${CategoryBarActionHost.cachedLiveListParams['categoryOrder']}',
  ].join('|');
}
