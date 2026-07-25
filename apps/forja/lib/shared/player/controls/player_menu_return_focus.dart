import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_server_stream_dialog.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';

FocusNode? _playerMenuReturnFocus;

bool _anyPlayerMenuOpen() {
  return PlayerStreamMenu.isShowing ||
      PlayerServerStreamDialog.isShowing ||
      PlayerPopupPanel.isShowing ||
      PlayerEpisodePanel.isShowing ||
      PlayerHubEpisodePanel.isShowing ||
      PlayerSourcesPanel.isShowing ||
      PlayerTorrentFilePanel.isShowing ||
      PlayerSubtitleSettingsDialog.isShowing;
}

bool _focusInPlayerTvMenu(FocusNode node) {
  FocusNode? current = node;
  while (current != null) {
    if (current.debugLabel == 'player-tv-menu') return true;
    current = current.parent;
  }
  return false;
}

/// Remember the chrome control that opened a player menu (TV). Kept across
/// drill-ins until the last overlay closes, then restored.
void playerMenuCaptureReturnFocus(BuildContext context) {
  final tv =
      ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips == true;
  if (!tv) return;
  if (_playerMenuReturnFocus != null) return;
  final node = FocusManager.instance.primaryFocus;
  if (node == null || !node.canRequestFocus) return;
  if (_focusInPlayerTvMenu(node)) return;
  _playerMenuReturnFocus = node;
}

/// After a menu/panel dismisses, refocus the opener if nothing else is open.
void playerMenuRestoreReturnFocus() {
  if (_playerMenuReturnFocus == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_anyPlayerMenuOpen()) return;
    final node = _playerMenuReturnFocus;
    _playerMenuReturnFocus = null;
    if (node == null || !node.canRequestFocus) return;
    node.requestFocus();
  });
}

/// Drop pending return focus without restoring (player exit).
void playerMenuClearReturnFocus() {
  _playerMenuReturnFocus = null;
}

/// True while a dismiss is about to restore the opener - don't steal to Play.
bool playerChromeHasPendingReturnFocus() => _playerMenuReturnFocus != null;
