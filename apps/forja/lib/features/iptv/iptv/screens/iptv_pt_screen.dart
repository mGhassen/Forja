import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/iptv/iptv/providers/iptv_controller_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/design/design.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_epg_guide_view.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/widgets/iptv_live_favorite_button.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_search_bar.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/forja_network_image.dart';
import 'package:forja/shared/widgets/list_letter_jump_scope.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_hold_accel.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/features/iptv/iptv/data/hardcoded_channels.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_movie_details_view.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_series_details_view.dart';
import 'package:forja/shared/sync/sync.dart';
import 'iptv_pt_player_screen.dart';

part 'iptv_pt_catalog_shell.dart';
part 'iptv_pt_widgets_common.dart';
part 'iptv_pt_browser_view.dart';
part 'iptv_pt_browser_sidebar.dart';
part 'iptv_pt_browser_streams.dart';
part 'iptv_pt_widgets_channels.dart';

/// Mask a URL for safe display: keeps host, masks each path segment to first 2 chars + ***.
/// Returns '-' for empty/invalid input. Strips query and fragment.
String _redactUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '-';
  return url.trim();
}

/// Main entry-point widget for the PT IPTV experience.
/// Presents all 6 sub-views and routes to the dedicated player.
class IptvPtScreen extends ConsumerStatefulWidget {
  const IptvPtScreen({super.key});

  @override
  ConsumerState<IptvPtScreen> createState() => _IptvPtScreenState();
}

class _IptvPtScreenState extends ConsumerState<IptvPtScreen>
    with ShellTabRefresh<IptvPtScreen> {
  IptvController get _ctrl => ref.read(iptvControllerProvider);

  /// Held so [dispose] can detach without [ref] (illegal after unmount —
  /// profile switch wipes the tab cache while IPTV may still be mounted).
  IptvController? _navListenerCtrl;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleIptv;

  @override
  bool get shellBlocksEviction => _ctrl.activePortal != null;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    await SyncService.instance.pullAccountFeatures(force: force);
    if (!mounted || !shellTabVisible) return;
    await _ctrl.init();
  }

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    // Keep portal / catalog selection; drop decoded logos so Home → IPTV
    // play does not compete with poster bitmaps on weak ATV SoCs.
    ShellBus.trimImageCacheForPlayback();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = ref.read(iptvControllerProvider);
      _navListenerCtrl = ctrl;
      ctrl.addListener(_syncShellNav);
      TvHeroActions.bind(
        'iptv',
        restoreFocus: () => iptvRestoreCatalogFocus(ctrl),
        enterFromNavFocus: () => iptvEnterFromNav(ctrl),
        pageBack: () => iptvHandleCatalogPageBack(ctrl),
      );
      unawaited(SyncService.instance.pullAccountFeatures());
      ctrl.init().then((_) {
        if (mounted) markShellTabFresh();
      });
    });
  }

  void _syncShellNav() {
    final ctrl = _navListenerCtrl;
    if (ctrl == null) return;
    // Catalog stays mounted under the overlay player; VisibilityDetector can
    // still fire with visibleFraction > 0. Do not restore the rail until the
    // player has left (dispose already clears hide).
    if (ShellBus.playerSurfaceActive.value) return;
    if (ShellBus.hideGlobalNav.value) {
      ShellBus.hideGlobalNav.value = false;
      ShellBus.notifyShellChromeChanged();
    }
  }

  @override
  void dispose() {
    TvHeroActions.unbind('iptv');
    ShellTvFocusCoordinator.clearTab('iptv');
    _navListenerCtrl?.removeListener(_syncShellNav);
    _navListenerCtrl = null;
    super.dispose();
  }

  bool _isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < 720;
  bool _isWide(BuildContext c) => shellIptvUsesWideLayout(c);

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(iptvControllerProvider);
    return TvFocusGraph(
      tabId: 'iptv',
      child: VisibilityDetector(
        key: const Key('iptv_pt_screen'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0) {
            _syncShellNav();
            unawaited(SyncService.instance.pullAccountFeatures());
          }
        },
        child: PopScope(
          canPop: !ctrl.portalPanelOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) ctrl.back();
          },
          child: AnimatedBuilder(
            animation: ctrl,
            builder: (_, _) => AnimatedSwitcher(
              duration: ShellTokens.isAndroidTvDevice
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(ctrl.view),
                child: _buildView(context, ctrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context, IptvController ctrl) {
    switch (ctrl.view) {
      case IptvView.portalList:
      case IptvView.sectionPick:
      case IptvView.browser:
        return _IptvCatalogShell(
          ctrl: ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
      case IptvView.episodeList:
      case IptvView.movieDetails:
        // Details open as shell overlays (Home-style MediaDetailsTv).
        return _IptvCatalogShell(
          ctrl: ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
      case IptvView.channelsHub:
      case IptvView.channelResults:
        return _IptvCatalogShell(
          ctrl: ctrl,
          compact: _isCompact(context),
          wide: _isWide(context),
        );
    }
  }
}


