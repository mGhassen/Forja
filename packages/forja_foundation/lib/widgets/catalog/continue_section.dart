import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:forja_foundation/widgets/chrome/section_title.dart';

/// Continue-watching row — props only (RFC-106 G5).
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    super.key,
    this.title = 'Continue watching',
    this.items,
    this.children,
    this.onSeeAll,
  }) : assert(items != null || children != null);

  final String title;
  final List<PosterItem>? items;
  final List<Widget>? children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle(
          title,
          trailing: onSeeAll == null
              ? null
              : GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        PosterRail(
          items: children == null ? items : null,
          children: children,
        ),
      ],
    );
  }
}
