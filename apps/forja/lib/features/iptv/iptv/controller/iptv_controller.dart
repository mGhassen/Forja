import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/iptv/iptv/data/hardcoded_channels.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
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
  /// Set of credKeys (user|pass) already verified — used to dedupe portals.
  /// Same credentials on a different URL still counts as a duplicate.
  final Set<String> _verifiedKeys = {};

  /// Set of credKeys we've already attempted (alive OR dead) during this
  /// session. Prevents re-testing portals that failed verification when the
  /// user presses Scrape / Get More repeatedly.
  final Set<String> _attemptedKeys = {};

  /// Untested portals scraped on previous Get-More presses.
  /// Consumed first before scraping a fresh page — never wasted.
  final List<IptvPortal> _pendingPortals = [];
  final Set<String> _pendingKeys = {};

  /// Favorite portal keys — pinned to the top of the list.
  final Set<String> _favoritePortals = {};

  /// Session-new portals (scrape / add / import) — visual badge only.
  final List<String> _newPortalKeys = [];

  /// Non-favorite display order: most recently added/scraped first.
  final List<String> _portalRecencyKeys = [];

  bool isFavoritePortal(String key) => _favoritePortals.contains(key);

  bool isNewPortal(String key) => _newPortalKeys.contains(key);

  /// Dismisses the "new" highlight only — does not reorder the list.
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
  List<IptvCategory> categories = const [];
  List<IptvStream> browserAllStreams = const [];
  /// In-session catalog cache: `portalKey|section` → last successful fetch.
  final Map<String, _CatalogSnap> _catalogCache = {};
  List<IptvEpisode> episodes = const [];
  String? error;

  String? browserSelectedCategoryId;
  String browserSearch = '';
  bool browserSearchOpen = false;

  /// Categories shown in the catalog sidebar (respects active search filter).
  List<IptvCategory> get browserSidebarCategories {
    final q = browserSearch.trim().toLowerCase();
    if (q.isEmpty) return categories;
    final selected = browserSelectedCategoryId;
    return categories.where((c) {
      if (c.id == selected) return true;
      if (c.id.isEmpty) return true;
      return c.name.toLowerCase().contains(q);
    }).toList();
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

  void closeBrowserSearch() {
    if (!browserSearchOpen && browserSearch.isEmpty) return;
    browserSearchOpen = false;
    browserSearch = '';
    notifyListeners();
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

  /// Per-stream health for live tiles: true=alive, false=dead, absent=unknown.
  final Map<String, bool> streamHealth = {};
  final Set<String> _healthInFlight = {};
  final List<IptvStream> _healthQueue = [];
  final Map<String, Timer> _healthDebounce = {};
  static const _maxLazyHealthChecks = 2;
  static const _lazyCheckDelay = Duration(milliseconds: 450);

  // ── EPG cache (live section only) ──
  /// Memoised `get_short_epg` results per stream for the current portal+section.
  /// Key = streamId. `null` value means "fetch in flight or finished with no
  /// data"; absent key means "not yet requested". Cleared on portal/section
  /// change. Wrapped in a Future so concurrent card builds dedupe to one call.
  final Map<String, Future<List<EpgEntry>>> _epgCache = {};

  bool _epgEnabled = true;

  IptvController() {
    _epgEnabled = SettingsService.iptvEpgEnabledNotifier.value;
    SettingsService.iptvEpgEnabledNotifier.addListener(_onEpgPrefChanged);
    unawaited(_syncEpgPref());
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
    }
    notifyListeners();
  }

  /// Lazy EPG fetch for a live stream. Returns the cached future (or fires a
  /// new request) so multiple `_StreamCard`s for the same id share one call.
  /// Safe to call from `FutureBuilder` — the Future is stable across rebuilds.
  Future<List<EpgEntry>> epgFor(IptvStream s, {int limit = 2}) {
    if (!_epgEnabled) return Future.value(const []);
    final p = activePortal;
    if (p == null || s.kind != 'live') {
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
  /// Lives for the controller's lifetime — re-running a scan on the same
  /// channel typically yields overlapping hits, so reuse is desirable.
  final Map<String, Future<List<EpgEntry>>> _hitEpgCache = {};

  /// Lazy EPG fetch for a hardcoded-channel hit. Same dedupe semantics as
  /// [epgFor] but keyed per (portal, stream).
  Future<List<EpgEntry>> epgForHit(ChannelHit h, {int limit = 2}) {
    if (!_epgEnabled) return Future.value(const []);
    if (h.stream.kind != 'live') {
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

  /// Favorite channel-hit URLs per channelId — pinned to the top.
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
    final stored = await IptvStore.load();
    _favoritePortals
      ..clear()
      ..addAll(await IptvStore.loadFavorites());
    _seedRecencyFrom(stored);
    verified = _sortPortals(stored);
    _verifiedKeys
      ..clear()
      ..addAll(stored.map((v) => v.credKey));
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
    final section = await IptvStore.loadLastSection();
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
    if (activeSection == section && !isLoading) return;
    if (activeSection != section) {
      activeSection = section;
      notifyListeners();
    }
    await openSection(section);
  }

  /// Force network reload for [section] (shelf reload control).
  Future<void> reloadSection(IptvSection section) async {
    if (activePortal == null) {
      openPortalPanel();
      notifyListeners();
      return;
    }
    await openSection(section, force: true);
  }

  Future<void> selectPortal(VerifiedPortal p, {bool closePanel = true}) async {
    activePortal = p;
    await IptvStore.saveLastPortalKey(p.key);
    if (closePanel) closePortalPanel();
    await openSection(IptvSection.live);
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
    SettingsService.iptvEpgEnabledNotifier
        .removeListener(_onEpgPrefChanged);
    cancelAllLazyChecks();
    super.dispose();
  }
}
