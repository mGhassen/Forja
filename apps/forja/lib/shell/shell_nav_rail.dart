import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_back_exit.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:google_fonts/google_fonts.dart';


double _navRailItemSpacingForHeight({
  required int itemCount,
  required double maxHeight,
  required double preferredSpacing,
  required double itemContentHeight,
}) {
  if (itemCount <= 0) return preferredSpacing;
  final naturalHeight = itemCount * (itemContentHeight + preferredSpacing);
  if (naturalHeight <= maxHeight) return preferredSpacing;
  return math.max(
    0,
    (maxHeight - itemCount * itemContentHeight) / itemCount,
  );
}

/// Opens the shell nav drawer when the rail is collapsed on narrow windows.
class ShellNavMenuButton extends StatefulWidget {
  const ShellNavMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<ShellNavMenuButton> createState() => _ShellNavMenuButtonState();
}

class _ShellNavMenuButtonState extends State<ShellNavMenuButton> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final active = (_hover && policy.scaleOnHover) ||
        (_focused && policy.scaleOnFocus);
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: AnimatedScale(
                scale: active
                    ? ShellTokens.navRailIconHoverScale
                    : ShellTokens.navRailIconIdleScale,
                duration: ShellTokens.navSelectionAnimation,
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.menu_rounded,
                  color: active
                      ? ForjaShellColors.iconHover
                      : ForjaShellColors.iconMuted,
                  size: ShellTokens.navRailIconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShellNavRail extends StatefulWidget {
  const ShellNavRail({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<ShellNavRail> createState() => _ShellNavRailState();
}

class _ShellNavRailState extends State<ShellNavRail> {
  bool _mouseInRail = false;
  bool _focusInRail = false;

  bool get _railEngaged => _mouseInRail || _focusInRail;

  List<String> get _navIds =>
      widget.visibleIds.where((id) => id != 'settings').toList();

  int? _indexForId(String id) {
    final idx = widget.visibleIds.indexOf(id);
    return idx >= 0 ? idx : null;
  }

  void _syncFocusInRail() {
    final engaged = ShellTvFocus.anyNavFocused;
    if (engaged != _focusInRail) {
      setState(() => _focusInRail = engaged);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNavOrder();
  }

  @override
  void didUpdateWidget(covariant ShellNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNavOrder();
  }

  void _syncNavOrder() {
    final order = [
      ..._navIds,
      if (_indexForId('settings') != null) 'settings',
    ];
    ShellTvFocusCoordinator.setNavOrder(order);
  }

  @override
  Widget build(BuildContext context) {
    final settingsIndex = _indexForId('settings');
    final metrics = ShellScope.metricsOf(context);

    Widget buildNavColumn(double itemSpacing) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _navIds.length; i++)
            Builder(
              builder: (context) {
                final id = _navIds[i];
                final index = _indexForId(id)!;
                final dest = navDestinations[id]!;
                final selected = index == widget.selectedIndex;
                return _ShellNavRailItem(
                  destination: dest,
                  selected: selected,
                  onTap: () => widget.onDestinationSelected(index),
                  itemSpacing: itemSpacing,
                  railEngaged: _railEngaged,
                  onFocusChanged: _syncFocusInRail,
                );
              },
            ),
        ],
      );
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Container(
      width: metrics.navRailWidth,
      color: AppTheme.bgDark,
      child: SafeArea(
        left: false,
        right: false,
        top: metrics.navRailSafeAreaVertical,
        bottom: metrics.navRailSafeAreaVertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: metrics.navRailTopPadding),
            const _RailLogo(),
            SizedBox(height: metrics.navRailLogoGap),
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _mouseInRail = true),
                onExit: (_) => setState(() => _mouseInRail = false),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final contentHeight =
                              shellNavRailItemContentHeight(context);
                          final itemSpacing = _navRailItemSpacingForHeight(
                            itemCount: _navIds.length,
                            maxHeight: constraints.maxHeight,
                            preferredSpacing: metrics.navRailItemSpacing,
                            itemContentHeight: contentHeight,
                          );
                          final navColumn = buildNavColumn(itemSpacing);

                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0,
                                  constraints.maxHeight - 16,
                                ),
                              ),
                              child: navColumn,
                            ),
                          );
                        },
                      ),
                    ),
                    if (settingsIndex != null)
                      _ShellNavRailItem(
                        destination: navDestinations['settings']!,
                        selected: settingsIndex == widget.selectedIndex,
                        onTap: () =>
                            widget.onDestinationSelected(settingsIndex),
                        itemSpacing: metrics.navRailItemSpacing,
                        railEngaged: _railEngaged,
                        onFocusChanged: _syncFocusInRail,
                      ),
                  ],
                ),
              ),
            ),
            if (settingsIndex != null)
              SizedBox(height: metrics.navRailBottomPadding),
          ],
        ),
      ),
      ),
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ShellTokens.navRailWidth,
      child: Center(
        child: Image.asset(
          'assets/icon/logo-dark.png',
          width: ShellTokens.navRailLogoWidth,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _TypewriterLabel extends StatefulWidget {
  const _TypewriterLabel({
    required this.text,
    required this.active,
    required this.style,
  });

  final String text;
  final bool active;
  final TextStyle style;

  @override
  State<_TypewriterLabel> createState() => _TypewriterLabelState();
}

class _TypewriterLabelState extends State<_TypewriterLabel> {
  int _visibleChars = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startTyping();
  }

  @override
  void didUpdateWidget(covariant _TypewriterLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startTyping();
    } else if (!widget.active) {
      _stopTyping(reset: true);
    } else if (widget.active && widget.text != oldWidget.text) {
      _startTyping();
    }
  }

  void _startTyping() {
    _stopTyping(reset: true);
    if (widget.text.isEmpty) return;

    _timer = Timer.periodic(ShellTokens.navRailLabelLetterInterval, (_) {
      if (!mounted) return;
      if (_visibleChars >= widget.text.length) {
        _timer?.cancel();
        return;
      }
      setState(() => _visibleChars++);
    });
  }

  void _stopTyping({bool reset = false}) {
    _timer?.cancel();
    _timer = null;
    if (reset && _visibleChars != 0) {
      setState(() => _visibleChars = 0);
    }
  }

  @override
  void dispose() {
    _stopTyping();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _visibleChars == 0) {
      return const SizedBox.shrink();
    }

    final end = _visibleChars.clamp(0, widget.text.length);
    return Text(
      widget.text.substring(0, end),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}

class _ShellNavRailItem extends StatefulWidget {
  const _ShellNavRailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.itemSpacing,
    required this.railEngaged,
    required this.onFocusChanged,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final double itemSpacing;
  final bool railEngaged;
  final VoidCallback onFocusChanged;

  @override
  State<_ShellNavRailItem> createState() => _ShellNavRailItemState();
}

class _ShellNavRailItemState extends State<_ShellNavRailItem> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;
  bool _typing = false;
  Timer? _revealTimer;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'nav-${widget.destination.id}');
    ShellTvFocus.registerNav(widget.destination.id, _focusNode);
  }

  @override
  void dispose() {
    ShellTvFocus.unregisterNav(widget.destination.id, _focusNode);
    _focusNode.dispose();
    _revealTimer?.cancel();
    super.dispose();
  }

  void _onHoverEnter() {
    final policy = ShellScope.inputPolicyOf(context);
    if (!policy.scaleOnHover) return;
    setState(() {
      _hover = true;
      _typing = false;
    });
    _revealTimer?.cancel();
    _revealTimer = Timer(ShellTokens.navRailLabelRevealDelay, () {
      if (!mounted || !_hover) return;
      setState(() => _typing = true);
    });
  }

  void _onHoverExit() {
    if (!ShellScope.inputPolicyOf(context).scaleOnHover) return;
    _revealTimer?.cancel();
    setState(() {
      _hover = false;
      _pressed = false;
      _typing = false;
    });
  }

  double _scaleFor(ShellInputPolicy policy) {
    final big = ShellTokens.navRailIconHoverScale;
    final small = ShellTokens.navRailIconIdleScale;
    final itemActive = (policy.scaleOnHover && _hover) ||
        (policy.scaleOnFocus && _focused);
    if (itemActive) return _pressed ? big * 0.92 : big;
    if (!widget.railEngaged) return widget.selected ? big : small;
    return small;
  }

  void _enterPageFromNav() {
    ShellTvBackExit.reset();
    widget.onTap();
    final tabId = widget.destination.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ShellTvFocusCoordinator.focusTabEnterFromNav(tabId)) {
        ShellTvFocusCoordinator.restoreTabFocusAfterNav(tabId);
      }
    });
  }

  void _returnToActivePage() {
    final tabId = ShellTvFocus.currentNavTabId;
    if (tabId == null || tabId.isEmpty) return;
    ShellTvFocusCoordinator.restoreTabFocusAfterNav(tabId);
  }

  bool _activeFor(ShellInputPolicy policy) =>
      (policy.scaleOnHover && _hover) || (policy.scaleOnFocus && _focused);

  /// Fixed footprint: icon + label slot + underline gap — never grows on reveal.
  double _contentHeight(BuildContext context) =>
      shellNavRailItemContentHeight(context);

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = _activeFor(policy);
    final selectedFocused = widget.selected && active;
    final iconSize = shellNavRailIconSize(context);
    final labelFontSize = shellNavRailLabelFontSize(context);
    final contentHeight = _contentHeight(context);
    final underlineWidth = shellScaled(context, 24).clamp(14.0, 24.0);
    final iconColor = selectedFocused
        ? Colors.white
        : widget.selected
            ? ForjaShellColors.iconActive
            : active
                ? ForjaShellColors.iconHover
                : ForjaShellColors.iconMuted;
    final labelColor = selectedFocused
        ? Colors.white
        : widget.selected
            ? ForjaShellColors.textPrimary
            : active
                ? ForjaShellColors.textSecondary
                : ForjaShellColors.iconMuted;
    final labelStyle = GoogleFonts.inter(
      color: labelColor,
      fontSize: labelFontSize,
      fontWeight: FontWeight.w500,
      height: 1,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: widget.itemSpacing / 2,
      ),
      child: Focus(
        focusNode: _focusNode,
        debugLabel: 'nav-${widget.destination.id}',
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          widget.onFocusChanged();
        },
        onKeyEvent: (node, event) {
          if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
          if (shellTvIsActivateKey(event)) {
            _enterPageFromNav();
            return KeyEventResult.handled;
          }
          if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
            final arrow = event.logicalKey;
            if (arrow == LogicalKeyboardKey.arrowRight) {
              _returnToActivePage();
              return KeyEventResult.handled;
            }
            if (arrow == LogicalKeyboardKey.arrowUp ||
                arrow == LogicalKeyboardKey.arrowDown ||
                arrow == LogicalKeyboardKey.arrowLeft) {
              if (ShellTvFocusCoordinator.handleNavKey(arrow)) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            return SizedBox(
                width: ShellTokens.navRailWidth,
                height: contentHeight,
                child: Center(
                  child: MouseRegion(
                    onEnter: (_) => _onHoverEnter(),
                    onExit: (_) => _onHoverExit(),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _pressed = true),
                      onTapUp: (_) => setState(() => _pressed = false),
                      onTapCancel: () => setState(() => _pressed = false),
                      onTap: _enterPageFromNav,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: ShellTokens.navRailWidth,
                        height: contentHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: iconSize *
                                  ShellTokens.navRailIconHoverScale +
                                  ShellTokens.navRailIconUnderlineGap +
                                  ShellTokens.shellNavUnderlineHeight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: AnimatedScale(
                                        scale: _scaleFor(policy),
                                        duration:
                                            ShellTokens.navSelectionAnimation,
                                        curve: Curves.easeOutCubic,
                                        child: NavDestinationIcon(
                                          destination: widget.destination,
                                          selected: widget.selected,
                                          color: iconColor,
                                          size: iconSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                        ShellTokens.navSelectionAnimation,
                                    curve: Curves.easeOutCubic,
                                    height:
                                        ShellTokens.shellNavUnderlineHeight,
                                    width: widget.selected ? underlineWidth : 0,
                                    decoration: BoxDecoration(
                                      color: widget.selected
                                          ? (selectedFocused
                                              ? Colors.white
                                              : ForjaShellColors.navUnderline)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: ShellTokens.navRailIconLabelGap),
                            SizedBox(
                              height: labelFontSize,
                              width: ShellTokens.navRailWidth,
                              child: Center(
                                child: _TypewriterLabel(
                                  text: widget.destination.label,
                                  active: _typing,
                                  style: labelStyle,
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
          },
        ),
      ),
    );
  }
}
