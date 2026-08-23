import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/settings/widgets/lan_p2p_required_dialog.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_menu_return_focus.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_server_stream_dialog.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_dialog.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';

export 'player_menu_return_focus.dart';
export 'player_seek_scrub_cancel.dart';

/// True when two-column player dialogs (Subtitles) stay centered on TV.
///
/// Sources / Episodes / Source always use the right-side panel on every
/// profile. Keys off [ShellProfile.tv] only — desktop can share TV *input*
/// policy without forcing this layout.
bool playerTvUsesCenteredDialogs(BuildContext context) {
  final profile =
      ShellScope.maybeOf(context)?.profile ?? resolveShellProfile(context);
  return profile == ShellProfile.tv;
}

/// Right-side panel shell for player Sources / Episodes / Source / torrent files
/// — same chrome on phone, desktop, and Android TV.
///
/// [detailsHost] — movies / hub details: frosted glass over the page
/// ([enableBlur] true). In-player overlays keep a flat translucent shell
/// (no BackdropFilter over live video).
Widget playerOverlayShell({
  required BuildContext context,
  required bool isOpen,
  required VoidCallback onClose,
  required Widget child,
  bool enableBlur = false,
  bool detailsHost = false,
  bool autofocusFirst = true,
  Uint8List? frozenFrame,
  EdgeInsets? contentPadding,
}) {
  return TorrentSourcesPanel(
    isOpen: isOpen,
    onClose: onClose,
    enableBlur: detailsHost ? true : enableBlur,
    frozenFrame: frozenFrame,
    contentPadding: contentPadding,
    absorbHitsWhenClosed: !detailsHost,
    child: detailsHost
        ? child
        : playerSidePanelTvScope(
            context: context,
            onClose: onClose,
            autofocusFirst: autofocusFirst,
            child: child,
          ),
  );
}

/// D-pad scope for player side panels (episodes, sources, stream list).
Widget playerSidePanelTvScope({
  required BuildContext context,
  required VoidCallback onClose,
  required Widget child,
  bool autofocusFirst = true,
}) {
  return TvOverlayScope(
    onDismiss: onClose,
    autofocusFirst: autofocusFirst,
    child: child,
  );
}

/// Dismisses the topmost player chrome overlay (menus, panels) if any is open.
///
/// For [PlayerPopupPanel] drill-ins (Settings → Speed, subtitle language, …),
/// pops one layer (back to parent) instead of closing the whole stack.
bool dismissAnyPlayerChromeOverlay() {
  if (LanP2pRequiredDialog.dismissIfShowing()) {
    return true;
  }
  if (SourcesPanelTv.dismissFiltersIfOpen()) {
    return true;
  }
  if (PlayerSubtitleSettingsDialog.dismissIfShowing()) {
    return true;
  }
  if (PlayerStreamMenu.isShowing) {
    PlayerStreamMenu.dismiss();
    return true;
  }
  if (PlayerServerStreamDialog.isShowing) {
    PlayerServerStreamDialog.dismiss();
    return true;
  }
  if (PlayerSubtitleDialog.isShowing) {
    PlayerSubtitleDialog.dismiss();
    return true;
  }
  if (PlayerPopupPanel.isShowing) {
    PlayerPopupPanel.popLayerOrDismiss();
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

/// True while a menu/panel overlay is mounted - seek bar must ignore taps.
bool playerChromeOverlayBlocksSeek() {
  return PlayerStreamMenu.isShowing ||
      PlayerServerStreamDialog.isShowing ||
      PlayerSubtitleDialog.isShowing ||
      PlayerPopupPanel.isShowing ||
      PlayerEpisodePanel.isShowing ||
      PlayerHubEpisodePanel.isShowing ||
      PlayerSourcesPanel.isShowing ||
      PlayerTorrentFilePanel.isShowing ||
      PlayerSubtitleSettingsDialog.isShowing ||
      LanP2pRequiredDialog.isShowing;
}

/// True while a menu/panel owns the remote - do not steal focus back to Play.
bool playerChromeOverlayBlocksFocusClaim() =>
    playerChromeOverlayBlocksSeek() || playerChromeHasPendingReturnFocus();