part of '../live_sports_hub_page.dart';

/// Match-detail Providers rows — same TTL idea as Live TV IPTV sports cache.
const _providersResultsCacheTtl = Duration(minutes: 30);

class _ProvidersResultsCacheEntry {
  const _ProvidersResultsCacheEntry({
    required this.expiresAt,
    required this.choices,
    required this.panelSources,
  });

  final DateTime expiresAt;
  final List<_StreamedStreamChoice> choices;
  final List<IptvPlaySource> panelSources;
}

final Map<String, _ProvidersResultsCacheEntry> _providersResultsCache = {};

String _providersResultsCacheKey(
  _StreamedMatch match, [
  _IframeCatalogStream? iframe,
]) {
  final base = iframe != null
      ? _liveEventViewerKeyFromIframeCatalog(iframe)
      : _liveEventViewerKey(match);
  return 'providers:$base';
}

_ProvidersResultsCacheEntry? _providersResultsCacheGet(String key) {
  final hit = _providersResultsCache[key];
  if (hit == null) return null;
  if (DateTime.now().isAfter(hit.expiresAt)) {
    _providersResultsCache.remove(key);
    return null;
  }
  if (hit.panelSources.isEmpty && hit.choices.isEmpty) {
    _providersResultsCache.remove(key);
    return null;
  }
  return hit;
}

void _providersResultsCachePut(
  String key, {
  required List<_StreamedStreamChoice> choices,
  required List<IptvPlaySource> panelSources,
}) {
  if (choices.isEmpty && panelSources.isEmpty) return;
  _providersResultsCache[key] = _ProvidersResultsCacheEntry(
    expiresAt: DateTime.now().add(_providersResultsCacheTtl),
    choices: List<_StreamedStreamChoice>.from(choices),
    panelSources: List<IptvPlaySource>.from(panelSources),
  );
}

void _providersResultsCacheDrop(String key) {
  _providersResultsCache.remove(key);
}

void _clearProvidersResultsCache() {
  _providersResultsCache.clear();
}

mixin _LiveMatchesPlayback
    on ConsumerState<LiveSportsHubPage>, _LiveMatchesData {
  @override
  LiveSportsHubPageState get _s => this as LiveSportsHubPageState;

  /// Leanback TV: never offer PPV / Streamed / Mut embed rows — only native.
  bool get _tvNativeLiveOnly => ShellScope.metricsOf(context).usesTvDensity;

  /// Stremio streams always offered on Providers (no browse mode gate).
  bool get _offerStremioPlayFallback => true;

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
    _IframeCatalogStream iframeCatalog,
    _StreamedMatch streamed,
  ) async {
    await _openLiveMatchDetails(
      host: _s,
      match: streamed,
      iframeCatalogAnchor: iframeCatalog,
    );
  }

  Future<void> fillMatchDetailsProviders({
    required _StreamedMatch match,
    _IframeCatalogStream? iframeCatalogAnchor,
    required _IptvSportsChannelsPanelController controller,
    required List<_StreamedStreamChoice> choices,
    required bool Function() isStale,
    bool force = false,
  }) async {
    if (isStale() || controller.isDisposed) return;

    final cacheKey = _providersResultsCacheKey(match, iframeCatalogAnchor);
    if (force) {
      _providersResultsCacheDrop(cacheKey);
    } else {
      final hit = _providersResultsCacheGet(cacheKey);
      if (hit != null) {
        debugPrint(
          '[LiveMatches] Providers: cache hit '
          '(${hit.panelSources.length} channels) for $cacheKey',
        );
        choices
          ..clear()
          ..addAll(hit.choices);
        if (!isStale() && !controller.isDisposed) {
          controller.appendSources(hit.panelSources);
        }
        return;
      }
    }

    controller.setSearchPhase('Providers');

    Future<void> runForjaLive() async {
      try {
        await _fillForjaLiveSources(
          match: match,
          controller: controller,
          choices: choices,
          isStale: isStale,
          iframeCatalogAnchor: iframeCatalogAnchor,
        );
      } catch (e, st) {
        debugPrint('[LiveMatches] Forja Live providers error: $e\n$st');
      }
    }

    Future<void> runStremio() async {
      if (isStale() || controller.isDisposed) return;
      try {
        if (match.isStremio) {
          await _fillStremioSources(
            match: match,
            controller: controller,
            isStale: isStale,
          );
          return;
        }
        final stremio = await _resolveStremioStreamsMatching(match);
        if (!isStale() && !controller.isDisposed && stremio.isNotEmpty) {
          controller.appendSources(stremio);
        }
      } catch (e, st) {
        debugPrint('[LiveMatches] Stremio providers error: $e\n$st');
      }
    }

    await Future.wait([runForjaLive(), runStremio()]);
    if (isStale() || controller.isDisposed) return;
    _providersResultsCachePut(
      cacheKey,
      choices: choices,
      panelSources: controller.sources,
    );
  }

  _StreamedMatch _enrichedIptvSportsMatch(_StreamedMatch match) {
    final mergedGame = IptvSportsMatchService.sportMatchGameForResolve(
      match,
      _s._espnGames,
    );
    final espnPayload =
        IptvSportsMatchService.findEspnGame(match, _s._espnGames);
    return IptvSportsMatchService.copyMatch(
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

  Future<_StreamedMatch> fillIptvSportsSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required bool Function() isStale,
    bool loadBroadcastHints = true,
    bool force = false,
  }) async {
    final enriched = _enrichedIptvSportsMatch(match);
    controller.setSearchPhase('Live TV');
    if (loadBroadcastHints) {
      controller.beginBroadcastHintsLoad();
    }
    try {
      await IptvSportsMatchService.resolveStreams(
        enriched,
        force: force,
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
        final hints = await IptvSportsMatchService.broadcastHintsFor(enriched);
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
    _IframeCatalogStream? iframeCatalogAnchor,
  }) async {
    await LiveMatchesEngine.warmPluginMeta();

    if (iframeCatalogAnchor != null && iframeCatalogAnchor.iframe.trim().isNotEmpty) {
      choices.add(_iframeCatalogStreamChoice(iframeCatalogAnchor, match));
    } else {
      _prependMatchingIframeCatalogChoices(match, choices);
    }
    _panelAppendChoices(controller, choices);

    final forjaLive = this as _LiveMatchesForjaLive;
    // Catalog chip scopes the schedule grid only — never Providers.
    await forjaLive._ensureAllCatalogsForProviders(isStale: isStale);
    if (isStale() || controller.isDisposed) return;

    var known = forjaLive._knownProviderEventMatches(match);
    // Horizon/cap on grid ingest can miss siblings — scan full catalogs.
    final hydrated = await forjaLive._hydrateMissingProviderCatalogMatches(
      match,
      known,
      isStale: isStale,
    );
    if (isStale() || controller.isDisposed) return;
    if (hydrated.isNotEmpty) {
      known = forjaLive._knownProviderEventMatches(match);
    }
    debugPrint(
      '[LiveMatches] Providers resolve targets: '
      '${known.isEmpty ? '(none)' : known.map((m) => '${m.livePluginId} src=${m.sources.length} inline=${m.inlineStreams.length}').join(' | ')}',
    );

    // Resolve via plugins/live (`live-*` action=resolve) — never catalog-* on Providers.
    if (known.isNotEmpty) {
      await _resolveCatalogStreamChoices(
        known,
        isStale: isStale,
        onPartial: (batch) {
          if (isStale() || controller.isDisposed) return;
          if (batch.isEmpty) return;
          choices.addAll(batch);
          _panelAppendChoices(controller, batch);
        },
      );
    }
    if (isStale() || controller.isDisposed) return;

    _rememberEventStreamViewers(match, _sheetTotalViewers(choices));
    if (iframeCatalogAnchor != null) {
      _rememberIframeCatalogViewers(iframeCatalogAnchor, _sheetTotalViewers(choices));
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
        await IptvSportsMatchService.resolveStreams(
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
        final hints = await IptvSportsMatchService.broadcastHintsFor(enriched);
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

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    await _openLiveMatchDetails(host: _s, match: match);
  }

  void _rememberEventStreamViewers(_StreamedMatch match, int total) {
    if (total <= 0 || !mounted) return;
    final key = _liveEventViewerKey(match);
    if (_s._eventStreamViewerTotals[key] == total) return;
    setState(() => _s._eventStreamViewerTotals[key] = total);
  }

  void _rememberIframeCatalogViewers(_IframeCatalogStream iframeCatalog, int total) {
    if (total <= 0 || !mounted) return;
    final key = _liveEventViewerKeyFromIframeCatalog(iframeCatalog);
    if (_s._eventStreamViewerTotals[key] == total) return;
    setState(() => _s._eventStreamViewerTotals[key] = total);
  }

  void _prependMatchingIframeCatalogChoices(
    _StreamedMatch match,
    List<_StreamedStreamChoice> choices,
  ) {
    if (choices.any(_isIframeCatalogStreamChoice)) return;
    for (final iframeRow in _s._iframeCatalogStreams) {
      if (!_sameIframeAndScheduleEvent(iframeRow, match) || iframeRow.iframe.trim().isEmpty) {
        continue;
      }
      choices.insert(0, _iframeCatalogStreamChoice(iframeRow, match));
      break;
    }
  }

  _StreamedStreamChoice _iframeCatalogStreamChoice(
    _IframeCatalogStream iframeRow,
    _StreamedMatch anchor,
  ) {
    final resolvePluginId = _iframeProviderLivePluginId();
    final sourceToken = resolvePluginId.isNotEmpty
        ? LiveMatchesEngine.cachedResolveSourceToken(resolvePluginId)
        : '';
    return _StreamedStreamChoice(
      catalogMatch: _StreamedMatch(
        id: 'iframe:${iframeRow.id}',
        title: anchor.title.isNotEmpty ? anchor.title : iframeRow.name,
        category: iframeRow.categoryName,
        dateMs: iframeRow.startsAt > 0
            ? iframeRow.startsAt * 1000
            : anchor.dateMs,
        poster: iframeRow.poster.isNotEmpty ? iframeRow.poster : anchor.poster,
        popular: false,
        airing: iframeRow.isLive,
        viewers: iframeRow.viewers,
        homeTeam: iframeRow.homeTeam ?? anchor.homeTeam,
        homeBadge: iframeRow.homeBadge ?? anchor.homeBadge,
        awayTeam: iframeRow.awayTeam ?? anchor.awayTeam,
        awayBadge: iframeRow.awayBadge ?? anchor.awayBadge,
        sources: const [],
        catalog: 'forja_live',
        livePluginId: resolvePluginId,
      ),
      stream: _StreamedStream(
        id: iframeRow.id,
        streamNo: 1,
        language: '',
        hd: false,
        embedUrl: iframeRow.iframe,
        source: sourceToken,
        viewers: iframeRow.viewers,
      ),
    );
  }

  IptvPlaySource _choiceToPanelSource(_StreamedStreamChoice choice) {
    final stream = choice.stream;
    final match = choice.catalogMatch;
    final embed = stream.embedUrl.trim();
    final sourceLabel = _StreamedStreamSheet.sourceLabel(stream.source);
    final title = _StreamedStreamSheet.streamTitle(stream, sourceLabel);
    final playUrl = embed.isNotEmpty
        ? embed
        : 'pending:${match.id}:${stream.id}:${stream.streamNo}';
    final directPlayback = stream.directPlayback ||
        (embed.isNotEmpty && iptvLiveEnginePlayUrlReady(embed));
    return IptvPlaySource(
      url: playUrl,
      label: title,
      detail: _streamPanelDetail(stream),
      headers: directPlayback ? (stream.resolvedHeaders ?? const {}) : const {},
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveProviderBadge: _StreamedStreamSheet.serverLabelFor(match),
      liveViewerCount: _effectiveStreamViewers(stream, match),
      liveStreamHd: stream.hd,
      liveEngineEmbedUrl: directPlayback ? null : (embed.isNotEmpty ? embed : null),
      liveEngineResolveParams: directPlayback
          ? null
          : _liveEngineResolveParams(match, stream),
    );
  }

  String _streamPanelLabel(_StreamedMatch match, _StreamedStream stream) {
    final sourceLabel = _StreamedStreamSheet.sourceLabel(stream.source);
    return _StreamedStreamSheet.streamTitle(stream, sourceLabel);
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
    final jobs = <( _StreamedMatch, _StreamedSourceRef)>[];
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
        jobs.add((m, ref));
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

    // Run source jobs one-at-a-time — eager Future() stamps Node/JSC unlocks.
    for (var i = 0; i < jobs.length; i++) {
      if (isStale?.call() == true) break;
      final (m, ref) = jobs[i];
      List<_StreamedStreamChoice> batch = const [];
      try {
        final streams = m.isForjaLive
            ? await _forjaLiveStreamsFromSource(
                m,
                ref,
                allowStreamedFallback: false,
              )
            : await _fetchStreamedStreams(ref, allowFallback: false);
        batch = [
          for (final stream in streams)
            if (stream.embedUrl.trim().isNotEmpty)
              _StreamedStreamChoice(catalogMatch: m, stream: stream),
        ];
      } catch (e) {
        debugPrint('[LiveMatches] resolve ${ref.source}/${ref.id}: $e');
      }
      if (isStale?.call() == true) break;
      final fresh = <_StreamedStreamChoice>[];
      for (final choice in batch) {
        final url = choice.stream.embedUrl.trim();
        if (url.isEmpty || !seenUrls.add(url)) continue;
        out.add(choice);
        fresh.add(choice);
      }
      if (fresh.isNotEmpty) onPartial?.call(fresh);
      if (i == jobs.length - 1) {
        onProgress?.call('Building stream list…');
      }
    }

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

  bool _isIframeCatalogMatch(_StreamedMatch match, [_StreamedStream? stream]) {
    if (LiveMatchesEngine.cachedIsIframeCatalog(match.livePluginId)) {
      return true;
    }
    if (stream != null) {
      final token = LiveMatchesEngine.cachedResolveSourceToken(
        match.livePluginId,
      );
      if (token.isNotEmpty &&
          stream.source.trim().toLowerCase() == token.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  String _iframeProviderLivePluginId() =>
      LiveMatchesEngine.cachedIframeProviderResolvePluginId() ?? '';

  bool _isIframeCatalogStreamChoice(_StreamedStreamChoice choice) {
    return _isIframeCatalogMatch(choice.catalogMatch, choice.stream);
  }

  Future<void> openResolvedStreamChoice(_StreamedStreamChoice choice) async {
    await _openStreamedEmbed(choice.catalogMatch, choice.stream);
  }

  /// Panel row with resolve params but no `_choices` hit (Stremio mix / desync).
  ///
  /// Opens **only** [picked] — never sibling Providers as failover
  /// (cross-provider rotate is movie-Sources-hostile).
  Future<void> openPanelLiveEngineSource(IptvPlaySource picked) async {
    final url = picked.url.trim();
    final ready = iptvLiveEnginePlayUrlReady(url) ||
        (picked.liveEngineResolveParams == null &&
            (url.startsWith('http://') || url.startsWith('https://')) &&
            !(url.startsWith('pending:')));
    if (ready) {
      await _openEngineNativeSources(
        title: picked.pickerTitle,
        subtitle: picked.pickerSubtitle ?? '',
        sources: [picked],
      );
      return;
    }
    IptvPlaySource? resolved;
    final ok = await _runWithCancellableLoading('Opening stream…', (
      setMessage,
    ) async {
      setMessage('Unlocking source…');
      resolved = await _resolveIptvPlaySourceFromCatalog(
        picked,
        onProgress: setMessage,
      );
    });
    if (!ok) return;
    final handoff = resolved;
    final handoffUrl = handoff?.url.trim() ?? '';
    if (handoff == null ||
        !(iptvLiveEnginePlayUrlReady(handoffUrl) ||
            handoffUrl.startsWith('http://') ||
            handoffUrl.startsWith('https://'))) {
      LiveMatchesEngine.engineResolveFailed();
      return;
    }
    await _openEngineNativeSources(
      title: handoff.pickerTitle,
      subtitle: handoff.pickerSubtitle ?? '',
      sources: [handoff],
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
      'isIframeCatalog': _isIframeCatalogMatch(match, stream),
      'hd': stream.hd,
      'viewers': stream.viewers,
      'language': stream.language,
    };
  }

  _StreamedMatch _streamedMatchFromLiveEngineParams(Map<String, dynamic> params) {
    final isForjaLive = params['isForjaLive'] == true;
    final isMut = params['isMut'] == true;
    var pluginId = (params['livePluginId'] ?? '').toString().trim();
    if (pluginId.isEmpty && params['isIframeCatalog'] == true) {
      pluginId = _iframeProviderLivePluginId();
    }
    return _StreamedMatch(
      id: (params['eventId'] ?? '').toString(),
      title: (params['title'] ?? '').toString(),
      category: (params['category'] ?? '').toString(),
      dateMs: 0,
      poster: '',
      popular: false,
      airing: true,
      viewers: parseLiveViewerCount(params['viewers']),
      sources: [
        _StreamedSourceRef(
          source: (params['source'] ?? '').toString(),
          id: (params['matchId'] ?? '').toString(),
        ),
      ],
      catalog: isForjaLive
          ? 'forja_live'
          : (isMut ? 'mut' : ''),
      livePluginId: pluginId,
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
      viewers: parseLiveViewerCount(params['viewers']),
    );
  }

  Future<IptvPlaySource?> _resolveIptvPlaySourceFromCatalog(
    IptvPlaySource catalog, {
    void Function(String)? onProgress,
  }) async {
    final params = catalog.liveEngineResolveParams;
    if (params == null) return null;
    var embed = (catalog.liveEngineEmbedUrl ?? '').trim();
    if (embed.isEmpty) {
      final url = catalog.url.trim();
      if (url.isNotEmpty && !url.startsWith('pending:')) embed = url;
    }
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
    final pluginId = LiveMatchesEngine.cachedProviderResolvePluginId(
      match.livePluginId,
    );
    if (pluginId.isEmpty) return const [];

    final catalogMeta = await _catalogStreamsForSourceRef(
      match,
      source,
      allowFallback: allowStreamedFallback,
    );

    // Catalog already lists every mirror (Streamed stream Nos, etc.).
    // Never GOAT-unlock them all during Providers fill — that stampedes
    // Node/happy-dom and SIGSEGVs macOS. List as unlock-on-tap; crack on play.
    if (catalogMeta.isNotEmpty) {
      final pluginSource = source.source.trim().isNotEmpty
          ? source.source.trim().toLowerCase()
          : LiveMatchesEngine.cachedResolveSourceToken(pluginId);
      final out = <_StreamedStream>[];
      final seen = <String>{};
      for (var i = 0; i < catalogMeta.length; i++) {
        final meta = catalogMeta[i];
        final embed = meta.embedUrl.trim().isNotEmpty
            ? meta.embedUrl.trim()
            : source.iframe.trim();
        if (embed.isEmpty || !seen.add(embed)) continue;
        out.add(
          _StreamedStream(
            id: meta.id.isNotEmpty ? meta.id : source.id,
            streamNo: meta.streamNo > 0 ? meta.streamNo : i + 1,
            language: meta.language,
            hd: meta.hd,
            embedUrl: embed,
            source: meta.source.trim().isNotEmpty
                ? meta.source
                : pluginSource,
            viewers: meta.viewers > 0 ? meta.viewers : match.viewers,
            directPlayback: false,
          ),
        );
      }
      if (out.isNotEmpty) return out;
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
      if (source.iframe.trim().isNotEmpty) {
        final token = LiveMatchesEngine.cachedResolveSourceToken(pluginId);
        return [
          _StreamedStream(
            id: source.id,
            streamNo: 1,
            language: '',
            hd: false,
            embedUrl: source.iframe,
            source: token.isNotEmpty ? token : source.source,
            viewers: match.viewers,
            directPlayback: false,
          ),
        ];
      }
      if (allowStreamedFallback && !match.isForjaLive) {
        return _fetchStreamedStreams(source, allowFallback: true);
      }
      return const [];
    }

    final pluginSource = source.source.trim().isNotEmpty
        ? source.source.trim().toLowerCase()
        : LiveMatchesEngine.cachedResolveSourceToken(pluginId);
    final out = <_StreamedStream>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row['webviewOnly'] == true) continue;
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      out.add(
        _streamedStreamFromResolveRow(
          row: row,
          source: source,
          match: match,
          pluginSource: pluginSource,
          catalogMeta: null,
          index: i,
        ),
      );
    }
    return out;
  }

  _StreamedStreamChoice? choiceForPanelSource(
    IptvPlaySource picked,
    List<_StreamedStreamChoice> choices,
  ) {
    final url = picked.url.trim();
    final embedUrl = (picked.liveEngineEmbedUrl ?? '').trim();
    for (final c in List<_StreamedStreamChoice>.from(choices)) {
      final embed = c.stream.embedUrl.trim();
      if (embed.isNotEmpty && (embed == url || embed == embedUrl)) return c;
      final pending =
          'pending:${c.catalogMatch.id}:${c.stream.id}:${c.stream.streamNo}';
      if (url == pending) return c;
    }
    final label = picked.label.trim();
    if (label.isEmpty) return null;
    for (final c in List<_StreamedStreamChoice>.from(choices)) {
      if (_streamPickerLabel(c.catalogMatch, c.stream) == label) return c;
      if (_streamPanelLabel(c.catalogMatch, c.stream) == label) return c;
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
    List<_StreamedMatch> catalog;
    try {
      catalog = await _fetchStremioSportMatches();
    } catch (e) {
      debugPrint('[LiveMatches] Stremio catalog error: $e');
      return const [];
    }
    final hits =
        catalog.where((m) => _stremioCatalogEventMatch(match, m)).toList();
    debugPrint(
      '[LiveMatches] Stremio providers: catalog=${catalog.length} '
      'hits=${hits.length} for ${match.id} "${match.title}"',
    );
    if (hits.isEmpty) return const [];

    final batches = await Future.wait(
      hits.take(3).map((hit) async {
        try {
          return await _stremioPlaySourcesFor(hit);
        } catch (e) {
          debugPrint('[LiveMatches] Stremio addon resolve error: $e');
          return const <IptvPlaySource>[];
        }
      }),
    );

    final out = <IptvPlaySource>[];
    final seenUrls = <String>{};
    for (final batch in batches) {
      for (final s in batch) {
        if (!seenUrls.add(s.url)) continue;
        out.add(s);
      }
    }
    debugPrint('[LiveMatches] Stremio providers: playable=${out.length}');
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

  Future<void> playIptvSportsSources(
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

  _StreamedMatch _streamedMatchFromIframeCatalog(_IframeCatalogStream s) => _StreamedMatch(
    id: 'iframe:${s.id}',
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

  _StreamedSourceRef? _sourceRefForStream(
    _StreamedMatch match,
    _StreamedStream stream,
  ) {
    for (final ref in match.sources) {
      if (ref.id == stream.id) return ref;
    }
    final src = stream.source.trim().toLowerCase();
    if (src.isNotEmpty) {
      for (final ref in match.sources) {
        if (ref.source.trim().toLowerCase() == src) return ref;
      }
    }
    if (stream.id.isEmpty && stream.source.trim().isEmpty) return null;
    return _StreamedSourceRef(
      source: stream.source,
      id: stream.id,
      iframe: stream.embedUrl,
    );
  }

  Future<IptvPlaySource?> _unlockForjaLiveSourceRef(
    _StreamedMatch match,
    _StreamedStream stream, {
    void Function(String)? onProgress,
  }) async {
    final ref = _sourceRefForStream(match, stream);
    if (ref == null) return null;
    final pluginId = LiveMatchesEngine.cachedProviderResolvePluginId(
      match.livePluginId,
    );
    if (pluginId.isEmpty) return null;
    var embed = stream.embedUrl.trim();
    if (embed.isEmpty || embed.startsWith('pending:')) {
      embed = ref.iframe.trim();
    }
    if (embed.isEmpty) return null;
    onProgress?.call('Unlocking source…');
    List<Map<String, dynamic>> rows = const [];
    try {
      rows = await EngineService.instance.runLivePlugin(
        pluginId: pluginId,
        action: 'resolve',
        params: {
          'matchId': stream.id.isNotEmpty ? stream.id : ref.id,
          'eventId': match.id,
          'source': stream.source.isNotEmpty ? stream.source : ref.source,
          'category': match.category,
          'title': match.title,
          'stream': stream.streamNo > 0 ? stream.streamNo.toString() : '1',
          'embedUrl': embed,
          'iframe': embed,
          'viewers': stream.viewers > 0 ? stream.viewers : match.viewers,
        },
      );
    } catch (e) {
      debugPrint(
        '[LiveMatches] unlock ${ref.source}/${ref.id} '
        '#${stream.streamNo}: $e',
      );
      return null;
    }
    for (final row in rows) {
      if (row['webviewOnly'] == true) continue;
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty || !iptvLiveEnginePlayUrlReady(url)) continue;
      final pluginSource = stream.source.trim().isNotEmpty
          ? stream.source.trim().toLowerCase()
          : LiveMatchesEngine.cachedResolveSourceToken(pluginId);
      final hit = _streamedStreamFromResolveRow(
        row: row,
        source: ref,
        match: match,
        pluginSource: pluginSource,
        catalogMeta: stream,
        index: 0,
      );
      return _resolveStreamToEnginePlaySource(
        match,
        hit,
        onProgress: onProgress,
        allowSourceRefFallback: false,
      );
    }
    return null;
  }

  Future<IptvPlaySource?> _resolveStreamToEnginePlaySource(
    _StreamedMatch match,
    _StreamedStream stream, {
    void Function(String)? onProgress,
    bool allowSourceRefFallback = true,
  }) async {
    var embed = stream.embedUrl.trim();
    if (embed.startsWith('pending:')) embed = '';
    if (embed.isEmpty) {
      final iframe = _sourceRefForStream(match, stream)?.iframe.trim() ?? '';
      if (iframe.isNotEmpty) embed = iframe;
    }

    // Already unlocked — do not re-unlock (signed CDNs die).
    if (embed.isNotEmpty &&
        (stream.directPlayback || iptvLiveEnginePlayUrlReady(embed))) {
      final headers = LiveGoatUnlock.withWftyPlaybackReferer(
        embed,
        stream.resolvedHeaders ??
            (_isIframeCatalogMatch(match, stream)
                ? _tokenizedEmbedStreamHeaders(embed)
                : _liveEmbedStreamHeaders(
                    embed,
                    catalogReferer: match.isForjaLive
                        ? _forjaLiveCdnReferer(embed)
                        : null,
                  )),
      );
      final direct = liveEngineOpenDirect(
        embed,
        pluginDirect: stream.directPlayback,
      );
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

    final iframeCatalog = _isIframeCatalogMatch(match, stream);
    final catalogReferer = iframeCatalog
        ? await LiveMatchesEngine.iframeCatalogWebReferer()
        : match.isForjaLive
        ? (embed.isNotEmpty
              ? (_forjaLiveCdnReferer(embed) ??
                    await LiveMatchesEngine.pluginReferer(
                      match.livePluginId,
                      embedUrl: embed,
                    ))
              : await LiveMatchesEngine.pluginReferer(match.livePluginId))
        : _streamedReferer;
    if (embed.isNotEmpty &&
        RegExp(r'\.m3u8|\.mp4', caseSensitive: false).hasMatch(embed)) {
      final headers = LiveGoatUnlock.withWftyPlaybackReferer(
        embed,
        iframeCatalog
            ? _tokenizedEmbedStreamHeaders(embed)
            : _liveEmbedStreamHeaders(
                embed,
                catalogReferer: match.isForjaLive
                    ? _forjaLiveCdnReferer(embed)
                    : null,
              ),
      );
      final direct = liveEngineOpenDirect(embed);
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
    var pluginId = LiveMatchesEngine.cachedProviderResolvePluginId(
      match.livePluginId,
    );
    if (pluginId.isEmpty && iframeCatalog) {
      pluginId = _iframeProviderLivePluginId();
    }
    LiveEngineResolveResult? result;
    if (pluginId.isNotEmpty) {
      result = await LiveMatchesEngine.resolve(
        pluginId: pluginId,
        params: {
          if (embed.isNotEmpty) 'embedUrl': embed,
          if (embed.isNotEmpty) 'iframe': embed,
          if (embed.isNotEmpty) 'url': embed,
          'source': stream.source,
          'matchId': stream.id,
          'stream': stream.streamNo.toString(),
          'category': match.category,
          'title': match.title,
        },
      );
    }
    if (result == null || !result.playable) {
      if (allowSourceRefFallback && match.isForjaLive) {
        return _unlockForjaLiveSourceRef(
          match,
          stream,
          onProgress: onProgress,
        );
      }
      return null;
    }

    final headers = LiveGoatUnlock.withWftyPlaybackReferer(
      result.url,
      result.headers.isNotEmpty
          ? result.headers
          : iframeCatalog
          ? _tokenizedEmbedStreamHeaders(embed.isNotEmpty ? embed : result.url)
          : _liveEmbedStreamHeaders(
              result.url,
              catalogReferer: catalogReferer,
            ),
    );
    final direct = liveEngineOpenDirect(
      result.url,
      pluginDirect: result.directPlayback,
    );
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

    try {
      if (PlatformInfo.isAndroidTv) {
        await PlatformChannel.releaseUnderlayPlatformViewFocus();
      }
      if (!mounted) return;
      await IptvPtPlayerScreen.open(
        context,
        IptvPtPlayerScreen(
          sources: sources,
          title: title,
          subtitle: subtitle,
          titleTracksSource: true,
          engineContext: BuiltInPlayerContext.live,
          liveSourceKind: IptvLiveSourceKind.liveEngine,
          liveEngineResolveSource: _resolveIptvPlaySourceFromCatalog,
        ),
      );
    } catch (_) {}
  }

  Future<bool> _tryEngineStreamedOpen(
    _StreamedMatch match,
    _StreamedStream stream,
  ) async {
    if (!await LiveMatchesEngine.isEngineResolveMode()) {
      LiveMatchesEngine.engineResolveFailed();
      return false;
    }

    // One Providers row → one player source. Do not pack sibling catalogs
    // (Watchdog was rotating WatchFooty → Streamed on open fail).
    IptvPlaySource? resolvedPick;
    final ok = await _runWithCancellableLoading('Opening stream…', (
      setMessage,
    ) async {
      setMessage('Unlocking source…');
      resolvedPick = await _resolveStreamToEnginePlaySource(
        match,
        stream,
        onProgress: setMessage,
      );
    });
    if (!ok) return true;
    final picked = resolvedPick;
    if (picked == null) {
      LiveMatchesEngine.engineResolveFailed();
      return false;
    }

    await _openEngineNativeSources(
      title: match.title,
      subtitle: _streamPlaySubtitle(match, stream),
      sources: [picked],
    );
    return true;
  }

  Future<void> _openStreamedEmbed(
    _StreamedMatch match,
    _StreamedStream stream,
  ) async {
    await _tryEngineStreamedOpen(match, stream);
  }

  Future<void> _openIframeCatalogStream(_IframeCatalogStream s) async {
    await _openLiveMatchDetails(
      host: _s,
      match: _streamedMatchFromIframeCatalog(s),
      iframeCatalogAnchor: s,
    );
  }
}
