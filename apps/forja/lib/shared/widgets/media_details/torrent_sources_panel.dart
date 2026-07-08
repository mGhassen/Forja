import 'package:flutter/material.dart';

/// Right-side sliding panel shell for torrent / addon source picking.
class TorrentSourcesPanel extends StatelessWidget {
  const TorrentSourcesPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 700 ? screenWidth * 0.92 : 480.0;

    return Stack(
      children: [
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.black54),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: isOpen ? 0 : -panelWidth,
          width: panelWidth,
          child: Material(
            color: const Color(0xFF141414),
            elevation: 12,
            child: SafeArea(
              left: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
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
  const TorrentSourcesPanelHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Sources',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ],
    );
  }
}
