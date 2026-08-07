part of 'iptv_pt_screen.dart';

/// Live channels probe on hover/focus; Movies and Series skip status checks.
bool _streamHealthEnabled(IptvStream s) => s.kind == 'live';

class _StreamThumbPlayHint extends StatelessWidget {
  const _StreamThumbPlayHint({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: active ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
            ),
          ),
        ),
        ShellCardPlayOverlay(
          active: false,
          visible: active,
          diameter: 30,
          iconSize: 18,
        ),
      ],
    );
  }
}

class _StreamCard extends StatefulWidget {
  final IptvStream stream;
  final IptvController ctrl;
  final VoidCallback onTap;
  final bool showLogo;
  final VoidCallback? onTvFocusGained;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  const _StreamCard({
    required this.stream,
    required this.ctrl,
    required this.onTap,
    this.showLogo = true,
    this.onTvFocusGained,
    this.gridIndex,
    this.gridColumns,
    this.onLeftEdge,
    this.onUpEdge,
    this.onRightEdge,
  });

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _syncLiveProbe(hovered || _focused);
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _syncLiveProbe(focused || _hovered);
    if (focused && iptvUseTvFocus(context)) {
      widget.onTvFocusGained?.call();
    }
  }

  void _syncLiveProbe(bool active) {
    if (!_streamHealthEnabled(widget.stream)) return;
    if (active) {
      widget.ctrl.scheduleLazyCheck(
        widget.stream,
        onlyThis: iptvUseTvFocus(context),
      );
    } else {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
  }

  @override
  void dispose() {
    if (_streamHealthEnabled(widget.stream)) {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
    super.dispose();
  }

  Color _surfaceColor(bool active, bool? health) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _borderColor(bool active, bool? health) {
    if (!_streamHealthEnabled(widget.stream) || health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    if (health) {
      return const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45);
    }
    return const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  void _showEpgSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EpgSheet(stream: widget.stream, ctrl: widget.ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final health = _streamHealthEnabled(widget.stream)
            ? widget.ctrl.healthFor(widget.stream.streamId)
            : null;
        final active = _active(context);
        final tv = ShellScope.metricsOf(context).usesTvDensity;
        final column = tv
            ? _buildTvPosterBody(context, health: health, active: active)
            : _buildDefaultBody(context, health: health, active: active);
        final radius = tv ? shellCardBorderRadius(context) : 12.0;
        Widget card = AnimatedContainer(
          duration: tv ? Duration.zero : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: tv ? Colors.transparent : _surfaceColor(active, health),
            borderRadius: BorderRadius.circular(radius),
            border: tv && !active
                ? Border.all(color: Colors.transparent)
                : Border.all(color: _borderColor(active, health)),
          ),
          child: iptvTap(
            context: context,
            onTap: widget.onTap,
            borderRadius: radius,
            scaleOnFocus: 1.0,
            gridIndex: widget.gridIndex,
            gridColumns: widget.gridColumns,
            tvRowId: 'browser-streams',
            tvZone: ShellTvZone.grid,
            onLeftEdge: widget.onLeftEdge,
            onUpEdge: widget.onUpEdge,
            onRightEdge: widget.onRightEdge,
            onFocusChange: _onFocus,
            onHoverChange: _onHover,
            child: column,
          ),
        );

        if (!iptvUseTvFocus(context) &&
            widget.stream.kind == 'live' &&
            widget.ctrl.epgEnabled) {
          card = GestureDetector(
            onLongPress: () => _showEpgSheet(context),
            child: card,
          );
        }

        if (!_streamHealthEnabled(widget.stream)) return card;

        return _LiveHealthProbe(
          stream: widget.stream,
          ctrl: widget.ctrl,
          child: card,
        );
      },
    );
  }

  Widget _buildDefaultBody(
    BuildContext context, {
    required bool? health,
    required bool active,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _streamThumb(),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: active ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              ShellCardPlayOverlay(active: false, visible: active),
              if (widget.stream.kind == 'live')
                Positioned(
                  top: 4,
                  left: 4,
                  child: IptvLiveFavoriteButton(
                    streamId: widget.stream.streamId,
                    ctrl: widget.ctrl,
                    reveal: active,
                  ),
                ),
              if (health != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _healthDot(health),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Tooltip(
            message: widget.stream.name,
            waitDuration: const Duration(milliseconds: 600),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  widget.stream.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: health == false ? Colors.white54 : Colors.white,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.stream.kind == 'live' && widget.showLogo)
          _EpgNowFooter(stream: widget.stream, ctrl: widget.ctrl),
      ],
    );
  }

  Widget _buildTvPosterBody(
    BuildContext context, {
    required bool? health,
    required bool active,
  }) {
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 8).clamp(4.0, 8.0);
    final titleSize = shellHubCardTitleFontSize(context);
    final isLive = widget.stream.kind == 'live';
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isLive)
            _buildTvLiveLogoBody(
              inset: inset,
              titleSize: titleSize,
              health: health,
            )
          else ...[
            _streamThumb(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
            Positioned(
              left: inset,
              right: inset,
              bottom: inset,
              child: Text(
                widget.stream.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: health == false ? Colors.white54 : Colors.white,
                  fontSize: titleSize,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          ShellCardPlayOverlay(
            active: false,
            visible: active,
            diameter: isLive ? 28 : 48,
            iconSize: isLive ? 16 : 28,
          ),
          if (isLive)
            Positioned(
              top: inset,
              left: inset,
              child: IptvLiveFavoriteButton(
                streamId: widget.stream.streamId,
                ctrl: widget.ctrl,
                reveal: active,
                iconSize: 13,
              ),
            ),
          if (health != null)
            Positioned(
              top: inset,
              right: inset,
              child: _healthDot(health, compact: true),
            ),
        ],
      ),
    );
  }

  /// Live logos sit in a centered square band so wide/tall marks share one
  /// optical box inside the tall poster cell (VOD stays full-bleed cover).
  Widget _buildTvLiveLogoBody({
    required double inset,
    required double titleSize,
    required bool? health,
  }) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, inset + 2, inset, 4),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _streamIconThumb(
                    icon: widget.showLogo ? widget.stream.icon : '',
                    contain: true,
                    padding: 6,
                    cacheWidth: 160,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
            child: Text(
              widget.stream.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: health == false ? Colors.white54 : Colors.white,
                fontSize: titleSize,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streamThumb() {
    return _streamIconThumb(
      icon: widget.showLogo ? widget.stream.icon : '',
      contain: widget.stream.kind == 'live',
      padding: 10,
    );
  }

  Widget _healthDot(bool health, {bool compact = false}) {
    final size = compact ? 8.0 : 10.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: health ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        border: Border.all(color: Colors.black54, width: 1),
      ),
    );
  }
}

class _StreamRowTile extends StatefulWidget {
  const _StreamRowTile({
    required this.stream,
    required this.ctrl,
    required this.categoryName,
    required this.onTap,
    this.showLogo = true,
    this.onTvFocusGained,
    this.listIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
  });

  final IptvStream stream;
  final IptvController ctrl;
  final String categoryName;
  final VoidCallback onTap;
  final bool showLogo;
  final VoidCallback? onTvFocusGained;
  final int? listIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;

  @override
  State<_StreamRowTile> createState() => _StreamRowTileState();
}

class _StreamRowTileState extends State<_StreamRowTile> {
  bool _hovered = false;
  bool _focused = false;

  bool _active(BuildContext context) => ShellInputPolicy.interactiveActive(
        ShellScope.inputPolicyOf(context),
        hovered: _hovered,
        focused: _focused,
      );

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _syncLiveProbe(hovered || _focused);
  }

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _syncLiveProbe(focused || _hovered);
    if (focused && iptvUseTvFocus(context)) {
      widget.onTvFocusGained?.call();
    }
  }

  void _syncLiveProbe(bool active) {
    if (!_streamHealthEnabled(widget.stream)) return;
    if (active) {
      widget.ctrl.scheduleLazyCheck(
        widget.stream,
        onlyThis: iptvUseTvFocus(context),
      );
    } else {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
  }

  @override
  void dispose() {
    if (_streamHealthEnabled(widget.stream)) {
      widget.ctrl.cancelLazyCheck(widget.stream.streamId);
    }
    super.dispose();
  }

  Color _surfaceColor(bool active, bool? health) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _borderColor(bool active, bool? health) {
    if (!_streamHealthEnabled(widget.stream) || health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    return health
        ? const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45)
        : const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (_, _) {
        final health = _streamHealthEnabled(widget.stream)
            ? widget.ctrl.healthFor(widget.stream.streamId)
            : null;
        final active = _active(context);
        final tile = Padding(
          padding: EdgeInsets.zero,
          child: AnimatedContainer(
            duration: iptvUseTvFocus(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _surfaceColor(active, health),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor(active, health)),
            ),
            child: iptvTap(
              context: context,
              onTap: widget.onTap,
              borderRadius: 10,
              scaleOnFocus: 1.0,
              listIndex: widget.listIndex,
              tvItemIndex: widget.listIndex,
              tvRowId: 'browser-streams',
              tvZone: ShellTvZone.row,
              onLeftEdge: widget.onLeftEdge,
              onRightEdge: widget.onRightEdge,
              onUpEdge: widget.onUpEdge,
              onFocusChange: _onFocus,
              onHoverChange: _onHover,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _streamIconThumb(
                              icon: widget.showLogo ? widget.stream.icon : '',
                              contain: widget.stream.kind == 'live',
                              padding: 4,
                              cacheWidth: 88,
                            ),
                            _StreamThumbPlayHint(active: active),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.stream.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: health == false
                                  ? Colors.white54
                                  : Colors.white,
                              fontSize: 12,
                              height: 1.18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.categoryName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (widget.stream.kind == 'live' && widget.showLogo)
                            _EpgNowFooter(
                              stream: widget.stream,
                              ctrl: widget.ctrl,
                            ),
                        ],
                      ),
                    ),
                    if (widget.stream.kind == 'live') ...[
                      IptvLiveFavoriteButton(
                        streamId: widget.stream.streamId,
                        ctrl: widget.ctrl,
                        reveal: active,
                        iconSize: 13,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (health != null)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: health
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                        ),
                      )
                    else
                      AnimatedOpacity(
                        opacity: active ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white38,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (!_streamHealthEnabled(widget.stream)) return tile;
        return _LiveHealthProbe(
          stream: widget.stream,
          ctrl: widget.ctrl,
          child: tile,
        );
      },
    );
  }
}

/// Platform-specific lazy health probe - desktop hover, TV focus, mobile visibility.
class _LiveHealthProbe extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  final Widget child;

  const _LiveHealthProbe({
    required this.stream,
    required this.ctrl,
    required this.child,
  });

  static bool isDesktopPlatform() =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Mobile touch scrolling needs visibility + scroll debounce.
  static bool usesScrollDebounce(BuildContext context) =>
      !isDesktopPlatform() &&
      resolveShellProfile(context) == ShellProfile.mobile;

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform() || isTvProfile(context)) {
      return child;
    }

    return VisibilityDetector(
      key: Key('health-${stream.kind}-${stream.streamId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.4) {
          ctrl.scheduleLazyCheck(stream);
        } else if (info.visibleFraction <= 0.05) {
          ctrl.cancelLazyCheck(stream.streamId);
        }
      },
      child: child,
    );
  }
}

/// Tiny "NOW · Title" strip at the bottom of a live `_StreamCard`.
///
/// Always reserves [_slotHeight] so EPG arriving later does not shrink the
/// logo [Expanded] and make channel marks look like they rescale.
class _EpgNowFooter extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  const _EpgNowFooter({required this.stream, required this.ctrl});

  static const _slotHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slotHeight,
      child: FutureBuilder<List<EpgEntry>>(
        future: ctrl.epgFor(stream),
        builder: (_, snap) {
          final data = snap.data;
          if (data == null || data.isEmpty) return const SizedBox.shrink();
          final now =
              data.firstWhere((e) => e.isNow, orElse: () => data.first);
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Long-press detail sheet - lists the next few programmes with start times.
class _EpgSheet extends StatelessWidget {
  final IptvStream stream;
  final IptvController ctrl;
  const _EpgSheet({required this.stream, required this.ctrl});

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stream.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: FutureBuilder<List<EpgEntry>>(
                    future: ctrl.epgFor(stream, limit: 8),
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: IptvShellStyle.accent,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final data = snap.data ?? const <EpgEntry>[];
                      if (data.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No EPG available for this channel.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in data)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 86,
                                    child: Text(
                                      '${_fmtTime(e.start)}–${_fmtTime(e.stop)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: e.isNow
                                            ? const Color(0xFFEF4444)
                                            : Colors.white60,
                                        fontSize: 11,
                                        fontWeight: e.isNow
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.title.isEmpty ? '-' : e.title,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (e.description.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              e.description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live channel logos use [BoxFit.contain] + inset so the mark sits inside the
/// card; VOD posters stay [BoxFit.cover] to fill the frame.
///
/// Always [SizedBox.expand] so decoded bitmaps never briefly take intrinsic
/// size and look oversized before layout clamps them.
Widget _streamIconThumb({
  required String icon,
  required bool contain,
  double padding = 0,
  int? cacheWidth,
}) {
  if (icon.isEmpty) {
    return const SizedBox.expand(child: _StreamPlaceholder());
  }
  final image = Image.network(
    icon,
    fit: contain ? BoxFit.contain : BoxFit.cover,
    alignment: Alignment.center,
    gaplessPlayback: true,
    cacheWidth: cacheWidth,
    // Only cacheWidth — setting both forces a stretched decode (deformed logos).
    filterQuality:
        cacheWidth != null ? FilterQuality.low : FilterQuality.medium,
    errorBuilder: (_, _, _) => const _StreamPlaceholder(),
    loadingBuilder: (_, child, p) =>
        p == null ? child : const _StreamPlaceholder(),
  );
  if (!contain) return SizedBox.expand(child: image);
  return Padding(
    padding: EdgeInsets.all(padding),
    child: SizedBox.expand(child: image),
  );
}

class _StreamPlaceholder extends StatelessWidget {
  const _StreamPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.tv_rounded, color: Colors.white24, size: 36),
    );
  }
}
