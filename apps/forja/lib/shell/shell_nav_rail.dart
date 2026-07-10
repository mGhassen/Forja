import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
                scale: active ? ShellTokens.navRailIconHoverScale : 1.0,
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

class ShellNavRail extends StatelessWidget {
  const ShellNavRail({
    super.key,
    required this.visibleIds,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  List<String> get _navIds =>
      visibleIds.where((id) => id != 'settings').toList();

  int? _indexForId(String id) {
    final idx = visibleIds.indexOf(id);
    return idx >= 0 ? idx : null;
  }

  @override
  Widget build(BuildContext context) {
    final settingsIndex = _indexForId('settings');
    final metrics = ShellScope.metricsOf(context);

    return Container(
      width: metrics.navRailWidth,
      color: AppTheme.bgDark,
      child: SafeArea(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final navColumn = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _navIds.length; i++)
                        Builder(
                          builder: (context) {
                            final id = _navIds[i];
                            final index = _indexForId(id)!;
                            final dest = navDestinations[id]!;
                            final selected = index == selectedIndex;
                            return _ShellNavRailItem(
                              destination: dest,
                              selected: selected,
                              onTap: () => onDestinationSelected(index),
                              itemSpacing: metrics.navRailItemSpacing,
                            );
                          },
                        ),
                    ],
                  );

                  if (metrics.usesTvDensity) {
                    return navColumn;
                  }

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
            if (settingsIndex != null) ...[
              _ShellNavRailItem(
                destination: navDestinations['settings']!,
                selected: settingsIndex == selectedIndex,
                onTap: () => onDestinationSelected(settingsIndex),
                itemSpacing: metrics.navRailItemSpacing,
              ),
              SizedBox(height: metrics.navRailBottomPadding),
            ],
          ],
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
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final double itemSpacing;

  @override
  State<_ShellNavRailItem> createState() => _ShellNavRailItemState();
}

class _ShellNavRailItemState extends State<_ShellNavRailItem> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;
  bool _typing = false;
  Timer? _revealTimer;

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _onHoverEnter() {
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
    _revealTimer?.cancel();
    setState(() {
      _hover = false;
      _pressed = false;
      _typing = false;
    });
  }

  double _scaleFor(ShellInputPolicy policy) {
    if (_pressed) return 0.92;
    if (policy.scaleOnHover && _hover) return ShellTokens.navRailIconHoverScale;
    if (policy.scaleOnFocus && _focused) return ShellTokens.navRailIconHoverScale;
    return 1.0;
  }

  bool _activeFor(ShellInputPolicy policy) =>
      (policy.scaleOnHover && _hover) || (policy.scaleOnFocus && _focused);

  /// Fixed footprint: icon + label slot + underline gap — never grows on reveal.
  static double get _contentHeight =>
      ShellTokens.navRailIconSize +
      ShellTokens.navRailIconLabelGap +
      ShellTokens.navRailLabelFontSize +
      6 +
      ShellTokens.shellNavUnderlineHeight;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = _activeFor(policy);
    final iconColor = widget.selected
        ? ForjaShellColors.iconActive
        : active
            ? ForjaShellColors.iconHover
            : ForjaShellColors.iconMuted;
    final labelColor = widget.selected
        ? ForjaShellColors.textPrimary
        : active
            ? ForjaShellColors.textSecondary
            : ForjaShellColors.iconMuted;
    final labelStyle = GoogleFonts.inter(
      color: labelColor,
      fontSize: ShellTokens.navRailLabelFontSize,
      fontWeight: FontWeight.w500,
      height: 1,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: widget.itemSpacing / 2,
      ),
      child: Focus(
        debugLabel: 'nav-${widget.destination.id}',
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            return SizedBox(
                width: ShellTokens.navRailWidth,
                height: _contentHeight,
                child: Center(
                  child: MouseRegion(
                    onEnter: (_) => _onHoverEnter(),
                    onExit: (_) => _onHoverExit(),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _pressed = true),
                      onTapUp: (_) => setState(() => _pressed = false),
                      onTapCancel: () => setState(() => _pressed = false),
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: ShellTokens.navRailWidth,
                        height: _contentHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: _scaleFor(policy),
                              duration: ShellTokens.navSelectionAnimation,
                              curve: Curves.easeOutCubic,
                              child: NavDestinationIcon(
                                destination: widget.destination,
                                selected: widget.selected,
                                color: iconColor,
                                size: ShellTokens.navRailIconSize,
                              ),
                            ),
                            SizedBox(height: ShellTokens.navRailIconLabelGap),
                            SizedBox(
                              height: ShellTokens.navRailLabelFontSize,
                              width: ShellTokens.navRailWidth,
                              child: Center(
                                child: _TypewriterLabel(
                                  text: widget.destination.label,
                                  active: _typing,
                                  style: labelStyle,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: ShellTokens.navSelectionAnimation,
                              height: ShellTokens.shellNavUnderlineHeight,
                              width: widget.selected ? 24 : 0,
                              decoration: BoxDecoration(
                                color: widget.selected
                                    ? ForjaShellColors.navUnderline
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
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
