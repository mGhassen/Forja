import 'package:flutter/material.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Isolated TV coordinator tab for media details overlays.
abstract final class MediaDetailsTv {
  static const tabId = 'media-details';
  static const heroRowId = 'hero-actions';
  static const heroRowSortOrder = -1;
}

/// Registers [MediaDetailsTv.tabId] row memory and hero restore for a details page.
class MediaDetailsTvScope extends StatefulWidget {
  const MediaDetailsTvScope({
    super.key,
    required this.heroPlayFocus,
    required this.scrollController,
    this.backFocus,
    required this.child,
  });

  final FocusNode heroPlayFocus;
  final ScrollController scrollController;
  /// Top-left Back chevron — first remote Back focuses it before popping.
  final FocusNode? backFocus;
  final Widget child;

  @override
  State<MediaDetailsTvScope> createState() => _MediaDetailsTvScopeState();
}

class _MediaDetailsTvScopeState extends State<MediaDetailsTvScope> {
  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      MediaDetailsTv.tabId,
      defaultFocus: () => widget.heroPlayFocus,
      heroReveal: _scrollHeroIntoView,
    );
    ShellTvFocusCoordinator.registerDetailBackFocus(widget.backFocus);
  }

  @override
  void didUpdateWidget(covariant MediaDetailsTvScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.backFocus, widget.backFocus)) {
      ShellTvFocusCoordinator.unregisterDetailBackFocus(oldWidget.backFocus);
      ShellTvFocusCoordinator.registerDetailBackFocus(widget.backFocus);
    }
  }

  void _scrollHeroIntoView() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.unregisterDetailBackFocus(widget.backFocus);
    ShellTvFocusCoordinator.clearTab(MediaDetailsTv.tabId);
    ShellTvFocusCoordinator.unregisterTabDefaults(MediaDetailsTv.tabId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
