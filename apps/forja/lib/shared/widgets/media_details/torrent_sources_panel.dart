import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Right-side sliding panel shell for torrent / addon source picking.
class TorrentSourcesPanel extends StatelessWidget {
  const TorrentSourcesPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
    /// Details: true → BackdropFilter. Player: false + [frozenFrame].
    this.enableBlur = true,
    this.frozenFrame,
    this.contentPadding,
    /// Player OverlayEntry only: keep a hit-absorbing scrim while [isOpen] is
    /// still false during the open animation. Details must leave this false —
    /// the panel stays mounted when closed and must not block the page.
    this.absorbHitsWhenClosed = false,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;
  final bool enableBlur;
  final Uint8List? frozenFrame;
  final EdgeInsets? contentPadding;
  final bool absorbHitsWhenClosed;

  static double panelWidthOf(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return screenWidth < 700 ? screenWidth * 0.92 : 480.0;
  }

  static double filterPanelWidthOf(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sources = panelWidthOf(context);
    final remaining = screenWidth - sources;
    if (remaining < 280) return (screenWidth * 0.88).clamp(260.0, 400.0);
    return remaining.clamp(300.0, 420.0);
  }

  static EdgeInsets defaultContentPadding({required bool playerOverlay}) {
    return playerOverlay
        ? ShellTokens.playerSidePanelPadding
        : DetailsTokens.sourcesPanelPadding;
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = panelWidthOf(context);
    final padding = contentPadding ?? defaultContentPadding(playerOverlay: !enableBlur);
    final playerFrost = !enableBlur;
    final showScrim = isOpen || absorbHitsWhenClosed;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showScrim)
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: isOpen ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: playerFrost ? 0.22 : 0.54,
                  ),
                ),
              ),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: isOpen ? 0 : -panelWidth,
          width: panelWidth,
          child: ForjaFrostedPanel(
            enableBlur: enableBlur,
            frozenFrame: frozenFrame,
            border: Border(
              left: BorderSide(color: ForjaShellColors.cinematic.borderSubtle),
            ),
            child: SafeArea(
              left: false,
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Header row inside [TorrentSourcesPanel].
class TorrentSourcesPanelHeader extends StatelessWidget {
  const TorrentSourcesPanelHeader({
    super.key,
    required this.onClose,
    this.title = 'Sources',
  });

  final VoidCallback onClose;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: ForjaShellColors.cinematic.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        ForjaCloseButton(
          color: ForjaShellColors.cinematic.textSecondary,
          onTap: onClose,
        ),
      ],
    );
  }
}

/// Compact title row + divider for player side panels (episodes, servers, torrent).
class PlayerSidePanelHeader extends StatelessWidget {
  const PlayerSidePanelHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.leading,
    this.trailing,
    this.badge,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? leading;
  final Widget? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cinematic.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      badge!,
                      style: TextStyle(
                        color: cinematic.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            ForjaCloseButton(
              color: cinematic.textSecondary,
              onTap: onClose,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: cinematic.borderSubtle),
      ],
    );
  }
}
