import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja_foundation/tokens/top_bar_scrim_tokens.dart';

/// Touch shell: theme background behind the status bar once the active hub
/// scrolls content under it. Nothing at rest, so an edge-to-edge hero keeps
/// its art behind the clock. Hidden while a shell overlay page (details,
/// search) owns the screen.
///
/// Mounted by [ShellScaffold] for the mobile profile only.
class ShellStatusBarScrim extends StatelessWidget {
  const ShellStatusBarScrim({super.key, required this.tabId});

  /// Active nav tab — reads its published hub scroll offset.
  final String tabId;

  /// 0 at rest, 1 once content has scrolled [fadeInDistance] under the bar.
  static double opacityFor(
    double scrollOffset, {
    double fadeInDistance = TopBarScrimTokens.scrollFadeInDistance,
  }) {
    if (fadeInDistance <= 0) return scrollOffset > 0 ? 1 : 0;
    return (scrollOffset / fadeInDistance).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: ShellBus.shellOverlayHasPage,
      builder: (context, overlay, _) {
        if (overlay) return const SizedBox.shrink();
        return ValueListenableBuilder<double>(
          valueListenable: ShellBus.hubScrollOffsetFor(tabId),
          builder: (context, offset, _) {
            final o = opacityFor(offset);
            if (o <= 0) return const SizedBox.shrink();
            return IgnorePointer(
              child: SizedBox(
                height: top,
                child: ColoredBox(
                  color: AppTheme.bgDark.withValues(
                    alpha: AppTheme.bgDark.a * o,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
