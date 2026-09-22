import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/engine/runtime/actions/iptv_sort/iptv_live_sort_providers.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/iptv_catalog_land.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja_foundation/blocks/catalog/catalog_channel_grid_focus.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/catalog_category_rail.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/live_favorite_star.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja/shared/engine/engine.dart';

/// Live category rail chrome — pack declares features; host owns store engines.
///
/// Mirrors [PortalsActionHost]: paint is foundation; pin/fav/watched/order SoT
/// is [PortalLiveChannelListsStore].
abstract final class CategoryBarActionHost {
  CategoryBarActionHost._();

  /// Last loaded Live list params for [packChromeFeedParams] (sync cache).
  static Map<String, dynamic> cachedLiveListParams = const {};

  static bool featuresEnabled(Map<String, dynamic> spec) {
    final raw = spec['features'];
    if (raw is! Map) return false;
    return raw['pin'] == true ||
        raw['reorder'] == true ||
        (raw['widgets'] is List && (raw['widgets'] as List).isNotEmpty);
  }

  static Widget buildRail(
    BuildContext context,
    WidgetRef ref, {
    required Map<String, dynamic> spec,
    required List<({String id, String label, String? icon})> seedItems,
    required String selectedId,
    required ValueChanged<String> onSelect,
    String? tabId,
    Widget? header,
  }) {
    return _CategoryBarRailHost(
      spec: spec,
      seedItems: seedItems,
      selectedId: selectedId,
      onSelect: onSelect,
      tabId: tabId,
      header: header,
    );
  }

  /// Opaque Live list ids for pack feed params.
  static Future<Map<String, dynamic>> liveListFeedParams({
    String? preferTabId,
  }) async {
    final portal = await _resolveActivePortal(preferTabId: preferTabId);
    if (portal == null) {
      cachedLiveListParams = const {};
      return const {};
    }
    final key = PortalAliveStore.portalKey(portal);
    final favs = await PortalLiveChannelListsStore.loadFavorites(key);
    final watched = await PortalLiveChannelListsStore.loadWatched(key);
    final pinned = await PortalLiveChannelListsStore.loadPinnedCategories(key);
    final order = await PortalLiveChannelListsStore.loadCategoryOrder(key);
    final out = <String, dynamic>{
      'favorites': favs.toList(),
      'watched': watched,
      'pinnedCats': pinned,
      'categoryOrder': order,
      'portalStoreKey': key,
    };
    cachedLiveListParams = out;
    return out;
  }

  static Future<void> recordWatched({
    required String portalKeyOrVaultKey,
    required String streamId,
  }) async {
    if (streamId.isEmpty) return;
    final portal = await _portalForKey(portalKeyOrVaultKey);
    if (portal == null) return;
    await PortalLiveChannelListsStore.recordWatched(
      PortalAliveStore.portalKey(portal),
      streamId,
    );
  }

  static Future<bool> toggleFavorite({
    required String portalKeyOrVaultKey,
    required String streamId,
  }) async {
    if (streamId.isEmpty) return false;
    final portal = await _portalForKey(portalKeyOrVaultKey);
    if (portal == null) return false;
    final key = PortalAliveStore.portalKey(portal);
    final next = await PortalLiveChannelListsStore.loadFavorites(key);
    final nowFav = !next.remove(streamId);
    if (nowFav) next.add(streamId);
    await PortalLiveChannelListsStore.saveFavorites(key, next);
    return nowFav;
  }

  static Future<Set<String>> loadFavoriteIds({
    required String portalKeyOrVaultKey,
  }) async {
    final portal = await _portalForKey(portalKeyOrVaultKey);
    if (portal == null) return {};
    return PortalLiveChannelListsStore.loadFavorites(
      PortalAliveStore.portalKey(portal),
    );
  }

  /// Favorite star for a live landscape card (props + callbacks only at DS).
  static Widget favoriteStar({
    required String portalKey,
    required String streamId,
    required bool reveal,
    double iconSize = 14,
  }) {
    return _LiveFavoriteStarHost(
      portalKey: portalKey,
      streamId: streamId,
      reveal: reveal,
      iconSize: iconSize,
    );
  }

  /// Vault `iptv.active` only — never invent the first inventory row.
  ///
  /// Feed params stamp `portalStoreKey` into [EngineCache]. Falling back to the
  /// first portal while active is empty cached the empty “Choose a portal”
  /// cover under that portal’s key, so selecting the first portal hit stale
  /// cache and the grid never loaded.
  static Future<Portal?> _resolveActivePortal({String? preferTabId}) async {
    try {
      final activeRaw = await EngineVault.get(PortalVaultKeys.active);
      final activeKey = (activeRaw ?? '').toString().trim();
      if (activeKey.isEmpty) return null;
      return PortalsHost.loadVaultPortal(activeKey);
    } catch (_) {
      return null;
    }
  }

  static Future<Portal?> _portalForKey(String key) async {
    final k = key.trim();
    if (k.isEmpty) return null;
    final byVault = await PortalsHost.loadVaultPortal(k);
    if (byVault != null) return byVault;
    // Full store key url|user|pass — match vault by url|user prefix.
    try {
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = jsonDecode(raw);
      if (parsed is! List) return null;
      for (final e in parsed) {
        if (e is! Map) continue;
        final p = Portal.fromJson(Map<String, dynamic>.from(e));
        if (PortalAliveStore.portalKey(p) == k) return p;
        if (PortalsHost.vaultPortalKey(Map<String, dynamic>.from(e)) == k) {
          return p;
        }
      }
    } catch (_) {}
    return null;
  }
}

final liveCategoryListsEpochProvider =
    StateProvider.family<int, String>((ref, tabId) => 0);

class _LiveFavoriteStarHost extends ConsumerStatefulWidget {
  const _LiveFavoriteStarHost({
    required this.portalKey,
    required this.streamId,
    required this.reveal,
    this.iconSize = 14,
  });

  final String portalKey;
  final String streamId;
  final bool reveal;
  final double iconSize;

  @override
  ConsumerState<_LiveFavoriteStarHost> createState() =>
      _LiveFavoriteStarHostState();
}

class _LiveFavoriteStarHostState extends ConsumerState<_LiveFavoriteStarHost> {
  bool? _fav;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _LiveFavoriteStarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamId != widget.streamId ||
        oldWidget.portalKey != widget.portalKey) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final ids = await CategoryBarActionHost.loadFavoriteIds(
      portalKeyOrVaultKey: widget.portalKey,
    );
    if (!mounted) return;
    setState(() => _fav = ids.contains(widget.streamId));
  }

  @override
  Widget build(BuildContext context) {
    return LiveFavoriteStar(
      favorited: _fav ?? false,
      reveal: widget.reveal,
      iconSize: widget.iconSize,
      onToggle: () async {
        final next = await CategoryBarActionHost.toggleFavorite(
          portalKeyOrVaultKey: widget.portalKey,
          streamId: widget.streamId,
        );
        await CategoryBarActionHost.liveListFeedParams();
        if (!mounted) return;
        setState(() => _fav = next);
      },
    );
  }
}

class _CategoryBarRailHost extends ConsumerStatefulWidget {
  const _CategoryBarRailHost({
    required this.spec,
    required this.seedItems,
    required this.selectedId,
    required this.onSelect,
    this.tabId,
    this.header,
  });

  final Map<String, dynamic> spec;
  final List<({String id, String label, String? icon})> seedItems;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String? tabId;
  final Widget? header;

  @override
  ConsumerState<_CategoryBarRailHost> createState() =>
      _CategoryBarRailHostState();
}

class _CategoryBarRailHostState extends ConsumerState<_CategoryBarRailHost> {
  List<CatalogCategoryItem> _items = const [];
  String? _storeKey;
  List<String> _pinned = const [];
  List<String> _order = const [];
  bool _loading = true;
  String? _boundSection;

  Map<String, dynamic> get _features {
    final raw = widget.spec['features'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  bool get _wantWidgets {
    final w = _features['widgets'];
    return w is List && w.isNotEmpty;
  }

  bool get _wantPin => _features['pin'] == true;
  bool get _wantReorder => _features['reorder'] == true;

  String get _section {
    final scope = LayoutScope.maybeOf(context);
    final catalogMenu = 'catalog';
    final sel = scope?.selectedId(catalogMenu) ?? '';
    return sel.isEmpty ? 'live' : sel;
  }

  bool get _isLive => _section == 'live' || _section.isEmpty;

  bool get _canReorder {
    if (!_wantReorder || !_isLive) return false;
    final categorySort = ref.watch(iptvLiveCategorySortProvider);
    final chrome = PackChromeScope.maybeOf(context);
    final q = (chrome?.eventQuery ?? '').trim();
    return categorySort == PortalCatalogSort.playlist && q.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    unawaited(hydrateIptvLiveSortProviders(ref));
    unawaited(_reload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final section = _section;
    if (_boundSection == section) return;
    final prev = _boundSection;
    _boundSection = section;
    if (prev == null) return;
    // Immediate wipe — do not keep Live Favorites/cats painted under Movies/Series.
    if (!_isLive) {
      setState(() {
        _items = const [];
        _loading = true;
        _storeKey = null;
        _pinned = const [];
        _order = const [];
      });
    }
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant _CategoryBarRailHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSeed(oldWidget.seedItems, widget.seedItems)) {
      unawaited(_reload());
    }
  }

  static bool _sameSeed(
    List<({String id, String label, String? icon})> a,
    List<({String id, String label, String? icon})> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].label != b[i].label) return false;
    }
    return true;
  }

  Future<void> _reload() async {
    final portal = await CategoryBarActionHost._resolveActivePortal(
      preferTabId: widget.tabId,
    );
    if (!mounted) return;
    if (portal == null || !_isLive) {
      setState(() {
        _storeKey = null;
        _pinned = const [];
        _order = const [];
        _items = _plainItems();
        _loading = false;
      });
      _ensureValidSelection(_items);
      return;
    }
    final key = PortalAliveStore.portalKey(portal);
    IptvCatalogLand.bindPortalKey(key);
    final pinned =
        await PortalLiveChannelListsStore.loadPinnedCategories(key);
    final order = await PortalLiveChannelListsStore.loadCategoryOrder(key);
    final lastCat = await PortalLiveChannelListsStore.loadLastCategory(key);
    await CategoryBarActionHost.liveListFeedParams(preferTabId: widget.tabId);
    if (!mounted) return;
    setState(() {
      _storeKey = key;
      _pinned = pinned;
      _order = order;
      _items = _buildItems(
        pinned: pinned,
        order: order,
        sort: ref.read(iptvLiveCategorySortProvider),
      );
      _loading = false;
    });
    _publishBar(chromeItems: _items);
    _ensureValidSelection(_items, preferCategoryId: lastCat);
    unawaited(IptvCatalogLand.hydrateHighlightFromStore());
  }

  List<CatalogCategoryItem> _plainItems() {
    return [
      for (final e in widget.seedItems)
        if (e.id.isNotEmpty &&
            e.id != 'all' &&
            !PortalLiveCatalog.isSyntheticId(e.id))
          CatalogCategoryItem(
            id: e.id,
            label: e.label,
            icon: catalogCategoryIconForId(e.id) ??
                _iconFromName(e.icon),
            fixed: true,
          ),
    ];
  }

  /// Movies/Series rail — same Categories sort as Live (no pin/reorder).
  List<CatalogCategoryItem> _vodItems(PortalCatalogSort sort) {
    final plain = _items.isNotEmpty ? _items : _plainItems();
    if (sort == PortalCatalogSort.playlist || plain.length < 2) {
      return plain;
    }
    final cats = [
      for (final e in plain) PortalCategory(id: e.id, name: e.label),
    ];
    final sorted = PortalLiveCatalog.sortCategories(cats, sort: sort);
    final byId = {for (final e in plain) e.id: e};
    return [
      for (final c in sorted)
        if (byId.containsKey(c.id)) byId[c.id]!,
    ];
  }

  List<CatalogCategoryItem> _buildItems({
    required List<String> pinned,
    required List<String> order,
    required PortalCatalogSort sort,
  }) {
    final byId = <String, ({String id, String label, String? icon})>{};
    for (final e in widget.seedItems) {
      if (e.id.isEmpty || e.id == 'all') continue;
      if (PortalLiveCatalog.isSyntheticId(e.id)) continue;
      byId[e.id] = e;
    }

    final cats = <PortalCategory>[
      for (final e in byId.values) PortalCategory(id: e.id, name: e.label),
    ];
    final sorted = PortalLiveCatalog.sortCategories(
      _wantWidgets ? PortalLiveCatalog.withPins(cats) : cats,
      sort: sort,
      userPinnedIds: pinned,
      customOrderIds: order,
    );

    final pinSet = pinned.toSet();
    return [
      for (final c in sorted)
        CatalogCategoryItem(
          id: c.id,
          label: c.name,
          icon: catalogCategoryIconForId(c.id) ??
              _iconFromName(byId[c.id]?.icon),
          fixed: PortalLiveCatalog.isSyntheticId(c.id),
          pinnable: _wantPin && !PortalLiveCatalog.isSyntheticId(c.id),
          pinned: pinSet.contains(c.id),
        ),
    ];
  }

  void _ensureValidSelection(
    List<CatalogCategoryItem> items, {
    String? preferCategoryId,
  }) {
    if (items.isEmpty) return;
    final sel = widget.selectedId.trim();
    if (sel.isNotEmpty && sel != 'all' && items.any((e) => e.id == sel)) {
      _armCatsFocusMemory(sel, items: items);
      return;
    }
    // Live only: restore last-played category when still in the rail.
    if (_isLive) {
      final prefer = (preferCategoryId ?? '').trim();
      if (prefer.isNotEmpty &&
          !PortalLiveCatalog.isSyntheticId(prefer) &&
          items.any((e) => e.id == prefer)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onSelect(prefer);
          _armCatsFocusMemory(prefer, items: items);
        });
        return;
      }
    }
    // Live + Movies/Series: no All row — land on first portal group
    // (skip Favorites / Already watched on Live).
    for (final e in items) {
      if (PortalLiveCatalog.isSyntheticId(e.id) || e.id == 'all') continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSelect(e.id);
        _armCatsFocusMemory(e.id, items: items);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSelect(items.first.id);
      _armCatsFocusMemory(items.first.id, items: items);
    });
  }

  void _onSelectCategory(String id) {
    widget.onSelect(id);
    _armCatsFocusMemory(id);
    if (_isLive) {
      unawaited(IptvCatalogLand.rememberCategory(id));
    }
  }

  /// Nav enter/restore remembered land → selected category (not a browse-only row).
  void _armCatsFocusMemory(
    String categoryId, {
    List<CatalogCategoryItem>? items,
  }) {
    final id = categoryId.trim();
    if (id.isEmpty) return;
    final tab = (widget.tabId ?? '').trim();
    if (tab.isEmpty) return;
    final list = items ?? _items;
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) return;
    ShellTvFocusCoordinator.setRowLastFocusedIndex(
      tab,
      IptvCatalogLand.catsRowId,
      index,
    );
  }

  void _publishBar({required List<CatalogCategoryItem> chromeItems}) {
    final chrome = PackChromeScope.maybeOf(context);
    final barId = (widget.spec['id'] ?? '').toString();
    if (chrome == null || barId.isEmpty) return;
    // Live-only — never restore Favorites/cats after Movies/Series wipe.
    if (!_isLive) return;
    final section = _section;
    final maps = <Map<String, dynamic>>[
      for (final e in chromeItems)
        {
          'id': e.id,
          'label': e.label,
          if (e.icon != null) 'icon': e.id,
        },
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _section != section || !_isLive) return;
      chrome.onDynamicBarItems(barId, maps);
    });
  }

  Future<void> _togglePin(String id) async {
    final key = _storeKey;
    if (key == null || PortalLiveCatalog.isSyntheticId(id) || id == 'all') {
      return;
    }
    final next = List<String>.from(_pinned);
    final pinning = !next.remove(id);
    if (pinning) next.insert(0, id);
    List<String>? order;
    if (pinning) {
      order = [
        for (final e in _items)
          if (!e.fixed && e.id != 'all') e.id,
      ];
      order.remove(id);
      order.insert(0, id);
    }
    await PortalLiveChannelListsStore.savePinnedCategories(key, next);
    if (order != null) {
      await PortalLiveChannelListsStore.saveCategoryOrder(key, order);
    }
    await CategoryBarActionHost.liveListFeedParams(preferTabId: widget.tabId);
    if (!mounted) return;
    setState(() {
      _pinned = next;
      if (order != null) _order = order;
      _items = _buildItems(
        pinned: next,
        order: order ?? _order,
        sort: ref.read(iptvLiveCategorySortProvider),
      );
    });
    _publishBar(chromeItems: _items);
    _bumpEpoch();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final key = _storeKey;
    if (key == null || !_canReorder) return;
    // onReorderItem already adjusts newIndex for the removed item.
    final movable = [for (final e in _items) if (!e.fixed) e.id];
    if (oldIndex < 0 ||
        oldIndex >= movable.length ||
        newIndex < 0 ||
        newIndex >= movable.length ||
        oldIndex == newIndex) {
      return;
    }
    final id = movable.removeAt(oldIndex);
    movable.insert(newIndex, id);
    final nextPins = [
      for (final pin in _pinned)
        if (movable.contains(pin)) pin,
    ];
    await PortalLiveChannelListsStore.saveCategoryOrder(key, movable);
    await PortalLiveChannelListsStore.savePinnedCategories(key, nextPins);
    await CategoryBarActionHost.liveListFeedParams(preferTabId: widget.tabId);
    if (!mounted) return;
    setState(() {
      _order = movable;
      _pinned = nextPins;
      _items = _buildItems(
        pinned: nextPins,
        order: movable,
        sort: ref.read(iptvLiveCategorySortProvider),
      );
    });
    _publishBar(chromeItems: _items);
    _bumpEpoch();
  }

  void _bumpEpoch() {
    final tab = (widget.tabId ?? '').trim();
    if (tab.isEmpty) return;
    ref.read(liveCategoryListsEpochProvider(tab).notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final tab = (widget.tabId ?? '').trim();
    if (tab.isNotEmpty) {
      ref.watch(liveCategoryListsEpochProvider(tab));
    }
    final categorySort = ref.watch(iptvLiveCategorySortProvider);
    final width = _d(context, 'width') ?? catalogSideRailWidth(context);
    final tvTab = tab.isNotEmpty ? tab : 'iptv';

    if (_loading && _items.isEmpty) {
      final loading = const ColoredBox(color: Color(0xFF141414));
      if (widget.header == null) {
        return SizedBox(width: width, child: loading);
      }
      return SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: widget.header!,
            ),
            Expanded(child: loading),
          ],
        ),
      );
    }

    final chrome = PackChromeScope.maybeOf(context);
    final q = (chrome?.eventQuery ?? '').trim().toLowerCase();
    final hitListenable = chrome?.searchHitKindIds;

    List<CatalogCategoryItem> applySearchFilter(
      List<CatalogCategoryItem> raw,
      Set<String> hits,
    ) {
      if (q.isEmpty) return raw;
      return [
        for (final c in raw)
          if (hits.contains(c.id) || c.label.toLowerCase().contains(q)) c,
      ];
    }

    Widget rail({
      required List<CatalogCategoryItem> items,
      ValueChanged<String>? onTogglePin,
      void Function(int oldIndex, int newIndex)? onReorder,
      required bool canReorder,
    }) {
      final scope = LayoutScope.maybeOf(context);
      final focusUp = scope?.resolveFocusEdge(
        (widget.spec['focusUp'] ?? '').toString(),
      );
      final enterChannels = scope?.resolveFocusEdge(
        (widget.spec['focusRight'] ?? '').toString(),
        last: true,
      );
      void enterItems() {
        // Focus the channel in front of this category (viewport-aligned). Never
        // select/reload. Fall back to remembered, then first.
        if (tvTab.isEmpty) {
          enterChannels?.call();
          return;
        }
        double? categoryY;
        final focusCtx = FocusManager.instance.primaryFocus?.context;
        final box = focusCtx?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          categoryY = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
        }
        if (CatalogChannelGridFocus.focusInFront(categoryGlobalY: categoryY)) {
          return;
        }
        final remembered = ShellTvFocusCoordinator.focusRowItemRemembered(
          tvTab,
          IptvCatalogLand.itemsRowId,
        );
        if (remembered) return;
        enterChannels?.call();
        ShellTvFocusCoordinator.focusRowItem(
          tvTab,
          IptvCatalogLand.itemsRowId,
          0,
        );
      }

      final child = CatalogCategoryRail(
        items: items,
        selectedId: widget.selectedId,
        width: width,
        rowHeight: _d(context, 'rowHeight'),
        fontSize: _d(context, 'fontSize'),
        iconSize: _d(context, 'iconSize'),
        rowPadH: _d(context, 'rowPadH'),
        listPadV: _d(context, 'listPadV') ?? catalogCategoryRailListPadV(context),
        pinSlotWidth:
            _d(context, 'pinSlotWidth') ?? catalogCategoryRailPinSlotWidth(context),
        onSelect: _onSelectCategory,
        onTogglePin: onTogglePin,
        onReorder: onReorder,
        canReorder: canReorder,
        header: widget.header,
        onTvEnterRight: enterItems,
        onTvFocusUp: focusUp,
        onScrollJumpReady: tvTab.isEmpty
            ? null
            : (jump) {
                ShellTvFocusCoordinator.setRowScrollIntoView(
                  tvTab,
                  IptvCatalogLand.catsRowId,
                  jump,
                );
              },
      );
      if (!ShellPaintScope.useTvFocusOf(context)) {
        return ShellPaintTvTabScope(tabId: tvTab, child: child);
      }
      return ShellPaintTvTabScope(
        tabId: tvTab,
        child: ShellPaintScope.tvRow(
          context: context,
          tabId: tvTab,
          rowId: IptvCatalogLand.catsRowId,
          sortOrder: 1,
          itemCount: items.length,
          axis: ShellPaintTvRowAxis.vertical,
          onFocusUp: focusUp,
          // Vertical panel — never walk sortOrder down into channels.
          onFocusDown: () {},
          child: child,
        ),
      );
    }

    // Movies/Series/Channels: fixed list (no pin/widgets), honor Categories sort.
    // Prefer cleared _items over stale Live seed until VOD/Channels republishes kinds.
    if (!_isLive) {
      final vodItems = _vodItems(categorySort);
      if (hitListenable == null) {
        return rail(
          items: applySearchFilter(vodItems, const {}),
          canReorder: false,
        );
      }
      return ValueListenableBuilder<Set<String>>(
        valueListenable: hitListenable,
        builder: (context, hits, _) {
          return rail(
            items: applySearchFilter(vodItems, hits),
            canReorder: false,
          );
        },
      );
    }

    final liveItems = _storeKey == null && _items.isEmpty
        ? _plainItems()
        : _buildItems(
            pinned: _pinned,
            order: _order,
            sort: categorySort,
          );
    if (hitListenable == null) {
      return rail(
        items: applySearchFilter(liveItems, const {}),
        onTogglePin: _wantPin ? _togglePin : null,
        onReorder: _wantReorder ? _reorder : null,
        canReorder: _canReorder,
      );
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: hitListenable,
      builder: (context, hits, _) {
        return rail(
          items: applySearchFilter(liveItems, hits),
          onTogglePin: _wantPin ? _togglePin : null,
          onReorder: _wantReorder ? _reorder : null,
          canReorder: _canReorder,
        );
      },
    );
  }

  /// Pack desktop px → TV × [ShellTokens.tvChromeScale].
  double? _d(BuildContext context, String k) {
    final raw = widget.spec[k];
    if (raw is! num) return null;
    return ShellTokens.chromeScale(
      raw.toDouble(),
      tv: ShellPaintScope.usesTvDensityOf(context),
    );
  }
}

IconData? _iconFromName(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty) return null;
  switch (n) {
    case 'grid':
    case 'grid_view':
      return Icons.grid_view_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'history':
      return Icons.history_rounded;
    default:
      return null;
  }
}
