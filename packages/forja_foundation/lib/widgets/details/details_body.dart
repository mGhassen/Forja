import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Constrained column below the full-bleed media details hero.
///
/// Horizontal inset is **not** applied here — catalog rows are edge-to-edge;
/// wrap text-only blocks in [padContent].
///
/// When [bodyOverlap] > 0, the body is translated up onto the hero backdrop
/// (no solid fill in that band — backdrop + soft gradient stay visible).
class DetailsBody extends StatelessWidget {
  const DetailsBody({
    super.key,
    required this.child,
    this.backgroundColor,
    this.bodyOverlap,
    this.topSpacing,
  });

  final Widget child;
  final Color? backgroundColor;
  final double? bodyOverlap;
  final double? topSpacing;

  /// Standard horizontal inset for synopsis blocks, episode headers, etc.
  static EdgeInsets contentPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = DetailsTokens.contentHorizontalPadding(width);
    return EdgeInsets.symmetric(horizontal: inset);
  }

  static Widget padContent(BuildContext context, Widget child) {
    return Padding(
      padding: contentPadding(context),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shellBg =
        backgroundColor ?? ForjaThemeExtension.of(context).bgDark;
    final overlap = bodyOverlap ?? DetailsTokens.heroBodyOverlap;
    final top = topSpacing ?? DetailsTokens.bodyTopSpacing;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ShellTokens.bodyMaxWidthDesktop,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            top,
            0,
            DetailsTokens.bodyBottomSpacing,
          ),
          child: child,
        ),
      ),
    );

    if (overlap > 0) {
      // Pull paint onto the backdrop. Stock Transform.translate fails hit tests
      // in the overflow band (y < 0) — seasons/cast never see hover. Use a
      // render object that hit-tests the painted bounds.
      return _OverlapPullUp(
        overlap: overlap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            ColoredBox(
              color: shellBg,
              child: SizedBox(height: overlap, width: double.infinity),
            ),
          ],
        ),
      );
    }

    return ColoredBox(color: shellBg, child: content);
  }
}

/// Host alias — same paint as [DetailsBody].
typedef MediaDetailsBody = DetailsBody;

/// Paints [child] shifted up by [overlap] and hit-tests that painted region.
class _OverlapPullUp extends SingleChildRenderObjectWidget {
  const _OverlapPullUp({
    required this.overlap,
    required Widget child,
  }) : super(child: child);

  final double overlap;

  @override
  _RenderOverlapPullUp createRenderObject(BuildContext context) {
    return _RenderOverlapPullUp(overlap: overlap);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOverlapPullUp renderObject,
  ) {
    renderObject.overlap = overlap;
  }
}

class _RenderOverlapPullUp extends RenderProxyBox {
  _RenderOverlapPullUp({required double overlap}) : _overlap = overlap;

  double _overlap;
  double get overlap => _overlap;
  set overlap(double value) {
    if (_overlap == value) return;
    _overlap = value;
    markNeedsPaint();
  }

  Matrix4 get _paintTransform =>
      Matrix4.translationValues(0, -_overlap, 0);

  @override
  bool get alwaysNeedsCompositing => _overlap != 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_overlap == 0) {
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _paintTransform,
      super.paint,
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.translateByDouble(0, -_overlap, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Painted y-range is [-overlap, size.height - overlap).
    if (position.dx < 0 ||
        position.dx >= size.width ||
        position.dy < -_overlap ||
        position.dy >= size.height - _overlap) {
      return false;
    }
    return result.addWithPaintTransform(
      transform: _paintTransform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child?.hitTest(result, position: transformed) ?? false;
      },
    );
  }
}
