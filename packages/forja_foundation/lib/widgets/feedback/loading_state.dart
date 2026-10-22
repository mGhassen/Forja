import 'package:flutter/material.dart';
import 'package:forja_foundation/components/spinner.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/loading_state_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Centered wait / outcome state: spinner (or [icon]) + [title] + optional
/// [detail], [hint] and an [actions] slot.
///
/// Paint only — the host decides what the title is (the item name while
/// metadata loads, the source label while a stream opens, the failure copy)
/// and fills [actions] with its own focusable buttons.
///
/// TV density: spinner / icon use hand-tuned sizes; type follows the leanback
/// ladder ([LoadingStateTokens]).
class ForjaLoadingState extends StatelessWidget {
  const ForjaLoadingState({
    super.key,
    this.title,
    this.detail,
    this.hint,
    this.icon,
    this.iconColor,
    this.actions,
    this.backgroundColor,
  });

  /// Shown when [title] is null or blank.
  static const String defaultTitle = 'Loading…';

  final String? title;
  final String? detail;

  /// Small muted line under [detail] — remote hints ("Press Back to cancel").
  final String? hint;

  /// When set, replaces the spinner (terminal states such as a failure).
  final IconData? icon;
  final Color? iconColor;

  /// Host-provided row of controls (Retry / Back). Painted under the text.
  final Widget? actions;

  /// Null paints nothing behind the column (overlay use); set for full pages.
  final Color? backgroundColor;

  String get _title {
    final t = title?.trim() ?? '';
    return t.isEmpty ? defaultTitle : t;
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final spinner = tv
        ? LoadingStateTokens.spinnerTv
        : LoadingStateTokens.spinner;
    final stroke = tv
        ? LoadingStateTokens.spinnerStrokeTv
        : LoadingStateTokens.spinnerStroke;
    final iconSize = tv
        ? LoadingStateTokens.statusIconTv
        : LoadingStateTokens.statusIcon;
    final titleSize = tv
        ? LoadingStateTokens.titleFontSizeTv
        : LoadingStateTokens.titleFontSize;
    final detailSize = tv
        ? LoadingStateTokens.detailFontSizeTv
        : LoadingStateTokens.detailFontSize;
    final hintSize = tv
        ? LoadingStateTokens.hintFontSizeTv
        : LoadingStateTokens.hintFontSize;
    final titleGap = tv
        ? LoadingStateTokens.titleGapTv
        : LoadingStateTokens.titleGap;
    final detailGap = tv
        ? LoadingStateTokens.detailGapTv
        : LoadingStateTokens.detailGap;
    final hintGap = tv
        ? LoadingStateTokens.hintGapTv
        : LoadingStateTokens.hintGap;
    final actionsGap = tv
        ? LoadingStateTokens.actionsGapTv
        : LoadingStateTokens.actionsGap;
    final maxW = tv
        ? LoadingStateTokens.maxWidthTv
        : LoadingStateTokens.maxWidth;
    final padH = tv ? LoadingStateTokens.padHTv : LoadingStateTokens.padH;
    final padV = tv ? LoadingStateTokens.padVTv : LoadingStateTokens.padV;

    final detailText = detail?.trim() ?? '';
    final hintText = hint?.trim() ?? '';

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? ForjaShellColors.sectionAccent,
          )
        else
          Spinner(
            size: SpinnerSize.lg,
            dimension: spinner,
            strokeWidth: stroke,
          ),
        SizedBox(height: titleGap),
        Text(
          _title,
          textAlign: TextAlign.center,
          maxLines: LoadingStateTokens.titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ForjaShellColors.textPrimary.withValues(
              alpha: LoadingStateTokens.titleAlpha,
            ),
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            height: LoadingStateTokens.titleLineHeight,
            letterSpacing: LoadingStateTokens.titleLetterSpacing,
          ),
        ),
        if (detailText.isNotEmpty) ...[
          SizedBox(height: detailGap),
          Text(
            detailText,
            textAlign: TextAlign.center,
            maxLines: LoadingStateTokens.detailMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ForjaShellColors.textPrimary.withValues(
                alpha: LoadingStateTokens.detailAlpha,
              ),
              fontSize: detailSize,
              fontWeight: FontWeight.w500,
              height: LoadingStateTokens.detailLineHeight,
            ),
          ),
        ],
        if (hintText.isNotEmpty) ...[
          SizedBox(height: hintGap),
          Text(
            hintText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ForjaShellColors.textPrimary.withValues(
                alpha: LoadingStateTokens.hintAlpha,
              ),
              fontSize: hintSize,
              fontWeight: FontWeight.w500,
              letterSpacing: LoadingStateTokens.hintLetterSpacing,
            ),
          ),
        ],
        if (actions != null) ...[SizedBox(height: actionsGap), actions!],
      ],
    );

    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: column,
        ),
      ),
    );

    if (backgroundColor == null) return body;
    return ColoredBox(color: backgroundColor!, child: body);
  }
}
