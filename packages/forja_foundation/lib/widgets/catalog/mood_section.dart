import 'package:flutter/material.dart';
import 'package:forja_foundation/components/mood_circle.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/section_title.dart';

/// Horizontal mood section — wraps [MoodCircle] items.
class MoodSection extends StatelessWidget {
  const MoodSection({
    super.key,
    this.title,
    required this.children,
    this.padding,
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) SectionTitle(title!),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                padding ?? EdgeInsets.symmetric(horizontal: theme.spaceLg),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(width: theme.spaceMd),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}
