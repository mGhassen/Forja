import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/engine/details/sources_panel_tv.dart';
import 'package:forja/shared/utils/torrent_meta_parser.dart';
import 'package:forja/shared/player/sources/torrent/torrent_sources_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
/// How many Nuvio provider chips count as an active Filters badge.
///
/// All selected (or none) is the default / empty state - badge stays clear.
/// A partial selection counts as filtered.
int nuvioProviderFilterActiveCount({
  required int selectedCount,
  required int totalEnabled,
}) {
  if (totalEnabled <= 0) return 0;
  if (selectedCount <= 0 || selectedCount >= totalEnabled) return 0;
  return selectedCount;
}

/// Picks a Stremio provider chip id that actually has streams.
///
/// Returns `null` when [currentId] should stay (preferred still loading,
/// current already has results, or the user explicitly tapped a chip).
/// Callers apply the returned id.
///
/// When the default/first addon (e.g. Torrentio) 403s and another addon (e.g.
/// YTS) returns rows, this moves the selection off the empty provider so the
/// list is not stuck blank while other addons succeeded — but only for
/// automatic selection. A manual chip tap must stick (empty state OK).
String? promoteStremioProviderId({
  required String currentId,
  String? preferredId,
  required List<String> addonBaseUrlsInOrder,
  required Set<String> loadedIds,
  required Set<String> completedIds,
  required bool fetching,
  required bool userPicked,
}) {
  // Explicit chip tap always wins — never steal focus from empty addons.
  if (userPicked) return null;
  if (!userPicked && currentId.isEmpty) return null;
  if (preferredId != null && preferredId.isNotEmpty) {
    if (loadedIds.contains(preferredId)) {
      return preferredId == currentId ? null : preferredId;
    }
    // Keep waiting only while that addon has not finished yet.
    if (fetching && !completedIds.contains(preferredId)) return null;
  }
  if (loadedIds.contains(currentId)) return null;
  for (final id in addonBaseUrlsInOrder) {
    if (loadedIds.contains(id)) return id;
  }
  return null;
}

/// Provider / addon / scraper chip for the Sources panel (under kind tabs).
class SourcesPanelProviderOption {
  const SourcesPanelProviderOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Torrents tab chips: All + Settings-enabled builtins + Jackett/Prowlarr.
List<SourcesPanelProviderOption> torrentProviderChipOptions({
  required Iterable<String> enabledProviders,
  required bool jackettConfigured,
  required bool prowlarrConfigured,
}) {
  final enabled = enabledProviders.toSet();
  return [
    const SourcesPanelProviderOption(
      id: TorrentSearchProviders.allId,
      label: 'All',
    ),
    for (final id in TorrentSearchProviders.all)
      if (enabled.contains(id))
        SourcesPanelProviderOption(
          id: id,
          label: TorrentSearchProviders.label(id),
        ),
    if (jackettConfigured)
      const SourcesPanelProviderOption(id: 'jackett', label: 'Jackett'),
    if (prowlarrConfigured)
      const SourcesPanelProviderOption(id: 'prowlarr', label: 'Prowlarr'),
  ];
}

/// Torrents chip selected chrome — All group vs provider group.
bool torrentProviderChipSelected({
  required String optionId,
  required String selectedSourceId,
  Set<String> viewFilterProviderIds = const {},
}) {
  if (TorrentSearchProviders.isNoneChip(selectedSourceId)) return false;
  final allOn = TorrentSearchProviders.isAllChip(selectedSourceId);
  if (optionId == TorrentSearchProviders.allId) return allOn;
  if (allOn) return viewFilterProviderIds.contains(optionId);
  return selectedSourceId == optionId;
}

bool sourcesPanelOptionIsAllChip(String optionId) =>
    optionId == TorrentSearchProviders.allId ||
    optionId == 'all_nuvio' ||
    optionId == EngineIds.allChip;

/// True when [optionId] is an individual provider used as an All-mode list filter
/// (tap toggles view filter — must not long-press reload).
bool sourcesPanelChipIsViewFilterSelection({
  required String optionId,
  required String selectedSourceId,
  bool nuvioAllMode = false,
  bool engineAllMode = false,
}) {
  if (sourcesPanelOptionIsAllChip(optionId)) return false;
  if (optionId.startsWith('nuvio:') && nuvioAllMode) return true;
  if (EngineIds.isPluginChip(optionId) && engineAllMode) return true;
  if (TorrentSearchProviders.isAllChip(selectedSourceId) &&
      TorrentSearchProviders.isBuiltinSearchChip(optionId)) {
    return true;
  }
  return false;
}

const kTorrentAudioTags = [
  'Atmos',
  'TrueHD',
  'DTS:X',
  'DTS-HD',
  'DTS',
  'DD+',
  'DD',
  'AAC',
  '7.1',
  '5.1',
  '2.0',
];

BoxDecoration _torrentPanelTrackDecoration({double radius = 24}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ForjaShellColors.cinematic.borderSubtle),
  );
}

BoxDecoration _torrentPanelControlDecoration({
  required bool active,
  double radius = 8,
}) {
  return BoxDecoration(
    color: active
        ? ForjaShellColors.chipSelectedBg
        : Colors.white.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: active
          ? ForjaShellColors.chipSelectedBorder
          : ForjaShellColors.cinematic.borderSubtle,
    ),
  );
}

class TorrentAudioFilterMenu extends StatefulWidget {
  const TorrentAudioFilterMenu({
    super.key,
    required this.allTags,
    required this.activeTags,
    required this.onChanged,
  });

  final List<String> allTags;
  final Set<String> activeTags;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<TorrentAudioFilterMenu> createState() => _TorrentAudioFilterMenuState();
}

class _TorrentAudioFilterMenuState extends State<TorrentAudioFilterMenu> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.activeTags);
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.graphic_eq,
                    size: 14,
                    color: cinematic.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Audio',
                      style: GoogleFonts.plusJakartaSans(
                        color: cinematic.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() => _selected.clear());
                          widget.onChanged({});
                        },
                        hoverColor: ForjaShellColors.inkHover,
                        splashColor: ForjaShellColors.inkSplash,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.plusJakartaSans(
                              color: cinematic.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: cinematic.borderSubtle, height: 8),
            ...widget.allTags.map((tag) {
              final on = _selected.contains(tag);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (on) {
                        _selected.remove(tag);
                      } else {
                        _selected.add(tag);
                      }
                    });
                    widget.onChanged(Set<String>.from(_selected));
                  },
                  hoverColor: ForjaShellColors.inkHover,
                  splashColor: ForjaShellColors.inkSplash,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag,
                            style: GoogleFonts.plusJakartaSans(
                              color: on
                                  ? cinematic.textPrimary
                                  : cinematic.textSecondary,
                              fontSize: 13,
                              fontWeight: on
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (on)
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: ForjaShellColors.chipSelectedIcon,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class TorrentSourceKindFilter extends StatelessWidget {
  const TorrentSourceKindFilter({
    super.key,
    required this.selected,
    required this.showTorrents,
    required this.showStremio,
    required this.showNuvio,
    this.showEngine = false,
    required this.onChanged,
  });

  final String selected;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final bool showEngine;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <({String id, String label, IconData icon})>[
      if (showEngine) (id: 'engine', label: 'Forja', icon: Icons.bolt_rounded),
      if (showTorrents)
        (id: 'torrents', label: 'Torrents', icon: Icons.downloading_rounded),
      if (showStremio)
        (id: 'stremio', label: 'Stremio', icon: Icons.extension_outlined),
      if (showNuvio) (id: 'nuvio', label: 'Nuvio', icon: Icons.code_rounded),
    ];
    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: _torrentPanelTrackDecoration(),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _SourceTab(
                label: option.label,
                icon: option.icon,
                selected: selected == option.id,
                compact: true,
                onTap: () => onChanged(option.id),
              ),
            ),
        ],
      ),
    );
  }
}

class TorrentSourceToggle extends StatelessWidget {
  const TorrentSourceToggle({
    super.key,
    required this.isStremio,
    required this.isNuvio,
    required this.isTorrent,
    required this.showNuvio,
    required this.showTorrent,
    this.showStremio = true,
    required this.onStremioTap,
    required this.onNuvioTap,
    required this.onTorrentTap,
  });

  final bool isStremio;
  final bool isNuvio;
  final bool isTorrent;
  final bool showNuvio;
  final bool showTorrent;
  final bool showStremio;
  final VoidCallback onStremioTap;
  final VoidCallback onNuvioTap;
  final VoidCallback onTorrentTap;

  @override
  Widget build(BuildContext context) {
    final selected = isNuvio
        ? 'nuvio'
        : isTorrent
        ? 'torrents'
        : 'stremio';
    return TorrentSourceKindFilter(
      selected: selected,
      showTorrents: showTorrent,
      showStremio: showStremio,
      showNuvio: showNuvio,
      onChanged: (id) {
        switch (id) {
          case 'torrents':
            onTorrentTap();
          case 'nuvio':
            onNuvioTap();
          case 'stremio':
            onStremioTap();
        }
      },
    );
  }
}

class _SourceTab extends StatelessWidget {
  const _SourceTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortLabel = label;
    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 20,
      scaleOnFocus: 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ForjaShellColors.chipSelectedBg
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? ForjaShellColors.chipSelectedBorder
                : Colors.transparent,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? ForjaShellColors.cinematic.textPrimary
                    : ForjaShellColors.cinematic.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                shortLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? ForjaShellColors.cinematic.textPrimary
                      : ForjaShellColors.cinematic.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal addon / scraper / indexer chips under Sources kind tabs.
class TorrentSourceChips extends StatefulWidget {
  const TorrentSourceChips({
    super.key,
    required this.options,
    required this.selectedSourceId,
    required this.nuvioSelectedScraperIds,
    this.engineSelectedPluginIds = const {},
    this.nuvioAllMode,
    this.engineAllMode,
    this.nuvioViewFilterScraperIds = const {},
    this.engineViewFilterPluginIds = const {},
    this.torrentViewFilterProviderIds = const {},
    this.loadingChipIds = const {},
    required this.onChipTap,
    this.onChipCancel,
    this.onChipReload,
    this.tvTabId,
    this.tvRowId,
  });

  final List<SourcesPanelProviderOption> options;
  final String selectedSourceId;
  final Set<String> nuvioSelectedScraperIds;
  final Set<String> engineSelectedPluginIds;

  /// When non-null, drives All-chip chrome instead of inferring from selection.
  final bool? nuvioAllMode;
  final bool? engineAllMode;
  final Set<String> nuvioViewFilterScraperIds;
  final Set<String> engineViewFilterPluginIds;
  final Set<String> torrentViewFilterProviderIds;
  final Set<String> loadingChipIds;
  final ValueChanged<String> onChipTap;

  /// Loading `...` → ✕ on that chip (Forja / Nuvio / torrent provider).
  final ValueChanged<String>? onChipCancel;

  /// Idle selected chip refresh — re-run that chip only.
  final ValueChanged<String>? onChipReload;
  final String? tvTabId;
  final String? tvRowId;

  @override
  State<TorrentSourceChips> createState() => _TorrentSourceChipsState();
}

class _TorrentSourceChipsState extends State<TorrentSourceChips> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  bool _chipSelected(SourcesPanelProviderOption option) {
    if (option.id == 'all_nuvio' || option.id.startsWith('nuvio:')) {
      return nuvioProviderChipSelected(
        optionId: option.id,
        allMode: widget.nuvioAllMode ?? false,
        selectedScraperIds: widget.nuvioSelectedScraperIds,
        viewFilterScraperIds: widget.nuvioViewFilterScraperIds,
      );
    }
    if (option.id == EngineIds.allChip ||
        option.id.startsWith(EngineIds.prefix)) {
      return engineProviderChipSelected(
        optionId: option.id,
        allMode: widget.engineAllMode ?? false,
        selectedPluginIds: widget.engineSelectedPluginIds,
        viewFilterPluginIds: widget.engineViewFilterPluginIds,
      );
    }
    return torrentProviderChipSelected(
      optionId: option.id,
      selectedSourceId: widget.selectedSourceId,
      viewFilterProviderIds: widget.torrentViewFilterProviderIds,
    );
  }

  bool _canReloadChip(SourcesPanelProviderOption option) {
    if (widget.onChipReload == null) return false;
    if (widget.loadingChipIds.contains(option.id)) return false;
    if (sourcesPanelChipIsViewFilterSelection(
      optionId: option.id,
      selectedSourceId: widget.selectedSourceId,
      nuvioAllMode: widget.nuvioAllMode ?? false,
      engineAllMode: widget.engineAllMode ?? false,
    )) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    final showArrows = widget.options.length > 3;
    final tab = (widget.tvTabId ?? '').trim();
    final row = (widget.tvRowId ?? '').trim();
    final metrics = ShellScope.metricsOf(context);
    final chipGap = metrics.usesTvDensity
        ? ShellTokens.shellChipGapTv
        : ShellTokens.shellChipGap;
    final dividerH = metrics.torrentPanelChipFontSize +
        metrics.torrentPanelChipVerticalPadding * 2;

    // Vertical pad + Clip.none so dense chip rows don't clip on hover/focus.
    Widget body = DesktopSwipeBackIgnore(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: metrics.usesTvDensity ? 4 * ShellTokens.tvChromeScale : 4,
        ),
        child: Row(
          children: [
            if (showArrows)
              _ScrollArrow(
                icon: Icons.arrow_back_ios_rounded,
                onTap: () => _scrollBy(-120),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.options.length; i++) ...[
                      if (i == 1 && sourcesPanelOptionIsAllChip(widget.options[0].id))
                        Padding(
                          padding: EdgeInsets.only(right: chipGap),
                          child: Container(
                            width: 1,
                            height: dividerH,
                            color: ForjaShellColors.cinematic.borderSubtle,
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(right: chipGap),
                        child: Builder(
                          builder: (context) {
                            final option = widget.options[i];
                            final canReload = _canReloadChip(option);
                            final selected = _chipSelected(option);
                            return ForjaShellChip(
                              label: option.label,
                              selected: selected,
                              loading: widget.loadingChipIds.contains(
                                option.id,
                              ),
                              onTap: () => widget.onChipTap(option.id),
                              onCancel:
                                  widget.onChipCancel == null ||
                                      !widget.loadingChipIds.contains(
                                        option.id,
                                      )
                                  ? null
                                  : () => widget.onChipCancel!(option.id),
                              // Icon: selected load chips only (not All-mode filters).
                              onReload: canReload && selected
                                  ? () => widget.onChipReload!(option.id)
                                  : null,
                              // Hold 2s reloads any loadable chip (not filter selection).
                              onLongPress: canReload
                                  ? () => widget.onChipReload!(option.id)
                                  : null,
                              accentHover: true,
                              radius: metrics.usesTvDensity
                                  ? ShellTokens.shellChipRadiusPillTv
                                  : 999,
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    metrics.torrentPanelChipHorizontalPadding,
                                vertical:
                                    metrics.torrentPanelChipVerticalPadding,
                              ),
                              fontSize: metrics.torrentPanelChipFontSize,
                              listIndex: widget.tvRowId != null ? i : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showArrows)
              _ScrollArrow(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: () => _scrollBy(120),
              ),
          ],
        ),
      ),
    );
    if (tab.isNotEmpty && row.isNotEmpty) {
      body = ShellPaintTvRowScope(tabId: tab, rowId: row, child: body);
    }
    return body;
  }
}

class TorrentSourceResultsHeader extends StatelessWidget {
  const TorrentSourceResultsHeader({
    super.key,
    required this.showSort,
    required this.isFetching,
    required this.episodeLabel,
    required this.resultCount,
    required this.sortPreference,
    required this.activeAudioFilters,
    required this.onSortChanged,
    required this.onCancelFetch,
    required this.onAudioFiltersChanged,
    this.compact = false,
  });

  final bool showSort;
  final bool isFetching;
  final String? episodeLabel;
  final int? resultCount;
  final String sortPreference;
  final Set<String> activeAudioFilters;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onCancelFetch;
  final ValueChanged<Set<String>> onAudioFiltersChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final tv = metrics.usesTvDensity;
    final headingFs = tv ? ShellTokens.tvBodyFontSize : 14.0;
    final metaFs = metrics.torrentPanelMetaFontSize;
    final iconSize = metrics.torrentPanelMetaIconSize;
    final gap = tv ? ShellTokens.torrentPanelChromeGapTv * 0.75 : 6.0;
    final spinner = tv ? metaFs : 12.0;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.download_rounded,
                color: ForjaShellColors.cinematic.textSecondary,
                size: iconSize,
              ),
              SizedBox(width: gap),
              Flexible(
                child: Text(
                  'Available Sources',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: headingFs,
                  ),
                ),
              ),
              if (resultCount != null) ...[
                SizedBox(width: gap),
                Text(
                  '($resultCount)',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textSecondary,
                    fontSize: metaFs,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (episodeLabel != null) ...[
                SizedBox(width: gap),
                Flexible(
                  child: Text(
                    '- $episodeLabel',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary
                          .withValues(alpha: 0.7),
                      fontSize: metaFs,
                    ),
                  ),
                ),
              ],
              if (isFetching) ...[
                SizedBox(width: gap),
                SizedBox(
                  width: spinner,
                  height: spinner,
                  child: CircularProgressIndicator(
                    strokeWidth: tv ? 1.5 : 2,
                    color: ForjaShellColors.sectionAccent,
                  ),
                ),
                SizedBox(width: gap),
                TextButton(
                  onPressed: onCancelFetch,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: gap,
                      vertical: tv ? 2 : 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary,
                      fontSize: metaFs,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showSort && !compact)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: gap,
                    vertical: tv ? 2 : 4,
                  ),
                  decoration: _torrentPanelControlDecoration(active: false),
                  child: DropdownButton<String>(
                    value: sortPreference,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: ForjaShellColors.cinematic.menuSurface,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ForjaShellColors.cinematic.textSecondary,
                      size: iconSize,
                    ),
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textPrimary,
                      fontSize: metaFs,
                    ),
                    items:
                        [
                              'Seeders (High to Low)',
                              'Seeders (Low to High)',
                              'Quality (High to Low)',
                              'Quality (Low to High)',
                              'Size (High to Low)',
                              'Size (Low to High)',
                            ]
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) onSortChanged(val);
                    },
                  ),
                ),
                SizedBox(width: gap),
                _AudioFilterButton(
                  activeFilters: activeAudioFilters,
                  onChanged: onAudioFiltersChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AudioFilterButton extends StatelessWidget {
  const _AudioFilterButton({
    required this.activeFilters,
    required this.onChanged,
  });

  final Set<String> activeFilters;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = activeFilters.isNotEmpty;
    final metrics = ShellScope.metricsOf(context);
    final tv = metrics.usesTvDensity;
    final iconSize = metrics.torrentPanelMetaIconSize;
    final metaFs = metrics.torrentPanelMetaFontSize;
    final padH = tv ? ShellTokens.torrentPanelChromeGapTv : 8.0;
    final padV = tv ? 3.0 : 6.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tv ? ShellTokens.shellChipRadiusTv : 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTapDown: (details) async {
          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final position = RelativeRect.fromRect(
            Rect.fromLTWH(
              details.globalPosition.dx,
              details.globalPosition.dy,
              1,
              1,
            ),
            Offset.zero & overlay.size,
          );
          await showMenu(
            context: context,
            position: position,
            color: ForjaShellColors.cinematic.menuSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                tv ? ShellTokens.shellChipRadiusTv : 8,
              ),
              side: BorderSide(color: ForjaShellColors.cinematic.borderSubtle),
            ),
            items: [
              PopupMenuItem(
                enabled: false,
                padding: EdgeInsets.zero,
                child: TorrentAudioFilterMenu(
                  allTags: kTorrentAudioTags,
                  activeTags: Set<String>.from(activeFilters),
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        },
        borderRadius: BorderRadius.circular(tv ? ShellTokens.shellChipRadiusTv : 8),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: _torrentPanelControlDecoration(active: active),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.graphic_eq,
                size: iconSize,
                color: active
                    ? ForjaShellColors.chipSelectedIcon
                    : ForjaShellColors.cinematic.textSecondary,
              ),
              if (active) ...[
                SizedBox(width: tv ? 3 : 4),
                Text(
                  '${activeFilters.length}',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontSize: metaFs,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    return Button(
      variant: ButtonVariant.plainIcon,
      size: ButtonSize.icon,
      icon: icon,
      iconSize: ShellTokens.iconSizeFor(16, tv: tv),
      height: tv ? 28 * ShellTokens.tvChromeScale : 28,
      color: ForjaShellColors.cinematic.textSecondary,
      onPressed: onTap,
    );
  }
}

class TorrentCacheStorageLine extends StatefulWidget {
  const TorrentCacheStorageLine({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<TorrentCacheStorageLine> createState() =>
      _TorrentCacheStorageLineState();
}

class _TorrentCacheStorageLineState extends State<TorrentCacheStorageLine> {
  static const _pollInterval = Duration(seconds: 2);

  TorrentDownloadCacheSnapshot? _snapshot;
  bool _loading = true;
  bool _clearing = false;
  int _loadGen = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TorrentCacheStorageLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final snapshot = await TorrentStreamService().queryDownloadCacheSnapshot();
    if (!mounted || gen != _loadGen) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      final hadDownloads = (_snapshot?.torrentCount ?? 0) > 0;
      final snap = await TorrentStreamService().clearCacheDirectory();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
      });
      if (hadDownloads) {
        ForjaToast.success(
          snap.hasClearableData ? 'Stopped active download' : 'Downloads cleared',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (_) {
      if (mounted) {
        ForjaToast.error(
          'Could not stop or clear torrent downloads',
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final speed = TorrentStreamService().activeStats()?.speedLabel;
    final snap = snapshot;
    final label = _loading ? '…' : (snap?.label(speedLabel: speed) ?? '…');
    final showPath = !_loading &&
        snap != null &&
        snap.torrentCount > 0 &&
        snap.cacheDir.isNotEmpty;
    final cinematic = ForjaShellColors.cinematic;
    final metrics = ShellScope.metricsOf(context);
    final hasData = !_loading && (snap?.hasClearableData ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.storage_rounded,
              size: metrics.torrentPanelMetaIconSize,
              color: cinematic.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cinematic.textSecondary,
                  fontSize: metrics.torrentPanelMetaFontSize,
                ),
              ),
            ),
            if (hasData && !_clearing)
              shellFocusableTap(
                context: context,
                onTap: _clear,
                borderRadius: 6,
                scaleOnFocus: 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    (snap?.torrentCount ?? 0) > 0 ? 'Stop & clear' : 'Clear',
                    style: TextStyle(
                      color: cinematic.textSecondary,
                      fontSize: metrics.torrentPanelMetaFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_clearing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cinematic.textSecondary,
                ),
              ),
          ],
        ),
        if (showPath)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              snap.cacheDir,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cinematic.textSecondary.withValues(alpha: 0.75),
                fontSize: metrics.torrentPanelMetaFontSize - 1,
              ),
            ),
          ),
      ],
    );
  }
}

String _languageChipLabel(String code) {
  final display = StreamProviderDisplay.flagDisplayForCountry(code);
  if (display.isEmpty) return code.toUpperCase();
  if (StreamProviderDisplay.supportsFlagEmoji) {
    return '$display ${code.toUpperCase()}';
  }
  return display;
}

class TorrentSourceSearchToolbar extends StatefulWidget {
  const TorrentSourceSearchToolbar({
    super.key,
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
    this.showFilters = true,
    this.showAudioFilters = false,
    this.activeAudioFilters = const {},
    this.onAudioFiltersChanged,
    this.availableSizeRanges = const {},
    this.activeSizeFilters = const {},
    this.onSizeFiltersChanged,
    this.offlineFilters = const {},
    this.onOfflineFiltersChanged,
    this.sortPreference,
    this.onSortChanged,

    /// Details: true (BackdropFilter). Player: false (no freeze-frame / no live blur).
    this.enableBlur = true,

    /// When Sources closes, dismiss Filters if they were open.
    this.sourcesPanelOpen = false,

    /// Forja tab soft categories (from installed plugin `types`).
    this.showEngineCategories = false,
    this.engineVisibleCategories = const {},
    this.engineCategoryOptions = const [],
    this.engineCategoryMediaType,
    this.onEngineCategoriesChanged,

    this.searchFocusNode,
    this.filtersFocusNode,
    this.onSearchUpEdge,
    this.onSearchDownEdge,
    this.onSearchRightEdge,
    this.onFiltersUpEdge,
    this.onFiltersDownEdge,
    this.onFiltersRightEdge,
  });

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
  final bool showFilters;
  final bool showAudioFilters;
  final Set<String> activeAudioFilters;
  final ValueChanged<Set<String>>? onAudioFiltersChanged;
  final Set<String> availableSizeRanges;
  final Set<String> activeSizeFilters;
  final ValueChanged<Set<String>>? onSizeFiltersChanged;
  final Set<String> offlineFilters;
  final ValueChanged<Set<String>>? onOfflineFiltersChanged;
  final String? sortPreference;
  final ValueChanged<String>? onSortChanged;
  final bool enableBlur;
  final bool sourcesPanelOpen;
  final bool showEngineCategories;
  final Set<String> engineVisibleCategories;
  final List<String> engineCategoryOptions;
  final String? engineCategoryMediaType;
  final ValueChanged<Set<String>>? onEngineCategoriesChanged;
  final FocusNode? searchFocusNode;
  final FocusNode? filtersFocusNode;
  final VoidCallback? onSearchUpEdge;
  final VoidCallback? onSearchDownEdge;
  final VoidCallback? onSearchRightEdge;
  final VoidCallback? onFiltersUpEdge;
  final VoidCallback? onFiltersDownEdge;
  final VoidCallback? onFiltersRightEdge;

  @override
  State<TorrentSourceSearchToolbar> createState() =>
      _TorrentSourceSearchToolbarState();
}

class _TorrentSourceSearchToolbarState
    extends State<TorrentSourceSearchToolbar> {
  OverlayEntry? _filtersEntry;
  bool _wasPanelOpen = false;
  final ValueNotifier<bool> _filtersHoveredN = ValueNotifier(false);
  bool _filtersFocused = false;

  // Always show the tune control when the chrome asks for filters - empty
  // Stremio/Nuvio lists used to hide it entirely (no facets yet).
  bool get _canFilter => widget.showFilters;

  int get _activeCount =>
      widget.activeQualityFilters.length +
      widget.activeLanguageFilters.length +
      widget.activeTechFilters.length +
      widget.activeAudioFilters.length +
      widget.activeSizeFilters.length +
      widget.offlineFilters.length +
      (widget.showEngineCategories
          ? EngineCategories.extraCategoryFilterCount(
              visibleCategories: widget.engineVisibleCategories,
              mediaType: widget.engineCategoryMediaType,
            )
          : 0);

  bool get _filtersOpen => _filtersEntry != null;

  @override
  void initState() {
    super.initState();
    _wasPanelOpen = widget.sourcesPanelOpen;
  }

  @override
  void didUpdateWidget(covariant TorrentSourceSearchToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.sourcesPanelOpen && _wasPanelOpen) {
      _closeFiltersOverlay(restoreFiltersButton: false);
    }
    _wasPanelOpen = widget.sourcesPanelOpen;
    if (_filtersOpen) {
      // OverlayEntry is not an ancestor of this widget - markNeedsBuild during
      // didUpdateWidget (parent rebuild) trips "setState during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _filtersEntry == null) return;
        _filtersEntry!.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    // Remove overlay only - never setState here (element is already unmounting).
    _removeFiltersOverlay();
    _filtersHoveredN.dispose();
    super.dispose();
  }

  void _toggleFilters() {
    if (_filtersOpen) {
      _closeFiltersOverlay();
    } else {
      _openFiltersSidePanel();
    }
  }

  void _removeFiltersOverlay() {
    SourcesPanelTv.setFiltersDismiss(null);
    final entry = _filtersEntry;
    if (entry == null) return;
    _filtersEntry = null;
    entry.remove();
  }

  void _restoreFiltersButtonFocus() {
    final node = widget.filtersFocusNode;
    if (node == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (!node.canRequestFocus) return;
      } catch (_) {
        return;
      }
      final ctx = node.context;
      if (ctx == null || !ctx.mounted) return;
      FocusScope.of(ctx).requestFocus(node);
    });
  }

  void _closeFiltersOverlay({bool restoreFiltersButton = true}) {
    if (_filtersEntry == null) return;
    _removeFiltersOverlay();
    if (mounted) setState(() {});
    if (restoreFiltersButton) _restoreFiltersButtonFocus();
  }

  void _openFiltersSidePanel() {
    if (_filtersEntry != null) return;
    // Same Overlay as Sources — rootOverlay can sit above a nested navigator
    // Overlay and then BackdropFilter never samples the frosted Sources shell.
    final overlay = Overlay.of(context);
    final tv = SourcesPanelTv.isTv(context);
    late OverlayEntry entry;

    void close({bool restoreFiltersButton = true}) {
      SourcesPanelTv.setFiltersDismiss(null);
      if (_filtersEntry == entry) {
        _filtersEntry = null;
      }
      entry.remove();
      if (mounted) setState(() {});
      if (restoreFiltersButton) _restoreFiltersButtonFocus();
    }

    entry = OverlayEntry(
      builder: (ctx) => _TorrentFiltersSidePanel(
        enableBlur: widget.enableBlur,
        onClose: () => close(),
        claimTvFocus: tv,
        child: _TorrentSourceFilterSheet(
          availableQualities: widget.availableQualities,
          availableLanguages: widget.availableLanguages,
          availableTech: widget.availableTech,
          availableSizeRanges: widget.availableSizeRanges,
          activeQualityFilters: widget.activeQualityFilters,
          activeLanguageFilters: widget.activeLanguageFilters,
          activeTechFilters: widget.activeTechFilters,
          activeAudioFilters: widget.activeAudioFilters,
          activeSizeFilters: widget.activeSizeFilters,
          showAudioFilters: widget.showAudioFilters,
          sortPreference: widget.sortPreference,
          onQualityFiltersChanged: widget.onQualityFiltersChanged,
          onLanguageFiltersChanged: widget.onLanguageFiltersChanged,
          onTechFiltersChanged: widget.onTechFiltersChanged,
          onAudioFiltersChanged: widget.onAudioFiltersChanged,
          onSizeFiltersChanged: widget.onSizeFiltersChanged,
          offlineFilters: widget.offlineFilters,
          onOfflineFiltersChanged: widget.onOfflineFiltersChanged,
          onSortChanged: widget.onSortChanged,
          showEngineCategories: widget.showEngineCategories,
          engineVisibleCategories: widget.engineVisibleCategories,
          engineCategoryOptions: widget.engineCategoryOptions,
          engineCategoryMediaType: widget.engineCategoryMediaType,
          onEngineCategoriesChanged: widget.onEngineCategoriesChanged,
          onClearAll: () {
            widget.onQualityFiltersChanged({});
            widget.onLanguageFiltersChanged({});
            widget.onTechFiltersChanged({});
            widget.onAudioFiltersChanged?.call({});
            widget.onSizeFiltersChanged?.call({});
            widget.onOfflineFiltersChanged?.call({});
            if (widget.showEngineCategories &&
                widget.onEngineCategoriesChanged != null) {
              widget.onEngineCategoriesChanged!(
                EngineCategories.defaultsForMediaType(
                  widget.engineCategoryMediaType,
                ),
              );
            }
          },
          onRequestClose: () => close(),
        ),
      ),
    );
    _filtersEntry = entry;
    overlay.insert(entry);
    SourcesPanelTv.setFiltersDismiss(() {
      if (_filtersEntry == null) return false;
      _closeFiltersOverlay();
      return true;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Same paint density as [_SearchField] — keep tune + search faces aligned.
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final filterGap = tv
        ? ShellTokens.torrentPanelSearchGapTv
        : ShellTokens.torrentPanelSearchGap;
    final filterRadius = tv
        ? ShellTokens.torrentPanelSearchRadiusTv
        : ShellTokens.torrentPanelSearchRadius;
    final filterIcon = tv
        ? ShellTokens.torrentPanelFilterIconSizeTv
        : ShellTokens.torrentPanelFilterIconSize;
    final filterHeight = tv
        ? ShellTokens.torrentPanelFilterButtonHeightTv
        : ShellTokens.torrentPanelFilterButtonHeight;
    final filterFont = tv
        ? ShellTokens.torrentPanelSearchFontSizeTv
        : ShellTokens.torrentPanelSearchFontSize;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _SearchField(
            query: widget.searchQuery,
            onChanged: widget.onSearchChanged,
            focusNode: widget.searchFocusNode,
            onUpEdge: widget.onSearchUpEdge,
            onDownEdge: widget.onSearchDownEdge,
            onRightEdge: widget.onSearchRightEdge ??
                (widget.filtersFocusNode == null
                    ? null
                    : () {
                        final node = widget.filtersFocusNode!;
                        if (node.canRequestFocus) node.requestFocus();
                      }),
          ),
        ),
        if (_canFilter) ...[
          SizedBox(width: filterGap),
          shellFocusableTap(
            context: context,
            onTap: _toggleFilters,
            focusNode: widget.filtersFocusNode,
            borderRadius: filterRadius,
            scaleOnFocus: 1.0,
            suppressInkHover: true,
            showFocusBorder: ShellScope.inputPolicyOf(
              context,
            ).useFocusableMoodChips,
            onFocusChange: (focused) {
              if (_filtersFocused == focused) return;
              setState(() => _filtersFocused = focused);
            },
            onHoverChange: (hovered) {
              if (_filtersHoveredN.value == hovered) return;
              _filtersHoveredN.value = hovered;
            },
            onUpEdge: widget.onFiltersUpEdge,
            onDownEdge: widget.onFiltersDownEdge,
            onRightEdge: widget.onFiltersRightEdge,
            onLeftEdge: widget.searchFocusNode == null
                ? null
                : () {
                    if (widget.searchFocusNode!.canRequestFocus) {
                      widget.searchFocusNode!.requestFocus();
                    }
                  },
            child: ValueListenableBuilder<bool>(
              valueListenable: _filtersHoveredN,
              builder: (context, hovered, _) {
                final lit = ShellInputPolicy.interactiveActive(
                  ShellScope.inputPolicyOf(context),
                  hovered: hovered,
                  focused: _filtersFocused,
                  context: context,
                );
                final filterColor = lit
                    ? ForjaShellColors.brandGreen
                    : (_activeCount > 0 || _filtersOpen)
                        ? ForjaShellColors.chipSelectedIcon
                        : ForjaShellColors.cinematic.textPrimary;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: filterHeight,
                      width: filterHeight,
                      child: Icon(
                        Icons.tune_rounded,
                        size: filterIcon,
                        color: filterColor,
                      ),
                    ),
                    if (_activeCount > 0) ...[
                      SizedBox(width: filterGap * 0.5),
                      Text(
                        '$_activeCount',
                        style: TextStyle(
                          color: lit
                              ? ForjaShellColors.brandGreen
                              : ForjaShellColors.cinematic.textPrimary,
                          fontSize: filterFont,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.query,
    required this.onChanged,
    this.focusNode,
    this.onUpEdge,
    this.onDownEdge,
    this.onRightEdge,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) _controller.text = widget.query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _caretAtEnd {
    final sel = _controller.selection;
    if (!sel.isValid) return true;
    return sel.isCollapsed && sel.baseOffset >= _controller.text.length;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onDownEdge?.call();
      return widget.onDownEdge != null
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onUpEdge?.call();
      return widget.onUpEdge != null
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // Keep ←/→ for the caret while editing mid-string.
      if (!_caretAtEnd) return KeyEventResult.ignored;
      widget.onRightEdge?.call();
      return widget.onRightEdge != null
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Paint density — not focus policy. Desktop must keep controlHeight even when
    // a TV focus graph is mounted under the same overlay.
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final secondary = ForjaShellColors.cinematic.textSecondary;
    final fontSize = tv
        ? ShellTokens.torrentPanelSearchFontSizeTv
        : ShellTokens.torrentPanelSearchFontSize;
    final iconSize = tv
        ? ShellTokens.torrentPanelSearchIconSizeTv
        : ShellTokens.torrentPanelSearchIconSize;
    final padH = tv
        ? ShellTokens.torrentPanelSearchPadHTv
        : ShellTokens.torrentPanelSearchPadH;
    final gap = tv
        ? ShellTokens.torrentPanelSearchGapTv
        : ShellTokens.torrentPanelSearchGap;
    final radius = tv
        ? ShellTokens.torrentPanelSearchRadiusTv
        : ShellTokens.torrentPanelSearchRadius;
    // Fixed face — never size from isDense TextField intrinsics (collapses ~22px).
    final height = tv
        ? ShellTokens.torrentPanelSearchHeightTv
        : ShellTokens.torrentPanelSearchHeight;
    final hintStyle = TextStyle(
      color: secondary.withValues(alpha: 0.7),
      fontSize: fontSize,
      height: 1.0,
    );
    final fieldStyle = TextStyle(
      color: ForjaShellColors.cinematic.textPrimary,
      fontSize: fontSize,
      height: 1.0,
    );
    // Zero vertical pad: the SizedBox face centers the line. ContentPadding
    // vertical used to fight the fixed height and still looked thin on desktop.
    final decoration = InputDecoration(
      hintText: 'Search',
      hintStyle: hintStyle,
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      isCollapsed: true,
    );
    // TV passes searchFocusNode — browse focus only until OK (TvBrowseTextField).
    final focus = widget.focusNode;
    final Widget field = focus != null
        ? TvBrowseTextField(
            controller: _controller,
            focusNode: focus,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onDownEdge?.call(),
            decoration: decoration,
            style: fieldStyle,
            browseHintStyle: hintStyle,
            onKeyEvent: _onKey,
          )
        : TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onDownEdge?.call(),
            style: fieldStyle,
            cursorHeight: fontSize,
            decoration: decoration,
          );

    return SizedBox(
      key: const ValueKey('sources-panel-search'),
      height: height,
      child: DecoratedBox(
        decoration: _torrentPanelControlDecoration(active: false, radius: radius),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded, size: iconSize, color: secondary),
              SizedBox(width: gap),
              Expanded(child: field),
              if (widget.query.isNotEmpty)
                Button(
                  variant: ButtonVariant.plainIcon,
                  size: ButtonSize.icon,
                  icon: Icons.close_rounded,
                  iconSize: iconSize,
                  compact: true,
                  color: secondary,
                  onPressed: () => widget.onChanged(''),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TorrentSourceFilterSheet extends StatefulWidget {
  const _TorrentSourceFilterSheet({
    required this.availableQualities,
    required this.availableLanguages,
    required this.availableTech,
    required this.availableSizeRanges,
    required this.activeQualityFilters,
    required this.activeLanguageFilters,
    required this.activeTechFilters,
    required this.activeAudioFilters,
    required this.activeSizeFilters,
    required this.showAudioFilters,
    required this.onQualityFiltersChanged,
    required this.onLanguageFiltersChanged,
    required this.onTechFiltersChanged,
    required this.onClearAll,
    this.sortPreference,
    this.onSortChanged,
    this.onAudioFiltersChanged,
    this.onSizeFiltersChanged,
    this.offlineFilters = const {},
    this.onOfflineFiltersChanged,
    this.showEngineCategories = false,
    this.engineVisibleCategories = const {},
    this.engineCategoryOptions = const [],
    this.engineCategoryMediaType,
    this.onEngineCategoriesChanged,
    this.onRequestClose,
  });

  final Set<String> availableQualities;
  final Set<String> availableLanguages;
  final Set<String> availableTech;
  final Set<String> availableSizeRanges;
  final Set<String> activeQualityFilters;
  final Set<String> activeLanguageFilters;
  final Set<String> activeTechFilters;
  final Set<String> activeAudioFilters;
  final Set<String> activeSizeFilters;
  final bool showAudioFilters;
  final String? sortPreference;
  final ValueChanged<Set<String>> onQualityFiltersChanged;
  final ValueChanged<Set<String>> onLanguageFiltersChanged;
  final ValueChanged<Set<String>> onTechFiltersChanged;
  final ValueChanged<Set<String>>? onAudioFiltersChanged;
  final ValueChanged<Set<String>>? onSizeFiltersChanged;
  final Set<String> offlineFilters;
  final ValueChanged<Set<String>>? onOfflineFiltersChanged;
  final ValueChanged<String>? onSortChanged;
  final bool showEngineCategories;
  final Set<String> engineVisibleCategories;
  final List<String> engineCategoryOptions;
  final String? engineCategoryMediaType;
  final ValueChanged<Set<String>>? onEngineCategoriesChanged;
  final VoidCallback onClearAll;
  final VoidCallback? onRequestClose;

  @override
  State<_TorrentSourceFilterSheet> createState() =>
      _TorrentSourceFilterSheetState();
}

class _TorrentSourceFilterSheetState extends State<_TorrentSourceFilterSheet> {
  late Set<String> _quality;
  late Set<String> _language;
  late Set<String> _tech;
  late Set<String> _audio;
  late Set<String> _size;
  late Set<String> _offline;
  late Set<String> _engineCats;
  late String? _sort;

  @override
  void initState() {
    super.initState();
    _quality = Set<String>.from(widget.activeQualityFilters);
    _language = Set<String>.from(widget.activeLanguageFilters);
    _tech = Set<String>.from(widget.activeTechFilters);
    _audio = Set<String>.from(widget.activeAudioFilters);
    _size = Set<String>.from(widget.activeSizeFilters);
    _offline = Set<String>.from(widget.offlineFilters);
    _engineCats = Set<String>.from(widget.engineVisibleCategories);
    _sort = widget.sortPreference;
  }

  @override
  void didUpdateWidget(covariant _TorrentSourceFilterSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engineVisibleCategories != widget.engineVisibleCategories) {
      _engineCats = Set<String>.from(widget.engineVisibleCategories);
    }
    if (oldWidget.offlineFilters != widget.offlineFilters) {
      _offline = Set<String>.from(widget.offlineFilters);
    }
  }

  void _toggle(Set<String> set, String value, void Function(Set<String>) emit) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
      emit(Set<String>.from(set));
    });
  }

  /// Offline / Online are exclusive — picking one clears the other.
  void _toggleOffline(String value) {
    final onChanged = widget.onOfflineFiltersChanged;
    if (onChanged == null) return;
    setState(() {
      if (_offline.contains(value)) {
        _offline.remove(value);
      } else {
        _offline
          ..clear()
          ..add(value);
      }
      onChanged(Set<String>.from(_offline));
    });
  }

  void _toggleEngineCategory(String id) {
    final onChanged = widget.onEngineCategoriesChanged;
    if (onChanged == null) return;
    setState(() {
      if (_engineCats.contains(id)) {
        // Keep at least one category so chips never vanish entirely.
        if (_engineCats.length <= 1) return;
        _engineCats.remove(id);
      } else {
        _engineCats.add(id);
      }
      onChanged(Set<String>.from(_engineCats));
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ShellScope.metricsOf(context);
    final cinematic = ForjaShellColors.cinematic;
    final pad = metrics.torrentPanelPadding;
    final tv = SourcesPanelTv.isTv(context);
    var nextSort = 1;

    void clearAll() {
      widget.onClearAll();
      final close = widget.onRequestClose;
      if (close != null) {
        close();
      } else {
        Navigator.pop(context);
      }
    }

    final headerActions = <Widget>[
      _FilterClearButton(
        onPressed: clearAll,
        listIndex: tv ? 0 : null,
      ),
      if (widget.onRequestClose != null) ...[
        SizedBox(width: ShellTokens.chromeScale(4, tv: tv)),
        if (tv)
          shellFocusableTap(
            context: context,
            onTap: widget.onRequestClose,
            borderRadius: ShellTokens.chromeScale(18, tv: tv),
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            listIndex: 1,
            tvTabId: SourcesPanelTv.filtersTabId,
            tvRowId: SourcesPanelTv.filtersHeaderRowId,
            tvItemIndex: 1,
            tvZone: ShellTvZone.chipStrip,
            child: SizedBox(
              width: ShellTokens.chromeScale(36, tv: tv),
              height: ShellTokens.chromeScale(36, tv: tv),
              child: Icon(
                Icons.close_rounded,
                size: ShellTokens.iconSizeFor(20, tv: tv),
                color: cinematic.textSecondary,
              ),
            ),
          )
        else
          Button(
            variant: ButtonVariant.plainIcon,
            size: ButtonSize.icon,
            icon: Icons.close_rounded,
            color: cinematic.textSecondary,
            onPressed: widget.onRequestClose,
          ),
      ],
    ];

    Widget header = Row(
      children: [
        Text(
          'Filters',
          style: TextStyle(
            color: cinematic.textPrimary,
            fontSize: metrics.torrentPanelTitleFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        ...headerActions,
      ],
    );
    if (tv) {
      header = TvKitRow(
        tabId: SourcesPanelTv.filtersTabId,
        rowId: SourcesPanelTv.filtersHeaderRowId,
        sortOrder: 0,
        itemCount: widget.onRequestClose != null ? 2 : 1,
        child: header,
      );
    }

    final sections = <Widget>[];
    if (widget.showEngineCategories &&
        widget.onEngineCategoriesChanged != null) {
      final ids = EngineCategories.filterTypeOptions(
        plugins: const [],
        include: widget.engineVisibleCategories,
        extra: widget.engineCategoryOptions,
      );
      const rowId = 'filters-category';
      sections.add(
        _sheetSection(
          'Category',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < ids.length; i++)
              _sheetChip(
                label: EngineCategories.typeLabel(ids[i]),
                selected: _engineCats.contains(ids[i]),
                onTap: () => _toggleEngineCategory(ids[i]),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.sortPreference != null && widget.onSortChanged != null) {
      const sorts = [
        'Seeders (High to Low)',
        'Seeders (Low to High)',
        'Quality (High to Low)',
        'Quality (Low to High)',
        'Size (High to Low)',
        'Size (Low to High)',
      ];
      const rowId = 'filters-sort';
      sections.add(
        _sheetSection(
          'Sort',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < sorts.length; i++)
              _sheetChip(
                label: sorts[i],
                selected: _sort == sorts[i],
                onTap: () {
                  setState(() => _sort = sorts[i]);
                  widget.onSortChanged!(sorts[i]);
                },
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.availableQualities.isNotEmpty) {
      final qs = TorrentMetaParser.qualityFilters
          .where(widget.availableQualities.contains)
          .toList();
      const rowId = 'filters-quality';
      sections.add(
        _sheetSection(
          'Quality',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < qs.length; i++)
              _sheetChip(
                label: qs[i],
                selected: _quality.contains(qs[i]),
                onTap: () =>
                    _toggle(_quality, qs[i], widget.onQualityFiltersChanged),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.availableSizeRanges.isNotEmpty &&
        widget.onSizeFiltersChanged != null) {
      final sizes = TorrentMetaParser.sizeFilters
          .where(widget.availableSizeRanges.contains)
          .toList();
      const rowId = 'filters-size';
      sections.add(
        _sheetSection(
          'Size',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < sizes.length; i++)
              _sheetChip(
                label: sizes[i],
                selected: _size.contains(sizes[i]),
                onTap: () =>
                    _toggle(_size, sizes[i], widget.onSizeFiltersChanged!),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.availableLanguages.isNotEmpty) {
      final langs = widget.availableLanguages.toList()..sort();
      const rowId = 'filters-language';
      sections.add(
        _sheetSection(
          'Language',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < langs.length; i++)
              _sheetChip(
                label: _languageChipLabel(langs[i]),
                selected: _language.contains(langs[i]),
                onTap: () => _toggle(
                  _language,
                  langs[i],
                  widget.onLanguageFiltersChanged,
                ),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.availableTech.isNotEmpty) {
      final tech = TorrentMetaParser.techFilters
          .where(widget.availableTech.contains)
          .toList();
      const rowId = 'filters-tech';
      sections.add(
        _sheetSection(
          'Tech',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < tech.length; i++)
              _sheetChip(
                label: tech[i],
                selected: _tech.contains(tech[i]),
                onTap: () =>
                    _toggle(_tech, tech[i], widget.onTechFiltersChanged),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.showAudioFilters && widget.onAudioFiltersChanged != null) {
      final tags = kTorrentAudioTags.toList();
      const rowId = 'filters-audio';
      sections.add(
        _sheetSection(
          'Audio',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < tags.length; i++)
              _sheetChip(
                label: tags[i],
                selected: _audio.contains(tags[i]),
                onTap: () =>
                    _toggle(_audio, tags[i], widget.onAudioFiltersChanged!),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }
    if (widget.onOfflineFiltersChanged != null) {
      const rowId = 'filters-offline';
      const options = [
        (kSourcesOfflineFilterId, 'Offline'),
        (kSourcesOnlineFilterId, 'Online'),
      ];
      sections.add(
        _sheetSection(
          'Offline',
          rowId: rowId,
          sortOrder: nextSort++,
          chips: [
            for (var i = 0; i < options.length; i++)
              _sheetChip(
                label: options[i].$2,
                selected: _offline.contains(options[i].$1),
                onTap: () => _toggleOffline(options[i].$1),
                rowId: rowId,
                index: i,
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pad,
        ShellTokens.chromeScale(8, tv: tv),
        pad,
        pad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: ShellTokens.chromeScale(8, tv: tv)),
          ...sections,
        ],
      ),
    );
  }

  Widget _sheetSection(
    String title, {
    required String rowId,
    required int sortOrder,
    required List<Widget> chips,
  }) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final tv = SourcesPanelTv.isTv(context);
    final sectionGap = ShellTokens.chromeScale(8, tv: tv);
    Widget chipRow = Wrap(
      spacing: sectionGap,
      runSpacing: sectionGap,
      children: chips,
    );
    if (tv) {
      chipRow = TvKitRow(
        tabId: SourcesPanelTv.filtersTabId,
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: chips.length,
        child: chipRow,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: ShellTokens.chromeScale(12, tv: tv)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ForjaShellColors.cinematic.textSecondary,
              fontSize: tv
                  ? ShellTokens.filterSheetMetaFontSizeTv
                  : ShellTokens.filterSheetMetaFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: sectionGap),
          chipRow,
        ],
      ),
    );
  }

  Widget _sheetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? rowId,
    int? index,
  }) {
    final metrics = ShellScope.metricsOf(context);
    final tv = SourcesPanelTv.isTv(context);
    final chip = ForjaShellChip(
      label: label,
      selected: selected,
      onTap: onTap,
      // Green hover (desktop) + green focus chrome (TV).
      accentHover: true,
      ensureVisibleMode: tv
          ? ShellPaintEnsureVisible.item
          : ShellPaintEnsureVisible.row,
      radius: tv
          ? ShellTokens.shellChipRadiusPillTv
          : ShellTokens.shellChipRadiusPill,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.torrentPanelChipHorizontalPadding,
        vertical: metrics.torrentPanelChipVerticalPadding,
      ),
      fontSize: metrics.torrentPanelChipFontSize,
      listIndex: tv ? index : null,
    );
    if (!tv || rowId == null || rowId.isEmpty) return chip;
    return ShellPaintTvRowScope(
      tabId: SourcesPanelTv.filtersTabId,
      rowId: rowId,
      child: chip,
    );
  }
}

class _FilterClearButton extends StatelessWidget {
  const _FilterClearButton({
    required this.onPressed,
    this.listIndex,
  });

  final VoidCallback onPressed;
  final int? listIndex;

  @override
  Widget build(BuildContext context) {
    final tv = SourcesPanelTv.isTv(context);
    final clearFs = tv
        ? ShellTokens.tvBodyFontSize
        : ShellTokens.filterSheetMetaFontSize;
    final label = Text(
      'Clear',
      style: TextStyle(
        color: ForjaShellColors.cinematic.textSecondary,
        fontSize: clearFs,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!tv) {
      return TextButton(onPressed: onPressed, child: label);
    }
    return shellFocusableTap(
      context: context,
      onTap: onPressed,
      borderRadius: ShellTokens.chromeScale(8, tv: tv),
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      listIndex: listIndex,
      tvTabId: SourcesPanelTv.filtersTabId,
      tvRowId: SourcesPanelTv.filtersHeaderRowId,
      tvItemIndex: listIndex,
      tvZone: ShellTvZone.chipStrip,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ShellTokens.chromeScale(12, tv: tv),
          vertical: ShellTokens.chromeScale(8, tv: tv),
        ),
        child: label,
      ),
    );
  }
}

/// Full-height Filters panel docked to the left of Sources.
class _TorrentFiltersSidePanel extends StatefulWidget {
  const _TorrentFiltersSidePanel({
    required this.child,
    required this.onClose,
    this.enableBlur = true,
    this.claimTvFocus = false,
  });

  final Widget child;
  final VoidCallback onClose;
  final bool enableBlur;
  final bool claimTvFocus;

  @override
  State<_TorrentFiltersSidePanel> createState() =>
      _TorrentFiltersSidePanelState();
}

class _TorrentFiltersSidePanelState extends State<_TorrentFiltersSidePanel> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _open = true);
      if (widget.claimTvFocus) {
        // After slide-in starts — chips need a frame to register in the graph.
        SourcesPanelTv.claimFiltersFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sourcesW = TorrentSourcesPanel.panelWidthOf(context);
    final filterW = TorrentSourcesPanel.filterPanelWidthOf(context);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final padding = tv
        ? ShellTokens.sourcesFilterPanelPaddingTv
        : ShellTokens.sourcesFilterPanelPadding;

    Widget panel = ForjaFrostedPanel(
      // Details: BackdropFilter. Player: translucent shell (no frame).
      enableBlur: widget.enableBlur,
      // Only a left border - the right edge butts flush against the
      // Sources panel (which draws its own left border) so the two
      // read as one continuous surface, not two floating cards.
      border: Border(
        left: BorderSide(
          color: ForjaShellColors.cinematic.borderSubtle,
        ),
      ),
      child: SafeArea(
        left: false,
        right: false,
        // Wide TV/desktop: no top SafeArea — same as Sources (avoids a dead
        // band above Filters / Clear). Phone still needs the inset.
        top: MediaQuery.sizeOf(context).width < 700,
        child: Padding(padding: padding, child: widget.child),
      ),
    );
    // Keep Positioned as OverlayEntry root — wrap only the panel body.
    if (widget.claimTvFocus) {
      // Per-section TvKitRows: ←/→ stay in the section; → on last chip traps;
      // ↓/↑ move between Category / Quality / Size / … (not reading-order wrap).
      // ShellTvDisableLinearFocus skips TvOverlayScope's nextFocus — claim the
      // first filter chip ourselves (otherwise Close near the tune button wins).
      panel = TvOverlayScope(
        onDismiss: widget.onClose,
        autofocusFirst: false,
        debugLabel: 'sources-filters-tv',
        child: ShellTvDisableLinearFocus(
          child: TvFocusGraph(
            tabId: SourcesPanelTv.filtersTabId,
            child: panel,
          ),
        ),
      );
    }

    // Occupy only the region LEFT of Sources. A full-screen Stack overlay
    // (even with an "empty" Sources strip) can still win the gesture arena on
    // desktop and block Torrents / Stremio / Nuvio row taps.
    final playerFrost = !widget.enableBlur;
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: sourcesW,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: filterW,
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: playerFrost ? 0.22 : 0.54,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: filterW,
            child: ClipRect(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                offset: _open ? Offset.zero : const Offset(1, 0),
                child: panel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
