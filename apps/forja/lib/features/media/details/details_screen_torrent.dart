part of 'details_screen.dart';

mixin _DetailsScreenTorrent on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  Future<void> _checkIndexerConfiguration() async {
    final jackettConfigured = await _s._settings.isJackettConfigured();
    final prowlarrConfigured = await _s._settings.isProwlarrConfigured();
    final enabled = await _s._settings.getEnabledTorrentProviders();
    if (mounted) {
      setState(() {
        _s._isJackettConfigured = jackettConfigured;
        _s._isProwlarrConfigured = prowlarrConfigured;
        _s._enabledTorrentProviders = enabled;
      });
    }
  }

  String _getHash(String magnet) {
    if (magnet.startsWith('magnet:?xt=urn:btih:')) {
      final parts = magnet.split('magnet:?xt=urn:btih:')[1].split('&');
      if (parts.isNotEmpty) return parts[0].toLowerCase();
    }
    return magnet.toLowerCase();
  }

  TorrentResult? _historyMatchedTorrent() {
    final progress = _s._lastProgress;
    if (progress?['method'] != 'torrent') return null;
    final sourceId = progress!['sourceId'];
    if (sourceId == null) return null;
    final historyHash = _getHash(sourceId);
    for (final result in _s._allTorrentResults) {
      if (_getHash(result.magnet) == historyHash) return result;
    }
    return null;
  }

  Future<void> _sortResults() async {
    if (_s._allTorrentResults.isEmpty) {
      CatalogSourcesSessionCache.writeTorrents(
        _s._catalogCacheKey,
        _s._allTorrentResults,
      );
      _s._maybeAutoPlay();
      return;
    }
    final sorted = (await Engine.sortTorrents(
      _s._allTorrentResults.map((e) => e.toJson()).toList(),
      _s._sortPreference,
    )).map(TorrentResult.fromJson).toList();
    if (_s._lastProgress != null && _s._lastProgress!['method'] == 'torrent') {
      final historyHash = _getHash(_s._lastProgress!['sourceId']);
      final index = sorted.indexWhere((r) => _getHash(r.magnet) == historyHash);
      if (index != -1) {
        final match = sorted.removeAt(index);
        sorted.insert(0, match);
      }
    }
    if (mounted) setState(() => _s._allTorrentResults = sorted);
    CatalogSourcesSessionCache.writeTorrents(
      _s._catalogCacheKey,
      _s._allTorrentResults,
    );
    _s._maybeAutoPlay();
  }
  Future<void> _searchTvTorrents(
    String seasonQuery,
    String episodeQuery,
  ) async {
    final gen = ++_s._torrentSearchGen;
    _s.ref
        .read(detailsResolveStatusProvider(_s._metaKey).notifier)
        .setLoading();
    setState(() {
      _s._isSearching = true;
      _s._allTorrentResults = [];
      _s._errorMessage = null;
    });
    try {
      final results = await Future.wait([
        Engine.searchTorrents(
          seasonQuery,
          imdbId: _s._movie.imdbId,
          season: _s._selectedSeason,
        ).then((list) => list.map(TorrentResult.fromJson).toList()),
        Engine.searchTorrents(
          episodeQuery,
          imdbId: _s._movie.imdbId,
          season: _s._selectedSeason,
          episode: _s._selectedEpisode,
        ).then((list) => list.map(TorrentResult.fromJson).toList()),
      ]);
      if (!mounted || gen != _s._torrentSearchGen) return;
      final filteredSeason = (await Engine.filterTorrents(
        results[0].map((e) => e.toJson()).toList(),
        _s._movie.title,
        requiredSeason: _s._selectedSeason,
      )).map(TorrentResult.fromJson).toList();
      if (!mounted || gen != _s._torrentSearchGen) return;
      final filteredEpisode = (await Engine.filterTorrents(
        results[1].map((e) => e.toJson()).toList(),
        _s._movie.title,
        requiredSeason: _s._selectedSeason,
        requiredEpisode: _s._selectedEpisode,
      )).map(TorrentResult.fromJson).toList();
      final combined = <String, TorrentResult>{};
      for (var r in filteredEpisode) {
        combined[r.magnet] = r;
      }
      for (var r in filteredSeason) {
        combined[r.magnet] = r;
      }
      if (!mounted || gen != _s._torrentSearchGen) return;
      setState(() {
        _s._allTorrentResults = combined.values.toList();
        _s._isSearching = false;
      });
      _s.ref
          .read(detailsResolveStatusProvider(_s._metaKey).notifier)
          .setReady();
      _sortResults();
    } catch (e) {
      if (mounted && gen == _s._torrentSearchGen) {
        setState(() {
          _s._errorMessage = e.toString();
          _s._isSearching = false;
        });
        _s.ref
            .read(detailsResolveStatusProvider(_s._metaKey).notifier)
            .setError();
        _s._maybeAutoPlay();
      }
    }
  }

  Future<void> _searchTorrents(String query) async {
    final gen = ++_s._torrentSearchGen;
    _s.ref
        .read(detailsResolveStatusProvider(_s._metaKey).notifier)
        .setLoading();
    setState(() {
      _s._isSearching = true;
      _s._allTorrentResults = [];
      _s._errorMessage = null;
    });
    try {
      final results = (await Engine.searchTorrents(
        query,
        imdbId: _s._movie.imdbId,
      )).map(TorrentResult.fromJson).toList();
      if (!mounted || gen != _s._torrentSearchGen) return;
      final filtered = (await Engine.filterTorrents(
        results.map((e) => e.toJson()).toList(),
        _s._movie.title,
      )).map(TorrentResult.fromJson).toList();
      if (!mounted || gen != _s._torrentSearchGen) return;
      setState(() {
        _s._allTorrentResults = filtered;
        _s._isSearching = false;
      });
      _s.ref
          .read(detailsResolveStatusProvider(_s._metaKey).notifier)
          .setReady();
      _sortResults();
    } catch (e) {
      if (mounted && gen == _s._torrentSearchGen) {
        setState(() {
          _s._errorMessage = e.toString();
          _s._isSearching = false;
        });
        _s.ref
            .read(detailsResolveStatusProvider(_s._metaKey).notifier)
            .setError();
        _s._maybeAutoPlay();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Jackett Search
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _searchJackett() async {
    if (!_s._isJackettConfigured) {
      if (mounted) {
        ForjaToast.info(
          'Jackett is not configured. Go to Settings to add your Base URL and API Key.',
        );
      }
      return;
    }

    final gen = ++_s._torrentSearchGen;
    setState(() {
      _s._isSearching = true;
      _s._allTorrentResults = [];
      _s._errorMessage = null;
    });

    try {
      final baseUrl = await _s._settings.getJackettBaseUrl();
      final apiKey = await _s._settings.getJackettApiKey();
      if (!mounted || gen != _s._torrentSearchGen) return;

      if (baseUrl == null || apiKey == null)
        throw Exception('Jackett configuration missing');

      if (_s._movie.mediaType == 'tv') {
        final s = _s._selectedSeason.toString().padLeft(2, '0');
        final e = _s._selectedEpisode.toString().padLeft(2, '0');
        final results = await Future.wait([
          _s._jackett.search(baseUrl, apiKey, '${_s._movie.title} S$s'),
          _s._jackett.search(baseUrl, apiKey, '${_s._movie.title} S${s}E$e'),
        ]);
        if (!mounted || gen != _s._torrentSearchGen) return;
        final filteredSeason = (await Engine.filterTorrents(
          results[0].map((e) => e.toJson()).toList(),
          _s._movie.title,
          requiredSeason: _s._selectedSeason,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _s._torrentSearchGen) return;
        final filteredEpisode = (await Engine.filterTorrents(
          results[1].map((e) => e.toJson()).toList(),
          _s._movie.title,
          requiredSeason: _s._selectedSeason,
          requiredEpisode: _s._selectedEpisode,
        )).map(TorrentResult.fromJson).toList();
        final combined = <String, TorrentResult>{};
        for (var r in filteredEpisode) {
          combined[r.magnet] = r;
        }
        for (var r in filteredSeason) {
          combined[r.magnet] = r;
        }
        if (!mounted || gen != _s._torrentSearchGen) return;
        if (combined.isEmpty) {
          setState(() {
            _s._errorMessage =
                'No results found for "S${s}E$e". Try checking your configured indexers in Jackett.';
            _s._isSearching = false;
          });
          _s._maybeAutoPlay();
        } else {
          setState(() {
            _s._allTorrentResults = combined.values.toList();
            _s._isSearching = false;
          });
          _sortResults();
        }
      } else {
        final year = _s._movie.releaseDate.length >= 4
            ? _s._movie.releaseDate.substring(0, 4)
            : '';
        final query = year.isNotEmpty ? '${_s._movie.title} $year' : _s._movie.title;
        final results = await _s._jackett.search(baseUrl, apiKey, query);
        if (!mounted || gen != _s._torrentSearchGen) return;
        final filtered = (await Engine.filterTorrents(
          results.map((e) => e.toJson()).toList(),
          _s._movie.title,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _s._torrentSearchGen) return;
        if (filtered.isEmpty) {
          setState(() {
            _s._errorMessage =
                'No results found for "$query". Try checking your configured indexers in Jackett.';
            _s._isSearching = false;
          });
          _s._maybeAutoPlay();
        } else {
          setState(() {
            _s._allTorrentResults = filtered;
            _s._isSearching = false;
          });
          _sortResults();
        }
      }
    } catch (e) {
      if (mounted && gen == _s._torrentSearchGen) {
        setState(() {
          _s._errorMessage = e.toString();
          _s._isSearching = false;
        });
        _s._maybeAutoPlay();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Prowlarr Search
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _searchProwlarr() async {
    if (!_s._isProwlarrConfigured) {
      if (mounted) {
        ForjaToast.info(
          'Prowlarr is not configured. Go to Settings to add your Base URL and API Key.',
        );
      }
      return;
    }

    final gen = ++_s._torrentSearchGen;
    setState(() {
      _s._isSearching = true;
      _s._allTorrentResults = [];
      _s._errorMessage = null;
    });

    try {
      final baseUrl = await _s._settings.getProwlarrBaseUrl();
      final apiKey = await _s._settings.getProwlarrApiKey();
      if (!mounted || gen != _s._torrentSearchGen) return;

      if (baseUrl == null || apiKey == null)
        throw Exception('Prowlarr configuration missing');

      final tagIds = await _s._settings.getProwlarrTagIds();
      if (!mounted || gen != _s._torrentSearchGen) return;
      List<int>? allowedIndexerIds;
      if (tagIds.isNotEmpty) {
        final resolved = await _s._prowlarr.resolveTagIndexerIds(
          baseUrl,
          apiKey,
          tagIds,
        );
        if (!mounted || gen != _s._torrentSearchGen) return;
        if (resolved.isNotEmpty) allowedIndexerIds = resolved;
      }

      if (_s._movie.mediaType == 'tv') {
        final s = _s._selectedSeason.toString().padLeft(2, '0');
        final e = _s._selectedEpisode.toString().padLeft(2, '0');
        final results = await Future.wait([
          _s._prowlarr.search(
            baseUrl,
            apiKey,
            '${_s._movie.title} S$s',
            indexerIds: allowedIndexerIds,
          ),
          _s._prowlarr.search(
            baseUrl,
            apiKey,
            '${_s._movie.title} S${s}E$e',
            indexerIds: allowedIndexerIds,
          ),
        ]);
        if (!mounted || gen != _s._torrentSearchGen) return;
        final filteredSeason = (await Engine.filterTorrents(
          results[0].map((e) => e.toJson()).toList(),
          _s._movie.title,
          requiredSeason: _s._selectedSeason,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _s._torrentSearchGen) return;
        final filteredEpisode = (await Engine.filterTorrents(
          results[1].map((e) => e.toJson()).toList(),
          _s._movie.title,
          requiredSeason: _s._selectedSeason,
          requiredEpisode: _s._selectedEpisode,
        )).map(TorrentResult.fromJson).toList();
        final combined = <String, TorrentResult>{};
        for (var r in filteredEpisode) {
          combined[r.magnet] = r;
        }
        for (var r in filteredSeason) {
          combined[r.magnet] = r;
        }
        if (!mounted || gen != _s._torrentSearchGen) return;
        if (combined.isEmpty) {
          setState(() {
            _s._errorMessage =
                'No results found for "S${s}E$e". Try checking your configured indexers in Prowlarr.';
            _s._isSearching = false;
          });
          _s._maybeAutoPlay();
        } else {
          setState(() {
            _s._allTorrentResults = combined.values.toList();
            _s._isSearching = false;
          });
          _sortResults();
        }
      } else {
        final year = _s._movie.releaseDate.length >= 4
            ? _s._movie.releaseDate.substring(0, 4)
            : '';
        final query = year.isNotEmpty ? '${_s._movie.title} $year' : _s._movie.title;
        final results = await _s._prowlarr.search(
          baseUrl,
          apiKey,
          query,
          indexerIds: allowedIndexerIds,
        );
        if (!mounted || gen != _s._torrentSearchGen) return;
        final filtered = (await Engine.filterTorrents(
          results.map((e) => e.toJson()).toList(),
          _s._movie.title,
        )).map(TorrentResult.fromJson).toList();
        if (!mounted || gen != _s._torrentSearchGen) return;
        if (filtered.isEmpty) {
          setState(() {
            _s._errorMessage =
                'No results found for "$query". Try checking your configured indexers in Prowlarr.';
            _s._isSearching = false;
          });
          _s._maybeAutoPlay();
        } else {
          setState(() {
            _s._allTorrentResults = filtered;
            _s._isSearching = false;
          });
          _sortResults();
        }
      }
    } catch (e) {
      if (mounted && gen == _s._torrentSearchGen) {
        setState(() {
          _s._errorMessage = e.toString();
          _s._isSearching = false;
        });
        _s._maybeAutoPlay();
      }
    }
  }
}
