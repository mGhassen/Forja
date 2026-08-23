import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/forja_switch.dart';
import 'package:forja/shared/design/src/shell_input_policy.dart';
import 'package:forja/shared/design/src/shell_layout.dart';
import 'package:forja/shared/design/src/shell_scope.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fixed Forja theme descriptor (single preset, not user-selectable).
class AppThemePreset {
  final String id;
  final String name;
  final Color bgDark;
  final Color bgCard;
  final Color primaryColor;
  final Color accentColor;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.bgDark,
    required this.bgCard,
    required this.primaryColor,
    required this.accentColor,
  });
}

class AppTheme {
  static const Color appBackground = Color(0xFF141414);
  static const String defaultPresetId = 'forja';

  static const AppThemePreset _forjaPreset = AppThemePreset(
    id: 'forja',
    name: 'Forja',
    bgDark: appBackground,
    bgCard: Color(0xFF1C1C1C),
    primaryColor: ForjaShellColors.brandGreen,
    accentColor: Color(0xFF9CA3AF),
  );

  static const List<AppThemePreset> presets = [_forjaPreset];

  static AppThemePreset get defaultPreset => _forjaPreset;

  static final ValueNotifier<AppThemePreset> themeNotifier =
      ValueNotifier<AppThemePreset>(_forjaPreset);

  static AppThemePreset get current => themeNotifier.value;

  static const Color primaryColor = ForjaShellColors.brandGreen;

  static Color get accentColor => ForjaShellColors.sectionAccent;

  static Color get bgDark => current.bgDark;
  static Color get bgCard => current.bgCard;

  static BoxDecoration get backgroundDecoration => effectiveBackground;
  static BoxDecoration get backgroundDecorationFlat => effectiveBackground;

  static BoxDecoration get effectiveBackground =>
      BoxDecoration(color: current.bgDark);

  static ThemeData get themeData {
    const preset = _forjaPreset;
    // Shared Forja button language: rectangle, small radius, hairline border,
    // lightly tinted (not saturated) fill. Mirrors [ForjaButton].
    const buttonRadius = BorderRadius.all(Radius.circular(8));
    const buttonShape = RoundedRectangleBorder(borderRadius: buttonRadius);
    const buttonBorder = BorderSide(color: ForjaShellColors.ghostBorder);
    const buttonFill = Color(0x0AFFFFFF); // ~4% white - barely-there tint
    const buttonFg = Color(0xFFF5F5F7);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 18);
    const buttonMinSize = Size(0, 44);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: preset.bgDark,
      primaryColor: preset.primaryColor,
      colorScheme: ColorScheme.dark(
        primary: preset.primaryColor,
        secondary: ForjaShellColors.sectionAccent,
        surface: preset.bgCard,
        onSurface: const Color(0xFFF5F5F7),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.oswald(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white),
        displayMedium: GoogleFonts.oswald(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: Colors.white),
        titleLarge: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFFF5F5F7)),
        bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF9CA3AF)),
        labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFF5F5F7)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF9CA3AF)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: buttonBorder,
          backgroundColor: buttonFill,
          foregroundColor: buttonFg,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: buttonBorder,
          backgroundColor: buttonFill,
          foregroundColor: buttonFg,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: buttonBorder,
          backgroundColor: buttonFill,
          foregroundColor: buttonFg,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: const CircleBorder(),
          foregroundColor: const Color(0xFFF5F5F7),
        ),
      ),
      // Canonical Forja toggle - see [ForjaSwitch] / [forjaSwitchThemeData].
      switchTheme: forjaSwitchThemeData,
    );
  }

  static Future<void> initTheme() async {
    themeNotifier.value = _forjaPreset;
  }

  static Future<void> setPreset(String id) async {}
}

class FocusableControl extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autoFocus;
  final double borderRadius;
  final double scaleOnFocus;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;
  final FocusNode? focusNode;
  final ShellTvFocusMeta? tvMeta;
  final ShellTvEnsureVisibleMode ensureVisibleMode;
  final bool showFocusBorder;

  /// Flat focus (scale ≤ 1): when false, only the thin border - no gray fill.
  final bool showFocusFill;

  /// Settings-style chrome: green left bar + [ForjaShellColors.inkHover] fill
  /// (same as category rail) — no gray/white focus ring box.
  final bool showFocusRail;

  /// Layout width used for focus-scale bleed. Defaults to poster card width.
  final double? focusBleedWidth;

  /// When true, nested [FocusableControl] / [Focus] children can receive focus
  /// (e.g. IPTV portal row → in-row favorite star). Default false.
  final bool allowNestedFocus;

  /// Optional key hook — runs before arrow / activate handling. Return
  /// [KeyEventResult.handled] to suppress the default OK → [onTap] path
  /// (e.g. IPTV category double-OK / long-press gestures).
  final FocusOnKeyEventCallback? onKeyEvent;

  const FocusableControl({
    super.key,
    required this.child,
    this.onTap,
    this.autoFocus = false,
    this.borderRadius = 12.0,
    this.scaleOnFocus = ShellTokens.focusActiveScale,
    this.showFocusBorder = false,
    this.showFocusFill = true,
    this.showFocusRail = false,
    this.focusBleedWidth,
    this.allowNestedFocus = false,
    this.onKeyEvent,
    this.onLeftEdge,
    this.onUpEdge,
    this.onDownEdge,
    this.onRightEdge,
    this.onFocusChange,
    this.onHoverChange,
    this.focusNode,
    this.tvMeta,
    this.ensureVisibleMode = ShellTvEnsureVisibleMode.row,
  });

  @override
  State<FocusableControl> createState() => _FocusableControlState();
}

class _FocusableControlState extends State<FocusableControl> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scale;
  FocusNode? _ownedNode;

  FocusNode get _effectiveNode => widget.focusNode ?? _ownedNode!;

  String _tvDebugLabel(ShellTvFocusMeta? meta) {
    if (meta == null || meta.rowId == null) return 'focusable-control';
    final idx = meta.itemIndex;
    return 'tv-${meta.tabId}-${meta.rowId}${idx != null ? '-$idx' : ''}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedNode = FocusNode(debugLabel: _tvDebugLabel(widget.tvMeta));
    }
    _registerTvItemNode();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: widget.scaleOnFocus).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant FocusableControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      final oldNode = oldWidget.focusNode ?? _ownedNode;
      if (oldNode != null) {
        _unregisterTvItemNode(oldWidget.tvMeta, node: oldNode);
      }
      if (widget.focusNode == null) {
        _ownedNode ??= FocusNode(debugLabel: _tvDebugLabel(widget.tvMeta));
      } else {
        _ownedNode?.dispose();
        _ownedNode = null;
      }
      _registerTvItemNode();
    } else if (oldWidget.tvMeta?.rowId != widget.tvMeta?.rowId ||
        oldWidget.tvMeta?.itemIndex != widget.tvMeta?.itemIndex) {
      _unregisterTvItemNode(oldWidget.tvMeta);
      final owned = _ownedNode;
      if (owned != null) {
        owned.debugLabel = _tvDebugLabel(widget.tvMeta);
      }
      _registerTvItemNode();
    }
  }

  void _registerTvItemNode() {
    final meta = widget.tvMeta;
    if (meta == null) return;
    if (meta.zone != ShellTvZone.row &&
        meta.zone != ShellTvZone.grid &&
        meta.zone != ShellTvZone.chipStrip &&
        meta.zone != ShellTvZone.topBar) {
      return;
    }
    if (meta.rowId == null || meta.itemIndex == null) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: meta.tabId,
      rowId: meta.rowId!,
      index: meta.itemIndex!,
      node: _effectiveNode,
    );
  }

  void _unregisterTvItemNode(ShellTvFocusMeta? meta, {FocusNode? node}) {
    if (meta == null) return;
    if (meta.zone != ShellTvZone.row &&
        meta.zone != ShellTvZone.grid &&
        meta.zone != ShellTvZone.chipStrip &&
        meta.zone != ShellTvZone.topBar) {
      return;
    }
    if (meta.rowId == null || meta.itemIndex == null) return;
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: meta.tabId,
      rowId: meta.rowId!,
      index: meta.itemIndex!,
      node: node ?? _effectiveNode,
    );
  }

  @override
  void dispose() {
    _unregisterTvItemNode(widget.tvMeta);
    final owned = _ownedNode;
    if (owned != null) {
      try {
        if (owned.hasFocus) owned.unfocus();
      } catch (_) {}
      owned.dispose();
      _ownedNode = null;
    }
    _controller.dispose();
    super.dispose();
  }

  void _updateState(bool active) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    // TV: snap scale — AnimationController.forward over 200ms janks every
    // D-pad step across catalog cards on weak leanback SoCs.
    if (policy.instantFocusChrome) {
      _controller.value = active ? 1.0 : 0.0;
      return;
    }
    if (active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _ensureVisible(BuildContext context, ShellInputPolicy policy) {
    if (!policy.ensureVisibleOnFocus) return;
    if (widget.ensureVisibleMode == ShellTvEnsureVisibleMode.off) return;

    // TV: jump instantly (no 200ms tween). Animated scroll leaves the focused
    // control clipped / hidden until the tween ends, and stacks into stutter.
    if (widget.ensureVisibleMode == ShellTvEnsureVisibleMode.item) {
      // Settings / vertical menus: first control snaps to content top so
      // section labels above it stay visible (keepVisible alone pins flush).
      shellTvEnsureVisibleItem(context);
      return;
    }

    // Run start+end keepVisible so ↑ and ↓ only nudge by the clipped edge.
    // Horizontal row ListViews still need this; vertical hub lift is below.
    const zero = Duration.zero;
    Scrollable.ensureVisible(
      context,
      alignment: 0.0,
      duration: zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    Scrollable.ensureVisible(
      context,
      alignment: 1.0,
      duration: zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );

    // Catalog rows: nearest Scrollable is the horizontal ListView, so the
    // keepVisible pair above often never moves the page. Lift in the vertical
    // hub scroller when the card sits under the bottom inset (focus ring bleed).
    final box = context.findRenderObject();
    final h = box is RenderBox && box.hasSize
        ? box.size.height
        : shellMovieCardHeight(context);
    final bleed = widget.showFocusBorder && widget.scaleOnFocus > 1.0
        ? h * (widget.scaleOnFocus - 1) / 2 + 2.5
        : (widget.showFocusBorder ? 2.5 : 0.0);
    shellTvRevealCatalogRowFocus(
      context,
      extraBottomPx: bleed,
      extraTopPx: bleed,
    );
  }

  KeyEventResult _handleArrow(KeyEvent event) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;

    if (event is KeyUpEvent) {
      ShellTvHoldAccel.note(event);
      return KeyEventResult.ignored;
    }
    if (shellTvIsNavigationKey(event)) {
      ShellTvHoldAccel.note(event);
    }

    final handled = shellTvHandleRowArrows(
      event: event,
      tvMeta: widget.tvMeta,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
    );
    if (handled == KeyEventResult.handled) return handled;

    // Opt-in linear hosts only (rare). Default TV D-pad is spatial 2D below.
    final linearScope = ShellTvLinearFocusScope.activeOf(context) &&
        !ShellTvDisableLinearFocus.activeOf(context);
    if (linearScope) {
      final linear = shellTvLinearMenuArrows(context: context, event: event);
      if (linear == KeyEventResult.handled) return linear;
      // Linear already owns ↑/↓/←/→ — do not also run focusInDirection.
      if (shellTvIsNavigationKey(event)) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.handled;
        }
      }
    }

    // Spatial nearest-neighbor when catalog row/grid edges did not claim the
    // arrow. Settings / overlay controls attach tvMeta (zone) for memory but
    // have no rowId — requiring tvMeta==null skipped focusInDirection and left
    // D-pad dead while DirectionalFocusAction no-ops ←/→ at the app root.
    if (policy.useFocusableMoodChips && shellTvIsNavigationKey(event)) {
      final key = event.logicalKey;
      TraversalDirection? direction;
      if (key == LogicalKeyboardKey.arrowLeft) {
        direction = TraversalDirection.left;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        direction = TraversalDirection.right;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        direction = TraversalDirection.up;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        direction = TraversalDirection.down;
      }
      // Focused control node — NOT FocusScope.focusInDirection (full-screen
      // chrome scopes find no neighbors from the scope rect).
      if (direction != null) {
        final vertical = direction == TraversalDirection.up ||
            direction == TraversalDirection.down;
        final steps = vertical ? ShellTvHoldAccel.lastStep : 1;
        var node = _effectiveNode;
        var movedAny = false;
        for (var i = 0; i < steps; i++) {
          if (!node.focusInDirection(direction)) break;
          movedAny = true;
          node = FocusManager.instance.primaryFocus ?? node;
        }
        if (movedAny) return KeyEventResult.handled;
      }
    }

    final trap = shellTvTrapRowGeometry(
      event: event,
      tvFocus: policy.useFocusableMoodChips,
      tvMeta: widget.tvMeta,
      trapHorizontal:
          policy.useFocusableMoodChips && widget.tvMeta?.rowId != null,
    );
    if (trap == KeyEventResult.handled) return trap;

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    return Focus(
      focusNode: _effectiveNode,
      autofocus: widget.autoFocus,
      // Own TV focus exclusively — nested InkWell/Material must not become
      // extra traversal stops (sort dialog double ↑/↓ per row).
      descendantsAreFocusable: widget.allowNestedFocus,
      descendantsAreTraversable: widget.allowNestedFocus,
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        _updateState(
          ShellInputPolicy.interactiveActive(
            policy,
            hovered: _isHovered,
            focused: f,
            context: context,
          ),
        );
        widget.onFocusChange?.call(f);
        if (f) {
          widget.tvMeta?.notifyFocused(_effectiveNode);
          _ensureVisible(context, policy);
        }
      },
      onKeyEvent: (node, event) {
        final custom = widget.onKeyEvent?.call(node, event);
        if (custom != null && custom != KeyEventResult.ignored) {
          return custom;
        }
        final arrow = _handleArrow(event);
        if (arrow == KeyEventResult.handled) return arrow;
        if (widget.onTap != null && shellTvIsActivateKey(event)) {
          widget.onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) {
          widget.onHoverChange?.call(true);
          if (!policy.scaleOnHover) return;
          setState(() => _isHovered = true);
          _updateState(
            ShellInputPolicy.interactiveActive(
              policy,
              hovered: true,
              focused: _isFocused,
              context: context,
            ),
          );
        },
        onExit: (_) {
          widget.onHoverChange?.call(false);
          if (!policy.scaleOnHover) return;
          setState(() => _isHovered = false);
          _updateState(
            ShellInputPolicy.interactiveActive(
              policy,
              hovered: false,
              focused: _isFocused,
              context: context,
            ),
          );
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: _buildFocusedChild(context),
        ),
      ),
    );
  }

  Widget _buildFocusedChild(BuildContext context) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final chromeActive = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _isHovered,
      focused: _isFocused,
      context: context,
    );

    // Settings rail: green left bar + ink fill (no ring box).
    // Flat menus (scale 1.0): gray fill + thin border.
    // Catalog cards: white focus ring + lift scale.
    final railFocus = widget.showFocusRail;
    final flatMenuFocus =
        !railFocus && widget.showFocusBorder && widget.scaleOnFocus <= 1.0;
    final showFocusRing = widget.showFocusBorder &&
        ((flatMenuFocus && _isHovered && policy.scaleOnHover) ||
            policy.focusChromeVisible(context, focused: _isFocused));
    // 0 = caller already reserved scale room (e.g. a grid cell).
    final bleed = widget.showFocusBorder &&
            !flatMenuFocus &&
            !railFocus &&
            widget.focusBleedWidth != 0
        ? shellMovieCardFocusBleed(
            context,
            scaleOnFocus: widget.scaleOnFocus,
            cardWidth: widget.focusBleedWidth,
          )
        : 0.0;

    Widget body = AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        Widget content = child!;
        if (railFocus) {
          content = AnimatedContainer(
            duration: policy.instantFocusChrome
                ? Duration.zero
                : const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: chromeActive
                  ? ForjaShellColors.inkHover
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: chromeActive
                      ? ForjaShellColors.brandGreen
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: content,
          );
        } else if (showFocusRing) {
          if (flatMenuFocus) {
            content = DecoratedBox(
              decoration: BoxDecoration(
                color: widget.showFocusFill
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: content,
            );
          } else {
            content = Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                content,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        }
        if (flatMenuFocus || railFocus) return content;
        return Transform.scale(
          scale: _scale.value,
          alignment: Alignment.center,
          child: content,
        );
      },
      child: widget.child,
    );

    if (bleed > 0) {
      body = Padding(
        padding: EdgeInsets.symmetric(horizontal: bleed),
        child: body,
      );
    }
    return body;
  }
}
