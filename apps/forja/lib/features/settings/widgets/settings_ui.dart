import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Category row in the Settings hub list / sidebar.
///
/// Chrome is only the green left bar / icon (selection). TV D-pad focus does
/// not draw a gray ring - focusing a tile selects it so accent + detail match.
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.onFocusSelect,
    this.focusNode,
    this.listIndex,
    this.tvRowId,
    this.tvItemIndex,
    this.onRightEdge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// TV split: focus lands on a tile → select only (do not enter detail).
  /// When null, [onTap] is used (compact list / non-TV).
  final VoidCallback? onFocusSelect;
  final FocusNode? focusNode;

  /// Hub list index - `0` sends Left D-pad to the nav rail.
  final int? listIndex;

  /// Split-layout TV: vertical category rail row id.
  final String? tvRowId;
  final int? tvItemIndex;

  /// Split-layout TV: Right enters the detail pane.
  final VoidCallback? onRightEdge;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        selected ? ForjaShellColors.brandGreen : ForjaShellColors.iconMuted;
    final titleColor =
        selected ? ForjaShellColors.textPrimary : ForjaShellColors.textSecondary;
    final rail = tvRowId != null;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? ForjaShellColors.inkHover : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: selected ? ForjaShellColors.brandGreen : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: SettingsTokens.categoryTitleSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!SettingsTokens.useSplitLayout(context))
            const Icon(
              Icons.chevron_right_rounded,
              color: ForjaShellColors.iconMuted,
              size: 22,
            ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      scaleOnFocus: 1.0,
      // Category rail chrome is the green left bar - never the gray menu ring.
      showFocusBorder: false,
      showFocusFill: false,
      listIndex: listIndex,
      tvTabId: 'settings',
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex ?? listIndex,
      tvZone: rail ? ShellTvZone.row : ShellTvZone.settings,
      onRightEdge: onRightEdge,
      focusNode: focusNode,
      onFocusChange: (focused) {
        // Keep detail pane on the focused category (no dual focus/selection).
        // Prefer [onFocusSelect] so OK/Right can enter detail without ↑/↓ also
        // diving into the right pane.
        if (tv && focused && !selected) {
          (onFocusSelect ?? onTap)();
        }
      },
      child: child,
    );
  }
}

/// Flat labeled section of settings rows - no card box, hairline row dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.label,
    required this.children,
  });

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SettingsTokens.groupSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 2,
                    color: ForjaShellColors.brandGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label!.toUpperCase(),
                    style: const TextStyle(
                      color: ForjaShellColors.brandGreen,
                      fontSize: SettingsTokens.groupLabelSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: ForjaShellColors.borderSubtle.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Broadcasts "user entered the Settings detail pane" so the right pane can
/// land D-pad focus on its first control (OK / → from the category rail).
class SettingsDetailEnter extends InheritedWidget {
  const SettingsDetailEnter({
    super.key,
    required this.enterToken,
    required super.child,
  });

  /// Increments on every OK / → enter from the category rail.
  final int enterToken;

  static SettingsDetailEnter? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsDetailEnter>();

  static int tokenOf(BuildContext context) => maybeOf(context)?.enterToken ?? 0;

  @override
  bool updateShouldNotify(SettingsDetailEnter oldWidget) =>
      enterToken != oldWidget.enterToken;
}

/// Scrollable detail page chrome (title + constrained body).
class SettingsPageScaffold extends StatefulWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  /// When false, [child] fills the remaining height (no outer scroll).
  final bool scrollable;

  @override
  State<SettingsPageScaffold> createState() => _SettingsPageScaffoldState();
}

class _SettingsPageScaffoldState extends State<SettingsPageScaffold> {
  final ScrollController _scrollController = ScrollController();
  int _handledEnterToken = 0;
  int _focusAttempts = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = SettingsDetailEnter.tokenOf(context);
    if (token > 0 && token != _handledEnterToken) {
      _handledEnterToken = token;
      _focusAttempts = 0;
      _scheduleLandFocus();
    }
  }

  void _scheduleLandFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _landFocusOnFirst());
  }

  void _landFocusOnFirst() {
    if (!mounted) return;
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;

    final scope = FocusScope.of(context);
    FocusNode? first;
    for (final node in scope.traversalDescendants) {
      if (identical(node, scope)) continue;
      if (!node.canRequestFocus || node.skipTraversal) continue;
      if (node.context == null) continue;
      first = node;
      break;
    }

    if (first != null) {
      first.requestFocus();
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null &&
          !identical(primary, scope) &&
          scope.hasFocus) {
        return;
      }
    } else if (scope.canRequestFocus) {
      scope.requestFocus();
    }

    if (_focusAttempts++ < 30) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _landFocusOnFirst());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsTokens.pagePadding,
              8,
              SettingsTokens.pagePadding,
              4,
            ),
            child: Row(
              children: [
                if (widget.showBack)
                  shellFocusableTap(
                    context: context,
                    onTap: widget.onBack ??
                        () => Navigator.of(context).maybePop(),
                    borderRadius: 20,
                    scaleOnFocus: 1.0,
                    showFocusBorder: true,
                    showFocusFill: true,
                    tvTabId: 'settings',
                    tvZone: ShellTvZone.settings,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: ForjaShellColors.textPrimary,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: SettingsTokens.pageTitleSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.scrollable
                ? Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        SettingsTokens.pagePadding,
                        8,
                        SettingsTokens.pagePadding,
                        48,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: SettingsTokens.detailMaxWidth,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SettingsTokens.pagePadding,
                      8,
                      SettingsTokens.pagePadding,
                      16,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth
                            .clamp(0.0, SettingsTokens.detailMaxWidth)
                            .toDouble();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: width,
                            height: constraints.maxHeight,
                            child: widget.child,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Toggle row used inside [SettingsGroup].
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ExcludeFocus(
            excluding: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
            child: ForjaSwitch(
              value: value,
              onChanged: onChanged,
              scale: ForjaSwitch.settingsScale,
            ),
          ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: () => onChanged(!value),
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

/// Dropdown select row used inside [SettingsGroup].
class SettingsSelectRow extends StatelessWidget {
  const SettingsSelectRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ExcludeFocus(
            excluding: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ForjaShellColors.sectionIconBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ForjaShellColors.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  dropdownColor: ForjaShellColors.cinematic.menuSurface,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: ForjaShellColors.brandGreen,
                    size: 20,
                  ),
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  items: options
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(o),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: () {
        if (options.isEmpty) return;
        final i = options.indexOf(value);
        final next = options[((i < 0 ? 0 : i) + 1) % options.length];
        onChanged(next);
      },
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

/// Tappable action / navigation row.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.destructive = false,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? const Color(0xFFF87171)
        : ForjaShellColors.textPrimary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ForjaShellColors.brandGreen,
              ),
            )
          else
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ForjaShellColors.iconMuted,
                ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: busy ? null : onTap,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      showFocusFill: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: content,
    );
  }
}

/// Slider row - TV: focus then ←/→ nudge immediately (no OK arm).
class SettingsSliderRow extends StatefulWidget {
  const SettingsSliderRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.onChangeEnd,
    this.divisions,
  });

  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int? divisions;

  @override
  State<SettingsSliderRow> createState() => _SettingsSliderRowState();
}

class _SettingsSliderRowState extends State<SettingsSliderRow> {
  bool _focused = false;

  void _nudge(double delta) {
    final span = widget.max - widget.min;
    final step = widget.divisions != null && widget.divisions! > 0
        ? span / widget.divisions!
        : span / 20;
    final next =
        (widget.value + delta * step).clamp(widget.min, widget.max).toDouble();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          ExcludeFocus(
            child: Slider(
              value: widget.value.clamp(widget.min, widget.max).toDouble(),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              activeColor: ForjaShellColors.brandGreen,
              inactiveColor: ForjaShellColors.borderSubtle,
              label: widget.label,
              onChanged: widget.onChanged,
              onChangeEnd: widget.onChangeEnd,
            ),
          ),
        ],
      ),
    );

    if (!tv) return content;

    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (!f) widget.onChangeEnd?.call(widget.value);
      },
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _nudge(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _nudge(1);
          return KeyEventResult.handled;
        }
        return shellTvLinearMenuArrows(context: context, event: event);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _focused ? ForjaShellColors.inkHover : Colors.transparent,
          border: _focused
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1,
                )
              : null,
        ),
        child: content,
      ),
    );
  }
}

/// Settings action button - thin wrapper over the shared [ForjaButton].
///
/// Hugs its label and left-aligns by default (never full-width in a stretch
/// column). Pass `expand: true` only when a caller explicitly wants a
/// width-filling button (e.g. inside a `Row`/`Expanded`).
///
/// `secondary: true` uses the neutral tone; otherwise the brand-green primary.
class SettingsFilledButton extends StatelessWidget {
  const SettingsFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.secondary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool secondary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = ForjaButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      busy: busy,
      expand: expand,
      height: 36,
      variant: secondary
          ? ForjaButtonVariant.neutral
          : ForjaButtonVariant.primary,
    );
    if (expand) return button;
    return Align(alignment: Alignment.centerRight, child: button);
  }
}

/// Flat underline text field - no filled box.
class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: enabled
            ? ForjaShellColors.textPrimary
            : ForjaShellColors.textSecondary.withValues(alpha: 0.55),
        fontSize: 14,
      ),
      cursorColor: ForjaShellColors.brandGreen,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        floatingLabelStyle: const TextStyle(color: ForjaShellColors.brandGreen),
        labelStyle: const TextStyle(color: ForjaShellColors.textSecondary),
        hintStyle: TextStyle(
          color: ForjaShellColors.textSecondary.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.only(top: 18, bottom: 10),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ForjaShellColors.borderSubtle),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: ForjaShellColors.borderSubtle.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ForjaShellColors.brandGreen, width: 2),
        ),
      ),
    );

    // TV detail panes: ←/→ keep caret editing; ↑/↓ move spatially among
    // neighboring controls (contained — not auto Left → nav).
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return field;
    }
    if (!ShellTvContainDpad.activeOf(context) &&
        !ShellTvLinearFocusScope.activeOf(context)) {
      return field;
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        final key = event.logicalKey;
        // Keep ←/→ for the caret (EditableText). Move focus only on ↑/↓.
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.ignored;
        }
        if (ShellTvLinearFocusScope.activeOf(context) &&
            !ShellTvDisableLinearFocus.activeOf(context)) {
          return shellTvLinearMenuArrows(context: context, event: event);
        }
        TraversalDirection? direction;
        if (key == LogicalKeyboardKey.arrowUp) {
          direction = TraversalDirection.up;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          direction = TraversalDirection.down;
        }
        if (direction != null &&
            (FocusManager.instance.primaryFocus ?? node)
                .focusInDirection(direction)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      },
      child: field,
    );
  }
}

/// Flat connected/status line - icon + title + subtitle, no box.
class SettingsStatusRow extends StatelessWidget {
  const SettingsStatusRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.check_circle_rounded,
    this.iconColor = ForjaShellColors.brandGreen,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Credits + version pinned to the bottom of the wide-settings sidebar.
class SettingsSidebarFooter extends StatelessWidget {
  const SettingsSidebarFooter({super.key});

  static const Color _loveAccent = Color(0xFFF472B6);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: ForjaShellColors.borderSubtle.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: ForjaShellColors.textSecondary,
                  ),
                  children: const [
                    TextSpan(text: 'Made with '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 15,
                        color: _loveAccent,
                      ),
                    ),
                    TextSpan(text: ' by '),
                    TextSpan(
                      text: 'Schmenka',
                      style: TextStyle(
                        color: ForjaShellColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AppVersionLabel(
                prefix: 'v',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary.withValues(
                    alpha: 0.85,
                  ),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Styled confirm dialog for settings destructive / overwrite actions.
Future<bool> showSettingsConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => ShellScope.rehost(
      context,
      _SettingsConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    ),
  );
  return result == true;
}

class _SettingsConfirmDialog extends StatefulWidget {
  const _SettingsConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_SettingsConfirmDialog> createState() => _SettingsConfirmDialogState();
}

class _SettingsConfirmDialogState extends State<_SettingsConfirmDialog> {
  final FocusNode _cancelFocus =
      FocusNode(debugLabel: 'settings-confirm-cancel');
  final FocusNode _confirmFocus =
      FocusNode(debugLabel: 'settings-confirm-ok');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      final node = widget.destructive ? _cancelFocus : _confirmFocus;
      if (node.canRequestFocus) node.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final confirmColor = widget.destructive
        ? const Color(0xFFF87171)
        : ForjaShellColors.brandGreen;

    Widget action({
      required String label,
      required Color color,
      required FontWeight weight,
      required FocusNode focus,
      required bool value,
      VoidCallback? onLeft,
      VoidCallback? onRight,
    }) {
      if (!tv) {
        return TextButton(
          onPressed: () => Navigator.pop(context, value),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: weight),
          ),
        );
      }
      return shellFocusableTap(
        context: context,
        onTap: () => Navigator.pop(context, value),
        focusNode: focus,
        borderRadius: 10,
        scaleOnFocus: ShellTokens.focusActiveScale,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        onLeftEdge: onLeft,
        onRightEdge: onRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: weight),
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(color: ForjaShellColors.textPrimary),
      ),
      content: Text(
        widget.body,
        style: const TextStyle(color: ForjaShellColors.textSecondary),
      ),
      actions: [
        action(
          label: 'Cancel',
          color: ForjaShellColors.textSecondary,
          weight: FontWeight.w500,
          focus: _cancelFocus,
          value: false,
          onRight: () {
            if (_confirmFocus.canRequestFocus) _confirmFocus.requestFocus();
          },
        ),
        action(
          label: widget.confirmLabel,
          color: confirmColor,
          weight: FontWeight.w700,
          focus: _confirmFocus,
          value: true,
          onLeft: () {
            if (_cancelFocus.canRequestFocus) _cancelFocus.requestFocus();
          },
        ),
      ],
    );
  }
}
