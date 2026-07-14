part of 'iptv_pt_screen.dart';

class _CategorySidebarRow extends StatefulWidget {
  const _CategorySidebarRow({
    required this.label,
    required this.selected,
    required this.compact,
    required this.listIndex,
    required this.onTap,
    this.onUpEdge,
    this.onRightEdge,
  });

  final String label;
  final bool selected;
  final bool compact;
  final int listIndex;
  final VoidCallback onTap;
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
    final fg = _tvFocused
        ? ForjaShellColors.brandGreen
        : (selected ? Colors.white : Colors.white70);

    return iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 8,
      listIndex: widget.listIndex,
      tvRowId: 'browser-categories',
      tvItemIndex: widget.listIndex,
      onUpEdge: widget.onUpEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 14,
          vertical: widget.compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: _tvFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
              : selected
                  ? IptvShellStyle.accent.withValues(alpha: 0.12)
                  : _active
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _tvFocused
                  ? ForjaShellColors.brandGreen
                  : selected
                      ? IptvShellStyle.accent
                      : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: fg,
            fontSize: widget.compact ? 11 : 12,
            fontWeight: selected || _tvFocused
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

