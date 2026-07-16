import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

/// How many Nuvio provider chips count as an active Filters badge.
///
/// All selected (or none) is the default / empty state — badge stays clear.
/// A partial selection counts as filtered.
int nuvioProviderFilterActiveCount({
  required int selectedCount,
  required int totalEnabled,
}) {
  if (totalEnabled <= 0) return 0;
  if (selectedCount <= 0 || selectedCount >= totalEnabled) return 0;
  return selectedCount;
}

/// Provider / addon / scraper row for the Sources Filters panel.
class SourcesPanelProviderOption {
  const SourcesPanelProviderOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Fetches the next selected Nuvio scraper.
class SourcesLoadNextProviderButton extends StatelessWidget {
  const SourcesLoadNextProviderButton({
    super.key,
    required this.remainingProviders,
    required this.onPressed,
    this.isLoading = false,
  });

  final int remainingProviders;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FocusableControl(
        onTap: isLoading ? null : onPressed,
        borderRadius: 10,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: _torrentPanelControlDecoration(active: false, radius: 10),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cinematic.textPrimary,
                  ),
                )
              : Text(
                  remainingProviders == 1
                      ? 'Load next provider (1 left)'
                      : 'Load next provider ($remainingProviders left)',
                  style: TextStyle(
                    color: cinematic.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
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

BoxDecoration _torrentPanelChipDecoration({
  required bool selected,
  double radius = 20,
}) {
  return BoxDecoration(
    color: selected
        ? ForjaShellColors.chipSelectedBg
        : Colors.white.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected
          ? ForjaShellColors.chipSelectedBorder
          : ForjaShellColors.cinematic.borderSubtle,
    ),
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
                    GestureDetector(
                      onTap: () {
                        setState(() => _selected.clear());
                        widget.onChanged({});
                      },
                      child: Text(
                        'Clear',
                        style: GoogleFonts.plusJakartaSans(
                          color: cinematic.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
    required this.onChanged,
  });

  final String selected;
  final bool showTorrents;
  final bool showStremio;
  final bool showNuvio;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <({String id, String label, IconData icon})>[
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
    return GestureDetector(
      onTap: onTap,
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

class TorrentSourceChips extends StatelessWidget {
  const TorrentSourceChips({
    super.key,
    required this.chips,
    required this.selectedSourceId,
    required this.nuvioSelectedScraperIds,
    required this.scrollController,
    required this.onChipTap,
    required this.onScrollBack,
    required this.onScrollForward,
  });

  final List<Map<String, dynamic>> chips;
  final String selectedSourceId;
  final Set<String> nuvioSelectedScraperIds;
  final ScrollController scrollController;
  final ValueChanged<String> onChipTap;
  final VoidCallback onScrollBack;
  final VoidCallback onScrollForward;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final showArrows = chips.length > 3;

    return Row(
      children: [
        if (showArrows)
          _ScrollArrow(icon: Icons.arrow_back_ios_rounded, onTap: onScrollBack),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips.map((chip) {
                final id = chip['id'] as String;
                final bool selected;
                if (id.startsWith('nuvio:')) {
                  selected = nuvioSelectedScraperIds.contains(
                    id.substring('nuvio:'.length),
                  );
                } else {
                  selected = selectedSourceId == id;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onChipTap(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: _torrentPanelChipDecoration(
                        selected: selected,
                        radius: 999,
                      ),
                      child: Text(
                        chip['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? ForjaShellColors.cinematic.textPrimary
                              : ForjaShellColors.cinematic.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (showArrows)
          _ScrollArrow(
            icon: Icons.arrow_forward_ios_rounded,
            onTap: onScrollForward,
          ),
      ],
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
                    '— $episodeLabel',
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
    return GestureDetector(
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
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          icon,
          color: ForjaShellColors.cinematic.textSecondary.withValues(
            alpha: 0.7,
          ),
          size: 16,
        ),
      ),
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
          FocusableControl(
            onTap: _clear,
            borderRadius: 6,
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
  final flag = StreamProviderDisplay.flagForCountry(code);
  if (flag.isEmpty) return code.toUpperCase();
  return '$flag ${code.toUpperCase()}';
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
    this.providerOptions = const [],
    this.selectedProviderId,
    this.nuvioSelectedScraperIds = const {},
    this.onProviderTap,

    /// Details: true (BackdropFilter). Player: false (no freeze-frame / no live blur).
    this.enableBlur = true,

    /// When Sources closes, dismiss Filters if they were open.
    this.sourcesPanelOpen = false,
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
  final List<SourcesPanelProviderOption> providerOptions;
  final String? selectedProviderId;
  final Set<String> nuvioSelectedScraperIds;
  final ValueChanged<String>? onProviderTap;
  final bool enableBlur;
  final bool sourcesPanelOpen;

  @override
  State<TorrentSourceSearchToolbar> createState() =>
      _TorrentSourceSearchToolbarState();
}

class _TorrentSourceSearchToolbarState
    extends State<TorrentSourceSearchToolbar> {
  OverlayEntry? _filtersEntry;
  bool _wasPanelOpen = false;

  bool get _canFilter =>
      widget.showFilters &&
      (widget.availableQualities.isNotEmpty ||
          widget.availableLanguages.isNotEmpty ||
          widget.availableTech.isNotEmpty ||
          widget.availableSizeRanges.isNotEmpty ||
          widget.showAudioFilters ||
          widget.sortPreference != null ||
          widget.providerOptions.isNotEmpty);

  int get _providerActiveCount {
    if (widget.providerOptions.isEmpty || widget.onProviderTap == null) {
      return 0;
    }
    final nuvio = widget.providerOptions
        .where((p) => p.id.startsWith('nuvio:'))
        .toList();
    if (nuvio.isNotEmpty) {
      return nuvioProviderFilterActiveCount(
        selectedCount: widget.nuvioSelectedScraperIds.length,
        totalEnabled: nuvio.length,
      );
    }
    if (widget.selectedProviderId == null ||
        widget.selectedProviderId!.isEmpty) {
      return 0;
    }
    return 1;
  }

  int get _activeCount =>
      widget.activeQualityFilters.length +
      widget.activeLanguageFilters.length +
      widget.activeTechFilters.length +
      widget.activeAudioFilters.length +
      widget.activeSizeFilters.length +
      _providerActiveCount;

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
      _closeFiltersOverlay();
    }
    _wasPanelOpen = widget.sourcesPanelOpen;
    if (_filtersOpen) {
      // OverlayEntry is not an ancestor of this widget — markNeedsBuild during
      // didUpdateWidget (parent rebuild) trips "setState during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _filtersEntry == null) return;
        _filtersEntry!.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    // Remove overlay only — never setState here (element is already unmounting).
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
    final entry = _filtersEntry;
    if (entry == null) return;
    _filtersEntry = null;
    entry.remove();
  }

  void _closeFiltersOverlay() {
    if (_filtersEntry == null) return;
    _removeFiltersOverlay();
    if (mounted) setState(() {});
  }

  void _openFiltersSidePanel() {
    if (_filtersEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    void close() {
      if (_filtersEntry == entry) {
        _filtersEntry = null;
      }
      entry.remove();
      if (mounted) setState(() {});
    }

    entry = OverlayEntry(
      builder: (ctx) => _TorrentFiltersSidePanel(
        enableBlur: widget.enableBlur,
        onClose: close,
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
          providerOptions: widget.providerOptions,
          selectedProviderId: widget.selectedProviderId,
          nuvioSelectedScraperIds: widget.nuvioSelectedScraperIds,
          onProviderTap: widget.onProviderTap,
          onQualityFiltersChanged: widget.onQualityFiltersChanged,
          onLanguageFiltersChanged: widget.onLanguageFiltersChanged,
          onTechFiltersChanged: widget.onTechFiltersChanged,
          onAudioFiltersChanged: widget.onAudioFiltersChanged,
          onSizeFiltersChanged: widget.onSizeFiltersChanged,
          onSortChanged: widget.onSortChanged,
          onClearAll: () {
            widget.onQualityFiltersChanged({});
            widget.onLanguageFiltersChanged({});
            widget.onTechFiltersChanged({});
            widget.onAudioFiltersChanged?.call({});
            widget.onSizeFiltersChanged?.call({});
          },
          onRequestClose: close,
        ),
      ),
    );
    _filtersEntry = entry;
    overlay.insert(entry);
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
          ),
        ),
        if (_canFilter) ...[
          const SizedBox(width: 8),
          FocusableControl(
            onTap: _toggleFilters,
            borderRadius: 10,
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
  const _SearchField({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _torrentPanelControlDecoration(active: false, radius: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: ForjaShellColors.cinematic.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: TextStyle(
                color: ForjaShellColors.cinematic.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (widget.query.isNotEmpty)
            ForjaCloseButton.compact(
              tooltip: null,
              color: ForjaShellColors.cinematic.textSecondary,
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
    this.providerOptions = const [],
    this.selectedProviderId,
    this.nuvioSelectedScraperIds = const {},
    this.onProviderTap,
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
  final List<SourcesPanelProviderOption> providerOptions;
  final String? selectedProviderId;
  final Set<String> nuvioSelectedScraperIds;
  final ValueChanged<String>? onProviderTap;
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
  late String? _sort;
  late String? _selectedProviderId;
  late Set<String> _nuvioSelectedScraperIds;

  @override
  void initState() {
    super.initState();
    _quality = Set<String>.from(widget.activeQualityFilters);
    _language = Set<String>.from(widget.activeLanguageFilters);
    _tech = Set<String>.from(widget.activeTechFilters);
    _audio = Set<String>.from(widget.activeAudioFilters);
    _size = Set<String>.from(widget.activeSizeFilters);
    _sort = widget.sortPreference;
    _selectedProviderId = widget.selectedProviderId;
    _nuvioSelectedScraperIds = Set<String>.from(widget.nuvioSelectedScraperIds);
  }

  @override
  void didUpdateWidget(covariant _TorrentSourceFilterSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProviderId != widget.selectedProviderId) {
      _selectedProviderId = widget.selectedProviderId;
    }
    // Always sync — OverlayEntry may rebuild a frame late after select-all.
    _nuvioSelectedScraperIds = Set<String>.from(widget.nuvioSelectedScraperIds);
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

  void _onProviderTap(String id) {
    setState(() {
      if (id.startsWith('nuvio:')) {
        final scraperId = id.substring('nuvio:'.length);
        if (_nuvioSelectedScraperIds.contains(scraperId)) {
          _nuvioSelectedScraperIds = Set<String>.from(_nuvioSelectedScraperIds)
            ..remove(scraperId);
        } else {
          _nuvioSelectedScraperIds = {
            ..._nuvioSelectedScraperIds,
            scraperId,
          };
        }
      } else {
        _selectedProviderId = id;
      }
    });
    widget.onProviderTap?.call(id);
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
                TextButton(
                  onPressed: () {
                    widget.onClearAll();
                    final close = widget.onRequestClose;
                    if (close != null) {
                      close();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: cinematic.textSecondary),
                  ),
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
            if (widget.providerOptions.isNotEmpty &&
                widget.onProviderTap != null)
              _sheetSection(
                'Providers',
                widget.providerOptions.map((option) {
                  final selected = option.id.startsWith('nuvio:')
                      ? _nuvioSelectedScraperIds.contains(
                          option.id.substring('nuvio:'.length),
                        )
                      : _selectedProviderId == option.id;
                  return _sheetChip(
                    label: option.label,
                    selected: selected,
                    onTap: () => _onProviderTap(option.id),
                  );
                }),
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
    return FocusableControl(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.torrentPanelChipHorizontalPadding,
          vertical: metrics.torrentPanelChipVerticalPadding,
        ),
        decoration: _torrentPanelChipDecoration(selected: selected),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? ForjaShellColors.cinematic.textPrimary
                : ForjaShellColors.cinematic.textSecondary,
            fontSize: metrics.torrentPanelChipFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
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
  });

  final Widget child;
  final VoidCallback onClose;
  final bool enableBlur;

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
                child: ForjaFrostedPanel(
                  // Details: BackdropFilter. Player: translucent shell (no frame).
                  enableBlur: widget.enableBlur,
                  // Only a left border — the right edge butts flush against the
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
