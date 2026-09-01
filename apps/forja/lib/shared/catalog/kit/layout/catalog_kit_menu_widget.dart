import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_focus.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layout widget [`CatalogKitTypes.menu`] — underline kind/filter menu.
class CatalogKitMenuWidget extends StatelessWidget {
  const CatalogKitMenuWidget({
    super.key,
    required this.tabId,
    required this.spec,
    this.sortOrder = 0,
    this.count,
    this.firstFocusNode,
  });

  final String tabId;
  final Map<String, dynamic> spec;
  final int sortOrder;
  final int? count;
  final FocusNode? firstFocusNode;

  String get _widgetId => (spec['id'] ?? 'menu').toString();
  bool get _toggle => spec['toggle'] == true;
  List<({String id, String label})> get _items => catalogKitItemsFromSpec(spec);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scope = CatalogLayoutScope.of(context);
    final selected = scope.selectedId(_widgetId);
    final focusUp = catalogKitFocusEdge(
      tabId,
      spec['focusUp']?.toString(),
      last: true,
    );
    final focusDown = catalogKitFocusEdge(tabId, spec['focusDown']?.toString());

    final useTv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final tabGap = useTv
        ? 28.0
        : MediaQuery.sizeOf(context).width < 560
        ? 20.0
        : 36.0;

    return TvCatalogRow(
      tabId: tabId,
      rowId: _widgetId,
      sortOrder: sortOrder,
      itemCount: _items.length,
      onFocusUp: focusUp ?? () {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShellTokens.compactChromeLeadingInset(context),
          ShellTokens.tabHeaderTopPadding,
          ShellTokens.bodyHorizontalPadding,
          4,
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) SizedBox(width: tabGap),
                _MenuTab(
                  label: _items[i].label,
                  isActive: selected == _items[i].id,
                  onTap: () => scope.onSelect(
                    _widgetId,
                    _items[i].id,
                    toggle: _toggle,
                  ),
                  tvFocus: useTv,
                  tabId: tabId,
                  rowId: _widgetId,
                  listIndex: i,
                  onDownEdge: focusDown ?? () {},
                  focusNode: i == 0 ? firstFocusNode : null,
                ),
              ],
              const Spacer(),
              if (count != null && count! > 0)
                Text(
                  '$count',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTab extends StatefulWidget {
  const _MenuTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tvFocus,
    required this.tabId,
    required this.rowId,
    required this.listIndex,
    required this.onDownEdge,
    this.focusNode,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool tvFocus;
  final String tabId;
  final String rowId;
  final int listIndex;
  final VoidCallback onDownEdge;
  final FocusNode? focusNode;

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _hoverT = 0.62;
  static const _selectedT = 1.0;

  bool _hovered = false;
  bool _focused = false;

  double get _visualTarget {
    if (widget.isActive) return _selectedT;
    final policy = ShellScope.inputPolicyOf(context);
    if (_hovered || policy.focusStyled(context, focused: _focused)) {
      return _hoverT;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final child = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _visualTarget),
      duration: _animDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final idle = ForjaShellColors.cinematic.textSecondary;
        final hoverWhite = Colors.white.withValues(alpha: 0.92);
        final color = t <= 0
            ? idle
            : t < _hoverT
            ? Color.lerp(idle, hoverWhite, t / _hoverT)!
            : Color.lerp(
                hoverWhite,
                Colors.white,
                (t - _hoverT) / (_selectedT - _hoverT),
              )!;
        final tabHeight = shellScaled(context, 34).clamp(28.0, 34.0);
        final tabFont = shellScaled(context, 17).clamp(14.0, 17.0);
        final hoverW = shellScaled(context, 28).clamp(14.0, 28.0);
        final underline = t <= 0
            ? 0.0
            : t < _hoverT
            ? hoverW * (t / _hoverT)
            : hoverW +
                  shellScaled(context, 4).clamp(2.0, 4.0) *
                      ((t - _hoverT) / (_selectedT - _hoverT));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: tabHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tabFont,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      t,
                    ),
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: shellScaled(
                context,
                ShellTokens.shellCategoryUnderlineGap,
              ).clamp(2.0, ShellTokens.shellCategoryUnderlineGap),
            ),
            Container(
              height: shellScaled(
                context,
                ShellTokens.shellNavUnderlineHeight,
              ).clamp(1.0, ShellTokens.shellNavUnderlineHeight),
              width: underline,
              decoration: BoxDecoration(
                color: underline > 0 ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );

    if (widget.tvFocus) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 4,
        scaleOnFocus: ShellTokens.focusActiveScale,
        listIndex: widget.listIndex,
        tvTabId: widget.tabId,
        tvRowId: widget.rowId,
        tvZone: ShellTvZone.row,
        tvItemIndex: widget.listIndex,
        onDownEdge: widget.onDownEdge,
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) => setState(() => _hovered = h),
        child: child,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}
