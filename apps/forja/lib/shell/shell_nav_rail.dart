import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
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
  return math.max(0, (maxHeight - itemCount * itemContentHeight) / itemCount);
}

double _navRailItemContentHeight({
  required double iconSize,
  required double labelFontSize,
}) {
  return iconSize * ShellTokens.navRailIconHoverScale +
      ShellTokens.navRailIconUnderlineGap +
      ShellTokens.shellNavUnderlineHeight +
      ShellTokens.navRailIconLabelGap +
      labelFontSize;
}

/// Shrink icons (then spacing) so [itemCount] rail items fit in [maxHeight].
({double iconSize, double labelFontSize, double itemSpacing}) _navRailFitForHeight({
  required int itemCount,
  required double maxHeight,
  required double preferredIconSize,
  required double preferredLabelFontSize,
  required double preferredSpacing,
}) {
  if (itemCount <= 0) {
    return (
      iconSize: preferredIconSize,
      labelFontSize: preferredLabelFontSize,
      itemSpacing: preferredSpacing,
    );
  }

  var iconSize = preferredIconSize;
  var labelFontSize = preferredLabelFontSize;
  double contentHeight() => _navRailItemContentHeight(
    iconSize: iconSize,
    labelFontSize: labelFontSize,
  );

  var spacing = _navRailItemSpacingForHeight(
    itemCount: itemCount,
    maxHeight: maxHeight,
    preferredSpacing: preferredSpacing,
    itemContentHeight: contentHeight(),
  );

  // Prefer keeping desktop-sized icons; only compress when spacing hits ~0.
  if (itemCount * contentHeight() <= maxHeight) {
    return (
      iconSize: iconSize,
      labelFontSize: labelFontSize,
      itemSpacing: spacing,
    );
  }

  final minIcon = ShellTokens.navRailIconSizeMin;
  // Solve: n * (icon * hoverScale + fixedChrome + minSpacing) <= maxHeight
  const minSpacing = 2.0;
  final fixedChrome = ShellTokens.navRailIconUnderlineGap +
      ShellTokens.shellNavUnderlineHeight +
      ShellTokens.navRailIconLabelGap;
  final perItemBudget = maxHeight / itemCount;
  final iconBudget =
      (perItemBudget - fixedChrome - preferredLabelFontSize - minSpacing) /
      ShellTokens.navRailIconHoverScale;
  iconSize = iconBudget.clamp(minIcon, preferredIconSize);
  labelFontSize = (preferredLabelFontSize * (iconSize / preferredIconSize))
      .clamp(9.0, preferredLabelFontSize);
  spacing = _navRailItemSpacingForHeight(
    itemCount: itemCount,
    maxHeight: maxHeight,
    preferredSpacing: preferredSpacing,
    itemContentHeight: contentHeight(),
  );
  return (
    iconSize: iconSize,
    labelFontSize: labelFontSize,
    itemSpacing: spacing,
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
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final active =
        (_hover && policy.scaleOnHover) || (_focused && policy.scaleOnFocus);
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
  bool _coldStartNavFocusDone = false;
  bool _coldStartNavFocusScheduled = false;
  String _profileLabel = 'Guest';

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

  void _onActiveProfile(SyncProfile? profile) {
    final label =
        profile?.name ??
        (SyncService.instance.isSignedIn ? 'Profile' : 'Guest');
    if (!mounted || label == _profileLabel) return;
    setState(() => _profileLabel = label);
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
    // Empty → first async navbar: allow cold-start focus again (earlier
    // attempts failed while the rail had no items).
    if (oldWidget.visibleIds.isEmpty && widget.visibleIds.isNotEmpty) {
      _coldStartNavFocusDone = false;
      _coldStartNavFocusScheduled = false;
    }
  }

  void _syncNavOrder() {
    final order = [..._navIds, if (_indexForId('settings') != null) 'settings'];
    ShellTvFocusCoordinator.setNavOrder(order);
  }

  /// First open on TV: land D-pad focus on the active nav item (Home by default).
  void _scheduleColdStartNavFocus(BuildContext context) {
    if (_coldStartNavFocusDone || _coldStartNavFocusScheduled) return;
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    if (policy == null) return;
    if (!policy.useFocusableMoodChips) {
      _coldStartNavFocusDone = true;
      return;
    }
    // Wait until the async navbar has real tabs — otherwise we burn attempts
    // on an empty rail and never focus after load.
    if (widget.visibleIds.isEmpty) return;
    _coldStartNavFocusScheduled = true;
    var attempts = 0;
    void attempt() {
      if (!mounted || _coldStartNavFocusDone) return;
      if (ShellTvFocus.focusCurrentNavTab()) {
        _coldStartNavFocusDone = true;
        return;
      }
      attempts += 1;
      if (attempts >= 8) {
        _coldStartNavFocusDone = true;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  @override
  Widget build(BuildContext context) {
    _scheduleColdStartNavFocus(context);
    final settingsIndex = _indexForId('settings');
    final metrics = ShellScope.metricsOf(context);
    final isTv = metrics.usesTvDensity;
    final showDesktopProfile =
        ShellScope.inputPolicyOf(context).scaleOnHover ||
        ShellScope.profileOf(context) == ShellProfile.tv;
    final preferredIconSize = shellNavRailIconSize(context);
    final preferredLabelFont = shellNavRailLabelFontSize(context);
    final profileAvatarScale = shellNavRailProfileAvatarScale(context);

    Widget buildNavColumn({
      required double itemSpacing,
      required double iconSize,
      required double labelFontSize,
    }) {
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
                  key: ValueKey('nav-rail-$id'),
                  destination: dest,
                  selected: selected,
                  onTap: () => widget.onDestinationSelected(index),
                  itemSpacing: itemSpacing,
                  iconSize: iconSize,
                  labelFontSize: labelFontSize,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final profileIconSize =
                          preferredIconSize * profileAvatarScale;
                      final profileSpacing =
                          isTv ? 4.0 : metrics.navRailItemSpacing;
                      final profileBlockHeight = settingsIndex == null
                          ? 0.0
                          : _navRailItemContentHeight(
                                iconSize: profileIconSize,
                                labelFontSize: preferredLabelFont,
                              ) +
                              profileSpacing;
                      const navPadV = 4.0;
                      final navMaxHeight = math.max(
                        0.0,
                        constraints.maxHeight -
                            profileBlockHeight -
                            (isTv ? navPadV * 2 : 16),
                      );
                      final fit = _navRailFitForHeight(
                        itemCount: _navIds.length,
                        maxHeight: navMaxHeight,
                        preferredIconSize: preferredIconSize,
                        preferredLabelFontSize: preferredLabelFont,
                        preferredSpacing: metrics.navRailItemSpacing,
                      );

                      final navColumn = buildNavColumn(
                        itemSpacing: fit.itemSpacing,
                        iconSize: fit.iconSize,
                        labelFontSize: fit.labelFontSize,
                      );

                      final navArea = isTv
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: navPadV,
                              ),
                              child: navColumn,
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: math.max(0, navMaxHeight),
                                ),
                                child: navColumn,
                              ),
                            );

                      return Column(
                        children: [
                          Expanded(child: navArea),
                          if (settingsIndex != null)
                            _ShellNavRailItem(
                              key: const ValueKey('nav-rail-settings'),
                              destination: navDestinations['settings']!,
                              label: showDesktopProfile ? _profileLabel : null,
                              icon: showDesktopProfile
                                  ? ForjaActiveProfileAvatar(
                                      size: profileIconSize,
                                      showBorder: false,
                                      onProfile: _onActiveProfile,
                                    )
                                  : null,
                              customIconSize: showDesktopProfile
                                  ? profileIconSize
                                  : null,
                              iconSize: fit.iconSize,
                              labelFontSize: preferredLabelFont,
                              alwaysShowLabel: showDesktopProfile,
                              desaturateCustomIconWhenIdle: showDesktopProfile,
                              selected: settingsIndex == widget.selectedIndex,
                              onTap: () {
                                widget.onDestinationSelected(settingsIndex);
                              },
                              itemSpacing: profileSpacing,
                              railEngaged: _railEngaged,
                              onFocusChanged: _syncFocusInRail,
                            ),
                        ],
                      );
                    },
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

  static const _devGreen = Color(0xFF1CE783);

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/icon/logo-dark.png',
      width: ShellTokens.navRailLogoWidth,
      fit: BoxFit.contain,
    );

    if (!kDebugMode) {
      return SizedBox(
        width: ShellTokens.navRailWidth,
        child: Center(child: logo),
      );
    }

    // Runtime DEV chip - no alternate logo asset.
    return SizedBox(
      width: ShellTokens.navRailWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _devGreen,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'DEV',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                height: 1.1,
              ),
            ),
          ),
        ],
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

class _AnimatedSaturation extends StatelessWidget {
  const _AnimatedSaturation({required this.colorized, required this.child});

  final bool colorized;
  final Widget child;

  static List<double> _matrix(double saturation) {
    final inverse = 1 - saturation;
    final red = 0.2126 * inverse;
    final green = 0.7152 * inverse;
    final blue = 0.0722 * inverse;
    return [
      red + saturation,
      green,
      blue,
      0,
      0,
      red,
      green + saturation,
      blue,
      0,
      0,
      red,
      green,
      blue + saturation,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Keep the avatar Element stable across grey↔color. A KeyedSubtree on the
    // avatar remounts [ForjaActiveProfileAvatar] and briefly flashes the default
    // forge face while the profile reloads - visible on quick hover.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: colorized ? 1 : 0),
          duration: ShellTokens.navSelectionAnimation,
          curve: Curves.easeOutCubic,
          child: child,
          builder: (context, saturation, child) => ColorFiltered(
            colorFilter: ColorFilter.matrix(_matrix(saturation)),
            child: child!,
          ),
        ),
        // Sibling marker only - must not wrap the avatar (see above).
        SizedBox.shrink(
          key: ValueKey(
            colorized ? 'nav-profile-avatar-color' : 'nav-profile-avatar-grey',
          ),
        ),
      ],
    );
  }
}

class _ShellNavRailItem extends StatefulWidget {
  const _ShellNavRailItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.itemSpacing,
    required this.railEngaged,
    required this.onFocusChanged,
    this.label,
    this.icon,
    this.iconSize,
    this.labelFontSize,
    this.customIconSize,
    this.alwaysShowLabel = false,
    this.desaturateCustomIconWhenIdle = false,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final double itemSpacing;
  final bool railEngaged;
  final VoidCallback onFocusChanged;
  final String? label;
  final Widget? icon;
  /// Fitted / preferred glyph size for destination icons.
  final double? iconSize;
  final double? labelFontSize;
  final double? customIconSize;
  final bool alwaysShowLabel;
  final bool desaturateCustomIconWhenIdle;

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
  void didUpdateWidget(covariant _ShellNavRailItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Without ValueKey, Flutter can reuse this State for a different tab after
    // an async navbar reload — keep the focus map keyed to the live id.
    if (oldWidget.destination.id != widget.destination.id) {
      ShellTvFocus.unregisterNav(oldWidget.destination.id, _focusNode);
      ShellTvFocus.registerNav(widget.destination.id, _focusNode);
      _focusNode.debugLabel = 'nav-${widget.destination.id}';
    }
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
    final itemActive =
        (policy.scaleOnHover && _hover) || (policy.scaleOnFocus && _focused);
    if (widget.customIconSize != null) {
      if (itemActive) return _pressed ? big * 0.92 : big;
      return 1;
    }
    if (itemActive) return _pressed ? big * 0.92 : big;
    if (!widget.railEngaged) return widget.selected ? big : small;
    return small;
  }

  void _enterPageFromNav() {
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

  /// Fixed footprint: icon + label slot + underline gap - never grows on reveal.
  double _contentHeight(BuildContext context) {
    final customIconSize = widget.customIconSize;
    final labelFont =
        widget.labelFontSize ?? shellNavRailLabelFontSize(context);
    if (customIconSize == null) {
      return shellNavRailItemContentHeight(
        context,
        iconSize: widget.iconSize,
        labelFontSize: labelFont,
      );
    }
    return customIconSize * ShellTokens.navRailIconHoverScale +
        ShellTokens.navRailIconUnderlineGap +
        ShellTokens.shellNavUnderlineHeight +
        ShellTokens.navRailIconLabelGap +
        labelFont;
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = _activeFor(policy);
    final selectedFocused = widget.selected && active;
    final iconSize = widget.iconSize ?? shellNavRailIconSize(context);
    final renderedIconSize = widget.customIconSize ?? iconSize;
    final labelFontSize =
        widget.labelFontSize ?? shellNavRailLabelFontSize(context);
    final contentHeight = _contentHeight(context);
    final underlineWidth = shellScaled(context, 24).clamp(14.0, 24.0);
    final destinationAccent =
        navDestinationAccentColors[widget.destination.id] ??
        ForjaShellColors.brandGreen;
    // Desktop hover + TV focus share the same per-tab accent language.
    final useDestinationAccent =
        policy.isInteractiveActive && widget.icon == null;
    final iconColor = useDestinationAccent
        ? (widget.selected || active
              ? destinationAccent
              : ForjaShellColors.iconMuted)
        : selectedFocused
        ? Colors.white
        : widget.selected
        ? ForjaShellColors.iconActive
        : active
        ? ForjaShellColors.iconHover
        : ForjaShellColors.iconMuted;
    final labelColor = useDestinationAccent
        ? (widget.selected || active
              ? destinationAccent
              : ForjaShellColors.iconMuted)
        : selectedFocused
        ? Colors.white
        : widget.selected
        ? ForjaShellColors.textPrimary
        : active
        ? ForjaShellColors.textSecondary
        : ForjaShellColors.iconMuted;
    final showLabel =
        widget.alwaysShowLabel || (policy.scaleOnFocus && _focused);
    final labelStyle = GoogleFonts.plusJakartaSans(
      color: labelColor,
      fontSize: labelFontSize,
      fontWeight: FontWeight.w500,
      height: 1,
    );
    final label = widget.label ?? widget.destination.label;
    Widget icon =
        widget.icon ??
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: iconColor),
          duration: ShellTokens.navSelectionAnimation,
          curve: Curves.easeOutCubic,
          builder: (context, color, _) => NavDestinationIcon(
            destination: widget.destination,
            selected: widget.selected,
            color: color ?? iconColor,
            size: iconSize,
          ),
        );
    if (widget.icon != null && widget.desaturateCustomIconWhenIdle) {
      icon = _AnimatedSaturation(
        colorized: widget.selected || active,
        child: icon,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.itemSpacing / 2),
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
                            height:
                                renderedIconSize *
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
                                      child: icon,
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  key: ValueKey(
                                    'nav-${widget.destination.id}-underline',
                                  ),
                                  duration: ShellTokens.navSelectionAnimation,
                                  curve: Curves.easeOutCubic,
                                  height: ShellTokens.shellNavUnderlineHeight,
                                  width: widget.selected ? underlineWidth : 0,
                                  decoration: BoxDecoration(
                                    color: widget.selected
                                        ? (useDestinationAccent
                                              ? destinationAccent
                                              : selectedFocused
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
                              child: showLabel
                                  ? Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: labelStyle,
                                    )
                                  : _TypewriterLabel(
                                      text: label,
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
