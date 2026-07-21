part of 'details_screen.dart';

mixin _DetailsScreenPanel on State<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  // ─── audio filter helpers ────────────────────────────────────────────────

  /// Torrent results after applying panel filters.
  List<TorrentResult> get _filteredTorrentResults => filterTorrentResults(
    _s._allTorrentResults,
    searchQuery: _s._sourceSearchQuery,
    qualityFilters: _s._activeQualityFilters,
    languageFilters: _s._activeLanguageFilters,
    techFilters: _s._activeTechFilters,
    audioFilters: _s._activeAudioFilters,
    sizeFilters: _s._activeSizeFilters,
  );

  bool get _panelShowsTorrents => _s._panelKindFilter == 'torrents';

  bool get _panelShowsStremio => _s._panelKindFilter == 'stremio';

  bool get _panelShowsNuvio => _s._panelKindFilter == 'nuvio';

  List<Map<String, dynamic>> get _filteredPanelStremioStreams {
    final streams = _s._selectedSourceId == 'all_stremio'
        ? _s._allCombinedStremioStreams
        : _s._stremioStreams;
    return streams.whereType<Map<String, dynamic>>().where((s) {
      if (_s._selectedSourceId != 'all_stremio' &&
          _s._selectedSourceId.isNotEmpty &&
          s['_addonBaseUrl'] != _s._selectedSourceId) {
        return false;
      }
      return _matchesPanelStreamFilters(s);
    }).toList();
  }

  bool _nuvioStreamSelected(Map<String, dynamic> s) {
    final id = s['_nuvioScraperId'] as String?;
    if (id != null) return _s._nuvioSelectedScraperIds.contains(id);
    final base = s['_addonBaseUrl'] as String?;
    if (base != null && base.startsWith('nuvio:')) {
      return _s._nuvioSelectedScraperIds.contains(
        base.substring('nuvio:'.length),
      );
    }
    return false;
  }

  List<Map<String, dynamic>> get _selectedNuvioStreams => _s._nuvioStreams
      .whereType<Map<String, dynamic>>()
      .where(_nuvioStreamSelected)
      .toList();

  List<Map<String, dynamic>> get _filteredPanelNuvioStreams =>
      _selectedNuvioStreams.where(_matchesPanelStreamFilters).toList();

  List<String> get _panelFilterNames {
    final names = <String>[];
    if (_panelShowsTorrents) {
      names.addAll(_s._allTorrentResults.map((r) => r.name));
    }
    if (_panelShowsStremio) {
      names.addAll(
        _s._stremioStreams.map(
          (s) => '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}',
        ),
      );
    }
    if (_panelShowsNuvio) {
      names.addAll(
        _selectedNuvioStreams.map(
          (s) => '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}',
        ),
      );
    }
    return names;
  }

  Set<String> get _panelAvailableQualities =>
      collectQualities(_panelFilterNames);

  Set<String> get _panelAvailableLanguages =>
      collectLanguages(_panelFilterNames);

  Set<String> get _panelAvailableTech => collectTechTags(_panelFilterNames);

  Set<String> get _panelAvailableSizeRanges {
    final sizes = <double>[];
    if (_panelShowsTorrents) {
      for (final r in _s._allTorrentResults) {
        final bytes = r.sizeInBytes > 0
            ? r.sizeInBytes
            : TorrentReleaseMetadata.parseSizeBytes(r.size);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_panelShowsStremio) {
      for (final s in _s._stremioStreams.whereType<Map<String, dynamic>>()) {
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_panelShowsNuvio) {
      for (final s in _selectedNuvioStreams) {
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    return collectSizeRanges(sizes);
  }

  double _streamSizeBytes(Map<String, dynamic> s) {
    final label = TorrentReleaseMetadata.resolveStreamSizeLabel(s);
    if (label != null) {
      final bytes = TorrentReleaseMetadata.parseSizeBytes(label);
      if (bytes > 0) return bytes;
    }
    final hints = s['behaviorHints'];
    if (hints is Map) {
      final videoSize = hints['videoSize'] ?? hints['video_size'];
      if (videoSize is num && videoSize > 0) return videoSize.toDouble();
      final parsed = double.tryParse(videoSize?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final blob =
        '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''} ${s['size'] ?? ''}';
    return TorrentReleaseMetadata.parseSizeBytes(blob);
  }

  bool _matchesPanelFilters(String name) =>
      TorrentReleaseMetadata.parse(name).matchesFiltersForName(
        name,
        searchQuery: _s._sourceSearchQuery,
        qualityFilters: _s._activeQualityFilters,
        languageFilters: _s._activeLanguageFilters,
        techFilters: _s._activeTechFilters,
        audioFilters: _s._activeAudioFilters,
      );

  bool _matchesPanelStreamFilters(Map<String, dynamic> s) {
    final name = '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}';
    if (!_matchesPanelFilters(name)) return false;
    return TorrentReleaseMetadata.matchesSizeFilters(
      _streamSizeBytes(s),
      _s._activeSizeFilters,
    );
  }

  void _resetPanelFilters() {
    _s._sourceSearchQuery = '';
    _s._activeQualityFilters = {};
    _s._activeLanguageFilters = {};
    _s._activeTechFilters = {};
    _s._activeAudioFilters = {};
    _s._activeSizeFilters = {};
  }

  int? get _panelVisibleCount {
    var count = 0;
    if (_panelShowsTorrents) count += _filteredTorrentResults.length;
    if (_panelShowsStremio) count += _filteredPanelStremioStreams.length;
    if (_panelShowsNuvio) count += _filteredPanelNuvioStreams.length;
    return count;
  }

  bool get _isTorrentSource =>
      _s._selectedSourceId == 'forja' ||
      _s._selectedSourceId == 'jackett' ||
      _s._selectedSourceId == 'prowlarr';

  bool get _isNuvioSource =>
      _s._selectedSourceId == 'all_nuvio' ||
      _s._selectedSourceId.startsWith('nuvio:') ||
      _s._selectedSourceId.startsWith('nuvio://');

  List<SourcesPanelProviderOption> _providerOptions() {
    final options = <SourcesPanelProviderOption>[];
    if (_s._panelKindFilter == 'torrents') {
      options.add(
        const SourcesPanelProviderOption(id: 'forja', label: 'Forja'),
      );
      if (_s._isJackettConfigured) {
        options.add(
          const SourcesPanelProviderOption(id: 'jackett', label: 'Jackett'),
        );
      }
      if (_s._isProwlarrConfigured) {
        options.add(
          const SourcesPanelProviderOption(id: 'prowlarr', label: 'Prowlarr'),
        );
      }
    } else if (_s._panelKindFilter == 'nuvio') {
      options.add(
        const SourcesPanelProviderOption(id: 'all_nuvio', label: 'All'),
      );
      for (final a in _s._nuvioAddons) {
        for (final s in a.scrapers) {
          if (!s.enabled) continue;
          options.add(
            SourcesPanelProviderOption(id: 'nuvio:${s.id}', label: s.name),
          );
        }
      }
    } else if (_s._panelKindFilter == 'stremio') {
      for (final a in _s._streamAddons) {
        final id = a['baseUrl']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        options.add(
          SourcesPanelProviderOption(
            id: id,
            label: (a['name'] ?? 'Addon').toString(),
          ),
        );
      }
    }
    return options;
  }

  bool _nuvioStreamFromScraper(Map<String, dynamic> s, String scraperId) {
    final id = s['_nuvioScraperId'] as String?;
    if (id != null) return id == scraperId;
    final base = s['_addonBaseUrl'] as String?;
    return base == 'nuvio:$scraperId';
  }

  void _onSourceChipTap(String id) {
    if (id == 'all_nuvio') {
      final enabled = enabledNuvioScraperIds(_s._nuvioAddons);
      if (enabled.isEmpty) return;
      final alreadyAll = enabled.every(_s._nuvioSelectedScraperIds.contains);
      if (alreadyAll) return;
      setState(() {
        _s._selectedSourceId = 'all_nuvio';
        _s._errorMessage = null;
        _s._nuvioSelectedScraperIds = Set<String>.from(enabled);
      });
      unawaited(
        NuvioService.instance.saveSourcesSelectedScraperIds(
          _s._nuvioSelectedScraperIds,
        ),
      );
      unawaited(_s._fetchNextNuvioScraper());
      return;
    }
    if (id.startsWith('nuvio:')) {
      final scraperId = id.substring('nuvio:'.length);
      final wasSelected = _s._nuvioSelectedScraperIds.contains(scraperId);
      final cancelInFlight = wasSelected &&
          _s._isNuvioFetching &&
          _s._nuvioInFlightScraperId == scraperId;
      setState(() {
        _s._selectedSourceId = 'all_nuvio';
        _s._errorMessage = null;
        if (wasSelected) {
          _s._nuvioSelectedScraperIds = Set<String>.from(
            _s._nuvioSelectedScraperIds,
          )..remove(scraperId);
          _s._nuvioStreams = _s._nuvioStreams
              .whereType<Map<String, dynamic>>()
              .where((s) => !_nuvioStreamFromScraper(s, scraperId))
              .toList();
          _s._nuvioFetchedScraperIds = Set<String>.from(
            _s._nuvioFetchedScraperIds,
          )..remove(scraperId);
          if (cancelInFlight) {
            _s._nuvioFetchGen++;
            _s._isNuvioFetching = false;
            _s._nuvioInFlightScraperId = null;
            DomainStreamProviderResolver.cancelAllPending(
              cancelEngineJobs: false,
            );
          }
        } else {
          _s._nuvioSelectedScraperIds = {
            ..._s._nuvioSelectedScraperIds,
            scraperId,
          };
        }
      });
      CatalogSourcesSessionCache.writeNuvio(
        _s._catalogCacheKey,
        List<Map<String, dynamic>>.from(_s._nuvioStreams),
        fetchedScraperIds: _s._nuvioFetchedScraperIds,
      );
      unawaited(
        NuvioService.instance.saveSourcesSelectedScraperIds(
          _s._nuvioSelectedScraperIds,
        ),
      );
      if (!wasSelected || cancelInFlight) {
        unawaited(_s._fetchNextNuvioScraper());
      }
      return;
    }
    if (id == _s._selectedSourceId) return;
    setState(() {
      _s._selectedSourceId = id;
      if (_s._panelKindFilter == 'stremio') {
        _s._userPickedStremioProvider = true;
      }
      _resetPanelFilters();
    });
    if (id == 'forja') {
      _s._autoSearch();
    } else if (id == 'jackett') {
      _s._searchJackett();
    } else if (id == 'prowlarr') {
      _s._searchProwlarr();
    } else if (_s._panelKindFilter == 'stremio') {
      setState(() {
        _s._applyStremioFilter();
        // If this addon is empty but another has rows, bounce to the working one
        // instead of a sticky red error that hides the whole list.
        if (_s._stremioStreams.isEmpty &&
            _s._allCombinedStremioStreams.isNotEmpty &&
            !_s._isStremioFetching) {
          _s._userPickedStremioProvider = false;
          _s._syncStremioProviderSelection();
          _s._applyStremioFilter();
          _s._errorMessage = null;
        } else {
          _s._errorMessage =
              _s._stremioStreams.isEmpty && !_s._isStremioFetching
              ? 'No streams found in selected addon'
              : null;
        }
      });
    } else {
      final chip = _providerOptions().firstWhere(
        (c) => c.id == id,
        orElse: () => const SourcesPanelProviderOption(id: '', label: 'addon'),
      );
      setState(() {
        _s._applyStremioFilter();
        _s._errorMessage = _s._stremioStreams.isEmpty && !_s._isStremioFetching
            ? 'No streams found in ${chip.label}'
            : null;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STREAM LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _torrentTileFor(TorrentResult r) {
    double prog = 0;
    var preselected = false;
    if (_s._lastProgress != null && _s._lastProgress!['method'] == 'torrent') {
      if (_s._getHash(r.magnet) == _s._getHash(_s._lastProgress!['sourceId'])) {
        preselected = true;
        final pos = (_s._lastProgress!['position'] != null)
            ? watchHistoryInt(_s._lastProgress!['position'])
            : 0;
        final dur = (_s._lastProgress!['duration'] != null)
            ? watchHistoryInt(_s._lastProgress!['duration'])
            : 0;
        if (dur > 0) {
          prog = (pos / dur).clamp(0.0, 1.0);
        }
      }
    }
    return TorrentSourceTile(
      result: r,
      progress: prog,
      isResumable: preselected,
      highlightStart: widget.startPosition != null,
      onPlay: () => _s._playTorrent(
        r,
        startPosition: preselected
            ? resumeStartPositionFromProgress(_s._lastProgress!)
            : widget.startPosition,
      ),
    );
  }

  Widget _stremioTileFor(
    Map<String, dynamic> s, {
    required bool showAddonName,
  }) {
    final title = s['title'] ?? s['name'] ?? 'Unknown Stream';
    final description = s['description'] ?? '';
    double prog = 0;
    var resumable = false;
    if (_s._lastProgress != null) {
      final String? sid = s['infoHash'] != null
          ? 'magnet:?xt=urn:btih:${s['infoHash']}'
          : s['url'];
      if (sid != null) {
        final hs = _s._lastProgress!['sourceId'] as String;
        final match = s['infoHash'] != null
            ? _s._getHash(hs) == _s._getHash(sid)
            : hs == sid;
        if (match) {
          final pos = watchHistoryInt(_s._lastProgress!['position']);
          final dur = watchHistoryInt(_s._lastProgress!['duration']);
          if (dur > 0) {
            prog = (pos / dur).clamp(0.0, 1.0);
            resumable = true;
          }
        }
      }
    }
    final presentation = stremioTilePresentation(s, isResumable: resumable);
    return StremioSourceTile(
      title: title,
      description: description,
      leadingIcon: presentation.leadingIcon,
      leadingColor: presentation.leadingColor,
      isExternal: presentation.isExternal,
      addonName: s['_addonName']?.toString(),
      showAddonName: showAddonName,
      sizeText: s['size']?.toString(),
      seeders: s['seeders']?.toString() ?? s['seeds']?.toString(),
      stream: s,
      progress: prog,
      isResumable: resumable,
      highlightStart: widget.startPosition != null,
      onTap: () => _s._playStremioStream(
        s,
        startPosition: resumable
            ? Duration(
                milliseconds: watchHistoryInt(_s._lastProgress!['position']),
              )
            : widget.startPosition,
      ),
    );
  }

  Widget _buildStreamList({bool inPanel = false}) {
    final torrents = _panelShowsTorrents
        ? _filteredTorrentResults
        : <TorrentResult>[];
    var stremio = _panelShowsStremio
        ? _filteredPanelStremioStreams
        : <Map<String, dynamic>>[];
    final nuvio = _panelShowsNuvio
        ? _filteredPanelNuvioStreams
        : <Map<String, dynamic>>[];

    // Dead provider selected (Torrentio 403) while another addon has rows —
    // show the working addon's streams and fix selection after this frame.
    if (_panelShowsStremio &&
        stremio.isEmpty &&
        _s._allCombinedStremioStreams.isNotEmpty) {
      final fallbackId = promoteStremioProviderId(
        currentId: _s._selectedSourceId,
        preferredId: null,
        addonBaseUrlsInOrder: _s._stremioAddonBaseUrlsInOrder,
        loadedIds: _s._loadedAddonBaseUrls.isNotEmpty
            ? _s._loadedAddonBaseUrls
            : {
                for (final s in _s._allCombinedStremioStreams)
                  if (s['_addonBaseUrl'] is String) s['_addonBaseUrl'] as String,
              },
        completedIds: _s._completedAddonBaseUrls,
        fetching: _s._isStremioFetching,
        userPicked: false,
      );
      if (fallbackId != null) {
        stremio = _s._allCombinedStremioStreams
            .whereType<Map<String, dynamic>>()
            .where((s) => s['_addonBaseUrl'] == fallbackId)
            .where(_matchesPanelStreamFilters)
            .toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_s._selectedSourceId == fallbackId &&
              _s._errorMessage == null) {
            return;
          }
          setState(() {
            _s._selectedSourceId = fallbackId;
            _s._userPickedStremioProvider = false;
            _s._errorMessage = null;
            _s._applyStremioFilter();
          });
        });
      }
    }

    final count = torrents.length + stremio.length + nuvio.length;
    final rawCount =
        (_panelShowsTorrents ? _s._allTorrentResults.length : 0) +
        (_panelShowsStremio ? _s._allCombinedStremioStreams.length : 0) +
        (_panelShowsNuvio ? _selectedNuvioStreams.length : 0);
    final isFetching =
        (_panelShowsTorrents && _s._isSearching) ||
        (_panelShowsStremio && _s._isStremioFetching) ||
        (_panelShowsNuvio && _s._isNuvioFetching);

    // Never replace a multi-addon result set with a sticky provider error.
    if (_s._errorMessage != null && count == 0 && !isFetching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _s._errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    if (!_s._isSearching && !isFetching && count == 0) {
      String msg;
      if (rawCount > 0 &&
          (_s._sourceSearchQuery.isNotEmpty ||
              _s._activeAudioFilters.isNotEmpty ||
              _s._activeQualityFilters.isNotEmpty ||
              _s._activeLanguageFilters.isNotEmpty ||
              _s._activeTechFilters.isNotEmpty ||
              _s._activeSizeFilters.isNotEmpty)) {
        msg = 'No results match your filters';
      } else if (_panelShowsTorrents &&
          _s._activeAudioFilters.isNotEmpty &&
          _s._allTorrentResults.isNotEmpty) {
        msg = 'No results match the audio filter';
      } else if (_panelShowsNuvio && _s._nuvioSelectedScraperIds.isEmpty) {
        msg = 'Select at least one provider';
      } else if (_panelShowsNuvio &&
          _s._nuvioStreams.isNotEmpty &&
          _selectedNuvioStreams.isEmpty) {
        msg = 'No results match your filters';
      } else {
        msg = 'No streams found';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            msg,
            style: TextStyle(color: ForjaShellColors.cinematic.textSecondary),
          ),
        ),
      );
    }

    final showAddonName =
        _panelShowsNuvio ||
        (_panelShowsStremio && _providerOptions().length > 1);

    return ListView.separated(
      shrinkWrap: !inPanel,
      physics: inPanel
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i < torrents.length) return _torrentTileFor(torrents[i]);
        final j = i - torrents.length;
        if (j < stremio.length) {
          return _stremioTileFor(stremio[j], showAddonName: showAddonName);
        }
        return _stremioTileFor(nuvio[j - stremio.length], showAddonName: true);
      },
    );
  }
}
