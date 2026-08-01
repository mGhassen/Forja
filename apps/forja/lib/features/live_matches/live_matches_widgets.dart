part of 'live_matches_screen.dart';

// ─── Top bar: Servers (green on TV focus) + Refresh (white on TV focus) ─────

class _LiveMatchesServersTopBarButton extends StatefulWidget {
  const _LiveMatchesServersTopBarButton({
    required this.onTap,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final VoidCallback onTap;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<_LiveMatchesServersTopBarButton> createState() =>
      _LiveMatchesServersTopBarButtonState();
}

class _LiveMatchesServersTopBarButtonState
    extends State<_LiveMatchesServersTopBarButton> {
  static const _radius = 20.0;
  bool _focused = false;
  bool _hovered = false;

  bool get _tv => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  bool get _tvFocused => _tv && _focused;

  bool get _active => ShellInputPolicy.interactiveActive(
    ShellScope.inputPolicyOf(context),
    hovered: _hovered,
    focused: _focused,
  );

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final decoration = _tvFocused
        ? iptvFocusButtonDecoration(
            active: _active,
            tvFocused: true,
            borderRadius: _radius,
          )
        : shellChipDecoration(selected: false, radius: _radius);
    final fg = _tvFocused
        ? ForjaShellColors.brandGreen
        : cinematic.textSecondary;

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_rounded, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            'Servers',
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (!_tv) {
      return shellRoundedInkHost(
        radius: _radius,
        onTap: widget.onTap,
        child: chip,
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: _radius,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      listIndex: _LiveMatchesScreenState._topBarServersIndex,
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._topBarRowId,
      tvItemIndex: _LiveMatchesScreenState._topBarServersIndex,
      tvZone: ShellTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: chip,
    );
  }
}

class _LiveMatchesRefreshTopBarButton extends StatefulWidget {
  const _LiveMatchesRefreshTopBarButton({
    required this.focusNode,
    required this.onTap,
    this.onLeftEdge,
    this.onDownEdge,
  });

  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onDownEdge;

  @override
  State<_LiveMatchesRefreshTopBarButton> createState() =>
      _LiveMatchesRefreshTopBarButtonState();
}

class _LiveMatchesRefreshTopBarButtonState
    extends State<_LiveMatchesRefreshTopBarButton> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => ShellInputPolicy.interactiveActive(
    ShellScope.inputPolicyOf(context),
    hovered: _hovered,
    focused: _focused,
  );

  @override
  Widget build(BuildContext context) {
    final fg = _active ? Colors.white : Colors.white70;
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 24,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      focusNode: widget.focusNode,
      tvTabId: _LiveMatchesScreenState._tabId,
      tvRowId: _LiveMatchesScreenState._topBarRowId,
      tvItemIndex: _LiveMatchesScreenState._topBarRefreshIndex,
      tvZone: ShellTvZone.topBar,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: widget.onLeftEdge,
      // TV has no view toggle - trap right at Refresh.
      onRightEdge: () {},
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          ShellTvFocusCoordinator.saveFocus(
            _LiveMatchesScreenState._tabId,
            ShellTvFocusMemory(
              zone: ShellTvZone.topBar,
              node: widget.focusNode,
            ),
          );
        }
      },
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: Tooltip(
        message: 'Refresh',
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.refresh_rounded, color: fg),
        ),
      ),
    );
  }
}

// ─── Server picker sheet ────────────────────────────────────────────────────

class _LiveMatchesServerSheet extends StatefulWidget {
  const _LiveMatchesServerSheet({
    required this.current,
    required this.onSelected,
  });

  final _LiveMatchesServer current;
  final ValueChanged<_LiveMatchesServer> onSelected;

  @override
  State<_LiveMatchesServerSheet> createState() =>
      _LiveMatchesServerSheetState();
}

class _LiveMatchesServerSheetState extends State<_LiveMatchesServerSheet> {
  static const _rowId = 'live-server-sheet';
  final FocusNode _firstFocus = FocusNode(
    debugLabel: 'live-server-sheet-first',
  );

  List<_LiveMatchesServer> get _servers => [
    _LiveMatchesServer.all,
    ..._LiveMatchesServer.values.where(
      (server) => server != _LiveMatchesServer.all,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Servers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a live match source:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < servers.length; i++)
                _LiveMatchesServerSheetOption(
                  server: servers[i],
                  current: widget.current,
                  onSelected: widget.onSelected,
                  tvItemIndex: i,
                  tvRowId: _rowId,
                  focusNode: i == 0 ? _firstFocus : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (!tv) return body;
    return TvCatalogRow(
      tabId: 'live_matches',
      rowId: _rowId,
      sortOrder: 0,
      itemCount: servers.length,
      orientation: ShellTvRowOrientation.vertical,
      child: body,
    );
  }
}

class _LiveMatchesServerSheetOption extends StatefulWidget {
  const _LiveMatchesServerSheetOption({
    required this.server,
    required this.current,
    required this.onSelected,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final _LiveMatchesServer server;
  final _LiveMatchesServer current;
  final ValueChanged<_LiveMatchesServer> onSelected;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<_LiveMatchesServerSheetOption> createState() =>
      _LiveMatchesServerSheetOptionState();
}

class _LiveMatchesServerSheetOptionState
    extends State<_LiveMatchesServerSheetOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.server == widget.current;
    return shellFocusableTap(
      context: context,
      onTap: () => widget.onSelected(widget.server),
      borderRadius: 12,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: ListTile(
        leading: Icon(
          widget.server == _LiveMatchesServer.all
              ? Icons.grid_view_rounded
              : Icons.dns_rounded,
          color: selected ? ForjaShellColors.sectionAccent : Colors.white54,
        ),
        title: Text(
          _liveMatchesServerLabel(widget.server),
          style: TextStyle(
            color: Colors.white,
            fontWeight: _focused || selected
                ? FontWeight.bold
                : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _liveMatchesServerSubtitle(widget.server),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: selected
            ? Icon(Icons.check_rounded, color: ForjaShellColors.sectionAccent)
            : const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}

// ─── Chips ────────────────────────────────────────────────────────────────────

class _TeamBadge extends StatelessWidget {
  final String? badge;
  final String name;
  const _TeamBadge({required this.badge, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white12,
          child: badge != null && badge!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: badge!,
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 50,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 8.5),
          ),
        ),
      ],
    );
  }
}

class _LiveMatchCornerBadge extends StatelessWidget {
  const _LiveMatchCornerBadge({
    required this.label,
    required this.live,
    this.color,
    this.top = 8,
    this.left,
    this.right = 8,
  });

  final String label;
  final bool live;
  final Color? color;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final fontSize = shellScaled(context, 10).clamp(9.0, 12.0);
    final padH = shellScaled(context, 8).clamp(6.0, 10.0);
    final padV = shellScaled(context, 3).clamp(2.0, 4.0);
    final radius = shellScaled(context, 6).clamp(4.0, 8.0);
    final inset = shellScaled(context, top).clamp(6.0, 10.0);
    final bg = color ?? (live ? Colors.red.shade700 : Colors.black54);

    return Positioned(
      top: inset,
      left: left,
      right: right,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CDN Channel Card ─────────────────────────────────────────────────────────

class _CdnChannelCard extends StatefulWidget {
  final _CdnChannel channel;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  const _CdnChannelCard({
    required this.channel,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  @override
  State<_CdnChannelCard> createState() => _CdnChannelCardState();
}

class _CdnChannelCardState extends State<_CdnChannelCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
    );
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (c.image.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: c.image,
                        height: 46,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const Icon(
                          Icons.tv_rounded,
                          color: Colors.white38,
                          size: 38,
                        ),
                      )
                    else
                      const Icon(
                        Icons.tv_rounded,
                        color: Colors.white38,
                        size: 38,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (c.viewers > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${c.viewers} viewers',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Channels are always live - keep the play affordance visible.
              ShellCardPlayOverlay(active: active, visible: true),
              _LiveMatchCornerBadge(
                label: '● LIVE',
                live: true,
                color: Colors.green.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CDN Sport Event Card ─────────────────────────────────────────────────────

class _CdnSportCard extends StatefulWidget {
  final _CdnSportEvent event;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final bool forceActive;
  final ValueChanged<bool>? onHoverChanged;
  final String tvRowId;
  final ShellTvZone tvZone;
  const _CdnSportCard({
    required this.event,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.forceActive = false,
    this.onHoverChanged,
    this.tvRowId = 'grid',
    this.tvZone = ShellTvZone.grid,
  });

  @override
  State<_CdnSportCard> createState() => _CdnSportCardState();
}

class _CdnSportCardState extends State<_CdnSportCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final canPlay = e.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active =
        widget.forceActive ||
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        );
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : ForjaShellColors.cinematic.borderSubtle,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          if (e.homeTeamIMG.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: e.homeTeamIMG,
                              width: 32,
                              height: 32,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.sports_rounded,
                                color: Colors.white38,
                                size: 26,
                              ),
                            )
                          else
                            const Icon(
                              Icons.sports_rounded,
                              color: Colors.white38,
                              size: 26,
                            ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 50,
                            child: Text(
                              e.homeTeam,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          if (e.awayTeamIMG.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: e.awayTeamIMG,
                              width: 32,
                              height: 32,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.sports_rounded,
                                color: Colors.white38,
                                size: 26,
                              ),
                            )
                          else
                            const Icon(
                              Icons.sports_rounded,
                              color: Colors.white38,
                              size: 26,
                            ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 50,
                            child: Text(
                              e.awayTeam,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.tournament,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Airing events always show the play button; hover/focus turns it green.
            if (canPlay) ShellCardPlayOverlay(active: active, visible: true),
            _LiveMatchCornerBadge(
              label: e.isLive ? '● LIVE' : e.status.toUpperCase(),
              live: e.isLive,
              color: e.isLive ? Colors.red.shade700 : Colors.orange.shade700,
            ),
          ],
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: canPlay ? widget.onTap : null,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.tvZone == ShellTvZone.grid ? widget.gridIndex : null,
      gridColumns: widget.tvZone == ShellTvZone.grid
          ? widget.gridColumns
          : null,
      listIndex: widget.tvZone == ShellTvZone.row ? widget.gridIndex : null,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvZone: widget.tvZone,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) {
        setState(() => _hovered = hovered);
        widget.onHoverChanged?.call(hovered);
      },
      child: card,
    );
  }
}

// ─── CDN Channel Sheet ────────────────────────────────────────────────────────

class _CdnChannelSheet extends StatefulWidget {
  final _CdnSportEvent event;
  final void Function(_CdnChannel) onChannelSelected;
  const _CdnChannelSheet({
    required this.event,
    required this.onChannelSelected,
  });

  @override
  State<_CdnChannelSheet> createState() => _CdnChannelSheetState();
}

class _CdnChannelSheetState extends State<_CdnChannelSheet> {
  static const _rowId = 'live-cdn-channel-sheet';
  final FocusNode _firstFocus = FocusNode(
    debugLabel: 'live-cdn-channel-sheet-first',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.event.channels;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.event.homeTeam} vs ${widget.event.awayTeam}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a channel:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < channels.length; i++)
                _CdnChannelSheetRow(
                  channel: channels[i],
                  onTap: () => widget.onChannelSelected(channels[i]),
                  tvItemIndex: i,
                  tvRowId: _rowId,
                  focusNode: i == 0 ? _firstFocus : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (!tv) return body;
    return TvCatalogRow(
      tabId: 'live_matches',
      rowId: _rowId,
      sortOrder: 0,
      itemCount: channels.length,
      orientation: ShellTvRowOrientation.vertical,
      child: body,
    );
  }
}

class _CdnChannelSheetRow extends StatefulWidget {
  const _CdnChannelSheetRow({
    required this.channel,
    required this.onTap,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final _CdnChannel channel;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<_CdnChannelSheetRow> createState() => _CdnChannelSheetRowState();
}

class _CdnChannelSheetRowState extends State<_CdnChannelSheetRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 12,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: ListTile(
        leading: widget.channel.image.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.channel.image,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => Icon(
                  Icons.tv_rounded,
                  color: ForjaShellColors.sectionAccent,
                ),
              )
            : Icon(Icons.tv_rounded, color: ForjaShellColors.sectionAccent),
        title: Text(
          widget.channel.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: _focused ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: widget.channel.viewers > 0
            ? Text(
                '${widget.channel.viewers} viewers',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}

// ─── Embed WebView player (PPV / CDN fallback) ───────────────────────────────

class _LiveMatchesEmbedPlayerScreen extends StatefulWidget {
  final String embedUrl;
  final String title;
  final String? subtitle;
  final String badgeLabel;
  final String referer;
  final String origin;

  const _LiveMatchesEmbedPlayerScreen({
    required this.embedUrl,
    required this.title,
    this.subtitle,
    required this.badgeLabel,
    this.referer = _ppvReferer,
    this.origin = 'https://ppv.is',
  });

  @override
  State<_LiveMatchesEmbedPlayerScreen> createState() =>
      _LiveMatchesEmbedPlayerScreenState();
}

class _LiveMatchesEmbedPlayerScreenState
    extends State<_LiveMatchesEmbedPlayerScreen> {
  /// IPTV chrome helpers ([iptvTap] / [IptvRoundIcon]) register under this tab.
  static const _tvTabId = 'iptv';
  static const _topRowId = 'live-embed-top';
  static const _controlsRowId = 'live-embed-controls';

  bool _loading = true;
  bool _isFullscreen = false;
  bool _ready = false;
  bool _mediaStopped = false;
  bool _exiting = false;
  bool _playing = false;
  bool _muted = false;

  /// Android: cover the broken WebView lock UI while we sniff HLS for native.
  bool _androidNativeHandoff = false;
  bool _androidHandoffStarted = false;
  bool _androidFallbackStarted = false;

  /// Permanent failure — stop sniff/handoff and leave the route.
  bool _androidHandoffAbandoned = false;

  /// Last sniffed media/variant playlist if master was never seen.
  String? _androidVariantFallback;

  /// Streamed: `#EXTM3U` body captured from WebView (do not re-GET CDN).
  String? _androidCapturedPlaylistUrl;
  String? _androidCapturedPlaylistBody;

  /// Streamed: loopback front that fetches via WebView (Exo never hits CDN).
  LiveEmbedWebViewProxy? _streamedWebViewProxy;
  Timer? _loadingWatchdog;
  Timer? _adWindowCloseTimer;
  Timer? _androidHandoffWatchdog;
  Timer? _androidSniffPoll;
  InAppWebViewController? _webViewController;

  /// Native popup ([window.open]) from an ad. Accepted off-screen so Streamed
  /// embeds that require a successful open keep working; never shown in UI.
  int? _adWindowId;

  /// Catalog-origin iframe wrapper (`streamed.pk` / `ppv.is`) so
  /// `document.referrer` matches the website (issue 046). Streamed keeps the
  /// wrapper on Android. PPV embedindia uses top-level load + Referer header
  /// so sniff is same-origin under the cover overlay.
  late final InAppWebViewInitialData? _initialData;
  late final URLRequest? _initialUrlRequest;

  /// Per-provider Android technique (PPV ≠ Streamed). Never cross settings.
  late final LiveEmbedAndroidHandoffProfile _androidProfile;
  late final InAppWebViewSettings _initialSettings;
  late final UnmodifiableListView<UserScript> _initialUserScripts;

  final FocusNode _backFocusNode = FocusNode(debugLabel: 'live-embed-back');
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'live-embed-play');

  bool _tvFocus() =>
      ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;

  bool _focusEmbedRow(String rowId, [int index = 0]) {
    return iptvFocusRowItem(rowId, index);
  }

  /// WebView platform views steal D-pad on TV - keep focus on Flutter chrome.
  /// Prefer Play so Select starts playback; fall back to Back.
  void _focusTvChrome({bool preferPlay = true}) {
    if (!mounted || !_tvFocus() || _isFullscreen) return;
    if (preferPlay) {
      if (_focusEmbedRow(_controlsRowId, 0)) return;
      if (_playFocusNode.canRequestFocus) {
        _playFocusNode.requestFocus();
        return;
      }
    }
    if (_focusEmbedRow(_topRowId, 0)) return;
    if (_backFocusNode.canRequestFocus) _backFocusNode.requestFocus();
  }

  Future<void> _runEmbedMediaCmd(String cmd) async {
    final ctrl = _webViewController;
    if (ctrl == null || _mediaStopped || _exiting) return;
    try {
      await ctrl.evaluateJavascript(source: _embedMediaCommandJs(cmd));
    } catch (_) {}
  }

  Future<void> _togglePlayPause() async {
    if (_playing) {
      await _runEmbedMediaCmd('pause');
      if (mounted) setState(() => _playing = false);
    } else {
      await _runEmbedMediaCmd('play');
      if (mounted) setState(() => _playing = true);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _runEmbedMediaCmd(next ? 'mute' : 'unmute');
    if (mounted) setState(() => _muted = next);
  }

  void _clearLoading() {
    if (!mounted || !_loading) return;
    setState(() {
      _loading = false;
      _ready = true;
    });
  }

  void _dismissAdWindow() {
    _adWindowCloseTimer?.cancel();
    _adWindowCloseTimer = null;
    if (!mounted || _adWindowId == null) return;
    setState(() => _adWindowId = null);
  }

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    final embedUrl = widget.embedUrl;
    // Catalog-origin iframe wrapper so document.referrer matches the site
    // (issue 046). On Android, System WebView cannot play embeds in-page
    // (CORS + host lock) — sniff HLS (with cookies) and hand off to native.
    // Exo must treat `/hls-proxy` as HLS (MimeTypes.APPLICATION_M3U8).
    _androidNativeHandoff =
        !kIsWeb &&
        Platform.isAndroid &&
        liveEmbedAndroidNativeHandoff(embedUrl);
    // PPV and Streamed use different load + Referer strategies — pick once.
    _androidProfile = LiveEmbedAndroidHandoffProfile.forEmbed(embedUrl);
    if (_androidNativeHandoff) {
      debugPrint(
        '[LiveMatches] android strategy=${_androidProfile.logLabel} '
        'topLevel=${_androidProfile.topLevelEmbedLoad}',
      );
    }
    // Never enable InAppWebView Fetch/Ajax intercept (breaks embedindia
    // Request reuse + Streamed handshake). Sniff via shouldInterceptRequest
    // + media spy only — same for both providers.
    _initialUserScripts = UnmodifiableListView([
      UserScript(
        source: _stripIframeSandboxJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        // Inject into nested embed frames too — main-frame-only left sandbox
        // on the player iframe (red “Remove sandbox attributes…” lock UI).
        forMainFrameOnly: false,
      ),
      if (_androidNativeHandoff)
        UserScript(
          source: _liveEmbedMediaSpyJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      UserScript(
        source: _embedMediaControlUserScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
      UserScript(
        source: _autoplayJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ),
      UserScript(
        source: _dblclickFullscreenJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ),
    ]);

    // Windows WebView2 opacity still forced opaque via forjaWebViewSettings
    // (issue 053).
    final wrapperBase = widget.referer.endsWith('/')
        ? widget.referer
        : '${widget.referer}/';
    if (_androidNativeHandoff && _androidProfile.topLevelEmbedLoad) {
      // PPV-only: top-level embedindia + catalog Referer header.
      _initialData = null;
      _initialUrlRequest = URLRequest(
        url: WebUri(embedUrl),
        headers: {'Referer': wrapperBase, 'User-Agent': _ua['User-Agent']!},
      );
    } else {
      // Streamed (and desktop/iOS): catalog iframe wrapper.
      _initialUrlRequest = null;
      _initialData = InAppWebViewInitialData(
        data: _buildLiveEmbedWrapperHtml(embedUrl),
        baseUrl: WebUri(wrapperBase),
        historyUrl: WebUri(wrapperBase),
        mimeType: 'text/html',
        encoding: 'utf-8',
      );
    }
    _initialSettings = InAppWebViewSettings(
      userAgent: _ua['User-Agent'],
      domStorageEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      javaScriptEnabled: true,
      disableDefaultErrorPage: true,
      allowsAirPlayForMediaPlayback: true,
      // PiP can keep OS media sessions alive after the Flutter route pops.
      allowsPictureInPictureMediaPlayback: false,
      iframeAllow: 'autoplay; fullscreen; encrypted-media',
      iframeAllowFullscreen: true,
      useShouldOverrideUrlLoading: true,
      useOnLoadResource: _androidNativeHandoff,
      useShouldInterceptRequest: _androidNativeHandoff,
      // Never wrap page fetch/XHR via InAppWebView interceptors — breaks
      // embedindia (reused Request) and Streamed handshake.
      useShouldInterceptAjaxRequest: false,
      useShouldInterceptFetchRequest: false,
      // Accept window.open off-screen. Rejecting it falls back to main-frame
      // ad navigations that break Streamed HLS (manifestParsingError).
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      // Stream tokens / CDN often need third-party cookies from ad opens.
      thirdPartyCookiesEnabled: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      contentBlockers: _liveEmbedContentBlockers(),
    );
    // Clear the Flutter spinner early; iframe load / embedReady also clears it.
    // A long center spinner sits on top of the embed play button.
    _loadingWatchdog = Timer(const Duration(seconds: 2), _clearLoading);
    if (_androidNativeHandoff) {
      _androidHandoffWatchdog = Timer(const Duration(seconds: 22), () {
        if (!mounted || _androidHandoffStarted || _exiting) return;
        debugPrint('[LiveMatches] Android HLS sniff timed out');
        unawaited(_androidSniffTimeoutFallback());
      });
      // Keep nudging play + polling JW playlist / resource URLs while the
      // cover is up. embedindia often only XHRs HLS after muted JW play /
      // a synthetic center tap; playlist `file` may also be readable earlier.
      _androidSniffPoll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_pollAndroidSniffCandidates());
      });
      // First nudge ASAP — do not wait a full poll period for JW setup.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_pollAndroidSniffCandidates());
      });
    }
    HardwareKeyboard.instance.addHandler(_handleEmbedKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusTvChrome(preferPlay: true);
    });
  }

  void _onSniffedMediaUrl(String rawUrl) {
    if (!_androidNativeHandoff ||
        _androidHandoffStarted ||
        _androidHandoffAbandoned ||
        _androidFallbackStarted ||
        _exiting) {
      return;
    }
    final url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!_liveEmbedIsSniffableMediaUrl(url)) {
      final low = url.toLowerCase();
      if (low.contains('m3u8') ||
          low.contains('strmd') ||
          low.contains('indianservers') ||
          low.contains('/hls') ||
          low.contains('playlist') ||
          low.contains('/secure/')) {
        debugPrint('[LiveMatches] sniff rejected: $url');
      }
      return;
    }
    // Prefer master playlist over media/variant tracks when both appear.
    final low = url.toLowerCase();
    if (low.contains('/tracks-') || low.contains('mono.ts.m3u8')) {
      debugPrint('[LiveMatches] sniff defer variant: $url');
      // Still accept if nothing better arrives before timeout — stash as fallback.
      _androidVariantFallback ??= url;
      return;
    }
    _androidHandoffStarted = true;
    _androidHandoffWatchdog?.cancel();
    _androidSniffPoll?.cancel();
    debugPrint('[LiveMatches] Android sniffed media: $url');
    if (_androidProfile.isStreamed) {
      // New path: wait briefly for captured playlist body, never /hls-proxy probe.
      unawaited(_handOffStreamedNative(url));
    } else {
      unawaited(_handOffToNativePlayer(url));
    }
  }

  void _onCapturedPlaylist(String rawUrl, String body) {
    // Do **not** gate on `_exiting`: Streamed handoff sets exiting while still
    // waiting for the in-flight `#EXTM3U` body (URL often sniffs first).
    if (!_androidNativeHandoff ||
        _androidHandoffAbandoned ||
        _androidFallbackStarted) {
      return;
    }
    final url = rawUrl.trim();
    final text = body.trimLeft();
    if (url.isEmpty || !text.startsWith('#EXTM3U')) return;
    if (!_liveEmbedIsSniffableMediaUrl(url)) return;
    final low = url.toLowerCase();
    if (low.contains('/tracks-') || low.contains('mono.ts.m3u8')) {
      // Prefer master; keep variant body only if nothing better lands.
      if (_androidCapturedPlaylistBody == null) {
        _androidCapturedPlaylistUrl = url;
        _androidCapturedPlaylistBody = text;
        _androidVariantFallback ??= url;
      }
      return;
    }
    _androidCapturedPlaylistUrl = url;
    _androidCapturedPlaylistBody = text;
    debugPrint(
      '[LiveMatches] captured playlist body '
      '(${text.length} chars) $url',
    );
    // Kick handoff if sniff URL never arrived (body-only path).
    if (!_androidHandoffStarted) {
      _onSniffedMediaUrl(url);
    }
  }

  Future<void> _pollAndroidSniffCandidates() async {
    if (!_androidNativeHandoff ||
        _androidHandoffStarted ||
        _androidHandoffAbandoned ||
        _androidFallbackStarted ||
        _exiting ||
        !mounted) {
      return;
    }
    final ctrl = _webViewController;
    if (ctrl == null) return;
    try {
      // Mute-first JW / center-tap play — cover hides video; audio must stay off.
      // Playlist may already be in jwplayer config before play succeeds.
      await ctrl.evaluateJavascript(source: _embedMediaCommandJs('mute'));
      await ctrl.evaluateJavascript(source: _autoplayJs);
      await ctrl.evaluateJavascript(source: _embedMediaCommandJs('play'));
      final raw = await ctrl.evaluateJavascript(source: _liveEmbedSniffPollJs);
      if (raw is List) {
        for (final item in raw) {
          _onSniffedMediaUrl(item.toString());
          if (_androidHandoffStarted) return;
        }
      } else if (raw is String && raw.isNotEmpty && raw != 'null') {
        // Some platforms JSON-encode the JS array as a string.
        final trimmed = raw.trim();
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              for (final item in decoded) {
                _onSniffedMediaUrl(item.toString());
                if (_androidHandoffStarted) return;
              }
            }
          } catch (_) {
            _onSniffedMediaUrl(trimmed);
          }
        } else {
          _onSniffedMediaUrl(trimmed);
        }
      }
    } catch (_) {}
  }

  /// Visible WebView sniff failed. Try variant fallback, then StreamExtractor
  /// on phone. On Android TV headless WebView is blocked — exit with a toast.
  Future<void> _androidSniffTimeoutFallback() async {
    if (_androidHandoffAbandoned ||
        _androidHandoffStarted ||
        _exiting ||
        _androidFallbackStarted) {
      return;
    }
    final variant = _androidVariantFallback;
    if (variant != null && variant.isNotEmpty) {
      debugPrint('[LiveMatches] Android sniff timeout → variant fallback');
      _androidHandoffStarted = true;
      _androidSniffPoll?.cancel();
      await _handOffToNativePlayer(variant);
      return;
    }
    _androidFallbackStarted = true;
    _androidSniffPoll?.cancel();

    final blockedOnTv =
        !kIsWeb && Platform.isAndroid && isAndroidTvHeadlessWebViewBlocked;
    if (!blockedOnTv) {
      debugPrint('[LiveMatches] Android sniff timeout → StreamExtractor');
      try {
        final extracted = await StreamExtractor().extract(
          widget.embedUrl,
          referer: widget.referer,
          // Match visible WebView: PPV top-level; Streamed keeps wrapper.
          iframeWrapperBaseUrl: _androidProfile.topLevelEmbedLoad
              ? null
              : widget.referer,
          timeout: const Duration(seconds: 22),
          isCancelled: () => _exiting || !mounted,
        );
        if (extracted != null &&
            extracted.url.isNotEmpty &&
            mounted &&
            !_exiting &&
            !_androidHandoffStarted) {
          _androidHandoffStarted = true;
          final url = extracted.url;
          // Already proxied by some extract paths — still run handoff headers
          // when it looks like a raw CDN playlist.
          if (url.contains('/hls-proxy')) {
            debugPrint('[LiveMatches] Android extract → $url');
            if (!mounted) return;
            final title = widget.title;
            final subtitle = widget.subtitle;
            final label = widget.badgeLabel;
            _exiting = true;
            _mediaStopped = true;
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => IptvPtPlayerScreen(
                  sources: [IptvPlaySource(url: url, label: label)],
                  title: title,
                  subtitle: subtitle,
                  engineContext: BuiltInPlayerContext.live,
                ),
              ),
            );
            return;
          }
          await _handOffToNativePlayer(url);
          return;
        }
      } catch (e) {
        debugPrint('[LiveMatches] Android extract fallback failed: $e');
      }
    } else {
      debugPrint(
        '[LiveMatches] Android TV sniff timeout (headless extract blocked)',
      );
    }

    if (!mounted || _exiting || _androidHandoffStarted) return;
    _androidHandoffAbandoned = true;
    ForjaToast.info('Could not open this stream');
    unawaited(_exitPlayer(force: true));
  }

  Future<void> _abandonAndroidHandoff(String reason) async {
    if (_androidHandoffAbandoned) return;
    _androidHandoffAbandoned = true;
    _androidFallbackStarted = true;
    _androidSniffPoll?.cancel();
    _androidHandoffWatchdog?.cancel();
    debugPrint('[LiveMatches] abandon handoff: $reason');
    if (!mounted) return;
    ForjaToast.info('Could not open this stream');
    await _exitPlayer(force: true);
  }

  /// Proxy Referer/Origin — PPV only (Streamed no longer uses `/hls-proxy`).
  Map<String, String> _androidProxyHeadersForAttempt(int attempt) {
    switch (_androidProfile.kind) {
      case LiveEmbedProviderKind.ppv:
        // Always full embedindia URL — catalog-only Referer 403s the CDN.
        return _ppvEmbedStreamHeaders(widget.embedUrl);
      case LiveEmbedProviderKind.streamed:
        final useCatalog = attempt == 1 || attempt == 3;
        return _liveEmbedStreamHeaders(
          widget.embedUrl,
          catalogReferer: useCatalog ? widget.referer : null,
        );
    }
  }

  /// When CORS hides `#EXTM3U` from the JS spy, re-GET with WebView cookies.
  Future<String?> _trySeedStreamedPlaylistBody(
    String mediaUrl, {
    int maxAttempts = 3,
  }) async {
    HttpClient? client;
    try {
      final attempts = maxAttempts < 1 ? 1 : maxAttempts;
      for (var attempt = 1; attempt <= attempts; attempt++) {
        if (_androidHandoffAbandoned || !mounted) return null;
        final headers = Map<String, String>.from(
          _androidProxyHeadersForAttempt(attempt),
        );
        final cookie = await _liveEmbedCollectCookieHeader(
          embedUrl: widget.embedUrl,
          streamUrl: mediaUrl,
          catalogReferer: widget.referer,
        );
        if (cookie != null && cookie.isNotEmpty) {
          headers['Cookie'] = cookie;
        }
        client?.close(force: true);
        client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        final req = await client.getUrl(Uri.parse(mediaUrl));
        headers.forEach(req.headers.set);
        final resp = await req.close().timeout(const Duration(seconds: 10));
        final text = await resp.transform(utf8.decoder).join();
        if (resp.statusCode < 400 && text.trimLeft().startsWith('#EXTM3U')) {
          debugPrint(
            '[LiveMatches] streamed playlist seeded via Dart '
            '(attempt $attempt, ${text.length} chars)',
          );
          return text;
        }
        final snip = text.length > 60 ? text.substring(0, 60) : text;
        debugPrint(
          '[LiveMatches] streamed seed attempt $attempt '
          'status=${resp.statusCode} body=${snip.replaceAll('\n', ' ')}',
        );
        if (attempt < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
        }
      }
    } catch (e) {
      debugPrint('[LiveMatches] streamed playlist seed failed: $e');
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  /// Streamed Android/ATV: Exo never hits `strmd.st` directly (OkHttp 403s).
  /// Capture `#EXTM3U` from WebView → local WebView-fetch proxy → Exo on
  /// loopback. Keep this route mounted under the player so Chromium can fetch.
  Future<void> _handOffStreamedNative(String mediaUrl) async {
    if (_androidHandoffAbandoned) return;
    // Do not set `_exiting` until the playlist body is ready — the spy still
    // needs to deliver `liveMediaPlaylist` after the URL sniff.
    _loadingWatchdog?.cancel();
    _androidHandoffWatchdog?.cancel();
    _androidSniffPoll?.cancel();

    // Wait for body BEFORE pausing — pause can cancel an in-flight HLS fetch.
    for (var i = 0; i < 50; i++) {
      if (_androidCapturedPlaylistBody != null &&
          _androidCapturedPlaylistBody!.trimLeft().startsWith('#EXTM3U')) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted || _androidHandoffAbandoned) return;
    }

    final capturedUrl = _androidCapturedPlaylistUrl ?? mediaUrl;
    var body = _androidCapturedPlaylistBody;

    // Last chance: ask the embed iframe to re-fetch the playlist via Chromium.
    if (body == null || !body.trimLeft().startsWith('#EXTM3U')) {
      debugPrint(
        '[LiveMatches] streamed: no captured body yet — waiting on proxy seed',
      );
      // Soft nudge play once more so HLS.js refetches, then wait again.
      try {
        await _webViewController?.evaluateJavascript(
          source: _embedMediaCommandJs('mute'),
        );
        await _webViewController?.evaluateJavascript(
          source: _embedMediaCommandJs('play'),
        );
      } catch (_) {}
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (_androidCapturedPlaylistBody != null &&
            _androidCapturedPlaylistBody!.trimLeft().startsWith('#EXTM3U')) {
          body = _androidCapturedPlaylistBody;
          break;
        }
        if (!mounted || _androidHandoffAbandoned) return;
      }
    }

    // CORS often hides the body from JS. Seed inside Chromium (same path Exo
    // will use) — Dart/OkHttp re-GETs of strmd.st almost always 403.
    final proxy = LiveEmbedWebViewProxy();
    proxy.attachController(_webViewController);
    _streamedWebViewProxy = proxy;
    if (body == null || !body.trimLeft().startsWith('#EXTM3U')) {
      debugPrint('[LiveMatches] streamed: seeding playlist via WebView fetch');
      body = await proxy.fetchPlaylistText(capturedUrl);
      if (body != null) {
        _androidCapturedPlaylistUrl = capturedUrl;
        _androidCapturedPlaylistBody = body;
      }
    }

    // Rare: cookie jar sometimes works when Chromium CORS fails entirely.
    if (body == null || !body.trimLeft().startsWith('#EXTM3U')) {
      body = await _trySeedStreamedPlaylistBody(capturedUrl);
      if (body != null) {
        _androidCapturedPlaylistUrl = capturedUrl;
        _androidCapturedPlaylistBody = body;
      }
    }

    if (body == null || !body.trimLeft().startsWith('#EXTM3U')) {
      // Last resort: classic Cookie + `/hls-proxy` (may still 403 on some CDNs).
      debugPrint(
        '[LiveMatches] streamed: no body — falling back to /hls-proxy',
      );
      await _streamedWebViewProxy?.stop();
      _streamedWebViewProxy = null;
      await _handOffStreamedViaHlsProxy(capturedUrl);
      return;
    }

    final playlistBody = body;
    _exiting = true;
    _mediaStopped = true;
    try {
      await _webViewController?.evaluateJavascript(
        source: _embedMediaCommandJs('pause'),
      );
    } catch (_) {}

    try {
      await proxy.start(
        playlistBody: playlistBody,
        playlistSourceUrl: capturedUrl,
      );
    } catch (e) {
      debugPrint('[LiveMatches] WebView proxy start failed: $e');
      await proxy.stop();
      _streamedWebViewProxy = null;
      await _abandonAndroidHandoff('streamed: proxy start failed');
      return;
    }
    if (proxy.playlistUrl.isEmpty) {
      await proxy.stop();
      _streamedWebViewProxy = null;
      await _abandonAndroidHandoff('streamed: proxy has no port');
      return;
    }

    if (!mounted || _androidHandoffAbandoned) {
      await proxy.stop();
      _streamedWebViewProxy = null;
      return;
    }

    final playUrl = proxy.playlistUrl;
    debugPrint(
      '[LiveMatches] streamed Android handoff (webview-proxy) → $playUrl',
    );
    final title = widget.title;
    final subtitle = widget.subtitle;
    final label = widget.badgeLabel;
    // Keep WebView for Chromium CDN fetches, but block leanback focus so Exo
    // chrome receives D-pad (issue 131).
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
    }
    if (!mounted || _androidHandoffAbandoned) {
      await proxy.stop();
      _streamedWebViewProxy = null;
      return;
    }
    // push (not replacement): keep WebView alive for Chromium CDN fetches.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen(
          sources: [IptvPlaySource(url: playUrl, label: label)],
          title: title,
          subtitle: subtitle,
          engineContext: BuiltInPlayerContext.live,
        ),
      ),
    );
    // Player popped — tear down proxy + embed.
    await _streamedWebViewProxy?.stop();
    _streamedWebViewProxy = null;
    if (mounted) {
      await _exitPlayer(force: true);
    }
  }

  /// Streamed fallback when `#EXTM3U` body never lands — Cookie + `/hls-proxy`.
  Future<void> _handOffStreamedViaHlsProxy(String mediaUrl) async {
    if (_androidHandoffAbandoned) return;
    _exiting = true;
    _mediaStopped = true;
    try {
      await _webViewController?.evaluateJavascript(
        source: _embedMediaCommandJs('pause'),
      );
    } catch (_) {}

    await Future<void>.delayed(_androidProfile.cookieSettle);
    if (!mounted || _androidHandoffAbandoned) return;

    String? playUrl;
    final maxAttempts = _androidProfile.maxProbeAttempts;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_androidHandoffAbandoned || !mounted) return;
      final headers = Map<String, String>.from(
        _androidProxyHeadersForAttempt(attempt),
      );
      final cookie = await _liveEmbedCollectCookieHeader(
        embedUrl: widget.embedUrl,
        streamUrl: mediaUrl,
        catalogReferer: widget.referer,
      );
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      } else {
        debugPrint(
          '[LiveMatches] streamed /hls-proxy attempt $attempt: no cookies yet',
        );
      }
      playUrl = mediaUrl;
      try {
        final proxy = LocalServerService();
        await proxy.start();
        if (proxy.port > 0) {
          playUrl = proxy.getHlsProxyUrl(mediaUrl, headers);
        }
      } catch (e) {
        debugPrint('[LiveMatches] streamed HLS proxy failed: $e');
      }
      if (playUrl == null || !playUrl.contains('/hls-proxy')) {
        break;
      }
      final ok = await _probeHlsProxyPlaylist(playUrl);
      if (ok) break;
      debugPrint(
        '[LiveMatches] streamed HLS proxy probe failed '
        '(attempt $attempt/$maxAttempts)',
      );
      playUrl = null;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
        if (!mounted || _androidHandoffAbandoned) return;
      }
    }

    if (playUrl == null || playUrl.isEmpty) {
      await _abandonAndroidHandoff('streamed: body + /hls-proxy exhausted');
      return;
    }

    debugPrint('[LiveMatches] streamed Android handoff (/hls-proxy) → $playUrl');
    if (!mounted || _androidHandoffAbandoned) return;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final label = widget.badgeLabel;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen(
          sources: [IptvPlaySource(url: playUrl!, label: label)],
          title: title,
          subtitle: subtitle,
          engineContext: BuiltInPlayerContext.live,
        ),
      ),
    );
  }

  /// PPV Android handoff: Cookie harvest + `/hls-proxy` + probe (unchanged).
  Future<void> _handOffToNativePlayer(String mediaUrl) async {
    if (_exiting || _androidHandoffAbandoned) return;
    if (_androidProfile.isStreamed) {
      await _handOffStreamedNative(mediaUrl);
      return;
    }
    _exiting = true;
    _mediaStopped = true;
    _loadingWatchdog?.cancel();
    _androidHandoffWatchdog?.cancel();
    _androidSniffPoll?.cancel();
    try {
      await _webViewController?.evaluateJavascript(
        source: _embedMediaCommandJs('pause'),
      );
    } catch (_) {}

    await Future<void>.delayed(_androidProfile.cookieSettle);
    if (!mounted || _androidHandoffAbandoned) return;

    String? playUrl;
    final maxAttempts = _androidProfile.maxProbeAttempts;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_androidHandoffAbandoned || !mounted) return;
      final headers = Map<String, String>.from(
        _androidProxyHeadersForAttempt(attempt),
      );
      final cookie = await _liveEmbedCollectCookieHeader(
        embedUrl: widget.embedUrl,
        streamUrl: mediaUrl,
        catalogReferer: widget.referer,
      );
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      } else {
        debugPrint(
          '[LiveMatches] ${_androidProfile.logLabel} handoff attempt '
          '$attempt: no cookies yet',
        );
      }
      playUrl = mediaUrl;
      try {
        final proxy = LocalServerService();
        await proxy.start();
        if (proxy.port > 0) {
          playUrl = proxy.getHlsProxyUrl(mediaUrl, headers);
        }
      } catch (e) {
        debugPrint('[LiveMatches] HLS proxy failed: $e');
      }
      if (playUrl == null || !playUrl.contains('/hls-proxy')) {
        break;
      }
      final ok = await _probeHlsProxyPlaylist(playUrl);
      if (ok) break;
      debugPrint(
        '[LiveMatches] ${_androidProfile.logLabel} HLS proxy probe failed '
        '(attempt $attempt/$maxAttempts)',
      );
      playUrl = null;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
        if (!mounted || _androidHandoffAbandoned) return;
      }
    }

    if (playUrl == null || playUrl.isEmpty) {
      await _abandonAndroidHandoff(
        '${_androidProfile.logLabel} probe exhausted',
      );
      return;
    }

    debugPrint('[LiveMatches] Android handoff → $playUrl');
    if (!mounted || _androidHandoffAbandoned) return;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final label = widget.badgeLabel;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen(
          sources: [IptvPlaySource(url: playUrl!, label: label)],
          title: title,
          subtitle: subtitle,
          engineContext: BuiltInPlayerContext.live,
        ),
      ),
    );
  }

  /// Confirm the local proxy returns a real `#EXTM3U` body (Cookie/Referer OK).
  Future<bool> _probeHlsProxyPlaylist(String playUrl) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(playUrl));
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await resp.transform(utf8.decoder).join();
      final ok = resp.statusCode < 400 && body.trimLeft().startsWith('#EXTM3U');
      if (!ok) {
        final snip = body.length > 80 ? body.substring(0, 80) : body;
        debugPrint(
          '[LiveMatches] HLS probe status=${resp.statusCode} body=${snip.replaceAll('\n', ' ')}',
        );
      }
      return ok;
    } catch (e) {
      debugPrint('[LiveMatches] HLS probe error: $e');
      // Soft-fail: still hand off — Exo may succeed where the probe flaked.
      return true;
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _enterFullscreen() async {
    if (DesktopWindowChrome.isDesktop) {
      try {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
        await windowManager.setFullScreen(true);
      } catch (_) {}
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
    }
    if (mounted) setState(() => _isFullscreen = true);
  }

  Future<void> _exitFullscreen() async {
    if (DesktopWindowChrome.isDesktop) {
      try {
        await windowManager.setFullScreen(false);
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
      } catch (_) {}
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([]);
    }
    if (mounted) {
      setState(() => _isFullscreen = false);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusTvChrome(preferPlay: true),
      );
    }
  }

  Future<void> _toggleFullscreen() async {
    if (DesktopWindowChrome.isDesktop) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (isFull) {
          await _exitFullscreen();
        } else {
          await _enterFullscreen();
        }
      } catch (_) {
        if (_isFullscreen) {
          await _exitFullscreen();
        } else {
          await _enterFullscreen();
        }
      }
      return;
    }
    if (_isFullscreen) {
      await _exitFullscreen();
    } else {
      await _enterFullscreen();
    }
  }

  /// Stop HTML5 / iframe media. Timeouts are mandatory - WebView JS/IPC can
  /// hang forever while HLS is playing, which blocked [Navigator.pop].
  Future<void> _stopEmbedMedia() async {
    if (_mediaStopped) return;
    _mediaStopped = true;
    _dismissAdWindow();
    final controller = _webViewController;
    _webViewController = null;
    if (controller == null) return;
    try {
      await controller
          .evaluateJavascript(source: _stopEmbedMediaJs)
          .timeout(const Duration(milliseconds: 400));
    } catch (_) {}
    try {
      await controller.stopLoading();
    } catch (_) {}
    try {
      await controller
          .loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')))
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    // Do not dispose the controller here - [InAppWebView] is still mounted
    // until the route pops; disposing early can hang the platform view.
  }

  Future<void> _exitPlayer({bool force = false}) async {
    if (_exiting && !force) return;
    _exiting = true;
    _androidHandoffAbandoned = true;
    _androidSniffPoll?.cancel();
    _androidHandoffWatchdog?.cancel();
    unawaited(_streamedWebViewProxy?.stop());
    _streamedWebViewProxy = null;
    if (_isFullscreen) {
      unawaited(_exitFullscreen());
    }
    // Cap wait so a stuck WebView never prevents leaving the player.
    try {
      await _stopEmbedMedia().timeout(const Duration(milliseconds: 700));
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    ShellBus.leavePlayerSurface();
    _loadingWatchdog?.cancel();
    _adWindowCloseTimer?.cancel();
    _androidHandoffWatchdog?.cancel();
    _androidSniffPoll?.cancel();
    unawaited(_streamedWebViewProxy?.stop());
    _streamedWebViewProxy = null;
    _backFocusNode.dispose();
    _playFocusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_handleEmbedKeyEvent);
    // Route may dispose without going through [_exitPlayer] (e.g. pushReplacement).
    unawaited(_stopEmbedMedia());
    if (DesktopWindowChrome.isDesktop) {
      Future.microtask(() async {
        try {
          if (await windowManager.isFullScreen()) {
            await windowManager.setFullScreen(false);
          }
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          }
        } catch (_) {}
      });
    } else {
      SystemChrome.setPreferredOrientations([]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    super.dispose();
  }

  bool _handleEmbedKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape &&
        event.logicalKey != LogicalKeyboardKey.goBack &&
        event.logicalKey != LogicalKeyboardKey.browserBack) {
      return false;
    }
    if (_isFullscreen) {
      unawaited(_exitFullscreen());
      return true;
    }
    unawaited(_exitPlayer());
    return true;
  }

  double _topBarTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 8;
    }
    return MediaQuery.paddingOf(context).top + 8;
  }

  Widget _buildSourceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue),
      ),
      child: Text(
        widget.badgeLabel,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final tv = _tvFocus();
    final bar = Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, _topBarTopPadding(context), 72, 16),
        child: Row(
          children: [
            // Opaque hit target - WKWebView/WebView2 steal taps when chrome is
            // only painted over the platform view (macOS especially).
            Listener(
              behavior: HitTestBehavior.opaque,
              child: iptvBackButton(
                context,
                onTap: () => unawaited(_exitPlayer()),
                color: Colors.white,
                size: 26,
                focusNode: _backFocusNode,
                tvRowId: _topRowId,
                tvItemIndex: 0,
                onDownEdge: () => _focusEmbedRow(_controlsRowId, 0),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IptvShellStyle.overlayTitle,
                  ),
                  if ((widget.subtitle ?? '').isNotEmpty)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!tv) return bar;
    return TvCatalogRow(
      tabId: _tvTabId,
      rowId: _topRowId,
      sortOrder: 0,
      itemCount: 1,
      child: FocusScope(
        debugLabel: 'live-embed-chrome',
        child: FocusTraversalGroup(child: bar),
      ),
    );
  }

  /// TV-only bottom chrome: Play/Pause · Mute (WebView steals D-pad).
  /// Fullscreen is omitted on TV — the player is already immersive.
  Widget _buildTvControls() {
    void upToBack() => _focusEmbedRow(_topRowId, 0);
    final row = Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Row(
          children: [
            IptvRoundIcon(
              icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              big: true,
              focusNode: _playFocusNode,
              tvRowId: _controlsRowId,
              tvItemIndex: 0,
              onUpEdge: upToBack,
              onRightEdge: () => _focusEmbedRow(_controlsRowId, 1),
              onTap: () => unawaited(_togglePlayPause()),
            ),
            const SizedBox(width: 14),
            IptvRoundIcon(
              icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tvRowId: _controlsRowId,
              tvItemIndex: 1,
              onUpEdge: upToBack,
              onLeftEdge: () => _focusEmbedRow(_controlsRowId, 0),
              onTap: () => unawaited(_toggleMute()),
            ),
          ],
        ),
      ),
    );
    return TvCatalogRow(
      tabId: _tvTabId,
      rowId: _controlsRowId,
      sortOrder: 1,
      itemCount: 2,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = widget.embedUrl;
    // Keep the WebView *below* the chrome so the platform view cannot steal
    // Back taps (overlay-on-WKWebView is unreliable on desktop).
    final Widget? chrome = !_isFullscreen
        ? ColoredBox(
            color: Colors.black,
            child: Stack(
              children: [
                _buildTopBar(),
                Positioned(
                  top: _topBarTopPadding(context),
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Desktop / phone: embeds often start muted (autoplay
                      // policy). TV has Mute in the bottom chrome instead.
                      if (!_tvFocus()) ...[
                        IptvRoundIcon(
                          icon: _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          onTap: () => unawaited(_toggleMute()),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _buildSourceBadge(),
                    ],
                  ),
                ),
              ],
            ),
          )
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isFullscreen) {
          await _exitFullscreen();
          return;
        }
        await _exitPlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(
          builder: (context) {
            Widget body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?chrome,
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ForjaInAppWebView(
                        // Catalog iframe (Streamed) vs PPV top-level embedindia —
                        // chosen by [_androidProfile], never cross-applied.
                        initialData: _initialData,
                        initialUrlRequest: _initialUrlRequest,
                        initialUserScripts: _initialUserScripts,
                        initialSettings: _initialSettings,
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                          controller.addJavaScriptHandler(
                            handlerName: 'toggleFullscreen',
                            callback: (_) {
                              unawaited(_toggleFullscreen());
                            },
                          );
                          controller.addJavaScriptHandler(
                            handlerName: 'embedReady',
                            callback: (_) {
                              _loadingWatchdog?.cancel();
                              _clearLoading();
                            },
                          );
                          if (_androidNativeHandoff) {
                            controller.addJavaScriptHandler(
                              handlerName: 'liveMediaUrl',
                              callback: (args) {
                                if (args.isEmpty) return null;
                                _onSniffedMediaUrl(args.first.toString());
                                return null;
                              },
                            );
                            controller.addJavaScriptHandler(
                              handlerName: 'liveMediaPlaylist',
                              callback: (args) {
                                if (args.length < 2) return null;
                                _onCapturedPlaylist(
                                  args[0].toString(),
                                  args[1].toString(),
                                );
                                return null;
                              },
                            );
                            controller.addJavaScriptHandler(
                              handlerName: 'liveProxyFetchResult',
                              callback: (args) {
                                if (args.length < 3) return null;
                                final id = args[0].toString();
                                final status =
                                    int.tryParse(args[1].toString()) ?? 0;
                                final b64 = args[2].toString();
                                final ct = args.length > 3
                                    ? args[3].toString()
                                    : '';
                                _streamedWebViewProxy?.onFetchResult(
                                  id,
                                  status,
                                  b64,
                                  ct,
                                );
                                return null;
                              },
                            );
                          }
                        },
                        onLoadResource: _androidNativeHandoff
                            ? (ctrl, resource) {
                                _onSniffedMediaUrl(resource.url.toString());
                              }
                            : null,
                        shouldInterceptRequest: _androidNativeHandoff
                            ? (ctrl, request) async {
                                final u = request.url.toString();
                                _onSniffedMediaUrl(u);
                                // Observe only — never await a Dart re-GET here.
                                // Streamed CDN 403s OkHttp, and blocking this
                                // callback delays Chromium's own playlist fetch
                                // until handoff has already given up on the body.
                                return null;
                              }
                            : null,
                        shouldInterceptAjaxRequest: null,
                        shouldInterceptFetchRequest: null,
                        onReceivedHttpError: _androidNativeHandoff
                            ? (ctrl, request, response) {
                                final u = request.url.toString();
                                // CORS / 403 on the playlist still exposes the URL.
                                _onSniffedMediaUrl(u);
                              }
                            : null,
                        onLoadStart: (_, _) {
                          // Ad main-frame hijack attempts can fire load-start; do not
                          // setState after the player is ready (rebuild churn + WK crash).
                          if (!mounted || _ready || _loading) return;
                          setState(() => _loading = true);
                        },
                        onLoadStop: (ctrl, _) async {
                          // Ignore about:blank teardown loads after exit started.
                          if (_mediaStopped || _exiting) return;
                          _loadingWatchdog?.cancel();
                          _clearLoading();
                          try {
                            await ctrl.evaluateJavascript(
                              source: _embedMediaControlUserScript,
                            );
                            if (_androidNativeHandoff) {
                              await ctrl.evaluateJavascript(
                                source: _liveEmbedMediaSpyJs,
                              );
                              // Sniffer only — keep silent under the handoff cover.
                              // Mute → force play (JW API + center tap) so PPV
                              // XHRs the playlist under the opaque cover.
                              await ctrl.evaluateJavascript(
                                source: _embedMediaCommandJs('mute'),
                              );
                              await ctrl.evaluateJavascript(
                                source: _autoplayJs,
                              );
                              await ctrl.evaluateJavascript(
                                source: _embedMediaCommandJs('play'),
                              );
                            } else {
                              await ctrl.evaluateJavascript(
                                source: _autoplayJs,
                              );
                            }
                            await ctrl.evaluateJavascript(
                              source: _dblclickFullscreenJs,
                            );
                            // Opening the match is a user gesture — force unmute after
                            // autoplay's muted fallback so MutStreams / JW are not stuck
                            // on "CLICK UNMUTE STREAM". Android sniff stays muted under
                            // the handoff cover. TV Mute chrome can still remute.
                            if (!_androidNativeHandoff) {
                              await ctrl.evaluateJavascript(
                                source: _embedMediaCommandJs('unmute'),
                              );
                              await ctrl.evaluateJavascript(
                                source: _embedMediaCommandJs('play'),
                              );
                            }
                            if (mounted) setState(() => _playing = true);
                          } catch (_) {}
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _focusTvChrome(preferPlay: true),
                          );
                        },
                        onEnterFullscreen: (_) => unawaited(_enterFullscreen()),
                        onExitFullscreen: (_) => unawaited(_exitFullscreen()),
                        onCreateWindow: (_, action) async {
                          // Keep a single hidden child; ignore extra ad spawns.
                          if (!mounted || _adWindowId != null) return false;
                          setState(() => _adWindowId = action.windowId);
                          _adWindowCloseTimer?.cancel();
                          _adWindowCloseTimer = Timer(
                            const Duration(seconds: 4),
                            _dismissAdWindow,
                          );
                          return true;
                        },
                        shouldOverrideUrlLoading: (ctrl, action) async {
                          // Player CDNs and nested iframes leave embed.st - never cancel
                          // subframe navigations (that caused blank/white players).
                          if (action.isForMainFrame != true) {
                            final sub = action.request.url?.toString() ?? '';
                            if (_androidNativeHandoff) {
                              _onSniffedMediaUrl(sub);
                            }
                            return NavigationActionPolicy.ALLOW;
                          }
                          final url = action.request.url?.toString() ?? '';
                          if (liveEmbedAllowsMainFrameNavigation(
                            url: url,
                            embedUrl: embedUrl,
                            allowEmbedHostAsMainFrame:
                                _androidProfile.allowEmbedHostAsMainFrame,
                            wrapperReferer: widget.referer,
                          )) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          debugPrint(
                            '[LiveMatches] blocked main-frame nav: $url',
                          );
                          return NavigationActionPolicy.CANCEL;
                        },
                      ),
                      // Android: keep this cover for the whole sniffer route.
                      // Tying it to !_androidHandoffStarted uncovered JW mid-probe
                      // (multi-cam PiP + audio) before pushReplacement to native.
                      // IgnorePointer: phone taps pass through so JW gets a real
                      // gesture under the opaque cover; ATV relies on JS play nudge.
                      if (_androidNativeHandoff)
                        const IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: ForjaShellColors.sectionAccent,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Opening stream…',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Handing off to the native player',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_loading && !_androidNativeHandoff)
                        Positioned(
                          top: 12,
                          right: 16,
                          child: IgnorePointer(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: ForjaShellColors.sectionAccent,
                              ),
                            ),
                          ),
                        ),
                      // Off-screen host for ad window.open - required by some Streamed
                      // embeds; never visible.
                      if (_adWindowId != null)
                        Positioned(
                          left: -2,
                          top: -2,
                          width: 1,
                          height: 1,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0,
                              child: InAppWebView(
                                windowId: _adWindowId,
                                initialSettings: forjaWebViewSettings(
                                  InAppWebViewSettings(
                                    transparentBackground: true,
                                    supportMultipleWindows: false,
                                    javaScriptCanOpenWindowsAutomatically:
                                        false,
                                  ),
                                ),
                                onCloseWindow: (_) => _dismissAdWindow(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_tvFocus() && !_isFullscreen) _buildTvControls(),
              ],
            );
            if (_tvFocus()) {
              body = TvFocusGraph(tabId: _tvTabId, child: body);
            }
            return body;
          },
        ),
      ),
    );
  }
}

// ─── Streamed stream sheet ────────────────────────────────────────────────────

class _MergedMatchStreamSheet extends StatefulWidget {
  const _MergedMatchStreamSheet({
    required this.title,
    required this.ppv,
    required this.streamed,
    required this.onPpvSelected,
    required this.onStreamedSelected,
  });

  final String title;
  final _DamiTvStream? ppv;
  final List<_StreamedStream> streamed;
  final VoidCallback onPpvSelected;
  final ValueChanged<_StreamedStream> onStreamedSelected;

  @override
  State<_MergedMatchStreamSheet> createState() =>
      _MergedMatchStreamSheetState();
}

class _MergedMatchStreamSheetState extends State<_MergedMatchStreamSheet> {
  static const _rowId = 'live-merged-stream-sheet';
  final FocusNode _firstFocus = FocusNode(
    debugLabel: 'live-merged-stream-sheet-first',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.streamed]
      ..sort((a, b) => b.viewers.compareTo(a.viewers));
    final count = sorted.length + (widget.ppv == null ? 0 : 1);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final streamedOffset = widget.ppv == null ? 0 : 1;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.title,
            style: const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${count == 1 ? 'stream' : 'streams'}',
            style: const TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (widget.ppv != null)
                    _MergedPpvStreamRow(
                      stream: widget.ppv!,
                      onTap: widget.onPpvSelected,
                      tvItemIndex: 0,
                      tvRowId: _rowId,
                      focusNode: _firstFocus,
                    ),
                  for (var i = 0; i < sorted.length; i++)
                    _StreamedStreamRow(
                      stream: sorted[i],
                      sourceLabel: _StreamedStreamSheet.sourceLabel(
                        sorted[i].source,
                      ),
                      serverLabel: 'Streamed',
                      onTap: () => widget.onStreamedSelected(sorted[i]),
                      tvItemIndex: streamedOffset + i,
                      tvRowId: _rowId,
                      focusNode: widget.ppv == null && i == 0
                          ? _firstFocus
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (!tv) return body;
    return TvCatalogRow(
      tabId: 'live_matches',
      rowId: _rowId,
      sortOrder: 0,
      itemCount: count,
      orientation: ShellTvRowOrientation.vertical,
      child: body,
    );
  }
}

class _MergedPpvStreamRow extends StatefulWidget {
  const _MergedPpvStreamRow({
    required this.stream,
    required this.onTap,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final _DamiTvStream stream;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<_MergedPpvStreamRow> createState() => _MergedPpvStreamRowState();
}

class _MergedPpvStreamRowState extends State<_MergedPpvStreamRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 10,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_outline,
              size: 20,
              color: ForjaShellColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.stream.league.isNotEmpty
                    ? widget.stream.league
                    : 'PPV stream',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: _focused ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
            const _LiveStreamProviderBadge(label: 'PPV'),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _StreamedStreamSheet extends StatefulWidget {
  final _StreamedMatch match;
  final List<_StreamedStream> streams;
  final void Function(_StreamedStream) onStreamSelected;

  const _StreamedStreamSheet({
    required this.match,
    required this.streams,
    required this.onStreamSelected,
  });

  static String sourceLabel(String source) {
    if (source.isEmpty) return '';
    return source[0].toUpperCase() + source.substring(1);
  }

  @override
  State<_StreamedStreamSheet> createState() => _StreamedStreamSheetState();
}

class _StreamedStreamSheetState extends State<_StreamedStreamSheet> {
  static const _rowId = 'live-streamed-stream-sheet';
  final FocusNode _firstFocus = FocusNode(
    debugLabel: 'live-streamed-stream-sheet-first',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  List<_StreamedStream> _sortedByViewers() {
    return [...widget.streams]..sort((a, b) => b.viewers.compareTo(a.viewers));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedByViewers();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.match.title,
            style: const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${sorted.length} ${sorted.length == 1 ? 'stream' : 'streams'}',
            style: const TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sorted.length; i++)
                      _StreamedStreamRow(
                        stream: sorted[i],
                        sourceLabel: _StreamedStreamSheet.sourceLabel(
                          sorted[i].source,
                        ),
                        serverLabel: widget.match.isMut ? 'Mut' : 'Streamed',
                        onTap: () => widget.onStreamSelected(sorted[i]),
                        tvItemIndex: i,
                        tvRowId: _rowId,
                        focusNode: i == 0 ? _firstFocus : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!tv) return body;
    return TvCatalogRow(
      tabId: 'live_matches',
      rowId: _rowId,
      sortOrder: 0,
      itemCount: sorted.length,
      orientation: ShellTvRowOrientation.vertical,
      child: body,
    );
  }
}

class _StreamedStreamRow extends StatefulWidget {
  final _StreamedStream stream;
  final String sourceLabel;
  final String serverLabel;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  const _StreamedStreamRow({
    required this.stream,
    required this.sourceLabel,
    this.serverLabel = 'Streamed',
    required this.onTap,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  @override
  State<_StreamedStreamRow> createState() => _StreamedStreamRowState();
}

class _StreamedStreamRowState extends State<_StreamedStreamRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (widget.sourceLabel.isNotEmpty) widget.sourceLabel,
      if (widget.stream.language.isNotEmpty) widget.stream.language,
    ];
    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 10,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            if (widget.stream.hd)
              _QualityChip(label: 'HD')
            else
              const Icon(
                Icons.play_circle_outline,
                size: 20,
                color: ForjaShellColors.textSecondary,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Stream ${widget.stream.streamNo > 0 ? widget.stream.streamNo : 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: _focused ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: const TextStyle(
                        color: ForjaShellColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.stream.viewers > 0) ...[
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.stream.viewers}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 10),
            ],
            _LiveStreamProviderBadge(label: widget.serverLabel),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _LiveStreamProviderBadge extends StatelessWidget {
  const _LiveStreamProviderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: label == 'PPV'
            ? Colors.orange.withValues(alpha: 0.2)
            : ForjaShellColors.sectionAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: label == 'PPV'
              ? Colors.orange.withValues(alpha: 0.55)
              : ForjaShellColors.sectionAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: label == 'PPV'
              ? Colors.orange.shade200
              : ForjaShellColors.sectionAccent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final String label;

  const _QualityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ForjaShellColors.sectionAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ForjaShellColors.sectionAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Streamed Match Card ──────────────────────────────────────────────────────

class _StreamedMatchCard extends StatefulWidget {
  final _StreamedMatch match;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final bool forceActive;
  final ValueChanged<bool>? onHoverChanged;
  final String tvRowId;
  final ShellTvZone tvZone;

  const _StreamedMatchCard({
    required this.match,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.forceActive = false,
    this.onHoverChanged,
    this.tvRowId = 'grid',
    this.tvZone = ShellTvZone.grid,
  });

  @override
  State<_StreamedMatchCard> createState() => _StreamedMatchCardState();
}

class _StreamedMatchCardState extends State<_StreamedMatchCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final hasSources =
        m.sources.isNotEmpty || m.inlineStreams.isNotEmpty || m.isStremio;
    final hasTeams = m.homeTeam != null && m.awayTeam != null;
    final canPlay = hasSources && m.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active =
        widget.forceActive ||
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : ForjaShellColors.cinematic.borderSubtle,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            if (m.poster.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: _streamedImageUrl(m.poster),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasTeams) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TeamBadge(
                          badge: _streamedImageUrl(m.homeBadge ?? ''),
                          name: m.homeTeam!,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        _TeamBadge(
                          badge: _streamedImageUrl(m.awayBadge ?? ''),
                          name: m.awayTeam!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    m.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Airing matches always show the play button; hover/focus turns it green.
            if (canPlay) ShellCardPlayOverlay(active: active, visible: true),
            _LiveMatchCornerBadge(
              label: m.categoryLabel.toUpperCase(),
              live: false,
              right: null,
              left: 8,
            ),
            if (m.isLive)
              const _LiveMatchCornerBadge(label: '● LIVE', live: true)
            else if (m.timeLabel.isNotEmpty)
              _LiveMatchCornerBadge(label: m.timeLabel, live: false),
            if (!hasSources)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Not yet available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: canPlay ? widget.onTap : null,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.tvZone == ShellTvZone.grid ? widget.gridIndex : null,
      gridColumns: widget.tvZone == ShellTvZone.grid
          ? widget.gridColumns
          : null,
      listIndex: widget.tvZone == ShellTvZone.row ? widget.gridIndex : null,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvZone: widget.tvZone,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) {
        setState(() => _hovered = hovered);
        widget.onHoverChanged?.call(hovered);
      },
      child: card,
    );
  }
}

// ─── Dami TV Match Card ───────────────────────────────────────────────────────

class _DamiTvMatchCard extends StatefulWidget {
  final _DamiTvStream stream;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final bool? playableOverride;
  final bool forceActive;
  final ValueChanged<bool>? onHoverChanged;
  final String tvRowId;
  final ShellTvZone tvZone;
  const _DamiTvMatchCard({
    required this.stream,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.playableOverride,
    this.forceActive = false,
    this.onHoverChanged,
    this.tvRowId = 'grid',
    this.tvZone = ShellTvZone.grid,
  });

  @override
  State<_DamiTvMatchCard> createState() => _DamiTvMatchCardState();
}

class _DamiTvMatchCardState extends State<_DamiTvMatchCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stream;
    final hasIframe = s.iframe.isNotEmpty;
    final hasTeams = s.homeTeam != null && s.awayTeam != null;
    final canPlay = widget.playableOverride ?? (hasIframe && s.isLive);
    final showLive = (widget.playableOverride == true) || s.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active =
        widget.forceActive ||
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : ForjaShellColors.cinematic.borderSubtle,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // poster background
            if (s.poster.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: s.poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // dark gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
            ),
            // content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasTeams) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TeamBadge(badge: s.homeBadge, name: s.homeTeam!),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        _TeamBadge(badge: s.awayBadge, name: s.awayTeam!),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (s.league.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.league,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Airing matches always show the play button; hover/focus turns it green.
            if (canPlay) ShellCardPlayOverlay(active: active, visible: true),
            _LiveMatchCornerBadge(
              label: s.categoryName.toUpperCase(),
              live: false,
              right: null,
              left: 8,
            ),
            if (showLive)
              const _LiveMatchCornerBadge(label: '● LIVE', live: true)
            else if (s.timeLabel.isNotEmpty)
              _LiveMatchCornerBadge(label: s.timeLabel, live: false),
            if (s.viewers > 0)
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text(
                          '${s.viewers}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // no iframe warning bottom
            if (!hasIframe)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Not yet available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: canPlay ? widget.onTap : null,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.tvZone == ShellTvZone.grid ? widget.gridIndex : null,
      gridColumns: widget.tvZone == ShellTvZone.grid
          ? widget.gridColumns
          : null,
      listIndex: widget.tvZone == ShellTvZone.row ? widget.gridIndex : null,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      tvTabId: 'live_matches',
      tvRowId: widget.tvRowId,
      tvZone: widget.tvZone,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) {
        setState(() => _hovered = hovered);
        widget.onHoverChanged?.call(hovered);
      },
      child: card,
    );
  }
}

/// Blocking load dialog with a Cancel control (Back / barrier also dismiss).
class _LiveCancellableLoadingDialog extends StatefulWidget {
  const _LiveCancellableLoadingDialog({
    required this.message,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onCancel;

  @override
  State<_LiveCancellableLoadingDialog> createState() =>
      _LiveCancellableLoadingDialogState();
}

class _LiveCancellableLoadingDialogState
    extends State<_LiveCancellableLoadingDialog> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'live-loading-cancel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_cancelFocus.canRequestFocus) _cancelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: ForjaShellColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ForjaShellColors.cinematic.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: const TextStyle(color: ForjaShellColors.textPrimary),
            ),
            const SizedBox(height: 18),
            if (tvFocus)
              shellFocusableTap(
                context: context,
                onTap: widget.onCancel,
                focusNode: _cancelFocus,
                borderRadius: 24,
                scaleOnFocus: ShellTokens.focusActiveScale,
                ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}
