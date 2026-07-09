import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
              scale: _hover ? ShellTokens.navRailIconHoverScale : 1.0,
              duration: ShellTokens.navSelectionAnimation,
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.menu_rounded,
                color: _hover
                    ? ForjaShellColors.iconHover
                    : ForjaShellColors.iconMuted,
                size: ShellTokens.navRailIconSize,
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
    required this.isDesktop,
  });

  final List<String> visibleIds;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDesktop;

  List<String> get _navIds =>
      visibleIds.where((id) => id != 'settings').toList();

  int? _indexForId(String id) {
    final idx = visibleIds.indexOf(id);
    return idx >= 0 ? idx : null;
  }

  @override
  Widget build(BuildContext context) {
    final settingsIndex = _indexForId('settings');

    return Container(
      width: ShellTokens.navRailWidth,
      color: AppTheme.bgDark,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: ShellTokens.shellHeaderTopPadding),
            const _RailLogo(),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          constraints.maxHeight - 16,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _navIds.map((id) {
                          final index = _indexForId(id)!;
                          final dest = navDestinations[id]!;
                          final selected = index == selectedIndex;
                          return _ShellNavRailItem(
                            destination: dest,
                            selected: selected,
                            onTap: () => onDestinationSelected(index),
                          );
                        }).toList(),
                      ),
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
              ),
              const SizedBox(height: 16),
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
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ShellNavRailItem> createState() => _ShellNavRailItemState();
}

class _ShellNavRailItemState extends State<_ShellNavRailItem> {
  bool _hover = false;
  bool _pressed = false;
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

  double get _scale {
    if (_pressed) return 0.92;
    if (_hover) return ShellTokens.navRailIconHoverScale;
    return 1.0;
  }

  /// Fixed footprint: icon + label slot + underline gap — never grows on reveal.
  static double get _contentHeight =>
      ShellTokens.navRailIconSize +
      ShellTokens.navRailIconLabelGap +
      ShellTokens.navRailLabelFontSize +
      6 +
      ShellTokens.shellNavUnderlineHeight;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.selected
        ? ForjaShellColors.iconActive
        : _hover
            ? ForjaShellColors.iconHover
            : ForjaShellColors.iconMuted;
    final labelColor = widget.selected
        ? ForjaShellColors.textPrimary
        : _hover
            ? ForjaShellColors.textSecondary
            : ForjaShellColors.iconMuted;
    final labelStyle = GoogleFonts.inter(
      color: labelColor,
      fontSize: ShellTokens.navRailLabelFontSize,
      fontWeight: FontWeight.w500,
      height: 1,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: ShellTokens.navRailItemSpacing / 2,
      ),
      child: SizedBox(
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
                      scale: _scale,
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
      ),
    );
  }
}
