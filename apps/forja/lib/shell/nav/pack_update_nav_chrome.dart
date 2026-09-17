import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/packs/engine_pack_update.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/nav/pack_update_alert_icon.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

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

        final label = EnginePackUpdateCopy.available(count);
        final offset = ShellTokens.packUpdateFlyoutOffset;

        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (context) {
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
                child: _PackUpdateFlyout(
                  label: label,
                  onTap: PackUpdateNavChrome.openForjaPacks,
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
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slide = ShellTokens.packUpdateFlyoutSlide;
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
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: ShellTokens.packUpdateFlyoutMaxWidth,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ShellTokens.packUpdateFlyoutPadH,
                vertical: ShellTokens.packUpdateFlyoutPadV,
              ),
              decoration: BoxDecoration(
                color: ForjaShellColors.surfaceElevated,
                borderRadius: BorderRadius.circular(
                  ShellTokens.packUpdateFlyoutRadius,
                ),
                border: Border.all(color: ForjaShellColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: ShellTokens.packUpdateFlyoutShadowAlpha,
                    ),
                    blurRadius: ShellTokens.packUpdateFlyoutShadowBlur,
                    offset: const Offset(
                      0,
                      ShellTokens.packUpdateFlyoutShadowY,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PackUpdateAlertIcon(
                    size: ShellTokens.packUpdateFlyoutIconSize,
                    heartbeat: false,
                  ),
                  const SizedBox(width: ShellTokens.packUpdateFlyoutGap),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontSize: ShellTokens.packUpdateFlyoutFontSize,
                        fontWeight: FontWeight.w600,
                        height: ShellTokens.packUpdateFlyoutLineHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
