import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/packs/engine_pack_update.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/nav/pack_update_alert_icon.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:google_fonts/google_fonts.dart';

export 'package:forja/shell/nav/pack_update_alert_icon.dart'
    show PackUpdateAlertIcon;

/// Corner badge + hover/focus flyout over profile / settings nav chrome.
///
/// Listens only to [PluginInstallCoordinator.pendingUpdateCount] — never
/// watches [enginePacksProvider] (that cached [] when profile scope was unbound).
class PackUpdateNavChrome extends StatefulWidget {
  const PackUpdateNavChrome({
    super.key,
    required this.child,
    required this.expanded,
    this.flyoutAbove = false,
    this.badgeSize = ShellTokens.packUpdateBadgeSize,
  });

  final Widget child;

  /// Host hover or focus — opens the tip.
  final bool expanded;

  /// Bottom nav: tip opens upward.
  final bool flyoutAbove;

  final double badgeSize;

  static void openForjaPacks() {
    ShellBus.openSettings(categoryId: SettingsCategoryId.forjaPacks);
  }

  @override
  State<PackUpdateNavChrome> createState() => _PackUpdateNavChromeState();
}

class _PackUpdateNavChromeState extends State<PackUpdateNavChrome> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  bool _checkScheduled = false;

  @override
  void dispose() {
    if (_portal.isShowing) _portal.hide();
    super.dispose();
  }

  void _syncPortal({required bool show}) {
    if (show) {
      if (!_portal.isShowing) _portal.show();
    } else if (_portal.isShowing) {
      _portal.hide();
    }
  }

  @override
  void didUpdateWidget(covariant PackUpdateNavChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPortal(
        show: widget.expanded &&
            PluginInstallCoordinator.instance.pendingUpdateCount.value > 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkScheduled) {
      _checkScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          PluginInstallCoordinator.instance.notifyPendingUpdatesIfAny(),
        );
      });
    }

    return ValueListenableBuilder<int>(
      valueListenable: PluginInstallCoordinator.instance.pendingUpdateCount,
      builder: (context, count, _) {
        if (count <= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _syncPortal(show: false);
          });
          return widget.child;
        }

        final show = widget.expanded;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncPortal(show: show);
        });

        final offset = ShellTokens.packUpdateFlyoutOffset;

        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (context) {
              // OverlayPortal gives max constraints — same trap as IPTV portal
              // probe cards; UnconstrainedBox keeps the tip content-sized.
              return CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: widget.flyoutAbove
                    ? Alignment.topCenter
                    : Alignment.centerRight,
                followerAnchor: widget.flyoutAbove
                    ? Alignment.bottomCenter
                    : Alignment.centerLeft,
                offset: widget.flyoutAbove
                    ? Offset(0, -offset)
                    : Offset(offset, 0),
                child: UnconstrainedBox(
                  alignment: widget.flyoutAbove
                      ? Alignment.bottomCenter
                      : Alignment.centerLeft,
                  child: _PackUpdateFlyout(
                    count: count,
                    onTap: PackUpdateNavChrome.openForjaPacks,
                  ),
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                widget.child,
                Positioned(
                  right: -ShellTokens.packUpdateBadgeCornerInset,
                  top: -ShellTokens.packUpdateBadgeCornerInset,
                  child: IgnorePointer(
                    child: PackUpdateAlertIcon(size: widget.badgeSize),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PackUpdateFlyout extends StatelessWidget {
  const _PackUpdateFlyout({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slide = ShellTokens.packUpdateFlyoutSlide;
    final radius = BorderRadius.circular(ShellTokens.packUpdateFlyoutRadius);
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: ShellTokens.packUpdateFlyoutAnim,
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset((1 - t) * -slide, 0),
              child: child,
            ),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: ShellTokens.packUpdateFlyoutWidth,
              child: ForjaFrostedPanel(
                borderRadius: radius,
                blurSigma: ShellTokens.packUpdateFlyoutBlur,
                border: Border.all(color: GuideChromeStyle.border),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ShellTokens.packUpdateFlyoutPadH,
                    ShellTokens.packUpdateFlyoutPadV,
                    ShellTokens.packUpdateFlyoutPadH,
                    ShellTokens.packUpdateFlyoutPadV,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const PackUpdateAlertIcon(
                            size: ShellTokens.packUpdateFlyoutIconSize,
                            heartbeat: false,
                          ),
                          const SizedBox(width: ShellTokens.packUpdateFlyoutGap),
                          Expanded(
                            child: Text(
                              EnginePackUpdateCopy.available(count),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: ForjaShellColors.brandGreen,
                                fontSize: ShellTokens.packUpdateFlyoutTitleSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: ShellTokens.packUpdateFlyoutMetaGap,
                      ),
                      Text(
                        EnginePackUpdateCopy.tipAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: ShellTokens.packUpdateFlyoutMetaSize,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
