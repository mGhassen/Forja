import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/iptv/iptv/data/hardcoded_channels.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';

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
class IptvController extends ChangeNotifier {
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

  // ────────────────────────────────────────────────────────────────────────
  // Portal-list actions
  // ────────────────────────────────────────────────────────────────────────
  Future<void> scrape() async {
    if (isScraping) return;
    isScraping = true;
    _scrapeCancel = false;
    statusText = 'Finding portals…';
    canGetMore = false;
    notifyListeners();
    await _scrapeAndVerify();
  }

  void stopScrape() {
    _scrapeCancel = true;
    statusText = 'Stopped.';
    notifyListeners();
  }

  Future<void> getMore() async {
    if (isScraping) return;
    isScraping = true;
    _scrapeCancel = false;
    statusText = 'Searching for more…';
    notifyListeners();
    await _scrapeAndVerify();
  }

  Future<void> _scrapeAndVerify() async {
    const targetAlive = 5;
    // Hard safety cap so a totally dead source can't loop forever.
    const maxPagesPerPress = 40;
    final newAlive = <VerifiedPortal>[];
    ScrapePage? page;
    var pagesTried = 0;
    var exhausted = false;
    var emptyPagesInRow = 0;

    try {
      // Outer loop: keep fetching catalog pages and verifying them until we
      // collect [targetAlive] live portals OR the source runs out of pages
      // OR we hit the safety cap.
      while (newAlive.length < targetAlive &&
          pagesTried < maxPagesPerPress &&
          !_scrapeCancel) {
        // ── Step 1: fetch fresh pages until the pending queue has work.
        //         (Pending queue may already be non-empty from a prior
        //         press that found enough alive portals before draining
        //         everything — in that case we skip the fetch entirely.)
        while (_pendingPortals.isEmpty &&
            pagesTried < maxPagesPerPress &&
            !_scrapeCancel) {
          pagesTried++;
          page = await IptvScraper.scrapeCatalogPage(
            maxResults: 50,
            after: _scrapeAfter,
          );
          _scrapeAfter = page.nextAfter;

          // Add only portals we haven't already verified, attempted, or queued.
          // Dedup is by credentials (user|pass) — same login on a different
          // host still counts as a duplicate.
          for (final p in page.portals) {
            if (_verifiedKeys.contains(p.credKey)) continue;
            if (_attemptedKeys.contains(p.credKey)) continue;
            if (_pendingKeys.contains(p.credKey)) continue;
            _pendingKeys.add(p.credKey);
            _pendingPortals.add(p);
          }

          if (page.portals.isEmpty) {
            emptyPagesInRow++;
            // Unified catalog: stop after many empty pages across backends.
            if (emptyPagesInRow >= IptvScraper.catalogSubCount + 8) {
              exhausted = true;
              break;
            }
          } else {
            emptyPagesInRow = 0;
          }

          // No more pages from this source — bail out of the fetch loop.
          if (_pendingPortals.isEmpty && !page.hasMore) {
            exhausted = true;
            break;
          }
        }

        if (_scrapeCancel) break;

        if (_pendingPortals.isEmpty) {
          // Nothing left to verify and nothing left to fetch.
          break;
        }

        // ── Step 2: verify what we've got. Only ask the verifier for
        //         however many MORE alive portals we still need this press.
        final remaining = targetAlive - newAlive.length;
        statusText =
            'Verifying ${_pendingPortals.length} portals  ·  need $remaining more';
        notifyListeners();

        final snapshot = List<IptvPortal>.from(_pendingPortals);
        await IptvVerifier.verifyUntil(
          portals: snapshot,
          target: remaining,
          isCancelled: () => _scrapeCancel,
          onAttempted: (p) {
            _attemptedKeys.add(p.credKey);
            if (_pendingKeys.remove(p.credKey)) {
              _pendingPortals.removeWhere((x) => x.credKey == p.credKey);
            }
          },
          onProgress: (c, t, a) {
            final total = newAlive.length + a;
            statusText =
                'Verifying $c / $t  ·  alive $total / $targetAlive';
            notifyListeners();
          },
          onAlive: (v) {
            if (_verifiedKeys.add(v.credKey)) {
              newAlive.add(v);
              _registerPortalAdded(v.key);
              verified = _sortPortals([...verified, v]);
              notifyListeners();
            }
          },
        );

        // If we still need more and the queue is dry, the outer loop will
        // fetch the next page automatically. If the source has no more
        // pages either, we'll exit cleanly on the next iteration.
        if (newAlive.length < targetAlive &&
            _pendingPortals.isEmpty &&
            (page == null || !page.hasMore)) {
          exhausted = true;
          break;
        }
      }

      if (newAlive.isNotEmpty) await IptvStore.save(verified);

      // Get-More is meaningful if either (a) we still have queued portals
      // we haven't verified yet, or (b) the catalog has more pages.
      canGetMore = _pendingPortals.isNotEmpty ||
          (page?.hasMore ?? canGetMore);

      if (_scrapeCancel) {
        statusText = 'Stopped.';
      } else if (newAlive.isEmpty) {
        statusText = exhausted
            ? 'No live portals found.'
            : (canGetMore
                ? 'No new live portals. Try Get More.'
                : 'No new live portals.');
      } else {
        final hit = newAlive.length >= targetAlive;
        statusText = hit
            ? 'Found ${newAlive.length} live portals.'
            : 'Found ${newAlive.length} live portals'
                '${exhausted ? ' (catalog exhausted).' : ' (stopped early).'}';
        if (_pendingPortals.isNotEmpty) {
          statusText += ' (${_pendingPortals.length} more queued)';
        }
      }
    } catch (e) {
      statusText = 'Scrape failed: $e';
    } finally {
      isScraping = false;
      notifyListeners();
    }
  }

  Future<void> runVerification() async {
    final manual = manualVerified;
    if (manual.isEmpty) return;
    statusText = 'Re-checking saved portals…';
    notifyListeners();
    // Only re-verify user-added (Manual) portals. Internally-scraped
    // ones are kept untouched so the channel hub can still use them.
    final manualKeys = manual.map((v) => v.key).toSet();
    final scrapedKept = verified.where((v) => !manualKeys.contains(v.key)).toList();
    final freshManual = <VerifiedPortal>[];
    for (final v in manual) {
      final fresh = await IptvClient.verifyOrNull(v.portal);
      if (fresh != null) freshManual.add(fresh);
    }
    verified = _sortPortals([...freshManual, ...scrapedKept]);
    _verifiedKeys
      ..clear()
      ..addAll(verified.map((v) => v.credKey));
    await IptvStore.save(verified);
    statusText = '${freshManual.length} portals still alive.';
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Edit / select / delete portals
  // ────────────────────────────────────────────────────────────────────────
  void toggleEditMode() {
    editMode = !editMode;
    if (!editMode) selected.clear();
    notifyListeners();
  }

  void toggleSelect(String key) {
    if (selected.contains(key)) {
      selected.remove(key);
    } else {
      selected.add(key);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (selected.length == verified.length) {
      selected.clear();
    } else {
      selected
        ..clear()
        ..addAll(verified.map((v) => v.key));
    }
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (selected.isEmpty) return;
    for (final k in selected) {
      _invalidatePortalCatalogCache(k);
      _newPortalKeys.remove(k);
      _portalRecencyKeys.remove(k);
    }
    final keep = verified.where((v) => !selected.contains(v.key)).toList();
    verified = keep;
    _verifiedKeys
      ..clear()
      ..addAll(keep.map((v) => v.credKey));
    if (activePortal != null && selected.contains(activePortal!.key)) {
      activePortal = null;
      activeSection = null;
      categories = const [];
      browserAllStreams = const [];
      await IptvStore.clearLastPortalKey();
    }
    selected.clear();
    editMode = false;
    await IptvStore.save(keep);
    notifyListeners();
  }

  Future<void> deletePortal(String key) async {
    _invalidatePortalCatalogCache(key);
    selected
      ..clear()
      ..add(key);
    await deleteSelected();
  }

  Future<void> updatePortal({
    required VerifiedPortal existing,
    required String url,
    required String username,
    required String password,
  }) async {
    final cleanUrl = normalizeUrl(url);
    if (cleanUrl.isEmpty || username.isEmpty || password.isEmpty) {
      addError = 'All fields required';
      notifyListeners();
      return;
    }
    isAdding = true;
    addError = null;
    notifyListeners();
    final p = IptvPortal(
      url: cleanUrl,
      username: username.trim(),
      password: password.trim(),
      source: existing.portal.source.isEmpty ? 'Manual' : existing.portal.source,
    );
    if (p.credKey != existing.credKey && _verifiedKeys.contains(p.credKey)) {
      addError = 'Portal already added (same username & password)';
      isAdding = false;
      notifyListeners();
      return;
    }
    final v = await IptvClient.verifyOrNull(p);
    isAdding = false;
    if (v == null) {
      addError = 'Login failed — wrong credentials or dead portal.';
      notifyListeners();
      return;
    }
    final wasActive = activePortal?.key == existing.key;
    _invalidatePortalCatalogCache(existing.key);
    final next = verified
        .where((x) => x.key != existing.key)
        .toList();
    verified = _sortPortals([v, ...next]);
    _verifiedKeys
      ..clear()
      ..addAll(verified.map((x) => x.credKey));
    await IptvStore.save(verified);
    if (wasActive) {
      await selectPortal(v);
    } else {
      notifyListeners();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Add manual portal
  // ────────────────────────────────────────────────────────────────────────
  void openAddDialog() {
    showAddDialog = true;
    addError = null;
    notifyListeners();
  }

  void dismissAddDialog() {
    if (isAdding) return;
    showAddDialog = false;
    addError = null;
    notifyListeners();
  }

  Future<void> addManual({
    required String url,
    required String username,
    required String password,
  }) async {
    final cleanUrl = normalizeUrl(url);
    if (cleanUrl.isEmpty || username.isEmpty || password.isEmpty) {
      addError = 'All fields required';
      notifyListeners();
      return;
    }
    isAdding = true;
    addError = null;
    notifyListeners();
    final p = IptvPortal(
      url: cleanUrl,
      username: username.trim(),
      password: password.trim(),
      source: 'Manual',
    );
    if (_verifiedKeys.contains(p.credKey)) {
      addError = 'Portal already added (same username & password)';
      isAdding = false;
      notifyListeners();
      return;
    }
    final v = await IptvClient.verifyOrNull(p);
    isAdding = false;
    if (v == null) {
      addError = 'Login failed — wrong credentials or dead portal.';
      notifyListeners();
      return;
    }
    _registerPortalAdded(v.key);
    verified = _sortPortals([v, ...verified]);
    _verifiedKeys.add(v.credKey);
    await IptvStore.save(verified);
    showAddDialog = false;
    await selectPortal(v);
  }

  String normalizeUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Bulk import from JSON
  // ────────────────────────────────────────────────────────────────────────
  bool isImporting = false;

  /// Decode a username/password value: tolerates URL-encoded forms like
  /// `live%3Apersian_share` -> `live:persian_share`. Falls back to raw
  /// input when decoding throws.
  String _decodeCred(String raw) {
    final s = raw.trim();
    if (!s.contains('%')) return s;
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  /// Parses a JSON file (string contents) of the form
  /// `{ "portals": [ { "url", "username", "password", ... }, ... ] }`
  /// and verifies + saves each unique entry as a Manual portal.
  ///
  /// Returns a (added, skipped, failed) tuple. `skipped` counts entries
  /// already present in the local list; `failed` counts entries the
  /// Xtream login refused or that didn't parse.
  Future<({int added, int skipped, int failed, String? error})>
      importFromJsonString(String contents) async {
    if (isImporting) {
      return (added: 0, skipped: 0, failed: 0, error: 'Already importing.');
    }
    List<IptvPortal> candidates;
    try {
      final decoded = json.decode(contents);
      List<dynamic> raw;
      if (decoded is Map<String, dynamic>) {
        final p = decoded['portals'];
        if (p is List) {
          raw = p;
        } else {
          return (
            added: 0,
            skipped: 0,
            failed: 0,
            error: 'JSON missing "portals" array.'
          );
        }
      } else if (decoded is List) {
        raw = decoded;
      } else {
        return (
          added: 0,
          skipped: 0,
          failed: 0,
          error: 'Unsupported JSON shape.'
        );
      }
      candidates = [];
      for (final e in raw) {
        if (e is! Map) continue;
        final url = normalizeUrl(e['url']?.toString() ?? '');
        final user = _decodeCred(e['username']?.toString() ?? '');
        final pass = _decodeCred(e['password']?.toString() ?? '');
        if (url.isEmpty || user.isEmpty || pass.isEmpty) continue;
        candidates.add(IptvPortal(
          url: url,
          username: user,
          password: pass,
          source: 'Manual',
        ));
      }
    } catch (e) {
      return (added: 0, skipped: 0, failed: 0, error: 'Invalid JSON: $e');
    }

    if (candidates.isEmpty) {
      return (
        added: 0,
        skipped: 0,
        failed: 0,
        error: 'No portal entries found.'
      );
    }

    isImporting = true;
    statusText = 'Importing 0 / ${candidates.length}…';
    notifyListeners();

    int added = 0, skipped = 0, failed = 0, done = 0;
    final newAlive = <VerifiedPortal>[];
    final seenInBatch = <String>{};

    Future<void> work(IptvPortal p) async {
      // Dedupe across the batch and against existing list.
      if (_verifiedKeys.contains(p.credKey) ||
          !seenInBatch.add(p.credKey)) {
        skipped++;
      } else {
        final v = await IptvClient.verifyOrNull(p);
        if (v == null) {
          failed++;
        } else {
          // Tag as Manual even if the existing entry was scraped: this
          // promotes the user-imported portal into the visible list.
          final manualV = VerifiedPortal(
            portal: IptvPortal(
              url: v.portal.url,
              username: v.portal.username,
              password: v.portal.password,
              source: 'Manual',
            ),
            name: v.name,
            expiry: v.expiry,
            maxConnections: v.maxConnections,
            activeConnections: v.activeConnections,
          );
          newAlive.add(manualV);
          _verifiedKeys.add(manualV.credKey);
          added++;
        }
      }
      done++;
      statusText = 'Importing $done / ${candidates.length}…';
      notifyListeners();
    }

    // Verify in parallel — same approach as scrape verifier, but simpler.
    const concurrency = 8;
    var idx = 0;
    Future<void> worker() async {
      while (idx < candidates.length) {
        final i = idx++;
        await work(candidates[i]);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    if (newAlive.isNotEmpty) {
      for (final v in newAlive) {
        _registerPortalAdded(v.key);
      }
      verified = _sortPortals([...newAlive, ...verified]);
      await IptvStore.save(verified);
    }

    isImporting = false;
    statusText = 'Imported $added · skipped $skipped · failed $failed';
    notifyListeners();
    return (added: added, skipped: skipped, failed: failed, error: null);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Open portal / sections
  // ────────────────────────────────────────────────────────────────────────
  void openPortal(VerifiedPortal p) {
    unawaited(selectPortal(p));
  }

  Future<void> openSection(
    IptvSection section, {
    bool persistSection = true,
    bool force = false,
  }) async {
    final p = activePortal;
    if (p == null) return;
    final cacheKey = _catalogCacheKey(p.key, section);

    if (!force) {
      final snap = _catalogCache[cacheKey];
      if (snap != null) {
        activeSection = section;
        view = IptvView.browser;
        isLoading = false;
        error = null;
        categories = snap.categories;
        browserAllStreams = snap.streams;
        browserSelectedCategoryId = '';
        browserSearch = '';
        browserSearchOpen = false;
        streamHealth.clear();
        _healthInFlight.clear();
        _healthQueue.clear();
        cancelAllLazyChecks();
        _epgCache.clear();
        if (section == IptvSection.live) {
          final key = IptvAliveStore.portalKey(p.portal);
          liveOnly = await IptvAliveStore.loadLiveOnly(key);
          final alive = await IptvAliveStore.load(key);
          if (alive != null) {
            aliveStreamIds = alive.aliveIds;
            aliveCheckedAt = alive.checkedAt;
            _seedHealthFromCache();
          } else {
            aliveStreamIds = const {};
            aliveCheckedAt = null;
          }
        } else {
          liveOnly = false;
          aliveStreamIds = const {};
          aliveCheckedAt = null;
        }
        if (persistSection) {
          await IptvStore.saveLastSection(section);
        }
        notifyListeners();
        return;
      }
    }

    activeSection = section;
    view = IptvView.browser;
    isLoading = true;
    error = null;
    categories = const [];
    browserAllStreams = const [];
    browserSelectedCategoryId = null;
    browserSearch = '';
    browserSearchOpen = false;
    aliveStreamIds = const {};
    aliveCheckedAt = null;
    streamHealth.clear();
    _healthInFlight.clear();
    _healthQueue.clear();
    cancelAllLazyChecks();
    _epgCache.clear();
    notifyListeners();
    try {
      final cats = await IptvClient.categories(p.portal, section);
      final streams = await IptvClient.streams(p.portal, section, '');
      categories = [const IptvCategory(id: '', name: 'All'), ...cats];
      browserAllStreams = streams;
      browserSelectedCategoryId = '';

      if (streams.isEmpty && cats.isEmpty) {
        error = 'Could not load channels from portal';
      }

      if (section == IptvSection.live) {
        final key = IptvAliveStore.portalKey(p.portal);
        liveOnly = await IptvAliveStore.loadLiveOnly(key);
        final snap = await IptvAliveStore.load(key);
        if (snap != null) {
          aliveStreamIds = snap.aliveIds;
          aliveCheckedAt = snap.checkedAt;
          _seedHealthFromCache();
        }
      } else {
        liveOnly = false;
      }

      _catalogCache[cacheKey] = _CatalogSnap(
        categories: categories,
        streams: browserAllStreams,
      );
    } catch (e) {
      error = '$e';
    } finally {
      isLoading = false;
      if (persistSection) {
        await IptvStore.saveLastSection(section);
      }
      notifyListeners();
    }
  }

  String _catalogCacheKey(String portalKey, IptvSection section) =>
      '$portalKey|${section.name}';

  void _invalidatePortalCatalogCache(String portalKey) {
    final prefix = '$portalKey|';
    _catalogCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  void _seedHealthFromCache() {
    for (final id in aliveStreamIds) {
      streamHealth[id] = true;
    }
  }

  /// Queue a health probe after the card has stayed visible (debounced).
  void scheduleLazyCheck(IptvStream s) {
    final p = activePortal;
    if (p == null || activeSection != IptvSection.live) return;
    if (s.kind != 'live' || s.streamId.isEmpty) return;
    if (streamHealth.containsKey(s.streamId)) return;
    if (_healthInFlight.contains(s.streamId)) return;

    _healthDebounce[s.streamId]?.cancel();
    _healthDebounce[s.streamId] = Timer(_lazyCheckDelay, () {
      _healthDebounce.remove(s.streamId);
      lazyCheckStream(s);
    });
  }

  void cancelLazyCheck(String streamId) {
    _healthDebounce[streamId]?.cancel();
    _healthDebounce.remove(streamId);
  }

  void cancelAllLazyChecks() {
    for (final t in _healthDebounce.values) {
      t.cancel();
    }
    _healthDebounce.clear();
  }

  /// Probe a single live stream — capped concurrency, called after debounce.
  void lazyCheckStream(IptvStream s) {
    final p = activePortal;
    if (p == null || activeSection != IptvSection.live) return;
    if (s.kind != 'live' || s.streamId.isEmpty) return;
    if (streamHealth.containsKey(s.streamId)) return;
    if (_healthInFlight.contains(s.streamId)) return;
    if (_healthInFlight.length >= _maxLazyHealthChecks) {
      if (!_healthQueue.any((x) => x.streamId == s.streamId)) {
        _healthQueue.add(s);
      }
      return;
    }
    unawaited(_runLazyHealthCheck(s));
  }

  Future<void> _runLazyHealthCheck(IptvStream s) async {
    final p = activePortal;
    if (p == null) return;
    _healthInFlight.add(s.streamId);
    try {
      final url = IptvClient.streamUrl(p.portal, s);
      final ok = await IptvAliveChecker.checkOne(url);
      streamHealth[s.streamId] = ok;
      if (ok) {
        aliveStreamIds = {...aliveStreamIds, s.streamId};
      }
      notifyListeners();
    } catch (_) {
      streamHealth[s.streamId] = false;
      notifyListeners();
    } finally {
      _healthInFlight.remove(s.streamId);
      _drainHealthQueue();
    }
  }

  void _drainHealthQueue() {
    while (_healthQueue.isNotEmpty &&
        _healthInFlight.length < _maxLazyHealthChecks) {
      final next = _healthQueue.removeAt(0);
      if (!streamHealth.containsKey(next.streamId)) {
        unawaited(_runLazyHealthCheck(next));
      }
    }
  }

  void markStreamDead(String streamId) {
    if (streamId.isEmpty) return;
    streamHealth[streamId] = false;
    notifyListeners();
  }

  bool? healthFor(String streamId) => streamHealth[streamId];

  // ── Portal panel live probes (hover / focus) ──
  final Map<String, bool> portalHealth = {};
  final Set<String> _portalHealthInFlight = {};
  final Map<String, Timer> _portalHealthDebounce = {};
  static const _portalHealthDelay = Duration(milliseconds: 350);

  bool? portalHealthFor(String key) => portalHealth[key];

  void schedulePortalHealthCheck(VerifiedPortal v) {
    final key = v.key;
    if (key.isEmpty) return;
    if (portalHealth.containsKey(key)) return;
    if (_portalHealthInFlight.contains(key)) return;
    _portalHealthDebounce[key]?.cancel();
    _portalHealthDebounce[key] = Timer(_portalHealthDelay, () {
      _portalHealthDebounce.remove(key);
      unawaited(_runPortalHealthCheck(v));
    });
  }

  void cancelPortalHealthCheck(String key) {
    _portalHealthDebounce[key]?.cancel();
    _portalHealthDebounce.remove(key);
  }

  Future<void> _runPortalHealthCheck(VerifiedPortal v) async {
    final key = v.key;
    if (portalHealth.containsKey(key)) return;
    if (!_portalHealthInFlight.add(key)) return;
    notifyListeners();
    try {
      final fresh = await IptvClient.verifyOrNull(
        v.portal,
        timeout: const Duration(seconds: 5),
      );
      portalHealth[key] = fresh != null;
      notifyListeners();
    } catch (_) {
      portalHealth[key] = false;
      notifyListeners();
    } finally {
      _portalHealthInFlight.remove(key);
      notifyListeners();
    }
  }

  bool isPortalHealthChecking(String key) =>
      _portalHealthInFlight.contains(key);

  void selectBrowserCategory(String id) {
    browserSelectedCategoryId = id;
    notifyListeners();
  }

  void setBrowserSearch(String q) {
    browserSearch = q;
    notifyListeners();
  }

  Future<void> setLiveOnly(bool enabled) async {
    final p = activePortal;
    if (p == null) return;
    liveOnly = enabled;
    await IptvAliveStore.saveLiveOnly(IptvAliveStore.portalKey(p.portal), enabled);
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Alive checking (Live category)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> startAliveCheck({bool force = false}) async {
    final p = activePortal;
    final section = activeSection;
    if (p == null || section != IptvSection.live) return;
    if (isVerifyingAlive) return;
    if (!force && aliveCheckedAt != null) return;

    final pkey = IptvAliveStore.portalKey(p.portal);
    final entries = browserAllStreams
        .map((s) => MapEntry(s.streamId, IptvClient.streamUrl(p.portal, s)))
        .toList();
    if (entries.isEmpty) return;

    isVerifyingAlive = true;
    aliveChecked = 0;
    aliveTotal = entries.length;
    aliveCount = 0;
    final aliveSet = <String>{};
    _aliveCancel = false;
    notifyListeners();

    await IptvAliveChecker.launchCheck(
      streams: entries,
      onResult: (id, alive) async {
        if (alive) aliveSet.add(id);
        streamHealth[id] = alive;
      },
      onProgress: (prog) async {
        aliveChecked = prog.checked;
        aliveTotal = prog.total;
        aliveCount = prog.alive;
        notifyListeners();
      },
      onDone: () async {
        aliveStreamIds = aliveSet;
        aliveCheckedAt = DateTime.now().millisecondsSinceEpoch;
        await IptvAliveStore.save(
          pkey,
          AliveSnapshot(
            checkedAt: aliveCheckedAt!,
            aliveIds: aliveSet,
          ),
        );
        isVerifyingAlive = false;
        notifyListeners();
      },
      isCancelled: () => _aliveCancel,
    );
    if (_aliveCancel) {
      isVerifyingAlive = false;
      notifyListeners();
    }
  }

  void stopAliveCheck() {
    _aliveCancel = true;
    isVerifyingAlive = false;
    notifyListeners();
  }

  Future<void> recheckAlive() async {
    final p = activePortal;
    if (p == null) return;
    await IptvAliveStore.clear(IptvAliveStore.portalKey(p.portal));
    aliveStreamIds = const {};
    aliveCheckedAt = null;
    streamHealth.clear();
    _healthInFlight.clear();
    _healthQueue.clear();
    cancelAllLazyChecks();
    notifyListeners();
    await startAliveCheck(force: true);
  }

  @override
  void dispose() {
    SettingsService.iptvEpgEnabledNotifier
        .removeListener(_onEpgPrefChanged);
    cancelAllLazyChecks();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Series
  // ────────────────────────────────────────────────────────────────────────
  Future<void> openSeries(IptvStream s) async {
    final p = activePortal;
    if (p == null) return;
    activeSeries = s;
    view = IptvView.episodeList;
    isLoading = true;
    error = null;
    episodes = const [];
    notifyListeners();
    try {
      episodes = await IptvClient.seriesEpisodes(p.portal, s.streamId);
    } catch (e) {
      error = '$e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Channels Hub
  // ────────────────────────────────────────────────────────────────────────
  void openChannelsHub() {
    activeHardcoded = null;
    channelResults = const [];
    channelStatus = '';
    view = IptvView.channelsHub;
    notifyListeners();
  }

  void stopChannelSearch() {
    _channelCancel = true;
    channelIsRunning = false;
    channelStatus = 'Stopped.';
    notifyListeners();
  }

  Future<void> openHardcodedChannel(HardcodedChannel ch) async {
    activeHardcoded = ch;
    view = IptvView.channelResults;
    channelResults = const [];
    channelStatus = '';
    notifyListeners();
    final stored = await IptvChannelResultsStore.load(ch.id);
    final favs = await IptvChannelFavoritesStore.load(ch.id);
    _favoriteHits[ch.id] = favs;
    channelResults = _sortHitsFavoritesFirst(
      ch.id,
      stored
          .map((h) => ChannelHit(
              portal: VerifiedPortal(
                portal: IptvPortal(
                  url: h.portalUrl,
                  username: h.portalUser,
                  password: h.portalPass,
                  source: 'Saved',
                ),
                name: h.portalName,
                expiry: '',
                maxConnections: '1',
                activeConnections: '0',
              ),
              stream: IptvStream(
                streamId: h.streamId,
                name: h.streamName,
                icon: h.streamIcon,
                categoryId: h.streamCategoryId,
                containerExt: h.streamContainerExt,
                kind: h.streamKind,
              ),
              streamUrl: h.streamUrl,
            ))
        .toList(),
    );
    notifyListeners();
    if (channelResults.isEmpty) {
      await runChannelScan(ch);
    }
  }

  Future<void> searchAgainChannel() async {
    final ch = activeHardcoded;
    if (ch == null) return;
    _channelAttempted.remove(ch.id);
    _channelCatalogAfter.remove(ch.id);
    _channelScrapedPool.remove(ch.id);
    channelResults = const [];
    await IptvChannelResultsStore.clear(ch.id);
    notifyListeners();
    await runChannelScan(ch);
  }

  Future<void> getMoreChannels() async {
    final ch = activeHardcoded;
    if (ch == null) return;
    await runChannelScan(ch, scrapeMore: true);
  }

  Future<void> deleteChannelHit(int index) async {
    final ch = activeHardcoded;
    if (ch == null) return;
    if (index < 0 || index >= channelResults.length) return;
    final updated = [...channelResults]..removeAt(index);
    channelResults = updated;
    await _saveChannelHits(ch.id, updated);
    notifyListeners();
  }

  Future<void> deleteChannelHits(Set<int> indices) async {
    final ch = activeHardcoded;
    if (ch == null) return;
    final keep = <ChannelHit>[];
    for (var i = 0; i < channelResults.length; i++) {
      if (!indices.contains(i)) keep.add(channelResults[i]);
    }
    channelResults = keep;
    await _saveChannelHits(ch.id, keep);
    notifyListeners();
  }

  Future<void> _saveChannelHits(String channelId, List<ChannelHit> hits) async {
    final stored = hits
        .map((h) => StoredHit(
              portalUrl: h.portal.portal.url,
              portalUser: h.portal.portal.username,
              portalPass: h.portal.portal.password,
              portalName: h.portal.name,
              streamId: h.stream.streamId,
              streamName: h.stream.name,
              streamIcon: h.stream.icon,
              streamCategoryId: h.stream.categoryId,
              streamContainerExt: h.stream.containerExt,
              streamKind: h.stream.kind,
              streamUrl: h.streamUrl,
            ))
        .toList();
    await IptvChannelResultsStore.save(channelId, stored);
  }

  /// Mirrors the Android TV `runChannelScan` exactly:
  ///   1. Bootstrap: seed the per-channel pool with all saved verified portals.
  ///   2. (Only if [scrapeMore] OR no portals at all) fetch one fresh catalog
  ///      page and verify-until 5 are alive — newly verified portals are added
  ///      to the user's library *and* the pool.
  ///   3. Take the next 8 portals from the pool, mark them attempted.
  ///   4. **In parallel** fetch live streams from all 8 portals at once,
  ///      filter by channel keywords → one big candidate list (deduped by URL).
  ///   5. Hand the entire candidate list to the 24-wide alive-checker. Hits
  ///      stream in via callback and are saved/notified live.
  Future<void> runChannelScan(HardcodedChannel ch, {bool scrapeMore = false}) async {
    if (channelIsRunning) return;
    channelIsRunning = true;
    _channelCancel = false;
    notifyListeners();

    final attempted = _channelAttempted.putIfAbsent(ch.id, () => <String>{});
    final pool = _channelScrapedPool.putIfAbsent(ch.id, () => []);

    // ── 1. Bootstrap pool from globally-verified portals ──
    final poolKeys = pool.map((p) => p.key).toSet();
    for (final vp in verified) {
      if (!attempted.contains(vp.key) && !poolKeys.contains(vp.key)) {
        pool.add(vp.portal);
      }
    }

    // ── 2. Scrape fresh portals if requested or we're empty ──
    final needsBootstrap =
        verified.isEmpty && pool.every((p) => attempted.contains(p.key));
    if (scrapeMore || needsBootstrap) {
      final pendingQueue =
          _channelPendingPortals.putIfAbsent(ch.id, () => <IptvPortal>[]);
      final pendingKeys =
          _channelPendingKeys.putIfAbsent(ch.id, () => <String>{});

      // Drop anything from the queue that we've since verified or attempted
      // through another channel's scan.
      pendingQueue.removeWhere((p) =>
          _verifiedKeys.contains(p.credKey) || attempted.contains(p.key));
      pendingKeys
        ..clear()
        ..addAll(pendingQueue.map((p) => p.credKey));

      // Only fetch a new catalog page when the queue is empty — otherwise
      // we'd be throwing away the un-tested portals from previous presses.
      if (pendingQueue.isEmpty) {
        channelStatus = 'Looking for more portals…';
        notifyListeners();
        try {
          final after = _channelCatalogAfter[ch.id];
          final page = await IptvScraper.scrapeCatalogPage(
              maxResults: 60, after: after);
          if (_channelCancel) {
            channelIsRunning = false;
            channelStatus = 'Stopped.';
            notifyListeners();
            return;
          }
          _channelCatalogAfter[ch.id] = page.nextAfter;
          final knownKeys = {
            ...pool.map((p) => p.key),
            ...attempted,
          };
          for (final p in page.portals) {
            if (_verifiedKeys.contains(p.credKey)) continue;
            if (knownKeys.contains(p.key)) continue;
            if (pendingKeys.add(p.credKey)) pendingQueue.add(p);
          }
          if (pendingQueue.isEmpty &&
              !page.hasMore &&
              channelResults.isEmpty) {
            channelIsRunning = false;
            channelStatus = 'No more portals available.';
            notifyListeners();
            return;
          }
        } catch (_) {}
      }

      if (pendingQueue.isNotEmpty) {
        final snapshot = List<IptvPortal>.from(pendingQueue);
        channelStatus = 'Verifying ${snapshot.length} new portal'
            '${snapshot.length == 1 ? '' : 's'}…';
        notifyListeners();
        await IptvVerifier.verifyUntil(
          portals: snapshot,
          target: 5,
          isCancelled: () => _channelCancel,
          onAttempted: (p) {
            if (pendingKeys.remove(p.credKey)) {
              pendingQueue.removeWhere((x) => x.credKey == p.credKey);
            }
          },
          onAlive: (v) async {
            if (_verifiedKeys.add(v.credKey)) {
              _registerPortalAdded(v.key);
              verified = _sortPortals([...verified, v]);
              await IptvStore.save(verified);
              if (!attempted.contains(v.key) &&
                  !pool.any((p) => p.key == v.key)) {
                pool.add(v.portal);
              }
            }
          },
          onProgress: (c, t, a) {
            channelStatus = 'Verifying portals $c/$t · $a working'
                '${pendingQueue.isNotEmpty ? ' · ${pendingQueue.length} queued' : ''}';
            notifyListeners();
          },
        );
      }
    }

    if (_channelCancel) {
      channelIsRunning = false;
      channelStatus = 'Stopped.';
      notifyListeners();
      return;
    }

    // ── 3. Take next 8 portals from the pool ──
    final toScan = pool.take(8).toList();
    if (toScan.isEmpty) {
      channelIsRunning = false;
      channelStatus = channelResults.isEmpty
          ? 'No working portals available. Tap Get More.'
          : '${channelResults.length} alive · no more portals to scan.';
      notifyListeners();
      return;
    }

    channelStatus = 'Searching ${toScan.length} portal'
        '${toScan.length == 1 ? '' : 's'}…';
    notifyListeners();

    // Mark attempted up-front so re-entry skips them
    for (final p in toScan) {
      attempted.add(p.key);
    }
    pool.removeWhere((p) => attempted.contains(p.key));

    // ── 4. Fan out: fetch live streams from all 8 portals IN PARALLEL ──
    if (_channelCancel) {
      channelIsRunning = false;
      channelStatus = 'Stopped.';
      notifyListeners();
      return;
    }
    final verifiedByKey = {for (final v in verified) v.key: v};
    final candidatesByPortal =
        await Future.wait(toScan.map((p) async {
      if (_channelCancel) return <_Candidate>[];
      final vp = verifiedByKey[p.key] ??
          VerifiedPortal(
            portal: p,
            name: p.url,
            expiry: '',
            maxConnections: '1',
            activeConnections: '0',
          );
      try {
        final streams =
            await IptvClient.streams(vp.portal, IptvSection.live, '');
        return streams
            .where((s) =>
                HardcodedChannels.matches(s.name, ch.keywords, ch.exclude))
            .map((s) => _Candidate(
                  portal: vp,
                  stream: s,
                  url: IptvClient.streamUrl(vp.portal, s),
                ))
            .toList();
      } catch (_) {
        return <_Candidate>[];
      }
    }));

    // Flatten + dedupe by URL + drop ones we already have
    final have = channelResults.map((h) => h.streamUrl).toSet();
    final seen = <String>{};
    final newCandidates = <_Candidate>[];
    for (final list in candidatesByPortal) {
      for (final c in list) {
        if (c.url.isEmpty) continue;
        if (have.contains(c.url)) continue;
        if (!seen.add(c.url)) continue;
        newCandidates.add(c);
      }
    }

    if (newCandidates.isEmpty || _channelCancel) {
      channelIsRunning = false;
      channelStatus = channelResults.isEmpty
          ? 'No matching channels found. Try Get More.'
          : '${channelResults.length} alive · no new matches.';
      notifyListeners();
      return;
    }

    // ── 5. ONE 24-wide alive-check pass across ALL candidates ──
    final byUrl = {for (final c in newCandidates) c.url: c};
    channelStatus = 'Found ${newCandidates.length} candidate'
        '${newCandidates.length == 1 ? '' : 's'} · verifying…';
    notifyListeners();

    await IptvAliveChecker.launchCheck(
      streams: newCandidates.map((c) => MapEntry(c.url, c.url)).toList(),
      isCancelled: () => _channelCancel,
      onResult: (id, alive) async {
        if (!alive) return;
        final c = byUrl[id];
        if (c == null) return;
        if (channelResults.any((h) => h.streamUrl == c.url)) return;
        final hit = ChannelHit(portal: c.portal, stream: c.stream, streamUrl: c.url);
        channelResults =
            _sortHitsFavoritesFirst(ch.id, [...channelResults, hit]);
        await _saveChannelHits(ch.id, channelResults);
        notifyListeners();
      },
      onProgress: (p) async {
        channelStatus = 'Verifying ${p.checked}/${p.total} · '
            '${channelResults.length} alive';
        notifyListeners();
      },
      onDone: () async {
        channelIsRunning = false;
        channelStatus = channelResults.isEmpty
            ? 'No alive streams for ${ch.name}. Try Get More.'
            : '${channelResults.length} alive stream'
                '${channelResults.length == 1 ? '' : 's'} saved.';
        notifyListeners();
      },
    );
    if (_channelCancel) {
      channelIsRunning = false;
      channelStatus = 'Stopped.';
      notifyListeners();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Navigation
  // ────────────────────────────────────────────────────────────────────────
  void back() {
    switch (view) {
      case IptvView.portalList:
      case IptvView.sectionPick:
      case IptvView.browser:
        if (portalPanelOpen) {
          closePortalPanel();
        }
        break;
      case IptvView.episodeList:
        view = IptvView.browser;
        activeSeries = null;
        episodes = const [];
        break;
      case IptvView.channelsHub:
        view = IptvView.browser;
        activeHardcoded = null;
        break;
      case IptvView.channelResults:
        stopChannelSearch();
        view = IptvView.browser;
        activeHardcoded = null;
        channelResults = const [];
        channelStatus = '';
        break;
    }
    notifyListeners();
  }
}

class _CatalogSnap {
  final List<IptvCategory> categories;
  final List<IptvStream> streams;
  const _CatalogSnap({required this.categories, required this.streams});
}

class _Candidate {
  final VerifiedPortal portal;
  final IptvStream stream;
  final String url;
  const _Candidate({
    required this.portal,
    required this.stream,
    required this.url,
  });
}
