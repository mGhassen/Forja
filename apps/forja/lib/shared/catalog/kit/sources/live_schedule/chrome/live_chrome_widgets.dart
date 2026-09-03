part of '../live_sports_hub_page.dart';

// ─── Top bar: Servers / Catalog / Time (neutral) + Refresh (white on TV focus) ─

class _LiveMatchesTopBarActionButton extends StatefulWidget {
  const _LiveMatchesTopBarActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tvItemIndex,
    this.accent = true,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int tvItemIndex;
  final bool accent;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<_LiveMatchesTopBarActionButton> createState() =>
      _LiveMatchesTopBarActionButtonState();
}

class _LiveMatchesTopBarActionButtonState
    extends State<_LiveMatchesTopBarActionButton> {
  static const _radius = 20.0;
  bool _focused = false;
  bool _hovered = false;

  bool get _tv => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  bool get _tvFocused => _tv && _focused;

  bool get _active => ShellInputPolicy.interactiveActive(
    ShellScope.inputPolicyOf(context),
    hovered: _hovered,
    focused: _focused,
    context: context,
  );

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final accent = widget.accent;
    // Idle stays neutral (no green fill). Hover / D-pad focus use the same
    // IPTV chrome as Portals — `_active` was computed but never painted when
    // accent was false, so Server / Catalog / Time looked dead on hover.
    final decoration = iptvFocusButtonDecoration(
      active: _active,
      tvFocused: _tvFocused,
      borderRadius: _radius,
      subtle: true,
      idleBg: accent
          ? ForjaShellColors.brandGreen.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.06),
      idleBorder: accent
          ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
          : ForjaShellColors.borderSubtle.withValues(alpha: 0.55),
    );
    final fg = iptvFocusFg(
      accent ? ForjaShellColors.brandGreen : cinematic.textSecondary,
      active: _active,
      tvFocused: _tvFocused,
    );

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
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
      showFocusFill: false,
      listIndex: widget.tvItemIndex,
      tvTabId: LiveSportsHubPageState._tabId,
      tvRowId: LiveSportsHubPageState._topBarRowId,
      tvItemIndex: widget.tvItemIndex,
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
    required this.tvItemIndex,
    required this.onTap,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final FocusNode focusNode;
  final int tvItemIndex;
  final VoidCallback onTap;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
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
        context: context,
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
      tvTabId: LiveSportsHubPageState._tabId,
      tvRowId: LiveSportsHubPageState._topBarRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.topBar,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge ?? () {},
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          ShellTvFocusCoordinator.saveFocus(
            LiveSportsHubPageState._tabId,
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

// ─── Catalog picker sheet ───────────────────────────────────────────────────

class _LiveMatchesCatalogSheet extends StatefulWidget {
  const _LiveMatchesCatalogSheet({
    required this.current,
    required this.catalogs,
    required this.onSelected,
  });

  final String current;
  final List<_ForjaLivePluginLoad> catalogs;
  final ValueChanged<String> onSelected;

  @override
  State<_LiveMatchesCatalogSheet> createState() =>
      _LiveMatchesCatalogSheetState();
}

class _LiveMatchesCatalogSheetState extends State<_LiveMatchesCatalogSheet> {
  static const _tvTabId = 'live_matches_catalog_sheet';
  static const _rowId = 'live-catalog-sheet';
  final FocusNode _firstFocus = FocusNode(
    debugLabel: 'live-catalog-sheet-first',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
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
    final options = <({String id, String label, String? subtitle})>[
      for (final c in widget.catalogs)
        (
          id: c.pluginId,
          label: c.label,
          subtitle: c.loading
              ? 'Loading…'
              : c.attempted
                  ? '${c.matchCount} match${c.matchCount == 1 ? '' : 'es'}'
                  : (_isStremioCatalogFilter(c.pluginId) ? 'Stremio' : null),
        ),
    ];
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
                'Catalog',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Filter the schedule by catalog:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < options.length; i++)
                _LiveMatchesCatalogSheetOption(
                  id: options[i].id,
                  label: options[i].label,
                  subtitle: options[i].subtitle,
                  selected: options[i].id == widget.current,
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
      tabId: _tvTabId,
      rowId: _rowId,
      sortOrder: 0,
      itemCount: options.length,
      orientation: ShellTvRowOrientation.vertical,
      child: body,
    );
  }
}

class _LiveMatchesCatalogSheetOption extends StatefulWidget {
  const _LiveMatchesCatalogSheetOption({
    required this.id,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.subtitle,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final String id;
  final String label;
  final String? subtitle;
  final bool selected;
  final ValueChanged<String> onSelected;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<_LiveMatchesCatalogSheetOption> createState() =>
      _LiveMatchesCatalogSheetOptionState();
}

class _LiveMatchesCatalogSheetOptionState
    extends State<_LiveMatchesCatalogSheetOption> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final mouseHover = policy.scaleOnHover;
    final tvFocus = policy.useFocusableMoodChips;
    final highlight = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    const radius = 12.0;

    final tile = ListTile(
      leading: Icon(
        Icons.video_library_rounded,
        color: widget.selected
            ? ForjaShellColors.sectionAccent
            : Colors.white54,
      ),
      title: Text(
        widget.label,
        style: TextStyle(
          color: Colors.white,
          fontWeight:
              highlight || widget.selected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: widget.subtitle == null
          ? null
          : Text(
              widget.subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
      trailing: widget.selected
          ? Icon(Icons.check_rounded, color: ForjaShellColors.sectionAccent)
          : const Icon(Icons.chevron_right, color: Colors.white38),
    );

    final row = Material(
      color: highlight ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : () => widget.onSelected(widget.id),
        borderRadius: BorderRadius.circular(radius),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: tile,
      ),
    );

    if (!tvFocus) {
      return shellRoundedInkHost(
        radius: radius,
        onTap: () => widget.onSelected(widget.id),
        child: tile,
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: () => widget.onSelected(widget.id),
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: _LiveMatchesCatalogSheetState._tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: mouseHover
          ? (hovered) => setState(() => _hovered = hovered)
          : null,
      child: row,
    );
  }
}

// ─── Schedule window picker sheet ───────────────────────────────────────────

class _LiveMatchesScheduleSheet extends StatefulWidget {
  const _LiveMatchesScheduleSheet({
    required this.status,
    required this.horizon,
    required this.onChanged,
  });

  final _LiveMatchesScheduleStatus status;
  final _LiveMatchesScheduleHorizon horizon;
  final void Function({
    _LiveMatchesScheduleStatus? status,
    _LiveMatchesScheduleHorizon? horizon,
  }) onChanged;

  @override
  State<_LiveMatchesScheduleSheet> createState() =>
      _LiveMatchesScheduleSheetState();
}

class _LiveMatchesScheduleSheetState extends State<_LiveMatchesScheduleSheet> {
  static const _tvTabId = 'live_matches_schedule_sheet';
  static const _statusRowId = 'live-schedule-status';
  static const _horizonRowId = 'live-schedule-horizon';
  final FocusNode _firstFocus = FocusNode(
    debugLabel: 'live-schedule-sheet-first',
  );

  late _LiveMatchesScheduleStatus _status;
  late _LiveMatchesScheduleHorizon _horizon;

  static const _statusOptions = _LiveMatchesScheduleStatus.values;
  static const _horizonOptions = _LiveMatchesScheduleHorizon.values;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _horizon = widget.horizon;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _LiveMatchesScheduleSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _status = widget.status;
    if (oldWidget.horizon != widget.horizon) _horizon = widget.horizon;
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  bool get _showHorizon => _status != _LiveMatchesScheduleStatus.airing;

  String _statusSubtitle(_LiveMatchesScheduleStatus status) => switch (status) {
        _LiveMatchesScheduleStatus.airing =>
          'In-play and 24/7 — including rows without streams yet',
        _LiveMatchesScheduleStatus.upcoming =>
          'Not started yet, within the horizon below',
        _LiveMatchesScheduleStatus.both =>
          'Airing + 24/7, plus upcoming within the horizon',
      };

  String _horizonSubtitle(_LiveMatchesScheduleHorizon horizon) {
    final futureH = _liveMatchesScheduleHorizonRange(horizon).future.inHours;
    return 'Upcoming kickoffs in the next ${futureH}h';
  }

  void _pickStatus(_LiveMatchesScheduleStatus status) {
    setState(() => _status = status);
    widget.onChanged(status: status);
  }

  void _pickHorizon(_LiveMatchesScheduleHorizon horizon) {
    setState(() => _horizon = horizon);
    widget.onChanged(horizon: horizon);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    Widget statusSection = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _statusOptions.length; i++)
          _LiveMatchesScheduleSheetOption(
            label: _liveMatchesScheduleStatusLabel(_statusOptions[i]),
            subtitle: _statusSubtitle(_statusOptions[i]),
            selected: _statusOptions[i] == _status,
            icon: Icons.sensors_rounded,
            onSelected: () => _pickStatus(_statusOptions[i]),
            tvTabId: _tvTabId,
            tvRowId: _statusRowId,
            tvItemIndex: i,
            focusNode: i == 0 ? _firstFocus : null,
          ),
      ],
    );
    if (tv) {
      statusSection = TvCatalogRow(
        tabId: _tvTabId,
        rowId: _statusRowId,
        sortOrder: 0,
        itemCount: _statusOptions.length,
        orientation: ShellTvRowOrientation.vertical,
        child: statusSection,
      );
    }

    Widget? horizonSection;
    if (_showHorizon) {
      horizonSection = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _horizonOptions.length; i++)
            _LiveMatchesScheduleSheetOption(
              label: _liveMatchesScheduleHorizonLabel(_horizonOptions[i]),
              subtitle: _horizonSubtitle(_horizonOptions[i]),
              selected: _horizonOptions[i] == _horizon,
              icon: Icons.schedule_rounded,
              onSelected: () => _pickHorizon(_horizonOptions[i]),
              tvTabId: _tvTabId,
              tvRowId: _horizonRowId,
              tvItemIndex: i,
            ),
        ],
      );
      if (tv) {
        horizonSection = TvCatalogRow(
          tabId: _tvTabId,
          rowId: _horizonRowId,
          sortOrder: 1,
          itemCount: _horizonOptions.length,
          orientation: ShellTvRowOrientation.vertical,
          child: horizonSection,
        );
      }
    }

    return Padding(
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
                'Schedule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'What to show, and how far ahead to load upcoming:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 18),
              const Text(
                'Status',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              statusSection,
              if (horizonSection != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Horizon',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                horizonSection,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveMatchesScheduleSheetOption extends StatefulWidget {
  const _LiveMatchesScheduleSheetOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onSelected,
    required this.tvTabId,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final String tvTabId;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<_LiveMatchesScheduleSheetOption> createState() =>
      _LiveMatchesScheduleSheetOptionState();
}

class _LiveMatchesScheduleSheetOptionState
    extends State<_LiveMatchesScheduleSheetOption> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final mouseHover = policy.scaleOnHover;
    final tvFocus = policy.useFocusableMoodChips;
    final highlight = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    const radius = 12.0;

    final tile = ListTile(
      leading: Icon(
        widget.icon,
        color: widget.selected
            ? ForjaShellColors.sectionAccent
            : Colors.white54,
      ),
      title: Text(
        widget.label,
        style: TextStyle(
          color: Colors.white,
          fontWeight:
              highlight || widget.selected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: widget.selected
          ? Icon(Icons.check_rounded, color: ForjaShellColors.sectionAccent)
          : const Icon(Icons.chevron_right, color: Colors.white38),
    );

    final row = Material(
      color: highlight ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : widget.onSelected,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: tile,
      ),
    );

    if (!tvFocus) {
      return shellRoundedInkHost(
        radius: radius,
        onTap: widget.onSelected,
        child: tile,
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: widget.onSelected,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: mouseHover
          ? (hovered) => setState(() => _hovered = hovered)
          : null,
      child: row,
    );
  }
}

// ─── Chips ────────────────────────────────────────────────────────────────────

class _TeamBadge extends StatelessWidget {
  final String? badge;
  final String name;
  final bool showName;
  final double radius;
  const _TeamBadge({
    required this.badge,
    required this.name,
    this.showName = true,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      child: badge != null && badge!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: badge!,
              width: radius * 1.67,
              height: radius * 1.67,
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
    );
    if (!showName) return avatar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
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

/// TV grid tile: landscape visual band + caption under.
class _LiveMatchTvCaptionBody extends StatelessWidget {
  const _LiveMatchTvCaptionBody({
    required this.active,
    required this.visual,
    required this.title,
    this.schedule,
    this.subtitle,
    this.overlays = const [],
  });

  final bool active;
  final Widget visual;
  final String title;
  final String? schedule;
  final String? subtitle;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 8).clamp(4.0, 8.0);
    final titleSize = shellHubCardTitleFontSize(context);
    return AnimatedContainer(
      duration: Duration.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.white.withValues(alpha: 0.03),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(inset, inset + 2, inset, 4),
                      child: visual,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (schedule != null && schedule!.isNotEmpty) ...[
                          Text(
                            schedule!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: (titleSize - 1).clamp(9.0, 11.0),
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          title,
                          maxLines: subtitle == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: (titleSize - 1).clamp(9.0, 11.0),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}

class _LiveMatchCornerBadge extends StatelessWidget {
  const _LiveMatchCornerBadge({
    required this.label,
    required this.live,
    this.top = 8,
    this.left,
    this.right = 8,
  });

  final String label;
  final bool live;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final fontSize = shellScaled(context, 10).clamp(9.0, 12.0);
    final padH = shellScaled(context, 8).clamp(6.0, 10.0);
    final padV = shellScaled(context, 3).clamp(2.0, 4.0);
    final radius = shellScaled(context, 6).clamp(4.0, 8.0);
    final verticalInset = shellScaled(context, top).clamp(6.0, 10.0);
    final bg = live ? Colors.red.shade700 : Colors.black54;

    return Positioned(
      top: verticalInset,
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

class _LiveMatchViewerBadge extends StatelessWidget {
  const _LiveMatchViewerBadge({required this.viewers});

  final int viewers;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                '$viewers',
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
    );
  }
}

// ─── Forja Sports channel panel (right side, progressive) ────────────────────

abstract final class _IptvSportsPanelCopy {
  static const empty = 'No channels matched this event';

  static String searching(String phase) {
    final p = phase.trim();
    if (p.isEmpty) return 'Searching channels…';
    return 'Searching $p…';
  }

  static String partial(int n, String phase) {
    final count = n == 1 ? '1 channel' : '$n channels';
    final p = phase.trim();
    if (p.isEmpty) return '$count found · still searching…';
    return '$count found · checking $p…';
  }

  static String ready(int n) {
    if (n <= 0) return empty;
    return n == 1 ? '1 channel ready' : '$n channels ready';
  }
}

class _IptvSportsChannelsPanelController extends ChangeNotifier {
  _IptvSportsChannelsPanelController({
    required this.match,
    this.panelTitle = 'Forja Sports',
    this.emptyMessage = _IptvSportsPanelCopy.empty,
    this.searchingHint = 'Matching channels from your portal',
    this.iptvCtrl,
  }) {
    healthProbe = IptvLazyUrlHealthProbe(
      delay: const Duration(milliseconds: 500),
      onResult: _mirrorProbeToCatalog,
    );
    unawaited(_hydrateIptvHealthCache());
  }

  final _StreamedMatch match;
  final String panelTitle;
  final String emptyMessage;
  final String searchingHint;
  final IptvController? iptvCtrl;
  final List<IptvPlaySource> sources = [];
  late final IptvLazyUrlHealthProbe healthProbe;
  bool searching = true;
  String searchPhase = '';
  _LiveBroadcastHints? broadcastHints;
  bool broadcastHintsLoading = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _mirrorProbeToCatalog(String key, bool ok) {
    final ctrl = iptvCtrl;
    if (ctrl == null || !ok) return;
    if (!sources.any((s) => (s.streamId ?? '').trim() == key)) return;
    if (ctrl.streamHealth[key] == true) return;
    ctrl.streamHealth[key] = ok;
    if (ok) {
      ctrl.aliveStreamIds = {...ctrl.aliveStreamIds, key};
    }
    ctrl.notifyListeners();
  }

  Future<void> _hydrateIptvHealthCache() async {
    final ctrl = iptvCtrl;
    final portal = ctrl?.activePortal;
    if (ctrl == null || portal == null) return;
    if (ctrl.aliveCheckedAt != null) return;
    final snap = await IptvAliveStore.load(
      IptvAliveStore.portalKey(portal.portal),
    );
    if (_disposed || snap == null) return;
    ctrl.aliveStreamIds = snap.aliveIds;
    ctrl.aliveCheckedAt = snap.checkedAt;
    for (final id in snap.aliveIds) {
      ctrl.streamHealth[id] = true;
    }
    ctrl.notifyListeners();
  }

  void beginSearching([String phase = '']) {
    if (_disposed) return;
    searching = true;
    final next = phase.trim();
    if (next.isNotEmpty) searchPhase = next;
    notifyListeners();
  }

  void resetForLoad() {
    if (_disposed) return;
    sources.clear();
    searching = false;
    searchPhase = '';
    broadcastHints = null;
    broadcastHintsLoading = false;
    notifyListeners();
  }

  void beginBroadcastHintsLoad() {
    if (_disposed) return;
    broadcastHintsLoading = true;
    broadcastHints = null;
    notifyListeners();
  }

  void setBroadcastHints(_LiveBroadcastHints hints) {
    if (_disposed) return;
    broadcastHints = hints;
    broadcastHintsLoading = false;
    notifyListeners();
  }

  void setSearchPhase(String phase) {
    if (_disposed) return;
    final next = phase.trim();
    if (searchPhase == next) return;
    searchPhase = next;
    notifyListeners();
  }

  void appendSources(Iterable<IptvPlaySource> next) {
    if (_disposed) return;
    final seen = <String>{
      for (final s in sources)
        () {
          final id = (s.streamId ?? '').trim();
          if (id.isNotEmpty) return 'id:$id';
          final url = s.url.trim();
          return url.isEmpty ? '' : 'url:$url';
        }(),
    }..remove('');
    var added = false;
    for (final s in next) {
      final id = (s.streamId ?? '').trim();
      final url = s.url.trim();
      final key = id.isNotEmpty
          ? 'id:$id'
          : (url.isEmpty ? '' : 'url:$url');
      if (key.isEmpty || !seen.add(key)) continue;
      sources.add(s);
      added = true;
    }
    if (added) notifyListeners();
  }

  void finishSearching() {
    if (_disposed) return;
    if (!searching) return;
    searching = false;
    searchPhase = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    healthProbe.dispose();
    super.dispose();
  }
}

/// Right-side overlay — same shell as movie Sources; fills as matches land.
class _IptvSportsChannelsPanel {
  static OverlayEntry? _entry;
  static _IptvSportsChannelsPanelController? _controller;
  static VoidCallback? _cancelInFlightSearch;

  static _IptvSportsChannelsPanelController show({
    required BuildContext context,
    required _StreamedMatch match,
    String panelTitle = 'Forja Sports',
    String emptyMessage = _IptvSportsPanelCopy.empty,
    String searchingHint = 'Matching channels from your portal',
    IptvController? iptvCtrl,
    VoidCallback? cancelInFlightSearch,
    required void Function(IptvPlaySource picked, List<IptvPlaySource> all)
    onChannelSelected,
  }) {
    dismiss();
    final controller = _IptvSportsChannelsPanelController(
      match: match,
      panelTitle: panelTitle,
      emptyMessage: emptyMessage,
      searchingHint: searchingHint,
      iptvCtrl: iptvCtrl,
    );
    _controller = controller;
    _cancelInFlightSearch = cancelInFlightSearch;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => _IptvSportsChannelsOverlay(
        controller: controller,
        onClose: dismiss,
        onChannelSelected: (picked) {
          final all = List<IptvPlaySource>.from(controller.sources);
          dismiss();
          onChannelSelected(picked, all);
        },
      ),
    );
    overlay.insert(_entry!);
    return controller;
  }

  static void dismiss() {
    final wasShowing = _entry != null;
    final ctrl = _controller;
    final cancelSearch = _cancelInFlightSearch;
    _cancelInFlightSearch = null;
    _entry?.remove();
    _entry = null;
    _controller = null;
    cancelSearch?.call();
    // Overlay State drops its listener on unmount; dispose after that frame.
    if (ctrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ctrl.isDisposed) ctrl.dispose();
      });
    }
    if (wasShowing) {
      ShellTvFocusCoordinator.setSourcesPanelDismiss(null);
    }
  }
}

class _IptvSportsChannelsOverlay extends StatefulWidget {
  const _IptvSportsChannelsOverlay({
    required this.controller,
    required this.onClose,
    required this.onChannelSelected,
  });

  final _IptvSportsChannelsPanelController controller;
  final VoidCallback onClose;
  final void Function(IptvPlaySource) onChannelSelected;

  @override
  State<_IptvSportsChannelsOverlay> createState() =>
      _IptvSportsChannelsOverlayState();
}

class _IptvSportsChannelsOverlayState
    extends State<_IptvSportsChannelsOverlay> {
  bool _open = false;
  int _lastSourceCount = 0;
  bool _didInitialFocus = false;
  final FocusNode _closeFocus = FocusNode(
    debugLabel: 'iptv-sports-channels-close',
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _open = true);
      _claimInitialFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _closeFocus.dispose();
    super.dispose();
  }

  void _focusClose() {
    if (_closeFocus.canRequestFocus) _closeFocus.requestFocus();
  }

  /// Real leanback only — desktop also has [SourcesPanelTv.isTv] true
  /// (`useFocusableMoodChips`), which would paint row 0 as "selected".
  bool get _tvLeanback => ShellScope.metricsOf(context).usesTvDensity;

  void _claimInitialFocus() {
    if (_didInitialFocus || !_tvLeanback) return;
    _didInitialFocus = true;
    final n = widget.controller.sources.length;
    if (n > 0) {
      SourcesPanelTv.claimFocus(listIndex: 0, close: _closeFocus);
    } else {
      SourcesPanelTv.claimFocus(close: _closeFocus);
    }
  }

  void _onController() {
    if (!mounted) return;
    final n = widget.controller.sources.length;
    final firstBatch = _lastSourceCount == 0 && n > 0;
    _lastSourceCount = n;
    setState(() {});
    if (!_tvLeanback) return;
    if (firstBatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SourcesPanelTv.focusListItem(index: 0);
      });
      return;
    }
    if (!_didInitialFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _claimInitialFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final sources = ctrl.sources;
    final tv = _tvLeanback;
    final match = ctrl.match;
    final showInlineStatus = !ctrl.searching || sources.isNotEmpty;
    final status = !showInlineStatus
        ? null
        : ctrl.searching
        ? _IptvSportsPanelCopy.partial(sources.length, ctrl.searchPhase)
        : (sources.isEmpty ? null : _IptvSportsPanelCopy.ready(sources.length));

    final matchMeta = [
      if (match.categoryLabel.trim().isNotEmpty) match.categoryLabel.trim(),
      if (match.isLive)
        'Live now'
      else if (match.timeLabel.isNotEmpty)
        match.timeLabel,
    ].join(' · ');

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: ctrl.panelTitle,
          onClose: widget.onClose,
          closeFocusNode: tv ? _closeFocus : null,
          closeOnKeyEvent: tv
              ? (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (sources.isNotEmpty) {
                      SourcesPanelTv.focusListItem(index: 0);
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          match.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ForjaShellColors.cinematic.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (matchMeta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            matchMeta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ForjaShellColors.cinematic.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (ctrl.searching) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: ForjaShellColors.sectionAccent,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: sources.isEmpty
              ? (ctrl.searching
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ForjaShellColors.sectionAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _IptvSportsPanelCopy.searching(
                                  ctrl.searchPhase,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ForjaShellColors.cinematic.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ctrl.searchingHint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      ForjaShellColors.cinematic.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: ForjaShellColors.cinematic.textSecondary
                                    .withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                ctrl.emptyMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      ForjaShellColors.cinematic.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Bleed past left panel padding; right pad is already 0.
                    final insetLeft = DetailsTokens.sourcesPanelPadding.left;
                    final list = ListView.separated(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: sources.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        return _IptvSportsChannelSheetRow(
                          source: sources[i],
                          iptvCtrl: ctrl.iptvCtrl,
                          healthProbe: ctrl.healthProbe,
                          onTap: () => widget.onChannelSelected(sources[i]),
                          tvItemIndex: i,
                          onUpEdge: i == 0 ? _focusClose : null,
                        );
                      },
                    );
                    final bled = OverflowBox(
                      // Surplus width hangs left so the right edge stays flush.
                      alignment: Alignment.centerRight,
                      minWidth: constraints.maxWidth + insetLeft,
                      maxWidth: constraints.maxWidth + insetLeft,
                      child: tv
                          ? TvCatalogRow(
                              tabId: SourcesPanelTv.tabId,
                              rowId: SourcesPanelTv.listRowId,
                              sortOrder: SourcesPanelTv.listSort,
                              itemCount: sources.length,
                              orientation: ShellTvRowOrientation.vertical,
                              onFocusUp: _focusClose,
                              child: list,
                            )
                          : list,
                    );
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: bled,
                    );
                  },
                ),
        ),
      ],
    );

    return TorrentSourcesPanel(
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: true,
      // No right inset — list tiles flush to the panel edge (movie Sources).
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 0, 12),
      child: SourcesPanelTv.wrapBody(
        context: context,
        onClose: widget.onClose,
        child: body,
      ),
    );
  }
}

class _IptvSportsChannelSheetRow extends StatelessWidget {
  const _IptvSportsChannelSheetRow({
    required this.source,
    required this.healthProbe,
    this.iptvCtrl,
    required this.onTap,
    this.tvItemIndex,
    this.onUpEdge,
    this.hideCategorySubtitle = false,
  });

  final IptvPlaySource source;
  final IptvLazyUrlHealthProbe healthProbe;
  final IptvController? iptvCtrl;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  /// When the Live TV category rail is visible, skip repeating category on the row.
  final bool hideCategorySubtitle;

  bool get _isLivePluginRow =>
      source.liveSourceKind == IptvLiveSourceKind.liveEngine ||
      source.liveSourceKind == IptvLiveSourceKind.stremio;

  bool get _isPortalIptvRow =>
      source.liveSourceKind == IptvLiveSourceKind.iptvXtream ||
      source.liveSourceKind == IptvLiveSourceKind.iptvStalker;

  bool? _portalCatalogHealth() {
    final id = (source.streamId ?? '').trim();
    if (id.isEmpty || iptvCtrl == null) return null;
    return iptvCtrl!.healthFor(id);
  }

  IptvStream? get _epgStream {
    final streamId = (source.streamId ?? '').trim();
    final epgId = (source.epgChannelId ?? '').trim();
    if (streamId.isEmpty && epgId.isEmpty) return null;
    return IptvStream(
      streamId: streamId,
      name: source.chromeTitle,
      icon: source.logoUrl ?? '',
      categoryId: '',
      containerExt: 'ts',
      kind: 'live',
      epgChannelId: epgId,
    );
  }

  Widget? _epgFooter() {
    final ctrl = iptvCtrl;
    final stream = _epgStream;
    if (ctrl == null || stream == null) return null;
    return _IptvSportsEpgNowRow(stream: stream, ctrl: ctrl);
  }

  String get _probeKey => iptvLiveSourceProbeKey(source);

  void _recordPortalHealth(IptvController ctrl, String id, bool ok) {
    if (ctrl.streamHealth[id] == ok) return;
    ctrl.streamHealth[id] = ok;
    if (ok) {
      ctrl.aliveStreamIds = {...ctrl.aliveStreamIds, id};
    } else if (ctrl.aliveStreamIds.contains(id)) {
      ctrl.aliveStreamIds = {...ctrl.aliveStreamIds}..remove(id);
    }
    ctrl.notifyListeners();
  }

  /// Portal Live TV — resolve via Xtream/Stalker then alive-check (same as IPTV
  /// Live hover). Never HTTP-probe the catalog template URL (false Unavailable).
  Future<bool> _portalHoverProbe() async {
    final ctrl = iptvCtrl;
    final id = (source.streamId ?? '').trim();
    if (ctrl == null || id.isEmpty) return true;

    final known = ctrl.healthFor(id);
    if (known != null) return known;

    final portal = ctrl.activePortal;
    final stream = _epgStream;
    if (portal == null || stream == null) return true;

    try {
      final url = await IptvClient.resolvePlayUrl(
        portal.portal,
        stream,
        section: 'live',
      );
      if (url == null || url.isEmpty) {
        _recordPortalHealth(ctrl, id, false);
        return false;
      }
      final ok = await IptvAliveChecker.checkOne(url);
      _recordPortalHealth(ctrl, id, ok);
      return ok;
    } catch (_) {
      _recordPortalHealth(ctrl, id, false);
      return false;
    }
  }

  Future<bool> _hoverProbe() async {
    final probed = healthProbe.healthFor(_probeKey);
    if (probed != null) return probed;
    final id = (source.streamId ?? '').trim();
    if (id.isNotEmpty && iptvCtrl != null) {
      final fromCatalog = iptvCtrl!.healthFor(id);
      if (fromCatalog == true) return true;
    }
    // Stalker sports rows have no durable URL until create_link at play.
    if (source.url.trim().isEmpty) return true;
    final probeUrl = iptvLiveSourceProbeUrl(source);
    if (probeUrl == null) return true;
    return healthProbe.checkNow(_probeKey, probeUrl);
  }

  Future<bool> _liveHoverProbe() async {
    final probed = healthProbe.healthFor(_probeKey);
    if (probed != null) return probed;
    final probeUrl = iptvLiveSourceProbeUrl(source);
    if (probeUrl == null) return iptvLiveSourceProbeSkipped(source);
    return healthProbe.checkNow(_probeKey, probeUrl);
  }

  String? _liveQualityBadge(IptvPlaySource source) {
    for (final text in [source.detail, source.label]) {
      final raw = (text ?? '').trim();
      if (raw.isEmpty) continue;
      final match = RegExp(
        r'\b(FHD|UHD|HD|4K|SD)\b',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null) return match.group(1)!.toUpperCase();
    }
    if (source.liveStreamHd) return 'HD';
    return null;
  }

  String? _liveEmbedHost(IptvPlaySource source) {
    final embed = (source.liveEngineEmbedUrl ?? '').trim();
    final url = source.url.trim();
    final probe = embed.isNotEmpty
        ? embed
        : (url.startsWith('pending:') ? '' : url);
    final host = Uri.tryParse(probe)?.host;
    if (host == null || host.isEmpty) return null;
    return host;
  }

  Widget _logo(BuildContext context) {
    const size = 40.0;
    final url = (source.logoUrl ?? '').trim();
    if (url.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.tv_rounded,
          color: ForjaShellColors.sectionAccent,
          size: size * 0.55,
        ),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (size * dpr).round().clamp(1, 512);
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: cacheW,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Icon(
          Icons.tv_rounded,
          color: ForjaShellColors.sectionAccent,
          size: size * 0.55,
        ),
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return Icon(
            Icons.tv_rounded,
            color: Colors.white24,
            size: size * 0.55,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[healthProbe];
    final ctrl = iptvCtrl;
    if (ctrl != null) listenables.add(ctrl);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final cachedHealth = _isPortalIptvRow
            ? _portalCatalogHealth()
            : healthProbe.healthFor(_probeKey);
        if (_isLivePluginRow) {
          final provider = (source.liveProviderBadge ?? '').trim().isNotEmpty
              ? source.liveProviderBadge!.trim()
              : (source.pickerSubtitle ?? '').trim();
          final qualityBadge = _liveQualityBadge(source);
          final viewers = source.liveViewerCount;
          final host = _liveEmbedHost(source);
          return SourcesPanelChannelTile(
            title: source.pickerTitle,
            provider: provider.isEmpty ? null : provider,
            footer: host == null
                ? null
                : Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
            badges: [
              if (qualityBadge != null) qualityBadge,
            ],
            viewerCount: viewers > 0 ? viewers : null,
            onPlay: onTap,
            tvItemIndex: tvItemIndex,
            onUpEdge: onUpEdge,
            onHoverProbe: _liveHoverProbe,
            probeHealthCache: cachedHealth,
          );
        }
        final subtitle =
            hideCategorySubtitle ? null : source.pickerSubtitle;
        return SourcesPanelChannelTile(
          title: source.pickerTitle,
          provider: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
          leading: _logo(context),
          footer: _epgFooter(),
          badges: const [],
          onPlay: onTap,
          tvItemIndex: tvItemIndex,
          onUpEdge: onUpEdge,
          onHoverProbe:
              _isPortalIptvRow ? _portalHoverProbe : _hoverProbe,
          probeHealthCache: cachedHealth,
        );
      },
    );
  }
}

class _IptvSportsEpgNowRow extends StatelessWidget {
  const _IptvSportsEpgNowRow({required this.stream, required this.ctrl});

  final IptvStream stream;
  final IptvController ctrl;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: ctrl.epgFor(stream),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        final now = data.firstWhere((e) => e.isNow, orElse: () => data.first);
        return Row(
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
                style: const TextStyle(
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
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


// ─── Streamed stream sheet ────────────────────────────────────────────────────

class _MergedMatchStreamSheet extends StatefulWidget {
  const _MergedMatchStreamSheet({
    required this.title,
    required this.iframeCatalog,
    required this.streamed,
    required this.onIframeCatalogSelected,
    required this.onStreamedSelected,
  });

  final String title;
  final _IframeCatalogStream? iframeCatalog;
  final List<_StreamedStream> streamed;
  final VoidCallback onIframeCatalogSelected;
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
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
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
    final count = sorted.length + (widget.iframeCatalog == null ? 0 : 1);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final streamedOffset = widget.iframeCatalog == null ? 0 : 1;
    var totalViewers = widget.iframeCatalog?.viewers ?? 0;
    for (final s in sorted) {
      totalViewers += s.viewers;
    }
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
            [
              if (count == 0)
                'No streams available'
              else
                '$count ${count == 1 ? 'stream' : 'streams'}',
              if (totalViewers > 0) '$totalViewers viewers',
            ].join(' · '),
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
                  if (widget.iframeCatalog != null)
                    _MergedIframeCatalogStreamRow(
                      stream: widget.iframeCatalog!,
                      onTap: widget.onIframeCatalogSelected,
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
                      viewers: sorted[i].viewers,
                      onTap: () => widget.onStreamedSelected(sorted[i]),
                      tvItemIndex: streamedOffset + i,
                      tvRowId: _rowId,
                      focusNode: widget.iframeCatalog == null && i == 0
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

class _MergedIframeCatalogStreamRow extends StatefulWidget {
  const _MergedIframeCatalogStreamRow({
    required this.stream,
    required this.onTap,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final _IframeCatalogStream stream;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<_MergedIframeCatalogStreamRow> createState() => _MergedIframeCatalogStreamRowState();
}

class _MergedIframeCatalogStreamRowState extends State<_MergedIframeCatalogStreamRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
        context: context,
    );
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
      onHoverChange: policy.scaleOnHover
          ? (hovered) => setState(() => _hovered = hovered)
          : null,
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
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                ),
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
  final List<_StreamedStreamChoice> choices;
  final void Function(_StreamedStreamChoice) onChoiceSelected;

  const _StreamedStreamSheet({
    required this.match,
    required this.choices,
    required this.onChoiceSelected,
  });

  static String sourceLabel(String source) {
    if (source.isEmpty) return '';
    return source[0].toUpperCase() + source.substring(1);
  }

  static String serverLabelFor(_StreamedMatch match) {
    if (match.isMut) return 'Mut';
    return _liveForjaPluginDisplayName(match.livePluginId);
  }

  static String streamTitle(_StreamedStream stream, String sourceLabel) {
    if (sourceLabel.isNotEmpty && stream.language.isNotEmpty) {
      return '$sourceLabel · ${stream.language}';
    }
    if (sourceLabel.isNotEmpty) return sourceLabel;
    if (stream.language.isNotEmpty) return stream.language;
    if (stream.streamNo > 0) return 'Stream ${stream.streamNo}';
    return 'Stream';
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
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  List<_StreamedStreamChoice> _sortedChoices() {
    return [...widget.choices]
      ..sort(
        (a, b) => _effectiveStreamViewers(b.stream, b.catalogMatch).compareTo(
          _effectiveStreamViewers(a.stream, a.catalogMatch),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedChoices();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final totalViewers = _sheetTotalViewers(sorted);
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
            [
              if (sorted.isEmpty)
                'No streams available'
              else
                '${sorted.length} ${sorted.length == 1 ? 'stream' : 'streams'}',
              if (totalViewers > 0) '$totalViewers viewers',
            ].join(' · '),
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
                        stream: sorted[i].stream,
                        pendingResolve: sorted[i].needsResolve,
                        sourceLabel: _StreamedStreamSheet.sourceLabel(
                          sorted[i].stream.source,
                        ),
                        serverLabel: _StreamedStreamSheet.serverLabelFor(
                          sorted[i].catalogMatch,
                        ),
                        viewers: _effectiveStreamViewers(
                          sorted[i].stream,
                          sorted[i].catalogMatch,
                        ),
                        onTap: () => widget.onChoiceSelected(sorted[i]),
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
  final bool pendingResolve;
  final int? viewers;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  const _StreamedStreamRow({
    required this.stream,
    required this.sourceLabel,
    this.serverLabel = 'Streamed',
    this.pendingResolve = false,
    this.viewers,
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.pendingResolve
        ? (widget.sourceLabel.isNotEmpty
              ? widget.sourceLabel
              : widget.serverLabel)
        : _StreamedStreamSheet.streamTitle(widget.stream, widget.sourceLabel);
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
        context: context,
    );
    final subtitleParts = <String>[
      if (widget.pendingResolve) 'Resolve on play',
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
      onHoverChange: policy.scaleOnHover
          ? (hovered) => setState(() => _hovered = hovered)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            if (widget.stream.hd) ...[
              _QualityChip(label: 'HD'),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
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
            if ((widget.viewers ?? widget.stream.viewers) > 0) ...[
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.viewers ?? widget.stream.viewers}',
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

class _LiveMatchCardTitleStack extends StatelessWidget {
  const _LiveMatchCardTitleStack({
    required this.title,
    this.schedule,
    this.secondary,
    this.rightPadding = 0,
  });

  final String title;
  final String? schedule;
  final String? secondary;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: rightPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (schedule != null && schedule!.isNotEmpty) ...[
            Text(
              schedule!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (secondary != null && secondary!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondary!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9.5,
              ),
            ),
          ],
        ],
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
  final bool? playableOverride;
  final bool forceActive;
  final ValueChanged<bool>? onHoverChanged;
  final String tvRowId;
  final ShellTvZone tvZone;

  /// Summed catalog / resolved stream viewers (PPV-style badge).
  final int? viewersOverride;

  const _StreamedMatchCard({
    required this.match,
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
    this.viewersOverride,
  });

  @override
  State<_StreamedMatchCard> createState() => _StreamedMatchCardState();
}

class _StreamedMatchCardState extends State<_StreamedMatchCard> {
  bool _hovered = false;
  bool _focused = false;

  int get _viewers => widget.viewersOverride ?? widget.match.viewers;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final hasTeams = m.homeTeam != null && m.awayTeam != null;
    final canPlay = widget.playableOverride ?? m.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final active =
        widget.forceActive ||
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        context: context,
        );
    final viewers = _viewers;

    final overlays = <Widget>[
      if (canPlay)
        ShellCardPlayOverlay(
          active: active,
          visible: true,
          diameter: tv ? 28 : 48,
          iconSize: tv ? 16 : 28,
        ),
      _LiveMatchCornerBadge(
        label: m.categoryLabel.toUpperCase(),
        live: false,
        right: null,
        left: tv ? 6 : 8,
        top: tv ? 6 : 8,
      ),
      if (m.isLive)
        _LiveMatchCornerBadge(label: '● LIVE', live: true, top: tv ? 6 : 8)
      else if (m.timeLabel.isNotEmpty)
        _LiveMatchCornerBadge(label: m.timeLabel, live: false, top: tv ? 6 : 8),
      if (!tv && viewers > 0) _LiveMatchViewerBadge(viewers: viewers),
    ];

    final Widget card;
    if (tv) {
      final Widget visual;
      if (hasTeams) {
        visual = Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TeamBadge(
                badge: _streamedImageUrl(m.homeBadge ?? ''),
                name: m.homeTeam!,
                showName: false,
                radius: 16,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TeamBadge(
                badge: _streamedImageUrl(m.awayBadge ?? ''),
                name: m.awayTeam!,
                showName: false,
                radius: 16,
              ),
            ],
          ),
        );
      } else if (m.poster.isNotEmpty) {
        visual = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: _streamedImageUrl(m.poster),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, _, _) => const Center(
              child: Icon(
                Icons.sports_rounded,
                color: Colors.white38,
                size: 36,
              ),
            ),
          ),
        );
      } else {
        visual = const Center(
          child: Icon(Icons.sports_rounded, color: Colors.white38, size: 36),
        );
      }
      card = _LiveMatchTvCaptionBody(
        active: active,
        title: m.title,
        schedule: m.scheduleLabel.isEmpty ? null : m.scheduleLabel,
        subtitle: viewers > 0 ? '$viewers viewers' : null,
        visual: visual,
        overlays: [
          if (canPlay)
            ShellCardPlayOverlay(
              active: active,
              visible: true,
              diameter: 28,
              iconSize: 16,
            ),
          _LiveMatchCornerBadge(
            label: m.categoryLabel.toUpperCase(),
            live: false,
            right: null,
            left: 6,
            top: 6,
          ),
          if (m.isLive)
            const _LiveMatchCornerBadge(label: '● LIVE', live: true, top: 6)
          else if (m.timeLabel.isNotEmpty)
            _LiveMatchCornerBadge(label: m.timeLabel, live: false, top: 6),
        ],
      );
    } else {
      card = AnimatedContainer(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: hasTeams
                          ? Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _TeamBadge(
                                    badge: _streamedImageUrl(m.homeBadge ?? ''),
                                    name: m.homeTeam!,
                                    showName: false,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'VS',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  _TeamBadge(
                                    badge: _streamedImageUrl(m.awayBadge ?? ''),
                                    name: m.awayTeam!,
                                    showName: false,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _LiveMatchCardTitleStack(
                      title: m.title,
                      schedule: m.scheduleLabel.isEmpty ? null : m.scheduleLabel,
                      rightPadding: viewers > 0 ? 52 : 0,
                    ),
                  ],
                ),
              ),
              ...overlays,
            ],
          ),
        ),
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: canPlay ? widget.onTap : null,
      borderRadius: tv ? shellCardBorderRadius(context) : 14,
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

class _IframeCatalogMatchCard extends StatefulWidget {
  final _IframeCatalogStream stream;
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

  /// Merged PPV+Streamed cards pass summed catalog viewers here.
  final int? viewersOverride;
  const _IframeCatalogMatchCard({
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
    this.viewersOverride,
  });

  @override
  State<_IframeCatalogMatchCard> createState() => _IframeCatalogMatchCardState();
}

class _IframeCatalogMatchCardState extends State<_IframeCatalogMatchCard> {
  bool _hovered = false;
  bool _focused = false;

  int get _viewers => widget.viewersOverride ?? widget.stream.viewers;

  @override
  Widget build(BuildContext context) {
    final s = widget.stream;
    final hasTeams = s.homeTeam != null && s.awayTeam != null;
    final canPlay = widget.playableOverride ?? s.isLive;
    final showLive = (widget.playableOverride == true) || s.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final active =
        widget.forceActive ||
        ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
        context: context,
        );

    final overlays = <Widget>[
      if (canPlay)
        ShellCardPlayOverlay(
          active: active,
          visible: true,
          diameter: tv ? 28 : 48,
          iconSize: tv ? 16 : 28,
        ),
      _LiveMatchCornerBadge(
        label: s.categoryName.toUpperCase(),
        live: false,
        right: null,
        left: tv ? 6 : 8,
        top: tv ? 6 : 8,
      ),
      if (showLive)
        _LiveMatchCornerBadge(label: '● LIVE', live: true, top: tv ? 6 : 8)
      else if (s.timeLabel.isNotEmpty)
        _LiveMatchCornerBadge(label: s.timeLabel, live: false, top: tv ? 6 : 8),
      if (!tv && _viewers > 0) _LiveMatchViewerBadge(viewers: _viewers),
    ];

    final Widget card;
    if (tv) {
      final Widget visual;
      if (hasTeams) {
        visual = Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TeamBadge(
                badge: s.homeBadge,
                name: s.homeTeam!,
                showName: false,
                radius: 16,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TeamBadge(
                badge: s.awayBadge,
                name: s.awayTeam!,
                showName: false,
                radius: 16,
              ),
            ],
          ),
        );
      } else if (s.poster.isNotEmpty) {
        visual = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: s.poster,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, _, _) => const Center(
              child: Icon(
                Icons.sports_rounded,
                color: Colors.white38,
                size: 36,
              ),
            ),
          ),
        );
      } else {
        visual = const Center(
          child: Icon(Icons.sports_rounded, color: Colors.white38, size: 36),
        );
      }
      final captionBits = <String>[
        if (s.league.isNotEmpty) s.league,
        if (_viewers > 0) '$_viewers viewers',
      ];
      card = _LiveMatchTvCaptionBody(
        active: active,
        title: s.name,
        schedule: s.scheduleLabel.isEmpty ? null : s.scheduleLabel,
        subtitle: captionBits.isEmpty ? null : captionBits.join(' · '),
        visual: visual,
        overlays: overlays,
      );
    } else {
      card = AnimatedContainer(
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
              if (s.poster.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: s.poster,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: hasTeams
                          ? Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _TeamBadge(
                                    badge: s.homeBadge,
                                    name: s.homeTeam!,
                                    showName: false,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'VS',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  _TeamBadge(
                                    badge: s.awayBadge,
                                    name: s.awayTeam!,
                                    showName: false,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _LiveMatchCardTitleStack(
                      title: s.name,
                      schedule: s.scheduleLabel.isEmpty ? null : s.scheduleLabel,
                      secondary: s.league.isEmpty ? null : s.league,
                      rightPadding: _viewers > 0 ? 52 : 0,
                    ),
                  ],
                ),
              ),
              ...overlays,
            ],
          ),
        ),
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: canPlay ? widget.onTap : null,
      borderRadius: tv ? shellCardBorderRadius(context) : 14,
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
    required this.messageListenable,
    required this.onCancel,
  });

  final ValueNotifier<String> messageListenable;
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
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_cancelFocus.canRequestFocus) _cancelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    try {
      if (_cancelFocus.hasFocus) _cancelFocus.unfocus();
    } catch (_) {}
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
            ValueListenableBuilder<String>(
              valueListenable: widget.messageListenable,
              builder: (_, message, _) => Text(
                message,
                style: const TextStyle(color: ForjaShellColors.textPrimary),
                textAlign: TextAlign.center,
              ),
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
