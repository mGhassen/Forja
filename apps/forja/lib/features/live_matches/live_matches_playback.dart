part of 'live_matches_screen.dart';

enum _LiveMatchPlayPath { engineChoices, iptvSports, stremioDirect }

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
    await _openLiveMatchDetails(
      host: _s,
      match: streamed,
      ppvAnchor: ppv,
    );
  }

  Future<void> _fillMatchDetailsProviders({
    required _StreamedMatch match,
    _DamiTvStream? ppvAnchor,
    required _IptvSportsChannelsPanelController controller,
    required List<_StreamedStreamChoice> choices,
    required bool Function() isStale,
  }) async {
    controller.setSearchPhase('Forja Live');

    // Providers = every enabled stream catalog + Stremio. Catalog-grid merge
    // (PPV+Streamed card) is display-only and must not scope this list.
    await _fillForjaLiveSources(
      match: match,
      controller: controller,
      choices: choices,
      isStale: isStale,
      ppvAnchor: ppvAnchor,
    );
    if (choices.isEmpty && !isStale() && !controller.isDisposed) {
      await _fillCatalogEngineSources(
        match: match,
        controller: controller,
        choices: choices,
        isStale: isStale,
        allowIptvFallback: false,
      );
    }

    if (isStale() || controller.isDisposed) return;

    controller.setSearchPhase('Stremio');
    if (match.isStremio) {
      await _fillStremioSources(
        match: match,
        controller: controller,
        isStale: isStale,
      );
    } else {
      try {
        final stremio = await _resolveStremioStreamsMatching(match);
        if (!isStale() && !controller.isDisposed && stremio.isNotEmpty) {
          controller.appendSources(stremio);
        }
      } catch (e) {
        debugPrint('[LiveMatches] Stremio match error: $e');
      }
    }
  }

  _StreamedMatch _enrichedIptvSportsMatch(_StreamedMatch match) {
    final mergedGame = _sportMatchGameForIptvResolve(match, _s._espnGames);
    final espnPayload = _findEspnGameForMatch(match, _s._espnGames);
    return _copyStreamedMatch(
      match,
      sportMatchGame: mergedGame,
      homeTeam: () {
        final fromEspn = (espnPayload?['homeTeam'] ?? mergedGame['homeTeam'])
            .toString()
            .trim();
        return fromEspn.isNotEmpty ? fromEspn : match.homeTeam;
      }(),
      awayTeam: () {
        final fromEspn = (espnPayload?['awayTeam'] ?? mergedGame['awayTeam'])
            .toString()
            .trim();
        return fromEspn.isNotEmpty ? fromEspn : match.awayTeam;
      }(),
    );
  }

  Future<_StreamedMatch> _fillIptvSportsSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required bool Function() isStale,
    bool loadBroadcastHints = true,
  }) async {
    final enriched = _enrichedIptvSportsMatch(match);
    controller.setSearchPhase('Live TV');
    if (loadBroadcastHints) {
      controller.beginBroadcastHintsLoad();
    }
    try {
      await _resolveIptvSportsStreams(
        enriched,
        onPartial: (batch) {
          if (isStale() || controller.isDisposed) return;
          controller.appendSources(batch);
        },
      );
    } catch (e) {
      debugPrint('[LiveMatches] IPTV sports resolve error: $e');
    }
    if (loadBroadcastHints && !isStale() && !controller.isDisposed) {
      try {
        final hints = await _broadcastHintsForMatch(enriched);
        if (!isStale() && !controller.isDisposed) {
          controller.setBroadcastHints(hints);
        }
      } catch (e) {
        debugPrint('[LiveMatches] broadcast hints error: $e');
        if (!isStale() && !controller.isDisposed) {
          controller.setBroadcastHints(const _LiveBroadcastHints());
        }
      }
    }
    return enriched;
  }

  Future<void> _fillStremioSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required bool Function() isStale,
  }) async {
    controller.setSearchPhase('Stremio');
    try {
      final sources = await _stremioPlaySourcesFor(match);
      if (isStale() || controller.isDisposed) return;
      controller.appendSources(sources);
    } catch (e) {
      debugPrint('[LiveMatches] Stremio stream error: $e');
    }
  }

  Future<void> _fillForjaLiveSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required List<_StreamedStreamChoice> choices,
    required bool Function() isStale,
    _DamiTvStream? ppvAnchor,
  }) async {
    controller.setSearchPhase('Forja Live');

    if (ppvAnchor != null && ppvAnchor.iframe.trim().isNotEmpty) {
      choices.add(_ppvStreamChoice(ppvAnchor, match));
    } else {
      _prependMatchingPpvChoices(match, choices);
    }
    _panelAppendChoices(controller, choices);

    // Resolve live-* plugins from the opened row + pool first — no catalog re-fetch.
    var catalogMatches = await (this as _LiveMatchesForjaLive)
        ._catalogMatchesForStreamResolve(
      match,
      fetchMissingCatalogs: false,
    );
    if (isStale() || controller.isDisposed) return;

    if (catalogMatches.isNotEmpty) {
      await _resolveCatalogStreamChoices(
        catalogMatches,
        isStale: isStale,
        onPartial: (batch) {
          if (isStale() || controller.isDisposed) return;
          choices.addAll(batch);
          _panelAppendChoices(controller, batch);
        },
      );
    }
    if (isStale() || controller.isDisposed) return;

    final hasNonPpvStreams = choices.any((c) => !_isPpvStreamChoice(c));
    if (!hasNonPpvStreams) {
      final seenIds = {for (final m in catalogMatches) m.id};
      final hydrated = await (this as _LiveMatchesForjaLive)
          ._catalogMatchesForStreamResolve(match);
      if (isStale() || controller.isDisposed) return;
      final extra = [
        for (final m in hydrated)
          if (!seenIds.contains(m.id)) m,
      ];
      if (extra.isNotEmpty) {
        await _resolveCatalogStreamChoices(
          extra,
          isStale: isStale,
          onPartial: (batch) {
            if (isStale() || controller.isDisposed) return;
            choices.addAll(batch);
            _panelAppendChoices(controller, batch);
          },
        );
      }
    }
    if (isStale() || controller.isDisposed) return;

    _rememberEventStreamViewers(match, _sheetTotalViewers(choices));
    if (ppvAnchor != null) {
      _rememberPpvStreamViewers(ppvAnchor, _sheetTotalViewers(choices));
    }
  }

  Future<_StreamedMatch> _fillNativeSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required bool Function() isStale,
  }) async {
    final ctrl = ref.read(iptvControllerProvider);
    final portal = ctrl.activePortal;
    if (portal != null && portal.portal.platform.supportsForjaSports) {
      await LiveMatchesIptvSportsConfig.ensureArmed(portalKey: portal.key);
    } else {
      await LiveMatchesIptvSportsConfig.ensureArmed();
    }
    if (!mounted) return match;

    final enriched = _enrichedIptvSportsMatch(match);

    Future<void> addForja() async {
      try {
        await _resolveIptvSportsStreams(
          enriched,
          onPartial: (batch) {
            if (controller.isDisposed || isStale()) return;
            controller.appendSources([
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
      if (!_offerStremioPlayFallback || isStale()) return;
      try {
        final stremio = await _resolveStremioStreamsMatching(enriched);
        if (controller.isDisposed || isStale()) return;
        controller.appendSources([
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

    controller.setSearchPhase('Forja Sports');
    await addForja();
    if (!controller.isDisposed && !isStale()) {
      controller.beginBroadcastHintsLoad();
      try {
        final hints = await _broadcastHintsForMatch(enriched);
        if (!controller.isDisposed && !isStale()) {
          controller.setBroadcastHints(hints);
        }
      } catch (e) {
        debugPrint('[LiveMatches] broadcast hints error: $e');
        if (!controller.isDisposed && !isStale()) {
          controller.setBroadcastHints(const _LiveBroadcastHints());
        }
      }
    }
    if (controller.isDisposed || isStale()) return enriched;
    controller.setSearchPhase('Stremio');
    await addStremio();
    return enriched;
  }

  Future<({_StreamedMatch match, _LiveMatchPlayPath? playPath})>
      _fillCatalogEngineSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required List<_StreamedStreamChoice> choices,
    required bool Function() isStale,
    bool allowIptvFallback = true,
  }) async {
    controller.setSearchPhase('streams');
    final catalogMatches = await (this as _LiveMatchesForjaLive)
        ._catalogMatchesForStreamResolve(match);

    _prependMatchingPpvChoices(match, choices);
    _panelAppendChoices(controller, choices);

    if (catalogMatches.isNotEmpty) {
      await _resolveCatalogStreamChoices(
        catalogMatches,
        isStale: isStale,
        onPartial: (batch) {
          if (isStale() || controller.isDisposed) return;
          choices.addAll(batch);
          _panelAppendChoices(controller, batch);
        },
      );
    }

    if (isStale() || controller.isDisposed) {
      return (match: match, playPath: null);
    }

    if (allowIptvFallback &&
        choices.isEmpty &&
        catalogMatches.any((m) => m.sportMatchGame != null)) {
      final enriched = await _fillIptvSportsSources(
        match: match,
        controller: controller,
        isStale: isStale,
      );
      return (match: enriched, playPath: _LiveMatchPlayPath.iptvSports);
    }

    _rememberEventStreamViewers(match, _sheetTotalViewers(choices));
    return (match: match, playPath: null);
  }

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    await _openLiveMatchDetails(host: _s, match: match);
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

  IptvPlaySource _choiceToPanelSource(_StreamedStreamChoice choice) {
    final stream = choice.stream;
    final embed = stream.embedUrl.trim();
    final key = embed.isNotEmpty
        ? embed
        : 'pending:${choice.catalogMatch.id}:${stream.id}:${stream.streamNo}';
    return IptvPlaySource(
      url: key,
      label: _streamPanelLabel(choice.catalogMatch, stream),
      detail: _streamPanelDetail(stream),
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveProviderBadge: _StreamedStreamSheet.serverLabelFor(
        choice.catalogMatch,
      ),
      liveViewerCount: _effectiveStreamViewers(stream, choice.catalogMatch),
      liveStreamHd: stream.hd,
      liveEngineEmbedUrl: embed.isNotEmpty ? embed : null,
    );
  }

  String _streamPanelLabel(_StreamedMatch match, _StreamedStream stream) {
    final lang = stream.language.trim();
    if (lang.isNotEmpty) return lang;
    return _streamPickerLabel(match, stream);
  }

  String? _streamPanelDetail(_StreamedStream stream) {
    final parts = <String>[];
    final quality = _streamQualityLabel(stream);
    if (quality != null) parts.add(quality);
    final host = Uri.tryParse(stream.embedUrl.trim())?.host;
    if (host != null && host.isNotEmpty) parts.add(host);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _streamQualityLabel(_StreamedStream stream) {
    final match = RegExp(
      r'\b(FHD|UHD|HD|4K|SD)\b',
      caseSensitive: false,
    ).firstMatch(stream.language);
    if (match != null) return match.group(1)!.toUpperCase();
    if (stream.hd) return 'HD';
    return null;
  }

  void _panelAppendChoices(
    _IptvSportsChannelsPanelController panel,
    Iterable<_StreamedStreamChoice> batch,
  ) {
    panel.appendSources([
      for (final choice in batch) _choiceToPanelSource(choice),
    ]);
  }

  Future<List<_StreamedStreamChoice>> _resolveCatalogStreamChoices(
    List<_StreamedMatch> catalogMatches, {
    void Function(String)? onProgress,
    void Function(List<_StreamedStreamChoice> batch)? onPartial,
    bool Function()? isStale,
  }) async {
    final out = <_StreamedStreamChoice>[];
    final seenUrls = <String>{};
    final seenRefs = <String>{};
    final jobs = <Future<List<_StreamedStreamChoice>>>[];
    final inlineBatch = <_StreamedStreamChoice>[];

    for (final m in catalogMatches) {
      for (final stream in m.inlineStreams) {
        final url = stream.embedUrl.trim();
        if (url.isEmpty || !seenUrls.add(url)) continue;
        final choice = _StreamedStreamChoice(catalogMatch: m, stream: stream);
        out.add(choice);
        inlineBatch.add(choice);
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

    if (inlineBatch.isNotEmpty && isStale?.call() != true) {
      onPartial?.call(inlineBatch);
    }

    if (jobs.isEmpty) return _sortStreamChoices(out);

    onProgress?.call(
      jobs.length == 1
          ? 'Checking source…'
          : 'Checking ${jobs.length} sources…',
    );

    var completed = 0;
    await Future.wait(
      jobs.map(
        (job) => job.then((batch) {
          if (isStale?.call() == true) return;
          completed++;
          final fresh = <_StreamedStreamChoice>[];
          for (final choice in batch) {
            final url = choice.stream.embedUrl.trim();
            if (url.isEmpty || !seenUrls.add(url)) continue;
            out.add(choice);
            fresh.add(choice);
          }
          if (fresh.isNotEmpty) onPartial?.call(fresh);
          if (completed == jobs.length) {
            onProgress?.call('Building stream list…');
          }
        }),
      ),
    );

    return _sortStreamChoices(out);
  }

  List<_StreamedStreamChoice> _sortStreamChoices(
    List<_StreamedStreamChoice> choices,
  ) {
    choices.sort(
      (a, b) => _effectiveStreamViewers(b.stream, b.catalogMatch).compareTo(
        _effectiveStreamViewers(a.stream, a.catalogMatch),
      ),
    );
    return choices;
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
    bool resolved = false,
  }) {
    final embed = stream.embedUrl.trim();
    return IptvPlaySource(
      url: url,
      label: _streamPanelLabel(match, stream),
      detail: _streamPanelDetail(stream),
      headers: headers,
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveProviderBadge: _StreamedStreamSheet.serverLabelFor(match),
      liveViewerCount: _effectiveStreamViewers(stream, match),
      liveStreamHd: stream.hd,
      liveEngineEmbedUrl: embed.isEmpty ? null : embed,
      liveEngineResolveParams: resolved
          ? null
          : _liveEngineResolveParams(match, stream),
    );
  }

  Map<String, dynamic> _liveEngineResolveParams(
    _StreamedMatch match,
    _StreamedStream stream,
  ) {
    return {
      'eventId': match.id,
      'matchId': stream.id,
      'streamNo': stream.streamNo,
      'category': match.category,
      'title': match.title,
      'source': stream.source,
      'livePluginId': match.livePluginId,
      'isForjaLive': match.isForjaLive,
      'isMut': match.isMut,
      'isPpv': _isPpvMatch(match, stream),
      'hd': stream.hd,
      'viewers': stream.viewers,
      'language': stream.language,
    };
  }

  _StreamedMatch _streamedMatchFromLiveEngineParams(Map<String, dynamic> params) {
    final isForjaLive = params['isForjaLive'] == true;
    final isMut = params['isMut'] == true;
    return _StreamedMatch(
      id: (params['eventId'] ?? '').toString(),
      title: (params['title'] ?? '').toString(),
      category: (params['category'] ?? '').toString(),
      dateMs: 0,
      poster: '',
      popular: false,
      airing: true,
      viewers: parsePpvViewers(params['viewers']),
      sources: const [],
      catalog: isForjaLive
          ? 'forja_live'
          : (isMut ? 'mut' : ''),
      livePluginId: (params['livePluginId'] ?? '').toString(),
    );
  }

  _StreamedStream _streamedStreamFromLiveEngineParams(
    Map<String, dynamic> params, {
    required String embedUrl,
  }) {
    return _StreamedStream(
      id: (params['matchId'] ?? '').toString(),
      streamNo: (params['streamNo'] as num?)?.toInt() ?? 1,
      language: (params['language'] ?? '').toString(),
      hd: params['hd'] == true,
      embedUrl: embedUrl,
      source: (params['source'] ?? '').toString(),
      viewers: parsePpvViewers(params['viewers']),
    );
  }

  Future<IptvPlaySource?> _resolveIptvPlaySourceFromCatalog(
    IptvPlaySource catalog, {
    void Function(String)? onProgress,
  }) async {
    final params = catalog.liveEngineResolveParams;
    if (params == null) return null;
    final embed = (catalog.liveEngineEmbedUrl ?? catalog.url).trim();
    if (embed.isEmpty) return null;
    final match = _streamedMatchFromLiveEngineParams(params);
    final stream = _streamedStreamFromLiveEngineParams(params, embedUrl: embed);
    final resolved = await _resolveStreamToEnginePlaySource(
      match,
      stream,
      onProgress: onProgress,
    );
    return resolved?.copyWith(
      liveEngineEmbedUrl: embed,
      liveEngineResolveParams: null,
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
        'viewers': match.viewers,
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

    final pluginSource = source.source.trim().isNotEmpty
        ? source.source.trim().toLowerCase()
        : label;
    final catalogViewers = match.viewers;
    final out = <_StreamedStream>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowViewers = parsePpvViewers(row['viewers']);
      final viewers = rowViewers > 0 ? rowViewers : catalogViewers;
      final fields = forjaLiveStreamFieldsFromRowName(
        (row['name'] ?? row['title'] ?? '').toString(),
      );
      if (row['webviewOnly'] == true) continue;
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      out.add(
        _StreamedStream(
          id: source.id,
          streamNo: i + 1,
          language: fields.language,
          hd: fields.hd,
          embedUrl: url,
          source: pluginSource,
          viewers: viewers,
        ),
      );
    }
    return out;
  }

  _StreamedStreamChoice? _choiceForPanelSource(
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
    final addonName = await _resolveStremioAddonName(
      baseUrl: match.stremioBaseUrl,
      matchAddonName: match.stremioAddonName,
    );
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
            label: _stremioStreamDisplayLabel(name, addonName),
            headers: StremioService.liveStreamRequestHeaders(s),
            liveSourceKind: IptvLiveSourceKind.stremio,
            liveProviderBadge: _stremioLiveProviderBadge(addonName),
          ),
        );
      }
    } catch (e) {
      debugPrint('[LiveMatches] Stremio stream error: $e');
    }
    return out;
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
        resolved: true,
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
      resolved: true,
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
          liveEngineResolveSource: _resolveIptvPlaySourceFromCatalog,
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

  List<IptvPlaySource> _liveEngineCatalogSources(
    List<_StreamedStreamChoice> candidates,
  ) {
    final sorted = [...candidates]
      ..sort(
        (a, b) => _effectiveStreamViewers(
          b.stream,
          b.catalogMatch,
        ).compareTo(_effectiveStreamViewers(a.stream, a.catalogMatch)),
      );
    final out = <IptvPlaySource>[];
    final seenEmbeds = <String>{};
    for (final choice in sorted) {
      final embed = choice.stream.embedUrl.trim();
      if (embed.isEmpty || !seenEmbeds.add(embed)) continue;
      out.add(
        _liveEnginePlaySource(
          match: choice.catalogMatch,
          stream: choice.stream,
          url: embed,
        ),
      );
    }
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
    final sources = _liveEngineCatalogSources(candidates);
    final pickedIndex = sources.indexWhere(
      (s) => (s.liveEngineEmbedUrl ?? s.url).trim() == pickedEmbed,
    );
    IptvPlaySource? resolvedPick;
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
      resolvedPick = picked;
      if (pickedIndex >= 0) {
        sources[pickedIndex] = picked;
        if (pickedIndex != 0) {
          final active = sources.removeAt(pickedIndex);
          sources.insert(0, active);
        }
      } else {
        sources.insert(0, picked);
      }
    });
    if (!ok) return true;
    if (resolvedPick == null) return false;
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
    if (isPpv || match.isForjaLive) {
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
    await _openLiveMatchDetails(
      host: _s,
      match: _streamedMatchFromPpv(s),
      ppvAnchor: s,
    );
  }
}
