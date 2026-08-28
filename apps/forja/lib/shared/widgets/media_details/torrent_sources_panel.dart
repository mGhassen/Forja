
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';

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
    /// still false during the open animation. Details must leave this false -
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
    if (remaining <= 0) return 0;
    // Never wider than the space left of Sources - a wider Filters overlay
    // sits on top of the Sources list and steals every row tap.
    if (remaining < 280) return remaining;
    return remaining.clamp(300.0, 420.0);
  }

  static EdgeInsets defaultContentPadding({required bool playerOverlay}) {
    return playerOverlay
        ? ShellTokens.playerSidePanelPadding
        : DetailsTokens.sourcesPanelPadding;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = panelWidthOf(context);
    final padding = contentPadding ?? defaultContentPadding(playerOverlay: !enableBlur);
    final playerFrost = !enableBlur;
    final showScrim = isOpen || absorbHitsWhenClosed;
    // Right-side desktop panel never sits under the notch / traffic lights
    // (those are top-left). SafeArea.top only left a dead band above the tabs.
    // Phone full-bleed (~92% width) still needs top inset.
    final topSafe = screenWidth < 700;

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
          child: DesktopSwipeBackIgnore(
            child: ForjaFrostedPanel(
              enableBlur: enableBlur,
              frozenFrame: frozenFrame,
              border: Border(
                left: BorderSide(color: ForjaShellColors.cinematic.borderSubtle),
              ),
              child: SafeArea(
                left: false,
                top: topSafe,
                child: Padding(
                  padding: padding,
                  child: child,
                ),
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
    this.titleTrailing,
    this.badge,
    this.closeFocusNode,
    this.closeOnKeyEvent,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? leading;
  final Widget? trailing;

  /// Rendered inline right after the title (e.g. a SUB/DUB group toggle).
  final Widget? titleTrailing;
  final String? badge;
  final FocusNode? closeFocusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? closeOnKeyEvent;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Small inset so title / close sit inside the panel edge (not flush).
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              if (title.isNotEmpty || badge != null || titleTrailing != null)
                Expanded(
                  child: Row(
                    children: [
                      if (title.isNotEmpty)
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
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
                      if (titleTrailing != null) ...[
                        const SizedBox(width: 12),
                        titleTrailing!,
                      ],
                    ],
                  ),
                )
              else
                const Spacer(),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 2),
              ],
              ForjaCloseButton.compact(
                color: cinematic.textSecondary,
                onTap: onClose,
                focusNode: closeFocusNode,
                onKeyEvent: closeOnKeyEvent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: cinematic.borderSubtle),
      ],
    );
  }
}

/// Bottom strip for Sources panels (details + player): episode + result count.
class SourcesPanelMetaFooter extends StatelessWidget {
  const SourcesPanelMetaFooter({
    super.key,
    this.episodeLabel,
    this.resultCount,
  });

  final String? episodeLabel;
  final int? resultCount;

  @override
  Widget build(BuildContext context) {
    if (episodeLabel == null && resultCount == null) {
      return const SizedBox.shrink();
    }
    final cinematic = ForjaShellColors.cinematic;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: cinematic.borderSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Row(
              children: [
                if (episodeLabel != null)
                  Text(
                    episodeLabel!,
                    style: TextStyle(
                      color: cinematic.textSecondary.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                const Spacer(),
                if (resultCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$resultCount',
                      style: TextStyle(
                        color: cinematic.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
