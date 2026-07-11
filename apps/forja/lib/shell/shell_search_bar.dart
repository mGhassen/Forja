import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';

/// Shell-owned search field shown above tab body on the Search tab.
class ShellSearchBar extends StatelessWidget {
  const ShellSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Search movies, shows...',
    this.wrapSafeArea = true,
    this.clearSuffix,
    this.onEscape,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;
  final bool wrapSafeArea;
  final Widget? clearSuffix;
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    final field = Padding(
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
        child: TvBrowseTextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onEscape: onEscape,
          browsePlaceholder: hintText,
          browseHintStyle: const TextStyle(color: Colors.white38),
          caretHeight: 22,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: query.isNotEmpty
                ? (clearSuffix ??
                    ForjaCloseButton.compact(
                      tooltip: null,
                      color: Colors.white70,
                      onTap: onClear,
                    ))
                : null,
          ),
        ),
      ),
    );

    if (!wrapSafeArea) return field;
    return SafeArea(bottom: false, child: field);
  }
}
