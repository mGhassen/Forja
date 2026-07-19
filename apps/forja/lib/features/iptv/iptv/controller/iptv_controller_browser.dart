part of 'iptv_controller.dart';

mixin _IptvControllerBrowser on ChangeNotifier {
  IptvController get _c => this as IptvController;

  void openPortal(VerifiedPortal p) {
    unawaited(_c.selectPortal(p));
  }

  Future<void> openSection(
    IptvSection section, {
    bool persistSection = true,
    bool force = false,
  }) async {
    final p = _c.activePortal;
    if (p == null) return;
    final cacheKey = _catalogCacheKey(p.key, section);
    // Invalidate any in-flight catalog fetch for a previous shelf click.
    final loadId = ++_c._catalogLoadId;

    if (!force) {
      final snap = _c._catalogCache[cacheKey];
      if (snap != null) {
        _c.activeSection = section;
        _c.view = IptvView.browser;
        _c.isLoading = false;
        _c.error = null;
        _c.categories = snap.categories;
        _c.browserAllStreams = snap.streams;
        _c.browserSelectedCategoryId = '';
        _c.browserSearch = '';
        _c.browserSearchOpen = false;
        _c.streamHealth.clear();
        _c._healthInFlight.clear();
        _c._healthQueue.clear();
        cancelAllLazyChecks();
        _c._epgCache.clear();
        _c._guideEpgCache.clear();
        _c.liveOnly = false;
        _c.aliveStreamIds = const {};
        _c.aliveCheckedAt = null;
        notifyListeners();
        unawaited(
          _hydrateLiveSectionPrefs(
            portal: p,
            section: section,
            persistSection: persistSection,
          ),
        );
        return;
      }
    }

    _c.activeSection = section;
    _c.view = IptvView.browser;
    _c.isLoading = true;
    _c.error = null;
    _c.categories = const [];
    _c.browserAllStreams = const [];
    _c.browserSelectedCategoryId = null;
    _c.browserSearch = '';
    _c.browserSearchOpen = false;
    _c.aliveStreamIds = const {};
    _c.aliveCheckedAt = null;
    _c.streamHealth.clear();
    _c._healthInFlight.clear();
    _c._healthQueue.clear();
    cancelAllLazyChecks();
    _c._epgCache.clear();
    _c._guideEpgCache.clear();
    notifyListeners();
    try {
      final cats = await IptvClient.categories(p.portal, section);
      final streams = await IptvClient.streams(p.portal, section, '');
      // Shelf switched (or reloaded) while this request was in flight.
      if (loadId != _c._catalogLoadId) return;
      if (_c.activePortal?.key != p.key || _c.activeSection != section) return;

      _c.categories = section == IptvSection.live
          ? IptvLiveCatalog.withPins(cats)
          : [const IptvCategory(id: '', name: 'All'), ...cats];
      _c.browserAllStreams = streams;
      _c.browserSelectedCategoryId = '';

      if (streams.isEmpty && cats.isEmpty) {
        _c.error = 'Could not load channels from portal';
      }

      if (section == IptvSection.live) {
        final key = IptvAliveStore.portalKey(p.portal);
        _c.liveOnly = await IptvAliveStore.loadLiveOnly(key);
        if (loadId != _c._catalogLoadId) return;
        if (_c.activePortal?.key != p.key || _c.activeSection != section) {
          return;
        }
        final snap = await IptvAliveStore.load(key);
        if (loadId != _c._catalogLoadId) return;
        if (_c.activePortal?.key != p.key || _c.activeSection != section) {
          return;
        }
        if (snap != null) {
          _c.aliveStreamIds = snap.aliveIds;
          _c.aliveCheckedAt = snap.checkedAt;
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
      }

      _c._catalogCache[cacheKey] = _CatalogSnap(
        categories: _c.categories,
        streams: _c.browserAllStreams,
      );
    } catch (e) {
      if (loadId != _c._catalogLoadId) return;
      if (_c.activePortal?.key != p.key || _c.activeSection != section) return;
      _c.error = '$e';
    } finally {
      if (loadId == _c._catalogLoadId) {
        _c.isLoading = false;
        if (persistSection &&
            _c.activePortal?.key == p.key &&
            _c.activeSection == section) {
          await IptvStore.saveLastSection(section);
        }
        notifyListeners();
      }
    }
  }

  String _catalogCacheKey(String portalKey, IptvSection section) =>
      '$portalKey|${section.name}';

  Future<void> _loadLiveChannelLists(String portalKey) async {
    final favs = await IptvLiveChannelListsStore.loadFavorites(portalKey);
    final watched = await IptvLiveChannelListsStore.loadWatched(portalKey);
    _c.liveFavoriteIds = favs;
    _c.liveWatchedIds = watched;
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
      // Cache snap may predate synthetic Live pins — ensure they exist.
      if (!_c.categories.any((c) => c.id == IptvLiveCatalog.favoritesId)) {
        final api = _c.categories
            .where((c) => !IptvLiveCatalog.isPinnedId(c.id))
            .toList();
        _c.categories = IptvLiveCatalog.withPins(api);
        final cacheKey = _catalogCacheKey(portal.key, section);
        _c._catalogCache[cacheKey] = _CatalogSnap(
          categories: _c.categories,
          streams: _c.browserAllStreams,
        );
      }
    } else {
      if (_c.activePortal?.key != portal.key || _c.activeSection != section) {
        return;
      }
      _c.liveOnly = false;
      _c.aliveStreamIds = const {};
      _c.aliveCheckedAt = null;
      _c.liveFavoriteIds = const {};
      _c.liveWatchedIds = const [];
    }
    if (persistSection) {
      await IptvStore.saveLastSection(section);
    }
    if (_c.activePortal?.key != portal.key || _c.activeSection != section) {
      return;
    }
    notifyListeners();
  }

  void _invalidatePortalCatalogCache(String portalKey) {
    final prefix = '$portalKey|';
    _c._catalogCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  void _seedHealthFromCache() {
    for (final id in _c.aliveStreamIds) {
      _c.streamHealth[id] = true;
    }
  }

  /// Queue a health probe after the card has stayed visible (debounced).
  void scheduleLazyCheck(IptvStream s) {
    final p = _c.activePortal;
    if (p == null || _c.activeSection != IptvSection.live) return;
    if (s.kind != 'live' || s.streamId.isEmpty) return;
    if (_c.streamHealth.containsKey(s.streamId)) return;
    if (_c._healthInFlight.contains(s.streamId)) return;

    _c._healthDebounce[s.streamId]?.cancel();
    _c._healthDebounce[s.streamId] = Timer(IptvController._lazyCheckDelay, () {
      _c._healthDebounce.remove(s.streamId);
      lazyCheckStream(s);
    });
  }

  void cancelLazyCheck(String streamId) {
    _c._healthDebounce[streamId]?.cancel();
    _c._healthDebounce.remove(streamId);
  }

  void cancelAllLazyChecks() {
    for (final t in _c._healthDebounce.values) {
      t.cancel();
    }
    _c._healthDebounce.clear();
    _cancelAllPortalHealthTimers();
  }

  /// Probe a single live stream — capped concurrency, called after debounce.
  void lazyCheckStream(IptvStream s) {
    final p = _c.activePortal;
    if (p == null || _c.activeSection != IptvSection.live) return;
    if (s.kind != 'live' || s.streamId.isEmpty) return;
    if (_c.streamHealth.containsKey(s.streamId)) return;
    if (_c._healthInFlight.contains(s.streamId)) return;
    if (_c._healthInFlight.length >= IptvController._maxLazyHealthChecks) {
      if (!_c._healthQueue.any((x) => x.streamId == s.streamId)) {
        _c._healthQueue.add(s);
      }
      return;
    }
    unawaited(_runLazyHealthCheck(s));
  }

  Future<void> _runLazyHealthCheck(IptvStream s) async {
    final p = _c.activePortal;
    if (p == null) return;
    _c._healthInFlight.add(s.streamId);
    try {
      final url = IptvClient.streamUrl(p.portal, s);
      final ok = await IptvAliveChecker.checkOne(url);
      _c.streamHealth[s.streamId] = ok;
      if (ok) {
        _c.aliveStreamIds = {..._c.aliveStreamIds, s.streamId};
      }
      notifyListeners();
    } catch (_) {
      _c.streamHealth[s.streamId] = false;
      notifyListeners();
    } finally {
      _c._healthInFlight.remove(s.streamId);
      _drainHealthQueue();
    }
  }

  void _drainHealthQueue() {
    while (_c._healthQueue.isNotEmpty &&
        _c._healthInFlight.length < IptvController._maxLazyHealthChecks) {
      final next = _c._healthQueue.removeAt(0);
      if (!_c.streamHealth.containsKey(next.streamId)) {
        unawaited(_runLazyHealthCheck(next));
      }
    }
  }

  void markStreamDead(String streamId) {
    if (streamId.isEmpty) return;
    _c.streamHealth[streamId] = false;
    notifyListeners();
  }

  bool? healthFor(String streamId) => _c.streamHealth[streamId];

  // ── Portal panel live probes (hover / focus) ──
  final Map<String, bool> portalHealth = {};
  final Set<String> _portalHealthInFlight = {};
  final Map<String, Timer> _portalHealthDebounce = {};
  final Map<String, Timer> _portalHealthExpiry = {};
  static const _portalHealthDelay = Duration(milliseconds: 350);
  /// After this, green/red dots return to gray unknown until the next probe.
  static const _portalHealthTtl = Duration(minutes: 2);

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

  void _setPortalHealth(String key, bool ok) {
    portalHealth[key] = ok;
    _portalHealthExpiry[key]?.cancel();
    _portalHealthExpiry[key] = Timer(_portalHealthTtl, () {
      _portalHealthExpiry.remove(key);
      if (portalHealth.remove(key) != null) {
        notifyListeners();
      }
    });
    notifyListeners();
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
    if (portalHealth.containsKey(key)) return;
    if (!_portalHealthInFlight.add(key)) return;
    notifyListeners();
    try {
      final fresh = await IptvClient.verifyOrNull(
        v.portal,
        timeout: const Duration(seconds: 5),
      );
      _setPortalHealth(key, fresh != null);
    } catch (_) {
      _setPortalHealth(key, false);
    } finally {
      _portalHealthInFlight.remove(key);
      notifyListeners();
    }
  }

  bool isPortalHealthChecking(String key) =>
      _portalHealthInFlight.contains(key);

  void selectBrowserCategory(String id) {
    _c.browserSelectedCategoryId = id;
    notifyListeners();
  }

  void setBrowserSearch(String q) {
    _c.browserSearch = q;
    notifyListeners();
  }

  Future<void> setLiveOnly(bool enabled) async {
    final p = _c.activePortal;
    if (p == null) return;
    _c.liveOnly = enabled;
    await IptvAliveStore.saveLiveOnly(IptvAliveStore.portalKey(p.portal), enabled);
    notifyListeners();
  }
}
