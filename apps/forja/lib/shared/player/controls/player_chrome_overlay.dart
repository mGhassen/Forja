import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/hero/hero_meta_line.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';

class PlayerFlatIconButton extends StatelessWidget {
  const PlayerFlatIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onPressedWithContext,
    this.label,
    this.tooltip,
    this.active = false,
    this.size = 40,
    this.iconSize = 22,
    this.tvFocusable = false,
    this.focusNode,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final VoidCallback? onPressed;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final String? label;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;
  final bool tvFocusable;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final onTap = onPressedWithContext != null
        ? () => onPressedWithContext!(context)
        : onPressed;
    final child = Material(
      color: active ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
      shape: label == null ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        customBorder: label == null ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: label == null ? size : null,
          height: size,
          child: label == null
              ? Icon(icon, color: Colors.white, size: iconSize)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: iconSize - 2),
                      const SizedBox(width: 6),
                      Text(label!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
        ),
      ),
    );
    final button = tvFocusable
        ? FocusableControl(
            focusNode: focusNode,
            onTap: onTap,
            borderRadius: label == null ? size / 2 : 8,
            child: child,
          )
        : child;
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Unified stream source control — one pill showing the active server/source.
class PlayerStreamPickerButton extends StatelessWidget {
  const PlayerStreamPickerButton({
    super.key,
    required this.label,
    required this.onPressedWithContext,
    this.enabled = true,
    this.size = 40,
    this.iconSize = 18,
    this.tvFocusable = false,
    this.focusNode,
  });

  final String label;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final bool enabled;
  final double size;
  final double iconSize;
  final bool tvFocusable;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final onTap = enabled && onPressedWithContext != null
        ? () => onPressedWithContext!(context)
        : null;
    final child = Material(
      color: Colors.white.withValues(alpha: enabled ? 0.1 : 0.05),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size, maxWidth: 168),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.45),
                  size: iconSize,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.45),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final button = tvFocusable
        ? FocusableControl(
            focusNode: focusNode,
            onTap: onTap,
            borderRadius: 20,
            child: child,
          )
        : child;
    return Tooltip(message: 'Stream source', child: button);
  }
}

class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    this.season,
    this.episode,
    this.episodeLine,
    this.statusMessage,
    this.statusActions,
    required this.onBack,
    this.trailing,
    this.tvFocusable = false,
  });

  final String title;
  final int? season;
  final int? episode;
  final String? episodeLine;
  final String? statusMessage;
  final Widget? statusActions;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool tvFocusable;

  String? get _episodeLine {
    if (episodeLine != null && episodeLine!.isNotEmpty) return episodeLine;
    if (episode == null) return null;
    if (season == null) return 'Episode $episode';
    return 'S$season E$episode';
  }

  static double topPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 6;
    }
    return MediaQuery.paddingOf(context).top + 6;
  }

  static double totalHeight(
    BuildContext context, {
    bool hasStatusMessage = false,
    bool hasStatusActions = false,
  }) {
    var height = topPadding(context) + 44 + 6;
    if (hasStatusMessage) height += 20;
    if (hasStatusActions) height += 30;
    return height;
  }

  bool get _hasStatusMessage =>
      statusMessage != null && statusMessage!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, topPadding(context), 8, 6),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayerFlatIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              size: 44,
              tvFocusable: tvFocusable,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_episodeLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _episodeLine!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ForjaShellColors.cinematic.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_hasStatusMessage) ...[
                    const SizedBox(height: 6),
                    Text(
                      statusMessage!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (statusActions != null) ...[
                    const SizedBox(height: 8),
                    statusActions!,
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const SizedBox(width: 44),
          ],
        ),
    );
  }
}

class PlayerTopStatusActions extends StatelessWidget {
  const PlayerTopStatusActions({
    super.key,
    required this.onRetry,
    this.onStream,
    this.streamEnabled = true,
  });

  final VoidCallback onRetry;
  final VoidCallback? onStream;
  final bool streamEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        _link('Retry', onRetry),
        if (onStream != null)
          _link('Stream', streamEnabled ? onStream! : () {}),
      ],
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class PlayerTopBarActions extends StatelessWidget {
  const PlayerTopBarActions({
    super.key,
    this.onCast,
    this.showCast = false,
    this.onPip,
    this.showPip = false,
    this.pipActive = false,
    this.onPlayer,
    this.showPlayer = false,
  });

  final VoidCallback? onCast;
  final bool showCast;
  final VoidCallback? onPip;
  final bool showPip;
  final bool pipActive;
  final ValueChanged<BuildContext>? onPlayer;
  final bool showPlayer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPlayer && onPlayer != null)
          PlayerFlatIconButton(
            icon: Icons.smart_display_outlined,
            tooltip: 'Player',
            onPressedWithContext: onPlayer!,
            size: 44,
          ),
        if (showCast && onCast != null)
          PlayerFlatIconButton(
            icon: Icons.cast_rounded,
            tooltip: 'Cast',
            onPressed: onCast!,
            size: 44,
          ),
        if (showPip && onPip != null)
          PlayerFlatIconButton(
            icon: pipActive
                ? Icons.picture_in_picture_alt_rounded
                : Icons.picture_in_picture_rounded,
            tooltip: 'Picture in Picture',
            onPressed: onPip!,
            size: 44,
          ),
      ],
    );
  }
}

void _showCastFeedback(
  BuildContext context, {
  PlayerStatusController? statusController,
  required String message,
  StatusRouletteKind kind = StatusRouletteKind.info,
}) {
  if (statusController != null) {
    statusController.upsert(
      'cast',
      message,
      kind: kind,
      dismissAfter: const Duration(seconds: 3),
    );
    return;
  }
  if (!context.mounted) return;
  final toastKind = switch (kind) {
    StatusRouletteKind.success => ForjaToastKind.success,
    StatusRouletteKind.failed => ForjaToastKind.error,
    StatusRouletteKind.loading => ForjaToastKind.info,
    StatusRouletteKind.info => ForjaToastKind.info,
  };
  ForjaToast.show(message, kind: toastKind, duration: const Duration(seconds: 3));
}

String _castTargetLabel(CastTarget target) =>
    target == CastTarget.airplay ? 'AirPlay' : 'Chromecast';

Future<void> showPlayerCastPicker(
  BuildContext context, {
  required String? streamUrl,
  required String title,
  Map<String, String>? headers,
  PlayerStatusController? statusController,
}) async {
  final casting = CastingService.instance;
  final canCast = casting.isAirPlayAvailable || casting.isChromecastAvailable;
  if (!canCast) {
    _showCastFeedback(
      context,
      statusController: statusController,
      message: 'Casting is not supported on this device',
      kind: StatusRouletteKind.failed,
    );
    return;
  }

  if (streamUrl == null || streamUrl.isEmpty) {
    _showCastFeedback(
      context,
      statusController: statusController,
      message: 'No stream to cast',
      kind: StatusRouletteKind.failed,
    );
    return;
  }

  CastTarget? target;
  if (casting.isAirPlayAvailable && casting.isChromecastAvailable) {
    target = await showMenu<CastTarget>(
      context: context,
      position: const RelativeRect.fromLTRB(9999, 56, 16, 0),
      items: [
        const PopupMenuItem(
          value: CastTarget.airplay,
          child: Text('AirPlay'),
        ),
        const PopupMenuItem(
          value: CastTarget.chromecast,
          child: Text('Chromecast'),
        ),
      ],
    );
    if (target == null || !context.mounted) return;
  } else if (casting.isAirPlayAvailable) {
    target = CastTarget.airplay;
  } else {
    target = CastTarget.chromecast;
  }

  final label = _castTargetLabel(target);
  _showCastFeedback(
    context,
    statusController: statusController,
    message: 'Starting $label…',
    kind: StatusRouletteKind.loading,
  );

  final started = await casting.castUrl(
    url: streamUrl,
    target: target,
    headers: headers,
    title: title,
  );

  if (!context.mounted) return;

  if (started) {
    _showCastFeedback(
      context,
      statusController: statusController,
      message: 'Casting to $label',
      kind: StatusRouletteKind.success,
    );
    return;
  }

  _showCastFeedback(
    context,
    statusController: statusController,
    message: '$label is not available yet',
    kind: StatusRouletteKind.failed,
  );
}

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

  Widget _buildCore({required bool highlight}) {
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
            color: Colors.white.withValues(alpha: highlight ? 0.22 : 0.14),
            border: Border.all(
              color: Colors.white.withValues(alpha: highlight ? 0.35 : 0.2),
            ),
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
                  color: Colors.white,
                  size: widget.iconSize,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

    if (widget.tvFocusable) {
      final highlight = ShellInputPolicy.interactiveActive(
        policy,
        hovered: false,
        focused: _focused,
      );
      return FocusableControl(
        focusNode: widget.focusNode,
        onTap: widget.onPressed,
        borderRadius: widget.size / 2,
        scaleOnFocus: 1.0,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: _buildCore(highlight: highlight),
      );
    }

    final highlight = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: false,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!policy.scaleOnHover) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!policy.scaleOnHover) return;
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: _buildCore(highlight: highlight),
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
