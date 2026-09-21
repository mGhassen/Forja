import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/props_map.dart';

/// Prebuilt hub catalog scroll body — section list + bottom gap.
///
/// ```json
/// { "type": "catalogBody", "props": { "bottomGap": 24 }, "children": [ …rails… ] }
/// ```
class CatalogBody extends StatelessWidget {
  const CatalogBody({
    super.key,
    required this.sections,
    this.controller,
    this.bottomGap = 0,
    this.cacheExtent,
    this.sectionSliver,
    this.emptyChild,
  });

  factory CatalogBody.fromProps(
    Map<String, dynamic> props, {
    required List<Widget> sections,
    ScrollController? controller,
    double? cacheExtent,
    Widget? emptyChild,
    Widget Function(BuildContext context, Widget section, int index)?
        sectionSliver,
  }) {
    return CatalogBody(
      sections: sections,
      controller: controller,
      bottomGap: propsNumOr(props, 'bottomGap', 0),
      cacheExtent: cacheExtent,
      sectionSliver: sectionSliver,
      emptyChild: emptyChild,
    );
  }

  final List<Widget> sections;
  final ScrollController? controller;
  final double bottomGap;

  /// Extra build window beyond the viewport. Hub TV D-pad needs below-fold
  /// rails mounted so [TvKitRow] can register before ↓ reaches them.
  final double? cacheExtent;

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
      cacheExtent: cacheExtent,
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
