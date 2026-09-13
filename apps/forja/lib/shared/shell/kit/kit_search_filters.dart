import 'package:flutter/material.dart';
import 'package:forja/shared/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/catalog_search_filters.dart';

export 'package:forja_foundation/widgets/chrome/catalog_search_filters.dart'
    show
        CatalogSearchFilters,
        CatalogSearchFilterLens,
        CatalogScoreArcPainter,
        CatalogYearTimelinePainter,
        SearchFilters,
        SearchMediaFilter,
        composeSearchQuery,
        kSearchFilterCountries,
        kSearchFilterGenres,
        kSearchFilterLanguages;

class KitSearchFilterToken extends StatelessWidget {
  const KitSearchFilterToken({
    super.key,
    required this.label,
    required this.onClear,
    this.listIndex,
  });

  final String label;
  final VoidCallback onClear;
  final int? listIndex;

  @override
  Widget build(BuildContext context) {
    final tabId = TvFocusGraph.tabIdOf(context, fallback: 'search');
    return shellFocusableTap(
      context: context,
      borderRadius: 16,
      scaleOnFocus: 1.04,
      onTap: onClear,
      listIndex: listIndex,
      tvTabId: tabId,
      tvRowId: 'search_filter_tokens',
      tvZone: ShellTvZone.row,
      tvItemIndex: listIndex,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ForjaShellColors.textPrimary.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.close,
              size: 14,
              color: ForjaShellColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

bool _searchFilterTvLeanback(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  if (policy != null) {
    return policy.useFocusableMoodChips && !policy.scaleOnHover;
  }
  return ShellTokens.isAndroidTvDevice;
}

/// Host TV/Interactive wrapper over [CatalogSearchFilterLens].
class KitSearchFilterLens extends StatelessWidget {
  const KitSearchFilterLens({
    super.key,
    required this.open,
    required this.filters,
    required this.onFiltersChanged,
    required this.onSubmit,
    this.firstFocusNode,
    this.onUpFromFirst,
  });

  final bool open;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onFiltersChanged;
  final VoidCallback onSubmit;
  final FocusNode? firstFocusNode;
  final VoidCallback? onUpFromFirst;

  @override
  Widget build(BuildContext context) {
    final tabId = TvFocusGraph.tabIdOf(context, fallback: 'search');
    return CatalogSearchFilterLens(
      open: open,
      filters: filters,
      onFiltersChanged: onFiltersChanged,
      onSubmit: onSubmit,
      firstFocusNode: firstFocusNode,
      onUpFromFirst: onUpFromFirst,
      tvLeanback: _searchFilterTvLeanback(context),
      onLeftFromFirstSegment: ShellTvFocusCoordinator.focusActiveNavTab,
      interactiveBuilder: ({
        required child,
        required onTap,
        focusNode,
        onUpEdge,
        onLeftEdge,
        listIndex,
        tvRowId,
      }) {
        final isSegment = tvRowId == null && listIndex != null;
        final isSubmit = tvRowId == null && listIndex == null && focusNode == null;
        return shellFocusableTap(
          context: context,
          focusNode: focusNode,
          onUpEdge: onUpEdge,
          onLeftEdge: onLeftEdge,
          listIndex: listIndex,
          borderRadius: isSubmit || isSegment ? 20 : 16,
          scaleOnFocus: isSegment
              ? 1.0
              : isSubmit
                  ? 1.02
                  : 1.04,
          showFocusFill: isSegment,
          onTap: onTap,
          tvTabId: tabId,
          tvRowId: tvRowId,
          tvZone: ShellTvZone.row,
          tvItemIndex: listIndex,
          child: child,
        );
      },
    );
  }
}
