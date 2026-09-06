import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Green sparkles beside admin-only Settings titles (`accounts.is_admin`).
class SettingsAdminTitle extends StatelessWidget {
  const SettingsAdminTitle({
    super.key,
    required this.title,
    required this.style,
    this.sparkSize = 14,
    this.maxLines = 1,
  });

  final String title;
  final TextStyle style;
  final double sparkSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome,
          size: sparkSize,
          color: ForjaShellColors.brandGreen,
        ),
        SizedBox(width: sparkSize * 0.45),
        Flexible(
          child: Text(
            title,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

Widget settingsTitleText(
  String title,
  TextStyle style, {
  bool adminOnly = false,
  double sparkSize = 14,
  int maxLines = 1,
}) {
  if (!adminOnly) {
    return Text(
      title,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
  return SettingsAdminTitle(
    title: title,
    style: style,
    sparkSize: sparkSize,
    maxLines: maxLines,
  );
}

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
    this.adminOnly = false,
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
  final bool adminOnly;

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
    final iconColor = selected
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.iconMuted;
    final titleColor = selected
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;
    final rail = tvRowId != null;

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
                settingsTitleText(
                  title,
                  TextStyle(
                    color: titleColor,
                    fontSize: SettingsTokens.categoryTitleSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  adminOnly: adminOnly,
                  sparkSize: 13,
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
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      // Category rail chrome is the green left bar - never the gray menu ring.
      showFocusBorder: false,
      showFocusFill: false,
      listIndex: listIndex,
      tvTabId: 'settings',
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex ?? listIndex,
      tvZone: rail ? ShellTvZone.row : ShellTvZone.settings,
      // Item mode snaps the first tile to list top (header stays visible).
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onRightEdge: onRightEdge,
      focusNode: focusNode,
      onFocusChange: (focused) {
        // Auto-select on focus is leanback-only. Desktop also has
        // useFocusableMoodChips (hybrid D-pad), but resume/rebuild can dump
        // focus onto the first category tile (Profile) and was calling
        // onSelect(profile) — yanking the hub every background→foreground.
        final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
        if (leanback && focused && !selected) {
          // Defer — sync onSelect rebuilds the rail and rebinds
          // [firstTileFocusNode] onto the new tile, disposing the owned node
          // that just received D-pad focus (↓ looked dead on Playback → Sources).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            (onFocusSelect ?? onTap)();
          });
        }
      },
      child: child,
    );
  }
}

/// Leanback TV: [ExpansionTile.trailing] sits beside the header and steals ↓
/// into a horizontal strip. Omit [trailing] from the tile header on leanback —
/// callers place actions with [settingsExpansionSideActions] instead. Desktop
/// hybrid keeps trailing in the header (mouse + arrow keys).
Widget? settingsExpansionTrailing(BuildContext context, Widget? trailing) {
  if (trailing == null) return null;
  if (ShellScope.inputPolicyOf(context).leanbackOnly) return null;
  return trailing;
}

/// Flat ExpansionTile chrome — ink hover, no rounded Material card.
ThemeData settingsExpansionTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    dividerColor: Colors.transparent,
    hoverColor: ForjaShellColors.inkHover,
    splashColor: ForjaShellColors.inkSplash,
    highlightColor: Colors.transparent,
  );
}

/// [ExpansionTile.shape] / [collapsedShape] for flat settings headers.
const Border settingsExpansionShape = Border();

/// Leanback: keep [trailing] visible to the right of [tile] (switch / refresh /
/// remove). Desktop keeps actions in [ExpansionTile.trailing] via
/// [settingsExpansionTrailing]. Prefer [settingsExpandableWithSideActions] for
/// pack/addon rows so the header is [shellFocusableTap] (Material
/// [ExpansionTile] ListTile focus cannot move → to side actions — app-root
/// DirectionalFocus no-ops ←/→). Wrap the pack list in
/// [ShellTvDisableLinearFocus] so ↓ walks packs and → reaches the actions.
Widget settingsExpansionSideActions({
  required BuildContext context,
  required Widget tile,
  Widget? trailing,
}) {
  if (trailing == null || !ShellScope.inputPolicyOf(context).leanbackOnly) {
    return tile;
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: tile),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: trailing,
      ),
    ],
  );
}

/// Desktop: [ExpansionTile] with optional [trailing] in the header.
/// Leanback: focusable header + side actions — → lands on switch / icons.
Widget settingsExpandableWithSideActions({
  required BuildContext context,
  required Widget leading,
  required Widget title,
  Widget? subtitle,
  required List<Widget> children,
  Widget? trailing,
  EdgeInsetsGeometry tilePadding = const EdgeInsets.symmetric(horizontal: 2),
  EdgeInsetsGeometry childrenPadding = const EdgeInsets.fromLTRB(8, 0, 2, 8),
}) {
  if (!ShellScope.inputPolicyOf(context).leanbackOnly) {
    return Theme(
      data: settingsExpansionTheme(context),
      child: ExpansionTile(
        shape: settingsExpansionShape,
        collapsedShape: settingsExpansionShape,
        tilePadding: tilePadding,
        childrenPadding: childrenPadding,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: settingsExpansionTrailing(context, trailing),
        children: settingsExpansionChildren(
          context,
          trailing: trailing,
          children: children,
        ),
      ),
    );
  }
  return _SettingsTvExpandableSideRow(
    leading: leading,
    title: title,
    subtitle: subtitle,
    trailing: trailing,
    tilePadding: tilePadding,
    childrenPadding: childrenPadding,
    children: children,
  );
}

/// Leanback pack/addon expand row — header owns D-pad; → moves to [trailing].
class _SettingsTvExpandableSideRow extends StatefulWidget {
  const _SettingsTvExpandableSideRow({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.children,
    this.trailing,
    required this.tilePadding,
    required this.childrenPadding,
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsetsGeometry tilePadding;
  final EdgeInsetsGeometry childrenPadding;

  @override
  State<_SettingsTvExpandableSideRow> createState() =>
      _SettingsTvExpandableSideRowState();
}

class _SettingsTvExpandableSideRowState
    extends State<_SettingsTvExpandableSideRow> {
  bool _expanded = false;
  late final FocusNode _headerFocus =
      FocusNode(debugLabel: 'settings-pack-header');

  @override
  void dispose() {
    _headerFocus.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  void _focusHeader() {
    if (_headerFocus.canRequestFocus) _headerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: widget.tilePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: widget.leading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: ForjaShellColors.textPrimary,
                    ),
                    child: widget.title,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    widget.subtitle!,
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: ForjaShellColors.iconMuted,
            ),
          ),
        ],
      ),
    );

    Widget? trailing = widget.trailing;
    if (trailing != null) {
      trailing = SettingsExpandHeaderFocus(
        focusHeader: _focusHeader,
        child: trailing,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: shellFocusableTap(
                context: context,
                focusNode: _headerFocus,
                onTap: _toggle,
                borderRadius: SettingsTokens.categoryTileRadius,
                scaleOnFocus: 1.0,
                showFocusRail: false,
                showFocusFill: true,
                showFocusBorder: false,
                tvTabId: 'settings',
                tvZone: ShellTvZone.settings,
                ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                child: header,
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: trailing,
              ),
          ],
        ),
        if (_expanded)
          Padding(
            padding: widget.childrenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// Lets side-action controls (pack switch) send ← back to the expand header.
class SettingsExpandHeaderFocus extends InheritedWidget {
  const SettingsExpandHeaderFocus({
    super.key,
    required this.focusHeader,
    required super.child,
  });

  final VoidCallback focusHeader;

  static VoidCallback? maybeFocusHeaderOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<SettingsExpandHeaderFocus>()
      ?.focusHeader;

  @override
  bool updateShouldNotify(covariant SettingsExpandHeaderFocus oldWidget) =>
      focusHeader != oldWidget.focusHeader;
}

List<Widget> settingsExpansionChildren(
  BuildContext context, {
  Widget? trailing,
  required List<Widget> children,
}) {
  // Actions live in the header (desktop) or beside the tile (leanback via
  // [settingsExpansionSideActions]) — never duplicated inside the expansion.
  return children;
}

/// Flat labeled section of settings rows - no card box, hairline row dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.label,
    this.adminOnly = false,
    required this.children,
  });

  final String? label;
  final bool adminOnly;
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
                  settingsTitleText(
                    label!.toUpperCase(),
                    const TextStyle(
                      color: ForjaShellColors.brandGreen,
                      fontSize: SettingsTokens.groupLabelSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                    adminOnly: adminOnly,
                    sparkSize: 12,
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
    this.adminOnly = false,
  });

  final String title;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  /// When false, [child] fills the remaining height (no outer scroll).
  final bool scrollable;

  /// Admin category — sparkles on the page title.
  final bool adminOnly;

  @override
  State<SettingsPageScaffold> createState() => _SettingsPageScaffoldState();
}

class _SettingsPageScaffoldState extends State<SettingsPageScaffold>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  int _handledEnterToken = 0;
  int _focusAttempts = 0;

  /// Extra bottom scroll padding so a focused text field can sit above the IME.
  /// Leanback keyboards often overlay without shrinking the Flutter view /
  /// reporting viewInsets — then we reserve a fraction of the screen.
  double _imeScrollPad = 0;

  static const _editFocusLabel = 'settings-text-edit';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Catch raw Material buttons (LAN Discover, etc.) that never call
    // shellTvEnsureVisibleItem themselves.
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChange);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _syncImeScrollPad(revealFocused: true);
  }

  bool get _editingSettingsField {
    final label = FocusManager.instance.primaryFocus?.debugLabel;
    return label == _editFocusLabel;
  }

  void _syncImeScrollPad({required bool revealFocused}) {
    if (!mounted || !widget.scrollable) return;
    final leanback = ShellScope.inputPolicyOf(context).instantFocusChrome;
    final view = View.of(context);
    final rawIme = view.viewInsets.bottom / view.devicePixelRatio;
    final inheritedIme = MediaQuery.viewInsetsOf(context).bottom;
    var pad = rawIme > inheritedIme ? rawIme : inheritedIme;
    // Android TV leanback IME often reports 0 while covering ~40% of the screen.
    if (leanback && _editingSettingsField && pad < 1) {
      pad = MediaQuery.sizeOf(context).height * 0.42;
    }
    if ((pad - _imeScrollPad).abs() < 0.5) {
      if (revealFocused && pad > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _revealFocusedField();
        });
      }
      return;
    }
    setState(() => _imeScrollPad = pad);
    if (revealFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealFocusedField();
      });
    }
  }

  void _revealFocusedField() {
    if (!mounted || !widget.scrollable) return;
    if (!_scrollController.hasClients) return;
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    if (policy == null || !policy.ensureVisibleOnFocus) return;

    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null || !ctx.mounted) return;

    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return;
    if (!identical(scrollable.position, _scrollController.position)) return;

    // Pin editing fields into the upper band so they clear the overlay IME.
    if (primary!.debugLabel == _editFocusLabel && _imeScrollPad > 0) {
      Scrollable.ensureVisible(ctx, alignment: 0.18, duration: Duration.zero);
      return;
    }
    shellTvEnsureVisibleItem(ctx);
  }

  void _onFocusChange() {
    _syncImeScrollPad(revealFocused: true);
    if (_imeScrollPad <= 0) _revealFocusedField();
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

  void _snapScrollToTop() {
    if (!mounted || !_scrollController.hasClients) return;
    final min = _scrollController.position.minScrollExtent;
    if (_scrollController.offset > min) {
      _scrollController.jumpTo(min);
    }
  }

  void _landFocusOnFirst() {
    if (!mounted) return;
    if (!ShellScope.metricsOf(context).usesTvDensity) return;

    final scope = FocusScope.of(context);

    // Already on a real detail control (not the bare scope).
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        !identical(primary, scope) &&
        primary.context != null &&
        primary.canRequestFocus &&
        scope.hasFocus) {
      return;
    }

    final policy =
        FocusTraversalGroup.maybeOf(context) ?? ReadingOrderTraversalPolicy();
    final fromPolicy = policy.findFirstFocus(scope, ignoreCurrentFocus: true);
    FocusNode? first;
    if (fromPolicy != null &&
        !identical(fromPolicy, scope) &&
        fromPolicy.canRequestFocus &&
        !fromPolicy.skipTraversal &&
        fromPolicy.context != null) {
      first = fromPolicy;
    } else {
      for (final node in scope.descendants) {
        if (identical(node, scope)) continue;
        if (node is FocusScopeNode) continue;
        if (!node.canRequestFocus || node.skipTraversal) continue;
        if (node.context == null) continue;
        first = node;
        break;
      }
    }

    if (first != null) {
      first.requestFocus();
      // After focus ensureVisible runs, re-pin to absolute top so title +
      // section labels above the first control stay on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) => _snapScrollToTop());
      if (first.hasPrimaryFocus || first.hasFocus) return;
    }

    if (_focusAttempts++ < 30) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _landFocusOnFirst());
    }
  }

  Widget _titleRow({required bool includeBack}) {
    return Row(
      children: [
        if (includeBack)
          shellFocusableTap(
            context: context,
            onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
            borderRadius: 20,
            scaleOnFocus: 1.0,
            // Circular control: soft rounded fill + hairline — never green left rail.
            showFocusRail: false,
            showFocusFill: true,
            showFocusBorder: true,
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
          child: settingsTitleText(
            widget.title,
            const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: SettingsTokens.pageTitleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            adminOnly: widget.adminOnly,
            sparkSize: 18,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    // TV: title lives inside the scroller so snap-to-top reveals it with the
    // section labels above the first control (sticky chrome was getting clipped).
    final titleTop = tv ? 28.0 : 8.0;
    final tvBottomSlack = tv && widget.scrollable
        ? MediaQuery.sizeOf(context).height * 0.22
        : 0.0;
    return SafeArea(
      child: widget.scrollable
          ? Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  SettingsTokens.pagePadding,
                  titleTop,
                  SettingsTokens.pagePadding,
                  48 + _imeScrollPad + tvBottomSlack,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: SettingsTokens.detailMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _titleRow(includeBack: widget.showBack),
                        const SizedBox(height: 12),
                        widget.child,
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    SettingsTokens.pagePadding,
                    titleTop,
                    SettingsTokens.pagePadding,
                    4,
                  ),
                  child: _titleRow(includeBack: widget.showBack),
                ),
                Expanded(
                  child: Padding(
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
    this.enabled = true,
    this.adminOnly = false,
    this.leadingCheckValue,
    this.onLeadingCheckChanged,
    this.leadingCheckLabel = 'Auto',
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool adminOnly;

  /// Optional checkbox before the switch (e.g. Forja Auto).
  final bool? leadingCheckValue;
  final ValueChanged<bool>? onLeadingCheckChanged;
  final String leadingCheckLabel;

  @override
  Widget build(BuildContext context) {
    final titleColor = enabled
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;
    final checkEnabled = enabled && value && onLeadingCheckChanged != null;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final content = Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  settingsTitleText(
                    title,
                    TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    adminOnly: adminOnly,
                    sparkSize: 13,
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
              excluding: tv,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingCheckValue != null) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: checkEnabled
                          ? () => onLeadingCheckChanged!(!leadingCheckValue!)
                          : null,
                      child: Opacity(
                        opacity: checkEnabled ? 1 : 0.45,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: leadingCheckValue,
                                onChanged: checkEnabled
                                    ? (v) {
                                        if (v != null) {
                                          onLeadingCheckChanged!(v);
                                        }
                                      }
                                    : null,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(
                                  color: checkEnabled
                                      ? ForjaShellColors.textSecondary
                                      : ForjaShellColors.borderSubtle,
                                ),
                                activeColor: ForjaShellColors.brandGreen,
                                checkColor: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              leadingCheckLabel,
                              style: TextStyle(
                                color: checkEnabled
                                    ? ForjaShellColors.textPrimary
                                    : ForjaShellColors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  ForjaSwitch(
                    value: value,
                    onChanged: enabled ? onChanged : null,
                    scale: ForjaSwitch.settingsScale,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: content,
    );
  }
}

/// Dropdown select row used inside [SettingsGroup].
///
/// Desktop/phone: Material [DropdownButton] (same chrome as before).
/// TV: same chrome, focus on the row; OK opens a D-pad option list.
class SettingsSelectRow extends StatelessWidget {
  const SettingsSelectRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
    this.adminOnly = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool adminOnly;

  Future<void> _openPicker(BuildContext context) async {
    if (options.isEmpty) return;
    final picked = await showSettingsSelectDialog(
      context: context,
      title: title,
      value: value,
      options: options,
    );
    if (!context.mounted || picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                settingsTitleText(
                  title,
                  const TextStyle(
                    color: ForjaShellColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  adminOnly: adminOnly,
                  sparkSize: 13,
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
            excluding: tv,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ForjaShellColors.sectionIconBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ForjaShellColors.borderSubtle),
              ),
              child: tv
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ForjaShellColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: ForjaShellColors.brandGreen,
                          size: 20,
                        ),
                      ],
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: options.contains(value) ? value : null,
                        hint: Text(
                          value,
                          style: const TextStyle(
                            color: ForjaShellColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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
                              (o) => DropdownMenuItem(value: o, child: Text(o)),
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
      onTap: () => _openPicker(context),
      onKeyEvent: tv
          ? (node, event) {
              if (shellTvIsActivateKey(event)) {
                _openPicker(context);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: content,
    );
  }
}

/// Option list for [SettingsSelectRow] (TV D-pad / desktop click).
Future<String?> showSettingsSelectDialog({
  required BuildContext context,
  required String title,
  required String value,
  required List<String> options,
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) => ShellScope.rehost(
      context,
      _SettingsSelectDialog(title: title, value: value, options: options),
    ),
  );
}

class _SettingsSelectDialog extends StatefulWidget {
  const _SettingsSelectDialog({
    required this.title,
    required this.value,
    required this.options,
  });

  final String title;
  final String value;
  final List<String> options;

  @override
  State<_SettingsSelectDialog> createState() => _SettingsSelectDialogState();
}

class _SettingsSelectDialogState extends State<_SettingsSelectDialog> {
  final ScrollController _scrollController = ScrollController();
  late final List<FocusNode> _nodes = List.generate(
    widget.options.length,
    (i) => FocusNode(debugLabel: 'settings-select-$i'),
  );
  int? _focusedIndex;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _nodes.length; i++) {
      final index = i;
      _nodes[index].addListener(() {
        if (!mounted) return;
        if (_nodes[index].hasFocus) {
          setState(() => _focusedIndex = index);
        } else if (_focusedIndex == index) {
          setState(() => _focusedIndex = null);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var i = widget.options.indexOf(widget.value);
      if (i < 0) i = 0;
      final node = _nodes[i.clamp(0, _nodes.length - 1)];
      if (node.canRequestFocus) node.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final size = MediaQuery.sizeOf(context);
    final maxH = size.height * 0.65;
    final maxW = (size.width * 0.45).clamp(320.0, 520.0);

    Widget optionRow(int index) {
      final option = widget.options[index];
      final selected = option == widget.value;
      final focused = _focusedIndex == index;
      final emphasize = selected || focused;
      final row = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  color: emphasize
                      ? ForjaShellColors.textPrimary
                      : ForjaShellColors.textSecondary,
                  fontSize: 15,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                color: ForjaShellColors.brandGreen,
                size: 22,
              ),
          ],
        ),
      );

      void pick() => Navigator.of(context, rootNavigator: true).pop(option);

      if (!tv) {
        return shellRoundedInkHost(
          radius: SettingsTokens.categoryTileRadius,
          onTap: pick,
          decoration: BoxDecoration(
            color: selected ? ForjaShellColors.inkHover : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected
                    ? ForjaShellColors.brandGreen
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: row,
        );
      }

      return shellFocusableTap(
        context: context,
        focusNode: _nodes[index],
        onTap: pick,
        borderRadius: SettingsTokens.categoryTileRadius,
        scaleOnFocus: 1.0,
        showFocusRail: true,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        child: row,
      );
    }

    final list = SizedBox(
      width: maxW,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: _scrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: widget.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (_, i) => optionRow(i),
          ),
        ),
      ),
    );

    final dialog = AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: list,
    );

    if (!tv) return dialog;
    return ShellTvContainDpad(child: ShellTvLinearFocusScope(child: dialog));
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
    this.adminOnly = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback? onTap;
  final bool busy;
  final bool adminOnly;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? const Color(0xFFF87171)
        : ForjaShellColors.textPrimary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                settingsTitleText(
                  title,
                  TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  adminOnly: adminOnly,
                  sparkSize: 13,
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
      // Flat green left-bar + ink (same as category rail) — no rounded card.
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
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
  bool _hovered = false;

  bool get _chromeActive => _focused || _hovered;

  void _nudge(double delta) {
    final span = widget.max - widget.min;
    final step = widget.divisions != null && widget.divisions! > 0
        ? span / widget.divisions!
        : span / 20;
    final next = (widget.value + delta * step)
        .clamp(widget.min, widget.max)
        .toDouble();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final sliderBody = Padding(
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
          MouseRegion(
            onEnter: (_) {
              if (_hovered) return;
              setState(() => _hovered = true);
            },
            onExit: (_) {
              if (!_hovered) return;
              setState(() => _hovered = false);
            },
            child: ExcludeFocus(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  // Focus/hover chrome is the thumb — not a row left-bar fill.
                  thumbColor: _chromeActive
                      ? Colors.white
                      : ForjaShellColors.brandGreen,
                  overlayColor: Colors.transparent,
                  activeTrackColor: ForjaShellColors.brandGreen,
                  inactiveTrackColor: ForjaShellColors.borderSubtle,
                ),
                child: Slider(
                  value: widget.value.clamp(widget.min, widget.max).toDouble(),
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  label: widget.label,
                  onChanged: widget.onChanged,
                  onChangeEnd: widget.onChangeEnd,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!tv) return sliderBody;

    // D-pad owns the row for ←/→ nudge — chrome stays on the Slider thumb,
    // not a green left-bar over the title/space.
    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          shellTvEnsureVisibleItem(context);
        } else {
          widget.onChangeEnd?.call(widget.value);
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) {
          ShellTvHoldAccel.note(event);
          return KeyEventResult.ignored;
        }
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        ShellTvHoldAccel.note(event);
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _nudge(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _nudge(1);
          return KeyEventResult.handled;
        }
        // Settings panes are linear vertical lists — ↑/↓ = prev/next row.
        if (ShellTvLinearFocusScope.activeOf(context) &&
            !ShellTvDisableLinearFocus.activeOf(context)) {
          return shellTvLinearMenuArrows(context: context, event: event);
        }
        TraversalDirection? direction;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          direction = TraversalDirection.up;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          direction = TraversalDirection.down;
        }
        if (direction != null) {
          final steps = ShellTvHoldAccel.lastStep;
          var n = node;
          var moved = false;
          for (var i = 0; i < steps; i++) {
            if (!n.focusInDirection(direction)) break;
            moved = true;
            n = FocusManager.instance.primaryFocus ?? n;
          }
          if (moved) return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: sliderBody,
    );
  }
}

/// Text action for settings lists — [TextButton] on touch/desktop;
/// [shellFocusableTap] on TV so D-pad owns a single focus node.
class SettingsTextAction extends StatelessWidget {
  const SettingsTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = ForjaShellColors.brandGreen,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = TextStyle(
      color: enabled ? color : color.withValues(alpha: 0.4),
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (!tv) {
      return TextButton(
        onPressed: onPressed,
        child: Text(label, style: style),
      );
    }
    if (!enabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: style),
      );
    }
    return shellFocusableTap(
      context: context,
      onTap: onPressed,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusRail: false,
      showFocusFill: true,
      showFocusBorder: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: style),
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
///
/// On Android TV: D-pad focus lands on a browse [Focus] wrapper — never on
/// [EditableText] — so the IME stays closed until OK/Select. Back leaves edit
/// mode and restores browse focus on the same field.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final FocusNode _browseFocus = FocusNode(
    debugLabel: 'settings-text-browse',
  );
  late final FocusNode _editFocus = FocusNode(debugLabel: 'settings-text-edit');
  bool _editing = false;

  /// True while switching browse ↔ edit so a one-frame unfocused gap does not
  /// clear [_editing] before the target node receives focus.
  bool _focusHandoff = false;

  bool get _tv {
    final policy = ShellScope.inputPolicyOf(context);
    return policy.useFocusableMoodChips && !policy.scaleOnHover;
  }

  bool get _browseOnly => _tv && !_editing;

  @override
  void initState() {
    super.initState();
    _browseFocus.onKeyEvent = _handleTvKey;
    _editFocus.onKeyEvent = _handleTvKey;
    _browseFocus.addListener(_onFocusChange);
    _editFocus.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFocusModes();
  }

  @override
  void didUpdateWidget(covariant SettingsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncFocusModes();
  }

  @override
  void dispose() {
    _browseFocus.removeListener(_onFocusChange);
    _editFocus.removeListener(_onFocusChange);
    _browseFocus.onKeyEvent = null;
    _editFocus.onKeyEvent = null;
    _browseFocus.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _syncFocusModes() {
    final enabled = widget.enabled;
    if (!_tv) {
      _browseFocus
        ..canRequestFocus = false
        ..skipTraversal = true;
      _editFocus
        ..canRequestFocus = enabled
        ..skipTraversal = false;
      return;
    }
    // Browse focus owns the field until OK; EditableText stays out of traversal
    // so Android never attaches an IME on D-pad land.
    _browseFocus
      ..canRequestFocus = enabled && !_editing
      ..skipTraversal = _editing;
    _editFocus
      ..canRequestFocus = enabled && _editing
      ..skipTraversal = !_editing;
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_focusHandoff) {
      if (_editing && _editFocus.hasFocus) _focusHandoff = false;
      if (!_editing && _browseFocus.hasFocus) _focusHandoff = false;
      setState(() {});
      return;
    }
    if (_editing && !_editFocus.hasFocus && !_browseFocus.hasFocus) {
      setState(() => _editing = false);
      _syncFocusModes();
      return;
    }
    if (_browseFocus.hasFocus || _editFocus.hasFocus) {
      shellTvEnsureVisibleItem(context);
    }
    setState(() {});
  }

  void _beginEditing() {
    if (!mounted || !widget.enabled) return;
    _focusHandoff = true;
    setState(() => _editing = true);
    _syncFocusModes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _editFocus.requestFocus();
      // IME opens after edit focus — second frame lets settings scroller pad
      // for the keyboard and pin this field above it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_editing) return;
        shellTvEnsureVisibleItem(context);
        Scrollable.ensureVisible(
          context,
          alignment: 0.18,
          duration: Duration.zero,
        );
      });
    });
  }

  void _endEditing({bool keepBrowseFocus = true}) {
    if (!mounted) return;
    _focusHandoff = true;
    if (_editing) setState(() => _editing = false);
    _syncFocusModes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (keepBrowseFocus && _browseFocus.canRequestFocus) {
        _browseFocus.requestFocus();
      } else {
        _focusHandoff = false;
      }
    });
  }

  KeyEventResult _handleTvKey(FocusNode node, KeyEvent event) {
    if (!_tv) return KeyEventResult.ignored;

    if (event is KeyUpEvent) {
      ShellTvHoldAccel.note(event);
      return KeyEventResult.ignored;
    }

    if (_browseOnly && shellTvIsActivateKey(event)) {
      _beginEditing();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        _editing &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack)) {
      _endEditing();
      return KeyEventResult.handled;
    }

    final inContain = ShellTvContainDpad.activeOf(context);
    final inLinear = ShellTvLinearFocusScope.activeOf(context);
    if (!inContain && !inLinear) return KeyEventResult.ignored;
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
    ShellTvHoldAccel.note(event);

    final key = event.logicalKey;
    // Editing: ←/→ keep the caret; browse: all arrows move focus.
    if (!_browseOnly &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      return KeyEventResult.ignored;
    }

    if (inLinear && !ShellTvDisableLinearFocus.activeOf(context)) {
      return shellTvLinearMenuArrows(context: context, event: event);
    }

    TraversalDirection? direction;
    if (key == LogicalKeyboardKey.arrowUp) {
      direction = TraversalDirection.up;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      direction = TraversalDirection.down;
    } else if (_browseOnly && key == LogicalKeyboardKey.arrowLeft) {
      direction = TraversalDirection.left;
    } else if (_browseOnly && key == LogicalKeyboardKey.arrowRight) {
      direction = TraversalDirection.right;
    }
    if (direction != null) {
      final vertical =
          direction == TraversalDirection.up ||
          direction == TraversalDirection.down;
      final steps = vertical ? ShellTvHoldAccel.lastStep : 1;
      var n = FocusManager.instance.primaryFocus ?? node;
      var moved = false;
      for (var i = 0; i < steps; i++) {
        if (!n.focusInDirection(direction)) break;
        moved = true;
        n = FocusManager.instance.primaryFocus ?? n;
      }
      if (moved) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final browseHighlight = _browseOnly && _browseFocus.hasFocus;
    final field = TextField(
      controller: widget.controller,
      focusNode: _editFocus,
      obscureText: widget.obscureText,
      enabled: enabled,
      readOnly: _browseOnly,
      showCursor: !_browseOnly,
      enableInteractiveSelection: !_browseOnly,
      // Belt-and-suspenders: even if edit focus leaks, no IME in browse.
      keyboardType: _browseOnly
          ? TextInputType.none
          : (widget.keyboardType ?? TextInputType.text),
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onTap: _tv && !_editing ? _beginEditing : null,
      onSubmitted: (value) {
        if (_tv) _endEditing();
        widget.onSubmitted?.call(value);
      },
      style: TextStyle(
        color: enabled
            ? ForjaShellColors.textPrimary
            : ForjaShellColors.textSecondary.withValues(alpha: 0.55),
        fontSize: 14,
      ),
      cursorColor: ForjaShellColors.brandGreen,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        isDense: true,
        counterText: widget.maxLength != null ? '' : null,
        floatingLabelStyle: TextStyle(
          color: browseHighlight
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.textSecondary,
        ),
        labelStyle: const TextStyle(color: ForjaShellColors.textSecondary),
        hintStyle: TextStyle(
          color: ForjaShellColors.textSecondary.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.only(top: 18, bottom: 10),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: browseHighlight
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.borderSubtle,
            width: browseHighlight ? 2 : 1,
          ),
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

    if (!_tv) return field;

    return Focus(
      focusNode: _browseFocus,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !_editing ? _beginEditing : null,
        child: field,
      ),
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
                  color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
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
  final FocusNode _cancelFocus = FocusNode(
    debugLabel: 'settings-confirm-cancel',
  );
  final FocusNode _confirmFocus = FocusNode(debugLabel: 'settings-confirm-ok');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
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
