part of 'iptv_controller.dart';

mixin _IptvControllerChannels on ChangeNotifier {
  IptvController get _c => this as IptvController;

  void openChannelsHub() {
    _c.activeHardcoded = null;
    _c.channelResults = const [];
    _c.channelStatus = '';
    _c.view = IptvView.channelsHub;
    notifyListeners();
  }

  void stopChannelSearch() {
    _c._channelCancel = true;
    _c.channelIsRunning = false;
    _c.channelStatus = 'Stopped.';
    notifyListeners();
  }

  Future<void> openHardcodedChannel(HardcodedChannel ch) async {
    _c.activeHardcoded = ch;
    _c.view = IptvView.channelResults;
    _c.channelResults = const [];
    _c.channelStatus = '';
    notifyListeners();
    final stored = await IptvChannelResultsStore.load(ch.id);
    final favs = await IptvChannelFavoritesStore.load(ch.id);
    _c._favoriteHits[ch.id] = favs;
    _c.channelResults = _c._sortHitsFavoritesFirst(
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
    if (_c.channelResults.isEmpty) {
      await runChannelScan(ch);
    }
  }

  Future<void> searchAgainChannel() async {
    final ch = _c.activeHardcoded;
    if (ch == null) return;
    _c._channelAttempted.remove(ch.id);
    _c._channelCatalogAfter.remove(ch.id);
    _c._channelScrapedPool.remove(ch.id);
    _c.channelResults = const [];
    await IptvChannelResultsStore.clear(ch.id);
    notifyListeners();
    await runChannelScan(ch);
  }

  Future<void> getMoreChannels() async {
    final ch = _c.activeHardcoded;
    if (ch == null) return;
    await runChannelScan(ch, scrapeMore: true);
  }

  Future<void> deleteChannelHit(int index) async {
    final ch = _c.activeHardcoded;
    if (ch == null) return;
    if (index < 0 || index >= _c.channelResults.length) return;
    final updated = [..._c.channelResults]..removeAt(index);
    _c.channelResults = updated;
    await _saveChannelHits(ch.id, updated);
    notifyListeners();
  }

  Future<void> deleteChannelHits(Set<int> indices) async {
    final ch = _c.activeHardcoded;
    if (ch == null) return;
    final keep = <ChannelHit>[];
    for (var i = 0; i < _c.channelResults.length; i++) {
      if (!indices.contains(i)) keep.add(_c.channelResults[i]);
    }
    _c.channelResults = keep;
    await _saveChannelHits(ch.id, keep);
    notifyListeners();
  }

  Future<void> _saveChannelHits(String channelId, List<ChannelHit> hits) async {
    final stored = hits
        .map((h) => StoredHit(
              portalUrl: h.portal.portal.url,
              portalUser: h.portal.portal.username,
              portalPass: h.portal.portal.password,
              portalName: h.portal.displayLabel,
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
    if (_c.channelIsRunning) return;
    _c.channelIsRunning = true;
    _c._channelCancel = false;
    notifyListeners();

    final attempted = _c._channelAttempted.putIfAbsent(ch.id, () => <String>{});
    final pool = _c._channelScrapedPool.putIfAbsent(ch.id, () => []);

    // ── 1. Bootstrap pool from globally-verified portals ──
    final poolKeys = pool.map((p) => p.key).toSet();
    for (final vp in _c.verified) {
      if (!attempted.contains(vp.key) && !poolKeys.contains(vp.key)) {
        pool.add(vp.portal);
      }
    }

    // ── 2. Scrape fresh portals if requested or we're empty ──
    final needsBootstrap =
        _c.verified.isEmpty && pool.every((p) => attempted.contains(p.key));
    final canScrape = AccountFeatures.instance.isIptvScrapeEnabled;
    if (canScrape && (scrapeMore || needsBootstrap)) {
      final pendingQueue =
          _c._channelPendingPortals.putIfAbsent(ch.id, () => <IptvPortal>[]);
      final pendingKeys =
          _c._channelPendingKeys.putIfAbsent(ch.id, () => <String>{});

      // Drop anything from the queue that we've since verified or attempted
      // through another channel's scan.
      pendingQueue.removeWhere((p) =>
          _c._verifiedKeys.contains(p.credKey) || attempted.contains(p.key));
      pendingKeys
        ..clear()
        ..addAll(pendingQueue.map((p) => p.credKey));

      // Only fetch a new catalog page when the queue is empty — otherwise
      // we'd be throwing away the un-tested portals from previous presses.
      if (pendingQueue.isEmpty) {
        _c.channelStatus = 'Looking for more portals…';
        notifyListeners();
        try {
          final after = _c._channelCatalogAfter[ch.id];
          final page = await IptvScraper.scrapeCatalogPage(
              maxResults: 60, after: after);
          if (_c._channelCancel) {
            _c.channelIsRunning = false;
            _c.channelStatus = 'Stopped.';
            notifyListeners();
            return;
          }
          _c._channelCatalogAfter[ch.id] = page.nextAfter;
          final knownKeys = {
            ...pool.map((p) => p.key),
            ...attempted,
          };
          for (final p in page.portals) {
            if (_c._verifiedKeys.contains(p.credKey)) continue;
            if (knownKeys.contains(p.key)) continue;
            if (pendingKeys.add(p.credKey)) pendingQueue.add(p);
          }
          if (pendingQueue.isEmpty &&
              !page.hasMore &&
              _c.channelResults.isEmpty) {
            _c.channelIsRunning = false;
            _c.channelStatus = 'No more portals available.';
            notifyListeners();
            return;
          }
        } catch (_) {}
      }

      if (pendingQueue.isNotEmpty) {
        final snapshot = List<IptvPortal>.from(pendingQueue);
        _c.channelStatus = 'Verifying ${snapshot.length} new portal'
            '${snapshot.length == 1 ? '' : 's'}…';
        notifyListeners();
        await IptvVerifier.verifyUntil(
          portals: snapshot,
          target: 5,
          isCancelled: () => _c._channelCancel,
          onAttempted: (p) {
            if (pendingKeys.remove(p.credKey)) {
              pendingQueue.removeWhere((x) => x.credKey == p.credKey);
            }
          },
          onAlive: (v) async {
            if (_c._verifiedKeys.add(v.credKey)) {
              _c._registerPortalAdded(v.key);
              _c.verified = _c._sortPortals([..._c.verified, v]);
              await IptvStore.save(_c.verified);
              if (!attempted.contains(v.key) &&
                  !pool.any((p) => p.key == v.key)) {
                pool.add(v.portal);
              }
            }
          },
          onProgress: (c, t, a) {
            _c.channelStatus = 'Verifying portals $c/$t · $a working'
                '${pendingQueue.isNotEmpty ? ' · ${pendingQueue.length} queued' : ''}';
            notifyListeners();
          },
        );
      }
    }

    if (_c._channelCancel) {
      _c.channelIsRunning = false;
      _c.channelStatus = 'Stopped.';
      notifyListeners();
      return;
    }

    // ── 3. Take next 8 portals from the pool ──
    final toScan = pool.take(8).toList();
    if (toScan.isEmpty) {
      _c.channelIsRunning = false;
      _c.channelStatus = _c.channelResults.isEmpty
          ? 'No working portals available. Tap Get More.'
          : '${_c.channelResults.length} alive · no more portals to scan.';
      notifyListeners();
      return;
    }

    _c.channelStatus = 'Searching ${toScan.length} portal'
        '${toScan.length == 1 ? '' : 's'}…';
    notifyListeners();

    // Mark attempted up-front so re-entry skips them
    for (final p in toScan) {
      attempted.add(p.key);
    }
    pool.removeWhere((p) => attempted.contains(p.key));

    // ── 4. Fan out: fetch live streams from all 8 portals IN PARALLEL ──
    if (_c._channelCancel) {
      _c.channelIsRunning = false;
      _c.channelStatus = 'Stopped.';
      notifyListeners();
      return;
    }
    final verifiedByKey = {for (final v in _c.verified) v.key: v};
    final candidatesByPortal =
        await Future.wait(toScan.map((p) async {
      if (_c._channelCancel) return <_Candidate>[];
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
    final have = _c.channelResults.map((h) => h.streamUrl).toSet();
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

    if (newCandidates.isEmpty || _c._channelCancel) {
      _c.channelIsRunning = false;
      _c.channelStatus = _c.channelResults.isEmpty
          ? 'No matching channels found. Try Get More.'
          : '${_c.channelResults.length} alive · no new matches.';
      notifyListeners();
      return;
    }

    // ── 5. ONE 24-wide alive-check pass across ALL candidates ──
    final byUrl = {for (final c in newCandidates) c.url: c};
    _c.channelStatus = 'Found ${newCandidates.length} candidate'
        '${newCandidates.length == 1 ? '' : 's'} · verifying…';
    notifyListeners();

    await IptvAliveChecker.launchCheck(
      streams: newCandidates.map((c) => MapEntry(c.url, c.url)).toList(),
      isCancelled: () => _c._channelCancel,
      onResult: (id, alive) async {
        if (!alive) return;
        final c = byUrl[id];
        if (c == null) return;
        if (_c.channelResults.any((h) => h.streamUrl == c.url)) return;
        final hit = ChannelHit(portal: c.portal, stream: c.stream, streamUrl: c.url);
        _c.channelResults =
            _c._sortHitsFavoritesFirst(ch.id, [..._c.channelResults, hit]);
        await _saveChannelHits(ch.id, _c.channelResults);
        notifyListeners();
      },
      onProgress: (p) async {
        _c.channelStatus = 'Verifying ${p.checked}/${p.total} · '
            '${_c.channelResults.length} alive';
        notifyListeners();
      },
      onDone: () async {
        _c.channelIsRunning = false;
        _c.channelStatus = _c.channelResults.isEmpty
            ? 'No alive streams for ${ch.name}. Try Get More.'
            : '${_c.channelResults.length} alive stream'
                '${_c.channelResults.length == 1 ? '' : 's'} saved.';
        notifyListeners();
      },
    );
    if (_c._channelCancel) {
      _c.channelIsRunning = false;
      _c.channelStatus = 'Stopped.';
      notifyListeners();
    }
  }
}
