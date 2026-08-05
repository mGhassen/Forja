part of 'mobile_player_screen.dart';

mixin _MobilePlayerTracks on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBTITLES
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  //  ONLINE SUBTITLE LOADER (download → temp file → SubtitleTrack.uri)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadOnlineSubtitle(Map<String, dynamic> s) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return;
    final isTranslated =
        s['translated'] == true || url.contains('/subtitlecat-translate');

    Future<void> applyUri(String uri) async {
      if (_s._disposed || !mounted) return;
      final track = SubtitleTrack.uri(
        uri,
        title: s['display'],
        language: s['language'],
      );
      await _s._player.setSubtitleTrack(track);
      if (_s._disposed || !mounted) return;
      _s._updateSubVisibility(track);
      if (mounted) setState(() => _s._selectedExternalSubUrl = url);
    }

    final cached = _s._externalSubFileCache[url];
    if (cached != null) {
      try {
        await applyUri(cached);
      } catch (e) {
        debugPrint('[MobilePlayer] cached subtitle re-apply failed: $e');
        _s._externalSubFileCache.remove(url);
      }
      if (_s._externalSubFileCache.containsKey(url)) return;
    }

    // Already-local subtitle (e.g. kisskh decrypted) - feed straight to libmpv.
    if (url.startsWith('file://') || url.startsWith('/')) {
      try {
        final uri = url.startsWith('file://') ? url : Uri.file(url).toString();
        _s._externalSubFileCache[url] = uri;
        await applyUri(uri);
      } catch (e) {
        if (!mounted) return;
        setState(() => _s._selectedExternalSubUrl = null);
        _s._statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
      }
      return;
    }

    try {
      // Many subtitle CDNs (megacloud, vid-cdn, etc.) gate on a browser UA
      // and the embed-host Referer (NOT the sub URL's own host). Prefer the
      // referer/origin the extractor passed through; otherwise fall back to
      // the sub URL's own origin.
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
      if (!mounted) return;
      if (res.statusCode != 200) {
        if (mounted) {
          setState(() => _s._selectedExternalSubUrl = null);
        }
        _s._statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
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
      _s._externalSubFileCache[url] = uri;
      await applyUri(uri);
    } catch (e) {
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

  Future<void> _fetchSubtitles() async {
    // Pre-populate with Jellyfin / hub-provided subtitles if present.
    final jellyfinSubs = widget.externalSubtitles ?? [];
    if (jellyfinSubs.isNotEmpty) {
      if (mounted) {
        setState(
          () => _s._externalSubtitles = List<Map<String, dynamic>>.from(
            jellyfinSubs,
          ),
        );
      }
    }

    // Anime / Asian Drama use negative hub ids — Wyzie/Levrx need TMDB > 0
    // (skipped inside SubtitleApi), but title scrapers still run. Always merge
    // provider sideloads with online results in the picker.
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
    await _maybeAutoPickExternalSubtitle(forcePlayerApply: true);
  }

  /// Applies preferred subtitle language when external tracks arrive.
  /// Preferred first; English if that category is missing.
  Future<void> _maybeAutoPickExternalSubtitle({
    bool forcePlayerApply = false,
  }) async {
    if (_s._disposed || !mounted) return;

    final preferred = await SettingsService().getPreferredSubtitleLanguage();
    if (_s._disposed || !mounted) return;
    if (preferred == 'None' || preferred.isEmpty) return;

    if (_activeSubtitleMatchesPreferred(preferred)) return;

    final preferredPick = pickExternalSubtitleForLanguage(
      preferred,
      _s._externalSubtitles,
    );

    final uiSelected = _s._selectedExternalSubUrl;
    if (uiSelected != null &&
        _playerHasActiveSubtitle() &&
        !forcePlayerApply) {
      if (preferredPick == null) return;
      if (uiSelected == preferredPick['url']) return;
      debugPrint(
        '[MobilePlayer] auto subtitle → ${preferredPick['display'] ?? preferredPick['language']}',
      );
      await _loadOnlineSubtitle(preferredPick);
      return;
    }

    final pick = preferredPick ??
        (preferred == 'English'
            ? null
            : pickExternalSubtitleForLanguage(
                'English',
                _s._externalSubtitles,
              ));
    if (pick == null) return;

    Map<String, dynamic> toLoad = pick;
    if (forcePlayerApply && uiSelected != null) {
      for (final s in _s._externalSubtitles) {
        if (s['url']?.toString() == uiSelected) {
          toLoad = s;
          break;
        }
      }
    }

    debugPrint(
      '[MobilePlayer] auto subtitle → ${toLoad['display'] ?? toLoad['language']}'
      '${forcePlayerApply ? ' (re-apply)' : ''}',
    );
    await _loadOnlineSubtitle(toLoad);
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
      onExternalUrlChanged: (url) =>
          setState(() => _s._selectedExternalSubUrl = url),
      onNativeSubtitleChanged: (v) => setState(() => _s._isNativeSubtitle = v),
      loadOnlineSubtitle: _loadOnlineSubtitle,
      onSubtitleSettings: _showSubtitleSettings,
      onSubtitleSelected: ({required bool off, String? language, String? title}) {
        unawaited(_rememberSubtitlePreference(
          off: off,
          language: language,
          title: title,
        ));
      },
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
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
    final prefs = await ref.read(playerSubtitlePrefsProvider(false).future);
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
  //  AUDIO MENU
  // ─────────────────────────────────────────────────────────────────────────

  void _showAudioMenu(BuildContext anchorContext) {
    PlayerAudioMenu.show(
      context,
      player: _s._player,
      onTrackSelected: () async {
        await SettingsService().setPlayerAutoAudio(false);
        setState(() => _s._audioPinned = true);
      },
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
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
    // If the user just picked a variant from the same master, keep the list.
    final existing = _s._hlsQualitiesNotifier.value;
    if (existing != null && existing.any((q) => q.url == url)) return;

    // New stream - clear any prior quality state immediately so the gear
    // doesn't expose stale variants while the new master loads.
    final resolved = resolvePlaybackHttpHeaders(headers, streamUrl: url);
    _s._hlsMasterUrl = url;
    _s._hlsMasterHeaders = resolved;
    _s._hlsQualitiesNotifier.value = null;
    fetchHlsQualities(url, headers: resolved).then((qs) {
      if (_s._disposed) return;
      // Only apply if a newer URL didn't take over while we were fetching.
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
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
    );
  }

  Future<void> _switchQuality(HlsQuality q) async {
    final pos = _s._positionNotifier.value;
    _s._currentQualityUrl = q.url;
    if (mounted) setState(() {});
    await openPlayerStream(
      _s._player,
      url: q.url,
      headers: _s._hlsMasterHeaders,
    );
    if (pos.inSeconds > 0) await _s._player.seek(pos);
    _s._startHideTimer();
  }

}
