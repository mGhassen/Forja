import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// Optional title row for body-only shell tabs.
class ShellTabHeader extends StatelessWidget {
  const ShellTabHeader({
    super.key,
    required this.title,
    this.actions,
    this.padding,
  });

  final String title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            ShellTokens.bodyHorizontalPadding,
            ShellTokens.tabHeaderTopPadding,
            ShellTokens.bodyHorizontalPadding,
            ShellTokens.tabHeaderBottomPadding,
          ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ShellTokens.tabHeaderFontSize,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}
