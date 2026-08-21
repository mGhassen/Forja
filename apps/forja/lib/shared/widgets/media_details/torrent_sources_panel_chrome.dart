import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

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
    this.loadingChipIds = const {},
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

    /// Forja tab: soft category filter (Movie / TV / Anime / Drama).
    this.showEngineCategories = false,
    this.engineVisibleCategories = const {},
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
  final Set<String> loadingChipIds;
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
  final bool showEngineCategories;
  final Set<String> engineVisibleCategories;
  final String? engineCategoryMediaType;
  final ValueChanged<Set<String>>? onEngineCategoriesChanged;
  final bool filterEnableBlur;
  final bool sourcesPanelOpen;
  final VoidCallback? onFocusList;
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
    if (widget.showTorrents) n++;
    if (widget.showStremio) n++;
    if (widget.showNuvio) n++;
    if (widget.showEngine) n++;
    return n;
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
    if (widget.sourcesPanelOpen &&
        _tv &&
        (widget.resultCount ?? 0) > 0 &&
        (oldWidget.resultCount ?? 0) == 0 &&
        !SourcesPanelTv.hasItemFocus &&
        !_searchFocus.hasFocus &&
        !_filtersFocus.hasFocus) {
      _claimPanelFocus();
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
    final count = widget.resultCount ?? 0;
    if (count > 0 && widget.onFocusList != null) {
      widget.onFocusList!();
      return;
    }
    SourcesPanelTv.claimFocus(
      search: _searchFocus,
      filters: _filtersFocus,
    );
  }

  void _focusList() {
    widget.onFocusList?.call();
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
    SourcesPanelTv.focusKindItem();
  }

  void _focusSearchFromProviders() {
    if (_searchFocus.canRequestFocus) {
      _searchFocus.requestFocus();
      return;
    }
    _focusList();
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;

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

    kind = Padding(
      padding: EdgeInsets.only(top: _tv ? 16 : 0),
      child: kind,
    );

    if (_tv && _kindCount > 0) {
      kind = TvCatalogRow(
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
        loadingChipIds: widget.loadingChipIds,
        onChipTap: widget.onProviderTap!,
        tvTabId: _tv ? SourcesPanelTv.tabId : null,
        tvRowId: _tv ? SourcesPanelTv.providersRowId : null,
      );
      if (_tv) {
        providers = TvCatalogRow(
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
        if (providers != null) ...[SizedBox(height: gap), providers],
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
          engineCategoryMediaType: widget.engineCategoryMediaType,
          onEngineCategoriesChanged: widget.onEngineCategoriesChanged,
          searchFocusNode: _tv ? _searchFocus : null,
          filtersFocusNode: _tv ? _filtersFocus : null,
          onSearchUpEdge: _tv
              ? () {
                  if (_showProviders) {
                    SourcesPanelTv.focusProvidersItem();
                  } else {
                    SourcesPanelTv.focusKindItem();
                  }
                }
              : null,
          onSearchDownEdge: _tv ? _focusList : null,
          onFiltersUpEdge: _tv
              ? () {
                  if (_searchFocus.canRequestFocus) {
                    _searchFocus.requestFocus();
                  } else if (_showProviders) {
                    SourcesPanelTv.focusProvidersItem();
                  } else {
                    SourcesPanelTv.focusKindItem();
                  }
                }
              : null,
          onFiltersDownEdge: _tv ? _focusList : null,
        ),
        if (widget.showCacheLine && widget.cacheRefreshToken != null) ...[
          const SizedBox(height: 4),
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
  static const _tvReloadHoldDelay = Duration(seconds: 1);

  bool _hovered = false;
  bool _focused = false;
  bool _reloadHovered = false;
  bool _busyHovered = false;
  bool _okHoldFired = false;
  Timer? _okHoldTimer;

  void _cancelOkHold({bool clearSpin = true, bool clearFired = true}) {
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    if (clearFired) _okHoldFired = false;
    if (clearSpin && _reloadHovered && mounted) {
      setState(() => _reloadHovered = false);
    }
  }

  KeyEventResult _onTvKey(FocusNode node, KeyEvent event) {
    if (shellTvIsActivateKey(event)) {
      if (widget.onReload == null) return KeyEventResult.ignored;
      _okHoldFired = false;
      _okHoldTimer?.cancel();
      setState(() => _reloadHovered = true);
      _okHoldTimer = Timer(_tvReloadHoldDelay, () {
        if (!mounted || !_focused) return;
        _okHoldFired = true;
        widget.onReload?.call();
      });
      return KeyEventResult.handled;
    }
    if (shellTvIsActivateKeyUp(event)) {
      if (_okHoldTimer == null && !_okHoldFired) {
        return KeyEventResult.ignored;
      }
      final held = _okHoldFired;
      _cancelOkHold();
      if (!held) widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant _KindTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onReload == null) {
      _okHoldTimer?.cancel();
      _okHoldTimer = null;
    }
  }

  @override
  void dispose() {
    _okHoldTimer?.cancel();
    super.dispose();
  }

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
        ? ForjaShellColors.brandGreen
        : (_hovered || _focused
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
              : Colors.transparent);

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        14,
        SourcesPanelTv.isTv(context) ? 8 : 0,
        14,
        0,
      ),
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
                    child:
                        widget.icon ??
                        Icon(widget.iconData, size: 14, color: color),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(widget.label),
              if (widget.loading) ...[
                const SizedBox(width: 4),
                _KindTabBusyGlyph(
                  color: color,
                  hovered: _busyHovered,
                  onHover: (v) => setState(() => _busyHovered = v),
                  onCancel: widget.onCancel,
                ),
              ],
              if (widget.onReload != null) ...[
                const SizedBox(width: 8),
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
        _busyHovered = false;
      }),
      cursor: SystemMouseCursors.click,
      child: shellFocusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: 0,
        scaleOnFocus: 1.0,
        suppressInkHover: true,
        listIndex: widget.tvItemIndex,
        tvTabId: SourcesPanelTv.tabId,
        tvRowId: SourcesPanelTv.kindRowId,
        tvItemIndex: widget.tvItemIndex,
        onKeyEvent: widget.onReload == null ? null : _onTvKey,
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          if (!focused) _cancelOkHold();
        },
        child: face,
      ),
    );
  }
}

class _KindTabBusyGlyph extends StatelessWidget {
  const _KindTabBusyGlyph({
    required this.color,
    required this.hovered,
    required this.onHover,
    this.onCancel,
  });

  final Color color;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final showCancel = hovered && onCancel != null;
    return ExcludeFocus(
      child: MouseRegion(
        cursor: onCancel == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: onCancel,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 18,
            height: 16,
            child: Center(
              child: showCancel
                  ? Icon(Icons.close_rounded, size: 14, color: color)
                  : ForjaLoadingDots(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
