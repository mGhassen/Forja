import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';

/// Compact top chrome for the Sources panel:
/// title + count · kind chips · optional providers · search/filters.
class TorrentSourcesPanelChrome extends StatelessWidget {
  const TorrentSourcesPanelChrome({
    super.key,
    required this.onClose,
    required this.kindFilter,
    required this.showTorrents,
    required this.showStremio,
    required this.showNuvio,
    required this.onKindChanged,
    required this.resultCount,
    required this.isFetching,
    required this.onCancelFetch,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.availableQualities,
    required this.availableLanguages,
    required this.availableTech,
    required this.activeQualityFilters,
    required this.activeLanguageFilters,
    required this.activeTechFilters,
    required this.onQualityFiltersChanged,
    required this.onLanguageFiltersChanged,
    required this.onTechFiltersChanged,
    this.episodeLabel,
    this.providerChips = const [],
    this.selectedSourceId,
    this.nuvioSelectedScraperIds = const {},
    this.chipsScrollController,
    this.onChipTap,
    this.onScrollBack,
    this.onScrollForward,
    this.showAudioFilters = false,
    this.activeAudioFilters = const {},
    this.onAudioFiltersChanged,
    this.availableSizeRanges = const {},
    this.activeSizeFilters = const {},
    this.onSizeFiltersChanged,
    this.sortPreference,
    this.onSortChanged,
    this.cacheRefreshToken,
    this.showCacheLine = false,
    /// Details: true. Player: false (no freeze-frame / no live video blur).
    this.filterEnableBlur = true,
  });

  final VoidCallback onClose;
  final String kindFilter;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final ValueChanged<String> onKindChanged;
  final int? resultCount;
  final bool isFetching;
  final VoidCallback onCancelFetch;
  final String? episodeLabel;
  final List<Map<String, dynamic>> providerChips;
  final String? selectedSourceId;
  final Set<String> nuvioSelectedScraperIds;
  final ScrollController? chipsScrollController;
  final ValueChanged<String>? onChipTap;
  final VoidCallback? onScrollBack;
  final VoidCallback? onScrollForward;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Set<String> availableQualities;
  final Set<String> availableLanguages;
  final Set<String> availableTech;
  final Set<String> activeQualityFilters;
  final Set<String> activeLanguageFilters;
  final Set<String> activeTechFilters;
  final ValueChanged<Set<String>> onQualityFiltersChanged;
  final ValueChanged<Set<String>> onLanguageFiltersChanged;
  final ValueChanged<Set<String>> onTechFiltersChanged;
  final bool showAudioFilters;
  final Set<String> activeAudioFilters;
  final ValueChanged<Set<String>>? onAudioFiltersChanged;
  final Set<String> availableSizeRanges;
  final Set<String> activeSizeFilters;
  final ValueChanged<Set<String>>? onSizeFiltersChanged;
  final String? sortPreference;
  final ValueChanged<String>? onSortChanged;
  final int? cacheRefreshToken;
  final bool showCacheLine;
  final bool filterEnableBlur;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleRow(
          resultCount: resultCount,
          episodeLabel: episodeLabel,
          isFetching: isFetching,
          onCancelFetch: onCancelFetch,
          onClose: onClose,
        ),
        SizedBox(height: gap),
        _KindChips(
          selected: kindFilter,
          showTorrents: showTorrents,
          showStremio: showStremio,
          showNuvio: showNuvio,
          onChanged: onKindChanged,
        ),
        if (providerChips.isNotEmpty &&
            chipsScrollController != null &&
            onChipTap != null &&
            selectedSourceId != null) ...[
          SizedBox(height: gap),
          TorrentSourceChips(
            chips: providerChips,
            selectedSourceId: selectedSourceId!,
            nuvioSelectedScraperIds: nuvioSelectedScraperIds,
            scrollController: chipsScrollController!,
            onChipTap: onChipTap!,
            onScrollBack: onScrollBack ?? () {},
            onScrollForward: onScrollForward ?? () {},
          ),
        ],
        SizedBox(height: gap),
        TorrentSourcePanelToolbar(
          searchQuery: searchQuery,
          onSearchChanged: onSearchChanged,
          availableQualities: availableQualities,
          availableLanguages: availableLanguages,
          availableTech: availableTech,
          activeQualityFilters: activeQualityFilters,
          activeLanguageFilters: activeLanguageFilters,
          activeTechFilters: activeTechFilters,
          onQualityFiltersChanged: onQualityFiltersChanged,
          onLanguageFiltersChanged: onLanguageFiltersChanged,
          onTechFiltersChanged: onTechFiltersChanged,
          showFilters: true,
          showAudioFilters: showAudioFilters,
          activeAudioFilters: activeAudioFilters,
          onAudioFiltersChanged: onAudioFiltersChanged,
          availableSizeRanges: availableSizeRanges,
          activeSizeFilters: activeSizeFilters,
          onSizeFiltersChanged: onSizeFiltersChanged,
          sortPreference: sortPreference,
          onSortChanged: onSortChanged,
          enableBlur: filterEnableBlur,
        ),
        if (showCacheLine && cacheRefreshToken != null) ...[
          const SizedBox(height: 4),
          TorrentCacheStorageLine(refreshToken: cacheRefreshToken!),
        ],
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.onClose,
    required this.isFetching,
    required this.onCancelFetch,
    this.resultCount,
    this.episodeLabel,
  });

  final VoidCallback onClose;
  final bool isFetching;
  final VoidCallback onCancelFetch;
  final int? resultCount;
  final String? episodeLabel;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                'Sources',
                style: TextStyle(
                  color: cinematic.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
              if (resultCount != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$resultCount',
                    style: TextStyle(
                      color: cinematic.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (episodeLabel != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    episodeLabel!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cinematic.textSecondary.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (isFetching) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ForjaShellColors.sectionAccent,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onCancelFetch,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: cinematic.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ForjaCloseButton(
          color: cinematic.textSecondary,
          onTap: onClose,
        ),
      ],
    );
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.selected,
    required this.showTorrents,
    required this.showStremio,
    required this.showNuvio,
    required this.onChanged,
  });

  final String selected;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <({String id, String label, Widget? icon})>[
      if (showTorrents && showStremio)
        (id: 'all', label: 'All', icon: null),
      if (showTorrents)
        (
          id: 'torrents',
          label: 'Torrents',
          icon: const HeroMagnetIcon(size: 13),
        ),
      if (showStremio)
        (
          id: 'stremio',
          label: 'Stremio',
          icon: Icon(
            Icons.extension_outlined,
            size: 13,
            color: selected == 'stremio'
                ? ForjaShellColors.cinematic.textPrimary
                : ForjaShellColors.cinematic.textSecondary,
          ),
        ),
      if (showNuvio)
        (
          id: 'nuvio',
          label: 'Nuvio',
          icon: Icon(
            Icons.code_rounded,
            size: 13,
            color: selected == 'nuvio'
                ? ForjaShellColors.cinematic.textPrimary
                : ForjaShellColors.cinematic.textSecondary,
          ),
        ),
    ];
    if (options.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _KindChip(
              label: options[i].label,
              icon: options[i].icon,
              selected: selected == options[i].id,
              onTap: () => onChanged(options[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? ForjaShellColors.chipSelectedBg
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(
                  size: 13,
                  color: selected ? cinematic.textPrimary : cinematic.textSecondary,
                ),
                child: icon!,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? cinematic.textPrimary : cinematic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
