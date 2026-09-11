import 'package:flutter/material.dart';

/// Catalog hub scroll body — section list + bottom gap (RFC-106 Zone A).
///
/// Host builds section widgets (rails, hero, mood) and optional sliver
/// wrappers; this composer owns [CustomScrollView] chrome only.
class CatalogBody extends StatelessWidget {
  const CatalogBody({
    super.key,
    required this.sections,
    this.controller,
    this.bottomGap = 0,
    this.sectionSliver,
    this.emptyChild,
  });

  final List<Widget> sections;
  final ScrollController? controller;
  final double bottomGap;

  /// Host maps each section to a sliver (e.g. row spacing). Default:
  /// [SliverToBoxAdapter].
  final Widget Function(BuildContext context, Widget section, int index)?
      sectionSliver;

  final Widget? emptyChild;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return emptyChild ?? const SizedBox.shrink();
    }
    return CustomScrollView(
      controller: controller,
      slivers: [
        for (var i = 0; i < sections.length; i++)
          sectionSliver?.call(context, sections[i], i) ??
              SliverToBoxAdapter(child: sections[i]),
        if (bottomGap > 0)
          SliverToBoxAdapter(child: SizedBox(height: bottomGap)),
      ],
    );
  }
}
