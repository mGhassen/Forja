import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

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
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            ShellTokens.compactChromeLeadingInset(context),
            ShellTokens.tabHeaderTopPadding,
            ShellTokens.bodyHorizontalPadding,
            ShellTokens.tabHeaderBottomPadding,
          ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: ShellTokens.tabHeaderFontSize,
              ),
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}
