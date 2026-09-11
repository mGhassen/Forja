import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/components/poster_frame.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Opaque poster item for [PosterRail].
class PosterItem {
  const PosterItem({
    required this.url,
    this.title,
    this.onTap,
  });

  final String url;
  final String? title;
  final VoidCallback? onTap;
}

/// Horizontal poster rail — [PosterFrame] + optional title (RFC-106 G5 / G7).
class PosterRail extends StatelessWidget {
  const PosterRail({
    super.key,
    this.items,
    this.children,
    this.itemWidth = 120,
    this.itemHeight = 180,
    this.height,
    this.padding,
  }) : assert(items != null || children != null);

  final List<PosterItem>? items;
  final List<Widget>? children;
  final double itemWidth;
  final double itemHeight;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final listChildren = children ??
        [
          for (final item in items!)
            _PosterCell(
              item: item,
              width: itemWidth,
              height: itemHeight,
            ),
        ];

    return SizedBox(
      height: height ??
          (itemHeight +
              (items?.any((i) => i.title != null) == true ? 40 : 0) +
              theme.spaceSm),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.symmetric(horizontal: theme.spaceLg),
        itemCount: listChildren.length,
        separatorBuilder: (_, _) => SizedBox(width: theme.spaceMd),
        itemBuilder: (_, i) => listChildren[i],
      ),
    );
  }
}

class _PosterCell extends StatelessWidget {
  const _PosterCell({
    required this.item,
    required this.width,
    required this.height,
  });

  final PosterItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final frame = SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: height,
            child: PosterFrame(
              child: ForjaNetworkImage(url: item.url),
            ),
          ),
          if (item.title != null && item.title!.trim().isNotEmpty) ...[
            SizedBox(height: theme.spaceSm),
            Text(
              item.title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    if (item.onTap == null) return frame;
    return GestureDetector(onTap: item.onTap, child: frame);
  }
}
