import 'package:flutter/material.dart';

import 'package:forja/shared/player/live/channel_guide/channel_guide_host.dart';
import 'package:forja/shared/player/live/tv_focus.dart';
import 'package:forja_foundation/widgets/guide/channel_search_overlay.dart'
    as foundation;

/// Host adapter — wires shell TV focus into foundation search overlay.
class ChannelSearchOverlay extends StatelessWidget {
  const ChannelSearchOverlay({
    super.key,
    required this.guide,
    required this.currentChannelId,
    required this.onChannelSelected,
    required this.onClose,
  });

  final ChannelGuide guide;
  final String currentChannelId;
  final ValueChanged<GuideChannel> onChannelSelected;
  final VoidCallback onClose;

  static const int maxVisibleResults =
      foundation.ChannelSearchOverlay.maxVisibleResults;
  static const double resultRowHeight =
      foundation.ChannelSearchOverlay.resultRowHeight;
  static const double panelRadius = foundation.ChannelSearchOverlay.panelRadius;
  static const double panelWidth = foundation.ChannelSearchOverlay.panelWidth;

  /// HardwareKeyboard steals Focus onKey for goBack — player overlay gate.
  static bool tryConsumeBackToField() =>
      foundation.ChannelSearchOverlay.tryConsumeBackToField();

  @override
  Widget build(BuildContext context) {
    return foundation.ChannelSearchOverlay(
      guide: guide,
      currentChannelId: currentChannelId,
      onChannelSelected: onChannelSelected,
      onClose: onClose,
      isTv: liveUseTvFocus(context),
    );
  }
}
