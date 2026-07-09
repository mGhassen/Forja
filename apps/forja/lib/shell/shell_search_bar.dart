import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Shell-owned search field shown above tab body on the Search tab.
class ShellSearchBar extends StatelessWidget {
  const ShellSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ShellTokens.bodyHorizontalPadding,
          8,
          ShellTokens.bodyHorizontalPadding,
          8,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.current.bgCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Search movies, shows...',
              hintStyle: const TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: query.isNotEmpty
                  ? ForjaCloseButton.compact(
                      tooltip: null,
                      color: Colors.white70,
                      onTap: onClear,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
