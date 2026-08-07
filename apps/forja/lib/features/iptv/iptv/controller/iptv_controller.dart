import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/iptv/iptv/data/hardcoded_channels.dart';
import 'package:forja/features/iptv/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_store.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:forja/shared/design/design.dart';
part 'iptv_controller_portal.dart';
part 'iptv_controller_browser.dart';
part 'iptv_controller_live.dart';
part 'iptv_controller_channels.dart';
part 'iptv_controller_nav.dart';
part 'iptv_controller_models.dart';

enum IptvView {
  portalList,
  sectionPick,
  browser,
  episodeList,
  channelsHub,
  channelResults,
}
/// Central controller for the entire PT IPTV experience.
/// Mirrors IptvViewModel.kt; uses ChangeNotifier for Flutter rebuilds.
class IptvController extends ChangeNotifier
    with _IptvControllerPortal, _IptvControllerBrowser, _IptvControllerLive, _IptvControllerChannels, _IptvControllerNav {
  // ── Top-level view ──
  IptvView view = IptvView.browser;

  /// Right-side portal inventory panel (catalog workspace).
  bool portalPanelOpen = false;

  // ── Portal-list state ──
  bool isScraping = false;
  bool _scrapeCancel = false;
  String statusText = '';
  List<VerifiedPortal> verified = const [];

  /// Subset of [verified] that the user added manually. The portal-list
  /// screen only ever shows these; portals discovered automatically by
  /// the channel scraper are kept internally for channel results but are
  /// hidden from the user-facing portal list.
  List<VerifiedPortal> get manualVerified =>
      verified.where((v) => v.portal.source == 'Manual').toList();
  bool canGetMore = false;
  String? _scrapeAfter;
  /// Set of credKeys (user|pass) already verified - used to dedupe portals.
  /// Same credentials on a different URL still counts as a duplicate.
  final Set<String> _verifiedKeys = {};

  /// Set of credKeys we've already attempted (alive OR dead) during this
  /// session. Prevents re-testing portals that failed verification when the
  /// user presses Scrape / Get More repeatedly.
  final Set<String> _attemptedKeys = {};

  /// Untested portals scraped on previous Get-More presses.
  /// Consumed first before scraping a fresh page - never wasted.
  final List<IptvPortal> _pendingPortals = [];
  final Set<String> _pendingKeys = {};

  /// Favorite portal keys - pinned to the top of the list.
  final Set<String> _favoritePortals = {};

  /// Session-new portals (scrape / deal / add / import) - visual badge only.
  final List<String> _newPortalKeys = [];

  /// Non-favorite display order: most recently added/scraped first.
  final List<String> _portalRecencyKeys = [];

  bool isFavoritePortal(String key) => _favoritePortals.contains(key);

  bool isNewPortal(String key) => _newPortalKeys.contains(key);

  /// Dismisses the "new" highlight only - does not reorder the list.
  void markPortalSeen(String key) {
    if (_newPortalKeys.remove(key)) {
      notifyListeners();
    }
  }

  void _markPortalNew(String key) {
    _newPortalKeys.remove(key);
    _newPortalKeys.insert(0, key);
  }

  void _touchPortalRecency(String key) {
    _portalRecencyKeys.remove(key);
    _portalRecencyKeys.insert(0, key);
  }

  void _registerPortalAdded(String key) {
    _markPortalNew(key);
    _touchPortalRecency(key);
  }

  void _seedRecencyFrom(List<VerifiedPortal> list) {
    _portalRecencyKeys.clear();
    for (final v in list) {
      if (_favoritePortals.contains(v.key)) continue;
      if (!_portalRecencyKeys.contains(v.key)) {
        _portalRecencyKeys.add(v.key);
      }
    }
  }

  // Manual edit
  bool editMode = false;
  final Set<String> selected = {};
  bool showAddDialog = false;
  bool isAdding = false;
  String? addError;

  // ── Browsing state ──
  VerifiedPortal? activePortal;
  IptvSection? activeSection;
  IptvStream? activeSeries;

  bool isLoading = false;
  /// Shelf loads use [isLoading] spinner (one shelf at a time).
  IptvCatalogLoadStyle catalogLoadStyle = IptvCatalogLoadStyle.none;
  IptvCatalogLoadStep? catalogLoadStep;
  IptvCatalogLoadProgress catalogLoadProgress = IptvCatalogLoadProgress.empty;
  /// In-session catalog cache - static so tab eviction / new [IptvController]
  /// does not force a re-fetch. Shelves are also persisted via
  /// [IptvCatalogDiskStore] so app restart can skip network when warm.
  static final Map<String, _CatalogSnap> _sharedCatalogCache = () {
    final map = <String, _CatalogSnap>{};
    IptvCatalogDiskStore.onClearAll = map.clear;
    return map;
  }();

  /// Last successful catalog counts per portal (session; also prefs-backed).
  static final Map<String, IptvCatalogLoadProgress> _sharedPortalCatalogStats =
      {};

  /// Drop session catalog snaps (disk clear is separate).
  static void clearSharedCatalogCaches() {
    _sharedCatalogCache.clear();
  }

  Map<String, _CatalogSnap> get _catalogCache => _sharedCatalogCache;

  Map<String, IptvCatalogLoadProgress> get portalCatalogStats =>
      _sharedPortalCatalogStats;
  List<IptvCategory> categories = const [];
  List<IptvStream> browserAllStreams = const [];
  /// Bumped on every catalog open/reload so stale in-flight fetches are ignored.
  int _catalogLoadId = 0;
  List<IptvEpisode> episodes = const [];
  String? error;

  /// True when the active shelf has at least one portal (non-synthetic) group.
  bool get hasPortalCatalogGroups => categories.any(
        (c) =>
            c.id.isNotEmpty &&
            !IptvLiveCatalog.isSyntheticId(c.id),
      );

  String? browserSelectedCategoryId;
  String browserSearch = '';
  bool browserSearchOpen = false;

  /// True while a non-empty search filter is active (enter/exit category logic).
  bool _browserSearchFilterActive = false;

  /// Category selected before the active search filter (fallback on clear).
  String? _browserCategoryBeforeSearch;

  /// Category chosen during search (sidebar tap or played channel); wins on clear.
  String? _browserSearchCommittedCategoryId;

  /// Live catalog only - Movies/Series keep API order.
  IptvCatalogSort liveCategorySort = IptvCatalogSort.playlist;
  IptvCatalogSort liveContentSort = IptvCatalogSort.playlist;

  /// Live channel pane: cards grid or EPG timeline (desktop).
  IptvLiveBrowseLayout liveBrowseLayout = IptvLiveBrowseLayout.cards;

  /// Device-local Live channel favorites (stream ids) for the active portal.
  Set<String> liveFavoriteIds = const {};

  /// Device-local recently opened Live channels (stream ids, most-recent first).
  List<String> liveWatchedIds = const [];

  /// Device-local pinned Live category ids (order: first = under Already watched).
  /// Used when [liveCategoryOrderIds] is empty; pin also updates custom order.
  List<String> livePinnedCategoryIds = const [];

  /// Full manual Live category order (non-synthetic ids). Empty = playlist/pins.
  List<String> liveCategoryOrderIds = const [];

  /// Categories shown in the catalog sidebar (respects active search filter).
  List<IptvCategory> get browserSidebarCategories {
    final q = browserSearch.trim().toLowerCase();
    final filtered =
        q.isEmpty ? categories : _categoriesWithMatchingStreams(q);
    if (activeSection != IptvSection.live) return filtered;
    return sortCategories(
      filtered,
      liveCategorySort,
      userPinnedIds: livePinnedCategoryIds,
      customOrderIds: liveCategoryOrderIds,
    );
  }

  /// Sidebar rows for a global channel search: only groups that contain hits.
  List<IptvCategory> _categoriesWithMatchingStreams(String q) {
    final catNameById = <String, String>{
      for (final c in categories)
        if (!IptvLiveCatalog.isSyntheticId(c.id)) c.id: c.name.toLowerCase(),
    };
    bool streamMatches(IptvStream x) {
      if (x.name.toLowerCase().contains(q)) return true;
      final key = x.categoryId.isEmpty
          ? IptvCatalogOrphans.uncategorizedId
          : x.categoryId;
      final cn = catNameById[key];
      return cn != null && cn.contains(q);
    }

    var streams = browserAllStreams;
    if (activeSection == IptvSection.live &&
        liveOnly &&
        aliveStreamIds.isNotEmpty) {
      streams =
          streams.where((x) => aliveStreamIds.contains(x.streamId)).toList();
    }

    final matchingCatIds = <String>{};
    var favHit = false;
    var watchedHit = false;
    for (final x in streams) {
      if (!streamMatches(x)) continue;
      matchingCatIds.add(
        x.categoryId.isEmpty
            ? IptvCatalogOrphans.uncategorizedId
            : x.categoryId,
      );
      if (liveFavoriteIds.contains(x.streamId)) favHit = true;
      if (liveWatchedIds.contains(x.streamId)) watchedHit = true;
    }

    return categories.where((c) {
      if (c.id == IptvLiveCatalog.favoritesId) return favHit;
      if (c.id == IptvLiveCatalog.watchedId) return watchedHit;
      return matchingCatIds.contains(c.id);
    }).toList();
  }

  /// Categories with Live sort applied (no search filter) - channel guide.
  /// Synthetic Favorites / Already watched rows are omitted (guide uses groups).
  List<IptvCategory> get liveSortedCategories {
    final cats = categories
        .where((c) => !IptvLiveCatalog.isSyntheticId(c.id))
        .toList();
    if (activeSection != IptvSection.live) return cats;
    return sortCategories(
      cats,
      liveCategorySort,
      userPinnedIds: livePinnedCategoryIds,
      customOrderIds: liveCategoryOrderIds,
    );
  }

  bool isLiveCategoryPinned(String categoryId) =>
      livePinnedCategoryIds.contains(categoryId);

  bool get canReorderLiveCategories =>
      activeSection == IptvSection.live &&
      liveCategorySort == IptvCatalogSort.playlist &&
      browserSearch.trim().isEmpty;

  Future<void> toggleLiveCategoryPin(String categoryId) async {
    if (categoryId.isEmpty ||
        activeSection != IptvSection.live ||
        IptvLiveCatalog.isSyntheticId(categoryId)) {
      return;
    }
    final p = activePortal;
    if (p == null) return;
    final next = List<String>.from(livePinnedCategoryIds);
    final pinning = !next.remove(categoryId);
    if (pinning) next.insert(0, categoryId);
    livePinnedCategoryIds = next;
    List<String>? order;
    if (pinning) {
      // Pin → front of the movable list (and seed custom order if needed).
      order = _seedCategoryOrder();
      order.remove(categoryId);
      order.insert(0, categoryId);
      liveCategoryOrderIds = order;
    }
    notifyListeners();
    final key = IptvAliveStore.portalKey(p.portal);
    await IptvLiveChannelListsStore.savePinnedCategories(key, next);
    if (order != null) {
      await IptvLiveChannelListsStore.saveCategoryOrder(key, order);
    }
  }

  /// Drag-reorder among non-synthetic sidebar rows.
  /// [oldIndex]/[newIndex] are indices into the movable slice
  /// (Favorites / Already watched excluded). Uses [onReorderItem] semantics
  /// (newIndex already accounts for the removed item).
  Future<void> reorderLiveCategories(int oldIndex, int newIndex) async {
    if (!canReorderLiveCategories) return;
    final p = activePortal;
    if (p == null) return;
    final order = _seedCategoryOrder();
    if (oldIndex < 0 ||
        oldIndex >= order.length ||
        newIndex < 0 ||
        newIndex >= order.length ||
        oldIndex == newIndex) {
      return;
    }
    final id = order.removeAt(oldIndex);
    order.insert(newIndex, id);
    liveCategoryOrderIds = order;
    livePinnedCategoryIds = [
      for (final pin in livePinnedCategoryIds)
        if (order.contains(pin)) pin,
    ];
    notifyListeners();
    final key = IptvAliveStore.portalKey(p.portal);
    await IptvLiveChannelListsStore.saveCategoryOrder(key, order);
    await IptvLiveChannelListsStore.savePinnedCategories(
      key,
      livePinnedCategoryIds,
    );
  }

  /// Current non-synthetic sidebar order (matches movable drag indices).
  List<String> _seedCategoryOrder() {
    final current = sortCategories(
      categories.where((c) => !IptvLiveCatalog.isSyntheticId(c.id)).toList(),
      liveCategorySort,
      userPinnedIds: livePinnedCategoryIds,
      customOrderIds: liveCategoryOrderIds,
    );
    return [for (final c in current) c.id];
  }

  /// Streams with Live content sort applied - channel guide / catalog.
  List<IptvStream> liveSortedStreams(List<IptvStream> streams) {
    if (activeSection != IptvSection.live) return streams;
    return sortStreams(streams, liveContentSort);
  }

  bool isLiveFavorite(String streamId) => liveFavoriteIds.contains(streamId);

  Future<void> toggleLiveFavorite(String streamId) async {
    if (streamId.isEmpty || activeSection != IptvSection.live) return;
    final p = activePortal;
    if (p == null) return;
    final next = Set<String>.from(liveFavoriteIds);
    if (!next.remove(streamId)) next.add(streamId);
    liveFavoriteIds = next;
    notifyListeners();
    await IptvLiveChannelListsStore.saveFavorites(
      IptvAliveStore.portalKey(p.portal),
      next,
    );
  }

  Future<void> recordLiveWatched(String streamId) async {
    if (streamId.isEmpty || activeSection != IptvSection.live) return;
    final p = activePortal;
    if (p == null) return;
    liveWatchedIds = await IptvLiveChannelListsStore.recordWatched(
      IptvAliveStore.portalKey(p.portal),
      streamId,
    );
    notifyListeners();
  }

  /// Order: Favorites · Already watched · custom order / pins · remaining.
  static List<IptvCategory> sortCategories(
    List<IptvCategory> input,
    IptvCatalogSort sort, {
    List<String> userPinnedIds = const [],
    List<String> customOrderIds = const [],
  }) {
    if (input.length < 2 &&
        userPinnedIds.isEmpty &&
        customOrderIds.isEmpty) {
      return input;
    }
    final synthetic = <IptvCategory>[];
    final byId = <String, IptvCategory>{};
    for (final c in input) {
      if (IptvLiveCatalog.isSyntheticId(c.id)) {
        synthetic.add(c);
      } else {
        byId[c.id] = c;
      }
    }

    // Full manual order wins in playlist mode.
    if (sort == IptvCatalogSort.playlist && customOrderIds.isNotEmpty) {
      final ordered = <IptvCategory>[];
      final seen = <String>{};
      for (final id in customOrderIds) {
        final c = byId[id];
        if (c == null || !seen.add(id)) continue;
        ordered.add(c);
      }
      for (final c in byId.values) {
        if (seen.add(c.id)) ordered.add(c);
      }
      return [...synthetic, ...ordered];
    }

    final userPinSet = userPinnedIds.toSet();
    final userPinnedById = <String, IptvCategory>{};
    final rest = <IptvCategory>[];
    for (final c in byId.values) {
      if (userPinSet.contains(c.id)) {
        userPinnedById[c.id] = c;
      } else {
        rest.add(c);
      }
    }
    final userPinned = [
      for (final id in userPinnedIds)
        if (userPinnedById.containsKey(id)) userPinnedById[id]!,
    ];
    if (sort != IptvCatalogSort.playlist && rest.length >= 2) {
      rest.sort((a, b) {
        final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return sort == IptvCatalogSort.nameAsc ? cmp : -cmp;
      });
    }
    return [...synthetic, ...userPinned, ...rest];
  }

  static List<IptvStream> sortStreams(
    List<IptvStream> input,
    IptvCatalogSort sort,
  ) {
    if (sort == IptvCatalogSort.playlist || input.length < 2) return input;
    final out = List<IptvStream>.of(input);
    out.sort((a, b) {
      final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return sort == IptvCatalogSort.nameAsc ? cmp : -cmp;
    });
    return out;
  }

  Future<void> setLiveCategorySort(IptvCatalogSort sort) async {
    if (liveCategorySort == sort) return;
    liveCategorySort = sort;
    notifyListeners();
    await IptvStore.saveLiveCategorySort(sort);
  }

  Future<void> setLiveContentSort(IptvCatalogSort sort) async {
    if (liveContentSort == sort) return;
    liveContentSort = sort;
    notifyListeners();
    await IptvStore.saveLiveContentSort(sort);
  }

  /// D-pad focus index for the selected category in [browserSidebarCategories].
  int get browserCategoryFocusIndex {
    final selected = browserSelectedCategoryId;
    final idx = browserSidebarCategories.indexWhere((c) => c.id == selected);
    return idx >= 0 ? idx : 0;
  }

  void toggleBrowserSearch() {
    if (browserSearchOpen) {
      closeBrowserSearch();
    } else {
      browserSearchOpen = true;
      notifyListeners();
    }
  }

  void openBrowserSearch() {
    if (browserSearchOpen) return;
    browserSearchOpen = true;
    notifyListeners();
  }

  /// True when [browserSearch] matches at least one stream by name or group.
  bool get browserSearchHasMatchingStreams {
    final q = browserSearch.trim().toLowerCase();
    if (q.isEmpty) return false;
    final catNameById = <String, String>{
      for (final c in categories)
        if (!IptvLiveCatalog.isSyntheticId(c.id)) c.id: c.name.toLowerCase(),
    };
    for (final x in browserAllStreams) {
      if (x.name.toLowerCase().contains(q)) return true;
      final key = x.categoryId.isEmpty
          ? IptvCatalogOrphans.uncategorizedId
          : x.categoryId;
      final cn = catNameById[key];
      if (cn != null && cn.contains(q)) return true;
    }
    return false;
  }

  void closeBrowserSearch() {
    if (!browserSearchOpen && browserSearch.isEmpty) return;
    browserSearchOpen = false;
    if (browserSearch.trim().isNotEmpty) {
      _exitBrowserSearchFilter();
    }
    browserSearch = '';
    notifyListeners();
  }

  void _enterBrowserSearchFilter() {
    if (_browserSearchFilterActive) return;
    _browserSearchFilterActive = true;
    _browserCategoryBeforeSearch = browserSelectedCategoryId;
    _browserSearchCommittedCategoryId = null;
    browserSelectedCategoryId = null;
  }

  void _exitBrowserSearchFilter() {
    if (!_browserSearchFilterActive) return;
    final committed = _browserSearchCommittedCategoryId;
    final before = _browserCategoryBeforeSearch;
    _browserSearchFilterActive = false;
    _browserSearchCommittedCategoryId = null;
    _browserCategoryBeforeSearch = null;
    if (committed != null && committed.isNotEmpty) {
      browserSelectedCategoryId = committed;
    } else if (before != null) {
      browserSelectedCategoryId = before;
    } else {
      browserSelectedCategoryId = _defaultCategoryId(categories);
    }
  }

  /// Remember a category chosen during search (sidebar or played channel).
  void _commitBrowserSearchCategory(String categoryId) {
    if (!_browserSearchFilterActive || categoryId.isEmpty) return;
    _browserSearchCommittedCategoryId = categoryId;
  }

  // ── Live alive checking ──
  bool liveOnly = false;
  Set<String> aliveStreamIds = const {};
  bool isVerifyingAlive = false;
  int aliveChecked = 0;
  int aliveTotal = 0;
  int aliveCount = 0;
  int? aliveCheckedAt;
  bool _aliveCancel = false;

  /// Per-stream health for catalog tiles: true=alive, false=dead, absent=unknown.
  final Map<String, bool> streamHealth = {};
  /// Wall-clock ms when [streamHealth] was last written (lazy / bulk probe).
  final Map<String, int> _streamHealthCheckedAtMs = {};
  final Set<String> _healthInFlight = {};
  final List<IptvStream> _healthQueue = [];
  final Map<String, Timer> _healthDebounce = {};
  static const _maxLazyHealthChecks = 2;
  /// Dwell before focus/hover probes fire — skip channels you only skim past.
  static const _lazyCheckDelay = Duration(milliseconds: 350);

  // ── EPG cache (live section only) ──
  /// Memoised `get_short_epg` results per stream for the current portal+section.
  /// Key = streamId. `null` value means "fetch in flight or finished with no
  /// data"; absent key means "not yet requested". Cleared on portal/section
  /// change. Wrapped in a Future so concurrent card builds dedupe to one call.
  final Map<String, Future<List<EpgEntry>>> _epgCache = {};

  /// Session cache for Live guide raw listings (`get_simple_data_table`,
  /// clipped to the 6h/24h guide window). Keyed by streamId. One fetch per
  /// channel; UI slices visible hours client-side.
  final Map<String, Future<List<EpgEntry>>> _guideEpgCache = {};
  static const guideHoursBehind = 6.0;
  static const guideHoursAhead = 24.0;

  bool _epgEnabled = true;
  bool _disposed = false;

  IptvController() {
    _epgEnabled = SettingsService.iptvEpgEnabledNotifier.value;
    SettingsService.iptvEpgEnabledNotifier.addListener(_onEpgPrefChanged);
    IptvStore.listRevision.addListener(_onStoreListRevision);
    unawaited(_syncEpgPref());
    unawaited(_loadLiveSortPrefs());
    unawaited(_loadLiveBrowseLayoutPref());
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  Future<void> _loadLiveSortPrefs() async {
    final category = await IptvStore.loadLiveCategorySort();
    final content = await IptvStore.loadLiveContentSort();
    if (_disposed) return;
    if (liveCategorySort == category && liveContentSort == content) return;
    liveCategorySort = category;
    liveContentSort = content;
    notifyListeners();
  }

  Future<void> _loadLiveBrowseLayoutPref() async {
    final layout = await IptvStore.loadLiveBrowseLayout();
    if (_disposed) return;
    if (liveBrowseLayout == layout) return;
    liveBrowseLayout = layout;
    notifyListeners();
  }

  Future<void> setLiveBrowseLayout(IptvLiveBrowseLayout layout) async {
    if (liveBrowseLayout == layout) return;
    liveBrowseLayout = layout;
    notifyListeners();
    await IptvStore.saveLiveBrowseLayout(layout);
  }

  bool get epgEnabled => _epgEnabled;

  Future<void> _syncEpgPref() async {
    final enabled = await SettingsService().isIptvEpgEnabled();
    SettingsService.iptvEpgEnabledNotifier.value = enabled;
    _epgEnabled = enabled;
  }

  void _onEpgPrefChanged() {
    final enabled = SettingsService.iptvEpgEnabledNotifier.value;
    if (_epgEnabled == enabled) return;
    _epgEnabled = enabled;
    if (!enabled) {
      _epgCache.clear();
      _hitEpgCache.clear();
      _guideEpgCache.clear();
    }
    notifyListeners();
  }

  /// Guide window anchored around [now] (floored to half-hour).
  static ({DateTime start, DateTime end}) guideWindow({DateTime? now}) {
    final n = now ?? DateTime.now();
    final flooredMinute = n.minute >= 30 ? 30 : 0;
    final anchor = DateTime(n.year, n.month, n.day, n.hour, flooredMinute);
    final start = anchor.subtract(Duration(minutes: (guideHoursBehind * 60).round()));
    final end = start.add(
      Duration(minutes: ((guideHoursBehind + guideHoursAhead) * 60).round()),
    );
    return (start: start, end: end);
  }

  /// Ensures guide listings for [s] are fetched (once). Stable Future for
  /// [FutureBuilder] - UI slices visible hours from the result.
  Future<List<EpgEntry>> guideEpgFor(IptvStream s) {
    if (!_epgEnabled) return Future.value(const []);
    final p = activePortal;
    if (p == null ||
        s.kind != 'live' ||
        p.platform != IptvPortalPlatform.xtream) {
      return Future.value(const []);
    }
    if (s.streamId.isEmpty && s.epgChannelId.isEmpty) {
      return Future.value(const []);
    }
    final cacheKey = s.streamId.isEmpty ? s.epgChannelId : s.streamId;
    return _guideEpgCache.putIfAbsent(cacheKey, () async {
      final window = guideWindow();
      if (s.streamId.isNotEmpty) {
        final rows = await IptvClient.simpleDataTable(
          p.portal,
          s.streamId,
          windowStart: window.start,
          windowEnd: window.end,
        );
        if (rows.isNotEmpty) return rows;
      }
      if (s.epgChannelId.isNotEmpty && s.epgChannelId != s.streamId) {
        return IptvClient.simpleDataTable(
          p.portal,
          s.epgChannelId,
          windowStart: window.start,
          windowEnd: window.end,
        );
      }
      return const [];
    });
  }

  void _onStoreListRevision() {
    if (_disposed) return;
    unawaited(_softReloadPortalsFromStore());
  }

  /// Pull portals/favorites from [IptvStore] after an external CSV import.
  Future<void> _softReloadPortalsFromStore() async {
    final stored = await IptvStore.load();
    if (_disposed) return;
    final favorites = await IptvStore.loadFavorites();
    if (_disposed) return;
    _favoritePortals
      ..clear()
      ..addAll(favorites);
    final knownKeys = stored.map((v) => v.key).toSet();
    for (final key in _portalRecencyKeys.toList()) {
      if (!knownKeys.contains(key)) _portalRecencyKeys.remove(key);
    }
    for (final v in stored) {
      if (!_portalRecencyKeys.contains(v.key) &&
          !_favoritePortals.contains(v.key)) {
        _portalRecencyKeys.add(v.key);
      }
    }
    verified = _sortPortals(stored);
    _verifiedKeys
      ..clear()
      ..addAll(stored.map((v) => v.credKey));
    final active = activePortal;
    if (active != null && !knownKeys.contains(active.key)) {
      activePortal = null;
      activeSection = null;
      await IptvStore.clearLastPortalKey();
      if (_disposed) return;
    } else if (active != null) {
      for (final v in verified) {
        if (v.key == active.key) {
          activePortal = v;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Lazy EPG fetch for a live stream. Returns the cached future (or fires a
  /// new request) so multiple `_StreamCard`s for the same id share one call.
  /// Safe to call from `FutureBuilder` - the Future is stable across rebuilds.
  Future<List<EpgEntry>> epgFor(IptvStream s, {int limit = 2}) {
    if (!_epgEnabled) return Future.value(const []);
    final p = activePortal;
    if (p == null ||
        s.kind != 'live' ||
        p.platform != IptvPortalPlatform.xtream) {
      return Future.value(const []);
    }
    if (s.streamId.isEmpty && s.epgChannelId.isEmpty) {
      return Future.value(const []);
    }
    final cacheKey = '${s.streamId.isEmpty ? s.epgChannelId : s.streamId}:$limit';
    return _epgCache.putIfAbsent(
      cacheKey,
      () async {
        if (s.streamId.isNotEmpty) {
          final rows =
              await IptvClient.shortEpg(p.portal, s.streamId, limit: limit);
          if (rows.isNotEmpty) return rows;
        }
        if (s.epgChannelId.isNotEmpty && s.epgChannelId != s.streamId) {
          return IptvClient.shortEpg(p.portal, s.epgChannelId, limit: limit);
        }
        return const [];
      },
    );
  }

  /// EPG cache for ChannelHit cards (Channels Hub). Keyed by
  /// `portal.key|streamId` because hits come from many different portals.
  /// Lives for the controller's lifetime - re-running a scan on the same
  /// channel typically yields overlapping hits, so reuse is desirable.
  final Map<String, Future<List<EpgEntry>>> _hitEpgCache = {};

  /// Lazy EPG fetch for a hardcoded-channel hit. Same dedupe semantics as
  /// [epgFor] but keyed per (portal, stream).
  Future<List<EpgEntry>> epgForHit(ChannelHit h, {int limit = 2}) {
    if (!_epgEnabled) return Future.value(const []);
    if (h.stream.kind != 'live' ||
        h.portal.platform != IptvPortalPlatform.xtream) {
      return Future.value(const []);
    }
    final streamId = h.stream.streamId;
    final epgId = h.stream.epgChannelId;
    if (streamId.isEmpty && epgId.isEmpty) {
      return Future.value(const []);
    }
    final key =
        '${h.portal.key}|${streamId.isEmpty ? epgId : streamId}|$epgId|$limit';
    return _hitEpgCache.putIfAbsent(
      key,
      () async {
        if (streamId.isNotEmpty) {
          final rows = await IptvClient.shortEpg(
            h.portal.portal,
            streamId,
            limit: limit,
          );
          if (rows.isNotEmpty) return rows;
        }
        if (epgId.isNotEmpty && epgId != streamId) {
          return IptvClient.shortEpg(h.portal.portal, epgId, limit: limit);
        }
        return const [];
      },
    );
  }

  // ── Channels Hub ──
  HardcodedChannel? activeHardcoded;
  String channelStatus = '';
  bool channelIsRunning = false;
  List<ChannelHit> channelResults = const [];
  bool _channelCancel = false;

  /// Favorite channel-hit URLs per channelId - pinned to the top.
  final Map<String, Set<String>> _favoriteHits = {};
  bool isFavoriteHit(String channelId, ChannelHit h) =>
      _favoriteHits[channelId]?.contains(h.streamUrl) ?? false;

  // Per-channel scan state (resumable)
  final Map<String, Set<String>> _channelAttempted = {}; // channelId → portalKey set
  final Map<String, String?> _channelCatalogAfter = {}; // channelId → catalog cursor
  final Map<String, List<IptvPortal>> _channelScrapedPool = {};

  /// Per-channel queue of UN-verified portals scraped from previous Get-More
  /// presses. Drained first before fetching a fresh catalog page so we never
  /// throw away portals we already paid the network cost to find.
  final Map<String, List<IptvPortal>> _channelPendingPortals = {};
  final Map<String, Set<String>> _channelPendingKeys = {};

  // ── Init ──
  Future<void> init() async {
    // Fresh flags/credits from cloud (admin toggles) before portal chrome builds.
    unawaited(SyncService.instance.pullAccountFeatures());
    var stored = await IptvStore.load();
    final migrated = await M3uStore.migrateToPortalsIfNeeded();
    if (migrated.isNotEmpty) {
      final byCred = {for (final v in stored) v.credKey: v};
      for (final v in migrated) {
        byCred.putIfAbsent(v.credKey, () => v);
      }
      stored = byCred.values.toList();
      await IptvStore.save(stored);
    }
    _favoritePortals
      ..clear()
      ..addAll(await IptvStore.loadFavorites());
    _seedRecencyFrom(stored);
    verified = _sortPortals(stored);
    _verifiedKeys
      ..clear()
      ..addAll(stored.map((v) => v.credKey));
    await _loadCatalogStatsFromStore();
    await _restoreLastPortal();
  }

  Future<void> _restoreLastPortal() async {
    view = IptvView.browser;
    final lastKey = await IptvStore.loadLastPortalKey();
    if (lastKey == null) {
      activePortal = null;
      activeSection = null;
      notifyListeners();
      return;
    }
    VerifiedPortal? portal;
    for (final v in verified) {
      if (v.key == lastKey) {
        portal = v;
        break;
      }
    }
    if (portal == null) {
      activePortal = null;
      activeSection = null;
      await IptvStore.clearLastPortalKey();
      notifyListeners();
      return;
    }
    activePortal = portal;
    // Arm spinner before health probe notifyListeners / store awaits.
    isLoading = true;
    error = null;
    browserAllStreams = const [];
    categories = const [];
    notifyListeners();
    ensurePortalHealth(portal);
    var section = await IptvStore.loadLastSection();
    if (!portal.platform.supportsVodSeries && section != IptvSection.live) {
      section = IptvSection.live;
    }
    await openSection(section, persistSection: false);
  }

  void togglePortalPanel() {
    portalPanelOpen = !portalPanelOpen;
    notifyListeners();
  }

  void openPortalPanel() {
    if (!portalPanelOpen) {
      portalPanelOpen = true;
      notifyListeners();
    }
  }

  void closePortalPanel() {
    if (portalPanelOpen) {
      portalPanelOpen = false;
      notifyListeners();
    }
  }

  Future<void> requestSection(IptvSection section) async {
    if (activePortal == null) {
      openPortalPanel();
      notifyListeners();
      return;
    }
    if (!activePortal!.platform.supportsVodSeries &&
        section != IptvSection.live) {
      section = IptvSection.live;
    }
    if (activeSection == section && !isLoading) return;
    // openSection arms loading before any paint — do not notify with an
    // empty shelf here (that flashed Reload + fake load error).
    await openSection(section);
  }

  /// Force network reload for [section] (shelf reload control).
  Future<void> reloadSection(IptvSection section) async {
    final portal = activePortal;
    if (portal == null) {
      openPortalPanel();
      notifyListeners();
      return;
    }
    refreshPortalHealth(portal);
    await openSection(section, force: true);
  }

  Future<void> selectPortal(VerifiedPortal p, {bool closePanel = true}) async {
    activePortal = p;
    // Arm spinner before health / store / panel notifies paint empty error UI.
    isLoading = true;
    error = null;
    browserAllStreams = const [];
    categories = const [];
    notifyListeners();
    ensurePortalHealth(p);
    await IptvStore.saveLastPortalKey(p.key);
    if (closePanel) closePortalPanel();
    var section = await IptvStore.loadLastSection();
    if (!p.platform.supportsVodSeries && section != IptvSection.live) {
      section = IptvSection.live;
    }
    await openSection(section);
  }

  List<VerifiedPortal> _sortPortals(List<VerifiedPortal> list) {
    final byKey = {for (final v in list) v.key: v};
    final seen = <String>{};
    final out = <VerifiedPortal>[];

    void addUnique(VerifiedPortal v) {
      if (seen.add(v.key)) out.add(v);
    }

    for (final v in list) {
      if (_favoritePortals.contains(v.key)) addUnique(v);
    }
    for (final key in _portalRecencyKeys) {
      if (_favoritePortals.contains(key)) continue;
      final v = byKey[key];
      if (v != null) addUnique(v);
    }
    for (final v in list) {
      if (!seen.contains(v.key)) addUnique(v);
    }
    return out;
  }

  List<ChannelHit> _sortHitsFavoritesFirst(
      String channelId, List<ChannelHit> list) {
    final favs = _favoriteHits[channelId] ?? const <String>{};
    if (favs.isEmpty) return list;
    final f = <ChannelHit>[];
    final r = <ChannelHit>[];
    for (final h in list) {
      if (favs.contains(h.streamUrl)) {
        f.add(h);
      } else {
        r.add(h);
      }
    }
    return [...f, ...r];
  }

  Future<void> toggleFavoritePortal(String key) async {
    if (_favoritePortals.contains(key)) {
      _favoritePortals.remove(key);
    } else {
      _favoritePortals.add(key);
    }
    verified = _sortPortals(verified);
    await IptvStore.saveFavorites(_favoritePortals);
    notifyListeners();
  }

  Future<void> toggleFavoriteHit(ChannelHit h) async {
    final ch = activeHardcoded;
    if (ch == null) return;
    final set = _favoriteHits.putIfAbsent(ch.id, () => <String>{});
    if (set.contains(h.streamUrl)) {
      set.remove(h.streamUrl);
    } else {
      set.add(h.streamUrl);
    }
    channelResults = _sortHitsFavoritesFirst(ch.id, channelResults);
    await IptvChannelFavoritesStore.save(ch.id, set);
    notifyListeners();
  }
  @override
  void dispose() {
    _disposed = true;
    SettingsService.iptvEpgEnabledNotifier
        .removeListener(_onEpgPrefChanged);
    IptvStore.listRevision.removeListener(_onStoreListRevision);
    cancelAllLazyChecks();
    _cancelAllPortalHealthTimers();
    portalHealth.clear();
    _portalHealthInFlight.clear();
    super.dispose();
  }
}
