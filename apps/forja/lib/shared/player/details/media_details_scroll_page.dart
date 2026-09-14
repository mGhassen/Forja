import 'package:flutter/material.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja_foundation/widgets/details/details_scroll_page.dart';

/// Host scroll page — wires TV hero/back focus into foundation paint.
class MediaDetailsScrollPage extends StatelessWidget {
  const MediaDetailsScrollPage({
    super.key,
    required this.hero,
    required this.backgroundColor,
    required this.sections,
    this.overlay,
    this.scrollController,
    this.bodyOverlap,
    this.topSpacing,
    this.tvHeroPlayFocus,
    this.tvBackFocus,
  });

  final Widget hero;
  final Color backgroundColor;
  final List<Widget> sections;
  final Widget? overlay;
  final ScrollController? scrollController;
  final double? bodyOverlap;
  final double? topSpacing;
  final FocusNode? tvHeroPlayFocus;
  final FocusNode? tvBackFocus;

  @override
  Widget build(BuildContext context) {
    Widget page = DetailsScrollPage(
      hero: hero,
      backgroundColor: backgroundColor,
      sections: sections,
      overlay: overlay,
      scrollController: scrollController,
      bodyOverlap: bodyOverlap,
      topSpacing: topSpacing,
    );

    if (tvHeroPlayFocus != null && scrollController != null) {
      page = MediaDetailsTvScope(
        heroPlayFocus: tvHeroPlayFocus!,
        scrollController: scrollController!,
        backFocus: tvBackFocus,
        child: page,
      );
    }

    return page;
  }
}
