import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/packs/engine_pack_update.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Heartbeating green circle with sun + exclamation.
class PackUpdateAlertIcon extends StatefulWidget {
  const PackUpdateAlertIcon({
    super.key,
    this.size = ShellTokens.packUpdateBadgeSize,
    this.heartbeat = true,
  });

  final double size;
  final bool heartbeat;

  @override
  State<PackUpdateAlertIcon> createState() => _PackUpdateAlertIconState();
}

class _PackUpdateAlertIconState extends State<PackUpdateAlertIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: ShellTokens.packUpdateHeartbeat,
    );
    if (widget.heartbeat) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PackUpdateAlertIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heartbeat == oldWidget.heartbeat) return;
    if (widget.heartbeat) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = _SunExclamation(
      size: widget.size * ShellTokens.packUpdateGlyphScale,
    );
    final circle = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: ForjaShellColors.brandGreen,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ForjaShellColors.brandGreen.withValues(
              alpha: ShellTokens.packUpdateGlowAlpha,
            ),
            blurRadius: widget.size * ShellTokens.packUpdateGlowBlurScale,
            spreadRadius: ShellTokens.packUpdateGlowSpread,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: glyph,
    );
    if (!widget.heartbeat) return circle;
    return ScaleTransition(
      scale: Tween<double>(
        begin: ShellTokens.packUpdateHeartbeatScaleMin,
        end: ShellTokens.packUpdateHeartbeatScaleMax,
      ).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: circle,
    );
  }
}

class _SunExclamation extends StatelessWidget {
  const _SunExclamation({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            PackUpdateAlertGlyph.icon,
            size: size * ShellTokens.packUpdateSunScale,
            color: Colors.black.withValues(
              alpha: ShellTokens.packUpdateSunInkAlpha,
            ),
          ),
          Positioned(
            right: -size * ShellTokens.packUpdateBangOffsetX,
            top: -size * ShellTokens.packUpdateBangOffsetY,
            child: Text(
              '!',
              style: TextStyle(
                color: Colors.black,
                fontSize: size * ShellTokens.packUpdateBangFontScale,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner badge + hover/focus flyout over profile / settings nav chrome.
class PackUpdateNavChrome extends ConsumerStatefulWidget {
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
  ConsumerState<PackUpdateNavChrome> createState() =>
      _PackUpdateNavChromeState();
}

class _PackUpdateNavChromeState extends ConsumerState<PackUpdateNavChrome> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  bool _refreshScheduled = false;

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
    final count = ref.read(enginePackUpdatesProvider).count;
    _syncPortal(show: widget.expanded && count > 0);
  }

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(enginePackUpdatesProvider);
    if (!_refreshScheduled &&
        updates.lastChecked == null &&
        !updates.checking) {
      _refreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(enginePackUpdatesProvider.notifier).refresh();
      });
    }

    final count = updates.count;
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
                    offset: const Offset(0, ShellTokens.packUpdateFlyoutShadowY),
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
