part of 'search_screen.dart';

enum SearchMediaFilter { all, movie, tv }

/// Genre chips → parser aliases (single-select).
const kSearchFilterGenres = <(String label, String token)>[
  ('Action', 'action'),
  ('Adventure', 'adventure'),
  ('Animation', 'animation'),
  ('Comedy', 'comedy'),
  ('Crime', 'crime'),
  ('Documentary', 'documentary'),
  ('Drama', 'drama'),
  ('Family', 'family'),
  ('Fantasy', 'fantasy'),
  ('History', 'history'),
  ('Horror', 'horror'),
  ('Music', 'music'),
  ('Mystery', 'mystery'),
  ('Romance', 'romance'),
  ('Sci-Fi', 'sci-fi'),
  ('Thriller', 'thriller'),
  ('War', 'war'),
  ('Western', 'western'),
  ('Kids', 'kids'),
];

/// Country chips → parser aliases / ISO (single-select).
const kSearchFilterCountries = <(String label, String token)>[
  ('USA', 'usa'),
  ('UK', 'uk'),
  ('France', 'france'),
  ('Germany', 'germany'),
  ('Japan', 'japan'),
  ('Korea', 'korea'),
  ('India', 'india'),
  ('Italy', 'italy'),
  ('Spain', 'spain'),
  ('Canada', 'canada'),
  ('Australia', 'australia'),
  ('China', 'china'),
  ('Brazil', 'brazil'),
  ('Mexico', 'mexico'),
  ('Sweden', 'sweden'),
  ('Norway', 'norway'),
  ('Denmark', 'denmark'),
  ('Turkey', 'turkey'),
  ('Hong Kong', 'hong kong'),
  ('Taiwan', 'taiwan'),
  ('Thailand', 'thailand'),
];

/// UI-driven Search filters — composed into the structured query string.
class SearchFilters {
  const SearchFilters({
    this.media = SearchMediaFilter.all,
    this.minScore,
    this.yearStart,
    this.yearEnd,
    this.genreToken,
    this.countryToken,
  });

  final SearchMediaFilter media;
  final double? minScore;
  final int? yearStart;
  final int? yearEnd;
  /// Parser genre alias, e.g. `horror`.
  final String? genreToken;
  /// Parser country alias, e.g. `japan`.
  final String? countryToken;

  static const empty = SearchFilters();

  bool get isActive =>
      media != SearchMediaFilter.all ||
      minScore != null ||
      (yearStart != null && yearEnd != null) ||
      genreToken != null ||
      countryToken != null;

  SearchFilters copyWith({
    SearchMediaFilter? media,
    double? minScore,
    int? yearStart,
    int? yearEnd,
    String? genreToken,
    String? countryToken,
    bool clearMinScore = false,
    bool clearYears = false,
    bool clearGenre = false,
    bool clearCountry = false,
  }) {
    return SearchFilters(
      media: media ?? this.media,
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      yearStart: clearYears ? null : (yearStart ?? this.yearStart),
      yearEnd: clearYears ? null : (yearEnd ?? this.yearEnd),
      genreToken: clearGenre ? null : (genreToken ?? this.genreToken),
      countryToken: clearCountry ? null : (countryToken ?? this.countryToken),
    );
  }

  /// Tokens appended to the typed query for [parseSearchQuery].
  String toQuerySuffix() {
    final parts = <String>[];
    switch (media) {
      case SearchMediaFilter.movie:
        parts.add('films');
      case SearchMediaFilter.tv:
        parts.add('series');
      case SearchMediaFilter.all:
        break;
    }
    if (genreToken != null) parts.add(genreToken!);
    if (countryToken != null) parts.add(countryToken!);
    if (minScore != null) {
      final v = minScore!;
      final label =
          v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
      parts.add('>=$label');
    }
    if (yearStart != null && yearEnd != null) {
      if (yearStart == yearEnd) {
        parts.add('$yearStart');
      } else {
        parts.add('$yearStart-$yearEnd');
      }
    }
    return parts.join(' ');
  }

  List<(String label, VoidCallback clear)> tokenActions(
    void Function(SearchFilters) apply,
  ) {
    final out = <(String, VoidCallback)>[];
    if (media == SearchMediaFilter.movie) {
      out.add((
        'Films',
        () => apply(copyWith(media: SearchMediaFilter.all)),
      ));
    } else if (media == SearchMediaFilter.tv) {
      out.add((
        'Series',
        () => apply(copyWith(media: SearchMediaFilter.all)),
      ));
    }
    if (genreToken != null) {
      final label = kSearchFilterGenres
          .where((e) => e.$2 == genreToken)
          .map((e) => e.$1)
          .firstOrNull;
      out.add((
        label ?? genreToken!,
        () => apply(copyWith(clearGenre: true)),
      ));
    }
    if (countryToken != null) {
      final label = kSearchFilterCountries
          .where((e) => e.$2 == countryToken)
          .map((e) => e.$1)
          .firstOrNull;
      out.add((
        label ?? countryToken!,
        () => apply(copyWith(clearCountry: true)),
      ));
    }
    if (minScore != null) {
      final v = minScore!;
      final label =
          v == v.roundToDouble() ? '≥${v.toInt()}' : '≥${v.toStringAsFixed(1)}';
      out.add((label, () => apply(copyWith(clearMinScore: true))));
    }
    if (yearStart != null && yearEnd != null) {
      final label =
          yearStart == yearEnd ? '$yearStart' : '$yearStart–$yearEnd';
      out.add((label, () => apply(copyWith(clearYears: true))));
    }
    return out;
  }
}

String composeSearchQuery(String typed, SearchFilters filters) {
  final q = typed.trim();
  final suffix = filters.toQuerySuffix();
  if (suffix.isEmpty) return q;
  if (q.isEmpty) return suffix;
  return '$q $suffix';
}

class _SearchFilterToken extends StatelessWidget {
  const _SearchFilterToken({
    required this.label,
    required this.onClear,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ForjaShellColors.textPrimary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: ForjaShellColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.close,
                size: 14,
                color: ForjaShellColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sliding All / Films / Series segment.
class _SearchTypeSegment extends StatelessWidget {
  const _SearchTypeSegment({
    required this.value,
    required this.onChanged,
  });

  final SearchMediaFilter value;
  final ValueChanged<SearchMediaFilter> onChanged;

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
                  for (final item in _items)
                    Expanded(
                      child: InkWell(
                        onTap: () => onChanged(item.$1),
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              color: value == item.$1
                                  ? ForjaShellColors.textPrimary
                                  : ForjaShellColors.textSecondary,
                              fontSize: 13,
                              fontWeight: value == item.$1
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(item.$2),
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
}

/// Score track: drag for minimum TMDB vote (≥). Double-tap clears.
class _SearchScoreArc extends StatelessWidget {
  const _SearchScoreArc({
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final ValueChanged<double?> onChanged;

  static const _min = 5.0;
  static const _max = 9.5;

  double _tFromValue(double? v) {
    if (v == null) return 0;
    return ((v - _min) / (_max - _min)).clamp(0.0, 1.0);
  }

  double? _valueFromT(double t) {
    if (t <= 0.02) return null;
    final v = _min + t * (_max - _min);
    return (v * 2).roundToDouble() / 2;
  }

  @override
  Widget build(BuildContext context) {
    final t = _tFromValue(value);
    final label = value == null
        ? 'Any score'
        : '≥ ${value == value!.roundToDouble() ? value!.toInt() : value!.toStringAsFixed(1)}';
    final warm = value != null && value! >= 8;

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
              label,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            void setFromDx(double dx) {
              final nt = (dx / w).clamp(0.0, 1.0);
              onChanged(_valueFromT(nt));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setFromDx(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => setFromDx(d.localPosition.dx),
              onDoubleTap: () => onChanged(null),
              child: SizedBox(
                height: 28,
                child: CustomPaint(
                  size: Size(w, 28),
                  painter: _ScoreArcPainter(t: t, warm: warm),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  _ScoreArcPainter({required this.t, required this.warm});

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
  bool shouldRepaint(covariant _ScoreArcPainter old) =>
      old.t != t || old.warm != warm;
}

/// Year range timeline scrub. Double-tap clears.
class _SearchYearTimeline extends StatefulWidget {
  const _SearchYearTimeline({
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final int? start;
  final int? end;
  final void Function(int? start, int? end) onChanged;

  @override
  State<_SearchYearTimeline> createState() => _SearchYearTimelineState();
}

class _SearchYearTimelineState extends State<_SearchYearTimeline> {
  static final int _lo = 1990;
  static final int _hi = DateTime.now().year;

  late double _a;
  late double _b;
  bool _dragging = false;
  bool _dragStart = true;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _SearchYearTimeline old) {
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

  void _emit() {
    if (_a <= 0.001 && _b >= 0.999) {
      widget.onChanged(null, null);
      return;
    }
    widget.onChanged(_year(_a), _year(_b));
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.start != null && widget.end != null;
    final label = !active
        ? 'Any year'
        : widget.start == widget.end
            ? '${widget.start}'
            : '${widget.start}–${widget.end}';

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
            Text(
              label,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                setState(() {
                  _a = 0;
                  _b = 1;
                });
                widget.onChanged(null, null);
              },
              onHorizontalDragStart: (d) {
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
              onHorizontalDragUpdate: (d) {
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
              onHorizontalDragEnd: (_) => _dragging = false,
              child: SizedBox(
                height: 32,
                child: CustomPaint(
                  size: Size(w, 32),
                  painter: _YearTimelinePainter(a: _a, b: _b, active: active),
                ),
              ),
            );
          },
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

class _YearTimelinePainter extends CustomPainter {
  _YearTimelinePainter({
    required this.a,
    required this.b,
    required this.active,
  });

  final double a;
  final double b;
  final bool active;

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

    for (final x in [x0, x1]) {
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()..color = ForjaShellColors.textPrimary,
      );
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = const Color(0xFF141414));
    }
  }

  @override
  bool shouldRepaint(covariant _YearTimelinePainter old) =>
      old.a != a || old.b != b || old.active != active;
}

/// Expandable filter lens under the search field.
class _SearchFilterLens extends StatelessWidget {
  const _SearchFilterLens({
    required this.open,
    required this.filters,
    required this.onFiltersChanged,
    required this.onSubmit,
  });

  final bool open;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onFiltersChanged;
  final VoidCallback onSubmit;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchTypeSegment(
                      value: filters.media,
                      onChanged: (m) =>
                          onFiltersChanged(filters.copyWith(media: m)),
                    ),
                    const SizedBox(height: 14),
                    _SearchScoreArc(
                      value: filters.minScore,
                      onChanged: (v) => onFiltersChanged(
                        filters.copyWith(
                          minScore: v,
                          clearMinScore: v == null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SearchYearTimeline(
                      start: filters.yearStart,
                      end: filters.yearEnd,
                      onChanged: (a, b) => onFiltersChanged(
                        filters.copyWith(
                          yearStart: a,
                          yearEnd: b,
                          clearYears: a == null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SearchFilterChipSection(
                      title: 'Genre',
                      options: kSearchFilterGenres,
                      selectedToken: filters.genreToken,
                      onSelected: (token) => onFiltersChanged(
                        token == filters.genreToken
                            ? filters.copyWith(clearGenre: true)
                            : filters.copyWith(genreToken: token),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SearchFilterChipSection(
                      title: 'Country',
                      options: kSearchFilterCountries,
                      selectedToken: filters.countryToken,
                      onSelected: (token) => onFiltersChanged(
                        token == filters.countryToken
                            ? filters.copyWith(clearCountry: true)
                            : filters.copyWith(countryToken: token),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onSubmit,
                        style: TextButton.styleFrom(
                          foregroundColor: ForjaShellColors.textPrimary,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: ForjaShellColors.textPrimary
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _SearchFilterChipSection extends StatelessWidget {
  const _SearchFilterChipSection({
    required this.title,
    required this.options,
    required this.selectedToken,
    required this.onSelected,
  });

  final String title;
  final List<(String label, String token)> options;
  final String? selectedToken;
  final ValueChanged<String> onSelected;

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
            for (final option in options)
              _SearchFilterGhostChip(
                label: option.$1,
                selected: selectedToken == option.$2,
                onTap: () => onSelected(option.$2),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchFilterGhostChip extends StatelessWidget {
  const _SearchFilterGhostChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? ForjaShellColors.textPrimary.withValues(alpha: 0.4)
        : ForjaShellColors.borderSubtle;
    final fg = selected
        ? ForjaShellColors.textPrimary
        : ForjaShellColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: ForjaShellColors.inkHover,
        child: AnimatedContainer(
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
        ),
      ),
    );
  }
}
