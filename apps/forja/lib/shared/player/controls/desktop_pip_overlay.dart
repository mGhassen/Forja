import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:window_manager/window_manager.dart';

/// Compact Safari-style PiP chrome: drag (throw snaps to corner), hover
/// play/pause + restore. No double-tap maximize (that was breaking PiP).
class DesktopPipOverlay extends StatelessWidget {
  const DesktopPipOverlay({
    super.key,
    required this.hovering,
    required this.onHoverChanged,
    required this.playing,
    required this.onTogglePlay,
    this.onRestore,
  });

  final bool hovering;
  final ValueChanged<bool> onHoverChanged;
  final bool playing;
  final VoidCallback onTogglePlay;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                unawaited(windowManager.startDragging());
              },
              // macOS snaps via native mouse-up monitor (more reliable after
              // startDragging). Windows relies on this Flutter end event.
              onPanEnd: Platform.isMacOS
                  ? null
                  : (_) {
                      unawaited(PipService.instance.snapToNearestCorner());
                    },
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: hovering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 160),
              child: IgnorePointer(
                ignoring: !hovering,
                child: Row(
                  children: [
                    _PipChip(
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onTap: onTogglePlay,
                    ),
                    const Spacer(),
                    _PipChip(
                      icon: Icons.picture_in_picture_alt_rounded,
                      onTap: () async {
                        if (onRestore != null) {
                          onRestore!();
                        } else {
                          await PipService.instance.leave();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipChip extends StatelessWidget {
  const _PipChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
