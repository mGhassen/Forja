import 'package:flutter/material.dart';

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
    final titleBlock = subtitle == null
        ? Text(title, style: titleStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(height: 2),
              Text(subtitle!, style: subtitleStyle(context)),
            ],
          );

    if (trailing == null || trailing!.isEmpty) {
      return Padding(padding: padding, child: titleBlock);
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: titleBlock),
          ...trailing!,
        ],
      ),
    );
  }
}
