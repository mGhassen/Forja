part of 'exo_player_screen.dart';

mixin _ExoPlayerSources on ConsumerState<ExoPlayerScreen> {
  _ExoPlayerScreenState get _s => this as _ExoPlayerScreenState;

  bool get _usesCatalogSourcesPanel {
    if (widget.movie == null) return false;
    final magnet = widget.magnetLink;
    if (magnet != null && magnet.isNotEmpty) return true;
    return isCatalogSourcesMode(
      _s._currentProvider ?? widget.activeProvider,
    );
  }

  bool get _hasStreamPickerSources {
    if (_usesCatalogSourcesPanel) return false;
    final hasProviders =
        widget.providers != null && widget.providers!.isNotEmpty;
    final hasSources =
        _s._currentSources != null && _s._currentSources!.isNotEmpty;
    return hasProviders || hasSources;
  }

  String _activeServerLabel() {
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid != null &&
        pid.isNotEmpty &&
        widget.providers != null &&
        widget.providers!.containsKey(pid)) {
      return PlayerProviderMenu.snackbarLabel(pid, widget.providers![pid]);
    }
    if (_s._sources.isNotEmpty) {
      final title = _s._sources[_s._sourceIndex].title.trim();
      if (title.isNotEmpty) return title;
    }
    return 'Sources';
  }

  void _seedSourceSession(List<_ExoSource> ranked) {
    _s._currentProvider = widget.activeProvider;
    _s._currentUrl =
        ranked.isNotEmpty ? ranked.first.url : widget.mediaPath;
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      _s._currentSources = dedupeStreamSources(widget.sources!);
    } else if (ranked.isNotEmpty) {
      _s._currentSources = [
        for (final s in ranked)
          StreamSource(
            url: s.url,
            title: s.title,
            type: 'video',
            headers: s.headers,
          ),
      ];
    } else {
      _s._currentSources = [
        StreamSource(
          url: widget.mediaPath,
          title: widget.title,
          type: 'video',
          headers: widget.headers,
        ),
      ];
    }
    final pid = _s._currentProvider;
    final sources = _s._currentSources;
    if (pid != null &&
        pid.isNotEmpty &&
        sources != null &&
        sources.isNotEmpty) {
      _s._providerSourcesCache.value = {
        ..._s._providerSourcesCache.value,
        pid: sources,
      };
    }
  }

  Future<List<StreamSource>?> _loadServer(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _s._providerSourcesCache.value[providerId];
      if (cached != null && cached.isNotEmpty) return cached;
      if (providerId == _s._currentProvider &&
          _s._currentSources != null &&
          _s._currentSources!.isNotEmpty) {
        return _s._currentSources;
      }
    } else {
      final next = Map<String, List<StreamSource>>.from(
        _s._providerSourcesCache.value,
      )..remove(providerId);
      _s._providerSourcesCache.value = next;
    }

    for (final id in _s._providerLoadGens.keys.toList()) {
      if (id == providerId) continue;
      _s._providerLoadGens[id] = (_s._providerLoadGens[id] ?? 0) + 1;
    }
    DomainStreamProviderResolver.cancelAllPending();

    final gen = (_s._providerLoadGens[providerId] ?? 0) + 1;
    _s._providerLoadGens[providerId] = gen;
    _s.ref.read(playerResolveStatusProvider.notifier).setLoading(providerId);

    try {
      if (widget.movie == null || widget.providers == null) return null;
      final hit = await PlayerSourceResolve.resolvePinnedForMovie(
        movie: widget.movie!,
        providers: widget.providers!,
        providerId: providerId,
        season: widget.selectedSeason ?? 1,
        episode: widget.hubEpisodeNumber?.toInt() ??
            widget.selectedEpisode ??
            1,
        isCancelled: () =>
            _s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen,
        bypassDiskCache: forceRefresh,
      );
      if (_s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen) {
        return null;
      }
      if (hit != null && hit.streamSources.isNotEmpty) {
        final sources = dedupeStreamSources(hit.streamSources);
        _s._providerSourcesCache.value = {
          ..._s._providerSourcesCache.value,
          providerId: sources,
        };
        if (forceRefresh && providerId == _s._currentProvider) {
          _s._currentSources = sources;
        }
        _s.ref.read(playerResolveStatusProvider.notifier).setReady();
        return sources;
      }
      _s.ref.read(playerResolveStatusProvider.notifier).setError(
            'No streams found',
          );
      return null;
    } catch (_) {
      if (!_s._disposed && (_s._providerLoadGens[providerId] ?? 0) == gen) {
        _s.ref.read(playerResolveStatusProvider.notifier).setError(
              'Failed to load sources',
            );
      }
      return null;
    }
  }

  Future<bool> _checkStreamSource(
    StreamSource source,
    int index, [
    String? providerId,
  ]) async {
    final pid = providerId ?? _s._currentProvider ?? '';
    try {
      var openUrl = source.url;
      Map<String, String>? headers = source.headers ?? widget.headers;

      if (animeHlsNeedsPngStripFor(openUrl, sourceKey: pid)) {
        final stripped = await applyAnimePngStripIfNeeded(
          StreamSource(
            url: openUrl,
            title: source.title,
            type: source.type,
            headers: headers,
          ),
          sourceKey: pid,
        );
        openUrl = stripped.url;
        headers = stripped.headers;
      }

      return await probeStreamSourceUrl(openUrl, headers, sourceKey: pid);
    } catch (_) {
      return false;
    }
  }

  Future<void> _selectStreamFromDialog(
    String providerId,
    StreamSource source,
    int index,
  ) async {
    final switchGen = ++_s._fallbackGen;
    final resumeAt = _s._position;
    final statusId = 'source-switch-$index';
    final label = source.title.trim().isEmpty ? 'Stream' : source.title;
    _s._statusController.upsert(
      statusId,
      label,
      kind: StatusRouletteKind.loading,
    );

    try {
      var openUrl = source.url;
      Map<String, String>? headers = source.headers ?? widget.headers;

      if (animeHlsNeedsPngStripFor(openUrl, sourceKey: providerId)) {
        final stripped = await applyAnimePngStripIfNeeded(
          StreamSource(
            url: openUrl,
            title: source.title,
            type: source.type,
            headers: headers,
          ),
          sourceKey: providerId,
        );
        openUrl = stripped.url;
        headers = stripped.headers;
      }

      final reachable = await probeStreamSourceUrl(
        openUrl,
        headers,
        sourceKey: providerId,
      );
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      if (!reachable) {
        _s._statusController.upsert(
          statusId,
          label,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }

      DomainStreamProviderResolver.cancelAllPending();
      try {
        await ExoPlayerBridge.stop(_s._viewId);
      } catch (_) {}
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;

      final cached = _s._providerSourcesCache.value[providerId];
      final sessionSources = (cached != null && cached.isNotEmpty)
          ? cached
          : dedupeStreamSources([source]);

      setState(() {
        _s._currentProvider = providerId;
        _s._currentSources = sessionSources;
        _s._currentUrl = openUrl;
        _s._hasError = false;
        _s._errorMessage = '';
        _s._sources = [
          for (final s in sessionSources)
            _ExoSource(
              url: s.url,
              title: s.title,
              headers: s.headers ?? headers,
            ),
        ];
        _s._sourceIndex = index.clamp(0, _s._sources.length - 1);
        final match = _s._sources.indexWhere((s) => s.url == source.url);
        if (match >= 0) _s._sourceIndex = match;
      });

      _s._opening = false;
      _s._startPositionApplied = true;
      _s._preferredSubtitleApplied = false;
      final prepared = await _s._prepareOpenSubtitles(
        (widget.externalSubtitles ?? [])
            .where((s) => (s['url'] ?? '').toString().isNotEmpty)
            .toList(),
      );
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      _s._sideloadedSubtitles = prepared;
      final maxH = await SettingsService().getMaxPlaybackHeight();
      final caps = exoVodCapsForMaxPlaybackHeight(maxH);
      await ExoPlayerBridge.open(
        viewId: _s._viewId,
        url: openUrl,
        headers: headers,
        startPosition: resumeAt.inSeconds > 0 ? resumeAt : Duration.zero,
        subtitles: prepared
            .map(
              (s) => {
                'url': s['url']!,
                'lang': s['lang'] ?? 'und',
                'label': s['label'] ?? s['lang'] ?? 'und',
              },
            )
            .toList(),
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
      );
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      await ExoPlayerBridge.setVolume(_s._viewId, _s._volume / 100.0);
      if (_s._rate != 1.0) {
        await ExoPlayerBridge.setRate(_s._viewId, _s._rate);
      }
      await ExoPlayerBridge.setResizeMode(_s._viewId, _s._resizeMode);
      _s._statusController.complete();
      widget.onPlaybackStarted?.call();
      if (_s._isTv) _s._claimPlayFocus();
    } catch (e) {
      debugPrint('[ExoPlayer] source switch failed: $e');
      if (!mounted || _s._disposed || switchGen != _s._fallbackGen) return;
      _s._statusController.upsert(
        statusId,
        label,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _showSourcesDialog(BuildContext anchorContext) async {
    if (!_hasStreamPickerSources) return;
    await PlayerServerStreamDialog.show(
      context,
      providers: widget.providers,
      currentProviderId: _s._currentProvider ?? widget.activeProvider,
      currentUrl: _s._currentUrl,
      currentSources: _s._currentSources,
      providerSourcesCache: _s._providerSourcesCache,
      onLoadServer: _loadServer,
      onSelectStream: _selectStreamFromDialog,
      onCheckStream: _checkStreamSource,
      movie: widget.movie,
      anchorContext: anchorContext,
    );
    if (_s._isTv) _s._claimPlayFocus();
  }
}
