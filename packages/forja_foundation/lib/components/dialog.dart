import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

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
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => ForjaDialog(
      title: title,
      description: description,
      body: body,
      actions: actions,
      type: type,
    ),
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
    final titleColor = type == ForjaDialogType.destructive
        ? const Color(0xFFF87171)
        : theme.textPrimary;

    return Dialog(
      backgroundColor: theme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusMd),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(theme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (description != null) ...[
                SizedBox(height: theme.spaceSm),
                Text(
                  description!,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              if (body != null) ...[
                SizedBox(height: theme.spaceMd),
                body!,
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                SizedBox(height: theme.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) SizedBox(width: theme.spaceSm),
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
