import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/tv_search_browse_overlay.dart';

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
    this.tvBrowseMode = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;
  final bool wrapSafeArea;
  final Widget? clearSuffix;
  final bool tvBrowseMode;

  @override
  Widget build(BuildContext context) {
    const hintStyle = TextStyle(color: Colors.white38, fontSize: 18);

    Widget buildField(bool showBrowsePlaceholder) {
      return Padding(
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
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: tvBrowseMode,
                showCursor: tvBrowseMode && query.isNotEmpty,
                enableInteractiveSelection: !tvBrowseMode,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: showBrowsePlaceholder ? null : hintText,
                  hintStyle: hintStyle,
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
              if (showBrowsePlaceholder)
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: TvSearchBrowsePlaceholder(
                    active: true,
                    placeholder: hintText,
                    hintStyle: hintStyle,
                    caretHeight: 20,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final field = ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final showBrowsePlaceholder =
            tvBrowseMode && focusNode.hasFocus && query.isEmpty;
        return buildField(showBrowsePlaceholder);
      },
    );

    if (!wrapSafeArea) return field;
    return SafeArea(bottom: false, child: field);
  }
}
