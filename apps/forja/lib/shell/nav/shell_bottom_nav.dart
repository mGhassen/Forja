import 'package:flutter/material.dart';
import 'package:forja/shell/nav/nav_complete_reload_hold.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shell/nav/pack_update_nav_chrome.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';

import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// Touch shell bottom bar.
///
/// Shows every painted tab. When they fit, slots share the width evenly.
/// When they overflow, the row scrolls horizontally (same idea as the
/// desktop/TV rail) and the selected tab is scrolled into view. Landscape
/// phones use a compact bar with icon and label side by side. The bar pads
/// itself for the bottom and side system insets (gesture pill, 3-button nav,
/// cutouts).
///
/// Item chrome matches [ShellNavRail]: destination accent + underline on
/// select, hover/focus color + icon scale — no Material pill / ink wash.
class ShellBottomNav extends StatefulWidget {
  const ShellBottomNav({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  /// Landscape phones use the compact bar.
  static bool compactOf(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Bar height above the bottom system inset.
  static double barHeightOf(BuildContext context) => compactOf(context)
      ? ShellTokens.bottomNavHeightCompact
      : ShellTokens.bottomNavHeight;

  static double itemWidthOf(BuildContext context) => compactOf(context)
      ? ShellTokens.bottomNavItemWidthCompact
      : ShellTokens.bottomNavItemWidth;

  /// Indexes into [visibleIds] that have a destination (paintable tabs).
  static List<int> paintedIndexes(List<String> visibleIds) => [
    for (var i = 0; i < visibleIds.length; i++)
      if (navDestinationFor(visibleIds[i]) != null) i,
  ];

  @override
  State<ShellBottomNav> createState() => _ShellBottomNavState();
}

class _ShellBottomNavState extends State<ShellBottomNav> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureSelectedVisible(),
    );
  }

  @override
  void didUpdateWidget(covariant ShellBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.visibleIds != widget.visibleIds) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureSelectedVisible(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureSelectedVisible() {
    if (!mounted || !_scrollController.hasClients) return;
    final painted = ShellBottomNav.paintedIndexes(widget.visibleIds);
    final slot = painted.indexOf(widget.selectedIndex);
    if (slot < 0) return;
    final itemW = ShellBottomNav.itemWidthOf(context);
    final target = slot * itemW;
    final position = _scrollController.position;
    final viewStart = position.pixels;
    final viewEnd = viewStart + position.viewportDimension;
    if (target >= viewStart && target + itemW <= viewEnd) return;
    final aligned = target.clamp(0.0, position.maxScrollExtent).toDouble();
    _scrollController.animateTo(
      aligned,
      duration: ShellTokens.navSelectionAnimation,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = ShellBottomNav.compactOf(context);
    final insets = MediaQuery.paddingOf(context);
    final painted = ShellBottomNav.paintedIndexes(widget.visibleIds);
    final itemW = ShellBottomNav.itemWidthOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: insets.left,
          right: insets.right,
          bottom: insets.bottom,
        ),
        child: SizedBox(
          height: ShellBottomNav.barHeightOf(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (painted.isEmpty) return const SizedBox.shrink();
              final needScroll = painted.length * itemW > constraints.maxWidth;
              final children = [
                for (final idx in painted)
                  SizedBox(
                    width: needScroll
                        ? itemW
                        : constraints.maxWidth / painted.length,
                    child: _BottomNavItem(
                      destination: navDestinationFor(widget.visibleIds[idx])!,
                      selected: widget.selectedIndex == idx,
                      compact: compact,
                      showPackUpdateBadge: widget.visibleIds[idx] == 'settings',
                      onTap: () => widget.onItemTapped(idx),
                      onLongPress:
                          VerticalFiltersRegistry.hasFilters(
                            widget.visibleIds[idx],
                          )
                          ? () => VerticalFiltersRegistry.showMenu(
                              widget.visibleIds[idx],
                            )
                          : null,
                      shareFilterMenuTapGroup:
                          VerticalFiltersRegistry.hasFilters(
                            widget.visibleIds[idx],
                          ),
                    ),
                  ),
              ];
              if (!needScroll) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
              }
              return Stack(
                children: [
                  ListView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    children: children,
                  ),
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _BottomNavEdgeFade(left: true),
                  ),
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _BottomNavEdgeFade(left: false),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavEdgeFade extends StatelessWidget {
  const _BottomNavEdgeFade({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: ShellTokens.bottomNavFadeWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: [AppTheme.bgDark, AppTheme.bgDark.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.onLongPress,
    this.shareFilterMenuTapGroup = false,
    this.showPackUpdateBadge = false,
  });

  final NavDestination destination;
  final bool selected;

  /// Landscape phone: icon and label side by side.
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Same [TapRegion] group as [VerticalFiltersRail] so re-press opens
  /// without the tap counting as outside and hiding the menu.
  final bool shareFilterMenuTapGroup;

  /// Settings slot: pack update badge.
  final bool showPackUpdateBadge;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _hover = false;
  bool _focused = false;
  bool _pressed = false;
  late final NavCompleteReloadHold _reloadHold;

  /// Same accent / hover language as the rail — mobile policy turns
  /// [ShellInputPolicy.scaleOnHover] off globally, so the bar tracks
  /// pointer itself.
  bool get _active => _hover || _focused;

  @override
  void initState() {
    super.initState();
    _reloadHold = NavCompleteReloadHold(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _reloadHold.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  double _iconScale() {
    final big = ShellTokens.navRailIconHoverScale;
    final small = ShellTokens.navRailIconIdleScale;
    if (_active) {
      return _pressed ? ShellTokens.navRailIconPressScale : 1;
    }
    return small / big;
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;
    final compact = widget.compact;
    final active = _active;
    final iconSize = compact
        ? ShellTokens.bottomNavIconSizeCompact
        : ShellTokens.navRailIconSize;
    final iconBox = iconSize * ShellTokens.navRailIconHoverScale;
    final destinationAccent =
        navDestinationAccentColors[widget.destination.id] ??
        ForjaShellColors.brandGreen;
    final chromeAnim = ShellTokens.navSelectionAnimation;
    final iconColor = isSelected || active
        ? destinationAccent
        : ForjaShellColors.iconMuted;
    final underlineColor = destinationAccent;
    final labelSize = compact
        ? ShellTokens.bottomNavLabelSizeCompact
        : ShellTokens.bottomNavLabelSize;
    final labelStyle = GoogleFonts.plusJakartaSans(
      color: iconColor,
      fontSize: labelSize,
      fontWeight: FontWeight.w500,
      height: ShellTokens.navRailLabelLineHeight,
    );

    Widget icon = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: iconColor),
      duration: chromeAnim,
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => NavDestinationIcon(
        destination: widget.destination,
        selected: isSelected,
        color: color ?? iconColor,
        size: iconBox,
      ),
    );
    if (widget.showPackUpdateBadge) {
      icon = PackUpdateNavChrome(
        expanded: active,
        flyoutAbove: true,
        badgeSize: ShellTokens.packUpdateBadgeSizeBottomNav,
        child: icon,
      );
    }
    icon = NavReloadHoldIcon(
      icon: icon,
      loading: _reloadHold.loading,
      size: iconBox,
    );

    final underlineWidth = ShellTokens.shellNavUnderlineWidth.clamp(
      ShellTokens.shellNavUnderlineWidthMin,
      ShellTokens.shellNavUnderlineWidth,
    );
    final iconStack = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconBox,
          height: iconBox,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedScale(
              alignment: Alignment.bottomCenter,
              scale: _iconScale(),
              duration: chromeAnim,
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: iconBox,
                height: iconBox,
                child: Center(child: icon),
              ),
            ),
          ),
        ),
        const SizedBox(height: ShellTokens.navRailIconUnderlineGap),
        AnimatedContainer(
          key: ValueKey('nav-${widget.destination.id}-underline'),
          duration: chromeAnim,
          curve: Curves.easeOutCubic,
          height: ShellTokens.shellNavUnderlineHeight,
          width: isSelected ? underlineWidth : 0,
          decoration: BoxDecoration(
            color: isSelected ? underlineColor : Colors.transparent,
            borderRadius: BorderRadius.circular(
              ShellTokens.shellNavUnderlineRadius,
            ),
          ),
        ),
      ],
    );

    final label = Text(
      widget.destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: labelStyle,
    );
    final content = compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconStack,
              const SizedBox(width: ShellTokens.bottomNavIconLabelGapCompact),
              Flexible(child: label),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconStack,
              const SizedBox(height: ShellTokens.navRailIconLabelGap),
              label,
            ],
          );

    Widget item = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) =>
              _reloadHold.pointerDown(e, hideMenuTabId: widget.destination.id),
          onPointerUp: _reloadHold.pointerUp,
          onPointerCancel: _reloadHold.pointerCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: () {
              if (_reloadHold.consumeCompleted()) return;
              widget.onTap();
            },
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    if (_reloadHold.didComplete) return;
                    widget.onLongPress!();
                  },
            child: Center(child: content),
          ),
        ),
      ),
    );
    if (widget.shareFilterMenuTapGroup) {
      item = TapRegion(
        groupId: VerticalFiltersRegistry.menuTapGroup,
        child: item,
      );
    }
    return item;
  }
}
