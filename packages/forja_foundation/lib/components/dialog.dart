import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Dialog tone.
enum ForjaDialogType {
  default_,
  destructive,
}

/// Show a Forja-styled modal dialog. Returns the result from [actions] pops.
Future<T?> showForjaDialog<T>({
  required BuildContext context,
  required String title,
  String? description,
  Widget? body,
  List<Widget>? actions,
  ForjaDialogType type = ForjaDialogType.default_,
  bool barrierDismissible = true,
}) {
  final hostPaint = ShellPaintScope.maybeOf(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      Widget dialog = ForjaDialog(
        title: title,
        description: description,
        body: body,
        actions: actions,
        type: type,
      );
      // Overlay routes leave the host [ShellPaintScope]; rehost density so
      // leanback type / padding still apply.
      if (hostPaint != null) {
        dialog = ShellPaintScope(
          useTvFocus: hostPaint.useTvFocus,
          scaleOnHover: hostPaint.scaleOnHover,
          usesTvDensity: hostPaint.usesTvDensity,
          focusStyled: hostPaint.focusStyled,
          focusableTapBuilder: hostPaint.focusableTapBuilder,
          wrapTvRow: hostPaint.wrapTvRow,
          wrapHorizontalScroller: hostPaint.wrapHorizontalScroller,
          absorbHorizontalScroll: hostPaint.absorbHorizontalScroll,
          isActivateKey: hostPaint.isActivateKey,
          child: dialog,
        );
      }
      return dialog;
    },
  );
}

/// Forja modal dialog surface.
class ForjaDialog extends StatelessWidget {
  const ForjaDialog({
    super.key,
    required this.title,
    this.description,
    this.body,
    this.actions,
    this.type = ForjaDialogType.default_,
  });

  final String title;
  final String? description;
  final Widget? body;
  final List<Widget>? actions;
  final ForjaDialogType type;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleColor = type == ForjaDialogType.destructive
        ? const Color(0xFFF87171)
        : theme.textPrimary;
    final screen = MediaQuery.sizeOf(context);
    final maxW = SettingsTokens.dialogMaxWidthOf(context, screen.width);
    final pad = tv ? theme.spaceMd : theme.spaceLg;
    final gapSm = tv ? 4.0 : theme.spaceSm;
    final gapMd = tv ? theme.spaceSm : theme.spaceMd;
    final gapLg = tv ? theme.spaceMd : theme.spaceLg;

    return Dialog(
      backgroundColor: theme.surfaceElevated,
      insetPadding: SettingsTokens.dialogInsetPaddingOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          SettingsTokens.dialogRadiusOf(context),
        ),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: tv ? ShellTokens.tvTitleFontSize : 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (description != null) ...[
                SizedBox(height: gapSm),
                Text(
                  description!,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: tv ? ShellTokens.tvBodyFontSize : 14,
                    height: 1.4,
                  ),
                ),
              ],
              if (body != null) ...[
                SizedBox(height: gapMd),
                body!,
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                SizedBox(height: gapLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) SizedBox(width: gapSm),
                      actions![i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Convenience cancel / confirm action pair.
  static List<Widget> confirmActions({
    required BuildContext context,
    String cancelLabel = 'Cancel',
    String confirmLabel = 'Confirm',
    bool destructive = false,
    VoidCallback? onConfirm,
  }) {
    return [
      Button(
        variant: ButtonVariant.ghost,
        label: cancelLabel,
        onPressed: () => Navigator.of(context).maybePop(false),
      ),
      Button(
        variant:
            destructive ? ButtonVariant.destructive : ButtonVariant.primary,
        label: confirmLabel,
        onPressed: () {
          onConfirm?.call();
          Navigator.of(context).maybePop(true);
        },
      ),
    ];
  }
}
