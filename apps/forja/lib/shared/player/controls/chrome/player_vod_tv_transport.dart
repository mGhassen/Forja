import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';

/// Shared Android TV bottom transport for VOD (MediaKit + Exo).
///
/// Explicit neighbour FocusNodes — app-root directional policy no-ops ←/→.
class PlayerVodTvTransportRow extends StatelessWidget {
  const PlayerVodTvTransportRow({
    super.key,
    required this.btnSize,
    required this.iconSz,
    required this.isPlayingListenable,
    required this.positionListenable,
    required this.durationListenable,
    required this.playFocus,
    required this.rewindFocus,
    required this.forwardFocus,
    required this.transportPrevEpFocus,
    required this.transportNextEpFocus,
    required this.transportSourcesFocus,
    required this.transportStreamFocus,
    required this.transportEpisodesFocus,
    required this.transportAudioFocus,
    required this.transportSubsFocus,
    required this.transportQualityFocus,
    required this.transportSettingsFocus,
    required this.hasPrevEpisode,
    required this.hasNextEpisode,
    required this.hasTorrentSources,
    required this.hasStreamPicker,
    required this.hasEpisodePicker,
    required this.catalogSourceLines,
    required this.streamPickerLines,
    required this.onPlayPause,
    required this.onRewind10,
    required this.onForward10,
    required this.onPreviousEpisode,
    required this.onNextEpisode,
    required this.onUpFromTransport,
    required this.onFocusFirstRightTransport,
    required this.onFocusLeftOfRightTransport,
    required this.onFocusRightOfForward,
    required this.onOpenTorrentSources,
    required this.onOpenStreamPicker,
    required this.onOpenEpisodes,
    required this.onOpenAudio,
    required this.onOpenSubtitles,
    required this.onOpenQuality,
    required this.onOpenSettings,
  });

  final double btnSize;
  final double iconSz;
  final ValueListenable<bool> isPlayingListenable;
  final ValueListenable<Duration> positionListenable;
  final ValueListenable<Duration> durationListenable;

  final FocusNode playFocus;
  final FocusNode rewindFocus;
  final FocusNode forwardFocus;
  final FocusNode transportPrevEpFocus;
  final FocusNode transportNextEpFocus;
  final FocusNode transportSourcesFocus;
  final FocusNode transportStreamFocus;
  final FocusNode transportEpisodesFocus;
  final FocusNode transportAudioFocus;
  final FocusNode transportSubsFocus;
  final FocusNode transportQualityFocus;
  final FocusNode transportSettingsFocus;

  final bool hasPrevEpisode;
  final bool hasNextEpisode;
  final bool hasTorrentSources;
  final bool hasStreamPicker;
  final bool hasEpisodePicker;
  final ({String label, String? server})? catalogSourceLines;
  final ({String label, String? server})? streamPickerLines;

  final VoidCallback onPlayPause;
  final VoidCallback onRewind10;
  final VoidCallback onForward10;
  final VoidCallback onPreviousEpisode;
  final VoidCallback onNextEpisode;
  final VoidCallback onUpFromTransport;
  final VoidCallback onFocusFirstRightTransport;
  final VoidCallback onFocusLeftOfRightTransport;
  final VoidCallback onFocusRightOfForward;
  final VoidCallback onOpenTorrentSources;
  final void Function(BuildContext ctx) onOpenStreamPicker;
  final void Function(BuildContext ctx) onOpenEpisodes;
  final void Function(BuildContext ctx) onOpenAudio;
  final void Function(BuildContext ctx) onOpenSubtitles;
  final void Function(BuildContext ctx) onOpenQuality;
  final void Function(BuildContext ctx) onOpenSettings;

  @override
  Widget build(BuildContext context) {
    Widget ordered(int order, Widget child) => FocusTraversalOrder(
          order: NumericFocusOrder(order.toDouble()),
          child: child,
        );

    void focusAudio() => transportAudioFocus.requestFocus();
    void focusEpisodesOrAudio() {
      if (hasEpisodePicker) {
        transportEpisodesFocus.requestFocus();
      } else {
        focusAudio();
      }
    }

    void focusStreamOrAfter() {
      if (hasStreamPicker) {
        transportStreamFocus.requestFocus();
      } else {
        focusEpisodesOrAudio();
      }
    }

    void focusSourcesOrBefore() {
      if (hasTorrentSources) {
        transportSourcesFocus.requestFocus();
      } else {
        onFocusLeftOfRightTransport();
      }
    }

    void focusStreamOrBefore() {
      if (hasStreamPicker) {
        transportStreamFocus.requestFocus();
      } else {
        focusSourcesOrBefore();
      }
    }

    void focusEpisodesOrBefore() {
      if (hasEpisodePicker) {
        transportEpisodesFocus.requestFocus();
      } else {
        focusStreamOrBefore();
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ordered(
                3,
                ValueListenableBuilder<bool>(
                  valueListenable: isPlayingListenable,
                  builder: (context, playing, _) => PlayerFlatIconButton(
                    tvFocusable: true,
                    focusNode: playFocus,
                    onUpEdge: onUpFromTransport,
                    onRightEdge: () {
                      if (rewindFocus.canRequestFocus) {
                        rewindFocus.requestFocus();
                      }
                    },
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: btnSize,
                    iconSize: iconSz,
                    onPressed: onPlayPause,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                4,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: rewindFocus,
                  onUpEdge: onUpFromTransport,
                  onLeftEdge: () => playFocus.requestFocus(),
                  onRightEdge: () => forwardFocus.requestFocus(),
                  icon: Icons.replay_10_rounded,
                  tooltip: 'Back 10s',
                  size: btnSize,
                  iconSize: iconSz,
                  onPressed: onRewind10,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                5,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: forwardFocus,
                  onUpEdge: onUpFromTransport,
                  onLeftEdge: () => rewindFocus.requestFocus(),
                  onRightEdge: onFocusRightOfForward,
                  icon: Icons.forward_10_rounded,
                  tooltip: 'Forward 10s',
                  size: btnSize,
                  iconSize: iconSz,
                  onPressed: onForward10,
                ),
              ),
              if (hasPrevEpisode) ...[
                const SizedBox(width: 2),
                ordered(
                  6,
                  PlayerFlatIconButton(
                    tvFocusable: true,
                    focusNode: transportPrevEpFocus,
                    onUpEdge: onUpFromTransport,
                    onLeftEdge: () => forwardFocus.requestFocus(),
                    onRightEdge: () {
                      if (hasNextEpisode &&
                          transportNextEpFocus.canRequestFocus) {
                        transportNextEpFocus.requestFocus();
                      } else {
                        onFocusFirstRightTransport();
                      }
                    },
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Previous Episode',
                    size: btnSize,
                    iconSize: iconSz,
                    onPressed: onPreviousEpisode,
                  ),
                ),
              ],
              if (hasNextEpisode) ...[
                const SizedBox(width: 2),
                ordered(
                  7,
                  PlayerFlatIconButton(
                    tvFocusable: true,
                    focusNode: transportNextEpFocus,
                    onUpEdge: onUpFromTransport,
                    onLeftEdge: () {
                      if (hasPrevEpisode &&
                          transportPrevEpFocus.canRequestFocus) {
                        transportPrevEpFocus.requestFocus();
                      } else {
                        forwardFocus.requestFocus();
                      }
                    },
                    onRightEdge: onFocusFirstRightTransport,
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next Episode',
                    size: btnSize,
                    iconSize: iconSz,
                    onPressed: onNextEpisode,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              ExcludeFocus(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: positionListenable,
                  builder: (context, pos, _) =>
                      ValueListenableBuilder<Duration>(
                    valueListenable: durationListenable,
                    builder: (context, dur, _) => PlayerTimeRange(
                      position: pos,
                      duration: dur,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTorrentSources)
                ordered(
                  8,
                  PlayerSourcesPanelButton(
                    tvFocusable: true,
                    focusNode: transportSourcesFocus,
                    onUpEdge: onUpFromTransport,
                    onLeftEdge: onFocusLeftOfRightTransport,
                    onRightEdge: focusStreamOrAfter,
                    size: btnSize,
                    iconSize: iconSz,
                    label: catalogSourceLines!.label,
                    server: catalogSourceLines!.server,
                    onPressed: onOpenTorrentSources,
                  ),
                ),
              if (hasTorrentSources) const SizedBox(width: 2),
              if (hasStreamPicker)
                ordered(
                  9,
                  PlayerStreamPickerButton(
                    tvFocusable: true,
                    focusNode: transportStreamFocus,
                    onUpEdge: onUpFromTransport,
                    onLeftEdge: focusSourcesOrBefore,
                    onRightEdge: focusEpisodesOrAudio,
                    size: btnSize,
                    iconSize: iconSz - 2,
                    label: streamPickerLines!.label,
                    server: streamPickerLines!.server,
                    onPressedWithContext: onOpenStreamPicker,
                  ),
                ),
              if (hasStreamPicker) const SizedBox(width: 2),
              if (hasEpisodePicker)
                ordered(
                  10,
                  PlayerFlatIconButton(
                    tvFocusable: true,
                    focusNode: transportEpisodesFocus,
                    onUpEdge: onUpFromTransport,
                    onLeftEdge: focusStreamOrBefore,
                    onRightEdge: focusAudio,
                    icon: Icons.video_library_outlined,
                    size: btnSize,
                    iconSize: iconSz,
                    tooltip: 'Episodes',
                    onPressedWithContext: onOpenEpisodes,
                  ),
                ),
              if (hasEpisodePicker) const SizedBox(width: 2),
              ordered(
                11,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: transportAudioFocus,
                  onUpEdge: onUpFromTransport,
                  onLeftEdge: focusEpisodesOrBefore,
                  onRightEdge: () => transportSubsFocus.requestFocus(),
                  icon: Icons.audiotrack_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Audio',
                  onPressedWithContext: onOpenAudio,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                12,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: transportSubsFocus,
                  onUpEdge: onUpFromTransport,
                  onLeftEdge: focusAudio,
                  onRightEdge: () => transportQualityFocus.requestFocus(),
                  icon: Icons.subtitles_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Subtitles',
                  onPressedWithContext: onOpenSubtitles,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                13,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: transportQualityFocus,
                  onUpEdge: onUpFromTransport,
                  onLeftEdge: () => transportSubsFocus.requestFocus(),
                  onRightEdge: () => transportSettingsFocus.requestFocus(),
                  icon: Icons.hd_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Quality',
                  onPressedWithContext: onOpenQuality,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                14,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: transportSettingsFocus,
                  onUpEdge: onUpFromTransport,
                  onLeftEdge: () => transportQualityFocus.requestFocus(),
                  icon: Icons.settings_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Settings',
                  onPressedWithContext: onOpenSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
