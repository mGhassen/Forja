part of 'iptv_pt_player_screen.dart';

mixin _IptvPtPlayerUi on ConsumerState<IptvPtPlayerScreen> {
  _IptvPtPlayerScreenState get _s => this as _IptvPtPlayerScreenState;

  void _closeGuideAndFocusPlayer() {
    setState(() {
      _s._guideVisible = false;
      _s._controlsVisible = true;
    });
    _s._hideControlsTimer?.cancel();
    _s._tvBackExitArmed = false;
    _focusPlayerChrome();
  }

  void _toggleGuide() {
    if (widget.channelGuide == null) return;
    setState(() {
      _s._guideVisible = !_s._guideVisible;
      if (_s._guideVisible) {
        _s._searchVisible = false;
        _s._controlsVisible = true;
        _s._hideControlsTimer?.cancel();
        // Always open on the playing channel's category.
        final playingGroup = widget.channelGuide!.groupIdForChannel(
          _s._currentChannelId,
        );
        if (playingGroup != null && playingGroup.isNotEmpty) {
          _s._selectedGroupId = playingGroup;
        }
      } else {
        if (iptvUseTvFocus(context)) {
          _s._hideControlsTimer?.cancel();
          _s._tvBackExitArmed = false;
          _focusPlayerChrome();
        } else {
          _scheduleHideControls();
          _focusPlayerChrome();
        }
      }
    });
  }

  void _toggleSearch() {
    if (widget.channelGuide == null) return;
    setState(() {
      _s._searchVisible = !_s._searchVisible;
      if (_s._searchVisible) {
        _s._guideVisible = false;
        _s._controlsVisible = true;
        _s._hideControlsTimer?.cancel();
      } else {
        _scheduleHideControls();
      }
    });
  }

  void _onSearchChannelSelected(IptvGuideChannel ch) {
    setState(() => _s._searchVisible = false);
    _s._switchChannel(ch);
    _scheduleHideControls();
  }

  IptvGuideChannel? _currentGuideChannel() {
    final guide = widget.channelGuide;
    if (guide == null || _s._currentChannelId.isEmpty) return null;
    for (final ch in guide.channels) {
      if (ch.id == _s._currentChannelId) return ch;
    }
    return null;
  }

  Future<List<EpgEntry>>? _floatingEpgFuture() {
    final epgEnabled = ref.watch(iptvEpgEnabledProvider);
    if (!epgEnabled || _s._epgCache == null) return null;
    final stream =
        _currentGuideChannel()?.xtreamStream ?? _s._epgStreamForActiveSource();
    if (stream == null) return null;
    return _s._epgCache!.load(stream);
  }

  /// Progress bar via chrome profile — hide only ATV Exo pure live.
  bool get _showProgressChrome => _s._chrome.showProgressChrome(
    exoBackend: _s._exoBackend,
    isVodHeuristic: _s._isVod,
  );

  /// Seek chrome: catalog VOD **or** seekable live (duration > 1s).
  bool get _isVodChrome => _s._chrome.vodSeekChrome || _s._isVod;

  /// Films/Series only — Live hides Audio/Subs (catalog `vodPlayback`).
  bool get _showTrackButtons => _s._chrome.showAudioSubtitles;

  bool get _showEpisodesButton =>
      _s._chrome.showEpisodes &&
      (_s.widget.seriesEpisodes?.isNotEmpty ?? false) &&
      _s.widget.seriesPortal != null;

  double _floatingEpgBottomInset(BuildContext context, bool compact) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barPad = compact ? 12.0 : 18.0;
    const barHeight = 56.0;
    final seekbar = _showProgressChrome ? (compact ? 48.0 : 56.0) : 0.0;
    return safeBottom + barPad + barHeight + seekbar + 12;
  }

  void _showStatsMenu(BuildContext anchorContext) {
    final exoId = _s._exoViewId;
    if (_s._exoBackend) {
      if (exoId == null) return;
    } else if (_s._player == null) {
      return;
    }
    // Opening a menu cancels an armed player-exit Back.
    _s._tvBackExitArmed = false;
    PlayerBackExitGate.exitReady = false;
    _scheduleHideControls();
    IptvPlayerStatsPanel.show(
      context,
      player: _s._exoBackend ? null : _s._player,
      exoViewId: _s._exoBackend ? exoId : null,
      anchorContext: anchorContext,
      alignment: Alignment.topRight,
      margin: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 56,
        right: 16,
      ),
      snapshot: () => IptvPlayerStatsSnapshot(
        playing: _s._playing,
        buffering: _s._buffering,
        sourceLabel: _s._sources[_s._sourceIdx].label,
        retryAttempt: _s._retryAttempt,
        volume: _s._volume,
        buffered: _s._buffered,
        position: _s._lastPos,
      ),
    );
  }

  /// ASS/PGS → mpv; SRT/VTT → Flutter overlay (same split as home movies).
  void _updateSubVisibility(SubtitleTrack track) {
    if (_s._exoBackend || _s._disposed || !mounted) return;
    final player = _s._player;
    if (player == null) return;
    final codec = track.codec?.toLowerCase() ?? '';
    final isNativeCodec =
        codec.contains('ass') ||
        codec.contains('ssa') ||
        codec.contains('pgs') ||
        codec.contains('dvd') ||
        codec.contains('dvb') ||
        codec.contains('vobsub');
    final title = (track.title ?? track.id).toLowerCase();
    final looksAss = title.endsWith('.ass') || title.endsWith('.ssa');
    final shouldUseNative = track.id != 'no' && (isNativeCodec || looksAss);
    if (shouldUseNative != _s._isNativeSubtitle) {
      setState(() => _s._isNativeSubtitle = shouldUseNative);
    }
    if (player.platform is NativePlayer) {
      (player.platform as NativePlayer).setProperty(
        'sub-visibility',
        shouldUseNative ? 'yes' : 'no',
      );
    }
  }

  Future<void> _showAudioMenu(BuildContext anchorContext) async {
    _s._tvBackExitArmed = false;
    PlayerBackExitGate.exitReady = false;
    _scheduleHideControls();
    if (_s._exoBackend) {
      final id = _s._exoViewId;
      if (id == null) return;
      final tracks = await ExoPlayerBridge.getTracks(id);
      if (!mounted || !anchorContext.mounted) return;
      await ExoPlayerMenus.showAudio(
        context: context,
        tracks: tracks,
        anchorContext: anchorContext,
        onSelect: (trackId) =>
            ExoPlayerBridge.selectTrack(id, type: 'audio', trackId: trackId),
      );
      return;
    }
    if (_s._player == null) return;
    PlayerAudioMenu.show(
      context,
      player: _s._player!,
      onTrackSelected: () {},
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
    );
  }

  Future<void> _showSubtitleMenu(BuildContext anchorContext) async {
    _s._tvBackExitArmed = false;
    PlayerBackExitGate.exitReady = false;
    _scheduleHideControls();
    final hint = _s._subQueryTitle.trim().isEmpty
        ? null
        : [
            _s._subQueryTitle,
            if (_s._subQueryYear != null) '(${_s._subQueryYear})',
            if (_s._subQuerySeason != null && _s._subQueryEpisode != null)
              'S${_s._subQuerySeason}E${_s._subQueryEpisode}',
          ].join(' ');
    if (_s._exoBackend) {
      final id = _s._exoViewId;
      if (id == null) return;
      final tracks = await ExoPlayerBridge.getTracks(id);
      if (!mounted || !anchorContext.mounted) return;
      await ExoPlayerMenus.showSubtitles(
        context: context,
        tracks: tracks,
        anchorContext: anchorContext,
        externalSubtitles: _s._externalSubtitles,
        selectedExternalSubUrl: _s._selectedExternalSubUrl,
        isFetchingSubs: _s._isFetchingSubs,
        onOff: () async {
          await ExoPlayerBridge.selectTrack(id, type: 'text', trackId: null);
          if (mounted) setState(() => _s._selectedExternalSubUrl = null);
        },
        onSelectEmbedded: (track) async {
          if (track == null) {
            await ExoPlayerBridge.selectTrack(id, type: 'text', trackId: null);
            return;
          }
          await ExoPlayerBridge.selectTrack(
            id,
            type: 'text',
            trackId: track.id,
          );
          if (mounted) setState(() => _s._selectedExternalSubUrl = null);
        },
        onSelectExternal: (sub) async {
          await _loadOnlineSubtitle(sub);
        },
        onSubtitleSettings: _s.widget.onlineSubtitles
            ? _showSubtitleSettings
            : null,
      );
      return;
    }
    if (_s._player == null) return;
    PlayerSubtitleMenu.show(
      context,
      player: _s._player!,
      anchorContext: anchorContext,
      externalSubtitles: _s._externalSubtitles,
      selectedExternalSubUrl: _s._selectedExternalSubUrl,
      isFetchingSubs: _s._isFetchingSubs,
      updateSubVisibility: _updateSubVisibility,
      onExternalUrlChanged: (url) =>
          setState(() => _s._selectedExternalSubUrl = url),
      onNativeSubtitleChanged: (v) => setState(() => _s._isNativeSubtitle = v),
      loadOnlineSubtitle: (s) async {
        await _loadOnlineSubtitle(s);
        return _s._selectedExternalSubUrl == (s['url'] ?? '').toString();
      },
      onSubtitleSettings: _showSubtitleSettings,
      onTitleSearch: widget.onlineSubtitles
          ? () => unawaited(_showTitleSearchDialog())
          : null,
      titleSearchHint: widget.onlineSubtitles ? hint : null,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
    );
  }

  void _showSubtitleSettings() {
    final exoId = _s._exoViewId;
    if (_s._exoBackend) {
      if (exoId == null) return;
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
        player: null,
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
          unawaited(
            ExoPlayerBridge.setSubtitleStyle(
              exoId,
              sizeSp: values.size,
              textColorArgb: values.color.toARGB32(),
              backgroundOpacity: values.bgOpacity,
              bottomPaddingPx: values.bottomPadding,
              bold: values.bold,
              font: values.font,
            ),
          );
        },
      );
      return;
    }
    if (_s._player == null) return;
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

  void _fetchOnlineSubtitles() {
    if (!widget.onlineSubtitles) return;
    final title = _s._subQueryTitle.trim();
    if (title.isEmpty) return;
    _s._subtitleFetchSub?.cancel();
    if (mounted) setState(() => _s._isFetchingSubs = true);
    final stream = SubtitleApi.fetchSubtitlesStream(
      tmdbId: 0,
      title: title,
      year: _s._subQueryYear,
      season: _s._subQuerySeason,
      episode: _s._subQueryEpisode,
    );
    _s._subtitleFetchSub = stream.listen(
      (subs) {
        if (!mounted) return;
        setState(
          () => _s._externalSubtitles = List<Map<String, dynamic>>.from(subs),
        );
      },
      onError: (e) {
        debugPrint('[IPTV Player] subtitle fetch error: $e');
        if (mounted) setState(() => _s._isFetchingSubs = false);
      },
      onDone: () {
        if (mounted) setState(() => _s._isFetchingSubs = false);
      },
    );
  }

  Future<void> _loadOnlineSubtitle(Map<String, dynamic> s) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return;
    if (_s._exoBackend) {
      await _loadOnlineSubtitleExo(s, url);
      return;
    }
    if (_s._player == null) return;
    final isTranslated =
        s['translated'] == true || url.contains('/subtitlecat-translate');

    Future<void> applyUri(String uri) async {
      if (_s._disposed || !mounted || _s._player == null) return;
      final track = SubtitleTrack.uri(
        uri,
        title: s['display']?.toString(),
        language: s['language']?.toString(),
      );
      await _s._player!.setSubtitleTrack(track);
      if (_s._disposed || !mounted) return;
      _updateSubVisibility(track);
      if (mounted) setState(() => _s._selectedExternalSubUrl = url);
    }

    final cached = _s._externalSubFileCache[url];
    if (cached != null) {
      try {
        await applyUri(cached);
        return;
      } catch (_) {
        _s._externalSubFileCache.remove(url);
      }
    }

    if (url.startsWith('file://') || url.startsWith('/')) {
      try {
        final uri = url.startsWith('file://') ? url : Uri.file(url).toString();
        _s._externalSubFileCache[url] = uri;
        await applyUri(uri);
      } catch (_) {
        if (mounted) {
          setState(() => _s._selectedExternalSubUrl = null);
          ForjaToast.warning('Subtitle failed');
        }
      }
      return;
    }

    try {
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
        setState(() => _s._selectedExternalSubUrl = null);
        ForjaToast.warning('Subtitle failed');
        return;
      }
      final dir = await getTemporaryDirectory();
      final safeLang = (s['language'] ?? 'sub').toString().replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final file = File(
        '${dir.path}/forja_iptv_sub_${DateTime.now().millisecondsSinceEpoch}_$safeLang.srt',
      );
      await file.writeAsBytes(res.bodyBytes);
      final uri = Uri.file(file.path).toString();
      _s._externalSubFileCache[url] = uri;
      await applyUri(uri);
    } catch (e) {
      debugPrint('[IPTV Player] subtitle download failed: $e');
      if (!mounted) return;
      setState(() => _s._selectedExternalSubUrl = null);
      ForjaToast.warning('Subtitle failed');
    }
  }

  Future<void> _loadOnlineSubtitleExo(
    Map<String, dynamic> s,
    String url,
  ) async {
    final id = _s._exoViewId;
    if (id == null) return;
    final lang = (s['language'] ?? s['lang'] ?? 'und').toString();
    final label = (s['display'] ?? lang).toString();
    try {
      var uri = url;
      if (!url.startsWith('file://') && !url.startsWith('/')) {
        final cached = _s._externalSubFileCache[url];
        if (cached != null) {
          uri = cached;
        } else {
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
          if (!mounted) return;
          if (res.statusCode != 200) {
            ForjaToast.warning('Subtitle failed');
            return;
          }
          final dir = await getTemporaryDirectory();
          final safeLang = lang.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
          final file = File(
            '${dir.path}/forja_iptv_exo_sub_${DateTime.now().millisecondsSinceEpoch}_$safeLang.srt',
          );
          await file.writeAsBytes(res.bodyBytes);
          uri = Uri.file(file.path).toString();
          _s._externalSubFileCache[url] = uri;
        }
      } else if (url.startsWith('/')) {
        uri = Uri.file(url).toString();
      }
      await ExoPlayerBridge.setSubtitles(id, [
        {'url': uri, 'lang': lang, 'label': label},
      ]);
      if (!mounted) return;
      setState(() => _s._selectedExternalSubUrl = url);
    } catch (e) {
      debugPrint('[IPTV Player] Exo subtitle load failed: $e');
      if (mounted) ForjaToast.warning('Subtitle failed');
    }
  }

  Future<void> _showTitleSearchDialog() async {
    if (!widget.onlineSubtitles) return;
    final titleCtrl = TextEditingController(text: _s._subQueryTitle);
    final yearCtrl = TextEditingController(
      text: _s._subQueryYear?.toString() ?? '',
    );
    final seasonCtrl = TextEditingController(
      text: _s._subQuerySeason?.toString() ?? '',
    );
    final episodeCtrl = TextEditingController(
      text: _s._subQueryEpisode?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ShellScope.rehost(
        context,
        AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Search subtitles',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Film or series name',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: yearCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Year (optional)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: seasonCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: episodeCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Episode',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Search',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    final typed = titleCtrl.text.trim();
    final yearRaw = yearCtrl.text.trim();
    final seasonRaw = seasonCtrl.text.trim();
    final episodeRaw = episodeCtrl.text.trim();
    titleCtrl.dispose();
    yearCtrl.dispose();
    seasonCtrl.dispose();
    episodeCtrl.dispose();
    if (ok != true || !mounted || typed.isEmpty) return;
    final cleaned = cleanIptvMediaTitle(typed);
    setState(() {
      _s._subQueryTitle = cleaned.title.isNotEmpty ? cleaned.title : typed;
      _s._subQueryYear = int.tryParse(yearRaw) ?? cleaned.year;
      _s._subQuerySeason = int.tryParse(seasonRaw) ?? cleaned.season;
      _s._subQueryEpisode = int.tryParse(episodeRaw) ?? cleaned.episode;
      _s._externalSubtitles = [];
      _s._selectedExternalSubUrl = null;
    });
    _fetchOnlineSubtitles();
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

  void _scheduleHideControls() {
    _s._hideControlsTimer?.cancel();
    if (_s._guideVisible || _s._searchVisible) return;
    // TV: match movie/Exo idle (10s). 4s was hiding mid D-pad walk.
    final hideAfter = iptvUseTvFocus(context)
        ? const Duration(seconds: 10)
        : const Duration(seconds: 4);
    _s._hideControlsTimer = Timer(hideAfter, () {
      if (!mounted) return;
      // Keep chrome (and its focus graph) while a menu owns D-pad.
      if (playerChromeOverlayBlocksSeek()) {
        _scheduleHideControls();
        return;
      }
      setState(() => _s._controlsVisible = false);
      if (iptvUseTvFocus(context)) {
        playerTvClaimVideoKeyFocusAfterHide(
          _s._playerTvKeyFocus,
          mounted: () => mounted,
        );
      }
    });
  }

  void _onPlayerMouseMove() {
    // Desktop hybrid has D-pad focus chips + mouse — only leanback skips hover.
    if (iptvLeanbackOnly(context)) return;
    if (_s._guideVisible || _s._searchVisible) return;
    final suppressUntil = _s._suppressChromeRevealUntil;
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) {
      return;
    }
    if (!_s._controlsVisible) {
      setState(() => _s._controlsVisible = true);
    }
    _scheduleHideControls();
  }

  /// Hide chrome without arming Escape (cursor-none hover must not snap chrome back).
  void _hideChromeIntentional() {
    _s._hideControlsTimer?.cancel();
    _s._suppressChromeRevealUntil =
        DateTime.now().add(const Duration(milliseconds: 450));
    _s._escapeExitArmed = false;
    if (!_s._controlsVisible) return;
    setState(() => _s._controlsVisible = false);
  }

  /// Desktop Escape ladder — IPTV + Live Matches (same player).
  /// Overlay/guide/search → hide chrome → leave fullscreen → arm → leave player.
  void _handleEscapeKey() {
    debugPrint(
      '[IptvPlayer] Escape down armed=${_s._escapeExitArmed} '
      'chrome=${_s._controlsVisible} fs=${_s._isFullscreen}',
    );
    final handledAt = _s._escapeHandledAt;
    if (handledAt != null &&
        DateTime.now().difference(handledAt) <
            const Duration(milliseconds: 80)) {
      debugPrint('[IptvPlayer] Escape ignored (same pulse)');
      return;
    }
    _s._escapeHandledAt = DateTime.now();
    PlayerBackExitGate.notePlayerEscapeHandled();

    if (dismissAnyPlayerChromeOverlay()) {
      debugPrint('[IptvPlayer] Escape → dismiss overlay (stay)');
      return;
    }
    if (_s._searchVisible) {
      setState(() {
        _s._searchVisible = false;
        _s._controlsVisible = true;
      });
      _s._escapeExitArmed = false;
      _scheduleHideControls();
      debugPrint('[IptvPlayer] Escape → close search (stay)');
      return;
    }
    if (_s._guideVisible) {
      setState(() {
        _s._guideVisible = false;
        _s._controlsVisible = true;
      });
      _s._escapeExitArmed = false;
      _scheduleHideControls();
      debugPrint('[IptvPlayer] Escape → close guide (stay)');
      return;
    }
    unawaited(_escapeLeaveFullscreenOrContinue());
  }

  Future<void> _escapeLeaveFullscreenOrContinue() async {
    final osFull = _s._isDesktop && await windowManager.isFullScreen();
    final inFullscreen = osFull || _s._isFullscreen;
    debugPrint(
      '[IptvPlayer] Escape ladder armed=${_s._escapeExitArmed} '
      'chrome=${_s._controlsVisible} fs=${_s._isFullscreen} osFull=$osFull',
    );
    if (_s._controlsVisible) {
      debugPrint('[IptvPlayer] Escape → hide chrome (no arm) fs=$inFullscreen');
      _hideChromeIntentional();
      return;
    }
    if (inFullscreen) {
      debugPrint('[IptvPlayer] Escape → exit fullscreen (stay)');
      await DesktopWindowGeometry.exitFullscreen();
      if (!mounted || _s._disposed) return;
      setState(() {
        _s._isFullscreen = false;
        _s._escapeExitArmed = false;
      });
      return;
    }
    if (!_s._escapeExitArmed) {
      debugPrint('[IptvPlayer] Escape → arm only');
      setState(() => _s._escapeExitArmed = true);
      return;
    }
    debugPrint('[IptvPlayer] Escape → confirm exit');
    _s._escapeExitArmed = false;
    await _s._exitIptvPlayer();
  }

  void _claimPlayFocus() {
    if (!iptvUseTvFocus(context) || !_s._controlsVisible) return;
    _s._tvBackExitArmed = false;
    // Underlay WebView / Exo SurfaceView can re-take leanback focus after
    // hybrid composition remounts — re-block before claiming Play.
    if (PlatformInfo.isAndroidTv) {
      unawaited(PlatformChannel.releaseUnderlayPlatformViewFocus());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._controlsVisible) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      if (!_s._playFocus.canRequestFocus) return;
      _s._playFocus.requestFocus();
    });
  }

  void _claimBackFocus() {
    if (!iptvUseTvFocus(context) || !_s._controlsVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._controlsVisible) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      if (!_s._backFocus.canRequestFocus) return;
      _s._backFocus.requestFocus();
    });
  }

  /// Progress bar → : first right-cluster control (Subs / Episodes / Search / Source).
  void _focusRightFromSeekbar() {
    if (!iptvUseTvFocus(context) || !_s._controlsVisible) return;
    final nodes = <FocusNode>[
      if (_showTrackButtons) _s._subtitleFocus,
      if (_showEpisodesButton) _s._episodesFocus,
      if (widget.channelGuide != null) _s._searchChromeFocus,
      if (_s._sources.length > 1) _s._bottomSourceFocus,
    ];
    for (final node in nodes) {
      if (!node.canRequestFocus) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_s._controlsVisible) return;
        if (playerChromeOverlayBlocksFocusClaim()) return;
        if (node.canRequestFocus) node.requestFocus();
      });
      return;
    }
    _claimPlayFocus();
  }

  void _focusPlayerChrome() => _claimPlayFocus();

  void _revealControlsAndFocus({required bool back}) {
    setState(() => _s._controlsVisible = true);
    _scheduleHideControls();
    if (back) {
      _claimBackFocus();
    } else {
      _claimPlayFocus();
    }
  }

  void _toggleControls() {
    final show = !_s._controlsVisible;
    setState(() => _s._controlsVisible = show);
    if (show) {
      _scheduleHideControls();
      _claimPlayFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellScopeBuilder(builder: (context, _) => _buildPlayer(context));
  }

  /// Cold open / Source / engine switch — full-screen spinner.
  /// Channel zap with guide open must NOT use this: unmounting the guide
  /// flashes the rail and resets TV “second OK closes” arm (issue 174).
  Widget _playerLoadingScaffold() {
    final banner = _s._statusBanner;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            if (banner != null) ...[
              const SizedBox(height: 16),
              Text(
                banner,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Video slot while ATV reseats under an open guide/search — keep overlays.
  Widget _playerSwitchingSurface() {
    final banner = _s._statusBanner;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            if (banner != null) ...[
              const SizedBox(height: 16),
              Text(
                banner,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final keepOverlays = _s._guideVisible || _s._searchVisible;
    if (!_s._playerReady && !keepOverlays) {
      return _playerLoadingScaffold();
    }

    final size = MediaQuery.sizeOf(context);
    final compact = size.shortestSide < 600;
    // Include enter-pending: window shrinks before the stream sets _isPipMode.
    final pipMode = _s._isPipMode || PipService.instance.isDesktopActive;
    final epgFuture = (!_s._guideVisible && !_s._searchVisible)
        ? _floatingEpgFuture()
        : null;
    return Actions(
      actions: {
        // Swallow Flutter Escape → DismissIntent → maybePop. Desktop ladder owns exit.
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            if (_s._isDesktop && !_s._isPipMode) {
              _handleEscapeKey();
            }
            return null;
          },
        ),
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (ShellTvFocusCoordinator.consumeOverlayBack()) return;
          if (ShellTvFocusCoordinator.tvBackPolicyEnabled &&
              PlayerBackExitGate.tryFocusBackStay()) {
            return;
          }
          // Desktop Escape must not leave through maybePop — ladder confirms exit.
          if (_s._isDesktop && !_s._isPipMode) {
            debugPrint('[IptvPlayer] PopScope → Escape ladder');
            _handleEscapeKey();
            return;
          }
          unawaited(_s._exitIptvPlayer());
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: PlayerTvKeyScope(
          enabled:
              iptvUseTvFocus(context) &&
              !_s._guideVisible &&
              !_s._searchVisible,
          focusNode: _s._playerTvKeyFocus,
          showControls: _s._controlsVisible,
          onBack: () {
            if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
              ShellTvFocusCoordinator.handleShellBackKey();
              return;
            }
            if (dismissAnyPlayerChromeOverlay()) return;
            unawaited(_s._exitIptvPlayer());
          },
          onPlayPause: () {
            unawaited(_s._togglePlayPauseFromKey());
          },
          onShowControls: () {
            setState(() => _s._controlsVisible = true);
            _scheduleHideControls();
            _focusPlayerChrome();
          },
          onSeekBack: () {
            if (!_isVodChrome || _s._duration.inSeconds <= 1) {
              _revealControlsAndFocus(back: false);
              return;
            }
            var target = _s._position - const Duration(seconds: 10);
            if (target < Duration.zero) target = Duration.zero;
            unawaited(_s._engineSeek(target));
            _scheduleHideControls();
          },
          onSeekForward: () {
            if (!_isVodChrome || _s._duration.inSeconds <= 1) {
              _revealControlsAndFocus(back: false);
              return;
            }
            var target = _s._position + const Duration(seconds: 10);
            if (target > _s._duration) target = _s._duration;
            unawaited(_s._engineSeek(target));
            _scheduleHideControls();
          },
          onVolumeUp: () {
            setState(() => _s._setCachedVolume((_s._volume + 5).clamp(0, 100)));
          },
          onVolumeDown: () {
            setState(() => _s._setCachedVolume((_s._volume - 5).clamp(0, 100)));
          },
          onToggleControls: _toggleControls,
          onFocusBack: () => _revealControlsAndFocus(back: true),
          onFocusPlay: () => _revealControlsAndFocus(back: false),
          onClaimPlayFocus: _claimPlayFocus,
          onControlsActivity: _scheduleHideControls,
          child: MouseRegion(
            onHover: (_) => _onPlayerMouseMove(),
            cursor:
                (_s._controlsVisible || _s._guideVisible || _s._searchVisible)
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: pipMode ? null : _toggleControls,
              // Double-click / double-tap video → toggle fullscreen (same as films).
              // Android TV is already immersive — no fullscreen toggle.
              onDoubleTap: () {
                if (pipMode ||
                    _s._guideVisible ||
                    _s._searchVisible ||
                    iptvLeanbackOnly(context)) {
                  return;
                }
                unawaited(_s._toggleFullscreen());
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video - fill the stack like the main player (Center can leave
                  // a zero-sized surface on Android when Impeller composites siblings).
                  Positioned.fill(
                    child: ExcludeFocus(
                      child: RepaintBoundary(
                        child: !_s._playerReady
                            ? _playerSwitchingSurface()
                            : _s._exoBackend
                                ? ExoPlayerView(
                                    viewId: _s._exoViewId!,
                                    // IPTV Exo always TextureView on ATV: physical
                                    // SurfaceView + hybrid composition went audio-only
                                    // black (even cold-open) and the composition-dead
                                    // surface still fires renderedFirstFrame, so the
                                    // watchdog cannot rescue it (issue 133).
                                    allowSurfaceView: false,
                                  )
                                : Video(
                                    key: ValueKey(_s._videoEpoch),
                                    controller: _s._controller!,
                                    fit: BoxFit.contain,
                                    fill: Colors.black,
                                    controls: NoVideoControls,
                                    subtitleViewConfiguration:
                                        const SubtitleViewConfiguration(
                                          visible: false,
                                        ),
                                  ),
                      ),
                    ),
                  ),
                  if (_s._coverDeadSurface)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(color: Colors.black),
                      ),
                    ),
                  // Text subs (SRT/VTT) — same Flutter overlay as home movies.
                  // ASS/PGS stay on mpv via sub-visibility.
                  if (!pipMode &&
                      !_s._exoBackend &&
                      _s._player != null &&
                      !_s._isNativeSubtitle)
                    StreamBuilder<List<String>>(
                      stream: _s._player!.stream.subtitle,
                      initialData: _s._player!.state.subtitle,
                      builder: (context, snap) {
                        final lines = snap.data ?? [];
                        final text = lines
                            .where((l) => l.trim().isNotEmpty)
                            .join('\n');
                        if (text.isEmpty) return const SizedBox.shrink();
                        const refHeight = 720.0;
                        final winH = MediaQuery.of(context).size.height;
                        final scale = (winH / refHeight).clamp(0.35, 1.0);
                        final hSidePad = 24.0 * scale;
                        return Positioned(
                          left: hSidePad,
                          right: hSidePad,
                          bottom: _s._subtitleBottomPadding * scale,
                          child: IgnorePointer(
                            child: Text(
                              text,
                              style: _buildSubtitleTextStyle(scale: scale),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  // Reconnect/switch always; Buffering… only when picture stalled.
                  if (!pipMode && _s._showPlaybackBanner) _buildBanner(),
                  if (!pipMode && _s._escapeExitArmed)
                    const PlayerEscapeExitHint(),
                  // Top bar + bottom controls (below guide when open).
                  // Hidden entirely while PiP is active - replaced by the
                  // floating revert button below on desktop.
                  if (!pipMode)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _s._controlsVisible ? 1 : 0,
                      child: ExcludeFocus(
                        excluding:
                            iptvUseTvFocus(context) &&
                            (!_s._controlsVisible ||
                                _s._guideVisible ||
                                _s._searchVisible),
                        child: IgnorePointer(
                          ignoring:
                              !_s._controlsVisible ||
                              _s._guideVisible ||
                              _s._searchVisible,
                          child: _buildOverlay(compact),
                        ),
                      ),
                    ),
                  if (pipMode) _buildPipRevertOverlay(),
                  // Positioned.fill must be a direct Stack child — wrapping the
                  // overlay (which used to return Positioned) in RepaintBoundary
                  // caused ParentDataWidget spam on every frame.
                  if (!pipMode &&
                      _s._searchVisible &&
                      widget.channelGuide != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: IptvChannelSearchOverlay(
                          guide: widget.channelGuide!,
                          currentChannelId: _s._currentChannelId,
                          onChannelSelected: _onSearchChannelSelected,
                          onClose: () => setState(() {
                            _s._searchVisible = false;
                            _scheduleHideControls();
                          }),
                        ),
                      ),
                    ),
                  if (!pipMode &&
                      _s._guideVisible &&
                      widget.channelGuide != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: IptvChannelGuidePanel(
                          guide: widget.channelGuide!,
                          selectedGroupId: _s._selectedGroupId,
                          currentChannelId: _s._currentChannelId,
                          epgCache: _s._epgCache,
                          epgEnabled: ref.watch(iptvEpgEnabledProvider),
                          onGroupSelected: (id) {
                            setState(() => _s._selectedGroupId = id);
                          },
                          onChannelSelected: _s._switchChannel,
                          onClose: _closeGuideAndFocusPlayer,
                        ),
                      ),
                    ),
                  if (!pipMode && epgFuture != null)
                    Positioned(
                      right: 16,
                      bottom: _floatingEpgBottomInset(context, compact),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _s._controlsVisible ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_s._controlsVisible,
                          child: IptvFloatingEpg(
                            key: ValueKey(_s._floatingEpgKey),
                            future: epgFuture,
                            maxWidth: compact ? 440 : 540,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBanner() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: IptvShellStyle.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IptvShellStyle.accent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _s._statusBanner ?? 'Buffering…',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(bool compact) {
    final overlay = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0, 0.25, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(compact),
            const Spacer(),
            // VOD scrubber (films/series) or live EPG / live-edge track.
            if (_showProgressChrome)
              _isVodChrome
                  ? _buildSeekbar(compact)
                  : _buildLiveProgressBar(compact),
            _buildBottomBar(compact),
          ],
        ),
      ),
    );
    if (!iptvUseTvFocus(context)) return overlay;
    return FocusScope(
      debugLabel: 'player-chrome',
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: overlay,
      ),
    );
  }

  double _topBarTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 8;
    }
    return 8;
  }

  double _topBarLeftPadding(BuildContext context) => 16;

  /// System-style PiP chrome — expand / Minimize / Close · ±15 · scrubber.
  Widget _buildPipRevertOverlay() {
    final vod = _s._isVod;
    return DesktopPipOverlay(
      hovering: _s._pipHover,
      onHoverChanged: (on) {
        if (!mounted) return;
        if (_s._pipHover == on) return;
        setState(() => _s._pipHover = on);
      },
      playing: _s._playing,
      onTogglePlay: () {
        if (_s._playing) {
          _s._userPlayWhenReady = false;
          unawaited(_s._enginePause());
        } else {
          _s._userPlayWhenReady = true;
          unawaited(_s._enginePlay());
        }
        setState(() {});
      },
      onClose: () => unawaited(_s._exitIptvPlayer()),
      onSeekBack: vod
          ? () {
              var target = _s._position - const Duration(seconds: 15);
              if (target < Duration.zero) target = Duration.zero;
              unawaited(_s._engineSeek(target));
            }
          : null,
      onSeekForward: vod
          ? () {
              var target = _s._position + const Duration(seconds: 15);
              if (target > _s._duration) target = _s._duration;
              unawaited(_s._engineSeek(target));
            }
          : null,
      position: vod ? _s._position : null,
      duration: vod ? _s._duration : null,
      onSeekTo: vod ? (pos) => unawaited(_s._engineSeek(pos)) : null,
    );
  }

  Future<void> _togglePip() async {
    await PipService.instance.toggle();
    if (!mounted) return;
    setState(() {});
    _scheduleHideControls();
  }

  BuiltInPlayerEngine get _builtInEngine => _s._exoBackend
      ? BuiltInPlayerEngine.exoPlayer
      : BuiltInPlayerEngine.mediaKit;

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    _scheduleHideControls();
    if (!anchorContext.mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      usingBuiltIn: true,
      builtInEngine: _builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) async {
        if (builtInEngine != null) {
          await _s._switchBuiltInEngine(
            builtInEngine,
            persist: _s._chrome.persistEnginePref,
          );
          return;
        }
        if (externalPlayer == null) return;
        final url = _s._sources[_s._sourceIdx].url;
        if (url.isEmpty) return;
        _s._userPlayWhenReady = false;
        await _s._enginePause();
        if (!mounted) return;
        final ok = await ExternalPlayerService.launch(
          url: url,
          title: _s._title,
          headers: const {'User-Agent': _IptvPtPlayerScreenState._ua},
          context: context,
          playerName: externalPlayer,
        );
        if (!mounted) return;
        if (!ok) {
          ForjaToast.warning('$externalPlayer not found.');
          _s._userPlayWhenReady = true;
          await _s._enginePlay();
        }
      },
    );
  }

  /// Flat top-bar action — same widget path as movie/Exo (`PlayerFlatIconButton`).
  /// TV must use [tvFocusable] + FocusableControl edges; the old iptvTap wrapper
  /// looked focused but → from Back often failed to claim Player (issue 110).
  Widget _topBarFlatAction({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    ValueChanged<BuildContext>? onPressedWithContext,
    VoidCallback? onDownEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    FocusNode? focusNode,
    int? tvFocusOrder,
  }) {
    assert(onPressed != null || onPressedWithContext != null);
    final tv = iptvUseTvFocus(context);
    final button = PlayerFlatIconButton(
      icon: icon,
      tooltip: tooltip,
      size: 44,
      tvFocusable: tv,
      focusNode: focusNode,
      onPressed: onPressed,
      onPressedWithContext: onPressedWithContext,
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
    );
    if (tvFocusOrder == null) return button;
    return FocusTraversalOrder(
      order: NumericFocusOrder(tvFocusOrder.toDouble()),
      child: button,
    );
  }

  Widget _buildTopBar(bool compact) {
    // PiP is phone/desktop chrome - hide on leanback TV (matches VOD player).
    final showPip =
        PipService.instance.isSupported && iptvShowPointerChrome(context);
    final tv = iptvUseTvFocus(context);
    void downFromTop() {
      if (_showProgressChrome &&
          _isVodChrome &&
          _s._seekFocus.canRequestFocus) {
        _s._seekFocus.requestFocus();
        return;
      }
      _claimPlayFocus();
    }

    void claim(FocusNode node) {
      void tryClaim() {
        if (!mounted) return;
        if (node.canRequestFocus) node.requestFocus();
      }

      tryClaim();
      // Mid-rebuild / ExcludeFocus race — retry once next frame (issue 110).
      if (!node.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryClaim());
      }
    }

    /// Explicit ←/→ edges — [focusInDirection] often fails across the title gap.
    VoidCallback? rightFromBack() {
      if (!tv) return null;
      return () => claim(_s._playerMenuFocus);
    }

    VoidCallback? leftFromPlayer() {
      if (!tv) return null;
      return () => claim(_s._backFocus);
    }

    VoidCallback? rightFromPlayer() {
      if (!tv) return null;
      return () => claim(_s._statsFocus);
    }

    Widget wrapOrder(int order, Widget child) {
      if (!tv) return child;
      return FocusTraversalOrder(
        order: NumericFocusOrder(order.toDouble()),
        child: child,
      );
    }

    var next = 1; // 1 = Back
    final playerOrder = ++next;
    final statsOrder = ++next;
    final pipOrder = showPip ? ++next : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _topBarLeftPadding(context),
        _topBarTopPadding(context),
        8,
        0,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            wrapOrder(
              1,
              iptvBackButton(
                context,
                onTap: () => unawaited(_s._exitIptvPlayer()),
                color: Colors.white,
                size: 22,
                focusNode: _s._backFocus,
                onRightEdge: rightFromBack(),
                onDownEdge: () {
                  _s._tvBackExitArmed = false;
                  downFromTop();
                },
              ),
            ),
            const SizedBox(width: 8),
            if ((_s._logoUrl ?? '').trim().isNotEmpty) ...[
              SizedBox(
                width: 36,
                height: 36,
                child: ForjaNetworkImage(
                  key: ValueKey(_s._logoUrl!.trim()),
                  url: _s._logoUrl!.trim(),
                  fit: BoxFit.contain,
                  useOldImageOnUrlChange: false,
                  error: const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _s._title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IptvShellStyle.overlayTitle.copyWith(
                      fontSize: compact ? 16 : 18,
                      height: 1.15,
                    ),
                  ),
                  if ((_s._subtitle ?? '').isNotEmpty)
                    Text(
                      _s._subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _topBarFlatAction(
              icon: Icons.smart_display_outlined,
              tooltip: 'Player',
              tvFocusOrder: playerOrder,
              focusNode: _s._playerMenuFocus,
              onPressedWithContext: (ctx) => unawaited(_showPlayerMenu(ctx)),
              onDownEdge: downFromTop,
              onLeftEdge: leftFromPlayer(),
              onRightEdge: rightFromPlayer(),
            ),
            _topBarFlatAction(
              icon: Icons.monitor_heart_outlined,
              tooltip: 'Stream stats',
              tvFocusOrder: statsOrder,
              focusNode: _s._statsFocus,
              onPressedWithContext: _showStatsMenu,
              onDownEdge: downFromTop,
              onLeftEdge: tv ? () => claim(_s._playerMenuFocus) : null,
            ),
            if (showPip)
              _topBarFlatAction(
                icon: PipService.instance.isDesktopActive
                    ? Icons.picture_in_picture_alt_rounded
                    : Icons.picture_in_picture_rounded,
                tooltip: 'Picture in Picture',
                tvFocusOrder: pipOrder,
                onPressed: () => unawaited(_togglePip()),
                onDownEdge: downFromTop,
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  //  VOD SEEKBAR - only shown when duration > 0 (Xtream movies / series)
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildChannelLogo(bool compact) {
    if ((_s._logoUrl ?? '').isEmpty) return const SizedBox.shrink();
    final size = compact ? 56.0 : 72.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ForjaNetworkImage(
        key: ValueKey(_s._logoUrl!),
        url: _s._logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        useOldImageOnUrlChange: false,
        error: const SizedBox.shrink(),
      ),
    );
  }

  static double _epgProgress(EpgEntry e) {
    final now = DateTime.now();
    final total = e.stop.difference(e.start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(e.start).inSeconds.clamp(0, total);
    return elapsed / total;
  }

  /// Live chrome: same logo + track + time row as VOD, driven by EPG when
  /// available (read-only). Pure live with no guide still shows a full track.
  /// Not used on Android TV Exo ([_showProgressChrome] is false there).
  Widget _buildLiveProgressBar(bool compact) {
    final future = _floatingEpgFuture();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 2 : 4,
      ),
      child: Row(
        children: [
          if ((_s._logoUrl ?? '').isNotEmpty) ...[
            _buildChannelLogo(compact),
            SizedBox(width: compact ? 10 : 16),
          ],
          Expanded(
            child: future == null
                ? _liveProgressTrack(value: 1.0, compact: compact)
                : FutureBuilder<List<EpgEntry>>(
                    future: future,
                    builder: (context, snap) {
                      final data = snap.data ?? const <EpgEntry>[];
                      EpgEntry? nowEntry;
                      if (data.isNotEmpty) {
                        nowEntry = data.cast<EpgEntry?>().firstWhere(
                          (e) => e!.isNow,
                          orElse: () => data.first,
                        );
                      }
                      final value = nowEntry != null
                          ? _epgProgress(nowEntry).clamp(0.0, 1.0)
                          : 1.0;
                      return _liveProgressTrack(value: value, compact: compact);
                    },
                  ),
          ),
          SizedBox(
            width: compact ? 84 : 100,
            child: future == null
                ? _liveProgressTimeLabel('LIVE', compact)
                : FutureBuilder<List<EpgEntry>>(
                    future: future,
                    builder: (context, snap) {
                      final data = snap.data ?? const <EpgEntry>[];
                      EpgEntry? nowEntry;
                      if (data.isNotEmpty) {
                        nowEntry = data.cast<EpgEntry?>().firstWhere(
                          (e) => e!.isNow,
                          orElse: () => data.first,
                        );
                      }
                      if (nowEntry == null || !nowEntry.isNow) {
                        return _liveProgressTimeLabel('LIVE', compact);
                      }
                      final elapsed = DateTime.now().difference(nowEntry.start);
                      final safe = elapsed.isNegative ? Duration.zero : elapsed;
                      return _liveProgressTimeLabel(
                        _IptvPtPlayerScreenState._fmtDur(safe),
                        compact,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _liveProgressTimeLabel(String text, bool compact) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: GoogleFonts.spaceMono(
        color: Colors.white,
        fontSize: compact ? 12 : 13,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
      ),
    );
  }

  Widget _liveProgressTrack({required double value, required bool compact}) {
    return SizedBox(
      height: compact ? 28 : 32,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 3.5,
            backgroundColor: Colors.white24,
            color: ForjaShellColors.brandGreen,
          ),
        ),
      ),
    );
  }

  /// VOD chrome before duration is known — keeps the progress row visible.
  Widget _buildVodSeekbarWaiting(bool compact) {
    final pos = _s._position;
    final tv = iptvUseTvFocus(context);
    final bar = SizedBox(
      height: compact ? 28 : 32,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: const LinearProgressIndicator(
            minHeight: 3.5,
            backgroundColor: Colors.white24,
            color: ForjaShellColors.brandGreen,
          ),
        ),
      ),
    );
    final track = !tv
        ? bar
        : Focus(
            focusNode: _s._seekFocus,
            onKeyEvent: (node, event) {
              if (!shellTvIsNavigationKey(event)) {
                return KeyEventResult.ignored;
              }
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.arrowUp) {
                _claimBackFocus();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowDown) {
                _claimPlayFocus();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowLeft) {
                _claimPlayFocus();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                _focusRightFromSeekbar();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (ctx) {
                final focused = Focus.of(ctx).hasFocus;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: focused
                        ? Border.all(
                            color: ForjaShellColors.brandGreen,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: bar,
                );
              },
            ),
          );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 2 : 4,
      ),
      child: Row(
        children: [
          if ((_s._logoUrl ?? '').isNotEmpty) ...[
            _buildChannelLogo(compact),
            SizedBox(width: compact ? 10 : 16),
          ],
          Expanded(child: track),
          SizedBox(
            width: compact ? 100 : 120,
            child: Text(
              '${_IptvPtPlayerScreenState._fmtDur(pos)} / --:--',
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekbar(bool compact) {
    final totalMs = _s._duration.inMilliseconds.toDouble();
    // Movies/series always reserve the scrubber row — Exo often reports
    // duration late (or never for some progressive MP4s). Don't hide chrome.
    if (totalMs <= 0) {
      if (!_isVodChrome) return const SizedBox.shrink();
      return _buildVodSeekbarWaiting(compact);
    }
    final currentMs = _s._isSeeking
        ? _s._seekPreview
        : _s._position.inMilliseconds.toDouble().clamp(0.0, totalMs);
    final shownPos = Duration(milliseconds: currentMs.toInt());
    final tv = iptvUseTvFocus(context);

    Widget slider;
    if (tv) {
      slider = CustomSeekbar(
        duration: _s._duration,
        position: _s._isSeeking
            ? Duration(milliseconds: _s._seekPreview.toInt())
            : _s._position,
        bufferedPosition: _s._buffered,
        focusNode: _s._seekFocus,
        tvFocusable: true,
        onTvFocusUp: () => _claimBackFocus(),
        onTvFocusDown: () => _claimPlayFocus(),
        onTvFocusLeft: () => _claimPlayFocus(),
        onTvFocusRight: _focusRightFromSeekbar,
        onDragStart: () {
          setState(() {
            _s._isSeeking = true;
            _s._seekPreview = _s._position.inMilliseconds.toDouble();
          });
          _s._hideControlsTimer?.cancel();
        },
        onDragEnd: () {
          if (!_s._isSeeking) return;
          setState(() => _s._isSeeking = false);
          _scheduleHideControls();
        },
        onSeek: (target) async {
          setState(() {
            _s._isSeeking = false;
            _s._position = target;
            _s._seekPreview = target.inMilliseconds.toDouble();
          });
          try {
            await _s._engineSeek(target);
          } catch (_) {}
          _scheduleHideControls();
        },
      );
    } else {
      slider = SliderTheme(
        data: IptvShellStyle.sliderTheme(context).copyWith(
          activeTrackColor: ForjaShellColors.brandGreen,
          thumbColor: ForjaShellColors.brandGreen,
          overlayColor: ForjaShellColors.brandGreen.withValues(alpha: 0.2),
          trackHeight: 3.5,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 7,
            elevation: 3,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: currentMs.clamp(0.0, totalMs),
          min: 0,
          max: totalMs,
          onChangeStart: (v) {
            setState(() {
              _s._isSeeking = true;
              _s._seekPreview = v;
            });
            _s._hideControlsTimer?.cancel();
          },
          onChanged: (v) {
            setState(() => _s._seekPreview = v);
          },
          onChangeEnd: (v) async {
            final target = Duration(milliseconds: v.toInt());
            setState(() {
              _s._isSeeking = false;
              _s._position = target;
            });
            try {
              await _s._engineSeek(target);
            } catch (_) {}
            _scheduleHideControls();
          },
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 2 : 4,
      ),
      child: Row(
        children: [
          if ((_s._logoUrl ?? '').isNotEmpty) ...[
            _buildChannelLogo(compact),
            SizedBox(width: compact ? 10 : 16),
          ],
          Expanded(child: slider),
          SizedBox(
            width: compact ? 100 : 120,
            child: Text(
              '${_IptvPtPlayerScreenState._fmtDur(shownPos)} / '
              '${_IptvPtPlayerScreenState._fmtDur(_s._duration)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool compact) {
    final tvFocus = iptvUseTvFocus(context);
    final showPointerChrome = iptvShowPointerChrome(context);

    /// Left transport (Play / Replay) → seekbar when present, else Back.
    void upFromLeftControls() {
      if (_showProgressChrome &&
          _isVodChrome &&
          _s._seekFocus.canRequestFocus) {
        _s._seekFocus.requestFocus();
        return;
      }
      _claimBackFocus();
    }

    /// Right chrome (Search / Guide / bottom Source) → top-right Player (not Back).
    void upFromRightControls() {
      if (_showProgressChrome &&
          _isVodChrome &&
          _s._seekFocus.canRequestFocus) {
        _s._seekFocus.requestFocus();
        return;
      }
      if (_s._playerMenuFocus.canRequestFocus) {
        _s._playerMenuFocus.requestFocus();
        return;
      }
      _claimBackFocus();
    }

    void claim(FocusNode node) {
      void tryClaim() {
        if (!mounted) return;
        if (node.canRequestFocus) node.requestFocus();
      }

      tryClaim();
      if (!node.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryClaim());
      }
    }

    Widget wrapOrder(int order, Widget child) {
      if (!tvFocus) return child;
      return FocusTraversalOrder(
        order: NumericFocusOrder(order.toDouble()),
        child: child,
      );
    }

    final hasGuide = widget.channelGuide != null;
    final hasSources = _s._sources.length > 1;
    final showTracks = _showTrackButtons;
    final showEpisodes = _showEpisodesButton;

    // Explicit ←/→ chain (issue 131) — Spacer / title-gap geometry fails on ATV.
    FocusNode? rightOfPlay() {
      if (!tvFocus) return null;
      return _s._replayFocus;
    }

    FocusNode? rightOfReplay() {
      if (!tvFocus) return null;
      if (showTracks) return _s._subtitleFocus;
      if (showEpisodes) return _s._episodesFocus;
      if (hasGuide) return _s._searchChromeFocus;
      if (hasSources) return _s._bottomSourceFocus;
      return null;
    }

    FocusNode? leftOfSubtitle() {
      if (!tvFocus) return null;
      return _s._replayFocus;
    }

    FocusNode? rightOfSubtitle() {
      if (!tvFocus) return null;
      return _s._audioFocus;
    }

    FocusNode? leftOfAudio() {
      if (!tvFocus) return null;
      return _s._subtitleFocus;
    }

    FocusNode? rightOfAudio() {
      if (!tvFocus) return null;
      if (showEpisodes) return _s._episodesFocus;
      if (hasGuide) return _s._searchChromeFocus;
      if (hasSources) return _s._bottomSourceFocus;
      return null;
    }

    FocusNode? leftOfEpisodes() {
      if (!tvFocus) return null;
      if (showTracks) return _s._audioFocus;
      return _s._replayFocus;
    }

    FocusNode? rightOfEpisodes() {
      if (!tvFocus) return null;
      if (hasGuide) return _s._searchChromeFocus;
      if (hasSources) return _s._bottomSourceFocus;
      return null;
    }

    FocusNode? leftOfSearch() {
      if (!tvFocus) return null;
      if (showEpisodes) return _s._episodesFocus;
      if (showTracks) return _s._audioFocus;
      return _s._replayFocus;
    }

    FocusNode? rightOfSearch() {
      if (!tvFocus) return null;
      return _s._guideFocus;
    }

    FocusNode? leftOfGuide() {
      if (!tvFocus) return null;
      return _s._searchChromeFocus;
    }

    FocusNode? rightOfGuide() {
      if (!tvFocus || !hasSources) return null;
      return _s._bottomSourceFocus;
    }

    FocusNode? leftOfBottomSource() {
      if (!tvFocus) return null;
      if (hasGuide) return _s._guideFocus;
      if (showEpisodes) return _s._episodesFocus;
      if (showTracks) return _s._audioFocus;
      return _s._replayFocus;
    }

    var order = 10; // bottom row after top-bar orders
    Widget nextIcon({
      required IconData icon,
      required VoidCallback onTap,
      bool big = false,
      FocusNode? focusNode,
      VoidCallback? onUpEdge,
      VoidCallback? onLeftEdge,
      VoidCallback? onRightEdge,
    }) {
      final widget = IptvRoundIcon(
        icon: icon,
        big: big,
        focusNode: focusNode,
        onUpEdge: onUpEdge,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onTap: onTap,
      );
      return wrapOrder(order++, widget);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 12 : 18,
      ),
      child: Row(
        children: [
          nextIcon(
            icon: _s._playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            big: true,
            focusNode: _s._playFocus,
            onUpEdge: tvFocus ? upFromLeftControls : null,
            onRightEdge: rightOfPlay() == null
                ? null
                : () => claim(rightOfPlay()!),
            onTap: () async {
              await _s._togglePlayPauseFromKey();
              _scheduleHideControls();
            },
          ),
          const SizedBox(width: 14),
          nextIcon(
            icon: Icons.replay_rounded,
            focusNode: _s._replayFocus,
            onUpEdge: tvFocus ? upFromLeftControls : null,
            onLeftEdge: tvFocus ? () => claim(_s._playFocus) : null,
            onRightEdge: rightOfReplay() == null
                ? null
                : () => claim(rightOfReplay()!),
            onTap: () {
              unawaited(_s._reloadCurrent());
              _scheduleHideControls();
            },
          ),
          if (showPointerChrome) ...[
            const SizedBox(width: 14),
            MouseRegion(
              onEnter: (_) {
                setState(() => _s._volumeHovering = true);
                _s._hideVolumeTimer?.cancel();
                _scheduleHideControls();
              },
              onExit: (_) {
                setState(() => _s._volumeHovering = false);
                _scheduleHideVolumeSlider();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IptvRoundIcon(
                    icon: _s._muted || _s._volume == 0
                        ? Icons.volume_off_rounded
                        : (_s._volume < 40
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                    onTap: _toggleMute,
                    onLongPress: () {
                      setState(
                        () => _s._showVolumeSlider = !_s._showVolumeSlider,
                      );
                      if (_s._showVolumeSlider) {
                        _s._hideVolumeTimer?.cancel();
                      } else {
                        _scheduleHideVolumeSlider();
                      }
                      _scheduleHideControls();
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      width: (_s._showVolumeSlider || _s._volumeHovering)
                          ? (compact ? 110 : 160)
                          : 0,
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SliderTheme(
                            data: IptvShellStyle.sliderTheme(context).copyWith(
                              inactiveTrackColor: Colors.white24,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                            ),
                            child: Slider(
                              value: _s._volume.clamp(0.0, 100.0),
                              min: 0,
                              max: 100,
                              onChangeStart: (_) {
                                _s._hideVolumeTimer?.cancel();
                                _scheduleHideControls();
                              },
                              onChanged: (v) {
                                setState(() => _s._setCachedVolume(v));
                                _scheduleHideVolumeSlider();
                                _scheduleHideControls();
                              },
                              onChangeEnd: (_) => _scheduleHideVolumeSlider(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (showTracks) ...[
            Builder(
              builder: (btnCtx) => nextIcon(
                icon: Icons.subtitles_outlined,
                focusNode: _s._subtitleFocus,
                onUpEdge: tvFocus ? upFromRightControls : null,
                onLeftEdge: leftOfSubtitle() == null
                    ? null
                    : () => claim(leftOfSubtitle()!),
                onRightEdge: rightOfSubtitle() == null
                    ? null
                    : () => claim(rightOfSubtitle()!),
                onTap: () => unawaited(_showSubtitleMenu(btnCtx)),
              ),
            ),
            const SizedBox(width: 14),
            Builder(
              builder: (btnCtx) => nextIcon(
                icon: Icons.audiotrack_rounded,
                focusNode: _s._audioFocus,
                onUpEdge: tvFocus ? upFromRightControls : null,
                onLeftEdge: leftOfAudio() == null
                    ? null
                    : () => claim(leftOfAudio()!),
                onRightEdge: rightOfAudio() == null
                    ? null
                    : () => claim(rightOfAudio()!),
                onTap: () => unawaited(_showAudioMenu(btnCtx)),
              ),
            ),
            const SizedBox(width: 14),
          ],
          if (showEpisodes) ...[
            Builder(
              builder: (btnCtx) => nextIcon(
                icon: Icons.video_library_outlined,
                focusNode: _s._episodesFocus,
                onUpEdge: tvFocus ? upFromRightControls : null,
                onLeftEdge: leftOfEpisodes() == null
                    ? null
                    : () => claim(leftOfEpisodes()!),
                onRightEdge: rightOfEpisodes() == null
                    ? null
                    : () => claim(rightOfEpisodes()!),
                onTap: () => unawaited(_showEpisodesPanel(btnCtx)),
              ),
            ),
            const SizedBox(width: 14),
          ],
          if (hasGuide) ...[
            nextIcon(
              icon: Icons.search_rounded,
              focusNode: _s._searchChromeFocus,
              onUpEdge: tvFocus ? upFromRightControls : null,
              onLeftEdge: leftOfSearch() == null
                  ? null
                  : () => claim(leftOfSearch()!),
              onRightEdge: rightOfSearch() == null
                  ? null
                  : () => claim(rightOfSearch()!),
              onTap: _toggleSearch,
            ),
            const SizedBox(width: 14),
            nextIcon(
              icon: Icons.grid_view_rounded,
              focusNode: _s._guideFocus,
              onUpEdge: tvFocus ? upFromRightControls : null,
              onLeftEdge: leftOfGuide() == null
                  ? null
                  : () => claim(leftOfGuide()!),
              onRightEdge: rightOfGuide() == null
                  ? null
                  : () => claim(rightOfGuide()!),
              onTap: _toggleGuide,
            ),
            const SizedBox(width: 14),
          ],
          if (hasSources)
            Builder(
              builder: (anchorContext) => nextIcon(
                icon: Icons.swap_horiz_rounded,
                focusNode: _s._bottomSourceFocus,
                onUpEdge: tvFocus ? upFromRightControls : null,
                onLeftEdge: leftOfBottomSource() == null
                    ? null
                    : () => claim(leftOfBottomSource()!),
                onTap: () => _showSourcePicker(anchorContext: anchorContext),
              ),
            ),
          if (hasSources) const SizedBox(width: 14),
          if (showPointerChrome)
            IptvRoundIcon(
              icon: _s._isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              onTap: _s._toggleFullscreen,
            ),
        ],
      ),
    );
  }

  static int _hubEpisodeKey(IptvEpisode e) => e.season * 10000 + e.episode;

  Future<void> _showEpisodesPanel(BuildContext anchorContext) async {
    final eps = _s.widget.seriesEpisodes;
    final portal = _s.widget.seriesPortal;
    if (eps == null || eps.isEmpty || portal == null) return;
    _s._tvBackExitArmed = false;
    PlayerBackExitGate.exitReady = false;
    _scheduleHideControls();
    final hub = [
      for (final e in eps)
        PlayerHubEpisode(
          number: _hubEpisodeKey(e),
          title: e.title.trim().isEmpty
              ? 'Episode ${e.episode}'
              : e.title.trim(),
          overview: e.plot.trim().isEmpty ? null : e.plot.trim(),
          thumbnailUrl: e.image.trim().isEmpty ? null : e.image.trim(),
        ),
    ];
    final current = (_s._playingSeason != null && _s._playingEpisode != null)
        ? _s._playingSeason! * 10000 + _s._playingEpisode!
        : hub.first.number;
    await PlayerHubEpisodePanel.show(
      context: context,
      episodes: hub,
      currentEpisode: current,
      onEpisodeSelected: (hubEp) async {
        final key = hubEp.number.toInt();
        IptvEpisode? match;
        for (final e in eps) {
          if (_hubEpisodeKey(e) == key) {
            match = e;
            break;
          }
        }
        if (match == null) return;
        await _switchSeriesEpisode(match, portal);
      },
    );
  }

  Future<void> _switchSeriesEpisode(
    IptvEpisode episode,
    IptvPortal portal,
  ) async {
    final url = await IptvClient.resolveEpisodeUrl(portal, episode);
    if (!mounted || url == null || url.isEmpty) return;
    final show = (_s.widget.seriesShowTitle ?? _s._subQueryTitle).trim();
    final epTitle = episode.title.trim().isEmpty
        ? 'Episode ${episode.episode}'
        : episode.title.trim();
    setState(() {
      _s._sources = [IptvPlaySource(url: url, label: _s._sources.first.label)];
      _s._sourceIdx = 0;
      _s._title = 'Ep ${episode.episode} · $epTitle';
      _s._subtitle = show.isEmpty
          ? 'Season ${episode.season}'
          : '$show · Season ${episode.season}';
      _s._logoUrl = episode.image.trim().isNotEmpty
          ? episode.image
          : _s._logoUrl;
      _s._playingSeason = episode.season;
      _s._playingEpisode = episode.episode;
      _s._subQuerySeason = episode.season;
      _s._subQueryEpisode = episode.episode;
      _s._position = Duration.zero;
      _s._duration = Duration.zero;
      _s._buffered = Duration.zero;
    });
    await _s._reloadCurrent();
    if (_s.widget.onlineSubtitles) {
      _fetchOnlineSubtitles();
    }
  }

  void _toggleMute() {
    setState(() {
      if (_s._muted || _s._volume == 0) {
        _s._setCachedVolume(
          _s._volumeBeforeMute > 0 ? _s._volumeBeforeMute : 100.0,
        );
      } else {
        _s._volumeBeforeMute = _s._volume;
        _s._setCachedVolume(0);
      }
      _s._showVolumeSlider = true;
    });
    _scheduleHideVolumeSlider();
    _scheduleHideControls();
  }

  void _scheduleHideVolumeSlider() {
    _s._hideVolumeTimer?.cancel();
    _s._hideVolumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _s._volumeHovering) return;
      setState(() => _s._showVolumeSlider = false);
    });
  }

  String _sourceHost(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host;
  }

  /// Category / group only for sports-style sources; host alone otherwise.
  String? _sourceSubtitle(IptvPlaySource src) {
    return iptvSourcePickerSubtitle(
      src,
      liveSourceKind: _s.widget.liveSourceKind,
      hostFallback: _sourceHost,
    );
  }

  PlayerPopupListTile _sourcePickerTile({
    required IptvPlaySource src,
    required bool selected,
    PlayerSourceStatus? status,
    ValueChanged<bool>? onInteractiveChange,
    required VoidCallback onTap,
  }) {
    return buildIptvSourcePickerTile(
      src: src,
      liveSourceKind: _s.widget.liveSourceKind,
      sourceLogo: _sourceLogo,
      selected: selected,
      status: status,
      trailing: null,
      onInteractiveChange: onInteractiveChange,
      onTap: onTap,
    );
  }

  Widget _sourceLogo(IptvPlaySource src) {
    const size = 40.0;
    final url = (src.logoUrl ?? '').trim();
    if (url.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.live_tv_rounded,
          color: Colors.white38,
          size: size * 0.55,
        ),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (size * dpr).round().clamp(1, 512);
    return SizedBox(
      width: size,
      height: size,
      child: ForjaNetworkImage(
        key: ValueKey(url),
        url: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        memCacheWidth: cacheW,
        filterQuality: FilterQuality.medium,
        useOldImageOnUrlChange: false,
        error: Icon(
          Icons.live_tv_rounded,
          color: Colors.white38,
          size: size * 0.55,
        ),
        placeholder: Icon(
          Icons.live_tv_rounded,
          color: Colors.white24,
          size: size * 0.55,
        ),
      ),
    );
  }

  /// Floating panel (not a bottom sheet) so TV gets D-pad focus + autofocus on
  /// the active source, same chrome as the Player / Stats menus.
  void _showSourcePicker({BuildContext? anchorContext}) {
    _scheduleHideControls();
    final sportsProbe = iptvUseLiveSportsSourcePicker(_s.widget);
    PlayerPopupPanel.show(
      context: context,
      title: 'Source',
      leadingIcon: Icons.swap_horiz_rounded,
      anchorContext: anchorContext,
      alignment: Alignment.bottomRight,
      margin: const EdgeInsets.only(right: 16, bottom: 96),
      width: 460,
      maxHeight: 440,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: sportsProbe
            ? _IptvSportsSourcePickerList(
                sources: _s._sources,
                selectedIndex: _s._sourceIdx,
                liveSourceKind: _s.widget.liveSourceKind,
                sourceLogo: _sourceLogo,
                sourceSubtitle: _sourceSubtitle,
                onPick: (i) {
                  PlayerPopupPanel.dismiss();
                  _s._switchSource(i);
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _s._sources.length; i++)
                    _sourcePickerTile(
                      src: _s._sources[i],
                      selected: i == _s._sourceIdx,
                      status: i == _s._sourceIdx
                          ? PlayerSourceStatus.active
                          : null,
                      onTap: () {
                        PlayerPopupPanel.dismiss();
                        _s._switchSource(i);
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _IptvSportsSourcePickerList extends StatefulWidget {
  const _IptvSportsSourcePickerList({
    required this.sources,
    required this.selectedIndex,
    required this.liveSourceKind,
    required this.sourceLogo,
    required this.sourceSubtitle,
    required this.onPick,
  });

  final List<IptvPlaySource> sources;
  final int selectedIndex;
  final IptvLiveSourceKind? liveSourceKind;
  final Widget Function(IptvPlaySource src) sourceLogo;
  final String? Function(IptvPlaySource src) sourceSubtitle;
  final ValueChanged<int> onPick;

  @override
  State<_IptvSportsSourcePickerList> createState() =>
      _IptvSportsSourcePickerListState();
}

class _IptvSportsSourcePickerListState extends State<_IptvSportsSourcePickerList> {
  final _healthProbe = IptvLazyUrlHealthProbe(
    delay: const Duration(milliseconds: 500),
  );
  final _rowKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _healthProbe.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!mounted) return;
    final ctx = _rowKeys[widget.selectedIndex]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  PlayerSourceStatus? _statusFor(int index, IptvPlaySource src) {
    if (index == widget.selectedIndex) return PlayerSourceStatus.active;
    final key = iptvLiveSourceProbeKey(src);
    final health = _healthProbe.healthFor(key);
    if (health == null) return null;
    return health ? PlayerSourceStatus.ready : PlayerSourceStatus.failed;
  }

  void _syncProbe(IptvPlaySource src, bool active) {
    final key = iptvLiveSourceProbeKey(src);
    final probeUrl = iptvLiveSourceProbeUrl(src);
    if (probeUrl == null) {
      if (!active) _healthProbe.cancel(key);
      return;
    }
    if (active) {
      _healthProbe.schedule(
        key,
        probeUrl,
        onlyThis: iptvUseTvFocus(context),
      );
    } else {
      _healthProbe.cancel(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _healthProbe,
      builder: (_, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.sources.length; i++)
              Builder(
                builder: (context) {
                  final src = widget.sources[i];
                  final rowKey =
                      _rowKeys.putIfAbsent(i, () => GlobalKey(debugLabel: 'iptv-source-$i'));
                  return KeyedSubtree(
                    key: rowKey,
                    child: buildIptvSourcePickerTile(
                      src: src,
                      liveSourceKind: widget.liveSourceKind,
                      sourceLogo: widget.sourceLogo,
                      selected: i == widget.selectedIndex,
                      status: _statusFor(i, src),
                      onInteractiveChange: (active) => _syncProbe(src, active),
                      onTap: () => widget.onPick(i),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

bool iptvUseLiveSportsSourcePicker(IptvPtPlayerScreen screen) {
  return screen.titleTracksSource || screen.liveSourceKind != null;
}

bool iptvLiveMatchSourcePicker(
  IptvLiveSourceKind? sessionKind,
  IptvPlaySource src,
) {
  return sessionKind == IptvLiveSourceKind.liveEngine ||
      (src.liveProviderBadge ?? '').trim().isNotEmpty;
}

String? iptvSourcePickerSubtitle(
  IptvPlaySource src, {
  required IptvLiveSourceKind? liveSourceKind,
  required String Function(String url) hostFallback,
}) {
  final structured = src.pickerSubtitle;
  if (structured != null && structured.isNotEmpty) return structured;
  final detail = (src.detail ?? '').trim();
  if (detail.isNotEmpty) return detail;
  if (iptvLiveMatchSourcePicker(liveSourceKind, src)) return null;
  final host = hostFallback(src.url);
  return host.isEmpty ? null : host;
}

Widget iptvLiveSourceLeading(IptvPlaySource src) {
  const size = 40.0;
  if (src.liveStreamHd) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'HD',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
  return SizedBox(
    width: size,
    height: size,
    child: Icon(
      Icons.play_circle_outline,
      color: Colors.white38,
      size: size * 0.55,
    ),
  );
}

Color? iptvLiveProviderBadgeColor(String? badge) {
  return switch (badge) {
    'PPV' => Colors.orange.shade700,
    _ => null,
  };
}

Widget? iptvLiveSourceTrailing(IptvPlaySource src) {
  if (src.liveViewerCount <= 0) return null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.visibility_outlined, size: 14, color: Colors.white38),
      const SizedBox(width: 4),
      Text(
        '${src.liveViewerCount}',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    ],
  );
}

PlayerPopupListTile buildIptvSourcePickerTile({
  required IptvPlaySource src,
  required IptvLiveSourceKind? liveSourceKind,
  required Widget Function(IptvPlaySource src) sourceLogo,
  required bool selected,
  PlayerSourceStatus? status,
  Widget? trailing,
  ValueChanged<bool>? onInteractiveChange,
  required VoidCallback onTap,
}) {
  final live = iptvLiveMatchSourcePicker(liveSourceKind, src);
  return PlayerPopupListTile(
    leading: live ? iptvLiveSourceLeading(src) : sourceLogo(src),
    label: src.pickerTitle,
    badge: live ? src.liveProviderBadge : null,
    badgeColor: live
        ? iptvLiveProviderBadgeColor(src.liveProviderBadge)
        : null,
    subtitle: iptvSourcePickerSubtitle(
      src,
      liveSourceKind: liveSourceKind,
      hostFallback: (url) {
        final host = Uri.tryParse(url)?.host ?? '';
        return host.isEmpty ? url : host;
      },
    ),
    selected: selected,
    status: status,
    trailing: trailing ?? (live ? iptvLiveSourceTrailing(src) : null),
    onInteractiveChange: onInteractiveChange,
    onTap: onTap,
  );
}
