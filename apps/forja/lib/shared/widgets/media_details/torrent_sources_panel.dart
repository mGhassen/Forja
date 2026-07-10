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
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;
  final bool enableBlur;
  final Uint8List? frozenFrame;

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

  @override
  Widget build(BuildContext context) {
    final panelWidth = panelWidthOf(context);
    const padding = EdgeInsets.fromLTRB(20, 8, 12, 16);
    final playerFrost = !enableBlur;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: playerFrost ? 0.22 : 0.54),
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
