part of 'iptv_pt_player_screen.dart';

class _SourceChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  const _SourceChip({
    required this.label,
    required this.onTap,
    this.focusNode,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip> {
  bool _focused = false;
  bool _hovered = false;

  bool get _tvFocused => iptvTvFocused(context, focused: _focused);

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final tv = iptvUseTvFocus(context);
    final borderColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : IptvShellStyle.accent.withValues(alpha: _active ? 0.8 : 0.5);
    final fg = _tvFocused ? ForjaShellColors.brandGreen : Colors.white;
    final iconColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : IptvShellStyle.accent;
    return iptvTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 20,
      scaleOnFocus: 1.0,
      focusNode: widget.focusNode,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: tv ? (f) => setState(() => _focused = f) : null,
      onHoverChange: tv ? (h) => setState(() => _hovered = h) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _tvFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: _tvFocused ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, color: iconColor, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IPTV top-bar flat icon with movie-player green D-pad chrome.
/// Uses FocusTraversal (no catalog-row meta) — same path as [PlayerFlatIconButton].
class _IptvPlayerTopBarIcon extends StatefulWidget {
  const _IptvPlayerTopBarIcon({
    required this.icon,
    required this.tooltip,
    this.focusNode,
    this.onPressed,
    this.onPressedWithContext,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final String tooltip;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_IptvPlayerTopBarIcon> createState() => _IptvPlayerTopBarIconState();
}

class _IptvPlayerTopBarIconState extends State<_IptvPlayerTopBarIcon> {
  bool _focused = false;
  bool _hovered = false;

  static const double _size = 44;
  static const double _iconSize = 22;

  bool get _tvFocused =>
      playerChromeTvFocused(tvFocusable: true, focused: _focused);

  bool get _highlight => playerChromeFocusActive(
        context,
        tvFocusable: true,
        hovered: _hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final shape = playerChromeButtonShape(
      isCircle: true,
      tvFocused: _tvFocused,
    );
    final iconColor = playerChromeIconColor(
      enabled: true,
      active: false,
      highlight: _highlight,
      tvFocused: _tvFocused,
    );
    final bg = playerChromeBackgroundColor(
      active: false,
      highlight: _highlight,
      tvFocused: _tvFocused,
    );

    return Builder(
      builder: (btnCtx) {
        final child = Material(
          color: bg,
          shape: shape,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(widget.icon, color: iconColor, size: _iconSize),
          ),
        );
        return Tooltip(
          message: widget.tooltip,
          child: iptvTap(
            context: context,
            onTap: () {
              if (widget.onPressedWithContext != null) {
                widget.onPressedWithContext!(btnCtx);
              } else {
                widget.onPressed!();
              }
            },
            borderRadius: _size / 2,
            scaleOnFocus: 1.0,
            focusNode: widget.focusNode,
            onDownEdge: widget.onDownEdge,
            onLeftEdge: widget.onLeftEdge,
            onRightEdge: widget.onRightEdge,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onHoverChange: (hovered) => setState(() => _hovered = hovered),
            child: child,
          ),
        );
      },
    );
  }
}
