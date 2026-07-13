import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/media_details_body.dart';

/// Unified scroll layout for torrent and streaming media details screens.
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
  });

  final Widget hero;
  final Color backgroundColor;
  final List<Widget> sections;
  final Widget? overlay;
  final ScrollController? scrollController;
  final double? bodyOverlap;
  final double? topSpacing;
  final FocusNode? tvHeroPlayFocus;

  @override
  Widget build(BuildContext context) {
    Widget scroll = SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hero,
          MediaDetailsBody(
            backgroundColor: backgroundColor,
            bodyOverlap: bodyOverlap,
            topSpacing: topSpacing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: ShellTokens.detailsSectionSpacing),
                  sections[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (tvHeroPlayFocus != null && scrollController != null) {
      scroll = MediaDetailsTvScope(
        heroPlayFocus: tvHeroPlayFocus!,
        scrollController: scrollController!,
        child: scroll,
      );
    }

    if (overlay == null) return scroll;

    return Stack(
      children: [
        scroll,
        overlay!,
      ],
    );
  }
}
