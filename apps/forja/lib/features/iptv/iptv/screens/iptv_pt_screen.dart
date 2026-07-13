import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/design/design.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_search_bar.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/features/iptv/iptv/data/hardcoded_channels.dart';
import 'package:forja/features/iptv/iptv/data/iptv_portal_share.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_playlists_screen.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_catalog_workspace.dart';
import 'iptv_pt_player_screen.dart';

part 'iptv_pt_catalog_shell.dart';
part 'iptv_pt_widgets_common.dart';
part 'iptv_pt_widgets_portal.dart';
part 'iptv_pt_widgets_section.dart';
part 'iptv_pt_browser_view.dart';
part 'iptv_pt_browser_sidebar.dart';
part 'iptv_pt_browser_streams.dart';
part 'iptv_pt_widgets_episode.dart';
part 'iptv_pt_widgets_channels.dart';

/// Mask a URL for safe display: keeps host, masks each path segment to first 2 chars + ***.
/// Returns '—' for empty/invalid input. Strips query and fragment.
String _redactUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '—';
  return url.trim();
}

/// Main entry-point widget for the PT IPTV experience.
/// Presents all 6 sub-views and routes to the dedicated player.
class IptvPtScreen extends StatefulWidget {
  const IptvPtScreen({super.key});

  @override
  State<IptvPtScreen> createState() => _IptvPtScreenState();
}

class _IptvPtScreenState extends State<IptvPtScreen>
    with ShellTabRefresh<IptvPtScreen> {
  late final IptvController _ctrl;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleIptv;

  @override
  bool get shellBlocksEviction =>
      _ctrl.view == IptvView.episodeList || _ctrl.activePortal != null;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    await _ctrl.init();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = IptvController();
    _ctrl.addListener(_syncShellNav);
    ShellTvFocusCoordinator.registerTabDefaults(
      'iptv',
      restoreFocus: iptvRestoreCatalogFocus,
      enterFromNavFocus: () => iptvEnterFromNav(_ctrl),
    );
    _ctrl.init().then((_) {
      if (mounted) markShellTabFresh();
    });
  }

  void _syncShellNav() {
    final hide = _ctrl.view == IptvView.episodeList;
    if (ShellBus.hideGlobalNav.value != hide) {
      ShellBus.hideGlobalNav.value = hide;
      ShellBus.notifyShellChromeChanged();
    }
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.unregisterTabDefaults('iptv');
    ShellTvFocusCoordinator.clearTab('iptv');
    _ctrl.removeListener(_syncShellNav);
    _ctrl.dispose();
    super.dispose();
  }

  bool _isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < 720;
  bool _isWide(BuildContext c) => shellIptvUsesWideLayout(c);

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('iptv_pt_screen'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) _syncShellNav();
      },
      child: PopScope(
        canPop: !_ctrl.portalPanelOpen && _ctrl.view != IptvView.episodeList,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _ctrl.back();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_ctrl.view),
              child: _buildView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context) {
    switch (_ctrl.view) {
      case IptvView.portalList:
      case IptvView.sectionPick:
      case IptvView.browser:
        return _IptvCatalogShell(
          ctrl: _ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
      case IptvView.episodeList:
        return _EpisodeListView(ctrl: _ctrl, compact: _isCompact(context));
      case IptvView.channelsHub:
      case IptvView.channelResults:
        return _IptvCatalogShell(
          ctrl: _ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
    }
  }
}


