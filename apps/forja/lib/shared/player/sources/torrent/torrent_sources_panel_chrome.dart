import 'package:flutter/material.dart';

import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/hero_pill_buttons.dart';
import 'package:forja/shared/engine/details/sources_panel_tv.dart';
import 'package:forja/shared/player/sources/torrent/torrent_source_filters.dart';
import 'package:forja_foundation/widgets/feedback/loading_dots.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
/// Compact top chrome for the Sources panel:
/// kind tabs · provider chips · search/filters.
/// Episode/count live in [SourcesPanelMetaFooter], not here.
class TorrentSourcesPanelChrome extends StatefulWidget {
  const TorrentSourcesPanelChrome({
    super.key,
    required this.kindFilter,
    required this.showTorrents,
    required this.showStremio,
    required this.showNuvio,
    this.showEngine = false,
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
    this.providerOptions = const [],
    this.selectedSourceId,
    this.nuvioSelectedScraperIds = const {},
    this.engineSelectedPluginIds = const {},
    this.nuvioAllMode,
    this.engineAllMode,
    this.nuvioViewFilterScraperIds = const {},
    this.engineViewFilterPluginIds = const {},
    this.torrentViewFilterProviderIds = const {},
    this.loadingChipIds = const {},
    this.onProviderTap,
    this.onProviderCancel,
    this.onProviderReload,
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

    /// Forja tab: soft category filter (Movie / TV / Anime / Drama).
    this.showEngineCategories = false,
    this.engineVisibleCategories = const {},
    this.engineCategoryOptions = const [],
    this.engineCategoryMediaType,
    this.onEngineCategoriesChanged,

    /// Details: true. Player: false (no freeze-frame / no live video blur).
    this.filterEnableBlur = true,

    /// Force-refetch the selected kind (`torrents` | `stremio` | `nuvio`).
    this.onReloadKind,

    /// When false after being true, dismisses Filters if open.
    this.sourcesPanelOpen = false,

    /// TV: ↓ from search/filters → source list (parent owns list graph).
    this.onFocusList,

    /// TV: parent registers ↑ from the list (search → providers → kind).
    this.onProvideListFocusUp,

    /// TV: claim initial focus when the panel opens (parent may also call).
    this.claimInitialFocus = true,
  });

  final String kindFilter;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final bool showEngine;
  final ValueChanged<String> onKindChanged;
  final int? resultCount;
  final bool isFetching;
  final VoidCallback onCancelFetch;
  final ValueChanged<String>? onReloadKind;
  final List<SourcesPanelProviderOption> providerOptions;
  final String? selectedSourceId;
  final Set<String> nuvioSelectedScraperIds;
  final Set<String> engineSelectedPluginIds;
  final bool? nuvioAllMode;
  final bool? engineAllMode;
  final Set<String> nuvioViewFilterScraperIds;
  final Set<String> engineViewFilterPluginIds;
  final Set<String> torrentViewFilterProviderIds;
  final Set<String> loadingChipIds;
  final ValueChanged<String>? onProviderTap;
  final ValueChanged<String>? onProviderCancel;
  final ValueChanged<String>? onProviderReload;
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
  final bool showEngineCategories;
  final Set<String> engineVisibleCategories;
  final List<String> engineCategoryOptions;
  final String? engineCategoryMediaType;
  final ValueChanged<Set<String>>? onEngineCategoriesChanged;
  final bool filterEnableBlur;
  final bool sourcesPanelOpen;
  final VoidCallback? onFocusList;
  final void Function(VoidCallback focusUp)? onProvideListFocusUp;
  final bool claimInitialFocus;

  @override
  State<TorrentSourcesPanelChrome> createState() =>
      _TorrentSourcesPanelChromeState();
}

class _TorrentSourcesPanelChromeState extends State<TorrentSourcesPanelChrome> {
  final FocusNode _searchFocus = FocusNode(debugLabel: 'sources-search');
  final FocusNode _filtersFocus = FocusNode(debugLabel: 'sources-filters');
  bool _didInitialFocus = false;

  bool get _tv => SourcesPanelTv.isTv(context);

  bool get _showProviders =>
      widget.providerOptions.isNotEmpty && widget.onProviderTap != null;

  int get _kindCount {
    var n = 0;
    if (widget.showEngine) n++;
    if (widget.showTorrents) n++;
    if (widget.showStremio) n++;
    if (widget.showNuvio) n++;
    return n;
  }

  /// Index in [_KindTabs] paint order (Forja → Torrents → Stremio → Nuvio).
  int get _selectedKindIndex {
    var i = 0;
    if (widget.showEngine) {
      if (widget.kindFilter == 'engine') return i;
      i++;
    }
    if (widget.showTorrents) {
      if (widget.kindFilter == 'torrents') return i;
      i++;
    }
    if (widget.showStremio) {
      if (widget.kindFilter == 'stremio') return i;
      i++;
    }
    if (widget.showNuvio) {
      if (widget.kindFilter == 'nuvio') return i;
      i++;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.sourcesPanelOpen) {
      _scheduleInitialFocus();
    }
  }

  @override
  void didUpdateWidget(covariant TorrentSourcesPanelChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourcesPanelOpen && !oldWidget.sourcesPanelOpen) {
      _didInitialFocus = false;
      _scheduleInitialFocus();
    }
    if (!widget.sourcesPanelOpen) {
      _didInitialFocus = false;
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _filtersFocus.dispose();
    super.dispose();
  }

  void _scheduleInitialFocus() {
    if (!widget.claimInitialFocus || _didInitialFocus) return;
    _didInitialFocus = true;
    // initState cannot dependOn ShellScope (_tv). Kind/list nodes also
    // register in their own initState after this chrome — wait a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _claimPanelFocus();
    });
  }

  void _claimPanelFocus() {
    if (!mounted || !_tv || !widget.sourcesPanelOpen) return;
    // Open lands on the selected kind tab (Forja first when that kind is on).
    // ↓ from search / providers still uses [onFocusList] via [_focusList].
    SourcesPanelTv.focusKindItem(index: _selectedKindIndex);
  }

  void _focusList() {
    if (widget.onFocusList != null) {
      widget.onFocusList!();
      return;
    }
    SourcesPanelTv.focusListItem();
  }

  void _focusProvidersOrSearchOrList() {
    if (_showProviders) {
      SourcesPanelTv.focusProvidersItem();
      return;
    }
    if (_searchFocus.canRequestFocus) {
      _searchFocus.requestFocus();
      return;
    }
    _focusList();
  }

  void _focusKindOrClose() {
    SourcesPanelTv.focusKindItem(index: _selectedKindIndex);
  }

  void _focusSearchFromProviders() {
    if (_searchFocus.canRequestFocus) {
      _searchFocus.requestFocus();
      return;
    }
    _focusList();
  }

  /// ↑ from the stream list — search sits between providers and the list.
  void _focusSearchOrProvidersFromList() {
    if (_searchFocus.canRequestFocus) {
      _searchFocus.requestFocus();
      return;
    }
    if (_showProviders) {
      SourcesPanelTv.focusProvidersItem();
      return;
    }
    _focusKindOrClose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final gap = metrics.usesTvDensity
        ? ShellTokens.torrentPanelChromeGapTv
        : ShellTokens.torrentPanelChromeGapDesktop;
    final providersTopGap = metrics.usesTvDensity
        ? ShellTokens.torrentPanelProvidersTopGapTv
        : ShellTokens.torrentPanelProvidersTopGapDesktop;
    widget.onProvideListFocusUp?.call(_focusSearchOrProvidersFromList);

    // No extra top inset — panel padding owns the edge; a TV-only pad left a
    // dead band above Forja / kind tabs.
    Widget kind = _KindTabs(
      selected: widget.kindFilter,
      showTorrents: widget.showTorrents,
      showStremio: widget.showStremio,
      showNuvio: widget.showNuvio,
      showEngine: widget.showEngine,
      onChanged: widget.onKindChanged,
      isFetching: widget.isFetching,
      onReloadKind: widget.isFetching ? null : widget.onReloadKind,
      onCancelFetch: widget.isFetching ? widget.onCancelFetch : null,
    );

    if (_tv && _kindCount > 0) {
      kind = TvKitRow(
        tabId: SourcesPanelTv.tabId,
        rowId: SourcesPanelTv.kindRowId,
        sortOrder: SourcesPanelTv.kindSort,
        itemCount: _kindCount,
        onFocusDown: _focusProvidersOrSearchOrList,
        child: kind,
      );
    }

    Widget? providers;
    if (_showProviders) {
      providers = TorrentSourceChips(
        options: widget.providerOptions,
        selectedSourceId: widget.selectedSourceId ?? '',
        nuvioSelectedScraperIds: widget.nuvioSelectedScraperIds,
        engineSelectedPluginIds: widget.engineSelectedPluginIds,
        nuvioAllMode: widget.nuvioAllMode,
        engineAllMode: widget.engineAllMode,
        nuvioViewFilterScraperIds: widget.nuvioViewFilterScraperIds,
        engineViewFilterPluginIds: widget.engineViewFilterPluginIds,
        torrentViewFilterProviderIds: widget.torrentViewFilterProviderIds,
        loadingChipIds: widget.loadingChipIds,
        onChipTap: widget.onProviderTap!,
        onChipCancel: widget.onProviderCancel,
        onChipReload: widget.onProviderReload,
        tvTabId: _tv ? SourcesPanelTv.tabId : null,
        tvRowId: _tv ? SourcesPanelTv.providersRowId : null,
      );
      if (_tv) {
        providers = TvKitRow(
          tabId: SourcesPanelTv.tabId,
          rowId: SourcesPanelTv.providersRowId,
          sortOrder: SourcesPanelTv.providersSort,
          itemCount: widget.providerOptions.length,
          onFocusUp: _focusKindOrClose,
          onFocusDown: _focusSearchFromProviders,
          child: providers,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kind,
        if (providers != null) ...[
          SizedBox(height: providersTopGap),
          providers,
        ],
        SizedBox(height: gap),
        TorrentSourceSearchToolbar(
          searchQuery: widget.searchQuery,
          onSearchChanged: widget.onSearchChanged,
          availableQualities: widget.availableQualities,
          availableLanguages: widget.availableLanguages,
          availableTech: widget.availableTech,
          activeQualityFilters: widget.activeQualityFilters,
          activeLanguageFilters: widget.activeLanguageFilters,
          activeTechFilters: widget.activeTechFilters,
          onQualityFiltersChanged: widget.onQualityFiltersChanged,
          onLanguageFiltersChanged: widget.onLanguageFiltersChanged,
          onTechFiltersChanged: widget.onTechFiltersChanged,
          showFilters: true,
          showAudioFilters: widget.showAudioFilters,
          activeAudioFilters: widget.activeAudioFilters,
          onAudioFiltersChanged: widget.onAudioFiltersChanged,
          availableSizeRanges: widget.availableSizeRanges,
          activeSizeFilters: widget.activeSizeFilters,
          onSizeFiltersChanged: widget.onSizeFiltersChanged,
          sortPreference: widget.sortPreference,
          onSortChanged: widget.onSortChanged,
          enableBlur: widget.filterEnableBlur,
          sourcesPanelOpen: widget.sourcesPanelOpen,
          showEngineCategories: widget.showEngineCategories,
          engineVisibleCategories: widget.engineVisibleCategories,
          engineCategoryOptions: widget.engineCategoryOptions,
          engineCategoryMediaType: widget.engineCategoryMediaType,
          onEngineCategoriesChanged: widget.onEngineCategoriesChanged,
          searchFocusNode: _tv ? _searchFocus : null,
          filtersFocusNode: _tv ? _filtersFocus : null,
          onSearchUpEdge: _tv
              ? () {
                  if (_showProviders) {
                    SourcesPanelTv.focusProvidersItem();
                  } else {
                    SourcesPanelTv.focusKindItem(index: _selectedKindIndex);
                  }
                }
              : null,
          onSearchDownEdge: _tv ? _focusList : null,
          onSearchRightEdge: _tv
              ? () {
                  if (_filtersFocus.canRequestFocus) {
                    _filtersFocus.requestFocus();
                  }
                }
              : null,
          onFiltersUpEdge: _tv
              ? () {
                  if (_searchFocus.canRequestFocus) {
                    _searchFocus.requestFocus();
                  } else if (_showProviders) {
                    SourcesPanelTv.focusProvidersItem();
                  } else {
                    SourcesPanelTv.focusKindItem(index: _selectedKindIndex);
                  }
                }
              : null,
          onFiltersDownEdge: _tv ? _focusList : null,
        ),
        SizedBox(height: gap * 0.5),
        if (widget.showCacheLine && widget.cacheRefreshToken != null) ...[
          SizedBox(height: gap * 0.5),
          TorrentCacheStorageLine(refreshToken: widget.cacheRefreshToken!),
        ],
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
    this.showEngine = false,
    required this.onChanged,
    this.isFetching = false,
    this.onReloadKind,
    this.onCancelFetch,
  });

  final String selected;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final bool showEngine;
  final ValueChanged<String> onChanged;
  final bool isFetching;
  final ValueChanged<String>? onReloadKind;
  final VoidCallback? onCancelFetch;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final magnetSize = ShellScope.metricsOf(context).torrentPanelMetaIconSize;
    final options =
        <({String id, String label, IconData? iconData, Widget? icon})>[
          if (showEngine)
            (
              id: 'engine',
              label: 'Forja',
              iconData: Icons.bolt_rounded,
              icon: null,
            ),
          if (showTorrents)
            (
              id: 'torrents',
              label: 'Torrents',
              iconData: null,
              icon: HeroMagnetIcon(size: magnetSize),
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
      child: DesktopSwipeBackIgnore(
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
                  loading: isFetching && selected == options[i].id,
                  tvItemIndex: i,
                  onTap: () => onChanged(options[i].id),
                  onReload: onReloadKind == null || selected != options[i].id
                      ? null
                      : () => onReloadKind!(options[i].id),
                  onCancel: onCancelFetch == null || selected != options[i].id
                      ? null
                      : onCancelFetch,
                ),
            ],
          ),
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
    this.loading = false,
    this.icon,
    this.iconData,
    this.onReload,
    this.onCancel,
  });

  final String label;
  final Widget? icon;
  final IconData? iconData;
  final bool selected;
  final bool loading;
  final int tvItemIndex;
  final VoidCallback onTap;
  final VoidCallback? onReload;
  final VoidCallback? onCancel;

  @override
  State<_KindTab> createState() => _KindTabState();
}

class _KindTabState extends State<_KindTab> {
  final _tabFocus = FocusNode(debugLabel: 'sources-kind-tab');
  final _reloadFocus = FocusNode(debugLabel: 'sources-kind-reload');

  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  final ValueNotifier<bool> _reloadHoveredN = ValueNotifier(false);
  final ValueNotifier<bool> _busyHoveredN = ValueNotifier(false);
  bool _focused = false;
  bool _reloadFocused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    _reloadHoveredN.dispose();
    _busyHoveredN.dispose();
    _tabFocus.dispose();
    _reloadFocus.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hoveredN.value == hovered) return;
    _hoveredN.value = hovered;
    if (!hovered) {
      _setReloadHovered(false);
      _setBusyHovered(false);
    }
  }

  void _setReloadHovered(bool hovered) {
    if (_reloadHoveredN.value == hovered) return;
    _reloadHoveredN.value = hovered;
  }

  void _setBusyHovered(bool hovered) {
    if (_busyHoveredN.value == hovered) return;
    _busyHoveredN.value = hovered;
  }

  Widget _buildTabFace(
    bool hovered,
    bool reloadHovered,
    bool busyHovered, {
    required bool showReload,
  }) {
    final metrics = ShellScope.metricsOf(context);
    final cinematic = ForjaShellColors.cinematic;
    final selected = widget.selected;
    final policy = ShellScope.inputPolicyOf(context);
    final tv = SourcesPanelTv.isTv(context);
    // Tab label greens only when the tab itself is focused — not the reload.
    final tabFocusStyled = policy.focusStyled(context, focused: _focused);
    final emphasize = selected || hovered || tabFocusStyled || _reloadFocused;
    final color = _reloadFocused
        ? cinematic.textPrimary
        : (hovered || tabFocusStyled)
            ? ForjaShellColors.brandGreen
            : (selected ? cinematic.textPrimary : cinematic.textSecondary);
    final indicatorColor = selected
        ? ForjaShellColors.brandGreen
        : (hovered || tabFocusStyled || _reloadFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
              : Colors.transparent);
    final tabFont = metrics.torrentPanelRowTitleFontSize;
    final tabIcon = metrics.torrentPanelMetaIconSize;
    final bottomPad = tv
        ? ShellTokens.torrentPanelKindTabPadBottomTv
        : ShellTokens.torrentPanelKindTabPadBottomDesktop;
    final tabPadH = tv
        ? ShellTokens.torrentPanelKindTabPadHTv
        : ShellTokens.torrentPanelKindTabPadHDesktop;
    final iconGap = tv
        ? ShellTokens.torrentPanelKindTabIconGapTv
        : ShellTokens.torrentPanelKindTabIconGapDesktop;

    final label = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      style: TextStyle(
        fontSize: tabFont,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: selected ? -0.1 : 0,
        color: color,
        height: 1.0,
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
                data: IconThemeData(size: tabIcon, color: color),
                child:
                    widget.icon ??
                    Icon(widget.iconData, size: tabIcon, color: color),
              ),
            ),
            SizedBox(width: iconGap),
          ],
          Text(widget.label),
          if (widget.loading) ...[
            const SizedBox(width: 4),
            ForjaBusyCancelGlyph(
              color: color,
              size: tabFont,
              hovered: busyHovered,
              onHover: _setBusyHovered,
              onCancel: widget.onCancel,
            ),
          ],
        ],
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        tabPadH,
        0,
        showReload ? 6 : tabPadH,
        0,
      ),
      transform: Matrix4.translationValues(
        0,
        (hovered || tabFocusStyled || _reloadFocused) && !selected ? -0.5 : 0,
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
        padding: EdgeInsets.only(bottom: bottomPad),
        child: label,
      ),
    );
  }

  Widget _buildReloadBtn(
    bool hovered,
    bool reloadHovered, {
    required bool tv,
    required bool showReload,
  }) {
    if (!showReload) return const SizedBox.shrink();
    final cinematic = ForjaShellColors.cinematic;
    final selected = widget.selected;
    final indicatorColor = selected
        ? ForjaShellColors.brandGreen
        : (hovered || _focused || _reloadFocused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
              : Colors.transparent);
    // Reload greens only when it owns focus/hover — idle next to a focused tab
    // stays muted so the label alone reads as the focus target.
    final reloadColor = (_reloadFocused || reloadHovered)
        ? ForjaShellColors.brandGreen
        : cinematic.textSecondary;
    final reloadIconSize = ShellScope.metricsOf(context).torrentPanelMetaIconSize;
    final bottomPad = tv
        ? ShellTokens.torrentPanelKindTabPadBottomTv
        : ShellTokens.torrentPanelKindTabPadBottomDesktop;

    final reloadIcon = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(2, 0, tv ? 8 : 12, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: indicatorColor,
            width: selected ? 2.0 : 1.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setReloadHovered(true),
          onExit: (_) => _setReloadHovered(false),
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 160),
            child: AnimatedRotation(
              turns: reloadHovered || _reloadFocused ? 0.5 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.refresh_rounded,
                size: reloadIconSize,
                color: reloadColor,
              ),
            ),
          ),
        ),
      ),
    );
    if (!tv) {
      return GestureDetector(
        onTap: widget.onReload,
        behavior: HitTestBehavior.opaque,
        child: reloadIcon,
      );
    }
    return shellFocusableTap(
      context: context,
      focusNode: _reloadFocus,
      onTap: widget.onReload,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      showFocusBorder: false,
      onLeftEdge: () => _tabFocus.requestFocus(),
      onFocusChange: (focused) => setState(() => _reloadFocused = focused),
      child: reloadIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = SourcesPanelTv.isTv(context);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _hoveredN,
          _reloadHoveredN,
          _busyHoveredN,
        ]),
        builder: (context, _) {
          final hovered = _hoveredN.value;
          final reloadHovered = _reloadHoveredN.value;
          final busyHovered = _busyHoveredN.value;
          final showReload = widget.onReload != null &&
              (hovered || _focused || _reloadFocused || reloadHovered);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              shellFocusableTap(
                context: context,
                focusNode: _tabFocus,
                onTap: widget.onTap,
                borderRadius: 0,
                scaleOnFocus: 1.0,
                suppressInkHover: true,
                listIndex: widget.tvItemIndex,
                tvTabId: SourcesPanelTv.tabId,
                tvRowId: SourcesPanelTv.kindRowId,
                tvItemIndex: widget.tvItemIndex,
                onRightEdge: !tv || !showReload
                    ? null
                    : () => _reloadFocus.requestFocus(),
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: _buildTabFace(
                  hovered,
                  reloadHovered,
                  busyHovered,
                  showReload: showReload,
                ),
              ),
              _buildReloadBtn(
                hovered,
                reloadHovered,
                tv: tv,
                showReload: showReload,
              ),
            ],
          );
        },
      ),
    );
  }
}
