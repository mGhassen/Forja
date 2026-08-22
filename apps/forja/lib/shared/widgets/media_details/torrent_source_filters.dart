import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/navigation/desktop_trackpad_nav.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';
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

/// Torrents chip selected chrome — All lights every builtin provider chip
/// (Nuvio All does the same). Jackett / Prowlarr stay exclusive.
bool torrentProviderChipSelected({
  required String optionId,
  required String selectedSourceId,
}) {
  if (TorrentSearchProviders.isNoneChip(selectedSourceId)) return false;
  if (selectedSourceId == optionId) return true;
  final allSelected = TorrentSearchProviders.isAllChip(selectedSourceId);
  return allSelected && TorrentSearchProviders.isBuiltin(optionId);
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
    if (option.id == 'all_nuvio') {
      final scraperIds = [
        for (final o in widget.options)
          if (o.id.startsWith('nuvio:')) o.id.substring('nuvio:'.length),
      ];
      return scraperIds.isNotEmpty &&
          scraperIds.every(widget.nuvioSelectedScraperIds.contains);
    }
    if (option.id.startsWith('nuvio:')) {
      return widget.nuvioSelectedScraperIds.contains(
        option.id.substring('nuvio:'.length),
      );
    }
    if (option.id == 'all_engine') {
      final pluginIds = [
        for (final o in widget.options)
          if (o.id.startsWith('engine:')) o.id.substring('engine:'.length),
      ];
      return pluginIds.isNotEmpty &&
          pluginIds.every(widget.engineSelectedPluginIds.contains);
    }
    if (option.id.startsWith('engine:')) {
      return widget.engineSelectedPluginIds.contains(
        option.id.substring('engine:'.length),
      );
    }
    return torrentProviderChipSelected(
      optionId: option.id,
      selectedSourceId: widget.selectedSourceId,
    );
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
                    for (var i = 0; i < widget.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ForjaShellChip(
                          label: widget.options[i].label,
                          selected: _chipSelected(widget.options[i]),
                          loading: widget.loadingChipIds.contains(
                            widget.options[i].id,
                          ),
                          onTap: () => widget.onChipTap(widget.options[i].id),
                          onCancel:
                              widget.onChipCancel == null ||
                                  !widget.loadingChipIds.contains(
                                    widget.options[i].id,
                                  )
                              ? null
                              : () => widget.onChipCancel!(
                                  widget.options[i].id,
                                ),
                          onReload:
                              widget.onChipReload == null ||
                                  widget.loadingChipIds.contains(
                                    widget.options[i].id,
                                  ) ||
                                  !_chipSelected(widget.options[i])
                              ? null
                              : () => widget.onChipReload!(
                                  widget.options[i].id,
                                ),
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
                        ),
                      ),
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
  String _label = '…';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TorrentCacheStorageLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final bytes = await TorrentStreamService().cacheDirectoryBytes();
    if (!mounted) return;
    setState(() {
      _label = TorrentStreamService.formatStorageBytes(bytes);
    });
  }

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      await TorrentStreamService().clearCacheDirectory();
      await _load();
    } catch (_) {
      if (mounted) {
        ForjaToast.error(
          'Could not clear stream cache',
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final metrics = ShellScope.metricsOf(context);
    final hasData = _label != '0 B';

    return Row(
      children: [
        Icon(
          Icons.storage_rounded,
          size: metrics.torrentPanelMetaIconSize,
          color: cinematic.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Stream cache: $_label',
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
                'Clear',
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

    /// Forja tab soft categories (Movie / TV / Anime / Drama).
    this.showEngineCategories = false,
    this.engineVisibleCategories = const {},
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _torrentPanelControlDecoration(
                active: _activeCount > 0 || _filtersOpen,
                radius: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: ForjaShellColors.cinematic.textPrimary,
                  ),
                  if (_activeCount > 0) ...[
                    const SizedBox(width: 6),
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                _FilterClearButton(
                  onPressed: () {
                    widget.onClearAll();
                    final close = widget.onRequestClose;
                    if (close != null) {
                      close();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                if (widget.onRequestClose != null) ...[
                  const SizedBox(width: 4),
                  ForjaCloseButton(
                    color: cinematic.textSecondary,
                    onTap: widget.onRequestClose,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (widget.showEngineCategories &&
                widget.onEngineCategoriesChanged != null)
              _sheetSection(
                'Category',
                EngineCategories.all.map(
                  (id) => _sheetChip(
                    label: EngineCategories.label(id),
                    selected: _engineCats.contains(id),
                    onTap: () => _toggleEngineCategory(id),
                  ),
                ),
              ),
            if (widget.sortPreference != null && widget.onSortChanged != null)
              _sheetSection(
                'Sort',
                [
                  'Seeders (High to Low)',
                  'Seeders (Low to High)',
                  'Quality (High to Low)',
                  'Quality (Low to High)',
                  'Size (High to Low)',
                  'Size (Low to High)',
                ].map(
                  (s) => _sheetChip(
                    label: s,
                    selected: _sort == s,
                    onTap: () {
                      setState(() => _sort = s);
                      widget.onSortChanged!(s);
                    },
                  ),
                ),
              ),
            if (widget.availableQualities.isNotEmpty)
              _sheetSection(
                'Quality',
                TorrentReleaseMetadata.qualityFilters
                    .where(widget.availableQualities.contains)
                    .map(
                      (q) => _sheetChip(
                        label: q,
                        selected: _quality.contains(q),
                        onTap: () => _toggle(
                          _quality,
                          q,
                          widget.onQualityFiltersChanged,
                        ),
                      ),
                    ),
              ),
            if (widget.availableSizeRanges.isNotEmpty &&
                widget.onSizeFiltersChanged != null)
              _sheetSection(
                'Size',
                TorrentReleaseMetadata.sizeFilters
                    .where(widget.availableSizeRanges.contains)
                    .map(
                      (s) => _sheetChip(
                        label: s,
                        selected: _size.contains(s),
                        onTap: () =>
                            _toggle(_size, s, widget.onSizeFiltersChanged!),
                      ),
                    ),
              ),
            if (widget.availableLanguages.isNotEmpty)
              _sheetSection(
                'Language',
                (widget.availableLanguages.toList()..sort()).map(
                  (code) => _sheetChip(
                    label: _languageChipLabel(code),
                    selected: _language.contains(code),
                    onTap: () => _toggle(
                      _language,
                      code,
                      widget.onLanguageFiltersChanged,
                    ),
                  ),
                ),
              ),
            if (widget.availableTech.isNotEmpty)
              _sheetSection(
                'Tech',
                TorrentReleaseMetadata.techFilters
                    .where(widget.availableTech.contains)
                    .map(
                      (t) => _sheetChip(
                        label: t,
                        selected: _tech.contains(t),
                        onTap: () =>
                            _toggle(_tech, t, widget.onTechFiltersChanged),
                      ),
                    ),
              ),
            if (widget.showAudioFilters && widget.onAudioFiltersChanged != null)
              _sheetSection(
                'Audio',
                kTorrentAudioTags.map(
                  (tag) => _sheetChip(
                    label: tag,
                    selected: _audio.contains(tag),
                    onTap: () =>
                        _toggle(_audio, tag, widget.onAudioFiltersChanged!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSection(String title, Iterable<Widget> chips) {
    final list = chips.toList();
    if (list.isEmpty) return const SizedBox.shrink();
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
          Wrap(spacing: 8, runSpacing: 8, children: list),
        ],
      ),
    );
  }

  Widget _sheetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final metrics = ShellScope.metricsOf(context);
    return ForjaShellChip(
      label: label,
      selected: selected,
      onTap: onTap,
      radius: 16,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.torrentPanelChipHorizontalPadding,
        vertical: metrics.torrentPanelChipVerticalPadding,
      ),
      fontSize: metrics.torrentPanelChipFontSize,
    );
  }
}

class _FilterClearButton extends StatelessWidget {
  const _FilterClearButton({required this.onPressed});

  final VoidCallback onPressed;

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
      panel = TvOverlayScope(
        onDismiss: widget.onClose,
        autofocusFirst: true,
        debugLabel: 'sources-filters-tv',
        child: panel,
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
