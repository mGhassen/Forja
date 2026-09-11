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

  TextScaler get _textScaler => MediaQuery.textScalerOf(context);

  TextDirection get _textDirection => Directionality.of(context);

  double _readMoreRowHeight(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.readMoreLabel, style: _readMoreStyle),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  bool _needsTruncation(String text, double maxWidth, int maxLines) {
    if (!maxWidth.isFinite || maxWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      maxLines: maxLines,
      textDirection: _textDirection,
      textScaler: _textScaler,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  double _contentHeight(
    double maxWidth,
    int maxLines, {
    required bool includeReadMore,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.overview, style: widget.style),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    var height = textPainter.height;
    if (includeReadMore) {
      height += _readMoreGap + _readMoreRowHeight(maxWidth);
    }
    return height;
  }

  int _maxLinesForHeight(
    double maxWidth,
    double maxHeight, {
    required bool reserveReadMore,
  }) {
    // Measure real glyphs + bold Read More (slot math often uses regular weight).
    var lines = widget.maxLines;
    while (lines > 1 &&
        _contentHeight(
              maxWidth,
              lines,
              includeReadMore: reserveReadMore,
            ) >
            maxHeight) {
      lines--;
    }
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
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
        final heightBound =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final maxHeight = heightBound ? constraints.maxHeight : null;

        final preliminaryTruncation = _needsTruncation(
          widget.overview,
          maxWidth,
          widget.maxLines,
        );
        // Fit whenever height is capped — including shrinkWrap slots (hub
        // details). ClipRect alone does not silence RenderFlex overflow.
        final effectiveMaxLines = maxHeight != null
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
          effectiveMaxLines: effectiveMaxLines,
          needsTruncation: needsTruncation,
        );

        // Unbounded parent — size to text.
        if (maxHeight == null) return content;

        // shrinkWrap: ceiling only — do not fill the overview slot (Play sits
        // under synopsis). Fixed slots (!shrinkWrap) keep a tight height.
        if (widget.shrinkWrap) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ClipRect(
              child: _expanded
                  ? SingleChildScrollView(child: content)
                  : content,
            ),
          );
        }

        return SizedBox(
          width: maxWidth.isFinite ? maxWidth : null,
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
