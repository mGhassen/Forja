part of 'exo_player_screen.dart';

mixin _ExoPlayerTracks on ConsumerState<ExoPlayerScreen> {
  _ExoPlayerScreenState get _s => this as _ExoPlayerScreenState;

  /// Download (or reuse cache) → local `file://` → soft-reload Media3 sideloads.
  ///
  /// [manual] is a user pick from the menu: it shows a loading / done chip and
  /// outranks any auto pick still downloading. An auto pick that finishes
  /// after a newer pick started is dropped.
  Future<void> _loadOnlineSubtitle(
    Map<String, dynamic> s, {
    bool manual = true,
  }) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return;
    final label = (s['display'] ?? s['language'] ?? s['lang'] ?? 'Subtitle')
        .toString();
    if (!manual &&
        _s._subtitlePickManual &&
        (_s._subtitlePickInFlight || _s._selectedExternalSubUrl != null)) {
      debugPrint('[ExoPlayer] subtitle auto pick skipped: manual pick owns it');
      return;
    }
    final gen = ++_s._subtitlePickGen;
    _s._subtitlePickManual = manual;
    _s._subtitlePickInFlight = true;
    debugPrint(
      '[ExoPlayer] subtitle pick${manual ? '' : ' (auto)'} → $label  $url',
    );
    try {
      await _runOnlineSubtitlePick(
        s,
        url: url,
        label: label,
        manual: manual,
        gen: gen,
      );
    } finally {
      if (gen == _s._subtitlePickGen) _s._subtitlePickInFlight = false;
    }
  }

  Future<void> _runOnlineSubtitlePick(
    Map<String, dynamic> s, {
    required String url,
    required String label,
    required bool manual,
    required int gen,
  }) async {
    if (manual) {
      _s._statusController.upsert(
        'subtitle',
        label,
        kind: StatusRouletteKind.loading,
      );
    }
    final sw = Stopwatch()..start();

    // Already attached and reported by Media3: a plain track switch, no
    // media reload.
    final attached = exoTextTrackForSideload(_s._tracks.text, url);
    if (attached != null &&
        _s._sideloadedSubtitles.any((e) => e['sourceUrl'] == url)) {
      _s._selectedExternalSubUrl = url;
      _s._preferredSubtitleApplied = true;
      debugPrint('[ExoPlayer] subtitle: attached, select ${attached.id}');
      await ExoPlayerBridge.selectTrack(
        _s._viewId,
        type: 'text',
        trackId: attached.id,
      );
      if (!mounted) return;
      if (manual) {
        _s._statusController.upsert(
          'subtitle',
          label,
          kind: StatusRouletteKind.success,
          dismissAfter: const Duration(milliseconds: 1500),
        );
      }
      setState(() {});
      return;
    }

    final prepared = await _prepareSubtitleSideload(s);
    if (_s._disposed || !mounted) return;
    if (gen != _s._subtitlePickGen) {
      debugPrint('[ExoPlayer] subtitle pick superseded: $url');
      return;
    }
    if (prepared == null) {
      debugPrint(
        '[ExoPlayer] subtitle pick failed after ${sw.elapsedMilliseconds} ms: '
        '$url',
      );
      // Auto may fall through to Wyzie — don't flash failed first.
      if (manual) {
        _s._statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
      }
      return;
    }
    debugPrint(
      '[ExoPlayer] subtitle ready in ${sw.elapsedMilliseconds} ms → '
      '${prepared['url']}',
    );

    // Keep other already-sideloaded tracks so the menu still lists them.
    final next = mergeSideloads(_s._sideloadedSubtitles, [prepared]);
    _s._sideloadedSubtitles = next;
    _s._selectedExternalSubUrl = url;
    // Soft-reload remounts MergingMediaPeriod — wait for next READY before
    // auto-select (issue 132).
    _s._exoReady = false;
    _s._preferredSubtitleApplied = false;

    try {
      debugPrint('[ExoPlayer] subtitle: setSubtitles n=${next.length}');
      final accepted = await ExoPlayerBridge.setSubtitles(
        _s._viewId,
        exoSideloadPayloads(next),
      );
      if (!mounted) return;
      if (accepted == 0) {
        throw StateError('player attached 0 of ${next.length} sideloads');
      }
      if (manual) {
        _s._statusController.upsert(
          'subtitle',
          label,
          kind: StatusRouletteKind.success,
          dismissAfter: const Duration(milliseconds: 1500),
        );
      }
      setState(() {});
    } catch (e) {
      debugPrint('[ExoPlayer] setSubtitles failed: $e');
      if (!mounted) return;
      // No reload happened (or it carried nothing): the player is still the
      // READY one from before, so auto-pick and late attach stay alive.
      _s._exoReady = true;
      setState(() => _s._selectedExternalSubUrl = null);
      if (manual) {
        _s._statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<Map<String, String>?> _prepareSubtitleSideload(
    Map<String, dynamic> s,
  ) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return null;
    final lang = (s['lang'] ?? s['language'] ?? 'und').toString();
    final label = (s['display'] ?? s['language'] ?? s['lang'] ?? lang)
        .toString();

    // Content sniff sets Media3 mime — URL/path extension is often wrong
    // (Wyzie/CDN extensionless VTT saved as `.srt` → empty cues).
    Future<Map<String, String>?> pack(String fileUri) async {
      final mime = await externalSubtitleMimeForFileUri(fileUri);
      if (mime == null) {
        debugPrint(
          '[ExoPlayer] subtitle sideload skipped (unsupported or unreadable): '
          '$fileUri',
        );
        return null;
      }
      return {
        'url': fileUri,
        'lang': lang,
        'label': label,
        'sourceUrl': url,
        'mime': mime,
      };
    }

    final cached = _s._externalSubFileCache[url];
    if (cached != null) {
      if (await externalSubtitleCacheFileValid(cached)) {
        final prepared = await pack(cached);
        if (prepared != null) return prepared;
      }
      _s._externalSubFileCache.remove(url);
      await deleteExternalSubtitleCacheFile(cached);
    }

    if (url.startsWith('file://') || url.startsWith('/')) {
      final uri = url.startsWith('file://') ? url : Uri.file(url).toString();
      _s._externalSubFileCache[url] = uri;
      return pack(uri);
    }

    // HLS TYPE=SUBTITLES / In-stream — merge playlist → local VTT (issue 507).
    // Do not pass raw `.m3u8` to Media3 as SubRip/VTT.
    if (exoSideloadNeedsHlsMaterialize(url: url, row: s)) {
      final playbackHeaders = _s._sources.isNotEmpty
          ? _s._sources[_s._sourceIndex].headers
          : widget.headers;
      // Keep Cookie/Referer from the play path (MediaKit parity).
      final headers = hlsInStreamRequestHeaders(
        streamHeaders: playbackHeaders,
        playbackHeaders: playbackHeaders,
      );
      try {
        final fileUri = await materializeHlsInStreamSubtitleFile(
          HlsInStreamSubtitle(language: lang, name: label, uri: url),
          headers: (headers == null || headers.isEmpty) ? null : headers,
        );
        if (fileUri == null) return null;
        _s._externalSubFileCache[url] = fileUri;
        return pack(fileUri);
      } catch (e) {
        debugPrint('[ExoPlayer] HLS in-stream materialize failed: $e');
        return null;
      }
    }

    if (hasInlineSubtitleContent(s)) {
      try {
        final local = await materializeInlineSubtitleFile(s);
        if (local == null) return null;
        final cacheKey = url.isNotEmpty ? url : local;
        final prior = _s._externalSubFileCache[cacheKey];
        if (prior != null && prior != local) {
          await deleteExternalSubtitleCacheFile(prior);
        }
        _s._externalSubFileCache[cacheKey] = local;
        return pack(local);
      } catch (e) {
        debugPrint('[ExoPlayer] inline subtitle materialize failed: $e');
        return null;
      }
    }

    try {
      final isTranslated =
          s['translated'] == true || url.contains('/subtitlecat-translate');
      final subUri = Uri.parse(url);
      final playbackHeaders = _s._sources.isNotEmpty
          ? _s._sources[_s._sourceIndex].headers
          : widget.headers;
      final headers = subtitleDownloadHttpHeaders(
        subtitleUrl: url,
        subtitleRow: s,
        playbackHeaders: playbackHeaders,
      );
      final sw = Stopwatch()..start();
      final res = await http
          .get(subUri, headers: headers)
          .timeout(Duration(minutes: isTranslated ? 5 : 1));
      if (res.statusCode != 200) {
        debugPrint(
          '[ExoPlayer] subtitle download HTTP ${res.statusCode} after '
          '${sw.elapsedMilliseconds} ms: $url',
        );
        return null;
      }
      if (!isPlausibleSubtitleBytes(res.bodyBytes)) {
        debugPrint(
          '[ExoPlayer] subtitle download rejected (invalid payload, '
          '${res.bodyBytes.length} B): $url',
        );
        return null;
      }
      debugPrint(
        '[ExoPlayer] subtitle downloaded ${res.bodyBytes.length} B in '
        '${sw.elapsedMilliseconds} ms: $url',
      );

      final dir = await getTemporaryDirectory();
      final safeLang = lang.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final body = stripSubtitlePromoCues(res.bodyBytes);
      final ext = externalSubtitleFileExtension(body);
      if (externalSubtitleMimeForExtension(ext) == null) {
        debugPrint(
          '[ExoPlayer] subtitle download skipped (Exo cannot paint $ext): $url',
        );
        return null;
      }
      final file = File(
        '${dir.path}/forja_exo_sub_${DateTime.now().millisecondsSinceEpoch}_$safeLang.$ext',
      );
      await file.writeAsBytes(body);
      final uri = Uri.file(file.path).toString();
      _s._externalSubFileCache[url] = uri;
      return pack(uri);
    } catch (e) {
      debugPrint('[ExoPlayer] subtitle download failed: $e  $url');
      return null;
    }
  }

  /// Downloads every sideload at once; one slow host no longer serialises
  /// the rest. Failed rows are dropped, order is preserved.
  Future<List<Map<String, String>>> _prepareOpenSubtitles(
    List<Map<String, dynamic>> raw,
  ) async {
    final results = await Future.wait([
      for (final s in raw) _prepareSubtitleSideload(s),
    ]);
    return [for (final prepared in results) ?prepared];
  }

  /// Sources switch: seed this row's provider `subtitles` (see desktop).
  void _applyProviderSubtitlesFromStream(Map<String, dynamic> stream) {
    final merged = mergeStreamProviderSubtitles(
      currentExternal: _s._externalSubtitles,
      previousProviderUrls: _s._providerExternalSubUrls,
      stream: stream,
    );
    if (!mounted) return;
    setState(() {
      _s._selectedExternalSubUrl = null;
      _s._providerExternalSubUrls = merged.providerUrls;
      _s._externalSubtitles = merged.external;
    });
    debugPrint(
      '[ExoPlayer] provider subtitle apply n=${merged.providerUrls.length}',
    );
    unawaited(_maybeAutoPickExternalSubtitle());
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

    // Offline download: keep saved / provider rows; do not hit Wyzie/Levrx/addons.
    if (_s._playingOfflineDownload) {
      await _maybeAutoPickExternalSubtitle();
      return;
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
          setState(
            () => _s._externalSubtitles = [
              ...jellyfinSubs,
              ...tagOnlineSubtitleRows(subs),
            ],
          );
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
    if (_s._subtitlePinned) return;
    // Soft-reload (setSubtitles) before READY races MergingMediaPeriod (issue 132).
    if (!_s._exoReady) return;
    final preferred = await SettingsService().getPreferredSubtitleLanguage();
    if (_s._disposed || !mounted || _s._preferredSubtitleApplied) return;
    if (preferred == 'None' || preferred.isEmpty) return;

    if (_s._providerExternalSubUrls.isEmpty &&
        (widget.externalSubtitles ?? const []).isNotEmpty) {
      _s._providerExternalSubUrls = providerExternalSubtitleUrls(
        widget.externalSubtitles!,
      );
    }

    // Manual pick from the subtitle dialog — do not override with auto-pick.
    final manualUrl = _s._selectedExternalSubUrl;
    if (manualUrl != null &&
        _s._sideloadedSubtitles.any((e) => e['sourceUrl'] == manualUrl)) {
      _s._preferredSubtitleApplied = true;
      return;
    }

    // Provider-attached (KissKh /api/Sub) beat HLS mux mistiming.
    if (_s._providerExternalSubUrls.isNotEmpty) {
      final providerOnly = providerAttachedSubtitles(
        all: _s._externalSubtitles.isNotEmpty
            ? _s._externalSubtitles
            : List<Map<String, dynamic>>.from(
                widget.externalSubtitles ?? const [],
              ),
        providerUrls: _s._providerExternalSubUrls,
      );
      final pick = pickExternalSubtitleWithFallback(preferred, providerOnly);
      if (pick != null) {
        final pickUrl = pick['url']?.toString();
        if (pickUrl != null && pickUrl == _s._selectedExternalSubUrl) {
          _s._preferredSubtitleApplied = true;
          return;
        }
        await _loadOnlineSubtitle(pick, manual: false);
        return;
      }
    }

    // Language-tagged in-stream tracks win — `_maybeApplyPreferredSubtitle`
    // owns selection. Anonymous CEA-608 ("CC 1" / "Track 1") must not block
    // Wyzie/Levrx — those often emit empty cues on VOD HLS (issue 230).
    final hasUsableMux = _s._tracks.text.any((t) {
      if (t.isAnonymousClosedCaption) return false;
      return matchesPreferredLanguage(
            preferred,
            language: t.language,
            title: t.label,
          ) ||
          matchesPreferredLanguage(
            'English',
            language: t.language,
            title: t.label,
          );
    });
    if (hasUsableMux) return;

    // HLS TYPE=SUBTITLES — materialize + sideload before Wyzie (MediaKit
    // parity; Exo used to only "wait for Media3" and never attached).
    if (await _applyPreferredHlsInStreamSubtitle(preferred)) return;

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
        engineCategory: widget.movie != null && widget.enginePlaySession != null
            ? engineCategoryForSession(widget.enginePlaySession, widget.movie!)
            : null,
      ),
    );

    final pick = pickExternalSubtitleWithFallback(preferred, subsForAuto);
    if (pick == null) return;
    final pickUrl = pick['url']?.toString();
    if (pickUrl != null && pickUrl == _s._selectedExternalSubUrl) {
      _s._preferredSubtitleApplied = true;
      return;
    }

    await _loadOnlineSubtitle(pick, manual: false);
  }

  /// Playlist has preferred language → merge to VTT and sideload (issue 507).
  Future<bool> _applyPreferredHlsInStreamSubtitle(String preferred) async {
    final playUrl = _s._currentUrl ?? widget.mediaPath;
    final headers = _s._sources.isNotEmpty
        ? _s._sources[_s._sourceIndex].headers
        : widget.headers;
    final pick = await preferredHlsInStreamSubtitle(
      playUrl: playUrl,
      headers: headers,
      preferredLang: preferred,
    );
    if (pick == null || _s._disposed || !mounted) return false;
    final row = hlsInStreamSubtitleRows([pick]).first;
    final pickUrl = row['url']?.toString();
    if (pickUrl != null &&
        pickUrl == _s._selectedExternalSubUrl &&
        _s._sideloadedSubtitles.any((e) => e['sourceUrl'] == pickUrl)) {
      _s._preferredSubtitleApplied = true;
      return true;
    }
    await _loadOnlineSubtitle(row, manual: false);
    if (_s._disposed || !mounted) return true;
    // Materialize failed → fall through to Wyzie/Levrx.
    return pickUrl != null && pickUrl == _s._selectedExternalSubUrl;
  }

  Future<void> _turnOffSubtitles() async {
    _s._selectedExternalSubUrl = null;
    _s._preferredSubtitleApplied = true;
    _s._cueTexts.value = const [];
    await SettingsService().setPreferredSubtitleLanguage('None');
    await ExoPlayerBridge.selectTrack(_s._viewId, type: 'text', trackId: null);
    if (mounted) setState(() {});
  }

  /// After [ExoPlayerBridge.setSubtitles], select the Media3 text track made
  /// from the picked sideload. Exact match on the sideload id Media3 echoes
  /// as `Format.id`; waits for the next tracks report when it is not there
  /// yet. Language / label is only a fallback for a native build that does
  /// not report format ids.
  ///
  /// [tracksFresh] is true from the tracks report that follows a reload; only
  /// then can a missing sideload be called a failure (native READY arrives
  /// before the new track list).
  Future<void> _selectSideloadedMatchingSelection({
    bool tracksFresh = false,
  }) async {
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
    final text = _s._tracks.text;
    if (sideload == null || text.isEmpty) {
      debugPrint(
        '[ExoPlayer] subtitle select: waiting '
        '(sideload=${sideload != null} textTracks=${text.length})',
      );
      return;
    }
    var match = exoTextTrackForSideload(text, sourceUrl);
    if (match == null) {
      final idsReported = text.any((t) => t.formatId.isNotEmpty);
      if (idsReported) {
        if (tracksFresh && _s._exoReady) {
          // READY came back without this sideload: Media3 dropped it. Say so
          // instead of leaving the row checked with no cues.
          debugPrint(
            '[ExoPlayer] subtitle select: sideload missing after reload '
            '(ids=${text.map((t) => t.formatId).join(',')})',
          );
          _s._selectedExternalSubUrl = null;
          _s._statusController.upsert(
            'subtitle',
            'Subtitle failed',
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
          if (mounted) setState(() {});
          return;
        }
        // The reload has not surfaced this sideload yet — tracksChanged
        // re-enters here.
        debugPrint('[ExoPlayer] subtitle select: track not reported yet');
        return;
      }
      final lang = sideload['lang'] ?? '';
      final label = sideload['label'] ?? '';
      for (final t in text) {
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
      match ??= text.last;
    }
    if (match.selected && !_s._tracks.textOff) return;
    debugPrint(
      '[ExoPlayer] subtitle select → ${match.id} '
      '(${match.label}, formatId=${match.formatId})',
    );
    await ExoPlayerBridge.selectTrack(
      _s._viewId,
      type: 'text',
      trackId: match.id,
    );
  }
}
