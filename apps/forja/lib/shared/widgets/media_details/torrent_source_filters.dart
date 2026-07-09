import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

const kTorrentAudioTags = [
  'Atmos', 'TrueHD', 'DTS:X', 'DTS-HD', 'DTS', 'DD+', 'DD', 'AAC', '7.1', '5.1', '2.0',
];

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
    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Audio',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 8),
            ...widget.allTags.map((tag) {
              final on = _selected.contains(tag);
              return InkWell(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: on ? ForjaShellColors.chipSelectedBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: on
                                ? ForjaShellColors.chipSelectedBorder
                                : Colors.white30,
                            width: 1.5,
                          ),
                        ),
                        child: on
                            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tag,
                        style: TextStyle(
                          color: on ? Colors.white : Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
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
            color: selected ? ForjaShellColors.chipSelectedBorder : Colors.transparent,
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
                      decoration: BoxDecoration(
                        color: selected
                            ? ForjaShellColors.chipSelectedBg
                            : Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? ForjaShellColors.chipSelectedBorder
                              : Colors.white.withValues(alpha: 0.2),
                        ),
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
    required this.sortPreference,
    required this.activeAudioFilters,
    required this.onSortChanged,
    required this.onCancelFetch,
    required this.onAudioFiltersChanged,
  });

  final bool showSort;
  final bool isFetching;
  final String? episodeLabel;
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<String>(
                    value: sortPreference,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: ForjaShellColors.cinematic.menuSurface,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        decoration: BoxDecoration(
          color: active ? ForjaShellColors.chipSelectedBg : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? ForjaShellColors.chipSelectedBorder : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 14,
              color: active ? ForjaShellColors.chipSelectedIcon : Colors.white54,
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Text(
                '${activeFilters.length}',
                style: TextStyle(
                  color: ForjaShellColors.textPrimary,
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
        child: Icon(icon, color: Colors.white38, size: 16),
      ),
    );
  }
}
