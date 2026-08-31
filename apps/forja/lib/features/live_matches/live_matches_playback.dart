part of 'live_matches_screen.dart';

mixin _LiveMatchesPlayback
    on ConsumerState<LiveMatchesScreen>, _LiveMatchesData {
  @override
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  /// Leanback TV: never offer PPV / Streamed / Mut embed rows — only native.
  bool get _tvNativeLiveOnly => ShellScope.metricsOf(context).usesTvDensity;

  /// Stremio catalog/stream fallback — All, Stremio, Forja Sports only.
  bool get _offerStremioPlayFallback =>
      _s._server == _LiveMatchesServer.all ||
      _s._server == _LiveMatchesServer.stremio ||
      _s._server == _LiveMatchesServer.iptvSports;

  VoidCallback _iptvSportsPanelDismissCancel() => () {
    _s._iptvSportsSearchGen++;
    Engine.cancelLiveMatchesFetch();
  };

  bool _iptvSportsSearchStale(int searchGen) =>
      searchGen != _s._iptvSportsSearchGen;

  /// Loading dialog that Back / Cancel can dismiss. Returns `false` if cancelled.
  Future<bool> _runWithCancellableLoading(
    String message,
    Future<void> Function(void Function(String) setMessage) action,
  ) async {
    if (!mounted) return false;
    var cancelled = false;
    var closingOurselves = false;
    final messageNotifier = ValueNotifier(message);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          // Imperative pop in [finally] also invokes this - don't treat that
          // as user cancel or play never continues after a successful resolve.
          if (didPop && !closingOurselves) cancelled = true;
        },
        child: _LiveCancellableLoadingDialog(
          messageListenable: messageNotifier,
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
    try {
      await action((next) {
        if (messageNotifier.value != next) messageNotifier.value = next;
      });
    } finally {
      if (mounted && !cancelled) {
        closingOurselves = true;
        try {
          FocusManager.instance.primaryFocus?.unfocus();
        } catch (_) {}
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
      messageNotifier.dispose();
    }
    return !cancelled && mounted;
  }

  Future<void> _openMergedMatch(
    _DamiTvStream ppv,
    _StreamedMatch streamed,
  ) async {
    if (_s._server == _LiveMatchesServer.iptvSports) {
      await _openIptvSportsMatch(streamed);
      return;
    }
    if (_tvNativeLiveOnly) {
      if (_s._server == _LiveMatchesServer.forjaLive) {
        await _openForjaLiveTvSources(streamed, ppvAnchor: ppv);
        return;
      }
      await _openTvNativeSourcesOnly(streamed);
      return;
    }
    if (!mounted) return;
    final streams = <_StreamedStream>[];
    final ok = await _runWithCancellableLoading(
      'Loading PPV and Streamed sources…',
      (setMessage) async {
        try {
          for (final source in streamed.sources) {
            setMessage('Loading ${source.source}…');
            streams.addAll(
              await _fetchStreamedStreams(source, allowFallback: false),
            );
          }
        } catch (e) {
          debugPrint('[LiveMatches] Merged Streamed resolve error: $e');
        }
      },
    );
    if (!ok || !mounted) return;

    final hasPpv = ppv.iframe.isNotEmpty;
    var totalViewers = hasPpv ? ppv.viewers : 0;
    for (final s in streams) {
      totalViewers += s.viewers;
    }
    _rememberEventStreamViewers(streamed, totalViewers);
    if (hasPpv) _rememberPpvStreamViewers(ppv, totalViewers);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MergedMatchStreamSheet(
        title: streamed.title.isNotEmpty ? streamed.title : ppv.name,
        ppv: hasPpv ? ppv : null,
        streamed: streams,
        onPpvSelected: () {
          Navigator.pop(context);
          unawaited(_openDamiTvStream(ppv));
        },
        onStreamedSelected: (stream) {
          Navigator.pop(context);
          unawaited(_openStreamedEmbed(streamed, stream));
        },
      ),
    );
  }

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    final forjaLive = _s._server == _LiveMatchesServer.forjaLive;
    if (_s._server == _LiveMatchesServer.iptvSports ||
        (match.isIptvSports && !forjaLive)) {
      await _openIptvSportsMatch(match);
      return;
    }
    if (match.isStremio) {
      await _openStremioSportMatch(match);
      return;
    }
    if (_tvNativeLiveOnly) {
      // Forja Live → plugin streams. Never route to Forja Sports Xtream.
      if (forjaLive) {
        await _openForjaLiveTvSources(match);
        return;
      }
      await _openTvNativeSourcesOnly(match);
      return;
    }
    final catalogMatches = _streamedMatchesForEvent(match, _s._streamedMatches);
    if (forjaLive && (this as _LiveMatchesForjaLive)._forjaLiveAnyLoading) {
      ForjaToast.info('Loading Forja Live plugins…');
      return;
    }

    final choices = <_StreamedStreamChoice>[];
    if (catalogMatches.isNotEmpty) {
      final ok = await _runWithCancellableLoading(
        'Finding streams…',
        (setMessage) async {
          choices.addAll(
            await _resolveAllCatalogStreamChoices(
              catalogMatches,
              onProgress: setMessage,
            ),
          );
        },
      );
      if (!ok || !mounted) return;
    }

    if (choices.isEmpty &&
        !forjaLive &&
        catalogMatches.any((m) => m.sportMatchGame != null)) {
      await _openIptvSportsMatch(match);
      return;
    }

    _prependMatchingPpvChoices(match, choices);
    _rememberEventStreamViewers(match, _sheetTotalViewers(choices));
    _showResolvedStreamSheet(match, choices);
  }

  void _rememberEventStreamViewers(_StreamedMatch match, int total) {
    if (total <= 0 || !mounted) return;
    final key = _liveEventViewerKey(match);
    if (_s._eventStreamViewerTotals[key] == total) return;
    setState(() => _s._eventStreamViewerTotals[key] = total);
  }

  void _rememberPpvStreamViewers(_DamiTvStream ppv, int total) {
    if (total <= 0 || !mounted) return;
    final key = _liveEventViewerKeyFromPpv(ppv);
    if (_s._eventStreamViewerTotals[key] == total) return;
    setState(() => _s._eventStreamViewerTotals[key] = total);
  }

  void _prependMatchingPpvChoices(
    _StreamedMatch match,
    List<_StreamedStreamChoice> choices,
  ) {
    if (choices.any(_isPpvStreamChoice)) return;
    for (final ppv in _s._damiTvStreams) {
      if (!_samePpvStreamedMatch(ppv, match) || ppv.iframe.trim().isEmpty) {
        continue;
      }
      choices.insert(0, _ppvStreamChoice(ppv, match));
      break;
    }
  }

  _StreamedStreamChoice _ppvStreamChoice(
    _DamiTvStream ppv,
    _StreamedMatch anchor,
  ) {
    return _StreamedStreamChoice(
      catalogMatch: _StreamedMatch(
        id: 'ppv:${ppv.id}',
        title: anchor.title.isNotEmpty ? anchor.title : ppv.name,
        category: ppv.categoryName,
        dateMs: ppv.startsAt > 0 ? ppv.startsAt * 1000 : anchor.dateMs,
        poster: ppv.poster.isNotEmpty ? ppv.poster : anchor.poster,
        popular: false,
        airing: ppv.isLive,
        viewers: ppv.viewers,
        homeTeam: ppv.homeTeam ?? anchor.homeTeam,
        homeBadge: ppv.homeBadge ?? anchor.homeBadge,
        awayTeam: ppv.awayTeam ?? anchor.awayTeam,
        awayBadge: ppv.awayBadge ?? anchor.awayBadge,
        sources: const [],
        catalog: 'forja_live',
        livePluginId: _ppvLivePluginId(),
      ),
      stream: _StreamedStream(
        id: ppv.id,
        streamNo: 1,
        language: '',
        hd: false,
        embedUrl: ppv.iframe,
        source: 'ppv',
        viewers: ppv.viewers,
      ),
    );
  }

  void _showResolvedStreamSheet(
    _StreamedMatch match,
    List<_StreamedStreamChoice> choices,
  ) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StreamedStreamSheet(
        match: match,
        choices: choices,
        onChoiceSelected: (choice) {
          Navigator.pop(context);
          unawaited(_openResolvedStreamChoice(choice, allChoices: choices));
        },
      ),
    );
  }

  Future<List<_StreamedStreamChoice>> _resolveAllCatalogStreamChoices(
    List<_StreamedMatch> catalogMatches, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Finding streams…');
    final out = <_StreamedStreamChoice>[];
    final seenUrls = <String>{};
    final seenRefs = <String>{};
    final jobs = <Future<List<_StreamedStreamChoice>>>[];

    for (final m in catalogMatches) {
      for (final stream in m.inlineStreams) {
        final url = stream.embedUrl.trim();
        if (url.isEmpty || !seenUrls.add(url)) continue;
        out.add(_StreamedStreamChoice(catalogMatch: m, stream: stream));
      }

      for (final ref in m.sources) {
        final key = 'ref:${m.livePluginId}:${ref.source}:${ref.id}';
        if (!seenRefs.add(key)) continue;
        jobs.add(() async {
          try {
            final streams = m.isForjaLive
                ? await _forjaLiveStreamsFromSource(
                    m,
                    ref,
                    allowStreamedFallback: false,
                  )
                : await _fetchStreamedStreams(ref, allowFallback: false);
            return [
              for (final stream in streams)
                if (stream.embedUrl.trim().isNotEmpty)
                  _StreamedStreamChoice(catalogMatch: m, stream: stream),
            ];
          } catch (e) {
            debugPrint('[LiveMatches] resolve ${ref.source}/${ref.id}: $e');
            return const <_StreamedStreamChoice>[];
          }
        }());
      }
    }

    if (jobs.isNotEmpty) {
      onProgress?.call(
        jobs.length == 1
            ? 'Checking source…'
            : 'Checking ${jobs.length} sources…',
      );
    }
    final batches = await Future.wait(jobs);
    onProgress?.call('Building stream list…');
    for (final batch in batches) {
      for (final choice in batch) {
        final url = choice.stream.embedUrl.trim();
        if (url.isEmpty || !seenUrls.add(url)) continue;
        out.add(choice);
      }
    }

    out.sort(
      (a, b) => _effectiveStreamViewers(b.stream, b.catalogMatch).compareTo(
        _effectiveStreamViewers(a.stream, a.catalogMatch),
      ),
    );
    return out;
  }

  bool _isPpvMatch(_StreamedMatch match, [_StreamedStream? stream]) {
    if (stream != null && stream.source.trim().toLowerCase() == 'ppv') {
      return true;
    }
    if (LiveMatchesEngine.cachedIsNativeUnlock(match.livePluginId, 'ppv')) {
      return true;
    }
    if (stream != null && _ppvEmbedRequiresWebView(stream.embedUrl)) {
      return true;
    }
    return false;
  }

  String _ppvLivePluginId() =>
      LiveMatchesEngine.cachedPluginIdForNativeUnlock('ppv') ?? 'ppv';

  String _defaultLivePluginId() =>
      LiveMatchesEngine.cachedPluginIdForNativeUnlock('streamed') ??
      'streamed';

  bool _isPpvStreamChoice(_StreamedStreamChoice choice) {
    return _isPpvMatch(choice.catalogMatch, choice.stream);
  }

  Future<void> _openResolvedStreamChoice(
    _StreamedStreamChoice choice, {
    List<_StreamedStreamChoice>? allChoices,
  }) async {
    await _openStreamedEmbed(
      choice.catalogMatch,
      choice.stream,
      allChoices: allChoices,
    );
  }

  String _streamPickerLabel(_StreamedMatch match, _StreamedStream stream) {
    final sourceLabel = _StreamedStreamSheet.sourceLabel(stream.source);
    final title = _StreamedStreamSheet.streamTitle(stream, sourceLabel);
    if (title.isNotEmpty) return title;
    if (sourceLabel.isNotEmpty) return sourceLabel;
    if (match.isForjaLive) {
      return _liveForjaPluginDisplayName(match.livePluginId);
    }
    return 'Stream';
  }

  String _streamPlaySubtitle(_StreamedMatch match, _StreamedStream stream) {
    final source = _StreamedStreamSheet.sourceLabel(stream.source);
    if (source.isNotEmpty) return source;
    return match.categoryLabel;
  }

  IptvPlaySource _liveEnginePlaySource({
    required _StreamedMatch match,
    required _StreamedStream stream,
    required String url,
    Map<String, String> headers = const {},
  }) {
    return IptvPlaySource(
      url: url,
      label: _streamPickerLabel(match, stream),
      detail: stream.hd ? 'HD' : null,
      headers: headers,
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveProviderBadge: _StreamedStreamSheet.serverLabelFor(match),
      liveViewerCount: _effectiveStreamViewers(stream, match),
      liveStreamHd: stream.hd,
    );
  }

  Future<List<_StreamedStream>> _forjaLiveStreamsFromSource(
    _StreamedMatch match,
    _StreamedSourceRef source, {
    bool allowStreamedFallback = true,
  }) async {
    final pluginId = match.livePluginId.isNotEmpty
        ? match.livePluginId
        : _defaultLivePluginId();
    final label = _liveForjaPluginDisplayName(pluginId).toLowerCase();
    final unlock = await LiveMatchesEngine.pluginNativeUnlock(pluginId);

    if (unlock == 'streamed') {
      final rows = await _fetchStreamedStreams(
        source,
        allowFallback: allowStreamedFallback,
      );
      if (rows.isNotEmpty) return rows;
    }

    if (unlock == 'watchfooty') {
      final mid = source.id.trim().replaceFirst(RegExp(r'^wf_'), '');
      if (mid.isNotEmpty) {
        final unlocked = await LiveGoatUnlock.resolveWatchfootyMatch(
          matchId: mid,
        );
        if (unlocked.isNotEmpty) {
          return [
            for (var i = 0; i < unlocked.length; i++)
              _StreamedStream(
                id: source.id,
                streamNo: i + 1,
                language: '',
                hd: unlocked[i].name.toLowerCase().contains('hd') ||
                    unlocked[i].name.toLowerCase().contains('fhd'),
                embedUrl: unlocked[i].url,
                source: unlocked[i].name.toLowerCase(),
                viewers: 0,
              ),
          ];
        }
      }
      return [];
    }

    final rows = await EngineService.instance.runLivePlugin(
      pluginId: pluginId,
      action: 'resolve',
      params: {
        'matchId': source.id,
        'eventId': match.id,
        'source': source.source,
        'category': match.category,
        'title': match.title,
        'stream': '1',
        'embedUrl': source.iframe,
        'iframe': source.iframe,
      },
    );
    if (rows.isEmpty) {
      if (unlock == 'ppv' && source.iframe.trim().isNotEmpty) {
        return [
          _StreamedStream(
            id: source.id,
            streamNo: 1,
            language: '',
            hd: false,
            embedUrl: source.iframe,
            source: 'ppv',
            viewers: 0,
          ),
        ];
      }
      return [];
    }

    final out = <_StreamedStream>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row['webviewOnly'] == true) {
        final embed = (row['embedUrl'] ?? '').toString().trim();
        if (embed.isEmpty) continue;
        out.add(
          _StreamedStream(
            id: source.id,
            streamNo: i + 1,
            language: '',
            hd: false,
            embedUrl: embed,
            source: label,
            viewers: 0,
          ),
        );
        continue;
      }
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      final name = (row['name'] ?? row['title'] ?? label).toString().trim();
      out.add(
        _StreamedStream(
          id: source.id,
          streamNo: i + 1,
          language: '',
          hd: false,
          embedUrl: url,
          source: name.isEmpty ? label : name.toLowerCase(),
          viewers: 0,
        ),
      );
    }
    return out;
  }

  /// TV Forja Live: Sources panel with engine plugin streams (not Xtream).
  ///
  /// Lists catalog rows immediately (same as desktop sheet). Unlock/play happens
  /// on tap — do not hide rows when GOAT/node unlock fails on Android.
  ///
  /// Respects Catalog filter: **PPV** → PPV only; a named plugin → that
  /// plugin only; **All** → every catalog row for the event (+ matching PPV).
  Future<void> _openForjaLiveTvSources(
    _StreamedMatch match, {
    _DamiTvStream? ppvAnchor,
  }) async {
    if (!mounted) return;
    if ((this as _LiveMatchesForjaLive)._forjaLiveAnyLoading) {
      ForjaToast.info('Loading Forja Live plugins…');
      return;
    }

    final filter = _s._forjaLivePluginFilter;
    final phase = filter == 'all'
        ? 'Forja Live'
        : _liveForjaPluginDisplayName(filter);
    final choices = <_StreamedStreamChoice>[];

    final panel = _IptvSportsChannelsPanel.show(
      context: context,
      match: match,
      panelTitle: 'Sources',
      emptyMessage: 'No streams available',
      searchingHint: 'Loading $phase streams',
      cancelInFlightSearch: _iptvSportsPanelDismissCancel(),
      onChannelSelected: (picked, all) {
        final hit = _forjaLiveTvChoiceForSource(picked, choices);
        if (hit == null) {
          LiveMatchesEngine.engineResolveFailed();
          return;
        }
        unawaited(_openResolvedStreamChoice(hit, allChoices: choices));
      },
    );
    panel.setSearchPhase(phase);
    final searchGen = _s._iptvSportsSearchGen;

    try {
      if (ppvAnchor != null && ppvAnchor.iframe.trim().isNotEmpty) {
        choices.add(_ppvStreamChoice(ppvAnchor, match));
      } else if (filter == 'all' ||
          LiveMatchesEngine.cachedIsNativeUnlock(filter, 'ppv')) {
        _prependMatchingPpvChoices(match, choices);
      }

      // Catalog → PPV: never pull TimStreams/Streamed/etc. from the session cache.
      if (!LiveMatchesEngine.cachedIsNativeUnlock(filter, 'ppv')) {
        final catalogMatches =
            _streamedMatchesForEvent(match, _s._streamedMatches);
        final scoped = filter == 'all'
            ? catalogMatches
            : catalogMatches
                .where((m) => m.livePluginId == filter)
                .toList();
        if (scoped.isNotEmpty) {
          choices.addAll(await _resolveAllCatalogStreamChoices(scoped));
        }
      }
      if (panel.isDisposed || _iptvSportsSearchStale(searchGen)) return;

      // List every catalog choice (desktop parity). Do not pre-unlock —
      // Android has no Node GOAT worker, so unlock-before-list hid Streamed/PPV.
      for (final choice in choices) {
        if (panel.isDisposed || _iptvSportsSearchStale(searchGen)) return;
        final stream = choice.stream;
        final embed = stream.embedUrl.trim();
        final key = embed.isNotEmpty
            ? embed
            : 'pending:${choice.catalogMatch.id}:${stream.id}:${stream.streamNo}';
        final provider =
            _StreamedStreamSheet.serverLabelFor(choice.catalogMatch);
        panel.appendSources([
          IptvPlaySource(
            url: key,
            label: _streamPickerLabel(choice.catalogMatch, stream),
            detail: stream.hd ? 'HD' : null,
            liveSourceKind: IptvLiveSourceKind.liveEngine,
            liveProviderBadge: provider,
            liveViewerCount: _effectiveStreamViewers(stream, choice.catalogMatch),
            liveStreamHd: stream.hd,
          ),
        ]);
      }
      _rememberEventStreamViewers(match, _sheetTotalViewers(choices));
      if (ppvAnchor != null) {
        _rememberPpvStreamViewers(ppvAnchor, _sheetTotalViewers(choices));
      }
    } catch (e) {
      debugPrint('[LiveMatches] TV Forja Live resolve error: $e');
    } finally {
      if (!panel.isDisposed) panel.finishSearching();
    }
  }

  _StreamedStreamChoice? _forjaLiveTvChoiceForSource(
    IptvPlaySource picked,
    List<_StreamedStreamChoice> choices,
  ) {
    final url = picked.url.trim();
    for (final c in choices) {
      final embed = c.stream.embedUrl.trim();
      if (embed.isNotEmpty && embed == url) return c;
      final pending =
          'pending:${c.catalogMatch.id}:${c.stream.id}:${c.stream.streamNo}';
      if (url == pending) return c;
    }
    final label = picked.label.trim();
    if (label.isEmpty) return null;
    for (final c in choices) {
      if (_streamPickerLabel(c.catalogMatch, c.stream) == label) return c;
    }
    return null;
  }

  /// TV non–Forja Live (All / PPV / Streamed leftover): Forja Sports ∪ Stremio.
  Future<void> _openTvNativeSourcesOnly(_StreamedMatch match) async {
    if (!mounted) return;
    final ctrl = ref.read(iptvControllerProvider);
    final portal = ctrl.activePortal;
    if (portal != null && portal.portal.platform.supportsForjaSports) {
      await LiveMatchesIptvSportsConfig.ensureArmed(portalKey: portal.key);
    } else {
      await LiveMatchesIptvSportsConfig.ensureArmed();
    }
    if (!mounted) return;

    final espnPayload = _findEspnGameForMatch(match, _s._espnGames);
    final enriched = espnPayload == null
        ? match
        : _copyStreamedMatch(
            match,
            sportMatchGame: espnPayload,
            homeTeam:
                (espnPayload['homeTeam'] as String?)?.trim().isNotEmpty == true
                ? espnPayload['homeTeam'] as String
                : match.homeTeam,
            awayTeam:
                (espnPayload['awayTeam'] as String?)?.trim().isNotEmpty == true
                ? espnPayload['awayTeam'] as String
                : match.awayTeam,
          );

    final panel = _IptvSportsChannelsPanel.show(
      context: context,
      match: enriched,
      panelTitle: 'Sources',
      iptvCtrl: ctrl,
      cancelInFlightSearch: _iptvSportsPanelDismissCancel(),
      onChannelSelected: (picked, all) {
        unawaited(_playIptvSportsSources(enriched, all, picked));
      },
    );
    panel.setSearchPhase('Forja Sports');
    final searchGen = _s._iptvSportsSearchGen;

    Future<void> addForja() async {
      try {
        await _resolveIptvSportsStreams(
          enriched,
          onPartial: (batch) {
            if (panel.isDisposed) return;
            panel.appendSources([
              for (final s in batch)
                IptvPlaySource(
                  url: s.url,
                  label: s.label,
                  detail: _tvNativeSourceDetail('Forja Sports', s.detail),
                  logoUrl: s.logoUrl,
                  streamId: s.streamId,
                  epgChannelId: s.epgChannelId,
                  headers: s.headers,
                  liveSourceKind:
                      s.liveSourceKind ?? IptvLiveSourceKind.iptvXtream,
                ),
            ]);
          },
        );
      } catch (e) {
        debugPrint('[LiveMatches] TV Forja Sports resolve error: $e');
      }
    }

    Future<void> addStremio() async {
      if (!_offerStremioPlayFallback) return;
      if (_iptvSportsSearchStale(searchGen)) return;
      try {
        final stremio = await _resolveStremioStreamsMatching(enriched);
        if (panel.isDisposed || _iptvSportsSearchStale(searchGen)) return;
        panel.appendSources([
          for (final s in stremio)
            IptvPlaySource(
              url: s.url,
              label: s.label,
              detail: _tvNativeSourceDetail('Stremio', s.detail),
              logoUrl: s.logoUrl,
              streamId: s.streamId,
              headers: s.headers,
              liveSourceKind: IptvLiveSourceKind.stremio,
            ),
        ]);
      } catch (e) {
        debugPrint('[LiveMatches] TV Stremio resolve error: $e');
      }
    }

    // Serial on TV: parallel Forja Sports (Xtream + EPG) + Stremio OOMs leanback.
    await addForja();
    if (panel.isDisposed || _iptvSportsSearchStale(searchGen)) return;
    panel.setSearchPhase('Stremio');
    await addStremio();
    if (!panel.isDisposed && !_iptvSportsSearchStale(searchGen)) {
      panel.finishSearching();
    }
  }

  String _tvNativeSourceDetail(String server, String? detail) {
    final d = (detail ?? '').trim();
    return d.isEmpty ? server : '$server · $d';
  }

  Future<List<IptvPlaySource>> _resolveStremioStreamsMatching(
    _StreamedMatch match,
  ) async {
    if (match.isStremio) {
      return _stremioPlaySourcesFor(match);
    }
    final catalog = await _fetchStremioSportMatches();
    final hits = catalog.where((m) => _sameStreamedEvent(match, m)).toList();
    if (hits.isEmpty) return const [];
    final out = <IptvPlaySource>[];
    final seenUrls = <String>{};
    for (final hit in hits.take(3)) {
      for (final s in await _stremioPlaySourcesFor(hit)) {
        if (!seenUrls.add(s.url)) continue;
        out.add(s);
      }
    }
    return out;
  }

  Future<List<IptvPlaySource>> _stremioPlaySourcesFor(
    _StreamedMatch match,
  ) async {
    final out = <IptvPlaySource>[];
    try {
      final raw = await StremioService().getStreams(
        baseUrl: match.stremioBaseUrl,
        type: match.stremioType,
        id: match.id,
      );
      for (final s in raw) {
        if (s is! Map) continue;
        final url = s['url']?.toString();
        if (!StremioService.isPlayableLiveUrl(url)) continue;
        final name = (s['name'] ?? s['title'] ?? 'Stream').toString().trim();
        out.add(
          IptvPlaySource(
            url: url!,
            label: name.isEmpty ? 'Stream' : name,
            headers: StremioService.liveStreamRequestHeaders(s),
            liveSourceKind: IptvLiveSourceKind.stremio,
          ),
        );
      }
    } catch (e) {
      debugPrint('[LiveMatches] Stremio stream error: $e');
    }
    return out;
  }

  Future<void> _openStremioSportMatch(_StreamedMatch match) async {
    if (!mounted) return;
    final sources = <IptvPlaySource>[];
    final ok = await _runWithCancellableLoading('Loading streams…', (
      setMessage,
    ) async {
      setMessage('Fetching Stremio sources…');
      sources.addAll(await _stremioPlaySourcesFor(match));
    });
    if (!ok) return;
    if (sources.isEmpty) {
      ForjaToast.info('No playable streams for this event');
      return;
    }
    if (!mounted) return;
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: sources,
        title: match.title,
        subtitle: match.categoryLabel,
        titleTracksSource: true,
        engineContext: BuiltInPlayerContext.live,
        liveSourceKind: IptvLiveSourceKind.stremio,
      ),
    );
  }

  Future<void> _openIptvSportsMatch(_StreamedMatch match) async {
    if (!mounted) return;
    final iptvCtrl = ref.read(iptvControllerProvider);
    final espnPayload = _findEspnGameForMatch(match, _s._espnGames);
    final enriched = espnPayload == null
        ? match
        : _copyStreamedMatch(
            match,
            sportMatchGame: espnPayload,
            homeTeam:
                (espnPayload['homeTeam'] as String?)?.trim().isNotEmpty == true
                ? espnPayload['homeTeam'] as String
                : match.homeTeam,
            awayTeam:
                (espnPayload['awayTeam'] as String?)?.trim().isNotEmpty == true
                ? espnPayload['awayTeam'] as String
                : match.awayTeam,
          );

    final panel = _IptvSportsChannelsPanel.show(
      context: context,
      match: enriched,
      iptvCtrl: iptvCtrl,
      cancelInFlightSearch: _iptvSportsPanelDismissCancel(),
      onChannelSelected: (picked, all) {
        unawaited(_playIptvSportsSources(enriched, all, picked));
      },
    );
    panel.setSearchPhase('Forja Sports');
    final searchGen = _s._iptvSportsSearchGen;

    try {
      await _resolveIptvSportsStreams(
        enriched,
        onPartial: (batch) {
          if (panel.isDisposed) return;
          panel.appendSources(batch);
        },
      );
    } catch (e) {
      debugPrint('[LiveMatches] IPTV sports resolve error: $e');
    } finally {
      if (!panel.isDisposed && !_iptvSportsSearchStale(searchGen)) {
        panel.finishSearching();
      }
    }
  }

  Future<void> _playIptvSportsSources(
    _StreamedMatch match,
    List<IptvPlaySource> sources,
    IptvPlaySource picked,
  ) async {
    if (!mounted) return;
    final gen = ++_s._iptvSportsPlayGen;
    final ordered = <IptvPlaySource>[
      picked,
      for (final s in sources)
        if (!identical(s, picked) &&
            (s.streamId ?? '').trim() != (picked.streamId ?? '').trim() &&
            (s.url.isEmpty || s.url != picked.url))
          s,
    ];
    var resolved = <IptvPlaySource>[];
    final ok = await _runWithCancellableLoading('Opening channel…', (
      setMessage,
    ) async {
      setMessage('Creating stream link…');
      resolved = await _resolveIptvSportsPlayUrls(ordered);
    });
    if (!ok || !mounted || gen != _s._iptvSportsPlayGen) return;
    if (resolved.isEmpty) {
      ForjaToast.info('Could not open channel');
      return;
    }
    final kind = resolved.first.liveSourceKind ?? IptvLiveSourceKind.iptvXtream;
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: resolved,
        title: _iptvSportsMatchChromeTitle(match),
        subtitle: resolved.first.pickerTitle,
        logoUrl: resolved.first.logoUrl,
        titleTracksSource: true,
        engineContext: BuiltInPlayerContext.iptv,
        liveSourceKind: kind,
      ),
    );
  }

  /// Stalker: create_link only the picked channel before open. Sibling channels
  /// keep [streamId] so the player can mint failover / reconnect links.
  Future<List<IptvPlaySource>> _resolveIptvSportsPlayUrls(
    List<IptvPlaySource> sources,
  ) async {
    if (sources.isEmpty) return sources;
    final needsLink = sources.any(
      (s) =>
          s.liveSourceKind == IptvLiveSourceKind.iptvStalker ||
          (s.url.trim().isEmpty && (s.streamId ?? '').trim().isNotEmpty),
    );
    if (!needsLink) return sources;

    final config = await LiveMatchesIptvSportsConfig.load();
    final armed = await config.resolveForFetch();
    if (armed == null) return [];
    final portals = await IptvStore.load();
    VerifiedPortal? portal;
    for (final p in portals) {
      if (p.key == armed.portalKey) {
        portal = p;
        break;
      }
    }
    if (portal == null ||
        portal.portal.platform != IptvPortalPlatform.stalker) {
      return sources.where((s) => s.url.trim().isNotEmpty).toList();
    }

    final out = <IptvPlaySource>[];
    var minted = false;
    for (final s in sources) {
      final cmd = (s.streamId ?? '').trim();
      final stalkerRow = s.liveSourceKind == IptvLiveSourceKind.iptvStalker ||
          (s.url.trim().isEmpty && cmd.isNotEmpty);
      if (!stalkerRow) {
        if (s.url.trim().isNotEmpty) out.add(s);
        continue;
      }
      if (cmd.isEmpty) {
        if (s.url.trim().isNotEmpty) out.add(s);
        continue;
      }
      if (!minted) {
        final url = await IptvClient.createLink(
          portal.portal,
          cmd: cmd,
          section: 'live',
        );
        if (url == null || url.isEmpty) {
          debugPrint('[LiveMatches] Stalker create_link failed for $cmd');
          continue;
        }
        minted = true;
        out.add(IptvPlaySource(
          url: url,
          label: s.label,
          detail: s.detail,
          logoUrl: s.logoUrl,
          streamId: s.streamId,
          epgChannelId: s.epgChannelId,
          headers: s.headers,
          liveSourceKind: IptvLiveSourceKind.iptvStalker,
        ));
      } else {
        out.add(IptvPlaySource(
          url: '',
          label: s.label,
          detail: s.detail,
          logoUrl: s.logoUrl,
          streamId: s.streamId,
          epgChannelId: s.epgChannelId,
          headers: s.headers,
          liveSourceKind: IptvLiveSourceKind.iptvStalker,
        ));
      }
    }
    return out;
  }

  /// Match first, kickoff time when known — channel sits in the subtitle.
  String _iptvSportsMatchChromeTitle(_StreamedMatch match) {
    final name = match.title.trim();
    final kickoff = _iptvSportsKickoffLabel(match.dateMs);
    if (name.isEmpty) return kickoff.isEmpty ? 'Live' : kickoff;
    if (kickoff.isEmpty) return name;
    return '$name · $kickoff';
  }

  String _iptvSportsKickoffLabel(int dateMs) {
    if (dateMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm';
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return time;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day} $time';
  }

  Future<void> _openIptvSportsFromPpv(_DamiTvStream s) async {
    await _openIptvSportsMatch(_streamedMatchFromPpv(s));
  }

  _StreamedMatch _streamedMatchFromPpv(_DamiTvStream s) => _StreamedMatch(
    id: 'ppv:${s.id}',
    title: s.name,
    category: s.categoryName,
    dateMs: s.startsAt > 0 ? s.startsAt * 1000 : 0,
    poster: s.poster,
    popular: false,
    airing: s.isLive,
    viewers: s.viewers,
    homeTeam: s.homeTeam,
    awayTeam: s.awayTeam,
    homeBadge: s.homeBadge,
    awayBadge: s.awayBadge,
    sources: const [],
  );

  Future<IptvPlaySource?> _resolveStreamToEnginePlaySource(
    _StreamedMatch match,
    _StreamedStream stream, {
    void Function(String)? onProgress,
  }) async {
    final embed = stream.embedUrl.trim();
    if (embed.isEmpty) return null;

    final isPpv = _isPpvMatch(match, stream);
    final catalogReferer = isPpv
        ? await LiveMatchesEngine.ppvWebReferer()
        : match.isForjaLive
        ? (_forjaLiveCdnReferer(embed) ??
              await LiveMatchesEngine.pluginReferer(
                match.livePluginId,
                embedUrl: embed,
              ))
        : _streamedReferer;
    if (RegExp(r'\.m3u8|\.mp4', caseSensitive: false).hasMatch(embed)) {
      final headers = isPpv
          ? _ppvEmbedStreamHeaders(embed)
          : _liveEmbedStreamHeaders(
              embed,
              catalogReferer: match.isForjaLive ? _forjaLiveCdnReferer(embed) : null,
            );
      final direct = liveEnginePreferDirectPlayback(embed);
      if (!direct) onProgress?.call('Preparing playback…');
      final playUrl = direct
          ? embed
          : await LiveMatchesEngine.proxyPlayUrl(url: embed, headers: headers);
      if (playUrl == null || playUrl.isEmpty) return null;
      return _liveEnginePlaySource(
        match: match,
        stream: stream,
        url: playUrl,
        headers: direct ? headers : const {},
      );
    }

    onProgress?.call('Unlocking source…');
    final pluginId = isPpv
        ? (match.livePluginId.isNotEmpty
              ? match.livePluginId
              : _ppvLivePluginId())
        : match.isForjaLive && match.livePluginId.isNotEmpty
        ? match.livePluginId
        : _defaultLivePluginId();
    final result = await LiveMatchesEngine.resolve(
      pluginId: pluginId,
      params: {
        'embedUrl': embed,
        'iframe': embed,
        'url': embed,
        'source': stream.source,
        'matchId': stream.id,
        'stream': stream.streamNo.toString(),
        'category': match.category,
        'title': match.title,
      },
    );
    if (result == null || !result.playable) return null;

    final headers = result.headers.isNotEmpty
        ? result.headers
        : isPpv
        ? _ppvEmbedStreamHeaders(embed.isNotEmpty ? embed : result.url)
        : _liveEmbedStreamHeaders(
            result.url,
            catalogReferer: catalogReferer,
          );
    final direct =
        result.directPlayback || liveEnginePreferDirectPlayback(result.url);
    if (!direct) onProgress?.call('Preparing playback…');
    final playUrl = direct
        ? result.url
        : await LiveMatchesEngine.proxyPlayUrl(url: result.url, headers: headers);
    if (playUrl == null || playUrl.isEmpty) return null;

    return _liveEnginePlaySource(
      match: match,
      stream: stream,
      url: playUrl,
      headers: direct ? headers : const {},
    );
  }

  Future<void> _openEngineNativeSources({
    required String title,
    required String subtitle,
    required List<IptvPlaySource> sources,
  }) async {
    if (sources.isEmpty) {
      LiveMatchesEngine.engineResolveFailed();
      return;
    }
    if (!mounted) return;
    _releaseLiveMatchesItemFocusIfHeld();

    var playSources = sources;
    var webViewProxy = false;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      playSources = await _androidWebViewProxyEngineSources(sources);
      webViewProxy = playSources.isNotEmpty &&
          playSources.first.url != sources.first.url;
    }

    try {
      if (webViewProxy && PlatformInfo.isAndroidTv) {
        await PlatformChannel.releaseUnderlayPlatformViewFocus();
      }
      if (!mounted) return;
      await IptvPtPlayerScreen.open(
        context,
        IptvPtPlayerScreen(
          sources: playSources,
          title: title,
          subtitle: subtitle,
          titleTracksSource: true,
          engineContext: BuiltInPlayerContext.live,
          liveSourceKind: IptvLiveSourceKind.liveEngine,
        ),
      );
    } finally {
      if (webViewProxy) {
        await LiveGoatWebviewUnlock.instance.stopStreamedPlaybackProxy();
      }
    }
  }

  /// Streamed engine resolve on Android: Exo cannot re-GET `strmd.st`.
  Future<List<IptvPlaySource>> _androidWebViewProxyEngineSources(
    List<IptvPlaySource> sources,
  ) async {
    if (sources.isEmpty) return sources;
    final first = sources.first;
    final playUrl = first.url.trim();
    if (playUrl.isEmpty || playUrl.contains('127.0.0.1')) {
      return sources;
    }

    var catalog = playUrl;
    final uri = Uri.tryParse(playUrl);
    if (uri != null && uri.path.contains('/hls-proxy')) {
      catalog = (uri.queryParameters['url'] ?? '').trim();
    }
    if (catalog.isEmpty || !catalog.toLowerCase().contains('strmd.st')) {
      return sources;
    }

    final local = await LiveGoatWebviewUnlock.instance.prepareStreamedPlaybackUrl(
      catalog,
    );
    if (local == null || local.isEmpty) return sources;

    final out = List<IptvPlaySource>.from(sources);
    out[0] = IptvPlaySource(
      url: local,
      label: first.label,
      detail: first.detail,
      logoUrl: first.logoUrl,
      streamId: first.streamId,
      epgChannelId: first.epgChannelId,
      headers: const {},
      liveSourceKind: first.liveSourceKind,
      liveProviderBadge: first.liveProviderBadge,
      liveViewerCount: first.liveViewerCount,
      liveStreamHd: first.liveStreamHd,
    );
    return out;
  }

  Future<bool> _tryEngineStreamedOpen(
    _StreamedMatch match,
    _StreamedStream stream, {
    List<_StreamedStreamChoice>? allChoices,
  }) async {
    if (!await LiveMatchesEngine.isEngineResolveMode()) return false;

    final candidates = <_StreamedStreamChoice>[];
    if (allChoices != null) {
      for (final choice in allChoices) {
        if (choice.stream.embedUrl.trim().isEmpty) continue;
        candidates.add(choice);
      }
    }
    if (candidates.isEmpty) {
      candidates.add(
        _StreamedStreamChoice(catalogMatch: match, stream: stream),
      );
    }

    final pickedEmbed = stream.embedUrl.trim();
    final sources = <IptvPlaySource>[];
    final ok = await _runWithCancellableLoading('Opening stream…', (
      setMessage,
    ) async {
      setMessage('Unlocking source…');
      final picked = await _resolveStreamToEnginePlaySource(
        match,
        stream,
        onProgress: setMessage,
      );
      if (picked == null) return;
      sources.add(picked);
      final seenUrls = {picked.url};

      final others = candidates.where((c) {
        return c.stream.embedUrl.trim() != pickedEmbed;
      }).toList();
      if (others.isEmpty) return;

      setMessage(
        others.length == 1
            ? 'Loading other server…'
            : 'Loading other servers…',
      );
      final resolved = await Future.wait(
        others.map(
          (c) => _resolveStreamToEnginePlaySource(c.catalogMatch, c.stream),
        ),
      );
      for (final src in resolved) {
        if (src == null || seenUrls.contains(src.url)) continue;
        seenUrls.add(src.url);
        sources.add(src);
      }
    });
    if (!ok) return true;
    if (sources.isEmpty) {
      debugPrint(
        '[LiveMatches] Engine resolve missed — no embed fallback '
        '(${stream.source}/${stream.id})',
      );
      LiveMatchesEngine.engineResolveFailed();
      return true;
    }

    await _openEngineNativeSources(
      title: match.title,
      subtitle: _streamPlaySubtitle(match, stream),
      sources: sources,
    );
    return true;
  }

  Future<void> _openStreamedEmbed(
    _StreamedMatch match,
    _StreamedStream stream, {
    List<_StreamedStreamChoice>? allChoices,
  }) async {
    if (await _tryEngineStreamedOpen(
      match,
      stream,
      allChoices: allChoices,
    )) {
      return;
    }

    final isPpv = _isPpvMatch(match, stream);
    if (isPpv) {
      LiveMatchesEngine.engineResolveFailed();
      return;
    }

    final catalogBase = match.isMut
        ? _mutBase
        : (match.isForjaLive
              ? (Uri.tryParse(stream.embedUrl)?.origin ?? _streamedBase)
              : _streamedBase);
    final catalogReferer = match.isMut
        ? _mutReferer
        : (match.isForjaLive
              ? await LiveMatchesEngine.pluginReferer(
                  match.livePluginId,
                  embedUrl: stream.embedUrl,
                )
              : _streamedReferer);
    final proxyReferer = match.isForjaLive
        ? _forjaLiveCdnReferer(stream.embedUrl)
        : null;
    final embedUrl = await liveEmbedResolveNestedPlayerUrl(
      stream.embedUrl,
      catalogReferer: catalogReferer,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: embedUrl,
          title: match.title,
          subtitle: match.categoryLabel,
          badgeLabel: match.isForjaLive
              ? 'Forja Live'
              : (match.isMut ? 'Mut' : 'Streamed'),
          referer: catalogReferer,
          origin: catalogBase,
          proxyReferer: proxyReferer,
        ),
      ),
    );
  }

  Future<void> _openDamiTvStream(_DamiTvStream s) async {
    if (_s._server == _LiveMatchesServer.iptvSports) {
      await _openIptvSportsFromPpv(s);
      return;
    }
    if (_tvNativeLiveOnly) {
      if (_s._server == _LiveMatchesServer.forjaLive) {
        await _openForjaLiveTvSources(
          _streamedMatchFromPpv(s),
          ppvAnchor: s,
        );
        return;
      }
      await _openTvNativeSourcesOnly(_streamedMatchFromPpv(s));
      return;
    }
    if (s.iframe.isEmpty) {
      _showResolvedStreamSheet(_streamedMatchFromPpv(s), const []);
      return;
    }
    if (!mounted) return;
    final anchor = _streamedMatchFromPpv(s);
    final choice = _ppvStreamChoice(s, anchor);
    await _openStreamedEmbed(choice.catalogMatch, choice.stream);
  }
}
