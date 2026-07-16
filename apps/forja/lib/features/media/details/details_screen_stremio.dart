part of 'details_screen.dart';

mixin _DetailsScreenStremio on State<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  Future<void> _checkAndFetchNuvio() async {
    try {
      final addons = await NuvioService.instance.listSourcesPanelAddons();
      if (!mounted) return;
      setState(() {
        _s._hasNuvioAddons = addons.isNotEmpty;
        _s._nuvioAddons = addons;
        // Default Filters → Providers to every enabled scraper as soon as the
        // list is known (before Sources/Filters open), so chips are not empty.
        if (_s._nuvioSelectedScraperIds.isEmpty) {
          _s._selectAllEnabledNuvioScrapers();
        }
      });
    } catch (_) {}
  }

  /// Stops in-flight torrent / Stremio / Nuvio fetches on the details tab.
  ///
  /// When [cancelEngineJobs] is false (closing Sources to start playback),
  /// only bump fetch generations and abort Nuvio — do not cancel engine jobs,
  /// so the magnet resolve that starts next is not aborted.
  void _cancelActiveSourceFetch({bool cancelEngineJobs = true}) {
    final changed =
        _s._isSearching || _s._isStremioFetching || _s._isNuvioFetching;
    _s._torrentSearchGen++;
    _s._stremioFetchGen++;
    _s._nuvioFetchGen++;
    if (cancelEngineJobs) {
      Engine.cancelPendingResolve();
    }
    NuvioService.instance.cancelPending();
    _s._isSearching = false;
    _s._isStremioFetching = false;
    _s._isNuvioFetching = false;
    if (changed && mounted) setState(() {});
  }

  Future<void> _fetchAllStremioStreams() async {
    if (_s._streamAddons.isEmpty) return;
    final gen = ++_s._stremioFetchGen;
    setState(() {
      _s._isStremioFetching = true;
      _s._errorMessage = null;
      _s._allCombinedStremioStreams = [];
      _s._loadedAddonBaseUrls.clear();
      if (_s._selectedSourceId == 'all_stremio') _s._stremioStreams = [];
    });
    try {
      String stremioId = _s._movie.imdbId ?? '';
      if (stremioId.isEmpty) {
        if (mounted && gen == _s._stremioFetchGen) {
          setState(() => _s._isStremioFetching = false);
        }
        return;
      }
      if (_s._movie.mediaType == 'tv')
        stremioId = '${stremioId}:${_s._selectedSeason}:${_s._selectedEpisode}';
      final type = _s._movie.mediaType == 'tv' ? 'series' : 'movie';

      int pendingCount = _s._streamAddons.length;

      void completeOne() {
        if (!mounted || gen != _s._stremioFetchGen) return;
        pendingCount--;
        if (pendingCount <= 0) {
          CatalogSourcesSessionCache.writeStremio(
            _s._catalogCacheKey,
            List<Map<String, dynamic>>.from(_s._allCombinedStremioStreams),
          );
          setState(() {
            _s._isStremioFetching = false;
            if (_s._isTorrentSource) _applyStremioFilter();
            if (_s._allCombinedStremioStreams.isEmpty &&
                _s._selectedSourceId == 'all_stremio') {
              _s._errorMessage = 'No streams found from any addon';
            }
          });
          _s._maybeAutoPlay();
          if (_s._episodePlayPending &&
              !_s._isStremioFetching &&
              _s._allCombinedStremioStreams.isEmpty) {
            _s._failEpisodePlayPending();
          }
        }
      }

      for (final addon in _s._streamAddons) {
        _s._stremio
            .getStreams(baseUrl: addon['baseUrl'], type: type, id: stremioId)
            .then((streams) {
              if (!mounted || gen != _s._stremioFetchGen) return;
              final tagged = _s._filterStremioStreams(
                streams.map((s) {
                  if (s is Map<String, dynamic>) {
                    return <String, dynamic>{
                      ...s,
                      '_addonName': addon['name'] ?? 'Unknown',
                      '_addonBaseUrl': addon['baseUrl'],
                    };
                  }
                  return <String, dynamic>{
                    '_addonName': addon['name'],
                    '_addonBaseUrl': addon['baseUrl'],
                  };
                }).toList(),
              );

              setState(() {
                // Only show chip if addon returned results
                if (tagged.isNotEmpty) {
                  _s._loadedAddonBaseUrls.add(addon['baseUrl'] as String);
                }
                // Append below existing results
                _s._allCombinedStremioStreams.addAll(tagged);
                if (_s._selectedSourceId == 'all_stremio' ||
                    _s._selectedSourceId == addon['baseUrl']) {
                  _applyStremioFilter();
                }
              });
            })
            .catchError((_) {
              // No-op: don't show chip for errored addons
            })
            .whenComplete(() {
              completeOne();
            });
      }
    } catch (e) {
      if (mounted && gen == _s._stremioFetchGen) {
        setState(() {
          _s._errorMessage = 'Error: $e';
          _s._isStremioFetching = false;
        });
      }
    }
  }

  List<String> get _orderedNuvioScraperIds => [
    for (final addon in _s._nuvioAddons)
      for (final scraper in addon.scrapers)
        if (scraper.enabled) scraper.id,
  ];

  List<String> get _pendingNuvioScraperIds => [
    for (final id in _orderedNuvioScraperIds)
      if (_s._nuvioSelectedScraperIds.contains(id) &&
          !_s._nuvioFetchedScraperIds.contains(id))
        id,
  ];

  Future<void> _fetchNextNuvioScraper({bool reset = false}) async {
    if (!_s._hasNuvioAddons || _s._movie.id <= 0) return;
    if (_s._isNuvioFetching && !reset) return;
    if (reset) NuvioService.instance.cancelPending();
    final fetchedIds = reset
        ? <String>{}
        : Set<String>.from(_s._nuvioFetchedScraperIds);
    final scraperId = nextNuvioScraperId(
      orderedIds: _orderedNuvioScraperIds,
      selectedIds: _s._nuvioSelectedScraperIds,
      fetchedIds: fetchedIds,
    );
    if (scraperId == null) return;
    final gen = ++_s._nuvioFetchGen;
    setState(() {
      _s._isNuvioFetching = true;
      if (reset) {
        _s._nuvioStreams = [];
        _s._nuvioFetchedScraperIds = {};
      }
      if (_s._selectedSourceId == 'all_nuvio') _s._errorMessage = null;
    });
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    final batch = await NuvioService.instance.runSourcesScraper(
      scraperId: scraperId,
      tmdbId: _s._movie.id.toString(),
      type: type,
      season: _s._movie.mediaType == 'tv' ? _s._selectedSeason : null,
      episode: _s._movie.mediaType == 'tv' ? _s._selectedEpisode : null,
    );
    if (!mounted || gen != _s._nuvioFetchGen) return;
    if (batch == null) {
      setState(() => _s._isNuvioFetching = false);
      return;
    }
    setState(() {
      _s._nuvioFetchedScraperIds.add(scraperId);
      if (batch.streams.isNotEmpty) {
        _s._nuvioStreams.addAll(
          batch.streams.map(
            (s) => <String, dynamic>{
              ...s,
              '_nuvioScraperId': batch.scraperId,
              '_addonName': s['sourceName'] ?? batch.scraperName,
              '_addonBaseUrl': 'nuvio:${batch.scraperId}',
            },
          ),
        );
      }
      _s._isNuvioFetching = false;
      if (_s._selectedSourceId == 'all_nuvio' &&
          _s._nuvioStreams.isEmpty &&
          _pendingNuvioScraperIds.isEmpty) {
        _s._errorMessage = 'No streams found from selected Nuvio providers';
      }
    });
    CatalogSourcesSessionCache.writeNuvio(
      _s._catalogCacheKey,
      List<Map<String, dynamic>>.from(_s._nuvioStreams),
      fetchedScraperIds: _s._nuvioFetchedScraperIds,
    );
    _s._maybeAutoPlay();
  }

  /// Fetches streams using the custom Stremio ID from the originating addon.
  Future<void> _fetchStremioStreamsForCustomId(
    Map<String, dynamic> item,
  ) async {
    final customId = item['id']?.toString() ?? '';
    final addonBaseUrl = item['_addonBaseUrl']?.toString() ?? '';
    final addonName = item['_addonName']?.toString() ?? 'Unknown';
    final type =
        item['type']?.toString() ??
        (_s._movie.mediaType == 'tv' ? 'series' : 'movie');
    debugPrint(
      '[CustomIdStreams] customId=$customId, addonBaseUrl=$addonBaseUrl, type=$type',
    );
    if (customId.isEmpty || addonBaseUrl.isEmpty) {
      debugPrint(
        '[CustomIdStreams] SKIPPED: customId empty=${customId.isEmpty}, addonBaseUrl empty=${addonBaseUrl.isEmpty}',
      );
      return;
    }

    final gen = ++_s._stremioFetchGen;
    setState(() {
      _s._isStremioFetching = true;
      _s._errorMessage = null;
      _s._stremioStreams = [];
      _s._allCombinedStremioStreams = [];
      _s._loadedAddonBaseUrls.clear();
    });

    try {
      if (type == 'collections') {
        final meta = await _s._stremio.getMeta(
          baseUrl: addonBaseUrl,
          type: type,
          id: customId,
        );
        if (!mounted || gen != _s._stremioFetchGen) return;
        if (meta != null && meta['videos'] != null) {
          final videos = meta['videos'] as List;
          debugPrint(
            '[CustomIdStreams] Got ${videos.length} collection items from meta',
          );

          // Parse videos to build collection structure
          _parseCollectionVideos(videos);

          // Collections don't have streams - they're just containers for other content
          // The UI will display the collection items and allow navigation to them
          if (mounted && gen == _s._stremioFetchGen) {
            setState(() {
              _s._isStremioFetching = false;
              _s._errorMessage = null;
            });
          }
          return;
        }
      }

      if (type == 'series') {
        final meta = await _s._stremio.getMeta(
          baseUrl: addonBaseUrl,
          type: type,
          id: customId,
        );
        if (!mounted || gen != _s._stremioFetchGen) return;
        if (meta != null && meta['videos'] != null) {
          final videos = meta['videos'] as List;
          debugPrint('[CustomIdStreams] Got ${videos.length} videos from meta');

          // Parse videos to build season/episode structure
          _parseCustomIdVideos(videos);

          // Now fetch streams for the selected episode
          final selectedVideo = _getSelectedVideoFromCustomId(videos);
          if (selectedVideo != null) {
            final videoId = selectedVideo['id']?.toString() ?? '';
            debugPrint(
              '[CustomIdStreams] Fetching streams for video: $videoId',
            );
            final streams = await _s._stremio.getStreams(
              baseUrl: addonBaseUrl,
              type: type,
              id: videoId,
            );
            debugPrint('[CustomIdStreams] Got ${streams.length} streams');

            if (!mounted || gen != _s._stremioFetchGen) return;
            final tagged = _s._filterStremioStreams(
              streams.map((s) {
                if (s is Map<String, dynamic>) {
                  return <String, dynamic>{
                    ...s,
                    '_addonName': addonName,
                    '_addonBaseUrl': addonBaseUrl,
                  };
                }
                return <String, dynamic>{
                  '_addonName': addonName,
                  '_addonBaseUrl': addonBaseUrl,
                };
              }).toList(),
            );
            setState(() {
              _s._stremioStreams = tagged;
              _s._allCombinedStremioStreams = tagged;
              _s._loadedAddonBaseUrls.add(addonBaseUrl);
              _s._isStremioFetching = false;
              if (streams.isEmpty) _s._errorMessage = 'No streams found';
            });
            return;
          }
        }
      }

      final streams = await _s._stremio.getStreams(
        baseUrl: addonBaseUrl,
        type: type,
        id: customId,
      );
      debugPrint('[CustomIdStreams] Got ${streams.length} streams');
      if (streams.isNotEmpty)
        debugPrint('[CustomIdStreams] First stream: ${streams.first}');
      if (!mounted || gen != _s._stremioFetchGen) return;
      final tagged = _s._filterStremioStreams(
        streams.map((s) {
          if (s is Map<String, dynamic>) {
            return <String, dynamic>{
              ...s,
              '_addonName': addonName,
              '_addonBaseUrl': addonBaseUrl,
            };
          }
          return <String, dynamic>{
            '_addonName': addonName,
            '_addonBaseUrl': addonBaseUrl,
          };
        }).toList(),
      );
      setState(() {
        _s._stremioStreams = tagged;
        _s._allCombinedStremioStreams = tagged;
        _s._loadedAddonBaseUrls.add(addonBaseUrl);
        _s._isStremioFetching = false;
        if (streams.isEmpty) _s._errorMessage = 'No streams found';
      });
    } catch (e) {
      if (mounted && gen == _s._stremioFetchGen) {
        setState(() {
          _s._errorMessage = 'Error: $e';
          _s._isStremioFetching = false;
          _s._loadedAddonBaseUrls.add(addonBaseUrl);
        });
      }
    }
  }

  /// Parses the videos array from custom ID meta to build season/episode structure
  void _parseCustomIdVideos(List videos) {
    if (videos.isEmpty) return;

    // Build a map of seasons to episodes
    final Map<int, List<Map<String, dynamic>>> seasonMap = {};
    for (final video in videos) {
      if (video is! Map) continue;
      final season = video['season'] as int? ?? 1;
      final episode = video['episode'] as int? ?? 1;

      seasonMap.putIfAbsent(season, () => []);
      seasonMap[season]!.add({
        'id': video['id'],
        'title': video['title'] ?? 'Episode $episode',
        'episode': episode,
        'season': season,
        'thumbnail': video['thumbnail'],
        'released': video['released'],
      });
    }

    // Sort episodes within each season
    for (final episodes in seasonMap.values) {
      episodes.sort(
        (a, b) => (a['episode'] as int).compareTo(b['episode'] as int),
      );
    }

    // Store in _s._seasonData format compatible with existing UI
    if (mounted) {
      setState(() {
        _s._seasonData = {
          'seasons': seasonMap.keys.toList()..sort(),
          'episodesBySeason': seasonMap,
        };
        // Ensure selected season/episode are valid
        if (!seasonMap.containsKey(_s._selectedSeason)) {
          _s._selectedSeason = seasonMap.keys.first;
        }
        final episodes = seasonMap[_s._selectedSeason] ?? [];
        if (episodes.isEmpty || _s._selectedEpisode > episodes.length) {
          _s._selectedEpisode = episodes.isNotEmpty
              ? episodes.first['episode']
              : 1;
        }
      });
    }
  }

  /// Parses the videos array from collection meta to build collection items list
  void _parseCollectionVideos(List videos) {
    if (videos.isEmpty) return;

    final List<Map<String, dynamic>> items = [];
    for (final video in videos) {
      if (video is! Map) continue;

      items.add({
        'id': video['id'],
        'title': video['title'] ?? 'Unknown',
        'thumbnail': video['thumbnail'],
        'released': video['released'],
        'ratings': video['ratings'],
        'overview': video['overview'],
      });
    }

    if (mounted) {
      setState(() {
        _s._collectionItems = items;
        _s._isCollection = true;
      });
    }
  }

  /// Gets the selected video from the custom ID videos array
  Map<String, dynamic>? _getSelectedVideoFromCustomId(List videos) {
    for (final video in videos) {
      if (video is! Map) continue;
      final season = video['season'] as int? ?? 1;
      final episode = video['episode'] as int? ?? 1;
      if (season == _s._selectedSeason && episode == _s._selectedEpisode) {
        return video as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Fetches streams from a single selected addon only.
  Future<void> _fetchStremioStreams() async {
    if (_s._selectedSourceId == 'all_stremio') {
      // "All" chip → just re-filter from cached results, or re-fetch if empty
      if (_s._allCombinedStremioStreams.isEmpty) {
        return _fetchAllStremioStreams();
      }
      setState(() {
        _s._stremioStreams = _s._allCombinedStremioStreams;
        _s._errorMessage = null;
      });
      return;
    }
    final addon = _s._streamAddons.firstWhere(
      (a) => a['baseUrl'] == _s._selectedSourceId,
      orElse: () => _s._streamAddons.isNotEmpty
          ? _s._streamAddons.first
          : <String, dynamic>{},
    );
    if (addon.isEmpty) return;
    final gen = ++_s._stremioFetchGen;
    setState(() {
      _s._isStremioFetching = true;
      _s._errorMessage = null;
      _s._stremioStreams = [];
    });
    try {
      String stremioId = _s._movie.imdbId ?? '';
      if (_s._movie.mediaType == 'tv')
        stremioId = '${stremioId}:${_s._selectedSeason}:${_s._selectedEpisode}';
      final type = _s._movie.mediaType == 'tv' ? 'series' : 'movie';
      final streams = await _s._stremio.getStreams(
        baseUrl: addon['baseUrl'],
        type: type,
        id: stremioId,
      );
      if (!mounted || gen != _s._stremioFetchGen) return;
      setState(() {
        _s._stremioStreams = _s._filterStremioStreams(streams);
        if (streams.isEmpty)
          _s._errorMessage = 'No streams found in ${addon['name']}';
      });
    } catch (e) {
      if (!mounted || gen != _s._stremioFetchGen) return;
      setState(() => _s._errorMessage = 'Error: $e');
    } finally {
      if (mounted && gen == _s._stremioFetchGen) {
        setState(() => _s._isStremioFetching = false);
        _s._maybeAutoPlay();
        if (_s._episodePlayPending && _s._stremioStreams.isEmpty) {
          _s._failEpisodePlayPending();
        }
      }
    }
  }

  /// Applies the current addon filter chip to _s._allCombinedStremioStreams.
  void _applyStremioFilter() {
    if (_s._selectedSourceId == 'all_stremio' || _s._isTorrentSource) {
      _s._stremioStreams = _s._allCombinedStremioStreams;
    } else {
      _s._stremioStreams = _s._allCombinedStremioStreams
          .where((s) => s['_addonBaseUrl'] == _s._selectedSourceId)
          .toList();
    }
  }
}
