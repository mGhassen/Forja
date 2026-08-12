part of 'iptv_pt_screen.dart';

class _ChannelsHubView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  const _ChannelsHubView({required this.ctrl, required this.compact});

  @override
  State<_ChannelsHubView> createState() => _ChannelsHubViewState();
}

class _ChannelsHubViewState extends State<_ChannelsHubView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HardcodedChannel> get _filtered {
    if (_query.trim().isEmpty) return HardcodedChannels.all;
    final q = _query.trim().toLowerCase();
    return HardcodedChannels.all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.short.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: 'Channels',
            subtitle: 'Curated brands · auto-find live streams',
            onBack: widget.ctrl.back,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TvBrowseTextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
              browsePlaceholder: 'Search channels…',
              browseHintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 14,
              ),
              caretHeight: 18,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search channels…',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
                suffixIcon: _query.isEmpty
                    ? null
                    : iptvCloseButton(
                        context,
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFF1A1A22),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: IptvShellStyle.accent,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No channels match “$_query”.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (_, c) {
                      final cross = (c.maxWidth ~/ 160).clamp(2, 8);
                      return iptvCatalogRow(
                        rowId: 'channels-hub',
                        sortOrder: 0,
                        itemCount: results.length,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final ch = results[i];
                            return _ChannelTile(
                              channel: ch,
                              gridIndex: i,
                              gridColumns: cross,
                              onTap: () =>
                                  widget.ctrl.openHardcodedChannel(ch),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final HardcodedChannel channel;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  const _ChannelTile({
    required this.channel,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: IptvShellStyle.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IptvShellStyle.border),
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 14,
          gridIndex: gridIndex,
          gridColumns: gridColumns,
          tvRowId: 'channels-hub',
          tvZone: ShellTvZone.grid,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  channel.short,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 4),
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHANNEL RESULTS
// ─────────────────────────────────────────────────────────────────────────────
class _ChannelResultsView extends StatefulWidget {
  final IptvController ctrl;
  final bool compact;
  const _ChannelResultsView({required this.ctrl, required this.compact});

  @override
  State<_ChannelResultsView> createState() => _ChannelResultsViewState();
}

class _ChannelResultsViewState extends State<_ChannelResultsView> {
  bool _editMode = false;

  /// Selection tracks streamUrl, not index, so it stays valid when the
  /// displayed list is filtered/sorted by the search box & EPG-first sort.
  final Set<String> _selected = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Sort order: favorites first, then hits whose Xtream stream has an
  /// `epg_channel_id` (a hint that the panel ships EPG for it), then
  /// everything else. Stable within each tier so user-curated ordering is
  /// preserved. Then filter by the search query if set.
  List<ChannelHit> _displayList(IptvController ctrl) {
    final channelId = ctrl.activeHardcoded?.id ?? '';
    final fav = <ChannelHit>[];
    final epg = <ChannelHit>[];
    final rest = <ChannelHit>[];
    for (final h in ctrl.channelResults) {
      if (ctrl.isFavoriteHit(channelId, h)) {
        fav.add(h);
      } else if (h.stream.epgChannelId.isNotEmpty) {
        epg.add(h);
      } else {
        rest.add(h);
      }
    }
    var list = <ChannelHit>[...fav, ...epg, ...rest];
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((h) {
        return h.stream.name.toLowerCase().contains(q) ||
            h.portal.displayLabel.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final ch = ctrl.activeHardcoded;
    final displayed = _displayList(ctrl);
    return SafeArea(
      child: Column(
        children: [
          _PtAppBar(
            title: ch?.name ?? 'Channel',
            subtitle: ctrl.channelStatus.isEmpty
                ? '${displayed.length}${_query.isEmpty ? '' : '/${ctrl.channelResults.length}'} hits'
                : ctrl.channelStatus,
            onBack: ctrl.back,
            actions: [
              if (ctrl.channelResults.isNotEmpty)
                IptvIconAction(
                  tooltip: _editMode ? 'Done' : 'Edit',
                  onPressed: () => setState(() {
                    _editMode = !_editMode;
                    if (!_editMode) _selected.clear();
                  }),
                  icon: _editMode ? Icons.check_rounded : Icons.edit_rounded,
                  color: _editMode ? IptvShellStyle.accent : Colors.white70,
                ),
            ],
          ),
          if (ctrl.channelResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TvBrowseTextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _query = v),
                browsePlaceholder: 'Search hits…',
                browseHintStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 14,
                ),
                caretHeight: 18,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search hits…',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
                  suffixIcon: _query.isEmpty
                      ? null
                      : iptvCloseButton(
                          context,
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A22),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: IptvShellStyle.accent,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          if (_editMode && ctrl.channelResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: IptvShellStyle.chipSelectedBg.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Text(
                    _selected.isEmpty
                        ? 'Select streams'
                        : '${_selected.length} selected',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                  ),
                  const Spacer(),
                  IptvTextAction(
                    icon:
                        displayed.isNotEmpty &&
                            _selected.containsAll(
                              displayed.map((h) => h.streamUrl),
                            )
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    label:
                        displayed.isNotEmpty &&
                            _selected.containsAll(
                              displayed.map((h) => h.streamUrl),
                            )
                        ? 'Clear'
                        : 'Select all',
                    onPressed: () {
                      setState(() {
                        final urls = displayed.map((h) => h.streamUrl).toSet();
                        final allSelected =
                            urls.isNotEmpty && _selected.containsAll(urls);
                        if (allSelected) {
                          _selected.removeAll(urls);
                        } else {
                          _selected.addAll(urls);
                        }
                      });
                    },
                  ),
                  if (_selected.isNotEmpty)
                    IptvIconAction(
                      tooltip: 'Delete selected',
                      onPressed: () async {
                        final indices = <int>{};
                        for (var i = 0; i < ctrl.channelResults.length; i++) {
                          if (_selected.contains(
                            ctrl.channelResults[i].streamUrl,
                          )) {
                            indices.add(i);
                          }
                        }
                        await ctrl.deleteChannelHits(indices);
                        setState(() {
                          _selected.clear();
                          _editMode = false;
                        });
                      },
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                ],
              ),
            ),
          if (ctrl.channelIsRunning) _buildSearchingBar(),
          Expanded(
            child: ctrl.channelResults.isEmpty
                ? _buildEmpty()
                : displayed.isEmpty
                ? Center(
                    child: Text(
                      'No hits match “$_query”.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  )
                : _buildResults(displayed),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSearchingBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: IptvShellStyle.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.ctrl.channelStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
            ),
          ),
          IptvTextAction(
            icon: Icons.stop_circle_rounded,
            label: 'Stop',
            onPressed: widget.ctrl.stopChannelSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final ctrl = widget.ctrl;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: IptvShellStyle.accent,
            ),
            const SizedBox(height: 16),
            Text(
              ctrl.channelIsRunning ? 'Searching…' : 'No hits yet',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              ctrl.channelStatus.isEmpty
                  ? 'Tap "Search Again" or "Get More" to scan saved + new portals.'
                  : ctrl.channelStatus,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<ChannelHit> displayed) {
    final ctrl = widget.ctrl;
    return LayoutBuilder(
      builder: (_, c) {
        final cross = (c.maxWidth ~/ 320).clamp(1, 4);
        return iptvCatalogRow(
          rowId: 'channel-results',
          sortOrder: 0,
          itemCount: displayed.length,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 132,
            ),
            itemCount: displayed.length,
            itemBuilder: (_, i) {
              final hit = displayed[i];
              final selected = _selected.contains(hit.streamUrl);
              return _ChannelHitCard(
                hit: hit,
                ctrl: ctrl,
                editMode: _editMode,
                selected: selected,
                gridIndex: i,
                gridColumns: cross,
                isFavorite: ctrl.isFavoriteHit(
                  ctrl.activeHardcoded?.id ?? '',
                  hit,
                ),
                onToggleFavorite: () => ctrl.toggleFavoriteHit(hit),
                onTap: () {
                  if (_editMode) {
                    setState(() {
                      if (selected) {
                        _selected.remove(hit.streamUrl);
                      } else {
                        _selected.add(hit.streamUrl);
                      }
                    });
                  } else {
                    // Put the tapped hit first so the player actually opens it,
                    // and keep the rest as failover sources for the watchdog.
                    // Use the full original results list (not filtered) so the
                    // watchdog has every fallback available.
                    final ordered = [
                      hit,
                      ...ctrl.channelResults.where((h) => h != hit),
                    ];
                    IptvPtPlayerScreen.open(
                      context,
                      IptvPtPlayerScreen.fromHits(
                        hits: ordered,
                        title: ctrl.activeHardcoded?.name ?? hit.stream.name,
                        logoUrl: hit.stream.icon,
                      ),
                    );
                  }
                },
                onLongPress: () {
                  if (!_editMode) {
                    setState(() {
                      _editMode = true;
                      _selected.add(hit.streamUrl);
                    });
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final ctrl = widget.ctrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IptvPrimaryButton(
              icon: Icons.refresh_rounded,
              label: 'Search Again',
              busy: ctrl.channelIsRunning,
              onPressed: ctrl.searchAgainChannel,
            ),
            const SizedBox(width: 8),
            IptvPrimaryButton(
              icon: Icons.add_circle_outline,
              label: 'Get More',
              subtle: true,
              onPressed: ctrl.channelIsRunning ? null : ctrl.getMoreChannels,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelHitCard extends StatelessWidget {
  final ChannelHit hit;
  final IptvController ctrl;
  final bool editMode;
  final bool selected;
  final bool isFavorite;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;
  const _ChannelHitCard({
    required this.hit,
    required this.ctrl,
    required this.editMode,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
    this.gridIndex,
    this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? IptvShellStyle.accent
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 12,
          gridIndex: gridIndex,
          gridColumns: gridColumns,
          tvRowId: 'channel-results',
          tvZone: ShellTvZone.grid,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (editMode) ...[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: selected ? IptvShellStyle.accent : Colors.white30,
                  ),
                  const SizedBox(width: 8),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: hit.stream.icon.isEmpty
                        ? const _StreamPlaceholder()
                        : ColoredBox(
                            color: Colors.white.withValues(alpha: 0.03),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.network(
                                hit.stream.icon,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const _StreamPlaceholder(),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: hit.stream.name,
                        waitDuration: const Duration(milliseconds: 600),
                        child: Text(
                          hit.stream.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'via ${_portalLabel(hit.portal)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                      _HitEpgNowRow(hit: hit, ctrl: ctrl),
                    ],
                  ),
                ),
                if (!editMode)
                  IptvIconAction(
                    tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
                    onPressed: onToggleFavorite,
                    icon: isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: isFavorite
                        ? const Color(0xFFFACC15)
                        : Colors.white38,
                    iconSize: 20,
                  ),
                if (!editMode)
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: IptvShellStyle.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _portalLabel(VerifiedPortal v) {
    final n = v.displayLabel;
    if (n.startsWith('http://') || n.startsWith('https://')) {
      return _redactUrl(n);
    }
    return n;
  }
}

/// Compact `[NOW] Programme` row rendered under the "via …" line on a hit
/// card. Stays empty (zero-height) when the portal has no EPG for this stream
/// so card layout doesn't shift visibly while loading.
class _HitEpgNowRow extends StatelessWidget {
  final ChannelHit hit;
  final IptvController ctrl;
  const _HitEpgNowRow({required this.hit, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: ctrl.epgForHit(hit),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        final now = data.firstWhere((e) => e.isNow, orElse: () => data.first);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: now.isNow
                      ? const Color(0xFFEF4444)
                      : IptvShellStyle.accent.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  now.isNow ? 'NOW' : 'NEXT',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  now.title.isEmpty ? '-' : now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
