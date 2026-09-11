import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Show a Forja bottom sheet. Returns the result from [Navigator.pop].
Future<T?> showForjaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: heightFactor != null,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final theme = ForjaThemeExtension.of(ctx);
      Widget content = SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(top: theme.spaceSm, bottom: theme.spaceSm),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            builder(ctx),
          ],
        ),
      );

      if (heightFactor != null) {
        content = SizedBox(
          height: MediaQuery.sizeOf(ctx).height *
              heightFactor.clamp(0.2, 0.95),
          child: content,
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: theme.surfaceElevated,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.radiusMd * 1.5),
          ),
          border: Border(
            top: BorderSide(color: theme.borderSubtle),
            left: BorderSide(color: theme.borderSubtle),
            right: BorderSide(color: theme.borderSubtle),
          ),
        ),
        child: content,
      );
    },
  );
}
