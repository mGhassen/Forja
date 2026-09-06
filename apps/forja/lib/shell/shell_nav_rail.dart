import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan.dart';
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
  required double labelSlotHeight,
}) {
  return iconSize * ShellTokens.navRailIconHoverScale +
      ShellTokens.navRailIconUnderlineGap +
      ShellTokens.shellNavUnderlineHeight +
      ShellTokens.navRailIconLabelGap +
      labelSlotHeight;
}

/// Shrink icons (then spacing) so [itemCount] rail items fit in [maxHeight].
({double iconSize, double labelSlotHeight, double itemSpacing}) _navRailFitForHeight({
  required int itemCount,
  required double maxHeight,
  required double preferredIconSize,
  required double preferredLabelSlotHeight,
  required double minLabelSlotHeight,
  required double preferredSpacing,
}) {
  if (itemCount <= 0) {
    return (
      iconSize: preferredIconSize,
      labelSlotHeight: preferredLabelSlotHeight,
      itemSpacing: preferredSpacing,
    );
  }

  var iconSize = preferredIconSize;
  var labelSlotHeight = preferredLabelSlotHeight;
  double contentHeight() => _navRailItemContentHeight(
    iconSize: iconSize,
    labelSlotHeight: labelSlotHeight,
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
      labelSlotHeight: labelSlotHeight,
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
      (perItemBudget - fixedChrome - preferredLabelSlotHeight - minSpacing) /
      ShellTokens.navRailIconHoverScale;
  iconSize = iconBudget.clamp(minIcon, preferredIconSize);
  labelSlotHeight =
      (preferredLabelSlotHeight * (iconSize / preferredIconSize)).clamp(
        minLabelSlotHeight,
        preferredLabelSlotHeight,
      );
  spacing = _navRailItemSpacingForHeight(
    itemCount: itemCount,
    maxHeight: maxHeight,
    preferredSpacing: preferredSpacing,
    itemContentHeight: contentHeight(),
  );
  return (
    iconSize: iconSize,
    labelSlotHeight: labelSlotHeight,
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
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hover,
      focused: _focused,
      context: context,
    );
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
                duration: policy.instantFocusChrome
                    ? Duration.zero
                    : ShellTokens.navSelectionAnimation,
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
    this.hideLogo = false,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Get-started empty shell — keep profile, hide top Forja logo.
  final bool hideLogo;

  @override
  State<ShellNavRail> createState() => _ShellNavRailState();
}

class _ShellNavRailState extends State<ShellNavRail> {
  bool _mouseInRail = false;
  bool _focusInRail = false;
  bool _coldStartNavFocusDone = false;
  bool _coldStartNavFocusScheduled = false;
  String _profileLabel = 'Guest';
  Timer? _lanPairPoll;

  bool get _railEngaged => _mouseInRail || _focusInRail;

  List<String> get _navIds =>
      widget.visibleIds.where((id) => id != 'settings').toList();

  int? _indexForId(String id) {
    final idx = widget.visibleIds.indexOf(id);
    return idx >= 0 ? idx : null;
  }

  void _syncFocusInRail() {
    // Desktop hover: rail-wide engage shrinks idle icons. TV must not —
    // parent setState rebuilds every nav item on content↔rail focus moves.
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    if (policy != null && policy.instantFocusChrome) return;
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
    LanPairingPresence.instance.refresh();
    // Desktop learns about a new TV pair via the engine store — light poll.
    _lanPairPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      LanPairingPresence.instance.notifyChanged();
    });
  }

  @override
  void dispose() {
    _lanPairPoll?.cancel();
    super.dispose();
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
    // Rail profile chrome follows shell profile, not input policy — desktop
    // keeps the large avatar+label even when running TV D-pad input.
    final showDesktopProfile =
        ShellScope.profileOf(context) == ShellProfile.desktop ||
        ShellScope.profileOf(context) == ShellProfile.tv;
    final preferredIconSize = shellNavRailIconSize(context);
    final preferredLabelFont = shellNavRailLabelFontSize(context);
    final preferredLabelSlot = shellNavRailLabelSlotHeight(
      context,
      preferredLabelFont,
    );
    final minLabelSlot = shellNavRailLabelSlotHeight(context, 9.0);
    final profileAvatarScale = shellNavRailProfileAvatarScale(context);

    Widget buildNavColumn({
      required double itemSpacing,
      required double iconSize,
      required double labelSlotHeight,
    }) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _navIds.length; i++)
            Builder(
              builder: (context) {
                final id = _navIds[i];
                final index = _indexForId(id)!;
                final dest = navDestinations[id] ??
                    NavDestination(
                      id: id,
                      icon: Icons.apps_outlined,
                      activeIcon: Icons.apps,
                      label: id,
                    );
                final selected = index == widget.selectedIndex;
                return _ShellNavRailItem(
                  key: ValueKey('nav-rail-$id'),
                  destination: dest,
                  selected: selected,
                  onTap: () => widget.onDestinationSelected(index),
                  itemSpacing: itemSpacing,
                  iconSize: iconSize,
                  labelSlotHeight: labelSlotHeight,
                  railEngaged: _railEngaged,
                  onFocusChanged: _syncFocusInRail,
                );
              },
            ),
        ],
      );
    }

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
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
              if (!widget.hideLogo) ...[
                _RailLogo(onTap: ShellBus.notifyShellLogoTap),
                SizedBox(height: metrics.navRailLogoGap),
              ],
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
                      final profileLabelSlot = math.max(
                        preferredLabelSlot,
                        LanPresenceMark.railSlotHeight(tv: isTv),
                      );
                      final profileBlockHeight = settingsIndex == null
                          ? 0.0
                          : _navRailItemContentHeight(
                                iconSize: profileIconSize,
                                labelSlotHeight: profileLabelSlot,
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
                        preferredLabelSlotHeight: preferredLabelSlot,
                        minLabelSlotHeight: minLabelSlot,
                        preferredSpacing: metrics.navRailItemSpacing,
                      );

                      final navColumn = buildNavColumn(
                        itemSpacing: fit.itemSpacing,
                        iconSize: fit.iconSize,
                        labelSlotHeight: fit.labelSlotHeight,
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
                            ValueListenableBuilder<LanPresence>(
                              valueListenable:
                                  LanPairingPresence.instance.status,
                              builder: (context, lanPresence, _) {
                                return _ShellNavRailItem(
                                  key: const ValueKey('nav-rail-settings'),
                                  destination: navDestinations['settings']!,
                                  label: showDesktopProfile
                                      ? _profileLabel
                                      : null,
                                  icon: showDesktopProfile
                                      ? ForjaActiveProfileAvatar(
                                          size: profileIconSize,
                                          showBorder: false,
                                          onProfile: _onActiveProfile,
                                        )
                                      : null,
                                  labelPresence: showDesktopProfile
                                      ? lanPresence
                                      : LanPresence.hidden,
                                  customIconSize: showDesktopProfile
                                      ? profileIconSize
                                      : null,
                                  iconSize: fit.iconSize,
                                  labelFontSize: preferredLabelFont,
                                  labelSlotHeight: profileLabelSlot,
                                  alwaysShowLabel: showDesktopProfile,
                                  desaturateCustomIconWhenIdle:
                                      showDesktopProfile,
                                  selected:
                                      settingsIndex == widget.selectedIndex,
                                  onTap: () {
                                    widget.onDestinationSelected(
                                      settingsIndex,
                                    );
                                  },
                                  itemSpacing: profileSpacing,
                                  railEngaged: _railEngaged,
                                  onFocusChanged: _syncFocusInRail,
                                );
                              },
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

class _RailLogo extends StatefulWidget {
  const _RailLogo({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_RailLogo> createState() => _RailLogoState();
}

class _RailLogoState extends State<_RailLogo> {
  static const _devGreen = Color(0xFF1CE783);

  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/icon/logo-dark.png',
      width: ShellTokens.navRailLogoWidth,
      fit: BoxFit.contain,
    );

    Widget content;
    if (!kDebugMode) {
      content = logo;
    } else {
      // Runtime DEV chip - no alternate logo asset.
      content = Column(
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
      );
    }

    final onTap = widget.onTap;
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final active = onTap != null &&
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hover,
          focused: _focused,
          context: context,
        );

    content = AnimatedScale(
      scale: active ? 1.04 : 1,
      duration: policy.instantFocusChrome
          ? Duration.zero
          : ShellTokens.navSelectionAnimation,
      curve: Curves.easeOutCubic,
      child: content,
    );

    if (onTap == null) {
      return SizedBox(
        width: ShellTokens.navRailWidth,
        child: Center(child: content),
      );
    }

    return SizedBox(
      width: ShellTokens.navRailWidth,
      child: Center(
        child: Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          onKeyEvent: (node, event) {
            if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select) {
              onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: content,
              ),
            ),
          ),
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
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final anim = policy.instantFocusChrome
        ? Duration.zero
        : ShellTokens.navSelectionAnimation;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: colorized ? 1 : 0),
          duration: anim,
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

class _NavRailLabel extends StatelessWidget {
  const _NavRailLabel({
    required this.text,
    required this.style,
    this.presence = LanPresence.hidden,
    this.markSize = 8,
    this.showBar = true,
  });

  final String text;
  final TextStyle style;
  final LanPresence presence;
  final double markSize;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (!presence.visible) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LanPresenceMark(
          presence: presence,
          size: markSize,
          showBar: showBar,
        ),
        const SizedBox(width: 5),
        Flexible(child: label),
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
    this.labelPresence = LanPresence.hidden,
    this.iconSize,
    this.labelFontSize,
    this.labelSlotHeight,
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
  /// LAN server (dot) + session (bar) before the profile label.
  final LanPresence labelPresence;
  /// Fitted / preferred glyph size for destination icons.
  final double? iconSize;
  final double? labelFontSize;
  final double? labelSlotHeight;
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
  Timer? _providerRevealTimer;
  Timer? _providerHoldTimer;
  bool _providerHoldFired = false;
  late final FocusNode _focusNode;

  bool get _hasVerticalFilters =>
      CatalogVerticalFiltersRegistry.hasFilters(widget.destination.id);

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
      _cancelProviderReveal();
    }
  }

  @override
  void dispose() {
    ShellTvFocus.unregisterNav(widget.destination.id, _focusNode);
    _focusNode.dispose();
    _revealTimer?.cancel();
    _cancelProviderReveal();
    super.dispose();
  }

  void _cancelProviderReveal() {
    _providerRevealTimer?.cancel();
    _providerRevealTimer = null;
    _providerHoldTimer?.cancel();
    _providerHoldTimer = null;
    _providerHoldFired = false;
  }

  void _scheduleProviderMenuReveal() {
    if (!_hasVerticalFilters) return;
    _providerRevealTimer?.cancel();
    _providerRevealTimer = Timer(CatalogVerticalFiltersRegistry.menuHoverDelay, () {
      if (!mounted) return;
      CatalogVerticalFiltersRegistry.showMenu(widget.destination.id);
    });
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
    CatalogVerticalFiltersRegistry.cancelMenuHide(widget.destination.id);
    _scheduleProviderMenuReveal();
  }

  void _onHoverExit() {
    if (!ShellScope.inputPolicyOf(context).scaleOnHover) return;
    _revealTimer?.cancel();
    _providerRevealTimer?.cancel();
    _providerRevealTimer = null;
    if (CatalogVerticalFiltersRegistry.menuVisibleFor(widget.destination.id).value) {
      CatalogVerticalFiltersRegistry.scheduleMenuHide(widget.destination.id);
    }
    setState(() {
      _hover = false;
      _pressed = false;
      _typing = false;
    });
  }

  double _scaleFor(ShellInputPolicy policy) {
    final big = ShellTokens.navRailIconHoverScale;
    final small = ShellTokens.navRailIconIdleScale;
    final itemActive = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hover,
      focused: _focused,
      context: context,
    );
    if (widget.customIconSize != null) {
      if (itemActive) return _pressed ? big * 0.92 : big;
      return 1;
    }
    if (itemActive) return _pressed ? big * 0.92 : big;
    // TV: selected stays big, idle stays small — no rail-engage shrink cascade.
    if (policy.instantFocusChrome) {
      return widget.selected ? big : small;
    }
    // Desktop: selected tab stays enlarged while browsing page content.
    if (!widget.railEngaged) return widget.selected ? big : small;
    return small;
  }

  Duration _chromeAnim(ShellInputPolicy policy) => policy.instantFocusChrome
      ? Duration.zero
      : ShellTokens.navSelectionAnimation;

  void _enterPageFromNav() {
    widget.onTap();
    ShellTvFocusCoordinator.enterTabFromNav(widget.destination.id);
  }

  void _returnToActivePage() {
    // Same path as handleNavKey(RIGHT): maps overlay details/search → their
    // tab memory (not the shell tab id, which would fall back to Play).
    ShellTvFocusCoordinator.handleNavKey(LogicalKeyboardKey.arrowRight);
  }

  bool _activeFor(BuildContext context, ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hover,
        focused: _focused,
        context: context,
      );

  /// Fixed footprint: icon + label slot + underline gap - never grows on reveal.
  double _contentHeight(BuildContext context) {
    final customIconSize = widget.customIconSize;
    final labelFont =
        widget.labelFontSize ?? shellNavRailLabelFontSize(context);
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final labelSlot = widget.labelSlotHeight ??
        (widget.alwaysShowLabel
            ? math.max(
                shellNavRailLabelSlotHeight(context, labelFont),
                LanPresenceMark.railSlotHeight(tv: tv),
              )
            : shellNavRailLabelSlotHeight(context, labelFont));
    if (customIconSize == null) {
      return shellNavRailItemContentHeight(
        context,
        iconSize: widget.iconSize,
        labelFontSize: labelFont,
        labelSlotHeight: labelSlot,
      );
    }
    return customIconSize * ShellTokens.navRailIconHoverScale +
        ShellTokens.navRailIconUnderlineGap +
        ShellTokens.shellNavUnderlineHeight +
        ShellTokens.navRailIconLabelGap +
        labelSlot;
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = _activeFor(context, policy);
    final selectedFocused = widget.selected && active;
    final iconSize = widget.iconSize ?? shellNavRailIconSize(context);
    final renderedIconSize = widget.customIconSize ?? iconSize;
    final labelFontSize =
        widget.labelFontSize ?? shellNavRailLabelFontSize(context);
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final lanShowBar = LanServerService.canRunServer;
    final lanMarkSize = LanPresenceMark.sizeFor(tv: tv);
    final labelSlotHeight = widget.labelSlotHeight ??
        (widget.alwaysShowLabel
            ? math.max(
                shellNavRailLabelSlotHeight(context, labelFontSize),
                LanPresenceMark.railSlotHeight(tv: tv),
              )
            : shellNavRailLabelSlotHeight(context, labelFontSize));
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
    // Desktop: typewriter on hover. TV: static label when D-pad focus is visible.
    final showLabel = widget.alwaysShowLabel ||
        policy.focusChromeVisible(context, focused: _focused) &&
            !policy.scaleOnHover;
    final labelStyle = GoogleFonts.plusJakartaSans(
      color: labelColor,
      fontSize: labelFontSize,
      fontWeight: FontWeight.w500,
      height: 1,
    );
    final label = widget.label ?? widget.destination.label;
    final chromeAnim = _chromeAnim(policy);
    Widget icon =
        widget.icon ??
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: iconColor),
          duration: chromeAnim,
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
          if (_hasVerticalFilters) {
            if (shellTvIsActivateKey(event)) {
              _providerHoldFired = false;
              _providerHoldTimer?.cancel();
              _providerHoldTimer = Timer(
                CatalogVerticalFiltersRegistry.menuHoldDelay,
                () {
                  if (!mounted) return;
                  _providerHoldFired = true;
                  CatalogVerticalFiltersRegistry.showMenu(widget.destination.id);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ShellTvFocus.focusVerticalFilterRail();
                  });
                },
              );
              return KeyEventResult.handled;
            }
            if (shellTvIsActivateKeyUp(event)) {
              _providerHoldTimer?.cancel();
              _providerHoldTimer = null;
              if (!_providerHoldFired) {
                _enterPageFromNav();
              }
              _providerHoldFired = false;
              return KeyEventResult.handled;
            }
          }
          if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
          if (shellTvIsActivateKey(event)) {
            _enterPageFromNav();
            return KeyEventResult.handled;
          }
          if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
            final arrow = event.logicalKey;
            if (arrow == LogicalKeyboardKey.arrowRight) {
              if (_hasVerticalFilters &&
                  CatalogVerticalFiltersRegistry.menuVisibleFor(
                    widget.destination.id,
                  ).value &&
                  ShellTvFocus.focusVerticalFilterRail()) {
                return KeyEventResult.handled;
              }
              _returnToActivePage();
              return KeyEventResult.handled;
            }
            if (arrow == LogicalKeyboardKey.arrowUp ||
                arrow == LogicalKeyboardKey.arrowDown ||
                arrow == LogicalKeyboardKey.arrowLeft) {
              if (arrow == LogicalKeyboardKey.arrowLeft &&
                  ShellTvFocus.miniRegistered &&
                  ShellTvFocus.tryFocusMiniFromNav()) {
                return KeyEventResult.handled;
              }
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
                    onLongPress: _hasVerticalFilters
                        ? () {
                            CatalogVerticalFiltersRegistry.showMenu(
                              widget.destination.id,
                            );
                          }
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: ShellTokens.navRailWidth,
                      height: contentHeight,
                      // Top-pin icon stack so focus scale + label never shift the
                      // icon baseline relative to unlabeled neighbors.
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: ShellTokens.navRailWidth,
                            height:
                                renderedIconSize *
                                ShellTokens.navRailIconHoverScale,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedScale(
                                alignment: Alignment.bottomCenter,
                                scale: _scaleFor(policy),
                                duration: chromeAnim,
                                curve: Curves.easeOutCubic,
                                child: SizedBox(
                                  width: renderedIconSize,
                                  height: renderedIconSize,
                                  child: Center(child: icon),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: ShellTokens.navRailIconUnderlineGap,
                          ),
                          AnimatedContainer(
                            key: ValueKey(
                              'nav-${widget.destination.id}-underline',
                            ),
                            duration: chromeAnim,
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
                          const SizedBox(
                            height: ShellTokens.navRailIconLabelGap,
                          ),
                          SizedBox(
                            height: labelSlotHeight,
                            width: ShellTokens.navRailWidth,
                            child: Center(
                              child: showLabel
                                  ? _NavRailLabel(
                                      text: label,
                                      style: labelStyle,
                                      presence: widget.labelPresence,
                                      markSize: lanMarkSize,
                                      showBar: lanShowBar,
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
