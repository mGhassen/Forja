import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja/shared/engine/portals/store/portal_vault_inventory.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja_foundation/widgets/chrome/catalog_category_rail.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/live_favorite_star.dart';
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
  }) {
    return _CategoryBarRailHost(
      spec: spec,
      seedItems: seedItems,
      selectedId: selectedId,
      onSelect: onSelect,
      tabId: tabId,
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

  static Future<Portal?> _resolveActivePortal({String? preferTabId}) async {
    try {
      final activeRaw = await EngineVault.get(PortalVaultKeys.active);
      final activeKey = (activeRaw ?? '').toString().trim();
      if (activeKey.isNotEmpty) {
        final p = await PortalsHost.loadVaultPortal(activeKey);
        if (p != null) return p;
      }
      final raw = await EngineVault.get(PortalVaultKeys.portals);
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = jsonDecode(raw);
      if (parsed is! List || parsed.isEmpty) return null;
      final first = parsed.first;
      if (first is! Map) return null;
      return Portal.fromJson(Map<String, dynamic>.from(first));
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
  });

  final Map<String, dynamic> spec;
  final List<({String id, String label, String? icon})> seedItems;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String? tabId;

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
    final scope = LayoutScope.maybeOf(context);
    final sort = scope?.selectedId('sort') ?? 'playlist';
    final chrome = PackChromeScope.maybeOf(context);
    final q = (chrome?.eventQuery ?? '').trim();
    return sort == 'playlist' && q.isEmpty;
  }

  @override
  void initState() {
    super.initState();
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
      return;
    }
    final key = PortalAliveStore.portalKey(portal);
    final pinned =
        await PortalLiveChannelListsStore.loadPinnedCategories(key);
    final order = await PortalLiveChannelListsStore.loadCategoryOrder(key);
    await CategoryBarActionHost.liveListFeedParams(preferTabId: widget.tabId);
    if (!mounted) return;
    setState(() {
      _storeKey = key;
      _pinned = pinned;
      _order = order;
      _items = _buildItems(pinned: pinned, order: order);
      _loading = false;
    });
    _publishBar(chromeItems: _items);
  }

  List<CatalogCategoryItem> _plainItems() {
    return [
      for (final e in widget.seedItems)
        CatalogCategoryItem(
          id: e.id,
          label: e.label,
          icon: catalogCategoryIconForId(e.id) ??
              _iconFromName(e.icon),
          fixed: true,
        ),
    ];
  }

  List<CatalogCategoryItem> _buildItems({
    required List<String> pinned,
    required List<String> order,
  }) {
    final byId = <String, ({String id, String label, String? icon})>{};
    for (final e in widget.seedItems) {
      if (e.id.isEmpty) continue;
      if (PortalLiveCatalog.isSyntheticId(e.id)) continue;
      byId[e.id] = e;
    }

    final cats = <PortalCategory>[
      for (final e in byId.values) PortalCategory(id: e.id, name: e.label),
    ];
    final sorted = PortalLiveCatalog.sortCategories(
      _wantWidgets ? PortalLiveCatalog.withPins(cats) : cats,
      userPinnedIds: pinned,
      customOrderIds: order,
    );

    final out = <CatalogCategoryItem>[];
    // Keep leading "all" if pack/host published it.
    final all = widget.seedItems.where((e) => e.id == 'all').toList();
    if (all.isNotEmpty) {
      out.add(
        CatalogCategoryItem(
          id: 'all',
          label: all.first.label.isEmpty ? 'All' : all.first.label,
          icon: catalogCategoryIconForId('all'),
          fixed: true,
        ),
      );
    }

    final pinSet = pinned.toSet();
    for (final c in sorted) {
      final seed = byId[c.id];
      final synthetic = PortalLiveCatalog.isSyntheticId(c.id);
      out.add(
        CatalogCategoryItem(
          id: c.id,
          label: c.name,
          icon: catalogCategoryIconForId(c.id) ??
              _iconFromName(seed?.icon),
          fixed: synthetic,
          pinnable: _wantPin && !synthetic && c.id != 'all',
          pinned: pinSet.contains(c.id),
        ),
      );
    }
    return out;
  }

  void _publishBar({required List<CatalogCategoryItem> chromeItems}) {
    final chrome = PackChromeScope.maybeOf(context);
    final barId = (widget.spec['id'] ?? '').toString();
    if (chrome == null || barId.isEmpty) return;
    final maps = <Map<String, dynamic>>[
      for (final e in chromeItems)
        {
          'id': e.id,
          'label': e.label,
          if (e.icon != null) 'icon': e.id,
        },
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
      _items = _buildItems(pinned: next, order: order ?? _order);
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
      _items = _buildItems(pinned: nextPins, order: movable);
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
    final width = (widget.spec['width'] is num)
        ? (widget.spec['width'] as num).toDouble()
        : 220.0;

    if (_loading && _items.isEmpty) {
      return SizedBox(
        width: width,
        child: const ColoredBox(color: Color(0xFF141414)),
      );
    }

    // Movies/Series: plain fixed list (no pin/widgets).
    if (!_isLive) {
      return CatalogCategoryRail(
        items: _plainItems(),
        selectedId: widget.selectedId,
        width: width,
        onSelect: widget.onSelect,
        canReorder: false,
      );
    }

    return CatalogCategoryRail(
      items: _items.isEmpty ? _plainItems() : _items,
      selectedId: widget.selectedId,
      width: width,
      onSelect: widget.onSelect,
      onTogglePin: _wantPin ? _togglePin : null,
      onReorder: _wantReorder ? _reorder : null,
      canReorder: _canReorder,
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
