import 'package:flutter/material.dart';

import 'package:forja/shared/engine/portals/network/iptv_network.dart';
import 'package:forja/shared/player/live/channel_guide/channel_guide_host.dart';
import 'package:forja/shared/player/live/channel_guide/guide_epg_cache.dart';
import 'package:forja/shared/player/live/tv_focus.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja_foundation/widgets/guide/channel_guide_panel.dart'
    as foundation;

/// Host adapter — wires portal engines + shell chrome into foundation paint.
class ChannelGuidePanel extends StatelessWidget {
  const ChannelGuidePanel({
    super.key,
    required this.guide,
    required this.selectedGroupId,
    required this.currentChannelId,
    required this.onGroupSelected,
    required this.onChannelSelected,
    required this.onClose,
    this.epgCache,
    this.epgEnabled = true,
  });

  final ChannelGuide guide;
  final String selectedGroupId;
  final String currentChannelId;
  final ValueChanged<String> onGroupSelected;
  final ValueChanged<GuideChannel> onChannelSelected;
  final VoidCallback onClose;
  final GuideEpgCache? epgCache;
  final bool epgEnabled;

  static const double wideBreakpoint = foundation.ChannelGuidePanel.wideBreakpoint;
  static const double panelWidthWide = foundation.ChannelGuidePanel.panelWidthWide;
  static const double panelWidthNarrow =
      foundation.ChannelGuidePanel.panelWidthNarrow;
  static const double panelEdgeGap = foundation.ChannelGuidePanel.panelEdgeGap;
  static const double panelRadius = foundation.ChannelGuidePanel.panelRadius;
  static const double panelHeightFractionPhone =
      foundation.ChannelGuidePanel.panelHeightFractionPhone;
  static const double panelVerticalGap =
      foundation.ChannelGuidePanel.panelVerticalGap;
  static const double channelRowExtent =
      foundation.ChannelGuidePanel.channelRowExtent;
  static const double channelListPaddingV =
      foundation.ChannelGuidePanel.channelListPaddingV;
  static const double groupRowExtent = foundation.ChannelGuidePanel.groupRowExtent;
  static const double groupListPaddingV =
      foundation.ChannelGuidePanel.groupListPaddingV;
  static const double listFocusMargin =
      foundation.ChannelGuidePanel.listFocusMargin;
  static const double epgPeekWidth = foundation.ChannelGuidePanel.epgPeekWidth;
  static const double epgPeekGap = foundation.ChannelGuidePanel.epgPeekGap;
  static const Duration epgHoverDelay =
      foundation.ChannelGuidePanel.epgHoverDelay;

  Future<String?> _resolvePlayUrl(GuideChannel ch) async {
    final portal = guide.xtreamPortal;
    if (ch.xtreamStream != null && portal != null) {
      return IptvClient.resolvePlayUrl(
        portal.portal,
        ch.xtreamStream!,
        section: 'live',
      );
    }
    final url = ch.playUrl;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Future<bool> _probeHealth(GuideChannel ch) async {
    final url = await _resolvePlayUrl(ch);
    if (url == null || url.isEmpty) return false;
    return IptvAliveChecker.checkOne(url);
  }

  Future<List<GuideEpgProgramme>> _loadEpg(GuideChannel ch) async {
    final cache = epgCache;
    final stream = ch.xtreamStream;
    if (cache == null || stream == null) return const [];
    return cache.loadProgrammes(stream);
  }

  @override
  Widget build(BuildContext context) {
    final tv = liveUseTvFocus(context);
    final leanback = liveLeanbackOnly(context);
    final desktop = DesktopWindowChrome.isDesktop;

    return foundation.ChannelGuidePanel(
      guide: guide,
      selectedGroupId: selectedGroupId,
      currentChannelId: currentChannelId,
      onGroupSelected: onGroupSelected,
      onChannelSelected: onChannelSelected,
      onClose: onClose,
      epgEnabled: epgEnabled,
      isTv: tv,
      leanbackOnly: leanback,
      isDesktop: desktop,
      panelInsets: (ctx) {
        if (tv) return EdgeInsets.zero;
        return EdgeInsets.only(
          top: DesktopWindowChrome.topInset(ctx) + panelVerticalGap,
          bottom: desktop ? panelEdgeGap : panelVerticalGap,
        );
      },
      resolvePlayUrl: _resolvePlayUrl,
      probeHealth: _probeHealth,
      loadEpg: epgEnabled && epgCache != null ? _loadEpg : null,
    );
  }
}
