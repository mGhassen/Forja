import 'package:flutter/material.dart';
import 'package:rust/rust.dart';

/// Minimal torrent resolve status for [LoadingOverlay] — one line only.
class TorrentLoadingStatusPanel extends StatelessWidget {
  const TorrentLoadingStatusPanel({super.key, required this.status});

  final TorrentLoadingStatus status;

  @override
  Widget build(BuildContext context) {
    return Text(
      status.headline,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.15,
        fontFamily: 'Poppins',
      ),
    );
  }
}
