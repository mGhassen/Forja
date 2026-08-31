part of 'desktop_player_screen.dart';

mixin _DesktopPlayerTracks
    on
        ConsumerState<DesktopPlayerScreen>,
        WidgetsBindingObserver,
        WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBTITLE MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  //  ONLINE SUBTITLE LOADER (download → temp file → SubtitleTrack.uri)
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _loadOnlineSubtitle(
    Map<String, dynamic> s, {
    bool userInitiated = false,
    bool showFailureToast = true,
  }) async {
    if (userInitiated) {
      _s._userPickedExternalSubtitle = true;
      _s._embeddedSubtitleAutoApplied = true;
    }
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return false;
    final isTranslated =
        s['translated'] == true || url.contains('/subtitlecat-translate');

    Future<bool> applyUri(String uri) async {
      if (_s._disposed || !mounted) return false;
      try {
        await preparePlayerExternalSubtitleSwitch(_s._player);
        final track = SubtitleTrack.uri(
          uri,
          title: s['display']?.toString(),
          language: s['language']?.toString(),
        );
        await _s._player.setSubtitleTrack(track);
        if (_s._disposed || !mounted) return false;
        _s._updateSubVisibility(track);
        if (mounted) setState(() => _s._selectedExternalSubUrl = url);
        return true;
      } catch (e) {
        debugPrint('[DesktopPlayer] subtitle apply failed: $e');
        return false;
      }
    }

    void fail() {
      if (!mounted) return;
      setState(() => _s._selectedExternalSubUrl = null);
      if (showFailureToast) {
        _s._statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
      }
    }

    // Reuse a previously downloaded file (media open often wipes the track).
    final cached = _s._externalSubFileCache[url];
    if (cached != null) {
      if (await externalSubtitleCacheFileValid(cached)) {
        try {
          if (await applyUri(cached)) return true;
        } catch (e) {
          debugPrint('[DesktopPlayer] cached subtitle re-apply failed: $e');
        }
        _s._externalSubFileCache.remove(url);
        await deleteExternalSubtitleCacheFile(cached);
      } else {
        _s._externalSubFileCache.remove(url);
        await deleteExternalSubtitleCacheFile(cached);
      }
    }

    // Already-local subtitle (e.g. provider-inlined plaintext) - feed straight to libmpv.
    if (url.startsWith('file://') || url.startsWith('/')) {
      try {
        final uri = url.startsWith('file://') ? url : Uri.file(url).toString();
        if (!await externalSubtitleCacheFileValid(uri)) {
          fail();
          return false;
        }
        _s._externalSubFileCache[url] = uri;
        return await applyUri(uri);
      } catch (e) {
        fail();
        return false;
      }
    }

    // Provider-supplied plaintext (e.g. KissKh Sub API decrypted in pack JS).
    if (hasInlineSubtitleContent(s)) {
      try {
        final local = await materializeInlineSubtitleFile(s);
        if (local == null || !await externalSubtitleCacheFileValid(local)) {
          fail();
          return false;
        }
        final cacheKey = url.isNotEmpty ? url : local;
        final prior = _s._externalSubFileCache[cacheKey];
        if (prior != null && prior != local) {
          await deleteExternalSubtitleCacheFile(prior);
        }
        _s._externalSubFileCache[cacheKey] = local;
        return await applyUri(local);
      } catch (e) {
        debugPrint('[DesktopPlayer] inline subtitle materialize failed: $e');
        fail();
        return false;
      }
    }

    try {
      // Many subtitle CDNs (megacloud, vid-cdn, lostproject.club, etc.) gate
      // on a browser UA and the embed-host Referer (NOT the sub URL's own
      // host). Prefer the referer/origin the extractor passed through;
      // otherwise fall back to the sub URL's own origin.
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
      if (!mounted) return false;
      if (res.statusCode != 200) {
        fail();
        return false;
      }
      if (!isPlausibleSubtitleBytes(res.bodyBytes)) {
        debugPrint(
          '[DesktopPlayer] subtitle download rejected (invalid payload)',
        );
        fail();
        return false;
      }
      final dir = await getTemporaryDirectory();
      final safeLang = (s['language'] ?? 'sub').toString().replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final file = File(
        '${dir.path}/forja_sub_${DateTime.now().millisecondsSinceEpoch}_$safeLang.srt',
      );
      await file.writeAsBytes(res.bodyBytes);
      final uri = Uri.file(file.path).toString();
      final prior = _s._externalSubFileCache[url];
      if (prior != null && prior != uri) {
        await deleteExternalSubtitleCacheFile(prior);
      }
      _s._externalSubFileCache[url] = uri;
      return await applyUri(uri);
    } catch (e) {
      fail();
      return false;
    }
  }

  Future<bool> _autoLoadExternalSubtitleCandidates(
    List<Map<String, dynamic>> candidates, {
    bool forcePlayerApply = false,
  }) async {
    if (candidates.isEmpty) return false;
    for (var i = 0; i < candidates.length; i++) {
      final s = candidates[i];
      debugPrint(
        '[DesktopPlayer] auto subtitle → ${s['display'] ?? s['language']}'
        '${forcePlayerApply ? ' (re-apply)' : ''}'
        '${i > 0 ? ' (fallback ${i + 1}/${candidates.length})' : ''}',
      );
      if (await _loadOnlineSubtitle(
        s,
        showFailureToast: i == candidates.length - 1,
      )) {
        return true;
      }
    }
    return false;
  }

  Future<void> _fetchSubtitles() async {
    // Pre-populate with Jellyfin / hub-provided subtitles if present.
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
          _maybeAutoPickExternalSubtitle();
        }
      },
      onError: (e) {
        debugPrint('Subtitle fetch error: $e');
        if (mounted) setState(() => _s._isFetchingSubs = false);
      },
      onDone: () {
        if (mounted) setState(() => _s._isFetchingSubs = false);
        _maybeAutoPickExternalSubtitle();
      },
    );

    // Prefer widget-provided tracks immediately (e.g. Videasy extract).
    if (jellyfinSubs.isNotEmpty) {
      await _maybeAutoPickExternalSubtitle();
    }
  }

  bool _playerHasActiveSubtitle() {
    final id = _s._player.state.track.subtitle.id;
    return id != 'no' && id != 'auto' && id.isNotEmpty;
  }

  bool _activeSubtitleMatchesPreferred(String preferred) {
    final current = _s._player.state.track.subtitle;
    if (!_playerHasActiveSubtitle()) return false;
    for (final lang in subtitleLanguageCandidates(preferred)) {
      if (matchesPreferredLanguage(
        lang,
        language: current.language,
        title: current.title,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Re-apply after media open / track settle - mpv clears external URI tracks.
  Future<void> _reapplyPreferredSubtitle() async {
    if (_s._disposed || !mounted) return;
    await _s._applyAutoSubtitle();
    if (_s._disposed || !mounted) return;
    // Only re-attach a sideloaded file if we were actually on one. In-stream
    // remount must not invent a Levrx apply while mux tracks are still empty.
    final restoreExternal = _s._userPickedExternalSubtitle ||
        _s._selectedExternalSubUrl != null;
    await _maybeAutoPickExternalSubtitle(forcePlayerApply: restoreExternal);
  }

  /// Applies [SettingsService.getPreferredSubtitleLanguage] when external
  /// tracks arrive. Preferred first; English if that category is missing.
  Future<void> _maybeAutoPickExternalSubtitle({
    bool forcePlayerApply = false,
  }) async {
    if (_s._disposed || !mounted) return;

    final preferred = await SettingsService().getPreferredSubtitleLanguage();
    if (_s._disposed || !mounted) return;
    if (preferred == 'None' || preferred.isEmpty) return;

    // Seed provider URLs from the playable stream before online scrapers merge.
    if (_s._providerExternalSubUrls.isEmpty &&
        (widget.externalSubtitles ?? const []).isNotEmpty) {
      _s._providerExternalSubUrls = providerExternalSubtitleUrls(
        widget.externalSubtitles!,
      );
    }

    // Provider-attached (KissKh /api/Sub, …) beat HLS mux — CDN in-stream is
    // often mistimed vs the site player.
    if (!_s._userPickedExternalSubtitle &&
        _s._providerExternalSubUrls.isNotEmpty) {
      final providerOnly = providerAttachedSubtitles(
        all: _s._externalSubtitles.isNotEmpty
            ? _s._externalSubtitles
            : List<Map<String, dynamic>>.from(widget.externalSubtitles ?? const []),
        providerUrls: _s._providerExternalSubUrls,
      );
      final providerCandidates = externalSubtitleAutoCandidates(
        preferredLang: preferred,
        subs: providerOnly,
        preferUrlFirst: forcePlayerApply ? _s._selectedExternalSubUrl : null,
      );
      if (providerCandidates.isNotEmpty) {
        if (await _autoLoadExternalSubtitleCandidates(
          providerCandidates,
          forcePlayerApply: forcePlayerApply,
        )) {
          return;
        }
      }
    }

    if (!_s._userPickedExternalSubtitle) {
      final embedded =
          embeddedSubtitleTracks(_s._player.state.tracks.subtitle);
      if (embedded.isNotEmpty) {
        await _s._applyAutoSubtitle();
        if (_s._disposed || !mounted) return;
        if (_s._selectedExternalSubUrl == null && _playerHasActiveSubtitle()) {
          return;
        }
      }
    }

    // In-stream wins when it matches settings — do not replace with scraped subs.
    if (!_s._userPickedExternalSubtitle &&
        _s._selectedExternalSubUrl == null &&
        _playerHasActiveSubtitle() &&
        _activeSubtitleMatchesPreferred(preferred)) {
      return;
    }

    // Remount with in-stream selected: mux list may still be empty. Do not
    // fill that gap with Levrx — late embedded auto will pick when tracks land.
    if (forcePlayerApply &&
        !_s._userPickedExternalSubtitle &&
        _s._selectedExternalSubUrl == null) {
      return;
    }

    if (_activeSubtitleMatchesPreferred(preferred) &&
        _s._selectedExternalSubUrl != null &&
        !forcePlayerApply) {
      return;
    }

    final subsForAuto = externalSubtitlesForAutoPick(
      all: _s._externalSubtitles,
      providerUrls: _s._providerExternalSubUrls,
      restrictScraped: restrictScrapedSubtitleAutoPick(
        mediaType: widget.movie?.mediaType,
        engineCategory: widget.movie != null && widget.enginePlaySession != null
            ? engineCategoryForSession(
                widget.enginePlaySession,
                widget.movie!,
              )
            : null,
      ),
    );

    final uiSelected = _s._selectedExternalSubUrl;
    if (uiSelected != null && !forcePlayerApply) {
      if (_playerHasActiveSubtitle()) return;
      await _autoLoadExternalSubtitleCandidates(
        externalSubtitleAutoCandidates(
          preferredLang: preferred,
          subs: subsForAuto,
          preferUrlFirst: uiSelected,
        ),
      );
      return;
    }

    await _autoLoadExternalSubtitleCandidates(
      externalSubtitleAutoCandidates(
        preferredLang: preferred,
        subs: subsForAuto,
        preferUrlFirst: forcePlayerApply ? uiSelected : null,
      ),
      forcePlayerApply: forcePlayerApply,
    );
  }

  void _showSubtitlesMenu(BuildContext anchorContext) {
    PlayerSubtitleMenu.show(
      context,
      player: _s._player,
      anchorContext: anchorContext,
      externalSubtitles: _s._externalSubtitles,
      selectedExternalSubUrl: _s._selectedExternalSubUrl,
      isFetchingSubs: _s._isFetchingSubs,
      updateSubVisibility: _s._updateSubVisibility,
      onExternalUrlChanged: (url) => setState(() {
        _s._selectedExternalSubUrl = url;
        if (url == null) _s._userPickedExternalSubtitle = false;
      }),
      onNativeSubtitleChanged: (v) => setState(() => _s._isNativeSubtitle = v),
      loadOnlineSubtitle: (s) => _loadOnlineSubtitle(s, userInitiated: true),
      onSubtitleSettings: _showSubtitleSettings,
      onSubtitleSelected:
          ({required bool off, String? language, String? title}) {
            _s._embeddedSubtitleAutoApplied = true;
            if (off) _s._userPickedExternalSubtitle = false;
            unawaited(
              _rememberSubtitlePreference(
                off: off,
                language: language,
                title: title,
              ),
            );
          },
    );
  }

  Future<void> _rememberSubtitlePreference({
    required bool off,
    String? language,
    String? title,
  }) async {
    final settings = SettingsService();
    if (off) {
      await settings.setPreferredSubtitleLanguage('None');
      await settings.setPlayerAutoSubtitle(false);
      if (mounted) setState(() => _s._subtitlePinned = true);
      return;
    }
    final resolved = resolvePreferredLanguageDisplayName(
      language: language,
      title: title,
    );
    if (resolved == null) return;
    await settings.setPreferredSubtitleLanguage(resolved);
  }

  void _showSubtitleSettings() {
    PlayerSubtitleSettingsDialog.show(
      context,
      initial: PlayerSubtitleSettingsValues(
        size: _s._subtitleSize,
        delay: _s._subtitleDelay,
        color: _s._subtitleColor,
        bgOpacity: _s._subtitleBgOpacity,
        bottomPadding: _s._subtitleBottomPadding,
        bold: _s._subtitleBold,
        font: _s._subtitleFont,
      ),
      player: _s._player,
      onChanged: (values) {
        setState(() {
          _s._subtitleSize = values.size;
          _s._subtitleDelay = values.delay;
          _s._subtitleColor = values.color;
          _s._subtitleBgOpacity = values.bgOpacity;
          _s._subtitleBottomPadding = values.bottomPadding;
          _s._subtitleBold = values.bold;
          _s._subtitleFont = values.font;
        });
      },
    );
  }

  Future<void> _loadSubtitlePrefs() async {
    final prefs = await ref.read(playerSubtitlePrefsProvider(true).future);
    if (mounted) {
      setState(() {
        _s._subtitleSize = prefs.size;
        _s._subtitleColor = Color(prefs.colorArgb);
        _s._subtitleBgOpacity = prefs.bgOpacity;
        _s._subtitleBold = prefs.bold;
        _s._subtitleBottomPadding = prefs.bottomPadding;
        _s._subtitleFont = prefs.font;
      });
    }
  }

  Future<void> _loadTorrentStatsPref() async {
    final show = await SettingsService().getShowTorrentStatsOverlay();
    if (!mounted) return;
    setState(() => _s._showTorrentStatsOverlay = show);
    _syncTorrentStatsSubscription();
  }

  void _syncTorrentStatsSubscription() {
    _s._torrentStatsSub?.cancel();
    _s._torrentStatsSub = null;
    final magnet = widget.magnetLink;
    if (!_s._showTorrentStatsOverlay || magnet == null || magnet.isEmpty) {
      if (_s._torrentStats != null && mounted) {
        setState(() => _s._torrentStats = null);
      } else {
        _s._torrentStats = null;
      }
      return;
    }
    _s._torrentStatsSub = TorrentStreamService().statsStream(magnet).listen((
      stats,
    ) {
      if (!mounted) return;
      setState(() => _s._torrentStats = stats);
    });
  }

  TextStyle _buildSubtitleTextStyle({double scale = 1.0}) {
    final base = TextStyle(
      height: 1.4,
      fontSize: _s._subtitleSize * scale,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
      color: _s._subtitleColor,
      fontWeight: _s._subtitleBold ? FontWeight.bold : FontWeight.normal,
      backgroundColor: Colors.black.withValues(alpha: _s._subtitleBgOpacity),
      shadows: [
        Shadow(
          blurRadius: 10 * scale,
          color: Colors.black,
          offset: Offset.zero,
        ),
      ],
    );
    if (_s._subtitleFont == 'Default') return base;
    final fontMap = <String, TextStyle Function({TextStyle? textStyle})>{
      'Poppins': GoogleFonts.poppins,
      'Roboto': GoogleFonts.roboto,
      'Roboto Mono': GoogleFonts.robotoMono,
      'Montserrat': GoogleFonts.montserrat,
      'Open Sans': GoogleFonts.openSans,
      'Lato': GoogleFonts.lato,
    };
    final fn = fontMap[_s._subtitleFont];
    if (fn != null) return fn(textStyle: base);
    return base;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  AUDIO
  // ─────────────────────────────────────────────────────────────────────────

  void _showAudioMenu(BuildContext anchorContext) {
    PlayerAudioMenu.show(
      context,
      player: _s._player,
      onTrackSelected: () async {
        await SettingsService().setPlayerAutoAudio(false);
        setState(() {
          _s._audioPinned = true;
          _s._userPickedAudioThisSource = true;
        });
      },
      anchorContext: anchorContext,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HLS QUALITY SELECTOR
  // ─────────────────────────────────────────────────────────────────────────

  /// Probe [url] as a master HLS playlist. Populates the quality notifier
  /// when 2+ variants are present, otherwise clears it (hiding the gear).
  void _detectHlsQualities(String url, Map<String, String>? headers) {
    _s._currentQualityUrl = url;
    if (!url.contains('.m3u8')) {
      _s._hlsMasterUrl = null;
      _s._hlsMasterHeaders = null;
      _s._hlsQualitiesNotifier.value = null;
      return;
    }
    final existing = _s._hlsQualitiesNotifier.value;
    if (existing != null && existing.any((q) => q.url == url)) return;

    final resolved = resolvePlaybackHttpHeaders(
      headers,
      streamUrl: url,
      providerId: _s._currentProvider,
    );
    _s._hlsMasterUrl = url;
    _s._hlsMasterHeaders = resolved;
    _s._hlsQualitiesNotifier.value = null;
    fetchHlsQualities(url, headers: resolved).then((qs) {
      if (_s._disposed) return;
      if (_s._hlsMasterUrl != url) return;
      _s._hlsQualitiesNotifier.value = qs;
    });
  }

  void _showQualityMenu(BuildContext anchorContext) {
    final qs = _s._hlsQualitiesNotifier.value ?? const <HlsQuality>[];
    PlayerQualityMenu.show(
      context,
      qualities: qs,
      currentQualityUrl: _s._currentQualityUrl,
      masterUrl: _s._hlsMasterUrl,
      playerState: _s._player.state,
      playbackQualityLabel: playbackQualityLabel(_s._player.state),
      playbackQualityDetail: playbackQualityDetail(_s._player.state),
      onSelect: _switchQuality,
      anchorContext: anchorContext,
    );
  }

  Future<void> _switchQuality(HlsQuality q) async {
    final pos = _s._positionNotifier.value;
    final switchGen = ++_s._fallbackGen;
    _s._isInitPlaybackRunning = true;
    _s._currentQualityUrl = q.url;
    if (mounted) {
      setState(() {
        _s._hasError = false;
      });
    }
    try {
      await openPlayerStream(
        _s._player,
        url: q.url,
        headers: _s._hlsMasterHeaders,
        startAt: pos.inSeconds > 0 ? pos : null,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      final opened = await waitForPlayerStreamOpen(
        _s._player,
        streamUrl: q.url,
        headers: _s._hlsMasterHeaders,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (!opened) {
        debugPrint('[Player] HLS quality switch failed to open: ${q.url}');
        return;
      }
      if (pos.inSeconds > 0) {
        await ensureOpenedNearPosition(
          _s._player,
          pos,
          skipNearCredits: false,
          streamUrl: q.url,
          openedWithMpvStart: true,
        );
      }
    } finally {
      if (switchGen == _s._fallbackGen) {
        _s._isInitPlaybackRunning = false;
      }
    }
    if (mounted && switchGen == _s._fallbackGen) {
      _s._onMouseMove();
    }
  }
}
