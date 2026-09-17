import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Plain text title for horizontal catalog rows (no icon, no underline).
class ShellSectionTitle extends StatelessWidget {
  const ShellSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsetsDirectional.only(
      start: ShellTokens.homeSectionHorizontalPadding,
      top: ShellTokens.homeSectionTitleTop,
      end: ShellTokens.homeSectionHorizontalPadding,
      bottom: 16,
    ),
    this.trailing,
    this.fontSize = ShellTokens.sectionTitleFontSize,
    this.subtitleFontSize = ShellTokens.sectionSubtitleFontSize,
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final List<Widget>? trailing;
  final double fontSize;
  final double subtitleFontSize;

  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: ShellTokens.sectionTitleFontSize,
    fontWeight: FontWeight.w800,
    letterSpacing: ShellTokens.sectionTitleLetterSpacing,
  );

  static TextStyle subtitleStyle(BuildContext context, {double fontSize = ShellTokens.sectionSubtitleFontSize}) =>
      TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: fontSize,
      );

  static EdgeInsetsDirectional defaultPadding(BuildContext context) {
    final h = ShellTokens.homeSectionHorizontalPadding;
    return EdgeInsetsDirectional.only(
      start: h,
      top: ShellTokens.homeSectionTitleTop,
      end: h,
      bottom: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding ==
            const EdgeInsetsDirectional.only(
              start: ShellTokens.homeSectionHorizontalPadding,
              top: ShellTokens.homeSectionTitleTop,
              end: ShellTokens.homeSectionHorizontalPadding,
              bottom: 16,
            )
            ? defaultPadding(context)
            : padding;
    final resolvedTitleStyle = titleStyle.copyWith(fontSize: fontSize);
    final titleBlock = subtitle == null
        ? Text(title, style: resolvedTitleStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: resolvedTitleStyle),
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: subtitleStyle(context, fontSize: subtitleFontSize),
              ),
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
