import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

const kTorrentAudioTags = [
  'Atmos', 'TrueHD', 'DTS:X', 'DTS-HD', 'DTS', 'DD+', 'DD', 'AAC', '7.1', '5.1', '2.0',
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
                  Icon(Icons.graphic_eq, size: 14, color: cinematic.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Audio',
                      style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              color: on ? cinematic.textPrimary : cinematic.textSecondary,
                              fontSize: 13,
                              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
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

class TorrentSourceToggle extends StatelessWidget {
  const TorrentSourceToggle({
    super.key,
    required this.isStremio,
    required this.isNuvio,
    required this.isWebstreaming,
    required this.isTorrent,
    required this.showNuvio,
    required this.showWebstreaming,
    required this.showTorrent,
    required this.onStremioTap,
    required this.onNuvioTap,
    required this.onWebstreamingTap,
    required this.onTorrentTap,
  });

  final bool isStremio;
  final bool isNuvio;
  final bool isWebstreaming;
  final bool isTorrent;
  final bool showNuvio;
  final bool showWebstreaming;
  final bool showTorrent;
  final VoidCallback onStremioTap;
  final VoidCallback onNuvioTap;
  final VoidCallback onWebstreamingTap;
  final VoidCallback onTorrentTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Container(
      decoration: _torrentPanelTrackDecoration(),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SourceTab(
              label: 'Stremio Addons',
              icon: Icons.extension_outlined,
              selected: isStremio,
              compact: compact,
              onTap: onStremioTap,
            ),
          ),
          if (showNuvio)
            Expanded(
              child: _SourceTab(
                label: 'Nuvio Addons',
                icon: Icons.code_rounded,
                selected: isNuvio,
                compact: compact,
                onTap: onNuvioTap,
              ),
            ),
          if (showWebstreaming)
            Expanded(
              child: _SourceTab(
                label: 'Webstreaming',
                icon: Icons.play_circle_outline_rounded,
                selected: isWebstreaming,
                compact: compact,
                onTap: onWebstreamingTap,
              ),
            ),
          if (showTorrent)
            Expanded(
              child: _SourceTab(
                label: 'Torrent Sources',
                icon: Icons.downloading_rounded,
                selected: isTorrent,
                compact: compact,
                onTap: onTorrentTap,
              ),
            ),
        ],
      ),
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
    final shortLabel = compact
        ? (label.startsWith('Stremio')
            ? 'Stremio'
            : label.startsWith('Nuvio')
                ? 'Nuvio'
                : label.startsWith('Webstreaming')
                    ? 'Stream'
                    : 'Torrent')
        : label;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ForjaShellColors.chipSelectedBg : Colors.transparent,
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
              Icon(icon, size: 14, color: selected ? ForjaShellColors.cinematic.textPrimary : ForjaShellColors.cinematic.textSecondary),
              const SizedBox(width: 5),
              Text(
                shortLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? ForjaShellColors.cinematic.textPrimary : ForjaShellColors.cinematic.textSecondary,
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
    required this.nuvioSelectedAddonUrl,
    required this.scrollController,
    required this.onChipTap,
    required this.onScrollBack,
    required this.onScrollForward,
  });

  final List<Map<String, dynamic>> chips;
  final String selectedSourceId;
  final String? nuvioSelectedAddonUrl;
  final ScrollController scrollController;
  final ValueChanged<String> onChipTap;
  final VoidCallback onScrollBack;
  final VoidCallback onScrollForward;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        _ScrollArrow(icon: Icons.arrow_back_ios_rounded, onTap: onScrollBack),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips.map((chip) {
                final id = chip['id'] as String;
                final bool selected;
                if (id.startsWith('nuvio_addon::')) {
                  selected = nuvioSelectedAddonUrl == id.substring('nuvio_addon::'.length);
                } else if (id == 'nuvio_back') {
                  selected = false;
                } else {
                  selected = selectedSourceId == id;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChipTap(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: _torrentPanelChipDecoration(selected: selected),
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
        _ScrollArrow(icon: Icons.arrow_forward_ios_rounded, onTap: onScrollForward),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.download_rounded, color: ForjaShellColors.cinematic.textSecondary, size: 16),
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
                      color: ForjaShellColors.cinematic.textSecondary.withValues(alpha: 0.7),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        if (showSort)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    items: [
                      'Seeders (High to Low)',
                      'Seeders (Low to High)',
                      'Quality (High to Low)',
                      'Quality (Low to High)',
                      'Size (High to Low)',
                      'Size (Low to High)',
                    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
        final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final position = RelativeRect.fromRect(
          Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 1, 1),
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
          color: ForjaShellColors.cinematic.textSecondary.withValues(alpha: 0.7),
          size: 16,
        ),
      ),
    );
  }
}

String _languageChipLabel(String code) {
  final flag = StreamProviderDisplay.flagForCountry(code);
  if (flag.isEmpty) return code.toUpperCase();
  return '$flag ${code.toUpperCase()}';
}

class TorrentSourcePanelToolbar extends StatefulWidget {
  const TorrentSourcePanelToolbar({
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

  @override
  State<TorrentSourcePanelToolbar> createState() => _TorrentSourcePanelToolbarState();
}

class _TorrentSourcePanelToolbarState extends State<TorrentSourcePanelToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant TorrentSourcePanelToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFilters = widget.showFilters &&
        (widget.availableQualities.isNotEmpty ||
            widget.availableLanguages.isNotEmpty ||
            widget.availableTech.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                  controller: _searchController,
                  onChanged: widget.onSearchChanged,
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search sources…',
                    hintStyle: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (widget.searchQuery.isNotEmpty)
                ForjaPlainIcon(
                  icon: Icons.close_rounded,
                  size: 18,
                  color: ForjaShellColors.cinematic.textSecondary,
                  onTap: () => widget.onSearchChanged(''),
                ),
            ],
          ),
        ),
        if (showFilters) ...[
          const SizedBox(height: 10),
          _FilterChipRow(
            label: 'Quality',
            chips: TorrentReleaseMetadata.qualityFilters
                .where(widget.availableQualities.contains)
                .toList(),
            active: widget.activeQualityFilters,
            onChanged: widget.onQualityFiltersChanged,
          ),
          if (widget.availableLanguages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FilterChipRow(
              label: 'Language',
              chips: widget.availableLanguages.toList()..sort(),
              active: widget.activeLanguageFilters,
              onChanged: widget.onLanguageFiltersChanged,
              labelBuilder: _languageChipLabel,
            ),
          ],
          if (widget.availableTech.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FilterChipRow(
              label: 'Tech',
              chips: TorrentReleaseMetadata.techFilters
                  .where(widget.availableTech.contains)
                  .toList(),
              active: widget.activeTechFilters,
              onChanged: widget.onTechFiltersChanged,
            ),
          ],
        ],
      ],
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.label,
    required this.chips,
    required this.active,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final List<String> chips;
  final Set<String> active;
  final ValueChanged<Set<String>> onChanged;
  final String Function(String code)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              label,
              style: TextStyle(
                color: ForjaShellColors.cinematic.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.map((chip) {
              final selected = active.contains(chip);
              final text = labelBuilder?.call(chip) ?? chip;
              return GestureDetector(
                onTap: () {
                  final next = Set<String>.from(active);
                  if (selected) {
                    next.remove(chip);
                  } else {
                    next.add(chip);
                  }
                  onChanged(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: _torrentPanelChipDecoration(selected: selected, radius: 16),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? ForjaShellColors.cinematic.textPrimary
                          : ForjaShellColors.cinematic.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
