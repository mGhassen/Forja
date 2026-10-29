import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/player_phone_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Phone (touch) VOD player chrome — shared by the MediaKit and Exo screens.
//  Leanback and desktop keep their own transport rows; hosts gate on phone.
// ─────────────────────────────────────────────────────────────────────────────

/// Keys for widget tests and on-device inspection.
abstract final class PlayerPhoneKeys {
  static const nextEpisode = ValueKey('player-phone-next-episode');
  static const episodes = ValueKey('player-phone-episodes');
  static const audioSubtitles = ValueKey('player-phone-audio-subtitles');
  static const more = ValueKey('player-phone-more');
  static const playPause = ValueKey('player-phone-play-pause');
}

/// 48 dp phone action: icon, plus a short label when [showLabel].
class PlayerPhoneActionButton extends StatelessWidget {
  const PlayerPhoneActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.showLabel = true,
    this.onPressed,
    this.onPressedWithContext,
    this.active = false,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final String label;
  final bool showLabel;
  final VoidCallback? onPressed;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: PlayerPhoneTokens.touchTarget,
        minHeight: PlayerPhoneTokens.touchTarget,
      ),
      child: PlayerFlatIconButton(
        icon: icon,
        label: showLabel ? label : null,
        tooltip: label,
        active: active,
        size: PlayerPhoneTokens.touchTarget,
        iconSize: PlayerPhoneTokens.actionIconSize,
        maxLabelWidth: PlayerPhoneTokens.actionLabelMaxWidth,
        onPressed: onPressed,
        onPressedWithContext: onPressedWithContext,
      ),
    );
  }
}

/// Phone bottom row under the seek bar.
///
/// Left: optional play/pause (only while the center cluster is covered by the
/// status overlay), time, next episode. Right: source, Episodes,
/// Audio & subtitles, More. Everything else lives in the More menu.
class PlayerPhoneTransportRow extends StatelessWidget {
  const PlayerPhoneTransportRow({
    super.key,
    this.time,
    this.playing,
    this.onPlayPause,
    this.onNextEpisode,
    this.source,
    this.onEpisodes,
    required this.onAudioSubtitles,
    required this.onMore,
  });

  /// Position / duration text; null when the host shows time elsewhere.
  final Widget? time;

  /// Non-null shows a play/pause action (center cluster hidden).
  final bool? playing;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNextEpisode;

  /// Host source / stream picker button (already labeled).
  final Widget? source;
  final ValueChanged<BuildContext>? onEpisodes;
  final ValueChanged<BuildContext> onAudioSubtitles;
  final ValueChanged<BuildContext> onMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labels =
            constraints.maxWidth >= PlayerPhoneTokens.labeledActionsMinWidth;
        const gap = SizedBox(width: PlayerPhoneTokens.actionGap);
        return Row(
          children: [
            if (playing != null && onPlayPause != null) ...[
              PlayerPhoneActionButton(
                key: PlayerPhoneKeys.playPause,
                icon: playing! ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: playing! ? 'Pause' : 'Play',
                showLabel: false,
                onPressed: onPlayPause,
              ),
              gap,
            ],
            if (time != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: time,
              ),
              gap,
            ],
            if (onNextEpisode != null)
              PlayerPhoneActionButton(
                key: PlayerPhoneKeys.nextEpisode,
                icon: Icons.skip_next_rounded,
                label: 'Next episode',
                showLabel: labels,
                onPressed: onNextEpisode,
              ),
            const Spacer(),
            if (source != null) ...[Flexible(child: source!), gap],
            if (onEpisodes != null) ...[
              PlayerPhoneActionButton(
                key: PlayerPhoneKeys.episodes,
                icon: Icons.video_library_outlined,
                label: 'Episodes',
                showLabel: labels,
                onPressedWithContext: onEpisodes,
              ),
              gap,
            ],
            PlayerPhoneActionButton(
              key: PlayerPhoneKeys.audioSubtitles,
              icon: Icons.subtitles_outlined,
              label: 'Audio & subtitles',
              showLabel: labels,
              onPressedWithContext: onAudioSubtitles,
            ),
            gap,
            PlayerPhoneActionButton(
              key: PlayerPhoneKeys.more,
              icon: Icons.more_horiz_rounded,
              label: 'More',
              showLabel: false,
              onPressedWithContext: onMore,
            ),
          ],
        );
      },
    );
  }
}

/// One row in a phone action menu (More, Audio & subtitles).
class PlayerPhoneMenuEntry {
  const PlayerPhoneMenuEntry({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;

  /// Called after the menu closes, with the menu's anchor so follow-up
  /// panels open in the same place.
  final ValueChanged<BuildContext> onSelected;
}

/// Floating list of [entries] anchored to [anchorContext].
void showPlayerPhoneActionMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required String title,
  required IconData icon,
  required List<PlayerPhoneMenuEntry> entries,
}) {
  unawaited(
    PlayerPopupPanel.show(
      context: context,
      title: title,
      leadingIcon: icon,
      anchorContext: anchorContext,
      width: 320,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            PlayerPopupNavRow(
              key: ValueKey('player-phone-menu-${entries[i].title}'),
              icon: entries[i].icon,
              title: entries[i].title,
              subtitle: entries[i].subtitle,
              value: entries[i].value,
              onTap: () {
                PlayerPopupPanel.dismiss();
                if (anchorContext.mounted) {
                  entries[i].onSelected(anchorContext);
                }
              },
            ),
          ],
        ],
      ),
    ),
  );
}

/// Volume page for the phone More menu: slider (0…[maxVolume]) + mute.
void showPlayerPhoneVolumePanel({
  required BuildContext context,
  required BuildContext anchorContext,
  required double Function() volume,
  required double maxVolume,
  required ValueChanged<double> onChanged,
  VoidCallback? onBack,
}) {
  double? beforeMute;
  unawaited(
    PlayerPopupPanel.show(
      context: context,
      title: 'Volume',
      leadingIcon: Icons.volume_up_rounded,
      anchorContext: anchorContext,
      width: 320,
      onBack: onBack,
      child: StatefulBuilder(
        builder: (context, setPage) {
          final v = volume().clamp(0.0, maxVolume);
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          inactiveTrackColor: ForjaShellColors.borderSubtle,
                          activeTrackColor: ForjaShellColors.textPrimary,
                          thumbColor: ForjaShellColors.textPrimary,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          key: const ValueKey('player-phone-volume-slider'),
                          value: v,
                          min: 0,
                          max: maxVolume,
                          onChanged: (next) {
                            onChanged(next);
                            setPage(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: PlayerPhoneTokens.touchTarget,
                      child: Text(
                        '${v.round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: ForjaShellColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PlayerPopupOptionChip(
                  label: v == 0 ? 'Unmute' : 'Mute',
                  selected: v == 0,
                  expanded: true,
                  onTap: () {
                    if (v > 0) {
                      beforeMute = v;
                      onChanged(0);
                    } else {
                      onChanged(beforeMute ?? 100);
                    }
                    setPage(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Double-tap seek
// ─────────────────────────────────────────────────────────────────────────────

/// Accumulates double-tap seeks into one burst (YouTube-style).
///
/// The first double tap on a side seeks one step. While the burst is live,
/// every further tap on that side adds a step: a single tap adds one, a
/// double tap adds two. The target is computed from the position where the
/// burst began, so taps faster than the player reports position still add up.
class PlayerTapSeekBurst {
  PlayerTapSeekBurst({
    this.step = const Duration(seconds: PlayerPhoneTokens.seekStepSeconds),
    this.window = PlayerPhoneTokens.seekBurstWindow,
  });

  final Duration step;
  final Duration window;

  bool _forward = true;
  int _steps = 0;
  Duration _base = Duration.zero;
  DateTime? _last;

  bool get forward => _forward;
  int get steps => _steps;
  int get totalSeconds => _steps * step.inSeconds;

  bool isLive(DateTime now, {bool? forward}) {
    final last = _last;
    if (last == null || _steps == 0) return false;
    if (now.difference(last) > window) return false;
    return forward == null || forward == _forward;
  }

  /// Double tap on one side. Returns the seek target.
  Duration doubleTap({
    required bool forward,
    required DateTime now,
    required Duration position,
    required Duration duration,
  }) {
    if (isLive(now, forward: forward)) {
      _steps += 2;
    } else {
      _forward = forward;
      _base = position;
      _steps = 1;
    }
    _last = now;
    return _target(duration);
  }

  /// Single tap. Returns the seek target when it extends a live burst on the
  /// same side; null means the tap is an ordinary tap (toggle chrome).
  Duration? singleTap({
    required bool forward,
    required DateTime now,
    required Duration duration,
  }) {
    if (!isLive(now, forward: forward)) return null;
    _steps += 1;
    _last = now;
    return _target(duration);
  }

  void reset() {
    _steps = 0;
    _last = null;
  }

  Duration _target(Duration duration) {
    final delta = step * _steps;
    var t = _forward ? _base + delta : _base - delta;
    if (t < Duration.zero) t = Duration.zero;
    if (duration > Duration.zero && t > duration) t = duration;
    return t;
  }
}

/// Seek feedback for a double-tap burst: tinted side, ripple at the tap,
/// and a "+30 s" bubble. Bump [pulse] on every tap to replay the ripple.
class PlayerDoubleTapSeekFeedback extends StatefulWidget {
  const PlayerDoubleTapSeekFeedback({
    super.key,
    required this.forward,
    required this.seconds,
    required this.tapPosition,
    required this.pulse,
  });

  final bool forward;
  final int seconds;
  final Offset tapPosition;
  final int pulse;

  static String label({required bool forward, required int seconds}) =>
      '${forward ? '+' : '-'}$seconds s';

  @override
  State<PlayerDoubleTapSeekFeedback> createState() =>
      _PlayerDoubleTapSeekFeedbackState();
}

class _PlayerDoubleTapSeekFeedbackState
    extends State<PlayerDoubleTapSeekFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: PlayerPhoneTokens.seekRippleDuration,
  )..forward();

  @override
  void didUpdateWidget(covariant PlayerDoubleTapSeekFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _ripple.forward(from: 0);
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forward = widget.forward;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final sideW = w * PlayerPhoneTokens.seekSideWidthFactor;
          final h = constraints.maxHeight;
          const d = PlayerPhoneTokens.seekRippleDiameter;
          return Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: forward ? null : 0,
                right: forward ? 0 : null,
                width: sideW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ForjaShellColors.inkSplash,
                    borderRadius: BorderRadius.horizontal(
                      left: forward ? Radius.circular(h / 2) : Radius.zero,
                      right: forward ? Radius.zero : Radius.circular(h / 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: widget.tapPosition.dx - d / 2,
                top: widget.tapPosition.dy - d / 2,
                width: d,
                height: d,
                child: AnimatedBuilder(
                  animation: _ripple,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(_ripple.value);
                    return Opacity(
                      opacity: (1 - t) * 0.6,
                      child: Transform.scale(
                        scale: 0.3 + 0.7 * t,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ForjaShellColors.chipSelectedBg,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: forward ? null : 0,
                right: forward ? 0 : null,
                width: sideW,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        forward
                            ? Icons.fast_forward_rounded
                            : Icons.fast_rewind_rounded,
                        color: Colors.white,
                        size: PlayerPhoneTokens.seekBubbleIconSize,
                      ),
                      const SizedBox(height: 4),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: PlayerPopupTokens.shellBg,
                          borderRadius: BorderRadius.circular(
                            PlayerPopupTokens.chipRadius,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            PlayerDoubleTapSeekFeedback.label(
                              forward: forward,
                              seconds: widget.seconds,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: PlayerPhoneTokens.seekBubbleFontSize,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
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
