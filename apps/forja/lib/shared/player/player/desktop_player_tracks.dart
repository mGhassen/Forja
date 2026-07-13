part of 'desktop_player_screen.dart';

mixin _DesktopPlayerTracks on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  void _cycleHwDec() {
    final next = _s._hwDecMode.next;
    setState(() => _s._hwDecMode = next);

    if (_s._player.platform is NativePlayer) {
      (_s._player.platform as NativePlayer).setProperty('hwdec', next.mpvValue);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBTITLE MANAGEMENT
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
      if (mounted)
        setState(
          () => _s._externalSubtitles = List<Map<String, dynamic>>.from(
            jellyfinSubs,
          ),
        );
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
      onDone: () {
        if (mounted) setState(() => _s._isFetchingSubs = false);
        _maybeAutoPickExternalSubtitle();
      },
    );
  }

  /// If the user has a preferred subtitle language but the embedded tracks
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
    );
  }

  void _showSubtitleSettings() {
    final fonts = [
      'Default',
      'Poppins',
      'Roboto',
      'Roboto Mono',
      'Montserrat',
      'Open Sans',
      'Lato',
    ];
    final colorOptions = <String, Color>{
      'White': Colors.white,
      'Yellow': const Color(0xFFFFEB3B),
      'Cyan': const Color(0xFF00E5FF),
      'Green': const Color(0xFF69F0AE),
      'Orange': const Color(0xFFFFAB40),
      'Pink': const Color(0xFFFF80AB),
    };

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            title: const Text(
              'Subtitle Settings',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Size ─────────────────────────────────────────────
                  _subRow(
                    'Size',
                    Expanded(
                      child: Slider(
                        value: _s._subtitleSize,
                        min: 20,
                        max: 80,
                        thumbColor: const Color(0xFF7C3AED),
                        onChanged: (v) {
                          setDialog(() => _s._subtitleSize = v);
                          setState(() {});
                        },
                      ),
                    ),
                    '${_s._subtitleSize.toInt()}',
                  ),

                  // ── Delay (arrow buttons) ──────────────────────────
                  _subRow(
                    'Delay',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () {
                            final v = _s._subtitleDelay - 0.1;
                            setDialog(
                              () => _s._subtitleDelay = double.parse(
                                v.toStringAsFixed(1),
                              ),
                            );
                            if (_s._player.platform is NativePlayer) {
                              (_s._player.platform as NativePlayer).setProperty(
                                'sub-delay',
                                _s._subtitleDelay.toString(),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () {
                            final v = _s._subtitleDelay + 0.1;
                            setDialog(
                              () => _s._subtitleDelay = double.parse(
                                v.toStringAsFixed(1),
                              ),
                            );
                            if (_s._player.platform is NativePlayer) {
                              (_s._player.platform as NativePlayer).setProperty(
                                'sub-delay',
                                _s._subtitleDelay.toString(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    '${_s._subtitleDelay.toStringAsFixed(1)}s',
                  ),

                  // ── Text Color ─────────────────────────────────────
                  _subLabel('Text Color'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorOptions.entries.map((e) {
                      final selected =
                          _s._subtitleColor.toARGB32() == e.value.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          setDialog(() => _s._subtitleColor = e.value);
                          setState(() {});
                          SettingsService().setSubColor(e.value.toARGB32());
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF7C3AED)
                                  : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // ── Background Opacity ─────────────────────────────
                  _subRow(
                    'BG Opacity',
                    Expanded(
                      child: Slider(
                        value: _s._subtitleBgOpacity,
                        min: 0.0,
                        max: 1.0,
                        thumbColor: const Color(0xFF7C3AED),
                        onChanged: (v) {
                          setDialog(() => _s._subtitleBgOpacity = v);
                          setState(() {});
                        },
                      ),
                    ),
                    '${(_s._subtitleBgOpacity * 100).toInt()}%',
                  ),

                  // ── Position (bottom padding) ──────────────────────
                  _subRow(
                    'Position',
                    Expanded(
                      child: Slider(
                        value: _s._subtitleBottomPadding,
                        min: 0,
                        max: 120,
                        thumbColor: const Color(0xFF7C3AED),
                        onChanged: (v) {
                          setDialog(() => _s._subtitleBottomPadding = v);
                          setState(() {});
                        },
                      ),
                    ),
                    '${_s._subtitleBottomPadding.toInt()}',
                  ),

                  // ── Bold ───────────────────────────────────────────
                  Row(
                    children: [
                      const SizedBox(
                        width: 70,
                        child: Text(
                          'Bold',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _s._subtitleBold,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: (v) {
                          setDialog(() => _s._subtitleBold = v);
                          setState(() {});
                          SettingsService().setSubBold(v);
                        },
                      ),
                    ],
                  ),

                  // ── Font ───────────────────────────────────────────
                  _subLabel('Font'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: fonts.map((f) {
                      final selected = _s._subtitleFont == f;
                      return GestureDetector(
                        onTap: () {
                          setDialog(() => _s._subtitleFont = f);
                          setState(() {});
                          SettingsService().setSubFont(f);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF7C3AED)
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SettingsService().setSubSize(_s._subtitleSize);
                  SettingsService().setSubBgOpacity(_s._subtitleBgOpacity);
                  SettingsService().setSubBottomPadding(_s._subtitleBottomPadding);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF7C3AED)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _subRow(String label, Widget middle, String trailing) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        if (middle is Expanded) middle else middle,
        SizedBox(
          width: 44,
          child: Text(
            trailing,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _subLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Future<void> _loadSubtitlePrefs() async {
    final s = SettingsService();
    final size = await s.getSubSize(isDesktop: true);
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
        setState(() => _s._audioPinned = true);
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

    _s._hlsMasterUrl = url;
    _s._hlsMasterHeaders = headers;
    _s._hlsQualitiesNotifier.value = null;
    fetchHlsQualities(url, headers: headers).then((qs) {
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
    _s._currentQualityUrl = q.url;
    if (mounted) setState(() {});
    if (_s._hlsMasterHeaders != null && _s._player.platform is NativePlayer) {
      final ref =
          _s._hlsMasterHeaders!['Referer'] ?? _s._hlsMasterHeaders!['referer'];
      if (ref != null) {
        await (_s._player.platform as NativePlayer).setProperty('referrer', ref);
      }
    }
    await _s._player.open(Media(q.url, httpHeaders: _s._hlsMasterHeaders));
    if (pos.inSeconds > 0) await _s._player.seek(pos);
    _s._onMouseMove();
  }

}
