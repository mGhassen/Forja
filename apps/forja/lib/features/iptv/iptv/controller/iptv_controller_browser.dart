part of 'iptv_controller.dart';

mixin _IptvControllerBrowser on ChangeNotifier {
  IptvController get _c => this as IptvController;

  void openPortal(VerifiedPortal p) {
    unawaited(_c.selectPortal(p));
  }

  bool _hasApiCategories(List<IptvCategory> cats) => cats.any(
        (c) =>
            c.id.isNotEmpty &&
            !IptvLiveCatalog.isSyntheticId(c.id),
      );

  /// Empty Live with only Favorites pins = timed-out fetch cached as success.
  bool _liveSnapIsStale(_CatalogSnap snap) =>
      snap.streams.isEmpty && !_hasApiCategories(snap.categories);

  void _pruneStaleLiveCache(String portalKey) {
    final key = _catalogCacheKey(portalKey, IptvSection.live);
    final snap = _c._catalogCache[key];
    if (snap != null && _liveSnapIsStale(snap)) {
      _c._catalogCache.remove(key);
      unawaited(
        IptvCatalogDiskStore.deleteShelf(portalKey, IptvSection.live),
      );
    }
  }

  bool _portalHasShelf(String portalKey, IptvSection section) =>
      _c._catalogCache.containsKey(_catalogCacheKey(portalKey, section));

  /// Pull missing shelves from disk into the session map (no network).
  Future<void> _hydratePortalFromDisk(String portalKey) async {
    if (portalKey.isEmpty) return;
    for (final section in IptvSection.values) {
      final cacheKey = _catalogCacheKey(portalKey, section);
      if (_c._catalogCache.containsKey(cacheKey)) continue;
      final disk = await IptvCatalogDiskStore.load(portalKey, section);
      if (disk == null) continue;
      final snap = _CatalogSnap(
        categories: disk.categories,
        streams: disk.streams,
      );
      if (section == IptvSection.live && _liveSnapIsStale(snap)) {
        unawaited(IptvCatalogDiskStore.deleteShelf(portalKey, section));
        continue;
      }
      _c._catalogCache[cacheKey] = snap;
    }
  }

  /// Movies + Series rows for [portalKey] from session/disk cache (no network).
  /// Used by IPTV details "More like this" to keep recommendations playable.
  Future<List<IptvStream>> vodSeriesCatalog(String portalKey) async {
    await _hydratePortalFromDisk(portalKey);
    final out = <IptvStream>[];
    for (final section in [IptvSection.vod, IptvSection.series]) {
      final snap = _c._catalogCache[_catalogCacheKey(portalKey, section)];
      if (snap == null) continue;
      out.addAll(snap.streams);
    }
    return out;
  }

  void _putCatalogSnap(
    String portalKey,
    IptvSection section,
    _CatalogSnap snap, {
    bool persist = true,
  }) {
    _c._catalogCache[_catalogCacheKey(portalKey, section)] = snap;
    if (!persist) return;
    if (section == IptvSection.live && _liveSnapIsStale(snap)) return;
    unawaited(
      IptvCatalogDiskStore.save(
        portalKey,
        section,
        snap.categories,
        snap.streams,
      ),
    );
  }

  int _apiCategoryCount(List<IptvCategory> cats) => cats
      .where(
        (c) =>
            c.id.isNotEmpty &&
            !IptvLiveCatalog.isSyntheticId(c.id) &&
            !IptvCatalogOrphans.isUncategorizedId(c.id),
      )
      .length;

  IptvCatalogLoadProgress _progressFromCache(String portalKey) {
    final live =
        _c._catalogCache[_catalogCacheKey(portalKey, IptvSection.live)];
    final vod = _c._catalogCache[_catalogCacheKey(portalKey, IptvSection.vod)];
    final series =
        _c._catalogCache[_catalogCacheKey(portalKey, IptvSection.series)];
    var cats = 0;
    if (live != null) cats += _apiCategoryCount(live.categories);
    if (vod != null) cats += _apiCategoryCount(vod.categories);
    if (series != null) cats += _apiCategoryCount(series.categories);
    return IptvCatalogLoadProgress(
      categoryCount: cats,
      channelCount: live?.streams.length ?? 0,
      movieCount: vod?.streams.length ?? 0,
      seriesCount: series?.streams.length ?? 0,
    );
  }

  IptvCatalogLoadProgress? catalogStatsFor(String? portalKey) {
    if (portalKey == null || portalKey.isEmpty) return null;
    return _c.portalCatalogStats[portalKey];
  }

  Future<void> _rememberCatalogStats(
    String portalKey,
    IptvCatalogLoadProgress progress,
  ) async {
    if (portalKey.isEmpty) return;
    final prev = _c.portalCatalogStats[portalKey];
    final hasLive = _portalHasShelf(portalKey, IptvSection.live);
    final hasVod = _portalHasShelf(portalKey, IptvSection.vod);
    final hasSeries = _portalHasShelf(portalKey, IptvSection.series);
    final merged = IptvCatalogLoadProgress(
      categoryCount: (hasLive && hasVod && hasSeries)
          ? progress.categoryCount
          : (progress.categoryCount > 0
              ? progress.categoryCount
              : (prev?.categoryCount ?? 0)),
      channelCount:
          hasLive ? progress.channelCount : (prev?.channelCount ?? 0),
      movieCount: hasVod ? progress.movieCount : (prev?.movieCount ?? 0),
      seriesCount:
          hasSeries ? progress.seriesCount : (prev?.seriesCount ?? 0),
      fraction: 1,
      finished: true,
    );
    if (!merged.hasAnyCount) return;
    _c.portalCatalogStats[portalKey] = merged;
    notifyListeners();
    await IptvStore.saveCatalogStats(portalKey, merged);
  }

  Future<void> _loadCatalogStatsFromStore() async {
    final all = await IptvStore.loadCatalogStats();
    if (all.isEmpty) return;
    _c.portalCatalogStats.addAll(all);
    notifyListeners();
  }


  Future<void> _applyCachedSnap(
    VerifiedPortal p,
    IptvSection section,
    _CatalogSnap cached, {
    required bool persistSection,
  }) async {
    _c.activePortal = p;
    _c.activeSection = section;
    _c.view = IptvView.browser;
    _c.isLoading = false;
    _c.catalogLoadStyle = IptvCatalogLoadStyle.none;
    _c.catalogLoadStep = null;
    _c.catalogLoadProgress = IptvCatalogLoadProgress.empty;
    _c.error = null;
    _c.categories = _withoutAllCategory(cached.categories);
    _c.browserAllStreams = cached.streams;
    _c.browserSelectedCategoryId = _defaultCategoryId(_c.categories);
    _c.browserHighlightedStreamId = null;
    _c.browserSearch = '';
    _c.browserSearchOpen = false;
    _c._browserSearchFilterActive = false;
    _c._browserCategoryBeforeSearch = null;
    _c._browserSearchCommittedCategoryId = null;
    _clearStreamHealthState();
    cancelAllLazyChecks();
    _c._epgCache.clear();
    _c._guideEpgCache.clear();
    IptvClient.clearStalkerEpgCache();
    _c.liveOnly = false;
    _c.aliveStreamIds = const {};
    _c.aliveCheckedAt = null;
    if (section == IptvSection.live) {
      final key = IptvAliveStore.portalKey(p.portal);
      final lastCat = await IptvLiveChannelListsStore.loadLastCategory(key);
      final lastCh = await IptvLiveChannelListsStore.loadLastChannel(key);
      if (_c.activePortal?.key != p.key || _c.activeSection != section) {
        return;
      }
      // Pins may be missing on older cache snaps — restore needs them first.
      if (!_c.categories.any((c) => c.id == IptvLiveCatalog.favoritesId)) {
        final api = _c.categories
            .where((c) => !IptvLiveCatalog.isPinnedId(c.id))
            .toList();
        _c.categories = IptvLiveCatalog.withPins(api);
      }
      _applyRestoredLiveBrowseSelection(
        categoryId: lastCat,
        streamId: lastCh,
      );
    }
    notifyListeners();
    unawaited(
      _hydrateLiveSectionPrefs(
        portal: p,
        section: section,
        persistSection: persistSection,
      ),
    );
  }

  /// Center ticker + empty pane before any await so health/store notifies cannot
  /// paint the Reload / "Failed to load" empty state mid-open.
  void _armCatalogLoading(IptvSection section) {
    _c.activeSection = section;
    _c.view = IptvView.browser;
    _c.isLoading = true;
    _c.error = null;
    _c.catalogLoadStyle = IptvCatalogLoadStyle.verbose;
    _c.catalogLoadStep = IptvCatalogLoadStep.cache;
    _c.catalogLoadProgress = IptvCatalogLoadProgress.empty;
    _c.categories = const [];
    _c.browserAllStreams = const [];
    _c.browserSelectedCategoryId = null;
    _c.browserHighlightedStreamId = null;
    _c.browserSearch = '';
    _c.browserSearchOpen = false;
    _c._browserSearchFilterActive = false;
    _c._browserCategoryBeforeSearch = null;
    _c._browserSearchCommittedCategoryId = null;
    _c.aliveStreamIds = const {};
    _c.aliveCheckedAt = null;
    _clearStreamHealthState();
    cancelAllLazyChecks();
    _c._epgCache.clear();
    _c._guideEpgCache.clear();
    IptvClient.clearStalkerEpgCache();
    notifyListeners();
  }

  void _setCatalogLoadStep(IptvCatalogLoadStep step) {
    if (_c.catalogLoadStep == step &&
        _c.catalogLoadStyle == IptvCatalogLoadStyle.verbose) {
      return;
    }
    _c.catalogLoadStyle = IptvCatalogLoadStyle.verbose;
    _c.catalogLoadStep = step;
    notifyListeners();
  }

  Future<void> openSection(
    IptvSection section, {
    bool persistSection = true,
    bool force = false,
  }) async {
    final p = _c.activePortal;
    if (p == null) return;

    final cacheKey = _catalogCacheKey(p.key, section);

    // Session hit → instant UI (no spinner flash).
    if (!force) {
      final mem = _c._catalogCache[cacheKey];
      if (mem != null) {
        if (section == IptvSection.live && _liveSnapIsStale(mem)) {
          _c._catalogCache.remove(cacheKey);
        } else {
          ++_c._catalogLoadId;
          await _applyCachedSnap(p, section, mem, persistSection: persistSection);
          return;
        }
      }
    }

    // Arm loading BEFORE disk hydrate / network so portal-health notifyListeners
    // cannot paint empty+error while streams are still [].
    final loadId = ++_c._catalogLoadId;
    _armCatalogLoading(section);
    // Reload skips disk hydrate — jump straight to portal fetch copy.
    if (force) _setCatalogLoadStep(IptvCatalogLoadStep.catalog);

    if (!force) {
      await _hydratePortalFromDisk(p.key);
      if (loadId != _c._catalogLoadId) return;
      if (_c.activePortal?.key != p.key || _c.activeSection != section) {
        return;
      }
    }
    _pruneStaleLiveCache(p.key);
    final cached = _c._catalogCache[cacheKey];

    // Disk hydrate filled the shelf → apply without network.
    if (!force && cached != null) {
      await _applyCachedSnap(p, section, cached, persistSection: persistSection);
      return;
    }

    // Cache miss / Reload → fetch this shelf only (already spinning).
    try {
      late final List<IptvCategory> cats;
      late final List<IptvStream> streams;

      _setCatalogLoadStep(IptvCatalogLoadStep.catalog);
      final snap = await IptvClient.catalog(p.portal, section);
      if (loadId != _c._catalogLoadId) return;
      if (_c.activePortal?.key != p.key || _c.activeSection != section) {
        return;
      }
      if (!snap.ok) {
        _c.error = snap.error ?? 'Could not load catalog';
        // Keep Favorites / Already watched focusable on Live even when the
        // portal catalog fetch fails (empty channel pane + Reload).
        if (section == IptvSection.live) {
          _c.categories = IptvLiveCatalog.withPins(const []);
          _c.browserSelectedCategoryId = _defaultCategoryId(_c.categories);
        }
        return;
      }
      cats = snap.categories;
      streams = snap.streams;

      _c.categories = section == IptvSection.live
          ? IptvLiveCatalog.withPins(cats)
          : cats;
      _c.browserAllStreams = streams;
      _c.browserSelectedCategoryId = _defaultCategoryId(_c.categories);

      if (streams.isEmpty && cats.isEmpty && section == IptvSection.live) {
        _c.error = 'Could not load channels from portal';
      }

      if (section == IptvSection.live) {
        _setCatalogLoadStep(IptvCatalogLoadStep.liveLists);
        final key = IptvAliveStore.portalKey(p.portal);
        _c.liveOnly = await IptvAliveStore.loadLiveOnly(key);
        if (loadId != _c._catalogLoadId) return;
        if (_c.activePortal?.key != p.key || _c.activeSection != section) {
          return;
        }
        final aliveSnap = await IptvAliveStore.load(key);
        if (loadId != _c._catalogLoadId) return;
        if (_c.activePortal?.key != p.key || _c.activeSection != section) {
          return;
        }
        if (aliveSnap != null) {
          _c.aliveStreamIds = aliveSnap.aliveIds;
          _c.aliveCheckedAt = aliveSnap.checkedAt;
          _seedHealthFromCache();
        }
        await _loadLiveChannelLists(key);
        if (loadId != _c._catalogLoadId) return;
        if (_c.activePortal?.key != p.key || _c.activeSection != section) {
          return;
        }
      } else {
        _c.liveOnly = false;
        _c.liveFavoriteIds = const {};
        _c.liveWatchedIds = const [];
        _c.livePinnedCategoryIds = const [];
        _c.liveCategoryOrderIds = const [];
      }

      _putCatalogSnap(
        p.key,
        section,
        _CatalogSnap(
          categories: _c.categories,
          streams: _c.browserAllStreams,
        ),
      );
      await _rememberCatalogStats(p.key, _progressFromCache(p.key));
    } catch (e) {
      if (loadId != _c._catalogLoadId) return;
      if (_c.activePortal?.key != p.key || _c.activeSection != section) return;
      _c.error = IptvClient.formatEngineError(e);
      if (section == IptvSection.live) {
        _c.categories = IptvLiveCatalog.withPins(const []);
        _c.browserSelectedCategoryId = _defaultCategoryId(_c.categories);
      }
    } finally {
      if (loadId == _c._catalogLoadId &&
          _c.activePortal?.key == p.key &&
          _c.activeSection == section) {
        if (section == IptvSection.live) {
          final key = IptvAliveStore.portalKey(p.portal);
          final lastCat =
              await IptvLiveChannelListsStore.loadLastCategory(key);
          final lastCh =
              await IptvLiveChannelListsStore.loadLastChannel(key);
          if (loadId == _c._catalogLoadId &&
              _c.activePortal?.key == p.key &&
              _c.activeSection == section) {
            _applyRestoredLiveBrowseSelection(
              categoryId: lastCat,
              streamId: lastCh,
            );
          }
        }
        if (loadId == _c._catalogLoadId &&
            _c.activePortal?.key == p.key &&
            _c.activeSection == section) {
          _c.isLoading = false;
          _c.catalogLoadStyle = IptvCatalogLoadStyle.none;
          _c.catalogLoadStep = null;
          _c.catalogLoadProgress = IptvCatalogLoadProgress.empty;
          notifyListeners();
          unawaited(
            _hydrateLiveSectionPrefs(
              portal: p,
              section: section,
              persistSection: persistSection,
            ),
          );
        }
      }
    }
  }

  String _catalogCacheKey(String portalKey, IptvSection section) =>
      '$portalKey|${section.name}';

  /// Drop legacy synthetic "All" (empty id) from cached category lists.
  List<IptvCategory> _withoutAllCategory(List<IptvCategory> cats) =>
      cats.where((c) => c.id.isNotEmpty).toList();

  /// First portal group, else first pinned row (Favorites / Already watched).
  String? _defaultCategoryId(List<IptvCategory> cats) {
    for (final c in cats) {
      if (c.id.isNotEmpty && !IptvLiveCatalog.isSyntheticId(c.id)) {
        return c.id;
      }
    }
    for (final c in cats) {
      if (c.id.isNotEmpty) return c.id;
    }
    return null;
  }

  Future<void> _loadLiveChannelLists(String portalKey) async {
    final favs = await IptvLiveChannelListsStore.loadFavorites(portalKey);
    final watched = await IptvLiveChannelListsStore.loadWatched(portalKey);
    final pinned = await IptvLiveChannelListsStore.loadPinnedCategories(
      portalKey,
    );
    var order = await IptvLiveChannelListsStore.loadCategoryOrder(portalKey);
    // Migrate legacy pins → custom order once (pins stay as pin markers).
    if (order.isEmpty && pinned.isNotEmpty) {
      order = List<String>.from(pinned);
      await IptvLiveChannelListsStore.saveCategoryOrder(portalKey, order);
    }
    _c.liveFavoriteIds = favs;
    _c.liveWatchedIds = watched;
    _c.livePinnedCategoryIds = pinned;
    _c.liveCategoryOrderIds = order;
  }

  Future<void> _hydrateLiveSectionPrefs({
    required VerifiedPortal portal,
    required IptvSection section,
    required bool persistSection,
  }) async {
    if (section == IptvSection.live) {
      final key = IptvAliveStore.portalKey(portal.portal);
      final liveOnlyPref = await IptvAliveStore.loadLiveOnly(key);
      final alive = await IptvAliveStore.load(key);
      await _loadLiveChannelLists(key);
      final lastCat = await IptvLiveChannelListsStore.loadLastCategory(key);
      final lastCh = await IptvLiveChannelListsStore.loadLastChannel(key);
      if (_c.activePortal?.key != portal.key || _c.activeSection != section) {
        return;
      }
      _c.liveOnly = liveOnlyPref;
      if (alive != null) {
        _c.aliveStreamIds = alive.aliveIds;
        _c.aliveCheckedAt = alive.checkedAt;
        _seedHealthFromCache();
      } else {
        _c.aliveStreamIds = const {};
        _c.aliveCheckedAt = null;
      }
      // Cache snap may predate synthetic Live pins - ensure they exist.
      if (!_c.categories.any((c) => c.id == IptvLiveCatalog.favoritesId)) {
        final api = _c.categories
            .where((c) => !IptvLiveCatalog.isPinnedId(c.id))
            .toList();
        _c.categories = IptvLiveCatalog.withPins(api);
        _putCatalogSnap(
          portal.key,
          section,
          _CatalogSnap(
            categories: _c.categories,
            streams: _c.browserAllStreams,
          ),
        );
      }
      _applyRestoredLiveBrowseSelection(
        categoryId: lastCat,
        streamId: lastCh,
      );
    } else {
      if (_c.activePortal?.key != portal.key || _c.activeSection != section) {
        return;
      }
      _c.liveOnly = false;
      _c.aliveStreamIds = const {};
      _c.aliveCheckedAt = null;
      _c.liveFavoriteIds = const {};
      _c.liveWatchedIds = const [];
      _c.livePinnedCategoryIds = const [];
      _c.liveCategoryOrderIds = const [];
      _c.browserHighlightedStreamId = null;
    }
    if (persistSection) {
      await IptvStore.saveLastSection(section);
    }
    if (_c.activePortal?.key != portal.key || _c.activeSection != section) {
      return;
    }
    notifyListeners();
  }

  /// Apply last category (must exist) + last played channel highlight.
  void _applyRestoredLiveBrowseSelection({
    required String? categoryId,
    required String? streamId,
  }) {
    if (categoryId != null &&
        categoryId.isNotEmpty &&
        _c.categories.any((c) => c.id == categoryId)) {
      _c.browserSelectedCategoryId = categoryId;
    } else if (_c.browserSelectedCategoryId == null ||
        !_c.categories.any((c) => c.id == _c.browserSelectedCategoryId)) {
      _c.browserSelectedCategoryId = _defaultCategoryId(_c.categories);
    }
    _c.browserHighlightedStreamId =
        (streamId != null && streamId.isNotEmpty) ? streamId : null;
  }

  void _invalidatePortalCatalogCache(String portalKey) {
    final prefix = '$portalKey|';
    _c._catalogCache.removeWhere((k, _) => k.startsWith(prefix));
    unawaited(IptvCatalogDiskStore.deletePortal(portalKey));
  }

  void _seedHealthFromCache() {
    for (final id in _c.aliveStreamIds) {
      _c.streamHealth[id] = true;
    }
  }

  /// Write [streamHealth]; returns true when the painted value changed.
  bool _recordStreamHealth(String streamId, bool ok, {String? kind}) {
    final prev = _c.streamHealth[streamId];
    _c.streamHealth[streamId] = ok;
    if (kind == 'live') {
      if (ok) {
        _c.aliveStreamIds = {..._c.aliveStreamIds, streamId};
      } else if (_c.aliveStreamIds.contains(streamId)) {
        _c.aliveStreamIds = {..._c.aliveStreamIds}..remove(streamId);
      }
    }
    return prev != ok;
  }

  void _clearStreamHealthState() {
    _c.streamHealth.clear();
    _c._healthInFlight.clear();
    _c._healthQueue.clear();
  }

  /// Queue a health probe after the card has stayed visible (debounced).
  /// Last border stays painted until the new result lands; every dwell
  /// re-probes so a dead portal flips green → red on re-hover/focus.
  ///
  /// [onlyThis]: TV D-pad focus — drop other pending timers/queue entries so
  /// skimming channels never piles probes behind the one you dwell on.
  void scheduleLazyCheck(IptvStream s, {bool onlyThis = false}) {
    final p = _c.activePortal;
    if (p == null || !_sectionSupportsStreamHealth(_c.activeSection)) return;
    if (!_streamSupportsHealthProbe(s)) return;
    if (_c._healthInFlight.contains(s.streamId)) return;

    if (onlyThis) {
      for (final id in _c._healthDebounce.keys.toList()) {
        if (id == s.streamId) continue;
        _c._healthDebounce[id]?.cancel();
        _c._healthDebounce.remove(id);
      }
      _c._healthQueue.removeWhere((x) => x.streamId != s.streamId);
    }

    _c._healthDebounce[s.streamId]?.cancel();
    _c._healthDebounce[s.streamId] = Timer(IptvController._lazyCheckDelay, () {
      _c._healthDebounce.remove(s.streamId);
      lazyCheckStream(s);
    });
  }

  static bool _sectionSupportsStreamHealth(IptvSection? section) =>
      section == IptvSection.live ||
      section == IptvSection.vod ||
      section == IptvSection.series;

  static bool _streamSupportsHealthProbe(IptvStream s) =>
      (s.kind == 'live' || s.kind == 'vod' || s.kind == 'series') &&
      s.streamId.isNotEmpty;

  void cancelLazyCheck(String streamId) {
    _c._healthDebounce[streamId]?.cancel();
    _c._healthDebounce.remove(streamId);
    _c._healthQueue.removeWhere((x) => x.streamId == streamId);
  }

  void cancelAllLazyChecks() {
    for (final t in _c._healthDebounce.values) {
      t.cancel();
    }
    _c._healthDebounce.clear();
    _c._healthQueue.clear();
    // Do not touch portal health expiry - catalog open/reload must keep
    // the active-portal status cache until TTL or an explicit refresh.
    for (final t in _portalHealthDebounce.values) {
      t.cancel();
    }
    _portalHealthDebounce.clear();
  }

  /// Probe a single catalog stream - capped concurrency, after debounce.
  void lazyCheckStream(IptvStream s) {
    final p = _c.activePortal;
    if (p == null || !_sectionSupportsStreamHealth(_c.activeSection)) return;
    if (!_streamSupportsHealthProbe(s)) return;
    if (_c._healthInFlight.contains(s.streamId)) return;
    if (_c._healthInFlight.length >= IptvController._maxLazyHealthChecks) {
      if (!_c._healthQueue.any((x) => x.streamId == s.streamId)) {
        _c._healthQueue.add(s);
      }
      return;
    }
    unawaited(_runLazyHealthCheck(s));
  }

  /// Live/movie direct URL; series resolves first episode via get_series_info.
  Future<String?> _resolveProbeUrl(IptvPortal portal, IptvStream s) async {
    if (s.kind == 'live' || s.kind == 'vod') {
      return IptvClient.resolvePlayUrl(portal, s, section: s.kind);
    }
    if (s.kind != 'series') return null;
    final eps = await IptvClient.seriesEpisodes(portal, s.streamId);
    for (final e in eps) {
      if (e.id.isEmpty) continue;
      final url = await IptvClient.resolveEpisodeUrl(portal, e);
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  Future<void> _runLazyHealthCheck(IptvStream s) async {
    final p = _c.activePortal;
    if (p == null) return;
    _c._healthInFlight.add(s.streamId);
    try {
      final url = await _resolveProbeUrl(p.portal, s);
      if (url == null || url.isEmpty) {
        if (_recordStreamHealth(s.streamId, false, kind: s.kind)) {
          notifyListeners();
        }
        return;
      }
      final ok = await IptvAliveChecker.checkOne(url);
      if (_recordStreamHealth(s.streamId, ok, kind: s.kind)) {
        notifyListeners();
      }
    } catch (_) {
      if (_recordStreamHealth(s.streamId, false, kind: s.kind)) {
        notifyListeners();
      }
    } finally {
      _c._healthInFlight.remove(s.streamId);
      _drainHealthQueue();
    }
  }

  void _drainHealthQueue() {
    while (_c._healthQueue.isNotEmpty &&
        _c._healthInFlight.length < IptvController._maxLazyHealthChecks) {
      final next = _c._healthQueue.removeAt(0);
      if (!_c._healthInFlight.contains(next.streamId)) {
        unawaited(_runLazyHealthCheck(next));
      }
    }
  }

  void markStreamDead(String streamId) {
    if (streamId.isEmpty) return;
    if (_recordStreamHealth(streamId, false, kind: 'live')) {
      notifyListeners();
    }
  }

  bool? healthFor(String streamId) => _c.streamHealth[streamId];

  // ── Portal status (active button + panel rows) ──
  final Map<String, bool> portalHealth = {};
  final Set<String> _portalHealthInFlight = {};
  final Map<String, Timer> _portalHealthDebounce = {};
  final Map<String, Timer> _portalHealthExpiry = {};
  static const _portalHealthDelay = Duration(milliseconds: 350);

  /// Cached green/red for this long, then re-probe the active portal.
  static const _portalHealthTtl = Duration(minutes: 2);

  bool? portalHealthFor(String key) => portalHealth[key];

  /// Hover/focus probe — last dot stays painted until the new result lands;
  /// every dwell re-probes so a transient red flips back on re-hover/focus.
  /// [delay] defaults to short hover debounce; TV panel rows use a longer dwell.
  void schedulePortalHealthCheck(
    VerifiedPortal v, {
    Duration delay = _portalHealthDelay,
  }) {
    final key = v.key;
    if (key.isEmpty) return;
    if (_portalHealthInFlight.contains(key)) return;
    _portalHealthDebounce[key]?.cancel();
    _portalHealthDebounce[key] = Timer(delay, () {
      _portalHealthDebounce.remove(key);
      unawaited(_runPortalHealthCheck(v));
    });
  }

  /// Probe when a portal becomes active (select / restore).
  void ensurePortalHealth(VerifiedPortal v) {
    final key = v.key;
    if (key.isEmpty) return;
    if (_portalHealthInFlight.contains(key)) return;
    cancelPortalHealthCheck(key);
    unawaited(_runPortalHealthCheck(v));
  }

  /// Drop cache and re-probe (shelf reload / explicit refresh).
  void refreshPortalHealth(VerifiedPortal v) {
    final key = v.key;
    if (key.isEmpty) return;
    cancelPortalHealthCheck(key);
    _portalHealthExpiry[key]?.cancel();
    _portalHealthExpiry.remove(key);
    portalHealth.remove(key);
    if (_portalHealthInFlight.contains(key)) {
      notifyListeners();
      return;
    }
    unawaited(_runPortalHealthCheck(v));
  }

  void cancelPortalHealthCheck(String key) {
    _portalHealthDebounce[key]?.cancel();
    _portalHealthDebounce.remove(key);
  }

  /// Write [portalHealth]; returns true when the painted dot changed.
  bool _recordPortalHealth(String key, bool ok) {
    final prev = portalHealth[key];
    portalHealth[key] = ok;
    _portalHealthExpiry[key]?.cancel();
    _portalHealthExpiry[key] = Timer(_portalHealthTtl, () {
      _portalHealthExpiry.remove(key);
      portalHealth.remove(key);
      notifyListeners();
      final active = _c.activePortal;
      if (active != null && active.key == key) {
        unawaited(_runPortalHealthCheck(active));
      }
    });
    return prev != ok;
  }

  void _cancelAllPortalHealthTimers() {
    for (final t in _portalHealthDebounce.values) {
      t.cancel();
    }
    _portalHealthDebounce.clear();
    for (final t in _portalHealthExpiry.values) {
      t.cancel();
    }
    _portalHealthExpiry.clear();
  }

  Future<void> _runPortalHealthCheck(VerifiedPortal v) async {
    final key = v.key;
    if (!_portalHealthInFlight.add(key)) return;
    notifyListeners();
    try {
      final fresh = await IptvClient.verifyOrNull(
        v.portal,
        timeout: const Duration(seconds: 5),
      );
      if (fresh != null) {
        await _mergePortalAccountInfo(v, fresh);
        if (_recordPortalHealth(key, true)) notifyListeners();
      } else {
        if (_recordPortalHealth(key, false)) notifyListeners();
      }
    } catch (_) {
      if (_recordPortalHealth(key, false)) notifyListeners();
    } finally {
      _portalHealthInFlight.remove(key);
      notifyListeners();
    }
  }

  /// Persist expiry / seats / account name from a successful status probe.
  Future<void> _mergePortalAccountInfo(
    VerifiedPortal existing,
    VerifiedPortal fresh,
  ) async {
    final idx = _c.verified.indexWhere((x) => x.key == existing.key);
    final current = idx >= 0
        ? _c.verified[idx]
        : (_c.activePortal?.key == existing.key ? _c.activePortal : null);
    if (current == null) return;

    final updated = current.withAccountFrom(fresh);
    if (current.sameAccountFields(updated)) return;

    if (idx >= 0) {
      final next = List<VerifiedPortal>.of(_c.verified);
      next[idx] = updated;
      _c.verified = next;
      await IptvStore.save(_c.verified);
    }
    if (_c.activePortal?.key == current.key) {
      _c.activePortal = updated;
    }
    notifyListeners();
  }

  bool isPortalHealthChecking(String key) =>
      _portalHealthInFlight.contains(key);

  void selectBrowserCategory(String id) {
    _c.browserSelectedCategoryId = id;
    _c._commitBrowserSearchCategory(id);
    notifyListeners();
    unawaited(_persistLiveBrowserCategory(id));
  }

  Future<void> _persistLiveBrowserCategory(String categoryId) async {
    if (categoryId.isEmpty || _c.activeSection != IptvSection.live) return;
    final p = _c.activePortal;
    if (p == null) return;
    await IptvLiveChannelListsStore.saveLastCategory(
      IptvAliveStore.portalKey(p.portal),
      categoryId,
    );
  }

  /// While searching, playing a channel commits its real category for clear.
  void noteBrowserSearchPlayedStream(IptvStream stream) {
    if (!_c._browserSearchFilterActive) return;
    _c._commitBrowserSearchCategory(stream.categoryId);
  }

  void setBrowserSearch(String q) {
    final prev = _c.browserSearch.trim();
    final next = q.trim();
    if (prev.isEmpty && next.isNotEmpty) {
      _c._enterBrowserSearchFilter();
    } else if (prev.isNotEmpty && next.isEmpty) {
      _c._exitBrowserSearchFilter();
    }
    _c.browserSearch = q;
    notifyListeners();
  }

  Future<void> setLiveOnly(bool enabled) async {
    final p = _c.activePortal;
    if (p == null) return;
    _c.liveOnly = enabled;
    await IptvAliveStore.saveLiveOnly(
      IptvAliveStore.portalKey(p.portal),
      enabled,
    );
    notifyListeners();
  }
}
