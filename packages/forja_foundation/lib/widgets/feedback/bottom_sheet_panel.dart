import 'package:flutter/material.dart';

import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/mobile_chrome_tokens.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';

/// Marks a subtree painted inside a [ForjaBottomSheetPanel].
///
/// Nested overlays (Sources → Filters) read this at open time so they follow
/// the sheet shape instead of docking beside a side panel that is not there.
class ForjaBottomSheetScope extends InheritedWidget {
  const ForjaBottomSheetScope({super.key, required super.child});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ForjaBottomSheetScope>() != null;

  @override
  bool updateShouldNotify(ForjaBottomSheetScope oldWidget) => false;
}

/// Grab handle drawn at the top of a bottom sheet.
class ForjaSheetHandle extends StatelessWidget {
  const ForjaSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MobileChromeTokens.sheetHandleWidth,
      height: MobileChromeTokens.sheetHandleHeight,
      decoration: BoxDecoration(
        color: ForjaShellColors.cinematic.textSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(
          MobileChromeTokens.sheetHandleHeight,
        ),
      ),
    );
  }
}

/// Phone bottom sheet frame for overlay panels (Sources, Filters).
///
/// Paint only: scrim + frosted sheet anchored to the bottom, a drag handle
/// (drag down to half-open or close, up to expand), optional [title] and a
/// close button. Sits above the keyboard and pads the system gesture bar.
///
/// [onClose] fires after the slide-out finishes.
class ForjaBottomSheetPanel extends StatefulWidget {
  const ForjaBottomSheetPanel({
    super.key,
    required this.child,
    required this.onClose,
    this.title,
    this.showClose = true,
    this.enableBlur = true,
    this.closeTooltip = 'Close',
    this.contentPadding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback onClose;
  final String? title;
  final bool showClose;

  /// Details pages: true (frosted over the page). Never over live video.
  final bool enableBlur;
  final String closeTooltip;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<ForjaBottomSheetPanel> createState() => ForjaBottomSheetPanelState();
}

class ForjaBottomSheetPanelState extends State<ForjaBottomSheetPanel> {
  bool _shown = false;
  bool _closing = false;
  bool _dragging = false;
  bool _expanded = true;

  /// Positive = finger moved down from the resting height.
  double _dragPx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  /// Slide out, then call [ForjaBottomSheetPanel.onClose].
  void close() {
    if (_closing) return;
    setState(() {
      _closing = true;
      _dragging = false;
    });
    Future<void>.delayed(MobileChromeTokens.sheetSnapDuration, () {
      if (mounted) widget.onClose();
    });
  }

  /// Height the sheet may use: its own box (a shell body ends above the tab
  /// bar), minus the keyboard and the window's status-bar inset (shell
  /// bodies may strip that padding from their MediaQuery).
  double _available(BuildContext context, double boxHeight) {
    final mq = MediaQuery.of(context);
    final windowTop = MediaQueryData.fromView(View.of(context)).viewPadding.top;
    final top = mq.viewPadding.top > windowTop ? mq.viewPadding.top : windowTop;
    final h = boxHeight - mq.viewInsets.bottom - top;
    return h < 0 ? 0 : h;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_closing) return;
    setState(() {
      _dragging = true;
      _dragPx += d.delta.dy;
    });
  }

  void _onDragEnd(DragEndDetails d, double available) {
    if (_closing) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final half = available * MobileChromeTokens.sheetHalfFraction;
    final full = available * MobileChromeTokens.sheetExpandedFraction;
    final current = (_expanded ? full : half) - _dragPx;

    var expand = _expanded;
    var dismiss = false;
    if (velocity > MobileChromeTokens.sheetFlingVelocity) {
      if (_expanded &&
          current > half * MobileChromeTokens.sheetDismissFraction) {
        expand = false;
      } else {
        dismiss = true;
      }
    } else if (velocity < -MobileChromeTokens.sheetFlingVelocity) {
      expand = true;
    } else if (current < half * MobileChromeTokens.sheetDismissFraction) {
      dismiss = true;
    } else {
      expand = (current - half).abs() > (current - full).abs();
    }

    setState(() {
      _dragging = false;
      _dragPx = 0;
      _expanded = expand;
    });
    if (dismiss) close();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildSheet(
        context,
        _available(
          context,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, double available) {
    final mq = MediaQuery.of(context);
    final cinematic = ForjaShellColors.cinematic;
    final full = available * MobileChromeTokens.sheetExpandedFraction;
    final half = available * MobileChromeTokens.sheetHalfFraction;
    final rest = _expanded ? full : half;

    // Dragging up grows the sheet (to full); dragging down slides it, so the
    // body never lays out at a tiny height.
    final height = _dragPx < 0 ? (rest - _dragPx).clamp(0.0, full) : rest;
    final visible = _shown && !_closing;
    final offset = visible ? (_dragPx > 0 ? _dragPx : 0.0) : height;
    final duration = _dragging
        ? Duration.zero
        : MobileChromeTokens.sheetSnapDuration;
    const radius = BorderRadius.vertical(
      top: Radius.circular(MobileChromeTokens.sheetTopRadius),
    );

    final title = widget.title?.trim() ?? '';
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: (d) => _onDragEnd(d, available),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MobileChromeTokens.sheetHeaderPadH,
          MobileChromeTokens.sheetHandleTopGap,
          MobileChromeTokens.sheetHeaderPadH / 2,
          MobileChromeTokens.sheetHeaderPadBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ForjaSheetHandle(),
            const SizedBox(height: MobileChromeTokens.sheetHandleBottomGap),
            if (title.isNotEmpty || widget.showClose)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cinematic.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: MobileChromeTokens.sheetTitleFontSize,
                      ),
                    ),
                  ),
                  if (widget.showClose)
                    Button(
                      variant: ButtonVariant.plainIcon,
                      size: ButtonSize.icon,
                      icon: Icons.close_rounded,
                      tooltip: widget.closeTooltip,
                      color: cinematic.textSecondary,
                      onPressed: close,
                    ),
                ],
              ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: close,
            behavior: HitTestBehavior.opaque,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: MobileChromeTokens.sheetSnapDuration,
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: MobileChromeTokens.sheetScrimAlpha,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: mq.viewInsets.bottom,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: height,
            transform: Matrix4.translationValues(0, offset, 0),
            child: ForjaFrostedPanel(
              enableBlur: widget.enableBlur,
              borderRadius: radius,
              border: Border(top: BorderSide(color: cinematic.borderSubtle)),
              child: SafeArea(
                top: false,
                child: ForjaBottomSheetScope(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Expanded(
                        child: Padding(
                          padding: widget.contentPadding,
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
