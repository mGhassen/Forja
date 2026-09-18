import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
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
    this.fontSize,
    this.subtitleFontSize,
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final List<Widget>? trailing;
  final double? fontSize;
  final double? subtitleFontSize;

  static TextStyle titleStyleFor(BuildContext context) {
    final tv = catalogUsesTvDensity(context);
    return TextStyle(
      color: Colors.white,
      fontSize: tv
          ? ShellTokens.tvTitleFontSize
          : ShellTokens.sectionTitleFontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: ShellTokens.sectionTitleLetterSpacing,
    );
  }

  /// Desktop title style (gallery / const callers). Prefer [titleStyleFor].
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: ShellTokens.sectionTitleFontSize,
    fontWeight: FontWeight.w800,
    letterSpacing: ShellTokens.sectionTitleLetterSpacing,
  );

  static TextStyle subtitleStyle(BuildContext context, {double? fontSize}) {
    final tv = catalogUsesTvDensity(context);
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.3),
      fontSize: fontSize ??
          (tv
              ? ShellTokens.tvMetaFontSize
              : ShellTokens.sectionSubtitleFontSize),
    );
  }

  static EdgeInsetsDirectional defaultPadding(BuildContext context) {
    final h = catalogSectionHorizontalPadding(context);
    return EdgeInsetsDirectional.only(
      start: h,
      top: catalogSectionTitleTop(context),
      end: h,
      bottom: catalogSectionBottomGap(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = catalogUsesTvDensity(context);
    final titleSize = fontSize ??
        (tv ? ShellTokens.tvTitleFontSize : ShellTokens.sectionTitleFontSize);
    final subSize = subtitleFontSize ??
        (tv
            ? ShellTokens.tvMetaFontSize
            : ShellTokens.sectionSubtitleFontSize);
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
    final resolvedTitleStyle = titleStyleFor(context).copyWith(fontSize: titleSize);
    final titleBlock = subtitle == null
        ? Text(title, style: resolvedTitleStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: resolvedTitleStyle),
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: subtitleStyle(context, fontSize: subSize),
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
