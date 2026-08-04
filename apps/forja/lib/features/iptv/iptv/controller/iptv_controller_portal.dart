part of 'iptv_controller.dart';

mixin _IptvControllerPortal on ChangeNotifier {
  IptvController get _c => this as IptvController;

  Future<void> scrape() async {
    if (!AccountFeatures.instance.isIptvScrapeEnabled) return;
    if (_c.isScraping) return;
    _c.isScraping = true;
    _c._scrapeCancel = false;
    _c.statusText = 'Finding portals…';
    _c.canGetMore = false;
    notifyListeners();
    await _scrapeAndVerify();
  }

  void stopScrape() {
    _c._scrapeCancel = true;
    _c.statusText = 'Stopped.';
    notifyListeners();
  }

  Future<void> getMore() async {
    if (!AccountFeatures.instance.isIptvScrapeEnabled) return;
    if (_c.isScraping) return;
    _c.isScraping = true;
    _c._scrapeCancel = false;
    _c.statusText = 'Searching for more…';
    notifyListeners();
    await _scrapeAndVerify();
  }

  Future<void> _scrapeAndVerify() async {
    final room = AccountFeatures.instance.iptvPortalSlotsRemaining(
      _c.verified.length,
    );
    if (room < 1) {
      final msg = AccountFeatures.instance.iptvPortalLimitReachedMessage();
      _c.statusText = msg;
      _c.isScraping = false;
      ForjaToast.warning(msg);
      notifyListeners();
      return;
    }
    // Prefer up to 5 new portals per press, but never exceed remaining slots.
    final targetAlive = room < 5 ? room : 5;
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
          !_c._scrapeCancel) {
        // ── Step 1: fetch fresh pages until the pending queue has work.
        //         (Pending queue may already be non-empty from a prior
        //         press that found enough alive portals before draining
        //         everything - in that case we skip the fetch entirely.)
        while (_c._pendingPortals.isEmpty &&
            pagesTried < maxPagesPerPress &&
            !_c._scrapeCancel) {
          pagesTried++;
          page = await IptvScraper.scrapeCatalogPage(
            maxResults: 50,
            after: _c._scrapeAfter,
          );
          _c._scrapeAfter = page.nextAfter;

          // Add only portals we haven't already verified, attempted, or queued.
          // Dedup is by credentials (user|pass) - same login on a different
          // host still counts as a duplicate.
          for (final p in page.portals) {
            if (_c._verifiedKeys.contains(p.credKey)) continue;
            if (_c._attemptedKeys.contains(p.credKey)) continue;
            if (_c._pendingKeys.contains(p.credKey)) continue;
            _c._pendingKeys.add(p.credKey);
            _c._pendingPortals.add(p);
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

          // No more pages from this source - bail out of the fetch loop.
          if (_c._pendingPortals.isEmpty && !page.hasMore) {
            exhausted = true;
            break;
          }
        }

        if (_c._scrapeCancel) break;

        if (_c._pendingPortals.isEmpty) {
          // Nothing left to verify and nothing left to fetch.
          break;
        }

        // ── Step 2: verify what we've got. Only ask the verifier for
        //         however many MORE alive portals we still need this press.
        final remaining = targetAlive - newAlive.length;
        _c.statusText =
            'Verifying ${_c._pendingPortals.length} portals  ·  need $remaining more';
        notifyListeners();

        final snapshot = List<IptvPortal>.from(_c._pendingPortals);
        await IptvVerifier.verifyUntil(
          portals: snapshot,
          target: remaining,
          isCancelled: () => _c._scrapeCancel,
          onAttempted: (p) {
            _c._attemptedKeys.add(p.credKey);
            if (_c._pendingKeys.remove(p.credKey)) {
              _c._pendingPortals.removeWhere((x) => x.credKey == p.credKey);
            }
          },
          onProgress: (c, t, a) {
            final total = newAlive.length + a;
            _c.statusText =
                'Verifying $c / $t  ·  alive $total / $targetAlive';
            notifyListeners();
          },
          onAlive: (v) {
            if (_c._verifiedKeys.add(v.credKey)) {
              newAlive.add(v);
              _c._registerPortalAdded(v.key);
              _c.verified = _c._sortPortals([..._c.verified, v]);
              notifyListeners();
            }
          },
        );

        // If we still need more and the queue is dry, the outer loop will
        // fetch the next page automatically. If the source has no more
        // pages either, we'll exit cleanly on the next iteration.
        if (newAlive.length < targetAlive &&
            _c._pendingPortals.isEmpty &&
            (page == null || !page.hasMore)) {
          exhausted = true;
          break;
        }
      }

      if (newAlive.isNotEmpty) await IptvStore.save(_c.verified);

      // Get-More is meaningful if either (a) we still have queued portals
      // we haven't verified yet, or (b) the catalog has more pages.
      _c.canGetMore = _c._pendingPortals.isNotEmpty ||
          (page?.hasMore ?? _c.canGetMore);

      if (_c._scrapeCancel) {
        _c.statusText = 'Stopped.';
      } else if (newAlive.isEmpty) {
        _c.statusText = exhausted
            ? 'No live portals found.'
            : (_c.canGetMore
                ? 'No new live portals. Try Get More.'
                : 'No new live portals.');
      } else {
        final hit = newAlive.length >= targetAlive;
        _c.statusText = hit
            ? 'Found ${newAlive.length} live portals.'
            : 'Found ${newAlive.length} live portals'
                '${exhausted ? ' (catalog exhausted).' : ' (stopped early).'}';
        if (_c._pendingPortals.isNotEmpty) {
          _c.statusText += ' (${_c._pendingPortals.length} more queued)';
        }
      }
    } catch (e) {
      _c.statusText = 'Scrape failed: $e';
    } finally {
      _c.isScraping = false;
      notifyListeners();
    }
  }

  Future<void> runVerification() async {
    final manual = _c.manualVerified;
    if (manual.isEmpty) return;
    _c.statusText = 'Re-checking saved portals…';
    notifyListeners();
    // Only re-verify user-added (Manual) portals. Internally-scraped
    // ones are kept untouched so the channel hub can still use them.
    final manualKeys = manual.map((v) => v.key).toSet();
    final scrapedKept = _c.verified.where((v) => !manualKeys.contains(v.key)).toList();
    final freshManual = <VerifiedPortal>[];
    for (final v in manual) {
      final fresh = await IptvClient.verifyOrNull(v.portal);
      if (fresh != null) freshManual.add(fresh.withLabel(v.label));
    }
    _c.verified = _c._sortPortals([...freshManual, ...scrapedKept]);
    _c._verifiedKeys
      ..clear()
      ..addAll(_c.verified.map((v) => v.credKey));
    await IptvStore.save(_c.verified);
    _c.statusText = '${freshManual.length} portals still alive.';
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Edit / select / delete portals
  // ────────────────────────────────────────────────────────────────────────
  void toggleEditMode() {
    _c.editMode = !_c.editMode;
    if (!_c.editMode) _c.selected.clear();
    notifyListeners();
  }

  void toggleSelect(String key) {
    if (_c.selected.contains(key)) {
      _c.selected.remove(key);
    } else {
      _c.selected.add(key);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (_c.selected.length == _c.verified.length) {
      _c.selected.clear();
    } else {
      _c.selected
        ..clear()
        ..addAll(_c.verified.map((v) => v.key));
    }
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_c.selected.isEmpty) return;
    for (final k in _c.selected) {
      _c._invalidatePortalCatalogCache(k);
      _c._newPortalKeys.remove(k);
      _c._portalRecencyKeys.remove(k);
    }
    final keep = _c.verified.where((v) => !_c.selected.contains(v.key)).toList();
    _c.verified = keep;
    _c._verifiedKeys
      ..clear()
      ..addAll(keep.map((v) => v.credKey));
    if (_c.activePortal != null && _c.selected.contains(_c.activePortal!.key)) {
      _c.activePortal = null;
      _c.activeSection = null;
      _c.categories = const [];
      _c.browserAllStreams = const [];
      await IptvStore.clearLastPortalKey();
    }
    _c.selected.clear();
    _c.editMode = false;
    // Intentional delete - allow cloud assignment count to drop (issue 118).
    await IptvStore.save(keep, scheduleSync: false);
    if (keep.isEmpty) {
      await SyncDomainBridge.instance.pushEmptyIptvInventory();
    } else {
      await SyncDomainBridge.instance.pushIptvInventoryAfterDelete();
    }
    notifyListeners();
  }

  Future<void> deletePortal(String key) async {
    _c._invalidatePortalCatalogCache(key);
    _c.selected
      ..clear()
      ..add(key);
    await deleteSelected();
  }

  Future<void> updatePortal({
    required VerifiedPortal existing,
    required String url,
    required String username,
    required String password,
    String label = '',
    IptvPortalPlatform platform = IptvPortalPlatform.xtream,
    String userAgent = '',
  }) async {
    final cleanUrl = normalizeUrl(url);
    final user = _normalizedUsername(platform, username);
    final pass = password.trim();
    if (!_credentialsOk(platform, cleanUrl, user, pass)) {
      _c.addError = _credentialsError(platform);
      notifyListeners();
      return;
    }
    _c.isAdding = true;
    _c.addError = null;
    notifyListeners();
    final p = IptvPortal(
      url: cleanUrl,
      username: user,
      password: pass,
      source: existing.portal.source.isEmpty ? 'Manual' : existing.portal.source,
      platform: platform,
      userAgent: userAgent.trim(),
    );
    if (p.credKey != existing.credKey && _c._verifiedKeys.contains(p.credKey)) {
      _c.addError = 'Portal already added';
      _c.isAdding = false;
      notifyListeners();
      return;
    }
    final verified = await IptvClient.verifyOrNull(p);
    _c.isAdding = false;
    if (verified == null) {
      _c.addError = 'Login failed - wrong credentials or dead portal.';
      notifyListeners();
      return;
    }
    final v = verified.withLabel(label);
    final wasActive = _c.activePortal?.key == existing.key;
    _c._invalidatePortalCatalogCache(existing.key);
    final next = _c.verified
        .where((x) => x.key != existing.key)
        .toList();
    _c.verified = _c._sortPortals([v, ...next]);
    _c._verifiedKeys
      ..clear()
      ..addAll(_c.verified.map((x) => x.credKey));
    await IptvStore.save(_c.verified);
    if (wasActive) {
      await _c.selectPortal(v);
    } else {
      notifyListeners();
    }
  }

  static String _normalizedUsername(IptvPortalPlatform platform, String username) {
    if (platform == IptvPortalPlatform.m3u) {
      return IptvPortalPlatform.m3uUsernameSentinel;
    }
    return username.trim();
  }

  static bool _credentialsOk(
    IptvPortalPlatform platform,
    String url,
    String username,
    String password,
  ) {
    if (url.isEmpty) return false;
    switch (platform) {
      case IptvPortalPlatform.xtream:
        return username.isNotEmpty && password.isNotEmpty;
      case IptvPortalPlatform.m3u:
        return true;
      case IptvPortalPlatform.stalker:
        return username.isNotEmpty;
    }
  }

  static String _credentialsError(IptvPortalPlatform platform) =>
      switch (platform) {
        IptvPortalPlatform.xtream => 'URL, username, and password required',
        IptvPortalPlatform.m3u => 'Playlist URL required',
        IptvPortalPlatform.stalker => 'Portal URL and MAC address required',
      };

  // ────────────────────────────────────────────────────────────────────────
  // Add manual portal
  // ────────────────────────────────────────────────────────────────────────
  void openAddDialog() {
    _c.showAddDialog = true;
    _c.addError = null;
    notifyListeners();
  }

  void dismissAddDialog() {
    if (_c.isAdding) return;
    _c.showAddDialog = false;
    _c.addError = null;
    notifyListeners();
  }

  Future<void> addManual({
    required String url,
    required String username,
    required String password,
    String label = '',
    bool closePanel = true,
    IptvPortalPlatform platform = IptvPortalPlatform.xtream,
    String userAgent = '',
  }) async {
    final cleanUrl = normalizeUrl(url);
    final user = _normalizedUsername(platform, username);
    final pass = password.trim();
    if (!_credentialsOk(platform, cleanUrl, user, pass)) {
      _c.addError = _credentialsError(platform);
      notifyListeners();
      return;
    }
    if (!AccountFeatures.instance.canAddIptvPortal(_c.verified.length)) {
      final msg = AccountFeatures.instance.iptvPortalLimitReachedMessage();
      _c.addError = msg;
      ForjaToast.warning(msg);
      notifyListeners();
      return;
    }
    _c.isAdding = true;
    _c.addError = null;
    notifyListeners();
    final p = IptvPortal(
      url: cleanUrl,
      username: user,
      password: pass,
      source: 'Manual',
      platform: platform,
      userAgent: userAgent.trim(),
    );
    if (_c._verifiedKeys.contains(p.credKey)) {
      _c.addError = 'Portal already added (same username & password)';
      _c.isAdding = false;
      notifyListeners();
      return;
    }
    final verified = await IptvClient.verifyOrNull(p);
    _c.isAdding = false;
    if (verified == null) {
      _c.addError = 'Login failed - wrong credentials or dead portal.';
      notifyListeners();
      return;
    }
    final v = verified.withLabel(label);
    _c._registerPortalAdded(v.key);
    _c.verified = _c._sortPortals([v, ..._c.verified]);
    _c._verifiedKeys.add(v.credKey);
    await IptvStore.save(_c.verified);
    _c.showAddDialog = false;
    if (!closePanel) _c.openPortalPanel();
    await _c.selectPortal(v, closePanel: closePanel);
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
    _c.statusText = 'Importing 0 / ${candidates.length}…';
    notifyListeners();

    int added = 0, skipped = 0, failed = 0, done = 0, skippedLimit = 0;
    final newAlive = <VerifiedPortal>[];
    final seenInBatch = <String>{};

    Future<void> work(IptvPortal p) async {
      // Dedupe across the batch and against existing list.
      if (_c._verifiedKeys.contains(p.credKey) ||
          !seenInBatch.add(p.credKey)) {
        skipped++;
      } else {
        final v = await IptvClient.verifyOrNull(p);
        if (v == null) {
          failed++;
        } else if (!AccountFeatures.instance.canAddIptvPortal(
          _c.verified.length + newAlive.length,
        )) {
          // Re-check after await — parallel workers may have filled the cap.
          skipped++;
          skippedLimit++;
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
            label: v.label,
            name: v.name,
            expiry: v.expiry,
            maxConnections: v.maxConnections,
            activeConnections: v.activeConnections,
          );
          newAlive.add(manualV);
          _c._verifiedKeys.add(manualV.credKey);
          added++;
        }
      }
      done++;
      _c.statusText = 'Importing $done / ${candidates.length}…';
      notifyListeners();
    }

    // Verify in parallel - same approach as scrape verifier, but simpler.
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
        _c._registerPortalAdded(v.key);
      }
      _c.verified = _c._sortPortals([...newAlive, ..._c.verified]);
      await IptvStore.save(_c.verified);
    }

    isImporting = false;
    _c.statusText = 'Imported $added · skipped $skipped · failed $failed';
    if (skippedLimit > 0) {
      ForjaToast.warning(
        AccountFeatures.instance.iptvPortalLimitReachedMessage(),
      );
    }
    notifyListeners();
    return (added: added, skipped: skipped, failed: failed, error: null);
  }

  /// Deal portals from the central catalog pool (RFC-040). Burns 1 credit.
  Future<({int assigned, String? error})> dealFromPool({
    String region = 'ANY',
    int count = 5,
  }) async {
    if (!SyncService.instance.isSignedIn) {
      return (assigned: 0, error: 'Sign in to deal portals.');
    }
    if (!AccountFeatures.instance.isDealPortalEnabled) {
      return (assigned: 0, error: 'Deal portals is not enabled for this account.');
    }
    if (AccountFeatures.instance.iptvCredits < 1) {
      return (assigned: 0, error: 'No credits left.');
    }
    final room = AccountFeatures.instance.iptvPortalSlotsRemaining(
      _c.verified.length,
    );
    if (room < 1) {
      final msg = AccountFeatures.instance.iptvPortalLimitReachedMessage();
      ForjaToast.warning(msg);
      return (assigned: 0, error: msg);
    }
    final dealCount = count < room ? count : room;
    final SyncProfile profile;
    try {
      final active = await SyncService.instance.activeProfile();
      if (active == null) {
        return (assigned: 0, error: 'No active profile.');
      }
      profile = active;
    } on SyncProfileFetchException catch (e) {
      return (assigned: 0, error: e.message);
    }
    _c.statusText = 'Dealing $dealCount portals ($region)…';
    notifyListeners();
    final beforeKeys = _c.verified.map((v) => v.key).toSet();
    try {
      final ids = await SyncService.instance.dealIptvPortals(
        profileId: profile.id,
        region: region,
        count: dealCount,
      );
      await SyncService.instance.pullAccountFeatures(force: true);
      final pulled =
          await SyncDomainBridge.instance.pullIptvPortalsFromCloud();
      if (pulled) {
        await _c._softReloadPortalsFromStore();
        // Same session-new chrome as scrape (accent + NEW badge until hover).
        for (final v in _c.verified) {
          if (!beforeKeys.contains(v.key)) {
            _c._registerPortalAdded(v.key);
          }
        }
        _c.verified = _c._sortPortals(_c.verified);
      }
      final n = ids.length;
      if (!pulled && n > 0) {
        _c.statusText =
            'Dealt $n portal${n == 1 ? '' : 's'} but sync failed - try again later.';
      } else {
        _c.statusText = n == 0
            ? 'Deal returned no portals.'
            : 'Dealt $n portal${n == 1 ? '' : 's'}.';
      }
      notifyListeners();
      return (assigned: n, error: null);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _c.statusText = 'Deal failed: $msg';
      if (msg.contains('Maximum of') && msg.contains('portal')) {
        ForjaToast.warning(msg);
      } else {
        ForjaToast.error(msg);
      }
      notifyListeners();
      return (assigned: 0, error: msg);
    }
  }

}
