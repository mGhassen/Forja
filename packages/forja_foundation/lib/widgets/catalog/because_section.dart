import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';
import 'package:forja_foundation/widgets/chrome/section_title.dart';

/// Because-you-watched row — props only (RFC-106 G5).
class BecauseSection extends StatelessWidget {
  const BecauseSection({
    super.key,
    this.title,
    this.becauseTitle,
    this.items,
    this.children,
    this.onSeeAll,
  }) : assert(items != null || children != null);

  /// Full section heading. When null, built from [becauseTitle].
  final String? title;

  /// Source title for “Because you watched …”.
  final String? becauseTitle;

  final List<PosterItem>? items;
  final List<Widget>? children;
  final VoidCallback? onSeeAll;

  String get _resolvedTitle {
    if (title != null && title!.trim().isNotEmpty) return title!;
    final src = becauseTitle?.trim() ?? '';
    if (src.isEmpty) return 'Because you watched';
    return 'Because you watched $src';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle(
          _resolvedTitle,
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
