import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/nav/nav_complete_reload_hold.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';

import 'package:forja/shared/lan/lan.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shell/focus/shell_hover_focus.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/brand/forja_profile_avatar.dart';
import 'package:forja/shell/nav/pack_update_nav_chrome.dart';
import 'package:forja_foundation/blocks/shell/shell_nav_placement.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Scroll a focused rail tab into view only when it is clipped.
void revealNavRailItem(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return;
  final viewport = RenderAbstractViewport.maybeOf(box);
  final scrollable = Scrollable.maybeOf(context);
  if (viewport == null || scrollable == null) return;
  final position = scrollable.position;
  if (!position.hasContentDimensions || !position.hasPixels) return;
  final top = viewport.getOffsetToReveal(box, 0.0).offset;
  final height = box.size.height;
  final pixels = position.pixels;
  final view = position.viewportDimension;
  const slop = 1.0;
  double? next;
  if (top < pixels - slop) {
    next = top;
  } else if (top + height > pixels + view + slop) {
    next = top + height - view;
  }
  if (next == null) return;
  next = next.clamp(position.minScrollExtent, position.maxScrollExtent);
  if ((next - pixels).abs() < 0.5) return;
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null && policy.instantFocusChrome) {
    position.jumpTo(next);
    return;
  }
  position.animateTo(
    next,
    duration: const Duration(milliseconds: 140),
    curve: Curves.easeOutCubic,
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
            width: ShellTokens.shellNavMenuButtonHitSize,
            height: ShellTokens.shellNavMenuButtonHitSize,
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
                      ? ForjaShellColors.cinematic.chromeIconActive
                      : ForjaShellColors.cinematic.chromeIconIdle,
                  size: ShellTokens.shellNavMenuButtonIconSize,
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
    this.pageDirection = TextDirection.ltr,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Get-started empty shell — keep profile, hide top Forja logo.
  final bool hideLogo;

  /// Writing direction of the selected hub. Moves D-pad "into the page".
  final TextDirection pageDirection;

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
    // Guest / Settings-only: empty get-started (or Settings hub) owns first
    // focus — cold-start rail steal left RIGHT/Back stuck on the Settings icon.
    if (widget.visibleIds.length == 1 &&
        widget.visibleIds.first == 'settings') {
      _coldStartNavFocusDone = true;
      return;
    }
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
                final dest =
                    navDestinationFor(id) ??
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
                  pageDirection: widget.pageDirection,
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
                      final padV = isTv
                          ? ShellTokens.navRailNavPadVTv
                          : ShellTokens.navRailScrollPadV;
                      final innerHeight = math.max(
                        0.0,
                        constraints.maxHeight - padV * 2,
                      );
                      final profileSpacing = isTv
                          ? ShellTokens.navRailProfileSpacingTv
                          : metrics.navRailItemSpacing;
                      final profileLabelSlot = math.max(
                        preferredLabelSlot,
                        LanPresenceMark.railSlotHeight(tv: isTv),
                      );
                      final showBoostedProfile =
                          settingsIndex != null && showDesktopProfile;
                      // Peer-size profile only in compact shell (☰ drawer width).
                      final compactShell = ShellTokens.usesCompactNavDrawer(
                        context,
                      );
                      final profileIconSize =
                          showBoostedProfile && !compactShell
                          ? preferredIconSize *
                                shellNavRailProfileAvatarScale(context)
                          : preferredIconSize;

                      // Paint at hover size; idle AnimatedScale downscales —
                      // upscaling a smaller SVG was the stutter/flash.
                      final profilePaintSize =
                          profileIconSize * ShellTokens.navRailIconHoverScale;

                      final navColumn = buildNavColumn(
                        itemSpacing: metrics.navRailItemSpacing,
                        iconSize: preferredIconSize,
                        labelSlotHeight: preferredLabelSlot,
                      );

                      // Fixed icon size and gap. Extra hubs scroll; profile
                      // stays pinned under this list.
                      final navArea = SingleChildScrollView(
                        padding: EdgeInsets.symmetric(vertical: padV),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: innerHeight),
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
                                  pageDirection: widget.pageDirection,
                                  destination: navDestinations['settings']!,
                                  label: showDesktopProfile
                                      ? _profileLabel
                                      : null,
                                  icon: showDesktopProfile
                                      ? ForjaActiveProfileAvatar(
                                          size: profilePaintSize,
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
                                  iconSize: preferredIconSize,
                                  labelFontSize: preferredLabelFont,
                                  labelSlotHeight: profileLabelSlot,
                                  alwaysShowLabel: showDesktopProfile,
                                  desaturateCustomIconWhenIdle:
                                      showDesktopProfile,
                                  selected:
                                      settingsIndex == widget.selectedIndex,
                                  onTap: () {
                                    widget.onDestinationSelected(settingsIndex);
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
    final metrics = ShellScope.metricsOf(context);
    final logo = Image.asset(
      'assets/icon/logo-dark.png',
      width: metrics.navRailLogoWidth,
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
    final active =
        onTap != null &&
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hover,
          focused: _focused,
          context: context,
        );

    content = AnimatedScale(
      scale: active ? ShellTokens.navRailLogoHoverScale : 1,
      duration: policy.instantFocusChrome
          ? Duration.zero
          : ShellTokens.navSelectionAnimation,
      curve: Curves.easeOutCubic,
      child: content,
    );

    if (onTap == null) {
      return SizedBox(
        width: metrics.navRailWidth,
        child: Center(child: content),
      );
    }

    return SizedBox(
      width: metrics.navRailWidth,
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
                padding: const EdgeInsets.symmetric(
                  vertical: ShellTokens.navRailLogoTapPadding,
                  horizontal: ShellTokens.navRailLogoTapPaddingWide,
                ),
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
        LanPresenceMark(presence: presence, size: markSize, showBar: showBar),
        const SizedBox(width: ShellTokens.navRailLanMarkGap),
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
    this.pageDirection = TextDirection.ltr,
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
  final TextDirection pageDirection;

  @override
  State<_ShellNavRailItem> createState() => _ShellNavRailItemState();
}

class _ShellNavRailItemState extends State<_ShellNavRailItem> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;
  bool _typing = false;
  Timer? _revealTimer;
  bool _mouseDownDidNavigate = false;
  Timer? _providerRevealTimer;
  Timer? _providerHoldTimer;
  bool _providerHoldFired = false;
  late final FocusNode _focusNode;
  late final void Function() _hoverClaim = _requestHoverFocus;
  late final NavCompleteReloadHold _reloadHold;

  bool get _hasVerticalFilters =>
      VerticalFiltersRegistry.hasFilters(widget.destination.id);

  void _requestHoverFocus() {
    if (!mounted) return;
    if (_focusNode.hasFocus || !_focusNode.canRequestFocus) return;
    _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _reloadHold = NavCompleteReloadHold(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _focusNode = FocusNode(debugLabel: 'nav-${widget.destination.id}');
    ShellTvFocus.registerNav(widget.destination.id, _focusNode);
    if (widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        revealNavRailItem(context);
      });
    }
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
    if (widget.selected && !oldWidget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        revealNavRailItem(context);
      });
    }
  }

  @override
  void dispose() {
    ShellHoverFocus.release(_hoverClaim);
    ShellTvFocus.unregisterNav(widget.destination.id, _focusNode);
    _focusNode.dispose();
    _revealTimer?.cancel();
    _reloadHold.dispose();
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
    _providerRevealTimer = Timer(VerticalFiltersRegistry.menuHoverDelay, () {
      if (!mounted) return;
      VerticalFiltersRegistry.showMenu(widget.destination.id);
    });
  }

  void _onHoverEnter() {
    final policy = ShellScope.inputPolicyOf(context);
    if (!policy.scaleOnHover) return;
    setState(() {
      _hover = true;
      _typing = false;
    });
    ShellHoverFocus.claim(_hoverClaim);
    _revealTimer?.cancel();
    _revealTimer = Timer(ShellTokens.navRailLabelRevealDelay, () {
      if (!mounted || !_hover) return;
      setState(() => _typing = true);
    });
    VerticalFiltersRegistry.cancelMenuHide(widget.destination.id);
    _scheduleProviderMenuReveal();
  }

  void _onHoverExit() {
    if (!ShellScope.inputPolicyOf(context).scaleOnHover) return;
    ShellHoverFocus.release(_hoverClaim);
    _revealTimer?.cancel();
    _providerRevealTimer?.cancel();
    _providerRevealTimer = null;
    if (VerticalFiltersRegistry.menuVisibleFor(widget.destination.id).value) {
      VerticalFiltersRegistry.scheduleMenuHide(widget.destination.id);
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
    // Profile: painted at hover size; idle downscales (never upscale SVG).
    if (widget.customIconSize != null) {
      final idle = 1 / ShellTokens.navRailIconHoverScale;
      if (itemActive) {
        return _pressed ? ShellTokens.navRailIconPressScale : 1;
      }
      return idle;
    }
    if (itemActive) {
      return _pressed ? big * ShellTokens.navRailIconPressScale : big;
    }
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
    final id = widget.destination.id;
    // Same-tab OK that opened the provider strip: stay on the nav so →
    // can move into the strip (enter would yank focus to the hero).
    if (VerticalFiltersRegistry.menuVisibleFor(id).value) {
      return;
    }
    ShellTvFocusCoordinator.enterTabFromNav(id);
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
    final labelSlot =
        widget.labelSlotHeight ??
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
    final labelSlotHeight =
        widget.labelSlotHeight ??
        (widget.alwaysShowLabel
            ? math.max(
                shellNavRailLabelSlotHeight(context, labelFontSize),
                LanPresenceMark.railSlotHeight(tv: tv),
              )
            : shellNavRailLabelSlotHeight(context, labelFontSize));
    final contentHeight = _contentHeight(context);
    final underlineWidth =
        shellScaled(context, ShellTokens.shellNavUnderlineWidth).clamp(
          ShellTokens.shellNavUnderlineWidthMin,
          ShellTokens.shellNavUnderlineWidth,
        );
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
    final showLabel =
        widget.alwaysShowLabel ||
        policy.focusChromeVisible(context, focused: _focused) &&
            !policy.scaleOnHover;
    final labelStyle = GoogleFonts.plusJakartaSans(
      color: labelColor,
      fontSize: labelFontSize,
      fontWeight: FontWeight.w500,
      height: ShellTokens.navRailLabelLineHeight,
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
    if (widget.destination.id == 'settings') {
      icon = PackUpdateNavChrome(
        expanded: active,
        badgeSize: tv
            ? ShellTokens.packUpdateBadgeSizeTv
            : ShellTokens.packUpdateBadgeSize,
        child: icon,
      );
    }
    final iconBox = widget.customIconSize != null
        ? renderedIconSize * ShellTokens.navRailIconHoverScale
        : renderedIconSize;
    icon = NavReloadHoldIcon(
      icon: icon,
      loading: _reloadHold.loading,
      size: iconBox,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.itemSpacing / 2),
      child: Focus(
        focusNode: _focusNode,
        debugLabel: 'nav-${widget.destination.id}',
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          widget.onFocusChanged();
          if (focused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              revealNavRailItem(context);
            });
          }
        },
        onKeyEvent: (node, event) {
          if (shellTvIsActivateKey(event)) {
            _reloadHold.activateDown(hideMenuTabId: widget.destination.id);
            if (_hasVerticalFilters) {
              _providerHoldFired = false;
              _providerHoldTimer?.cancel();
              _providerHoldTimer = Timer(
                VerticalFiltersRegistry.menuHoldDelay,
                () {
                  if (!mounted || _reloadHold.didComplete) return;
                  _providerHoldFired = true;
                  VerticalFiltersRegistry.showMenu(widget.destination.id);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ShellTvFocus.focusVerticalFilterRail();
                  });
                },
              );
            }
            return KeyEventResult.handled;
          }
          if (shellTvIsActivateKeyUp(event)) {
            final completed = _reloadHold.didComplete;
            _reloadHold.activateUp();
            if (completed) {
              _reloadHold.consumeCompleted();
              _providerHoldTimer?.cancel();
              _providerHoldTimer = null;
              _providerHoldFired = false;
              return KeyEventResult.handled;
            }
            if (_hasVerticalFilters) {
              _providerHoldTimer?.cancel();
              _providerHoldTimer = null;
              if (!_providerHoldFired) {
                _enterPageFromNav();
              }
              _providerHoldFired = false;
              return KeyEventResult.handled;
            }
            _enterPageFromNav();
            return KeyEventResult.handled;
          }
          if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
          if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
            final arrow = event.logicalKey;
            final placement = ShellNavPlacement(
              textDirection: widget.pageDirection,
            );
            if (placement.isTowardPage(arrow)) {
              // Provider strip sits on the physical left, next to an LTR rail.
              if (!placement.isRtl &&
                  _hasVerticalFilters &&
                  VerticalFiltersRegistry.menuVisibleFor(
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
                placement.isAwayFromPage(arrow)) {
              if (!placement.isRtl &&
                  arrow == LogicalKeyboardKey.arrowLeft &&
                  ShellTvFocus.miniRegistered &&
                  ShellTvFocus.tryFocusMiniFromNav()) {
                return KeyEventResult.handled;
              }
              // Coordinator treats left as the trapped edge and right as
              // "return to the page". Map the physical away-key onto left.
              final navKey = placement.isAwayFromPage(arrow)
                  ? LogicalKeyboardKey.arrowLeft
                  : arrow;
              if (ShellTvFocusCoordinator.handleNavKey(navKey)) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final railW = ShellScope.metricsOf(context).navRailWidth;
            Widget hitTarget = MouseRegion(
              onEnter: (_) => _onHoverEnter(),
              onExit: (_) => _onHoverExit(),
              cursor: SystemMouseCursors.click,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _reloadHold.pointerDown(
                    e,
                    hideMenuTabId: widget.destination.id,
                  );
                  // Long-press owns the hold (provider menu). A plain click
                  // acts on mouse down so it doesn't wait on that arena.
                  if (_hasVerticalFilters) return;
                  if (e.kind != PointerDeviceKind.mouse) return;
                  if ((e.buttons & kPrimaryButton) == 0) return;
                  _mouseDownDidNavigate = true;
                  _enterPageFromNav();
                },
                onPointerUp: _reloadHold.pointerUp,
                onPointerCancel: _reloadHold.pointerCancel,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  // Do not cancel the 4s reload hold here — long-press (Home
                  // watch services) wins the arena and would abort the hold.
                  onTapCancel: () => setState(() => _pressed = false),
                  onTap: () {
                    if (_reloadHold.consumeCompleted()) return;
                    if (_mouseDownDidNavigate) {
                      _mouseDownDidNavigate = false;
                      return;
                    }
                    _enterPageFromNav();
                  },
                  onLongPress: _hasVerticalFilters
                      ? () {
                          if (_reloadHold.didComplete) return;
                          VerticalFiltersRegistry.showMenu(
                            widget.destination.id,
                          );
                        }
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: railW,
                    height: contentHeight,
                    // Top-pin icon stack so focus scale + label never shift the
                    // icon baseline relative to unlabeled neighbors.
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: railW,
                          height:
                              renderedIconSize *
                              ShellTokens.navRailIconHoverScale,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: RepaintBoundary(
                              // AnimatedScale's filter bakes in the paint
                              // offset. On the right edge of a wide window
                              // that offset is large and Impeller flashes the
                              // glyph for the whole scale. A boundary keeps
                              // the filter local.
                              child: AnimatedScale(
                                alignment: Alignment.bottomCenter,
                                scale: _scaleFor(policy),
                                duration: chromeAnim,
                                curve: Curves.easeOutCubic,
                                // Bilinear — Impeller defaults can nearest-neighbor
                                // the focus grow and make pack PNGs look 8-bit.
                                filterQuality: FilterQuality.medium,
                                child: SizedBox(
                                  width: iconBox,
                                  height: iconBox,
                                  child: Center(child: icon),
                                ),
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
                            borderRadius: BorderRadius.circular(
                              ShellTokens.shellNavUnderlineRadius,
                            ),
                          ),
                        ),
                        const SizedBox(height: ShellTokens.navRailIconLabelGap),
                        SizedBox(
                          height: labelSlotHeight,
                          width: railW,
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
            );
            // Same TapRegion group as VerticalFiltersRail — otherwise the
            // re-press tap that opens the menu is also tap-outside and hides it.
            if (_hasVerticalFilters) {
              hitTarget = TapRegion(
                groupId: VerticalFiltersRegistry.menuTapGroup,
                child: hitTarget,
              );
            }
            return SizedBox(
              width: railW,
              height: contentHeight,
              child: Center(child: hitTarget),
            );
          },
        ),
      ),
    );
  }
}
