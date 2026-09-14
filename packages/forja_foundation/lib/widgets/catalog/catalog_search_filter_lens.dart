import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/catalog_search_filters.dart';

bool _searchFilterActivateKey(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final key = event.logicalKey;
  return key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.numpadEnter;
}

/// Interactive wrap for filter lens controls (TV focus / host tap).
typedef CatalogSearchFilterInteractive = Widget Function({
  required Widget child,
  required VoidCallback onTap,
  FocusNode? focusNode,
  VoidCallback? onUpEdge,
  VoidCallback? onLeftEdge,
  int? listIndex,
  String? tvRowId,
});

/// Sliding All / Films / Series segment paint.
class CatalogSearchTypeSegment extends StatelessWidget {
  const CatalogSearchTypeSegment({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstFocusNode,
    this.onUpFromFirst,
    this.interactiveBuilder,
  });

  final SearchMediaFilter value;
  final ValueChanged<SearchMediaFilter> onChanged;
  final FocusNode? firstFocusNode;
  final VoidCallback? onUpFromFirst;
  final CatalogSearchFilterInteractive? interactiveBuilder;

  static const _items = [
    (SearchMediaFilter.all, 'All'),
    (SearchMediaFilter.movie, 'Films'),
    (SearchMediaFilter.tv, 'Series'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final slot = w / _items.length;
        final idx = _items.indexWhere((e) => e.$1 == value).clamp(0, 2);
        return SizedBox(
          height: 36,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ForjaShellColors.borderSubtle),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: idx * slot + 2,
                top: 2,
                bottom: 2,
                width: slot - 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: ForjaShellColors.textPrimary.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _wrapTap(
                        focusNode: i == 0 ? firstFocusNode : null,
                        onUpEdge: i == 0 ? onUpFromFirst : null,
                        onLeftEdge: i == 0 ? null : null,
                        listIndex: i,
                        onTap: () => onChanged(_items[i].$1),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                color: value == _items[i].$1
                                    ? ForjaShellColors.textPrimary
                                    : ForjaShellColors.textSecondary,
                                fontSize: 13,
                                fontWeight: value == _items[i].$1
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              child: Text(_items[i].$2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wrapTap({
    required Widget child,
    required VoidCallback onTap,
    FocusNode? focusNode,
    VoidCallback? onUpEdge,
    VoidCallback? onLeftEdge,
    int? listIndex,
  }) {
    final wrap = interactiveBuilder;
    if (wrap != null) {
      return wrap(
        child: child,
        onTap: onTap,
        focusNode: focusNode,
        onUpEdge: onUpEdge,
        onLeftEdge: onLeftEdge,
        listIndex: listIndex,
        tvRowId: null,
      );
    }
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// Score track: drag on desktop; on TV focus then OK to arm, Left/Right to scrub.
class CatalogSearchScoreArc extends StatefulWidget {
  const CatalogSearchScoreArc({
    super.key,
    required this.value,
    required this.onChanged,
    this.tvLeanback = false,
  });

  final double? value;
  final ValueChanged<double?> onChanged;
  final bool tvLeanback;

  @override
  State<CatalogSearchScoreArc> createState() => _CatalogSearchScoreArcState();
}

class _CatalogSearchScoreArcState extends State<CatalogSearchScoreArc> {
  static const _min = 5.0;
  static const _max = 9.5;

  final FocusNode _focus = FocusNode(debugLabel: 'search-filter-score');
  bool _armed = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _tFromValue(double? v) {
    if (v == null) return 0;
    return ((v - _min) / (_max - _min)).clamp(0.0, 1.0);
  }

  double? _valueFromT(double t) {
    if (t <= 0.02) return null;
    final v = _min + t * (_max - _min);
    return (v * 2).roundToDouble() / 2;
  }

  void _nudge(int dir) {
    final cur = widget.value ?? (_min - 0.5);
    final next = ((cur + dir * 0.5) * 2).roundToDouble() / 2;
    if (next < _min) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(next.clamp(_min, _max));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.tvLeanback) return KeyEventResult.ignored;

    if (!_armed) {
      if (_searchFilterActivateKey(event)) {
        setState(() => _armed = true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (_searchFilterActivateKey(event) ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      setState(() => _armed = false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _nudge(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _nudge(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvLeanback;
    final t = _tFromValue(widget.value);
    final label = widget.value == null
        ? 'Any score'
        : '≥ ${widget.value == widget.value!.roundToDouble() ? widget.value!.toInt() : widget.value!.toStringAsFixed(1)}';
    final warm = widget.value != null && widget.value! >= 8;
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Score',
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              tv && focused && !_armed
                  ? '$label · OK to adjust'
                  : (tv && _armed ? '$label · ← → · OK done' : label),
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          onFocusChange: (f) {
            if (!f && _armed) setState(() => _armed = false);
            setState(() {});
          },
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              void setFromDx(double dx) {
                final nt = (dx / w).clamp(0.0, 1.0);
                widget.onChanged(_valueFromT(nt));
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tv
                    ? () {
                        _focus.requestFocus();
                        setState(() => _armed = !_armed);
                      }
                    : null,
                onTapDown: tv ? null : (d) => setFromDx(d.localPosition.dx),
                onHorizontalDragUpdate:
                    tv ? null : (d) => setFromDx(d.localPosition.dx),
                onDoubleTap: () => widget.onChanged(null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _armed
                          ? ForjaShellColors.textPrimary.withValues(alpha: 0.55)
                          : focused
                              ? ForjaShellColors.textPrimary
                                  .withValues(alpha: 0.3)
                              : Colors.transparent,
                      width: _armed ? 1.5 : 1,
                    ),
                  ),
                  child: SizedBox(
                    height: 28,
                    child: CustomPaint(
                      size: Size(w, 28),
                      painter: CatalogScoreArcPainter(t: t, warm: warm),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CatalogScoreArcPainter extends CustomPainter {
  CatalogScoreArcPainter({required this.t, required this.warm});

  final double t;
  final bool warm;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = ForjaShellColors.borderSubtle
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = warm
          ? const Color(0xFFE8C07A).withValues(alpha: 0.85)
          : ForjaShellColors.textPrimary.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    final start = Offset(4, y);
    final end = Offset(size.width - 4, y);
    canvas.drawLine(start, end, track);
    if (t > 0) {
      final mid = Offset(4 + (size.width - 8) * t, y);
      canvas.drawLine(start, mid, fill);
      canvas.drawCircle(mid, 6, Paint()..color = ForjaShellColors.textPrimary);
      canvas.drawCircle(mid, 4, Paint()..color = const Color(0xFF141414));
    }
  }

  @override
  bool shouldRepaint(covariant CatalogScoreArcPainter old) =>
      old.t != t || old.warm != warm;
}

/// Year range timeline. Desktop: drag. TV: OK to arm, ↑/↓ thumb, ←/→ nudge.
class CatalogSearchYearTimeline extends StatefulWidget {
  const CatalogSearchYearTimeline({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.tvLeanback = false,
  });

  final int? start;
  final int? end;
  final void Function(int? start, int? end) onChanged;
  final bool tvLeanback;

  @override
  State<CatalogSearchYearTimeline> createState() =>
      _CatalogSearchYearTimelineState();
}

class _CatalogSearchYearTimelineState extends State<CatalogSearchYearTimeline> {
  static final int _lo = 1990;
  static final int _hi = DateTime.now().year;

  final FocusNode _focus = FocusNode(debugLabel: 'search-filter-year');
  late double _a;
  late double _b;
  bool _dragging = false;
  bool _dragStart = true;
  bool _armed = false;
  bool _editStart = true;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogSearchYearTimeline old) {
    super.didUpdateWidget(old);
    if (!_dragging) _syncFromWidget();
  }

  void _syncFromWidget() {
    if (widget.start == null || widget.end == null) {
      _a = 0;
      _b = 1;
    } else {
      _a = ((widget.start! - _lo) / (_hi - _lo)).clamp(0.0, 1.0);
      _b = ((widget.end! - _lo) / (_hi - _lo)).clamp(0.0, 1.0);
      if (_a > _b) {
        final tmp = _a;
        _a = _b;
        _b = tmp;
      }
    }
  }

  int _year(double t) => (_lo + t * (_hi - _lo)).round();

  double _stepT() => 1.0 / (_hi - _lo);

  void _emit() {
    if (_a <= 0.001 && _b >= 0.999) {
      widget.onChanged(null, null);
      return;
    }
    widget.onChanged(_year(_a), _year(_b));
  }

  void _nudge(int dir) {
    setState(() {
      final step = _stepT() * dir;
      if (_editStart) {
        _a = (_a + step).clamp(0.0, _b);
      } else {
        _b = (_b + step).clamp(_a, 1.0);
      }
    });
    _emit();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.tvLeanback) return KeyEventResult.ignored;

    if (!_armed) {
      if (_searchFilterActivateKey(event)) {
        setState(() {
          _armed = true;
          _editStart = true;
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (_searchFilterActivateKey(event) ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      setState(() => _armed = false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _editStart = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _editStart = false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _nudge(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _nudge(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvLeanback;
    final active = widget.start != null && widget.end != null;
    final label = !active
        ? 'Any year'
        : widget.start == widget.end
            ? '${widget.start}'
            : '${widget.start}–${widget.end}';
    final focused = _focus.hasFocus;
    final hint = tv && focused && !_armed
        ? '$label · OK to adjust'
        : (tv && _armed
            ? '$label · ${_editStart ? 'start' : 'end'} · ↑↓ thumb · ←→ · OK done'
            : label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Year',
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                hint,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          onFocusChange: (f) {
            if (!f && _armed) setState(() => _armed = false);
            setState(() {});
          },
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tv
                    ? () {
                        _focus.requestFocus();
                        setState(() => _armed = !_armed);
                      }
                    : null,
                onDoubleTap: () {
                  setState(() {
                    _a = 0;
                    _b = 1;
                  });
                  widget.onChanged(null, null);
                },
                onHorizontalDragStart: tv
                    ? null
                    : (d) {
                        _dragging = true;
                        final t = (d.localPosition.dx / w).clamp(0.0, 1.0);
                        _dragStart = (t - _a).abs() <= (t - _b).abs();
                        setState(() {
                          if (_dragStart) {
                            _a = t.clamp(0.0, _b);
                          } else {
                            _b = t.clamp(_a, 1.0);
                          }
                        });
                        _emit();
                      },
                onHorizontalDragUpdate: tv
                    ? null
                    : (d) {
                        final t = (d.localPosition.dx / w).clamp(0.0, 1.0);
                        setState(() {
                          if (_dragStart) {
                            _a = t.clamp(0.0, _b);
                          } else {
                            _b = t.clamp(_a, 1.0);
                          }
                        });
                        _emit();
                      },
                onHorizontalDragEnd: tv ? null : (_) => _dragging = false,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _armed
                          ? ForjaShellColors.textPrimary.withValues(alpha: 0.55)
                          : focused
                              ? ForjaShellColors.textPrimary
                                  .withValues(alpha: 0.3)
                              : Colors.transparent,
                      width: _armed ? 1.5 : 1,
                    ),
                  ),
                  child: SizedBox(
                    height: 32,
                    child: CustomPaint(
                      size: Size(w, 32),
                      painter: CatalogYearTimelinePainter(
                        a: _a,
                        b: _b,
                        active: active,
                        highlightStart: _armed && _editStart,
                        highlightEnd: _armed && !_editStart,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '$_lo',
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              '$_hi',
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CatalogYearTimelinePainter extends CustomPainter {
  CatalogYearTimelinePainter({
    required this.a,
    required this.b,
    required this.active,
    this.highlightStart = false,
    this.highlightEnd = false,
  });

  final double a;
  final double b;
  final bool active;
  final bool highlightStart;
  final bool highlightEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Paint()
      ..color = ForjaShellColors.borderSubtle
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), track);

    final x0 = 4 + (size.width - 8) * a;
    final x1 = 4 + (size.width - 8) * b;
    final fill = Paint()
      ..color = ForjaShellColors.textPrimary.withValues(
        alpha: active ? 0.75 : 0.25,
      )
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), fill);

    void drawThumb(double x, {required bool highlight}) {
      final r = highlight ? 8.0 : 6.0;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = ForjaShellColors.textPrimary,
      );
      canvas.drawCircle(
        Offset(x, y),
        highlight ? 5.0 : 4.0,
        Paint()..color = const Color(0xFF141414),
      );
    }

    drawThumb(x0, highlight: highlightStart);
    drawThumb(x1, highlight: highlightEnd);
  }

  @override
  bool shouldRepaint(covariant CatalogYearTimelinePainter old) =>
      old.a != a ||
      old.b != b ||
      old.active != active ||
      old.highlightStart != highlightStart ||
      old.highlightEnd != highlightEnd;
}

class CatalogSearchFilterChipSection extends StatelessWidget {
  const CatalogSearchFilterChipSection({
    super.key,
    required this.title,
    required this.options,
    required this.selectedToken,
    required this.onSelected,
    this.tvRowId,
    this.interactiveBuilder,
  });

  final String title;
  final List<(String label, String token)> options;
  final String? selectedToken;
  final ValueChanged<String> onSelected;
  final String? tvRowId;
  final CatalogSearchFilterInteractive? interactiveBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              CatalogSearchFilterGhostChip(
                label: options[i].$1,
                selected: selectedToken == options[i].$2,
                listIndex: i,
                tvRowId: tvRowId,
                onTap: () => onSelected(options[i].$2),
                interactiveBuilder: interactiveBuilder,
              ),
          ],
        ),
      ],
    );
  }
}

class CatalogSearchFilterGhostChip extends StatelessWidget {
  const CatalogSearchFilterGhostChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.listIndex,
    this.tvRowId,
    this.interactiveBuilder,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? listIndex;
  final String? tvRowId;
  final CatalogSearchFilterInteractive? interactiveBuilder;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? ForjaShellColors.textPrimary.withValues(alpha: 0.4)
        : ForjaShellColors.borderSubtle;
    final fg = selected
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;
    final paint = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
    final wrap = interactiveBuilder;
    if (wrap != null) {
      return wrap(
        child: paint,
        onTap: onTap,
        listIndex: listIndex,
        tvRowId: tvRowId,
      );
    }
    return GestureDetector(onTap: onTap, child: paint);
  }
}

/// Filter lens paint — host wraps taps via [interactiveBuilder].
class CatalogSearchFilterLens extends StatelessWidget {
  const CatalogSearchFilterLens({
    super.key,
    required this.open,
    required this.filters,
    required this.onFiltersChanged,
    required this.onSubmit,
    this.firstFocusNode,
    this.onUpFromFirst,
    this.tvLeanback = false,
    this.interactiveBuilder,
    this.onLeftFromFirstSegment,
  });

  final bool open;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onFiltersChanged;
  final VoidCallback onSubmit;
  final FocusNode? firstFocusNode;
  final VoidCallback? onUpFromFirst;
  final bool tvLeanback;
  final CatalogSearchFilterInteractive? interactiveBuilder;
  final VoidCallback? onLeftFromFirstSegment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: open
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - t)),
                    child: child,
                  ),
                ),
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: CatalogSearchTypeSegment(
                          value: filters.media,
                          firstFocusNode: firstFocusNode,
                          onUpFromFirst: onUpFromFirst,
                          interactiveBuilder: ({
                            required child,
                            required onTap,
                            focusNode,
                            onUpEdge,
                            onLeftEdge,
                            listIndex,
                            tvRowId,
                          }) {
                            final wrap = interactiveBuilder;
                            if (wrap == null) {
                              return GestureDetector(
                                onTap: onTap,
                                child: child,
                              );
                            }
                            return wrap(
                              child: child,
                              onTap: onTap,
                              focusNode: focusNode,
                              onUpEdge: onUpEdge,
                              onLeftEdge: listIndex == 0
                                  ? onLeftFromFirstSegment
                                  : onLeftEdge,
                              listIndex: listIndex,
                              tvRowId: tvRowId,
                            );
                          },
                          onChanged: (m) =>
                              onFiltersChanged(filters.copyWith(media: m)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: CatalogSearchScoreArc(
                          value: filters.minScore,
                          tvLeanback: tvLeanback,
                          onChanged: (v) => onFiltersChanged(
                            filters.copyWith(
                              minScore: v,
                              clearMinScore: v == null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: CatalogSearchYearTimeline(
                          start: filters.yearStart,
                          end: filters.yearEnd,
                          tvLeanback: tvLeanback,
                          onChanged: (a, b) => onFiltersChanged(
                            filters.copyWith(
                              yearStart: a,
                              yearEnd: b,
                              clearYears: a == null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(4),
                        child: CatalogSearchFilterChipSection(
                          title: 'Genre',
                          tvRowId: 'search_filter_genre',
                          options: kSearchFilterGenres,
                          selectedToken: filters.genreToken,
                          interactiveBuilder: interactiveBuilder,
                          onSelected: (token) => onFiltersChanged(
                            token == filters.genreToken
                                ? filters.copyWith(clearGenre: true)
                                : filters.copyWith(genreToken: token),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(5),
                        child: CatalogSearchFilterChipSection(
                          title: 'Country',
                          tvRowId: 'search_filter_country',
                          options: kSearchFilterCountries,
                          selectedToken: filters.countryToken,
                          interactiveBuilder: interactiveBuilder,
                          onSelected: (token) => onFiltersChanged(
                            token == filters.countryToken
                                ? filters.copyWith(clearCountry: true)
                                : filters.copyWith(countryToken: token),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(6),
                        child: CatalogSearchFilterChipSection(
                          title: 'Language',
                          tvRowId: 'search_filter_language',
                          options: kSearchFilterLanguages,
                          selectedToken: filters.languageToken,
                          interactiveBuilder: interactiveBuilder,
                          onSelected: (token) => onFiltersChanged(
                            token == filters.languageToken
                                ? filters.copyWith(clearLanguage: true)
                                : filters.copyWith(languageToken: token),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(7),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _submitButton(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _submitButton(BuildContext context) {
    final paint = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ForjaShellColors.textPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: const Text(
        'Search',
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final wrap = interactiveBuilder;
    if (wrap != null) {
      return wrap(child: paint, onTap: onSubmit);
    }
    return GestureDetector(onTap: onSubmit, child: paint);
  }
}
