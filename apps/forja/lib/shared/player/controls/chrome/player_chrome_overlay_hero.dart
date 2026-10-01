part of 'player_chrome_overlay.dart';

class PlayerTitleMeta extends StatelessWidget {
  const PlayerTitleMeta({
    super.key,
    required this.title,
    this.movie,
    this.season,
    this.episode,
  });

  final String title;
  final Movie? movie;
  final int? season;
  final int? episode;

  String? _metaLine() {
    if (season != null && episode != null) return 'S$season E$episode';
    final m = movie;
    if (m == null) return null;
    final parts = <String>[];
    if (m.genres.isNotEmpty) parts.add(m.genres.take(2).join(' | '));
    if (m.runtime > 0) {
      parts.add(WatchProgressBar.formatMinutes(m.runtime * 60000));
    }
    if (m.releaseDate.length >= 4) parts.add(m.releaseDate.substring(0, 4));
    return parts.isEmpty ? null : parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaLine();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: ShellScope.metricsOf(context).usesTvDensity
                ? ShellTokens.playerChromeHeroTitleFontSizeTv
                : ShellTokens.playerChromeHeroTitleFontSize,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: ShellScope.metricsOf(context).usesTvDensity
                  ? ShellTokens.playerChromeMetaFontSizeTv
                  : ShellTokens.playerChromeMetaFontSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class PlayerPausedHero extends StatelessWidget {
  const PlayerPausedHero({
    super.key,
    required this.movie,
    this.season,
    this.episode,
    this.episodeLine,
    this.episodeOverview,
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? episodeLine;
  final String? episodeOverview;

  String? get _episodeLine {
    if (episodeLine != null && episodeLine!.isNotEmpty) return episodeLine;
    if (episode == null) return null;
    if (season == null) return 'Episode $episode';
    return 'S$season E$episode';
  }

  @override
  Widget build(BuildContext context) {
    final rawOverview = (episodeOverview?.trim().isNotEmpty == true)
        ? episodeOverview!
        : movie.overview;
    // Hub callers sometimes pass "Episode N" as overview — same string as
    // [_episodeLine] — which stacked two identical lines under the title.
    final episode = _episodeLine;
    final overview = (episode != null &&
            rawOverview.trim().toLowerCase() == episode.trim().toLowerCase())
        ? ''
        : rawOverview;
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final padding = tv
        ? ShellTokens.playerPausedHeroPaddingTv
        : ShellTokens.playerPausedHeroPadding;
    final maxWidth = tv
        ? ShellTokens.playerPausedHeroMaxWidthTv
        : ShellTokens.playerPausedHeroMaxWidth;
    final logoMaxHeight = tv
        ? ShellTokens.playerPausedHeroLogoMaxHeightTv
        : ShellTokens.playerPausedHeroLogoMaxHeight;

    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroTitle(
              title: movie.title,
              logoUrl: tmdbLogoImageUrlFromPath(movie.logoPath),
              style: HeroTitleStyle.details,
              logoMaxHeight: logoMaxHeight,
              tvDensity: tv,
              plainTitle:
                  ShellScope.inputPolicyOf(context).useFocusableMoodChips,
              selectable: shellDesktopTextSelect(context),
            ),
            const SizedBox(height: 10),
            MetaLine(
              releaseDate: movie.releaseDate,
              mediaType: movie.mediaType,
              runtimeMinutes: movie.runtime,
              voteAverage: movie.voteAverage,
              genres: movie.genres,
            ),
            if (episode != null) ...[
              const SizedBox(height: 6),
              Text(
                episode,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: tv
                      ? ShellTokens.playerChromeMetaFontSizeTv
                      : ShellTokens.playerChromeStatusFontSize,
                ),
              ),
            ],
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 10),
              HeroOverviewText(
                overview: overview,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: tv
                      ? ShellTokens.playerChromeMetaFontSizeTv
                      : ShellTokens.playerChromeStatusFontSize,
                  height: 1.45,
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlayerTimeRange extends StatelessWidget {
  const PlayerTimeRange({
    super.key,
    required this.position,
    required this.duration,
    this.fontSize = 12,
  });

  final Duration position;
  final Duration duration;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fs = playerChromeScale(context, fontSize);
    return Text(
      '${_fmt(position)} / ${_fmt(duration)}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: ShellPaintScope.usesTvDensityOf(context)
            ? ShellTokens.playerChromeTimeFontSizeTv
            : fs,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class PlayerCenterActionButton extends StatefulWidget {
  const PlayerCenterActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 64,
    this.iconSize = 32,
    this.showSpinner = false,
    this.tvFocusable = false,
    this.focusNode,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final bool showSpinner;
  final bool tvFocusable;
  final FocusNode? focusNode;

  @override
  State<PlayerCenterActionButton> createState() =>
      _PlayerCenterActionButtonState();
}

class _PlayerCenterActionButtonState extends State<PlayerCenterActionButton> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _pressed = false;
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
  }

  Widget _buildCore({required bool highlight, required bool tvFocused}) {
    final borderColor = tvFocused
        ? ForjaShellColors.brandGreen
        : Colors.white.withValues(alpha: highlight ? 0.35 : 0.2);
    final fillAlpha = tvFocused ? 0.16 : (highlight ? 0.22 : 0.14);
    final iconColor = tvFocused ? ForjaShellColors.brandGreen : Colors.white;
    final size = playerChromeScale(context, widget.size);
    final iconSize = playerChromeScale(context, widget.iconSize);
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : (highlight ? 1.06 : 1.0),
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: fillAlpha),
            border: Border.all(color: borderColor, width: tvFocused ? 1.5 : 1),
          ),
          child: widget.showSpinner
              ? Center(
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Icon(
                  widget.icon,
                  color: iconColor,
                  size: iconSize,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tvFocusable) {
      final highlight = playerChromeFocusActive(
        context,
        tvFocusable: true,
        hovered: false,
        focused: _focused,
      );
      final tvFocused = playerChromeTvFocused(
        context,
        tvFocusable: true,
        focused: _focused,
      );
      return FocusableControl(
        focusNode: widget.focusNode,
        onTap: widget.onPressed,
        borderRadius: playerChromeScale(context, widget.size) / 2,
        scaleOnFocus: 1.0,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) {
          if (hovered) playerChromeCancelSeekScrubs();
        },
        child: _buildCore(highlight: highlight, tvFocused: tvFocused),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        // Center ±10 / play sit above the seek bar - drop scrub or the thumb
        // stays magnetized to the cursor over these controls.
        playerChromeCancelSeekScrubs();
        final policy =
            ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
        if (!policy.scaleOnHover) return;
        _setHovered(true);
      },
      onExit: (_) {
        final policy =
            ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
        if (!policy.scaleOnHover) return;
        _setHovered(false);
        setState(() => _pressed = false);
      },
      child: ListenableBuilder(
        listenable: _hoveredN,
        builder: (context, _) {
          final highlight = playerChromeFocusActive(
            context,
            tvFocusable: false,
            hovered: _hoveredN.value,
            focused: false,
          );
          return _buildCore(highlight: highlight, tvFocused: false);
        },
      ),
    );
  }
}

/// Inline volume control: mute button + horizontal slider in the player row (IPTV-style).
class PlayerVolumeControl extends StatefulWidget {
  const PlayerVolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.maxVolume = 150,
    this.onInteraction,
    this.onDragStart,
    this.onDragEnd,
    this.size = 40,
    this.iconSize = 22,
    this.compact = false,
    this.tvFocusable = false,
  });

  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final double maxVolume;
  final VoidCallback? onInteraction;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double size;
  final double iconSize;
  final bool compact;
  final bool tvFocusable;

  @override
  State<PlayerVolumeControl> createState() => _PlayerVolumeControlState();
}

class _PlayerVolumeControlState extends State<PlayerVolumeControl> {
  final ValueNotifier<bool> _hoveringN = ValueNotifier(false);
  bool _sliderPinned = false;
  double? _volumeBeforeMute;
  Timer? _hideSliderTimer;

  bool _showSliderFor(bool hovering) => hovering || _sliderPinned;

  void _setHovering(bool hovering) {
    if (_hoveringN.value == hovering) return;
    _hoveringN.value = hovering;
  }

  double get _sliderWidth =>
      playerChromeScale(context, widget.compact ? 110.0 : 160.0);

  IconData _iconFor(double vol) {
    if (vol == 0) return Icons.volume_off_rounded;
    if (vol < 50) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  void dispose() {
    _hideSliderTimer?.cancel();
    _hoveringN.dispose();
    super.dispose();
  }

  void _setVolume(double v) {
    widget.onVolumeChanged(v.clamp(0, widget.maxVolume));
    widget.onInteraction?.call();
  }

  void _toggleMute() {
    if (widget.volume > 0) {
      _volumeBeforeMute = widget.volume;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute ?? 100);
    }
  }

  void _toggleSliderPinned() {
    setState(() => _sliderPinned = !_sliderPinned);
    if (_sliderPinned) {
      _hideSliderTimer?.cancel();
    } else {
      _scheduleHideSlider();
    }
    widget.onInteraction?.call();
  }

  void _scheduleHideSlider() {
    _hideSliderTimer?.cancel();
    _hideSliderTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _sliderPinned = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        playerChromeCancelSeekScrubs();
        _setHovering(true);
        _hideSliderTimer?.cancel();
      },
      onExit: (_) {
        _setHovering(false);
        _scheduleHideSlider();
      },
      child: ListenableBuilder(
        listenable: _hoveringN,
        builder: (context, _) {
          final showSlider = _showSliderFor(_hoveringN.value);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onLongPress: _toggleSliderPinned,
                child: PlayerFlatIconButton(
                  icon: _iconFor(widget.volume),
                  tooltip: widget.volume > 0 ? 'Mute' : 'Unmute',
                  size: widget.size,
                  iconSize: widget.iconSize,
                  tvFocusable: widget.tvFocusable,
                  onPressed: _toggleMute,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: showSlider ? _sliderWidth : 0,
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          inactiveTrackColor: Colors.white24,
                          activeTrackColor: Colors.white,
                          thumbColor: Colors.white,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                        ),
                        child: Slider(
                          value: widget.volume.clamp(0, widget.maxVolume),
                          min: 0,
                          max: widget.maxVolume,
                          onChangeStart: (_) {
                            widget.onDragStart?.call();
                            _hideSliderTimer?.cancel();
                          },
                          onChanged: (v) {
                            _setVolume(v);
                            _scheduleHideSlider();
                          },
                          onChangeEnd: (_) {
                            widget.onDragEnd?.call();
                            _scheduleHideSlider();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PlayerOverlayGradient extends StatelessWidget {
  const PlayerOverlayGradient({super.key, required this.isTop});

  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: isTop ? 120 : 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: isTop ? 0.72 : 0.85),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

