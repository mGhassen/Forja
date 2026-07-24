import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_menu_return_focus.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_server_stream_dialog.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';

export 'player_menu_return_focus.dart';
export 'player_seek_scrub_cancel.dart';

/// True when player chrome should use centered TV dialogs (not side panels).
bool playerTvUsesCenteredDialogs(BuildContext context) =>
    ShellScope.inputPolicyOf(context).useFocusableMoodChips;

/// Dialog width / max height for centered player overlays on TV.
({double width, double maxHeight}) playerTvDialogSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return (
    width: (size.width * 0.72).clamp(420.0, 640.0),
    maxHeight: size.height * 0.82,
  );
}

/// Side panel on phone/desktop; centered dialog with D-pad on TV.
Widget playerOverlayShell({
  required BuildContext context,
  required bool isOpen,
  required VoidCallback onClose,
  required Widget child,
  bool enableBlur = false,
  Uint8List? frozenFrame,
  EdgeInsets? contentPadding,
}) {
  if (!playerTvUsesCenteredDialogs(context)) {
    return TorrentSourcesPanel(
      isOpen: isOpen,
      onClose: onClose,
      enableBlur: enableBlur,
      frozenFrame: frozenFrame,
      contentPadding: contentPadding,
      absorbHitsWhenClosed: true,
      child: playerSidePanelTvScope(
        context: context,
        onClose: onClose,
        child: child,
      ),
    );
  }

  if (!isOpen) return const SizedBox.shrink();

  final dialog = playerTvDialogSize(context);
  final padding = contentPadding ??
      TorrentSourcesPanel.defaultContentPadding(playerOverlay: !enableBlur);

  return PlayerPopupPanel.tvFocusableOverlay(
    overlayContext: context,
    onDismiss: onClose,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialog.width,
                  maxHeight: dialog.maxHeight,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PlayerPopupTokens.shellBg,
                    borderRadius: BorderRadius.circular(
                      PlayerPopupTokens.shellRadius,
                    ),
                    border: Border.all(color: PlayerPopupTokens.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      PlayerPopupTokens.shellRadius,
                    ),
                    child: playerSidePanelTvScope(
                      context: context,
                      onClose: onClose,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Padding(padding: padding, child: child),
                      ),
                    ),
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

/// D-pad scope for player side panels (episodes, sources, stream list).
Widget playerSidePanelTvScope({
  required BuildContext context,
  required VoidCallback onClose,
  required Widget child,
}) {
  final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
  if (!tv) return child;
  // FocusScope traps FocusableControl arrows here — not in player chrome.
  return FocusScope(
    debugLabel: 'player-tv-menu',
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
    child: ShellTvLinearFocusScope(
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: _TvPanelFocusOnOpen(child: child),
      ),
    ),
  );
}

class _TvPanelFocusOnOpen extends StatefulWidget {
  const _TvPanelFocusOnOpen({required this.child});

  final Widget child;

  @override
  State<_TvPanelFocusOnOpen> createState() => _TvPanelFocusOnOpenState();
}

class _TvPanelFocusOnOpenState extends State<_TvPanelFocusOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Episode panel (and similar) own initial focus — don't steal to first chip.
      if (ShellTvDisableLinearFocus.activeOf(context)) return;
      final scope = FocusScope.of(context);
      if (scope.focusedChild != null) return;
      scope.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  if (PlayerServerStreamDialog.isShowing) {
    PlayerServerStreamDialog.dismiss();
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

/// True while a menu/panel overlay is mounted — seek bar must ignore taps.
bool playerChromeOverlayBlocksSeek() {
  return PlayerStreamMenu.isShowing ||
      PlayerServerStreamDialog.isShowing ||
      PlayerPopupPanel.isShowing ||
      PlayerEpisodePanel.isShowing ||
      PlayerHubEpisodePanel.isShowing ||
      PlayerSourcesPanel.isShowing ||
      PlayerTorrentFilePanel.isShowing ||
      PlayerSubtitleSettingsDialog.isShowing;
}

/// True while a menu/panel owns the remote — do not steal focus back to Play.
bool playerChromeOverlayBlocksFocusClaim() =>
    playerChromeOverlayBlocksSeek() || playerChromeHasPendingReturnFocus();