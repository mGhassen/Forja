import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/details/details_block.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Generic kit entry details chrome — props + body slot (RFC-106 Zone A).
///
/// Host [KitEntryDetailsPage] wires list registry / routing into [body].
class EntryDetails extends StatelessWidget {
  const EntryDetails({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.emptyMessage = 'No details panel for this list',
  });

  final String title;
  final Widget? body;
  final VoidCallback? onBack;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return EntryDetailsChrome(
      title: title,
      onBack: onBack,
      body: body ??
          Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: ForjaShellColors.textSecondary),
            ),
          ),
    );
  }
}
