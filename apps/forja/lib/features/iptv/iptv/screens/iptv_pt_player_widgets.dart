part of 'iptv_pt_player_screen.dart';

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
