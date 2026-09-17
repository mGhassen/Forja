import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/details/details_block.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/widgets/details/details_body.dart';

/// Unified scroll layout for torrent and streaming media details screens.
///
/// Host wraps with TV focus scope when needed.
class DetailsScrollPage extends StatelessWidget {
  const DetailsScrollPage({
    super.key,
    required this.hero,
    required this.backgroundColor,
    required this.sections,
    this.overlay,
    this.scrollController,
    this.bodyOverlap,
    this.topSpacing,
  });

  final Widget hero;
  final Color backgroundColor;
  final List<Widget> sections;
  final Widget? overlay;
  final ScrollController? scrollController;
  final double? bodyOverlap;
  final double? topSpacing;

  @override
  Widget build(BuildContext context) {
    final scroll = DetailsBlock(
      hero: hero,
      scrollController: scrollController,
      physics: const BouncingScrollPhysics(),
      backgroundColor: backgroundColor,
      // Fade must sit *inside* DetailsBody's overlap pull-up. AnimatedOpacity
      // ancestors reject y < 0 before _OverlapPullUp can hit-test the band
      // where seasons / cast paint over the hero — hover never fires.
      body: sections.isEmpty
          ? const SizedBox.shrink()
          : DetailsBody(
              backgroundColor: backgroundColor,
              bodyOverlap: bodyOverlap,
              topSpacing: topSpacing,
              child: _FadeIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: DetailsTokens.sectionSpacing),
                      sections[i],
                    ],
                  ],
                ),
              ),
            ),
    );

    if (overlay == null) return scroll;

    return Stack(
      children: [
        scroll,
        overlay!,
      ],
    );
  }
}

/// Host alias — same paint as [DetailsScrollPage].
typedef MediaDetailsScrollPage = DetailsScrollPage;

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );
  }
}
