import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

class PlayerEpisodeMenu {
  static Future<void> show(
    BuildContext context, {
    required Movie movie,
    required int currentSeason,
    required int currentEpisode,
    required Future<void> Function(int season, int episode) onEpisodeSelected,
    BuildContext? anchorContext,
    Uint8List? frozenFrame,
  }) async {
    PlayerPopupPanel.dismiss();
    await PlayerEpisodePanel.show(
      context: context,
      movie: movie,
      currentSeason: currentSeason,
      currentEpisode: currentEpisode,
      onEpisodeSelected: onEpisodeSelected,
      frozenFrame: frozenFrame,
    );
  }
}
