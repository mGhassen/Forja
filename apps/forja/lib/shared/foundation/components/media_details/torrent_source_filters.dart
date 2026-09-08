import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/shell_tv_focus.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';
import 'package:forja/shared/foundation/components/media_details/sources_panel_tv.dart';
import 'package:forja/shared/foundation/components/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/foundation/components/media_details/torrent_sources_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

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

    // Vertical pad + Clip.none so dense chip rows don't clip on hover/focus.
    return DesktopSwipeBackIgnore(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 1,
                            height: 22,
                            color: ForjaShellColors.cinematic.borderSubtle,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
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
                              radius: 999,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              fontSize: 12,
                              listIndex: widget.tvRowId != null ? i : null,
                              tvTabId: widget.tvTabId,
                              tvRowId: widget.tvRowId,
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
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.download_rounded,
                color: ForjaShellColors.cinematic.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Available Sources',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (resultCount != null) ...[
                const SizedBox(width: 6),
                Text(
                  '($resultCount)',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (episodeLabel != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '- $episodeLabel',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary
                          .withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (isFetching) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ForjaShellColors.sectionAccent,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onCancelFetch,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary,
                      fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
                      size: 16,
                    ),
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textPrimary,
                      fontSize: 11,
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
                const SizedBox(width: 8),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: _torrentPanelControlDecoration(active: active),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.graphic_eq,
                size: 14,
                color: active
                    ? ForjaShellColors.chipSelectedIcon
                    : ForjaShellColors.cinematic.textSecondary,
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Text(
                  '${activeFilters.length}',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontSize: 11,
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
    return ForjaPlainIcon(
      icon: icon,
      size: 16,
      hitSize: 28,
      color: ForjaShellColors.cinematic.textSecondary,
      onTap: onTap,
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

  // Always show the tune control when the chrome asks for filters - empty
  // Stremio/Nuvio lists used to hide it entirely (no facets yet).
  bool get _canFilter => widget.showFilters;

  int get _activeCount =>
      widget.activeQualityFilters.length +
      widget.activeLanguageFilters.length +
      widget.activeTechFilters.length +
      widget.activeAudioFilters.length +
      widget.activeSizeFilters.length +
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
    final overlay = Overlay.of(context, rootOverlay: true);
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
    return Row(
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
          const SizedBox(width: 8),
          shellFocusableTap(
            context: context,
            onTap: _toggleFilters,
            focusNode: widget.filtersFocusNode,
            borderRadius: 10,
            scaleOnFocus: 1.0,
            suppressInkHover: true,
            showFocusBorder: ShellScope.inputPolicyOf(
              context,
            ).useFocusableMoodChips,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ForjaPlainIcon(
                  icon: Icons.tune_rounded,
                  size: 18,
                  hitSize: 32,
                  color: (_activeCount > 0 || _filtersOpen)
                      ? ForjaShellColors.chipSelectedIcon
                      : ForjaShellColors.cinematic.textPrimary,
                ),
                if (_activeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$_activeCount',
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
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
    final secondary = ForjaShellColors.cinematic.textSecondary;
    final hintStyle = TextStyle(
      color: secondary.withValues(alpha: 0.7),
      fontSize: 13,
    );
    final fieldStyle = TextStyle(
      color: ForjaShellColors.cinematic.textPrimary,
      fontSize: 13,
    );
    final decoration = InputDecoration(
      hintText: 'Search',
      hintStyle: hintStyle,
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
            decoration: decoration,
          );

    return Container(
      decoration: _torrentPanelControlDecoration(active: false, radius: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: secondary),
          const SizedBox(width: 8),
          Expanded(child: field),
          if (widget.query.isNotEmpty)
            ForjaCloseButton.compact(
              tooltip: null,
              color: secondary,
              onTap: () => widget.onChanged(''),
            ),
        ],
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
    _engineCats = Set<String>.from(widget.engineVisibleCategories);
    _sort = widget.sortPreference;
  }

  @override
  void didUpdateWidget(covariant _TorrentSourceFilterSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engineVisibleCategories != widget.engineVisibleCategories) {
      _engineCats = Set<String>.from(widget.engineVisibleCategories);
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
        const SizedBox(width: 4),
        if (tv)
          shellFocusableTap(
            context: context,
            onTap: widget.onRequestClose,
            borderRadius: 18,
            scaleOnFocus: 1.0,
            showFocusBorder: true,
            listIndex: 1,
            tvTabId: SourcesPanelTv.filtersTabId,
            tvRowId: SourcesPanelTv.filtersHeaderRowId,
            tvItemIndex: 1,
            tvZone: ShellTvZone.chipStrip,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: cinematic.textSecondary,
              ),
            ),
          )
        else
          ForjaCloseButton(
            color: cinematic.textSecondary,
            onTap: widget.onRequestClose,
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
      final qs = TorrentReleaseMetadata.qualityFilters
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
      final sizes = TorrentReleaseMetadata.sizeFilters
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
      final tech = TorrentReleaseMetadata.techFilters
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 8),
            ...sections,
          ],
        ),
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
    Widget chipRow = Wrap(spacing: 8, runSpacing: 8, children: chips);
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ForjaShellColors.cinematic.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
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
    return ForjaShellChip(
      label: label,
      selected: selected,
      onTap: onTap,
      // TV: green focus chrome (chips otherwise paint no focus ring).
      accentHover: tv,
      ensureVisibleMode: tv
          ? ShellTvEnsureVisibleMode.item
          : ShellTvEnsureVisibleMode.row,
      radius: 16,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.torrentPanelChipHorizontalPadding,
        vertical: metrics.torrentPanelChipVerticalPadding,
      ),
      fontSize: metrics.torrentPanelChipFontSize,
      tvTabId: tv && rowId != null ? SourcesPanelTv.filtersTabId : null,
      tvRowId: tv ? rowId : null,
      listIndex: tv ? index : null,
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
    final label = Text(
      'Clear',
      style: TextStyle(color: ForjaShellColors.cinematic.textSecondary),
    );
    if (!SourcesPanelTv.isTv(context)) {
      return TextButton(onPressed: onPressed, child: label);
    }
    return shellFocusableTap(
      context: context,
      onTap: onPressed,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      listIndex: listIndex,
      tvTabId: SourcesPanelTv.filtersTabId,
      tvRowId: SourcesPanelTv.filtersHeaderRowId,
      tvItemIndex: listIndex,
      tvZone: ShellTvZone.chipStrip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      if (mounted) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sourcesW = TorrentSourcesPanel.panelWidthOf(context);
    final filterW = TorrentSourcesPanel.filterPanelWidthOf(context);
    const padding = EdgeInsets.fromLTRB(20, 8, 12, 16);

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
        child: Padding(padding: padding, child: widget.child),
      ),
    );
    // Keep Positioned as OverlayEntry root — wrap only the panel body.
    if (widget.claimTvFocus) {
      // Per-section TvKitRows: ←/→ stay in the section; → on last chip traps;
      // ↓/↑ move between Category / Quality / Size / … (not reading-order wrap).
      panel = TvOverlayScope(
        onDismiss: widget.onClose,
        autofocusFirst: true,
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
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
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
