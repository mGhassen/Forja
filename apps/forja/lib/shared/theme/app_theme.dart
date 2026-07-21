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
    const buttonFill = Color(0x0AFFFFFF); // ~4% white — barely-there tint
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
      // Canonical Forja toggle — see [ForjaSwitch] / [forjaSwitchThemeData].
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

  /// Flat focus (scale ≤ 1): when false, only the thin border — no gray fill.
  final bool showFocusFill;

  const FocusableControl({
    super.key,
    required this.child,
    this.onTap,
    this.autoFocus = false,
    this.borderRadius = 12.0,
    this.scaleOnFocus = ShellTokens.focusActiveScale,
    this.showFocusBorder = false,
    this.showFocusFill = true,
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

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedNode = FocusNode(debugLabel: 'focusable-control');
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
        _ownedNode ??= FocusNode(debugLabel: 'focusable-control');
      } else {
        _ownedNode?.dispose();
        _ownedNode = null;
      }
      _registerTvItemNode();
    } else if (oldWidget.tvMeta?.rowId != widget.tvMeta?.rowId ||
        oldWidget.tvMeta?.itemIndex != widget.tvMeta?.itemIndex) {
      _unregisterTvItemNode(oldWidget.tvMeta);
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
    _ownedNode?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _updateState(bool active) {
    if (active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _ensureVisible(BuildContext context, ShellInputPolicy policy) {
    if (!policy.ensureVisibleOnFocus) return;
    if (widget.ensureVisibleMode == ShellTvEnsureVisibleMode.off) return;

    final alignment =
        widget.ensureVisibleMode == ShellTvEnsureVisibleMode.item ? 0.5 : 0.2;
    Scrollable.ensureVisible(
      context,
      alignment: alignment,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleArrow(KeyEvent event) {
    final policy =
        ShellScope.maybeOf(context)?.inputPolicy ?? ShellInputPolicy.desktop;
    final handled = shellTvHandleRowArrows(
      event: event,
      tvMeta: widget.tvMeta,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
    );
    if (handled == KeyEventResult.handled) return handled;

    // Player / dialog menus: linear next/previous — geometric inDirection
    // often fails across Overlay + Wrap/Column and leaks to chrome.
    final linear = shellTvLinearMenuArrows(context: context, event: event);
    if (linear == KeyEventResult.handled) return linear;

    if (widget.tvMeta == null &&
        policy.useFocusableMoodChips &&
        shellTvIsNavigationKey(event)) {
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
      if (direction != null &&
          FocusScope.of(context).focusInDirection(direction)) {
        return KeyEventResult.handled;
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
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        _updateState(f || (policy.scaleOnHover && _isHovered));
        widget.onFocusChange?.call(f);
        if (f) {
          widget.tvMeta?.notifyFocused(_effectiveNode);
          _ensureVisible(context, policy);
        }
      },
      onKeyEvent: (node, event) {
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
          _updateState(true);
        },
        onExit: (_) {
          widget.onHoverChange?.call(false);
          if (!policy.scaleOnHover) return;
          setState(() => _isHovered = false);
          _updateState(_isFocused);
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
    // Flat menus (scale 1.0): gray fill + thin border. Catalog cards keep
    // the white focus ring + lift scale.
    final flatMenuFocus =
        widget.showFocusBorder && widget.scaleOnFocus <= 1.0;
    final bleed = widget.showFocusBorder && !flatMenuFocus
        ? shellMovieCardFocusBleed(context, scaleOnFocus: widget.scaleOnFocus)
        : 0.0;

    Widget body = AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        Widget content = child!;
        if (widget.showFocusBorder && _isFocused) {
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
        if (flatMenuFocus) return content;
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
