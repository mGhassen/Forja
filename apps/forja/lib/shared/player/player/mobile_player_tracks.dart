part of 'mobile_player_screen.dart';

mixin _MobilePlayerTracks on State<MobilePlayerScreen> {
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

    // Already-local subtitle (e.g. kisskh decrypted) — feed straight to libmpv.
    if (url.startsWith('file://') || url.startsWith('/')) {
      try {
        _s._player.setSubtitleTrack(
          SubtitleTrack.uri(
            url.startsWith('file://') ? url : Uri.file(url).toString(),
            title: s['display'],
            language: s['language'],
          ),
        );
        if (mounted) setState(() => _s._selectedExternalSubUrl = url);
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
      final track = SubtitleTrack.uri(
        uri,
        title: s['display'],
        language: s['language'],
      );
      _s._player.setSubtitleTrack(track);
      _s._updateSubVisibility(track);
      if (mounted) {
        setState(() => _s._selectedExternalSubUrl = url);
      }
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
    // Pre-populate with Jellyfin subtitles if provided
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

    if (widget.movie == null || widget.movie!.id <= 0) return;
    if (mounted) setState(() => _s._isFetchingSubs = true);

    final stream = SubtitleApi.fetchSubtitlesStream(
      tmdbId: widget.movie!.id,
      imdbId: widget.movie!.imdbId,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      title: widget.movie!.title,
      year: widget.movie!.releaseDate.length >= 4
          ? int.tryParse(widget.movie!.releaseDate.substring(0, 4))
          : null,
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
  }

  /// Subtitle auto-pick was removed (the user explicitly disabled the
  /// preferred-subtitle setting). Kept as a no-op so existing call sites
  /// don't have to be re-plumbed.
  Future<void> _maybeAutoPickExternalSubtitle() async {}

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
      onSubtitleSelected: () async {
        await SettingsService().setPlayerAutoSubtitle(false);
        setState(() => _s._subtitlePinned = true);
      },
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
    );
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
    final s = SettingsService();
    final size = await s.getSubSize();
    final color = await s.getSubColor();
    final bgOp = await s.getSubBgOpacity();
    final bold = await s.getSubBold();
    final padding = await s.getSubBottomPadding();
    final font = await s.getSubFont();
    if (mounted) {
      setState(() {
        _s._subtitleSize = size;
        _s._subtitleColor = Color(color);
        _s._subtitleBgOpacity = bgOp;
        _s._subtitleBold = bold;
        _s._subtitleBottomPadding = padding;
        _s._subtitleFont = font;
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

    // New stream — clear any prior quality state immediately so the gear
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
