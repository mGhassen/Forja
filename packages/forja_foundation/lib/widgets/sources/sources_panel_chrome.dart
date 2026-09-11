import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Sources panel chrome only — title, list slot, close (RFC-106 G5).
///
/// No resolve / play / MatchEvent. Caller owns list content + callbacks.
class SourcesPanelChrome extends StatelessWidget {
  const SourcesPanelChrome({
    super.key,
    this.title = 'Sources',
    required this.list,
    this.onClose,
    this.header,
    this.width = 360,
  });

  final String title;
  final Widget list;
  final VoidCallback? onClose;
  final Widget? header;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: theme.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spaceMd,
                theme.spaceMd,
                theme.spaceSm,
                theme.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    Button(
                      variant: ButtonVariant.plainIcon,
                      size: ButtonSize.icon,
                      icon: Icons.close,
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
            if (header != null) header!,
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
}
