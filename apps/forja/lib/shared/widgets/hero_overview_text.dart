import 'package:flutter/material.dart';

/// Truncated hero synopsis with ellipsis and a separate [readMoreLabel] row below.
class HeroOverviewText extends StatefulWidget {
  const HeroOverviewText({
    super.key,
    required this.overview,
    required this.style,
    this.maxLines = 3,
    this.onReadMore,
    this.readMoreLabel = 'Read More',
    this.readLessLabel = 'Read Less',
    this.shrinkWrap = true,
  });

  final String overview;
  final TextStyle style;
  final int maxLines;
  /// When set, tapping read more calls this (e.g. open details). Otherwise expands inline.
  final VoidCallback? onReadMore;
  final String readMoreLabel;
  final String readLessLabel;
  /// When false, expands to fill a bounded parent height (fixed overview slots).
  final bool shrinkWrap;

  @override
  State<HeroOverviewText> createState() => _HeroOverviewTextState();
}

class _HeroOverviewTextState extends State<HeroOverviewText> {
  static const _readMoreGap = 8.0;
  bool _expanded = false;

  TextStyle get _readMoreStyle => widget.style.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.55),
      );

  double _lineHeight(TextPainter painter) {
    if (painter.computeLineMetrics().isEmpty) {
      return (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.0);
    }
    return painter.computeLineMetrics().first.height;
  }

  double _readMoreRowHeight(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.readMoreLabel, style: _readMoreStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  bool _needsTruncation(String text, double maxWidth, int maxLines) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  int _maxLinesForHeight(double maxWidth, double maxHeight, {required bool reserveReadMore}) {
    final readMoreReserve = reserveReadMore
        ? _readMoreGap + _readMoreRowHeight(maxWidth)
        : 0.0;
    final textBudget = maxHeight - readMoreReserve;
    if (textBudget <= 0) return 1;

    final singleLinePainter = TextPainter(
      text: TextSpan(text: 'A', style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    final lineHeight = _lineHeight(singleLinePainter);
    if (lineHeight <= 0) return widget.maxLines;

    final lines = (textBudget / lineHeight).floor().clamp(1, widget.maxLines);
    return lines;
  }

  void _handleReadMore() {
    if (widget.onReadMore != null) {
      widget.onReadMore!();
      return;
    }
    setState(() => _expanded = true);
  }

  Widget _buildContent({
    required double maxWidth,
    required double? maxHeight,
    required int effectiveMaxLines,
    required bool needsTruncation,
  }) {
    if (!needsTruncation || _expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.overview,
            style: widget.style,
            maxLines: _expanded ? null : effectiveMaxLines,
            overflow: _expanded ? null : TextOverflow.clip,
          ),
          if (_expanded && widget.onReadMore == null) ...[
            const SizedBox(height: _readMoreGap),
            GestureDetector(
              onTap: () => setState(() => _expanded = false),
              child: Text(widget.readLessLabel, style: _readMoreStyle),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.overview,
          style: widget.style,
          maxLines: effectiveMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: _readMoreGap),
        GestureDetector(
          onTap: _handleReadMore,
          child: Text(widget.readMoreLabel, style: _readMoreStyle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.overview.isEmpty) {
      return Text(' ', style: widget.style.copyWith(color: Colors.transparent));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final bounded = !widget.shrinkWrap &&
            constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite;
        final maxHeight = bounded ? constraints.maxHeight : null;

        final preliminaryTruncation = _needsTruncation(
          widget.overview,
          maxWidth,
          widget.maxLines,
        );
        final effectiveMaxLines = bounded && maxHeight != null
            ? _maxLinesForHeight(
                maxWidth,
                maxHeight,
                reserveReadMore: preliminaryTruncation && !_expanded,
              )
            : widget.maxLines;
        final needsTruncation = _needsTruncation(
          widget.overview,
          maxWidth,
          effectiveMaxLines,
        );

        final content = _buildContent(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          effectiveMaxLines: effectiveMaxLines,
          needsTruncation: needsTruncation,
        );

        if (!bounded) return content;

        return SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: ClipRect(
            child: _expanded
                ? SingleChildScrollView(child: content)
                : Align(
                    alignment: Alignment.topLeft,
                    child: content,
                  ),
          ),
        );
      },
    );
  }
}
