import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
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
        if (showSort && !compact)
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

class TorrentCacheStorageLine extends StatefulWidget {
  const TorrentCacheStorageLine({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<TorrentCacheStorageLine> createState() => _TorrentCacheStorageLineState();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not clear stream cache'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final isTv = ShellTokens.isTvLayout(context);
    final hasData = _label != '0 B';

    return Row(
      children: [
        Icon(Icons.storage_rounded, size: isTv ? 16 : 14, color: cinematic.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Stream cache: $_label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cinematic.textSecondary,
              fontSize: isTv ? 12 : 11,
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
                  fontSize: isTv ? 12 : 11,
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

class TorrentSourcePanelToolbar extends StatelessWidget {
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
    this.showAudioFilters = false,
    this.activeAudioFilters = const {},
    this.onAudioFiltersChanged,
    this.sortPreference,
    this.onSortChanged,
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
  final String? sortPreference;
  final ValueChanged<String>? onSortChanged;

  int get _activeCount =>
      activeQualityFilters.length +
      activeLanguageFilters.length +
      activeTechFilters.length +
      activeAudioFilters.length;

  Future<void> _openFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TorrentSourceFilterSheet(
        availableQualities: availableQualities,
        availableLanguages: availableLanguages,
        availableTech: availableTech,
        activeQualityFilters: activeQualityFilters,
        activeLanguageFilters: activeLanguageFilters,
        activeTechFilters: activeTechFilters,
        activeAudioFilters: activeAudioFilters,
        showAudioFilters: showAudioFilters,
        sortPreference: sortPreference,
        onQualityFiltersChanged: onQualityFiltersChanged,
        onLanguageFiltersChanged: onLanguageFiltersChanged,
        onTechFiltersChanged: onTechFiltersChanged,
        onAudioFiltersChanged: onAudioFiltersChanged,
        onSortChanged: onSortChanged,
        onClearAll: () {
          onQualityFiltersChanged({});
          onLanguageFiltersChanged({});
          onTechFiltersChanged({});
          onAudioFiltersChanged?.call({});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ShellTokens.isTvLayout(context);
    final canFilter = showFilters &&
        (availableQualities.isNotEmpty ||
            availableLanguages.isNotEmpty ||
            availableTech.isNotEmpty ||
            showAudioFilters ||
            sortPreference != null);

    if (isTv) {
      if (!canFilter) return const SizedBox.shrink();
      return FocusableControl(
        onTap: () => _openFilters(context),
        borderRadius: 10,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: _torrentPanelControlDecoration(active: _activeCount > 0, radius: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 20, color: ForjaShellColors.cinematic.textPrimary),
              const SizedBox(width: 8),
              Text(
                _activeCount > 0 ? 'Filters ($_activeCount)' : 'Filters & sort',
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: _SearchField(query: searchQuery, onChanged: onSearchChanged)),
        if (canFilter) ...[
          const SizedBox(width: 8),
          FocusableControl(
            onTap: () => _openFilters(context),
            borderRadius: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _torrentPanelControlDecoration(active: _activeCount > 0, radius: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: ForjaShellColors.cinematic.textPrimary),
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
          Icon(Icons.search_rounded, size: 18, color: ForjaShellColors.cinematic.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: TextStyle(color: ForjaShellColors.cinematic.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search',
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
          if (widget.query.isNotEmpty)
            ForjaPlainIcon(
              icon: Icons.close_rounded,
              size: 18,
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
    required this.activeQualityFilters,
    required this.activeLanguageFilters,
    required this.activeTechFilters,
    required this.activeAudioFilters,
    required this.showAudioFilters,
    required this.onQualityFiltersChanged,
    required this.onLanguageFiltersChanged,
    required this.onTechFiltersChanged,
    required this.onClearAll,
    this.sortPreference,
    this.onSortChanged,
    this.onAudioFiltersChanged,
  });

  final Set<String> availableQualities;
  final Set<String> availableLanguages;
  final Set<String> availableTech;
  final Set<String> activeQualityFilters;
  final Set<String> activeLanguageFilters;
  final Set<String> activeTechFilters;
  final Set<String> activeAudioFilters;
  final bool showAudioFilters;
  final String? sortPreference;
  final ValueChanged<Set<String>> onQualityFiltersChanged;
  final ValueChanged<Set<String>> onLanguageFiltersChanged;
  final ValueChanged<Set<String>> onTechFiltersChanged;
  final ValueChanged<Set<String>>? onAudioFiltersChanged;
  final ValueChanged<String>? onSortChanged;
  final VoidCallback onClearAll;

  @override
  State<_TorrentSourceFilterSheet> createState() => _TorrentSourceFilterSheetState();
}

class _TorrentSourceFilterSheetState extends State<_TorrentSourceFilterSheet> {
  late Set<String> _quality;
  late Set<String> _language;
  late Set<String> _tech;
  late Set<String> _audio;
  late String? _sort;

  @override
  void initState() {
    super.initState();
    _quality = Set<String>.from(widget.activeQualityFilters);
    _language = Set<String>.from(widget.activeLanguageFilters);
    _tech = Set<String>.from(widget.activeTechFilters);
    _audio = Set<String>.from(widget.activeAudioFilters);
    _sort = widget.sortPreference;
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

  @override
  Widget build(BuildContext context) {
    final isTv = ShellTokens.isTvLayout(context);
    final cinematic = ForjaShellColors.cinematic;
    final pad = isTv ? 24.0 : 16.0;

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
                    fontSize: isTv ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onClearAll();
                    Navigator.pop(context);
                  },
                  child: Text('Clear', style: TextStyle(color: cinematic.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                ].map((s) => _sheetChip(
                      label: s,
                      selected: _sort == s,
                      onTap: () {
                        setState(() => _sort = s);
                        widget.onSortChanged!(s);
                      },
                    )),
              ),
            if (widget.availableQualities.isNotEmpty)
              _sheetSection(
                'Quality',
                TorrentReleaseMetadata.qualityFilters
                    .where(widget.availableQualities.contains)
                    .map((q) => _sheetChip(
                          label: q,
                          selected: _quality.contains(q),
                          onTap: () => _toggle(_quality, q, widget.onQualityFiltersChanged),
                        )),
              ),
            if (widget.availableLanguages.isNotEmpty)
              _sheetSection(
                'Language',
                (widget.availableLanguages.toList()..sort()).map((code) => _sheetChip(
                      label: _languageChipLabel(code),
                      selected: _language.contains(code),
                      onTap: () => _toggle(_language, code, widget.onLanguageFiltersChanged),
                    )),
              ),
            if (widget.availableTech.isNotEmpty)
              _sheetSection(
                'Tech',
                TorrentReleaseMetadata.techFilters
                    .where(widget.availableTech.contains)
                    .map((t) => _sheetChip(
                          label: t,
                          selected: _tech.contains(t),
                          onTap: () => _toggle(_tech, t, widget.onTechFiltersChanged),
                        )),
              ),
            if (widget.showAudioFilters && widget.onAudioFiltersChanged != null)
              _sheetSection(
                'Audio',
                kTorrentAudioTags.map((tag) => _sheetChip(
                      label: tag,
                      selected: _audio.contains(tag),
                      onTap: () => _toggle(_audio, tag, widget.onAudioFiltersChanged!),
                    )),
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
    final isTv = ShellTokens.isTvLayout(context);
    return FocusableControl(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isTv ? 16 : 12, vertical: isTv ? 10 : 8),
        decoration: _torrentPanelChipDecoration(selected: selected),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? ForjaShellColors.cinematic.textPrimary
                : ForjaShellColors.cinematic.textSecondary,
            fontSize: isTv ? 14 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
