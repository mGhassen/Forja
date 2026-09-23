import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/actions/category_bar/category_bar_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

/// True when kind chips re-query the pack (Live Sports schedule).
/// IPTV Live category rail filters in paint — no horizon menu.
bool packChromeKindReloadsFeed(Map<String, dynamic> listSpec) {
  final kindMenu = (listSpec['kindMenu'] ?? '').toString().trim();
  final horizonMenu = (listSpec['horizonMenu'] ?? '').toString().trim();
  return kindMenu.isNotEmpty && horizonMenu.isNotEmpty;
}

/// IPTV Live/Movies/Series/Channels — category/sort/search must re-query
/// `catalog_page` (host shelf). Live used to paint-filter a full feed; under
/// issue 290 the feed is one page, so paint-filter leaves other cats empty.
bool packChromeVodPagedFeed(
  Map<String, dynamic> listSpec,
  LayoutScope? scope,
) {
  final catalogMenu = (listSpec['catalogMenu'] ?? '').toString().trim();
  if (catalogMenu.isEmpty) return false;
  final section = (scope?.selectedId(catalogMenu) ?? '').trim().toLowerCase();
  return section == 'live' ||
      section == 'movies' ||
      section == 'series' ||
      section == 'channels';
}

/// Params safe to satisfy from page `feed.rails[rail]` (no per-row extras
/// like `genreRow` — those must hit action:`rail` with full params).
///
/// [hubPage] is chrome tab id (not a TMDB page index). [maxPages] is host
/// pagination metadata. Both must stay allowed — Sep 16 `page`→`hubPage`
/// rename forgot `hubPage` and broke Home feed sharing (N parallel rails).
bool packRailParamsAreFeedShared(Map<String, dynamic> params) {
  const allowed = {
    'rail',
    'limit',
    'page',
    'hubPage',
    'maxPages',
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
    // Hide keys until Simkl refetch catches a local remove.
    try {
      final hidden = ProviderScope.containerOf(context, listen: false)
          .read(bookmarkHiddenKeysProvider);
      if (hidden.isNotEmpty) {
        params['hiddenKeys'] = hidden.toList(growable: false);
      }
    } catch (_) {}
  }

  injectMenu('catalogMenu', 'catalogFilter', asAlso: 'section');
  // Always stamp section when the list declares a catalog menu — empty
  // selection must match top-bar paint (`dynamicCatalogs` → all), not IPTV's
  // `live` section id (that filtered Live Sports to a non-existent plugin).
  final catalogMenu = (listSpec['catalogMenu'] ?? '').toString().trim();
  if (catalogMenu.isNotEmpty &&
      (params['section'] == null ||
          params['section'].toString().trim().isEmpty)) {
    final fallback = (scope?.selectedId(catalogMenu) ?? 'all').trim();
    params['section'] = fallback.isEmpty ? 'all' : fallback;
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
  // IPTV Live/Movies/Series: kind re-queries catalog_page (issue 290).
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

  // Live Sports + IPTV catalog sections: sort/search re-query.
  if (kindReloadsFeed || vodPaged) {
    injectMenu('sortMenu', 'sort');
  }
  injectMenu('horizonMenu', 'horizon');

  // View (cards / guide / list) is paint-only — do not put it in feed params
  // (that re-fetched IPTV catalog on every Cards↔EPG flip).

  final q = (chrome?.eventQuery ?? '').trim();
  if (q.isNotEmpty && (kindReloadsFeed || vodPaged)) params['q'] = q;

  // Live category lists (Favorites / pins / order) — IPTV / Live Sports only.
  // Never stamp onto Home/Anime rails or feed-share always fails after IPTV.
  final liveLists = CategoryBarActionHost.cachedLiveListParams;
  if ((kindReloadsFeed || vodPaged) && liveLists.isNotEmpty) {
    params.addAll(liveLists);
  }

  // Do NOT put force/refresh here. refreshEpoch already busts PackLoadedPaint's
  // selection epoch; a permanent force:true wiped live_sports.feed on every
  // sport/horizon change after the user tapped Refresh once.

  final filters = catalogChromeFilters(tabId: tabId, pluginId: pluginId);
  return catalogParamsWithFilters(params, filters: filters);
}

/// Epoch for IPTV empty-grid placeholder (category / Favorites / search flip).
///
/// Omits [portalStoreKey] and refresh — those rebind soft (keep last paint).
/// Hashing portal hydrate (`''` → key) as a flip wiped warm channels on hub open.
String packChromeGridFlipEpoch(
  BuildContext context, {
  required Map<String, dynamic> listSpec,
  String? tabId,
}) {
  final scope = LayoutScope.maybeOf(context);
  final chrome = PackChromeScope.maybeOf(context);
  final kindReloadsFeed = packChromeKindReloadsFeed(listSpec);
  final vodPaged = packChromeVodPagedFeed(listSpec, scope);
  final kindBustsFeed = kindReloadsFeed || vodPaged;

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
  final listEpoch = statusTab.trim().isEmpty
      ? ''
      : '${listFeedEpochListenable.value}';

  return [
    status,
    kindBustsFeed ? sel('kindMenu') : '',
    sel('catalogMenu'),
    kindBustsFeed ? sel('sortMenu') : '',
    sel('horizonMenu'),
    kindBustsFeed ? (chrome?.eventQuery ?? '') : '',
    listEpoch,
    catalogChromeFilterEpoch(tabId),
  ].join('|');
}

/// Epoch string so [PackLoadedPaint] reloads when chrome affecting feed changes.
String packChromeSelectionEpoch(
  BuildContext context, {
  required Map<String, dynamic> listSpec,
  String? tabId,
}) {
  final chrome = PackChromeScope.maybeOf(context);
  final scope = LayoutScope.maybeOf(context);
  final kindReloadsFeed = packChromeKindReloadsFeed(listSpec);
  final vodPaged = packChromeVodPagedFeed(listSpec, scope);

  final portalStoreKey =
      (CategoryBarActionHost.cachedLiveListParams['portalStoreKey'] ?? '')
          .toString();

  // portalStoreKey only for IPTV live shelf — hashing it on every Home/Anime
  // rail rebind when live-list prefs warm caused tab-return skeleton flashes.
  final portalEpoch =
      (vodPaged || kindReloadsFeed) ? portalStoreKey : '';

  return [
    packChromeGridFlipEpoch(
      context,
      listSpec: listSpec,
      tabId: tabId,
    ),
    '${chrome?.refreshEpoch ?? 0}',
    portalEpoch,
  ].join('|');
}
