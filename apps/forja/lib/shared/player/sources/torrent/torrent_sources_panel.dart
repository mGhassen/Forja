
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
/// Sliding panel shell for torrent / addon source picking.
/// Left-to-right pages dock it on the right. A right-to-left details page docks it on the left.
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
    if (screenWidth < ShellTokens.playerSidePanelNarrowMaxWidth) {
      return screenWidth * 0.92;
    }
    return ShellTokens.chromeScale(
      ShellTokens.playerSidePanelWidth,
      tv: ShellPaintScope.usesTvDensityOf(context),
    );
  }

  static double filterPanelWidthOf(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sources = panelWidthOf(context);
    final remaining = screenWidth - sources;
    if (remaining <= 0) return 0;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final softMin = tv
        ? ShellTokens.sourcesFilterPanelSoftMinTv
        : ShellTokens.sourcesFilterPanelSoftMin;
    final maxW = tv
        ? ShellTokens.sourcesFilterPanelWidthTv
        : ShellTokens.sourcesFilterPanelWidth;
    // Never wider than the space left of Sources - a wider Filters overlay
    // sits on top of the Sources list and steals every row tap.
    if (remaining < softMin) return remaining;
    return remaining < maxW ? remaining : maxW;
  }

  static EdgeInsets defaultContentPadding({required bool playerOverlay}) {
    // Caller must prefer TV padding via [ShellPaintScope] when painting.
    return playerOverlay
        ? ShellTokens.playerSidePanelPadding
        : DetailsTokens.sourcesPanelPadding;
  }

  static EdgeInsets contentPaddingOf(
    BuildContext context, {
    required bool playerOverlay,
  }) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    if (!playerOverlay) {
      return tv
          ? DetailsTokens.sourcesPanelPaddingTv
          : DetailsTokens.sourcesPanelPadding;
    }
    return tv
        ? ShellTokens.playerSidePanelPaddingTv
        : ShellTokens.playerSidePanelPadding;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = panelWidthOf(context);
    final padding = contentPadding ??
        contentPaddingOf(context, playerOverlay: !enableBlur);
    final playerFrost = !enableBlur;
    final showScrim = isOpen || absorbHitsWhenClosed;
    // Right-side desktop panel never sits under the notch / traffic lights
    // (those are top-left). SafeArea.top only left a dead band above the tabs.
    // Phone full-bleed (~92% width) still needs top inset.
    final topSafe = screenWidth < 700;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final seam = BorderSide(color: ForjaShellColors.cinematic.borderSubtle);

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
          left: rtl ? (isOpen ? 0 : -panelWidth) : null,
          right: rtl ? null : (isOpen ? 0 : -panelWidth),
          width: panelWidth,
          child: DesktopSwipeBackIgnore(
            child: ForjaFrostedPanel(
              enableBlur: enableBlur,
              frozenFrame: frozenFrame,
              border: Border(
                left: rtl ? BorderSide.none : seam,
                right: rtl ? seam : BorderSide.none,
              ),
              child: SafeArea(
                left: rtl,
                right: !rtl,
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: ForjaShellColors.cinematic.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: tv
                ? ShellTokens.torrentPanelTitleFontSizeTv
                : ShellTokens.torrentPanelTitleFontSizeDesktop,
          ),
        ),
        const Spacer(),
        Button(
          variant: ButtonVariant.plainIcon,
          size: ButtonSize.icon,
          icon: Icons.close_rounded,
          color: ForjaShellColors.cinematic.textSecondary,
          onPressed: onClose,
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
    this.showClose = true,
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

  /// When false, [trailing] owns the close control (e.g. TV FocusableControl X).
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleFs = tv ? ShellTokens.tvTitleFontSize : 15.0;
    final badgeFs = tv ? ShellTokens.tvBodyFontSize : 12.0;
    final gap = ShellTokens.chromeScale(8, tv: tv);
    final padH = ShellTokens.chromeScale(4, tv: tv);
    final padTop = ShellTokens.chromeScale(2, tv: tv);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Small inset so title / close sit inside the panel edge (not flush).
        Padding(
          padding: EdgeInsets.fromLTRB(padH, padTop, padH, 0),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: gap),
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
                              fontSize: titleFs,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      if (badge != null) ...[
                        SizedBox(width: ShellTokens.chromeScale(6, tv: tv)),
                        Text(
                          badge!,
                          style: TextStyle(
                            color: cinematic.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: badgeFs,
                          ),
                        ),
                      ],
                      if (titleTrailing != null) ...[
                        SizedBox(width: ShellTokens.chromeScale(12, tv: tv)),
                        titleTrailing!,
                      ],
                    ],
                  ),
                )
              else
                const Spacer(),
              if (trailing != null) ...[
                trailing!,
                if (showClose)
                  SizedBox(width: ShellTokens.chromeScale(2, tv: tv)),
              ],
              if (showClose)
                Button(
                  variant: ButtonVariant.plainIcon,
                  size: ButtonSize.icon,
                  icon: Icons.close_rounded,
                  compact: true,
                  color: cinematic.textSecondary,
                  onPressed: onClose,
                  focusNode: closeFocusNode,
                  onKeyEvent: closeOnKeyEvent,
                ),
            ],
          ),
        ),
        SizedBox(height: ShellTokens.chromeScale(6, tv: tv)),
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final metaFs = tv ? ShellTokens.tvBodyFontSize : 12.0;
    return Padding(
      padding: EdgeInsets.only(top: ShellTokens.chromeScale(8, tv: tv)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: cinematic.borderSubtle),
          Padding(
            padding: EdgeInsets.fromLTRB(
              ShellTokens.chromeScale(4, tv: tv),
              ShellTokens.chromeScale(10, tv: tv),
              ShellTokens.chromeScale(4, tv: tv),
              ShellTokens.chromeScale(2, tv: tv),
            ),
            child: Row(
              children: [
                if (episodeLabel != null)
                  Text(
                    episodeLabel!,
                    style: TextStyle(
                      color: cinematic.textSecondary.withValues(alpha: 0.85),
                      fontSize: metaFs,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                const Spacer(),
                if (resultCount != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ShellTokens.chromeScale(8, tv: tv),
                      vertical: ShellTokens.chromeScale(3, tv: tv),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$resultCount',
                      style: TextStyle(
                        color: cinematic.textSecondary,
                        fontSize: metaFs,
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
