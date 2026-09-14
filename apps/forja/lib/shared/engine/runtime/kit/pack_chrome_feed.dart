import 'package:flutter/material.dart';
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
  // Client-side kind filter for IPTV cats / Live sports — also pass categoryId.
  final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
  if (kindMenu.isNotEmpty) {
    final kind = scope?.selectedId(kindMenu);
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      params['categoryId'] = kind;
      params['sport'] = kind;
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

  final refresh = chrome?.refreshEpoch ?? 0;
  if (refresh > 0) {
    params['refresh'] = refresh;
    params['force'] = true;
  }

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
  ].join('|');
}
