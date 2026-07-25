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
      // Vertical category column is the catalog's left edge — Left → nav rail
      // (not only listIndex 0; vertical rows otherwise trap ←).
      navLeftAlways: true,
      tvRowId: 'browser-categories',
      tvItemIndex: widget.listIndex,
      onUpEdge: widget.onUpEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
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
    return ReorderableDragStartListener(index: reorderIndex, child: row);
  }
}

IconData? _iptvCategoryIcon(String categoryId) {
  if (categoryId == IptvLiveCatalog.favoritesId) return Icons.star_rounded;
  if (categoryId == IptvLiveCatalog.watchedId) {
    return Icons.history_rounded;
  }
  return null;
}
