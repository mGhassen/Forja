import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Horizontal scrollable strip with overlaid left/right arrow buttons.
/// Arrows appear on desktop/wide screens and on hover; they paginate the
/// list by roughly one viewport width per click. Touch-only / narrow
/// layouts get plain swipe scrolling with no overlay.
///
/// On desktop, vertical mouse wheel / trackpad scroll over the row moves
/// the strip horizontally instead of scrolling the parent page.
class HorizontalScroller extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry padding;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final double arrowOffset;
  final ScrollController? controller;
  final Clip clipBehavior;
  final ScrollPhysics? physics;

  const HorizontalScroller({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding = EdgeInsets.zero,
    this.arrowOffset = 8,
    this.controller,
    this.clipBehavior = Clip.none,
    this.physics,
  });

  @override
  State<HorizontalScroller> createState() => _HorizontalScrollerState();
}

class _HorizontalScrollerState extends State<HorizontalScroller> {
  ScrollController? _ownedController;
  late ScrollController _ctrl;
  bool _hovering = false;
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? (_ownedController = ScrollController());
    _ctrl.addListener(_updateEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void didUpdateWidget(covariant HorizontalScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _ctrl.removeListener(_updateEdges);
    _ownedController?.dispose();
    _ownedController = null;
    _ctrl = widget.controller ?? (_ownedController = ScrollController());
    _ctrl.addListener(_updateEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateEdges);
    _ownedController?.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!_ctrl.hasClients) return;
    final left = _ctrl.offset > 4;
    final right = _ctrl.offset < _ctrl.position.maxScrollExtent - 4;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + delta)
        .clamp(0.0, _ctrl.position.maxScrollExtent);
    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!ShellScope.inputPolicyOf(context).scaleOnHover) return;
    if (event is! PointerScrollEvent) return;

    final dy = event.scrollDelta.dy;
    if (dy == 0.0) return;
    if (!_ctrl.hasClients) return;

    final pos = _ctrl.position;
    if (pos.maxScrollExtent <= 0) return;

    // pixels += dy: positive dy → right, negative dy → left.
    // At an edge in that direction, do not claim — let the parent page scroll.
    final atMin = pos.pixels <= pos.minScrollExtent + 0.5;
    final atMax = pos.pixels >= pos.maxScrollExtent - 0.5;
    final canScrollRow = (dy > 0 && !atMax) || (dy < 0 && !atMin);
    if (!canScrollRow) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent) return;
      final delta = resolved.scrollDelta.dy;
      if (delta == 0.0) return;
      if (!_ctrl.hasClients) return;

      final position = _ctrl.position;
      final atStart = position.pixels <= position.minScrollExtent + 0.5;
      final atEnd = position.pixels >= position.maxScrollExtent - 0.5;
      if ((atStart && delta < 0) || (atEnd && delta > 0)) return;

      final target = (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target != position.pixels) {
        _ctrl.jumpTo(target);
        _updateEdges();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showArrows = ShellScope.inputPolicyOf(context).scaleOnHover;
    final physics = widget.physics ?? const BouncingScrollPhysics();
    final tvFocus = ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ??
        false;
    final scrollCacheExtent =
        tvFocus ? ScrollCacheExtent.pixels(2000) : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: SizedBox(
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  _updateEdges();
                  return shellAbsorbHorizontalScroll(notification);
                },
                child: widget.separatorBuilder != null
                    ? ListView.separated(
                        controller: _ctrl,
                        clipBehavior: widget.clipBehavior,
                        scrollDirection: Axis.horizontal,
                        physics: physics,
                        padding: widget.padding,
                        itemCount: widget.itemCount,
                        scrollCacheExtent: scrollCacheExtent,
                        separatorBuilder: widget.separatorBuilder!,
                        itemBuilder: widget.itemBuilder,
                      )
                    : ListView.builder(
                        controller: _ctrl,
                        clipBehavior: widget.clipBehavior,
                        scrollDirection: Axis.horizontal,
                        physics: physics,
                        padding: widget.padding,
                        itemCount: widget.itemCount,
                        scrollCacheExtent: scrollCacheExtent,
                        itemBuilder: widget.itemBuilder,
                      ),
              ),
              if (showArrows) ...[
                _ArrowButton(
                  visible: _hovering && _canLeft,
                  left: true,
                  offset: widget.arrowOffset,
                  onTap: () => _scrollBy(-_pageStep(context)),
                ),
                _ArrowButton(
                  visible: _hovering && _canRight,
                  left: false,
                  offset: widget.arrowOffset,
                  onTap: () => _scrollBy(_pageStep(context)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _pageStep(BuildContext context) {
    // Roughly one viewport's worth, biased a bit smaller so users see overlap.
    final w = MediaQuery.of(context).size.width;
    return (w * 0.7).clamp(280, 1100);
  }
}

class _ArrowButton extends StatelessWidget {
  final bool visible;
  final bool left;
  final double offset;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.visible,
    required this.left,
    required this.offset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? offset : null,
      right: left ? null : offset,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: Center(
            child: ForjaInteractive(
              onTap: onTap,
              hoverScale: 1.06,
              pressScale: 0.95,
              builder: (hover, pressed) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ForjaShellColors.surfaceElevated
                        .withValues(alpha: hover ? 0.98 : 0.92),
                    border: Border.all(
                      color: hover
                          ? ForjaShellColors.textPrimary
                              .withValues(alpha: 0.22)
                          : ForjaShellColors.borderSubtle,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    left
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: hover
                        ? ForjaShellColors.textPrimary
                        : ForjaShellColors.iconActive,
                    size: 24,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
