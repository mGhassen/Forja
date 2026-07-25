import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Compact top chrome for the Sources panel:
/// title + count · kind tabs · provider chips · search/filters.
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
    this.providerOptions = const [],
    this.selectedSourceId,
    this.nuvioSelectedScraperIds = const {},
    this.onProviderTap,
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
    /// Force-refetch the selected kind (`torrents` | `stremio` | `nuvio`).
    this.onReloadKind,
    /// When false after being true, dismisses Filters if open.
    this.sourcesPanelOpen = false,
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
  final ValueChanged<String>? onReloadKind;
  final String? episodeLabel;
  final List<SourcesPanelProviderOption> providerOptions;
  final String? selectedSourceId;
  final Set<String> nuvioSelectedScraperIds;
  final ValueChanged<String>? onProviderTap;
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
  final bool sourcesPanelOpen;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    final showProviders =
        providerOptions.isNotEmpty && onProviderTap != null;

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
        _KindTabs(
          selected: kindFilter,
          showTorrents: showTorrents,
          showStremio: showStremio,
          showNuvio: showNuvio,
          onChanged: onKindChanged,
          onReloadKind: isFetching ? null : onReloadKind,
        ),
        if (showProviders) ...[
          SizedBox(height: gap),
          TorrentSourceChips(
            options: providerOptions,
            selectedSourceId: selectedSourceId ?? '',
            nuvioSelectedScraperIds: nuvioSelectedScraperIds,
            onChipTap: onProviderTap!,
          ),
        ],
        SizedBox(height: gap),
        TorrentSourceSearchToolbar(
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
          sourcesPanelOpen: sourcesPanelOpen,
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
                _SourcesCancelChip(onCancel: onCancelFetch),
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

class _KindTabs extends StatelessWidget {
  const _KindTabs({
    required this.selected,
    required this.showTorrents,
    required this.showStremio,
    required this.showNuvio,
    required this.onChanged,
    this.onReloadKind,
  });

  final String selected;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onReloadKind;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final options = <({String id, String label, IconData? iconData, Widget? icon})>[
      if (showTorrents)
        (
          id: 'torrents',
          label: 'Torrents',
          iconData: null,
          icon: const HeroMagnetIcon(size: 14),
        ),
      if (showStremio)
        (
          id: 'stremio',
          label: 'Stremio',
          iconData: Icons.extension_outlined,
          icon: null,
        ),
      if (showNuvio)
        (
          id: 'nuvio',
          label: 'Nuvio',
          iconData: Icons.code_rounded,
          icon: null,
        ),
    ];
    if (options.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cinematic.borderSubtle.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              _KindTab(
                label: options[i].label,
                icon: options[i].icon,
                iconData: options[i].iconData,
                selected: selected == options[i].id,
                tvItemIndex: i,
                onTap: () => onChanged(options[i].id),
                // Reload only the opened kind - never prefetch a hidden category.
                onReload: onReloadKind == null || selected != options[i].id
                    ? null
                    : () => onReloadKind!(options[i].id),
              ),
          ],
        ),
      ),
    );
  }
}

class _KindTab extends StatefulWidget {
  const _KindTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tvItemIndex,
    this.icon,
    this.iconData,
    this.onReload,
  });

  final String label;
  final Widget? icon;
  final IconData? iconData;
  final bool selected;
  final int tvItemIndex;
  final VoidCallback onTap;
  final VoidCallback? onReload;

  @override
  State<_KindTab> createState() => _KindTabState();
}

class _KindTabState extends State<_KindTab> {
  bool _hovered = false;
  bool _focused = false;
  bool _reloadHovered = false;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final selected = widget.selected;
    final emphasize = selected || _hovered || _focused;
    final color = selected
        ? cinematic.textPrimary
        : (_hovered || _focused
            ? cinematic.textPrimary.withValues(alpha: 0.88)
            : cinematic.textSecondary);
    final indicatorColor = selected
        ? ForjaShellColors.sectionAccent
        : (_hovered || _focused
            ? cinematic.textSecondary.withValues(alpha: 0.55)
            : Colors.transparent);

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      transform: Matrix4.translationValues(
        0,
        (_hovered || _focused) && !selected ? -0.5 : 0,
        0,
      ),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: indicatorColor,
            width: selected ? 2.0 : 1.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: selected ? -0.1 : 0,
            color: color,
            height: 1.1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null || widget.iconData != null) ...[
                AnimatedScale(
                  scale: emphasize ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: IconTheme(
                    data: IconThemeData(size: 14, color: color),
                    child: widget.icon ??
                        Icon(widget.iconData, size: 14, color: color),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(widget.label),
              if (widget.onReload != null) ...[
                const SizedBox(width: 8),
                // Reload stays pointer-only on TV - Kind tab OK switches kinds.
                ExcludeFocus(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _reloadHovered = true),
                    onExit: (_) => setState(() => _reloadHovered = false),
                    child: GestureDetector(
                      onTap: widget.onReload,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedOpacity(
                        opacity: _hovered || selected || _focused ? 1 : 0.7,
                        duration: const Duration(milliseconds: 160),
                        child: AnimatedRotation(
                          turns: _reloadHovered ? 0.5 : 0,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _reloadHovered = false;
      }),
      cursor: SystemMouseCursors.click,
      child: shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 8,
        scaleOnFocus: 1.0,
        listIndex: widget.tvItemIndex,
        tvRowId: 'sources-kind',
        tvItemIndex: widget.tvItemIndex,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: face,
      ),
    );
  }
}

class _SourcesCancelChip extends StatefulWidget {
  const _SourcesCancelChip({required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<_SourcesCancelChip> createState() => _SourcesCancelChipState();
}

class _SourcesCancelChipState extends State<_SourcesCancelChip> {
  final FocusNode _focus = FocusNode(debugLabel: 'sources-cancel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_focus.canRequestFocus) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final label = Text(
      'Cancel',
      style: TextStyle(
        color: cinematic.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
      return GestureDetector(onTap: widget.onCancel, child: label);
    }
    return shellFocusableTap(
      context: context,
      onTap: widget.onCancel,
      focusNode: _focus,
      borderRadius: 8,
      scaleOnFocus: ShellTokens.focusActiveScale,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      tvRowId: 'sources-cancel',
      tvItemIndex: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: label,
      ),
    );
  }
}
