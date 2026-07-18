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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
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
              fontSize: 12,
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
    final overview = (episodeOverview?.trim().isNotEmpty == true)
        ? episodeOverview!
        : movie.overview;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroTitle(
              movie: movie,
              logoUrl: movie.logoPath.isNotEmpty
                  ? TmdbApi.getImageUrl(movie.logoPath)
                  : null,
              style: HeroTitleStyle.details,
            ),
            const SizedBox(height: 10),
            HeroMetaLine(movie: movie, style: HeroMetaStyle.details),
            if (_episodeLine != null) ...[
              const SizedBox(height: 6),
              Text(
                _episodeLine!,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 10),
              HeroOverviewText(
                overview: overview,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
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
    return Text(
      '${_fmt(position)} / ${_fmt(duration)}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: fontSize,
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
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  Widget _buildCore({required bool highlight, required bool tvFocused}) {
    final borderColor = tvFocused
        ? ForjaShellColors.brandGreen
        : Colors.white.withValues(alpha: highlight ? 0.35 : 0.2);
    final fillAlpha = tvFocused ? 0.16 : (highlight ? 0.22 : 0.14);
    final iconColor = tvFocused ? ForjaShellColors.brandGreen : Colors.white;
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : (highlight ? 1.06 : 1.0),
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: fillAlpha),
            border: Border.all(color: borderColor, width: tvFocused ? 1.5 : 1),
          ),
          child: widget.showSpinner
              ? Center(
                  child: SizedBox(
                    width: widget.iconSize,
                    height: widget.iconSize,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Icon(
                  widget.icon,
                  color: iconColor,
                  size: widget.iconSize,
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
        tvFocusable: true,
        focused: _focused,
      );
      return FocusableControl(
        focusNode: widget.focusNode,
        onTap: widget.onPressed,
        borderRadius: widget.size / 2,
        scaleOnFocus: 1.06,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: (hovered) {
          if (hovered) playerChromeCancelSeekScrubs();
        },
        child: _buildCore(highlight: highlight, tvFocused: tvFocused),
      );
    }

    final highlight = playerChromeFocusActive(
      context,
      tvFocusable: false,
      hovered: _hovered,
      focused: false,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        // Center ±10 / play sit above the seek bar — drop scrub or the thumb
        // stays magnetized to the cursor over these controls.
        playerChromeCancelSeekScrubs();
        final policy =
            ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
        if (!policy.scaleOnHover) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        final policy =
            ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
        if (!policy.scaleOnHover) return;
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: _buildCore(highlight: highlight, tvFocused: false),
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
  bool _hovering = false;
  bool _sliderPinned = false;
  double? _volumeBeforeMute;
  Timer? _hideSliderTimer;

  bool get _showSlider => _hovering || _sliderPinned;

  double get _sliderWidth => widget.compact ? 110.0 : 160.0;

  IconData _iconFor(double vol) {
    if (vol == 0) return Icons.volume_off_rounded;
    if (vol < 50) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  void dispose() {
    _hideSliderTimer?.cancel();
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
        setState(() => _hovering = true);
        _hideSliderTimer?.cancel();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _scheduleHideSlider();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onLongPress: _toggleSliderPinned,
            child: PlayerFlatIconButton(
              icon: _iconFor(widget.volume),
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
              width: _showSlider ? _sliderWidth : 0,
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

