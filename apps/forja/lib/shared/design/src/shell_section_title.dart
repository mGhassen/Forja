import 'package:flutter/material.dart';

import 'package:forja/shared/design/src/shell_layout.dart';

/// Plain text title for horizontal catalog rows (no icon, no underline).
class ShellSectionTitle extends StatelessWidget {
  const ShellSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(24, 36, 24, 16),
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final List<Widget>? trailing;

  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static TextStyle subtitleStyle(BuildContext context) => TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 11,
      );

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding == const EdgeInsets.fromLTRB(24, 36, 24, 16)
            ? shellSectionTitlePadding(context)
            : padding;
    final titleStyle = shellSectionTitleTextStyle(context);
    final titleBlock = subtitle == null
        ? Text(title, style: titleStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              SizedBox(height: shellScaled(context, 2).clamp(1.0, 2.0)),
              Text(subtitle!, style: shellSectionSubtitleTextStyle(context)),
            ],
          );

    if (trailing == null || trailing!.isEmpty) {
      return Padding(padding: resolvedPadding, child: titleBlock);
    }

    return Padding(
      padding: resolvedPadding,
      child: Row(
        children: [
          Expanded(child: titleBlock),
          ...trailing!,
        ],
      ),
    );
  }
}
