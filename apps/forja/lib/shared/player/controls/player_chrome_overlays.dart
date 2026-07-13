import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// D-pad scope for player side panels (episodes, sources, stream list).
Widget playerSidePanelTvScope({
  required BuildContext context,
  required VoidCallback onClose,
  required Widget child,
}) {
  final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
  if (!tv) return child;
  return FocusTraversalGroup(
    policy: ReadingOrderTraversalPolicy(),
    child: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    ),
  );
}

/// Dismisses the topmost player chrome overlay (menus, panels) if any is open.
bool dismissAnyPlayerChromeOverlay() {
  if (PlayerSubtitleSettingsDialog.dismissIfShowing()) {
    return true;
  }
  if (PlayerStreamMenu.isShowing) {
    PlayerStreamMenu.dismiss();
    return true;
  }
  if (PlayerPopupPanel.isShowing) {
    PlayerPopupPanel.dismiss();
    return true;
  }
  if (PlayerEpisodePanel.isShowing) {
    PlayerEpisodePanel.dismiss();
    return true;
  }
  if (PlayerHubEpisodePanel.isShowing) {
    PlayerHubEpisodePanel.dismiss();
    return true;
  }
  if (PlayerSourcesPanel.isShowing) {
    PlayerSourcesPanel.dismiss();
    return true;
  }
  if (PlayerTorrentFilePanel.isShowing) {
    PlayerTorrentFilePanel.dismiss();
    return true;
  }
  return false;
}
