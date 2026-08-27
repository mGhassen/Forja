part of 'exo_player_screen.dart';

mixin _ExoPlayerTracks on ConsumerState<ExoPlayerScreen> {
  _ExoPlayerScreenState get _s => this as _ExoPlayerScreenState;

  /// Download (or reuse cache) → local `file://` → soft-reload Media3 sideloads.
  Future<void> _loadOnlineSubtitle(Map<String, dynamic> s) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return;

    final prepared = await _prepareSubtitleSideload(s);
    if (prepared == null) {
      if (!mounted) return;
      _s._statusController.upsert(
        'subtitle',
        'Subtitle failed',
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      return;
    }

    // Keep other already-sideloaded tracks so the menu still lists them.
    final next = <Map<String, String>>[
      for (final e in _s._sideloadedSubtitles)
        if (e['sourceUrl'] != url) e,
      prepared,
    ];
    _s._sideloadedSubtitles = next;
    _s._selectedExternalSubUrl = url;
    // Soft-reload remounts MergingMediaPeriod — wait for next READY before
    // auto-select (issue 132).
    _s._exoReady = false;
    _s._preferredSubtitleApplied = false;

    try {
      await ExoPlayerBridge.setSubtitles(
        _s._viewId,
        next
            .map(
              (e) => {
                'url': e['url']!,
                'lang': e['lang'] ?? 'und',
                'label': e['label'] ?? e['lang'] ?? 'und',
              },
            )
            .toList(),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[ExoPlayer] setSubtitles failed: $e');
      if (!mounted) return;
      setState(() => _s._selectedExternalSubUrl = null);
      _s._statusController.upsert(
        'subtitle',
        'Subtitle failed',
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    }
  }

  /// Maps a provider/online subtitle entry to a Media3 sideload payload.
  /// Returns null on download failure. Keys: `url` (file://), `lang`, `label`,
  /// `sourceUrl` (original remote/local key for selection UI).
  Future<Map<String, String>?> _prepareSubtitleSideload(
    Map<String, dynamic> s,
  ) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return null;
    final lang = (s['lang'] ?? s['language'] ?? 'und').toString();
    final label = (s['display'] ?? s['language'] ?? s['lang'] ?? lang)
        .toString();

    Future<Map<String, String>> pack(String fileUri) async => {
          'url': fileUri,
          'lang': lang,
          'label': label,
          'sourceUrl': url,
        };

    final cached = _s._externalSubFileCache[url];
    if (cached != null) return pack(cached);

    if (url.startsWith('file://') || url.startsWith('/')) {
      final uri = url.startsWith('file://') ? url : Uri.file(url).toString();
      _s._externalSubFileCache[url] = uri;
      return pack(uri);
    }

    try {
      final isTranslated =
          s['translated'] == true || url.contains('/subtitlecat-translate');
      final subUri = Uri.parse(url);
      final selfOrigin = '${subUri.scheme}://${subUri.host}';
      final ref = (s['referer'] as String?)?.trim();
      final org = (s['origin'] as String?)?.trim();
      final headers = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Referer': (ref != null && ref.isNotEmpty) ? ref : '$selfOrigin/',
        'Origin': (org != null && org.isNotEmpty) ? org : selfOrigin,
      };
      final res = await http
          .get(subUri, headers: headers)
          .timeout(Duration(minutes: isTranslated ? 5 : 1));
      if (res.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final safeLang = lang.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final lowerPath = subUri.path.toLowerCase();
      final ext = lowerPath.endsWith('.vtt')
          ? 'vtt'
          : lowerPath.endsWith('.srt')
              ? 'srt'
              : 'srt';
      final file = File(
        '${dir.path}/forja_exo_sub_${DateTime.now().millisecondsSinceEpoch}_$safeLang.$ext',
      );
      await file.writeAsBytes(res.bodyBytes);
      final uri = Uri.file(file.path).toString();
      _s._externalSubFileCache[url] = uri;
      return pack(uri);
    } catch (e) {
      debugPrint('[ExoPlayer] subtitle download failed: $e');
      return null;
    }
  }

  Future<List<Map<String, String>>> _prepareOpenSubtitles(
    List<Map<String, dynamic>> raw,
  ) async {
    final out = <Map<String, String>>[];
    for (final s in raw) {
      final prepared = await _prepareSubtitleSideload(s);
      if (prepared != null) out.add(prepared);
    }
    return out;
  }

  Future<void> _fetchSubtitles() async {
    final jellyfinSubs = widget.externalSubtitles ?? [];
    _s._providerExternalSubUrls = providerExternalSubtitleUrls(jellyfinSubs);
    if (jellyfinSubs.isNotEmpty) {
      if (mounted) {
        setState(
          () => _s._externalSubtitles = List<Map<String, dynamic>>.from(
            jellyfinSubs,
          ),
        );
      }
    }

    final movie = widget.movie;
    final title = movie?.title.trim() ?? '';
    final tmdbId = (movie != null && movie.id > 0) ? movie.id : 0;
    if (tmdbId <= 0 && title.isEmpty) {
      await _maybeAutoPickExternalSubtitle();
      return;
    }
    if (mounted) setState(() => _s._isFetchingSubs = true);

    final release = movie?.releaseDate ?? '';
    final stream = SubtitleApi.fetchSubtitlesStream(
      tmdbId: tmdbId,
      imdbId: movie?.imdbId,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      title: title.isEmpty ? null : title,
      year: release.length >= 4 ? int.tryParse(release.substring(0, 4)) : null,
    );

    stream.listen(
      (subs) {
        if (mounted) {
          setState(() => _s._externalSubtitles = [...jellyfinSubs, ...subs]);
          unawaited(_maybeAutoPickExternalSubtitle());
        }
      },
      onError: (e) {
        debugPrint('[ExoPlayer] subtitle fetch error: $e');
        if (mounted) setState(() => _s._isFetchingSubs = false);
      },
      onDone: () {
        if (mounted) setState(() => _s._isFetchingSubs = false);
        unawaited(_maybeAutoPickExternalSubtitle());
      },
    );

    if (jellyfinSubs.isNotEmpty) {
      await _maybeAutoPickExternalSubtitle();
    }
  }

  Future<void> _maybeAutoPickExternalSubtitle() async {
    if (_s._disposed || !mounted || _s._preferredSubtitleApplied) return;
    // Soft-reload (setSubtitles) before READY races MergingMediaPeriod (issue 132).
    if (!_s._exoReady) return;
    final preferred = await SettingsService().getPreferredSubtitleLanguage();
    if (_s._disposed || !mounted || _s._preferredSubtitleApplied) return;
    if (preferred == 'None' || preferred.isEmpty) return;

    // Manual pick from the subtitle dialog — do not override with auto-pick.
    final manualUrl = _s._selectedExternalSubUrl;
    if (manualUrl != null &&
        _s._sideloadedSubtitles.any((e) => e['sourceUrl'] == manualUrl)) {
      _s._preferredSubtitleApplied = true;
      return;
    }

    // Already on a matching Media3 text track (embedded or previous sideload).
    if (_s._tracks.text.any(
          (t) =>
              !_s._tracks.textOff &&
              t.selected &&
              matchesPreferredLanguage(
                preferred,
                language: t.language,
                title: t.label,
              ),
        )) {
      _s._preferredSubtitleApplied = true;
      return;
    }

    final subsForAuto = externalSubtitlesForAutoPick(
      all: _s._externalSubtitles,
      providerUrls: _s._providerExternalSubUrls,
      restrictScraped: restrictScrapedSubtitleAutoPick(
        mediaType: widget.movie?.mediaType,
        engineCategory: widget.enginePlaySession?.category,
      ),
    );

    final pick = pickExternalSubtitleWithFallback(
      preferred,
      subsForAuto,
    );
    if (pick == null) return;
    final pickUrl = pick['url']?.toString();
    if (pickUrl != null && pickUrl == _s._selectedExternalSubUrl) {
      _s._preferredSubtitleApplied = true;
      return;
    }

    debugPrint(
      '[ExoPlayer] auto external subtitle → ${pick['display'] ?? pick['language']}',
    );
    await _loadOnlineSubtitle(pick);
  }

  Future<void> _turnOffSubtitles() async {
    _s._selectedExternalSubUrl = null;
    _s._preferredSubtitleApplied = true;
    await SettingsService().setPreferredSubtitleLanguage('None');
    await ExoPlayerBridge.selectTrack(
      _s._viewId,
      type: 'text',
      trackId: null,
    );
    if (mounted) setState(() {});
  }

  /// After [ExoPlayerBridge.setSubtitles], pick the Media3 text track that
  /// matches the last external selection (by language/label).
  Future<void> _selectSideloadedMatchingSelection() async {
    if (_s._disposed || !mounted) return;
    final sourceUrl = _s._selectedExternalSubUrl;
    if (sourceUrl == null) return;
    Map<String, String>? sideload;
    for (final e in _s._sideloadedSubtitles) {
      if (e['sourceUrl'] == sourceUrl) {
        sideload = e;
        break;
      }
    }
    if (sideload == null || _s._tracks.text.isEmpty) return;
    final lang = sideload['lang'] ?? '';
    final label = sideload['label'] ?? '';
    ExoTrackInfo? match;
    for (final t in _s._tracks.text) {
      if ((lang.isNotEmpty &&
              matchesPreferredLanguage(
                lang,
                language: t.language,
                title: t.label,
              )) ||
          (label.isNotEmpty &&
              t.label.toLowerCase() == label.toLowerCase())) {
        match = t;
        break;
      }
    }
    match ??= _s._tracks.text.last;
    if (match.selected && !_s._tracks.textOff) return;
    await ExoPlayerBridge.selectTrack(
      _s._viewId,
      type: 'text',
      trackId: match.id,
    );
  }
}
