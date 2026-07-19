part of 'iptv_pt_screen.dart';

class _CategorySidebarRow extends StatefulWidget {
  const _CategorySidebarRow({
    required this.label,
    required this.selected,
    required this.compact,
    required this.listIndex,
    required this.onTap,
    this.icon,
    this.onUpEdge,
    this.onRightEdge,
  });

  final String label;
  final bool selected;
  final bool compact;
  final int listIndex;
  final VoidCallback onTap;
  final IconData? icon;
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

    return iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      listIndex: widget.listIndex,
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
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 12,
          vertical: widget.compact ? 10 : 12,
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
              // Selected / TV focus / hover — keep rail so hover isn't "flat".
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
          ],
        ),
      ),
    );
  }
}

IconData? _iptvCategoryIcon(String categoryId) {
  if (categoryId == IptvLiveCatalog.favoritesId) return Icons.star_rounded;
  if (categoryId == IptvLiveCatalog.watchedId) {
    return Icons.history_rounded;
  }
  return null;
}
