import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';

class HubCatalogSection<T> extends StatefulWidget {
  const HubCatalogSection({
    super.key,
    required this.title,
    required this.cardBuilder,
    this.future,
    this.items,
    this.compactTop = false,
    this.showRank = false,
  }) : assert(future != null || items != null);

  final String title;
  final Future<List<T>>? future;
  final List<T>? items;
  final bool compactTop;
  final bool showRank;
  final HubPosterCard Function(BuildContext context, T item, int index)
      cardBuilder;

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
  }) {
    final top = compactTop
        ? ShellTokens.homeSectionTitleTopCompactDesktop
        : ShellTokens.homeSectionTitleTop;
    const headerRow = 28.0;
    const bottomGap = 16.0;
    return top + headerRow + bottomGap + HubPosterCard.cardHeight(context);
  }

  @override
  State<HubCatalogSection<T>> createState() => _HubCatalogSectionState<T>();
}

class _HubCatalogSectionState<T> extends State<HubCatalogSection<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _sectionTitleTop(BuildContext context) {
    if (!widget.compactTop) return ShellTokens.homeSectionTitleTop;
    return homeUsesShellLayout(context)
        ? ShellTokens.homeSectionTitleTopCompactDesktop
        : ShellTokens.homeSectionTitleTopCompactMobile;
  }

  Widget _buildRow(List<T> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    final sectionTop = _sectionTitleTop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShellSectionTitle(
          title: widget.title,
          padding: EdgeInsets.fromLTRB(24, sectionTop, 24, 16),
        ),
        SizedBox(
          height: HubPosterCard.cardHeight(context),
          child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: widget.showRank ? 6 : 14),
            itemBuilder: (context, index) =>
                widget.cardBuilder(context, list[index], index),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final staticItems = widget.items;
    if (staticItems != null) {
      return _buildRow(staticItems);
    }

    return FutureBuilder<List<T>>(
      future: widget.future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final list = snapshot.data ?? <T>[];

        if (loading || list.isEmpty) {
          if (loading || !snapshot.hasData) {
            return homeLoadingShimmer(
              homeMovieRowSkeleton(
                context,
                compactTop: widget.compactTop,
                titleWidth: widget.title.length > 12
                    ? 180
                    : widget.title.length * 11.0,
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return _buildRow(list);
      },
    );
  }
}

SliverToBoxAdapter hubRowSliver(
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero)
          const SizedBox(height: ShellTokens.homeRowSpacing),
        RepaintBoundary(child: section),
      ],
    ),
  );
}
