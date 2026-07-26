part of 'iptv_pt_screen.dart';

class _CategorySidebarRow extends StatefulWidget {
  const _CategorySidebarRow({
    super.key,
    required this.label,
    required this.selected,
    required this.compact,
    required this.listIndex,
    required this.onTap,
    this.icon,
    this.pinnable = false,
    this.pinned = false,
    this.onTogglePin,
    this.reorderIndex,
    this.onUpEdge,
    this.onRightEdge,
  });

  final String label;
  final bool selected;
  final bool compact;
  final int listIndex;
  final VoidCallback onTap;
  final IconData? icon;
  final bool pinnable;
  final bool pinned;
  final VoidCallback? onTogglePin;
  /// Non-null → whole row is a reorder drag target.
  final int? reorderIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_CategorySidebarRow> createState() => _CategorySidebarRowState();
}

class _CategorySidebarRowState extends State<_CategorySidebarRow> {
  bool _focused = false;
  bool _hovered = false;

  bool get _tvFocused => iptvTvFocused(context, focused: _focused);

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  bool get _showPin =>
      widget.pinnable &&
      widget.onTogglePin != null &&
      (widget.pinned || _hovered || _tvFocused);

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final highlight = selected || _tvFocused;
    final emphatic = selected || _active || _tvFocused;
    final iconColor = _tvFocused || selected
        ? ForjaShellColors.brandGreen
        : _active
            ? Colors.white
            : ForjaShellColors.textSecondary;
    final titleColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : emphatic
            ? Colors.white
            : ForjaShellColors.textSecondary;

    Widget row = iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      listIndex: widget.listIndex,
      // Vertical category column is the catalog's left edge - Left → nav rail
      // (not only listIndex 0; vertical rows otherwise trap ←).
      navLeftAlways: true,
      tvRowId: 'browser-categories',
      tvItemIndex: widget.listIndex,
      onUpEdge: widget.onUpEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        // Keep channel grid on the focused group (Settings category rail pattern).
        if (focused &&
            !widget.selected &&
            iptvUseTvFocus(context)) {
          widget.onTap();
        }
      },
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: widget.compact ? 42 : 46,
        padding: EdgeInsets.only(
          left: widget.compact ? 10 : 12,
          right: widget.compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: _tvFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
              : selected
                  ? ForjaShellColors.inkHover
                  : _active
                      ? ForjaShellColors.inkHover
                      : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: highlight
                  ? ForjaShellColors.brandGreen
                  : _active
                      ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
                      : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: widget.compact ? 18 : 20, color: iconColor),
              SizedBox(width: widget.compact ? 10 : 12),
            ],
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: titleColor,
                  fontSize: widget.compact ? 13 : 14,
                  fontWeight: emphatic ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (_showPin)
              ExcludeFocus(
                excluding: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
                child: Tooltip(
                  message: widget.pinned ? 'Unpin category' : 'Pin category',
                  waitDuration: const Duration(milliseconds: 400),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: widget.onTogglePin,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          widget.pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          size: widget.compact ? 16 : 17,
                          color: ForjaShellColors.iconMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final reorderIndex = widget.reorderIndex;
    if (reorderIndex == null) return row;
    return _CategoryReorderDragStartListener(
      index: reorderIndex,
      child: row,
    );
  }
}

/// Hold ~1.5s before category reorder begins (tap/scroll stay normal).
class _CategoryReorderDragStartListener extends ReorderableDragStartListener {
  const _CategoryReorderDragStartListener({
    required super.child,
    required super.index,
  });

  static const Duration _delay = Duration(milliseconds: 1500);

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: _delay,
      debugOwner: this,
    );
  }
}

/// Floating drag proxy: lifted card, elevated surface, brand-green accent.
Widget _iptvCategoryReorderProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Transform.translate(
        offset: Offset(6 * t, -6 * t),
        child: Transform.scale(
          scale: 1 + 0.04 * t,
          alignment: Alignment.centerLeft,
          child: Material(
            elevation: 12 * t,
            color: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color.lerp(
                        ForjaShellColors.surfaceElevated,
                        const Color(0xFF1E2A22),
                        t,
                      )!,
                    ),
                  ),
                  child!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ForjaShellColors.brandGreen
                                .withValues(alpha: 0.28 + 0.52 * t),
                            width: 1.5,
                          ),
                          color: ForjaShellColors.brandGreen
                              .withValues(alpha: 0.10 * t),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    child: child,
  );
}

IconData? _iptvCategoryIcon(String categoryId) {
  if (categoryId == IptvLiveCatalog.favoritesId) return Icons.star_rounded;
  if (categoryId == IptvLiveCatalog.watchedId) {
    return Icons.history_rounded;
  }
  return null;
}
