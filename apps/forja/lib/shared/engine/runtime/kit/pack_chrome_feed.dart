import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/chrome/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

/// True when kind chips re-query the pack (Live Sports schedule).
/// IPTV Live category rail filters in paint — no horizon menu.
bool packChromeKindReloadsFeed(Map<String, dynamic> listSpec) {
  final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
  final horizonMenu = (listSpec['horizonMenu'] ?? '').toString().trim();
  return kindMenu.isNotEmpty && horizonMenu.isNotEmpty;
}

/// IPTV Movies/Series/Channels — category/sort/search must re-query.
bool packChromeVodPagedFeed(
  Map<String, dynamic> listSpec,
  LayoutScope? scope,
) {
  final catalogMenu = (listSpec['catalogMenu'] ?? '').toString().trim();
  if (catalogMenu.isEmpty) return false;
  final section = (scope?.selectedId(catalogMenu) ?? '').trim().toLowerCase();
  return section == 'movies' || section == 'series' || section == 'channels';
}

/// Params safe to satisfy from page `feed.rails[rail]` (no per-row extras
/// like `genreRow` — those must hit action:`rail` with full params).
bool packRailParamsAreFeedShared(Map<String, dynamic> params) {
  const allowed = {
    'rail',
    'limit',
    'page',
    'filter',
    'force',
    'refresh',
    '_poolPage',
  };
  for (final k in params.keys) {
    if (!allowed.contains(k)) return false;
  }
  return true;
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
  };
  // Hub tab id is not a feed page index — only stamp numeric pagination pages.
  final basePage = baseParams['page'];
  if (basePage is num ||
      (basePage is String &&
          basePage.trim().isNotEmpty &&
          int.tryParse(basePage.trim()) != null)) {
    params['page'] = basePage;
  } else if (tabId != null && tabId.trim().isNotEmpty) {
    params['hubPage'] = tabId.trim();
  }
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

  injectMenu('catalogMenu', 'catalogFilter', asAlso: 'section');
  // Always stamp section when the list declares a catalog menu — empty
  // selection must not silently default inside the pack to a stale Live fetch.
  final catalogMenu = (listSpec['catalogMenu'] ?? '').toString().trim();
  if (catalogMenu.isNotEmpty &&
      (params['section'] == null ||
          params['section'].toString().trim().isEmpty)) {
    final fallback = (scope?.selectedId(catalogMenu) ?? 'live').trim();
    params['section'] = fallback.isEmpty ? 'live' : fallback;
    params['catalogFilter'] = params['section'];
  }
  if (catalogMenu.isNotEmpty) {
    debugPrint(
      '[kit] ${pluginId} feed section=${params['section']} '
      'catalogFilter=${params['catalogFilter']}',
    );
  }

  final vodPaged = packChromeVodPagedFeed(listSpec, scope);

  // Live Sports (horizonMenu): kind → feed sportFilter (schedule re-query).
  // IPTV Live: kind is paint-only. IPTV Movies/Series: kind re-queries page 1.
  if (kindReloadsFeed || vodPaged) {
    final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
    final kind = scope?.selectedId(kindMenu);
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      params['kind'] = kind;
      params['categoryId'] = kind;
      if (kindReloadsFeed) {
        params['sport'] = kind;
        params['sportFilter'] = kind;
      }
    }
  }

  // Live Sports + IPTV VOD: sort/search re-query. IPTV Live stays paint-only.
  if (kindReloadsFeed || vodPaged) {
    injectMenu('sortMenu', 'sort');
  }
  injectMenu('horizonMenu', 'horizon');

  // View (cards / guide / list) is paint-only — do not put it in feed params
  // (that re-fetched IPTV catalog on every Cards↔EPG flip).

  final q = (chrome?.eventQuery ?? '').trim();
  if (q.isNotEmpty && (kindReloadsFeed || vodPaged)) params['q'] = q;

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

  final vodPaged = packChromeVodPagedFeed(listSpec, scope);
  final kindBustsFeed = kindReloadsFeed || vodPaged;

  return [
    status,
    // Sport chips + IPTV VOD cats reload feed; IPTV Live cats stay paint-only.
    kindBustsFeed ? sel('kindMenu') : '',
    sel('catalogMenu'),
    kindBustsFeed ? sel('sortMenu') : '',
    sel('horizonMenu'),
    // View is paint-only (cards↔EPG) — omit so PackLoadedPaint keeps items.
    kindBustsFeed ? (chrome?.eventQuery ?? '') : '',
    '${chrome?.refreshEpoch ?? 0}',
    catalogChromeFilterEpoch(tabId),
    // Fav/pin lists: paint filters Favorites/Watched; pin order is rail-only.
    // Do not bust catalog feed when lists warm or a star toggles.
  ].join('|');
}
