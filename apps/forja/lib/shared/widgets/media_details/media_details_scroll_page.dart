import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/widgets/media_details_body.dart';

/// Unified scroll layout for torrent and streaming media details screens.
class MediaDetailsScrollPage extends StatelessWidget {
  const MediaDetailsScrollPage({
    super.key,
    required this.hero,
    required this.backgroundColor,
    required this.sections,
    this.overlay,
  });

  final Widget hero;
  final Color backgroundColor;
  final List<Widget> sections;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hero,
          MediaDetailsBody(
            backgroundColor: backgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

    if (overlay == null) return scroll;

    return Stack(
      children: [
        scroll,
        overlay!,
      ],
    );
  }
}
