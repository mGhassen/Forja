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
      });
    } catch (_) {}
  }
  /// Stops in-flight torrent / Stremio / Nuvio fetches on the details tab.
  void _cancelActiveSourceFetch() {
    var changed = false;
    if (_s._isSearching) {
      _s._torrentSearchGen++;
      _s._isSearching = false;
      changed = true;
    }
    if (_s._isStremioFetching) {
      _s._stremioFetchGen++;
      _s._isStremioFetching = false;
      changed = true;
    }
    if (_s._isNuvioFetching) {
      NuvioService.instance.cancelPending();
      _s._nuvioSub?.cancel();
      _s._nuvioSub = null;
      _s._isNuvioFetching = false;
      changed = true;
    }
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
        stremioId =
            '${stremioId}:${_s._selectedSeason}:${_s._selectedEpisode}';
      final type = _s._movie.mediaType == 'tv' ? 'series' : 'movie';

      int pendingCount = _s._streamAddons.length;

      void completeOne() {
        if (!mounted || gen != _s._stremioFetchGen) return;
        pendingCount--;
        if (pendingCount <= 0) {
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

  /// Runs ONE Nuvio scraper on demand and replaces `_s._nuvioStreams` with its
  /// results. Triggered when the user taps a scraper chip — keeps the
  /// details page snappy by avoiding the parallel-everything fetch.
  Future<void> _runSingleNuvioScraper(String scraperId) async {
    if (_s._movie.id <= 0) return;
    await _s._nuvioSub?.cancel();
    _s._nuvioSub = null;
    setState(() {
      _s._isNuvioFetching = true;
      _s._nuvioStreams = [];
      _s._errorMessage = null;
    });
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    try {
      final results = await NuvioService.instance.runOneScraper(
        scraperId: scraperId,
        tmdbId: _s._movie.id.toString(),
        type: type,
        season: _s._movie.mediaType == 'tv' ? _s._selectedSeason : null,
        episode: _s._movie.mediaType == 'tv' ? _s._selectedEpisode : null,
      );
      if (!mounted) return;
      // Resolve the human-readable scraper name for tagging.
      String scraperName = scraperId;
      for (final a in _s._nuvioAddons) {
        for (final s in a.scrapers) {
          if (s.id == scraperId) {
            scraperName = s.name;
            break;
          }
        }
      }
      setState(() {
        _s._nuvioStreams = results
            .map(
              (r) => <String, dynamic>{
                ...r.toStremioStream(sourceLabel: scraperName),
                '_addonName': scraperName,
                '_addonBaseUrl': 'nuvio:$scraperId',
              },
            )
            .toList();
        _s._isNuvioFetching = false;
        _s._errorMessage = _s._nuvioStreams.isEmpty
            ? 'No streams found from $scraperName'
            : null;
      });
      _s._maybeAutoPlay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _s._isNuvioFetching = false;
        _s._errorMessage = 'Error: $e';
      });
      _s._maybeAutoPlay();
    }
  }

  /// Fetches streams from every enabled Nuvio scraper in parallel and
  /// appends results in real time as each scraper completes — so chips and
  /// streams light up the UI progressively instead of waiting for the
  /// slowest provider. Re-entrant: a fresh call cancels the previous
  /// subscription and resets the visible list.
  Future<void> _fetchAllNuvioStreams() async {
    if (!_s._hasNuvioAddons || _s._movie.id <= 0) return;
    // Tear down any previous in-flight stream — e.g. user switched
    // season/episode mid-fetch.
    await _s._nuvioSub?.cancel();
    _s._nuvioSub = null;
    setState(() {
      _s._isNuvioFetching = true;
      _s._nuvioStreams = [];
      if (_s._selectedSourceId == 'all_nuvio') _s._errorMessage = null;
    });
    final type = _s._movie.mediaType == 'tv' ? 'tv' : 'movie';
    final stream = NuvioService.instance.streamAll(
      tmdbId: _s._movie.id.toString(),
      type: type,
      season: _s._movie.mediaType == 'tv' ? _s._selectedSeason : null,
      episode: _s._movie.mediaType == 'tv' ? _s._selectedEpisode : null,
    );
    _s._nuvioSub = stream.listen(
      (batch) {
        if (!mounted) return;
        if (batch.streams.isEmpty) return; // failed/empty scrapers add nothing
        setState(() {
          _s._nuvioStreams.addAll(
            batch.streams.map(
              (s) => <String, dynamic>{
                ...s,
                '_addonName': s['sourceName'] ?? batch.scraperName,
                '_addonBaseUrl':
                    'nuvio://${s['sourceName'] ?? batch.scraperId}',
              },
            ),
          );
          if (_s._selectedSourceId == 'all_nuvio') _s._errorMessage = null;
        });
      },
      onError: (e) {
        debugPrint('[DetailsScreen] Nuvio stream error: $e');
      },
      onDone: () {
        _s._nuvioSub = null;
        if (!mounted) return;
        setState(() {
          _s._isNuvioFetching = false;
          if (_s._selectedSourceId == 'all_nuvio' && _s._nuvioStreams.isEmpty) {
            _s._errorMessage = 'No streams found from any Nuvio addon';
          }
        });
        _s._maybeAutoPlay();
      },
      cancelOnError: false,
    );
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
      orElse: () =>
          _s._streamAddons.isNotEmpty ? _s._streamAddons.first : <String, dynamic>{},
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
        stremioId =
            '${stremioId}:${_s._selectedSeason}:${_s._selectedEpisode}';
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
