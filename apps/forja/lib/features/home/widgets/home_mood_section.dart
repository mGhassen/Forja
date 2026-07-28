// Home tab section widgets - extracted from home_screen.dart (RFC-019 Phase B).

import 'dart:math' as math;

import 'package:forja/features/home/widgets/home_widget_imports.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
class HomeMoodCircleLayout {
  const HomeMoodCircleLayout({
    required this.circleSize,
    required this.itemWidth,
    required this.horizontalGap,
    required this.rowHeight,
    required this.labelFontSize,
    required this.iconSize,
    required this.iconSizeActive,
    required this.labelMaxLines,
  });

  final double circleSize;
  final double itemWidth;
  final double horizontalGap;
  final double rowHeight;
  final double labelFontSize;
  final double iconSize;
  final double iconSizeActive;
  final int labelMaxLines;

  static const desktop = HomeMoodCircleLayout(
    circleSize: 72,
    itemWidth: 96,
    horizontalGap: 24,
    rowHeight: 72 + 8 + 34,
    labelFontSize: 12.5,
    iconSize: 26,
    iconSizeActive: 34,
    labelMaxLines: 2,
  );

  double contentWidth(int itemCount) {
    if (itemCount <= 0) return 0;
    return itemCount * itemWidth + (itemCount - 1) * horizontalGap;
  }

  /// TV: shrink items so every mood fits on screen without horizontal scroll.
  static HomeMoodCircleLayout forTv({
    required int itemCount,
    required double maxWidth,
  }) {
    if (itemCount <= 0) return desktop;

    const edgePad = 12.0;
    final available = (maxWidth - edgePad * 2).clamp(240.0, double.infinity);

    var gap = 10.0;
    var itemWidth = 78.0;
    while (
        itemCount * itemWidth + (itemCount - 1) * gap > available &&
        itemWidth > 52) {
      itemWidth -= 2;
      gap = math.max(4, gap - 1);
    }

    final circleSize = (itemWidth * 0.74).clamp(40.0, 54.0);
    final labelFontSize = itemWidth < 64 ? 9.5 : 10.5;
    final labelLineHeight = 1.15;
    final rowHeight = circleSize + 6 + labelFontSize * labelLineHeight + 2;
    final iconSize = circleSize * 0.42;
    final iconSizeActive = circleSize * 0.52;

    return HomeMoodCircleLayout(
      circleSize: circleSize,
      itemWidth: itemWidth,
      horizontalGap: gap,
      rowHeight: rowHeight,
      labelFontSize: labelFontSize,
      iconSize: iconSize,
      iconSizeActive: iconSizeActive,
      labelMaxLines: 1,
    );
  }

  static HomeMoodCircleLayout resolve(
    BuildContext context, {
    required int itemCount,
    required double maxWidth,
  }) {
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return forTv(itemCount: itemCount, maxWidth: maxWidth);
    }
    return desktop;
  }
}

/// Circular mood picker - layout matches details **Main Characters** cast row.
class HomeMoodCircleItem extends StatefulWidget {
  const HomeMoodCircleItem({
    required this.layout,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.listIndex,
    this.tvTabId,
    this.tvRowId,
    this.onDownEdge,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final HomeMoodCircleLayout layout;
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  final int? listIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onDownEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<HomeMoodCircleItem> createState() => HomeMoodCircleItemState();
}

class HomeMoodCircleItemState extends State<HomeMoodCircleItem> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active => widget.selected || _hovered || _focused;

  Widget _circle() {
    final layout = widget.layout;
    final accent = widget.accent;
    final bgAlpha = widget.selected ? 0.62 : (_active ? 0.42 : 0.22);
    final borderColor = widget.selected
        ? accent
        : _active
            ? accent.withValues(alpha: 0.95)
            : accent.withValues(alpha: 0.35);
    final iconSize =
        _active ? layout.iconSizeActive : layout.iconSize;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: layout.circleSize,
      height: layout.circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: bgAlpha),
        border: Border.all(
          color: borderColor,
          width: widget.selected ? 2.5 : 1.5,
        ),
        boxShadow: _active
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: layout.circleSize * 0.2,
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        scale: _active ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Icon(
          widget.icon,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _content() {
    final layout = widget.layout;
    return SizedBox(
      width: layout.itemWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circle(),
          SizedBox(height: layout.labelMaxLines == 1 ? 6 : 8),
          Text(
            widget.label,
            maxLines: layout.labelMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: layout.labelFontSize,
              fontWeight:
                  widget.selected || _focused ? FontWeight.w700 : FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    final policy = ShellScope.inputPolicyOf(context);
    final borderRadius = widget.layout.circleSize / 2;

    if (policy.useFocusableMoodChips) {
      return shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: borderRadius,
        scaleOnFocus: 1.0,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHoverChange: policy.scaleOnHover
            ? (hovered) => setState(() => _hovered = hovered)
            : null,
        listIndex: widget.listIndex,
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvRowId,
        tvItemIndex: widget.listIndex,
        tvZone: ShellTvZone.chipStrip,
        onDownEdge: widget.onDownEdge,
        onUpEdge: widget.onUpEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

class HomeMoodSection extends StatefulWidget {
  final List<({
    String id,
    String label,
    IconData icon,
    Color accent,
    List<int> movieGenres,
    List<int> tvGenres,
  })> moods;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Future<List<Movie>>? future;
  final Function(Movie) onMovieTap;
  final bool compactTop;
  final int tvRowOrder;

  const HomeMoodSection({
    required this.moods,
    required this.selectedId,
    required this.onSelect,
    required this.future,
    required this.onMovieTap,
    this.compactTop = false,
    this.tvRowOrder = 3,
  });

  @override
  State<HomeMoodSection> createState() => HomeMoodSectionState();
}

class HomeMoodSectionState extends State<HomeMoodSection> {
  List<Movie>? _cachedResults;

  Widget _moodCircleItem({
    required BuildContext context,
    required HomeMoodCircleLayout layout,
    required int i,
    required List<({
      String id,
      String label,
      IconData icon,
      Color accent,
      List<int> movieGenres,
      List<int> tvGenres,
    })> moods,
    required String selectedId,
    required ValueChanged<String> onSelect,
    TvChipEdges? edges,
  }) {
    final m = moods[i];
    final isSelected = m.id == selectedId;
    return HomeMoodCircleItem(
      layout: layout,
      label: m.label,
      icon: m.icon,
      accent: m.accent,
      selected: isSelected,
      listIndex: i,
      tvTabId: 'home',
      tvRowId: 'mood-chips',
      onTap: () {
        if (m.id != selectedId) {
          onSelect(m.id);
        } else if (edges != null) {
          edges.onSelectAlreadySelected();
        }
      },
      onLeftEdge: edges?.onLeft,
      onRightEdge: edges?.onRight,
      onUpEdge: edges?.onUp,
      onDownEdge: edges?.onDown,
    );
  }

  Widget _centeredMoodRow({
    required BuildContext context,
    required HomeMoodCircleLayout layout,
    required List<({
      String id,
      String label,
      IconData icon,
      Color accent,
      List<int> movieGenres,
      List<int> tvGenres,
    })> moods,
    required String selectedId,
    required ValueChanged<String> onSelect,
    bool scaleToFit = false,
    TvChipEdges Function(int index)? edgesFor,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < moods.length; i++) ...[
          if (i > 0) SizedBox(width: layout.horizontalGap),
          _moodCircleItem(
            context: context,
            layout: layout,
            i: i,
            moods: moods,
            selectedId: selectedId,
            onSelect: onSelect,
            edges: edgesFor?.call(i),
          ),
        ],
      ],
    );

    return SizedBox(
      height: layout.rowHeight,
      width: double.infinity,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: scaleToFit
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: row,
              )
            : Center(child: row),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moods = widget.moods;
    final selectedId = widget.selectedId;
    final onSelect = widget.onSelect;
    final future = widget.future;
    final onMovieTap = widget.onMovieTap;
    final titleTop = shellHomeSectionTitleTop(
      context,
      compact: widget.compactTop,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: shellHomeSectionTitlePadding(
            context,
            top: titleTop,
            bottom: shellScaled(context, 12).clamp(4.0, 12.0),
          ),
          child: const Text(
            "What's your mood?",
            style: ShellSectionTitle.titleStyle,
          ),
        ),
        Builder(
          builder: (context) {
            final tvNav =
                ShellScope.inputPolicyOf(context).useFocusableMoodChips;
            return LayoutBuilder(
              builder: (context, constraints) {
                final layout = HomeMoodCircleLayout.resolve(
                  context,
                  itemCount: moods.length,
                  maxWidth: constraints.maxWidth,
                );

                if (tvNav) {
                  return TvChipStrip(
                    rowId: 'mood-chips',
                    sortOrder: widget.tvRowOrder,
                    itemCount: moods.length,
                    resultsRowId: 'mood-results',
                    builder: (context, edgesFor) => _centeredMoodRow(
                      context: context,
                      layout: layout,
                      moods: moods,
                      selectedId: selectedId,
                      onSelect: onSelect,
                      scaleToFit: true,
                      edgesFor: edgesFor,
                    ),
                  );
                }

                final fitsCentered =
                    layout.contentWidth(moods.length) <= constraints.maxWidth;
                if (fitsCentered) {
                  return _centeredMoodRow(
                    context: context,
                    layout: layout,
                    moods: moods,
                    selectedId: selectedId,
                    onSelect: onSelect,
                  );
                }

                return FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: HorizontalScroller(
                    height: layout.rowHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: shellHomeSectionHorizontalPadding(context),
                    ),
                    itemCount: moods.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(width: layout.horizontalGap),
                    itemBuilder: (context, i) => _moodCircleItem(
                      context: context,
                      layout: layout,
                      i: i,
                      moods: moods,
                      selectedId: selectedId,
                      onSelect: onSelect,
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Movie>>(
          future: future,
          builder: (context, snap) {
            final waiting =
                future == null || snap.connectionState == ConnectionState.waiting;
            if (snap.hasData && snap.data!.isNotEmpty) {
              _cachedResults = snap.data;
            }
            final movies = waiting && _cachedResults != null
                ? _cachedResults!
                : (snap.data ?? const <Movie>[]);
            final loading = waiting && _cachedResults == null;

            if (loading) {
              return homeLoadingShimmer(
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SizedBox(
                    height: HomeMovieCard.cardHeight(context),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: shellHomeSectionHorizontalPadding(context),
                      ),
                      itemCount: 5,
                      separatorBuilder: (_, _) =>
                          SizedBox(width: shellMovieCardRowGap(context)),
                      itemBuilder: (_, _) => homeCardSkeleton(context),
                    ),
                  ),
                ),
              );
            }

            if (movies.isEmpty) {
              return SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No matches for this mood',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }
            final count = movies.length.clamp(0, 20);
            return TvCatalogRow(
              rowId: 'mood-results',
              sortOrder: widget.tvRowOrder + 1,
              itemCount: count,
              child: FocusTraversalGroup(
                child: HorizontalScroller(
                  height: HomeMovieCard.cardHeight(context),
                  padding: EdgeInsets.symmetric(
                    horizontal: shellHomeSectionHorizontalPadding(context),
                  ),
                  itemCount: count,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: shellMovieCardRowGap(context)),
                  itemBuilder: (context, i) => HomeMovieCard(
                    movie: movies[i],
                    onTap: () => onMovieTap(movies[i]),
                    listIndex: i,
                    tvTabId: 'home',
                    tvRowId: 'mood-results',
                    onUpEdge: tvResultsUpToChips(context),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
