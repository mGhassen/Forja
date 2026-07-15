part of 'live_matches_screen.dart';

// ─── Server picker sheet ────────────────────────────────────────────────────

class _LiveMatchesServerSheet extends StatelessWidget {
  const _LiveMatchesServerSheet({
    required this.current,
    required this.onSelected,
  });

  final _LiveMatchesServer current;
  final ValueChanged<_LiveMatchesServer> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
          _LiveMatchesServerSheetOption(
            server: _LiveMatchesServer.all,
            current: current,
            onSelected: onSelected,
          ),
          ..._LiveMatchesServer.values
              .where((server) => server != _LiveMatchesServer.all)
              .map(
                (server) => _LiveMatchesServerSheetOption(
                  server: server,
                  current: current,
                  onSelected: onSelected,
                ),
              ),
        ],
      ),
    );
  }
}

class _LiveMatchesServerSheetOption extends StatelessWidget {
  const _LiveMatchesServerSheetOption({
    required this.server,
    required this.current,
    required this.onSelected,
  });

  final _LiveMatchesServer server;
  final _LiveMatchesServer current;
  final ValueChanged<_LiveMatchesServer> onSelected;

  @override
  Widget build(BuildContext context) {
    return shellFocusableTap(
      context: context,
      onTap: () => onSelected(server),
      borderRadius: 12,
      navLeftAlways: true,
      tvTabId: 'live_matches',
      tvZone: ShellTvZone.row,
      child: ListTile(
        leading: Icon(
          server == _LiveMatchesServer.all
              ? Icons.grid_view_rounded
              : Icons.dns_rounded,
          color: server == current
              ? ForjaShellColors.sectionAccent
              : Colors.white54,
        ),
        title: Text(
          _liveMatchesServerLabel(server),
          style: TextStyle(
            color: Colors.white,
            fontWeight: server == current ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _liveMatchesServerSubtitle(server),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: server == current
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
  const _CdnChannelCard({
    required this.channel,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
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
              ShellCardPlayOverlay(active: active, visible: active),
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
  const _CdnSportCard({
    required this.event,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
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
    final active = canPlay &&
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
            if (canPlay) ShellCardPlayOverlay(active: active, visible: active),
            _LiveMatchCornerBadge(
              label: e.isLive ? '● LIVE' : e.status.toUpperCase(),
              live: e.isLive,
              color: e.isLive
                  ? Colors.red.shade700
                  : Colors.orange.shade700,
            ),
          ],
        ),
      ),
    );

    if (!canPlay) return card;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: card,
    );
  }
}

// ─── CDN Channel Sheet ────────────────────────────────────────────────────────

class _CdnChannelSheet extends StatelessWidget {
  final _CdnSportEvent event;
  final void Function(_CdnChannel) onChannelSelected;
  const _CdnChannelSheet({
    required this.event,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
            '${event.homeTeam} vs ${event.awayTeam}',
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
          ...event.channels.map(
            (ch) => shellFocusableTap(
              context: context,
              onTap: () => onChannelSelected(ch),
              borderRadius: 12,
              navLeftAlways: true,
              tvTabId: 'live_matches',
              tvZone: ShellTvZone.row,
              child: ListTile(
                leading: ch.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ch.image,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => Icon(
                          Icons.tv_rounded,
                          color: ForjaShellColors.sectionAccent,
                        ),
                      )
                    : Icon(
                        Icons.tv_rounded,
                        color: ForjaShellColors.sectionAccent,
                      ),
                title: Text(
                  ch.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: ch.viewers > 0
                    ? Text(
                        '${ch.viewers} viewers',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      )
                    : null,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ],
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
  bool _loading = true;
  bool _isFullscreen = false;
  bool _ready = false;
  Timer? _loadingWatchdog;
  Timer? _adWindowCloseTimer;

  /// Native popup ([window.open]) from an ad. Accepted off-screen so Streamed
  /// embeds that require a successful open keep working; never shown in UI.
  int? _adWindowId;

  late final InAppWebViewInitialData _initialData;
  late final InAppWebViewSettings _initialSettings;
  late final UnmodifiableListView<UserScript> _initialUserScripts;

  final FocusNode _backFocusNode = FocusNode(
    debugLabel: 'live-embed-back',
  );

  bool _tvFocus() =>
      ShellScope.maybeOf(context)?.inputPolicy.useFocusableMoodChips ?? false;

  /// The embed is a native WebView platform view that grabs D-pad input on TV.
  /// Pull focus back to the Flutter back button so it stays reachable.
  void _focusBack() {
    if (!mounted || !_tvFocus() || _isFullscreen) return;
    if (_backFocusNode.canRequestFocus) _backFocusNode.requestFocus();
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
    final embedUrl = widget.embedUrl;
    final wrapperBase = widget.referer.endsWith('/')
        ? widget.referer
        : '${widget.referer}/';
    _initialData = InAppWebViewInitialData(
      data: _buildLiveEmbedWrapperHtml(embedUrl),
      baseUrl: WebUri(wrapperBase),
      historyUrl: WebUri(wrapperBase),
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
    _initialUserScripts = UnmodifiableListView([
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
    _initialSettings = InAppWebViewSettings(
      userAgent: _ua['User-Agent'],
      domStorageEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      javaScriptEnabled: true,
      disableDefaultErrorPage: true,
      allowsAirPlayForMediaPlayback: true,
      allowsPictureInPictureMediaPlayback: true,
      iframeAllow: 'autoplay; fullscreen; encrypted-media',
      iframeAllowFullscreen: true,
      useShouldOverrideUrlLoading: true,
      // Accept window.open off-screen. Rejecting it falls back to main-frame
      // ad navigations that break Streamed HLS (manifestParsingError).
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      contentBlockers: _liveEmbedContentBlockers(),
    );
    // Wrapper + iframe usually finishes quickly; if an ad CDN still hangs the
    // document, don't leave the spinner forever.
    _loadingWatchdog = Timer(const Duration(seconds: 12), _clearLoading);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusBack());
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
    if (mounted) setState(() => _isFullscreen = false);
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

  @override
  void dispose() {
    _loadingWatchdog?.cancel();
    _adWindowCloseTimer?.cancel();
    _backFocusNode.dispose();
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
    final bar = Padding(
      padding: EdgeInsets.fromLTRB(8, _topBarTopPadding(context), 72, 16),
      child: Row(
        children: [
          iptvBackButton(
            context,
            onTap: () => Navigator.of(context).maybePop(),
            color: Colors.white,
            size: 26,
            focusNode: _backFocusNode,
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!_tvFocus()) return bar;
    return FocusScope(
      debugLabel: 'live-embed-chrome',
      child: FocusTraversalGroup(child: bar),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = widget.embedUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            ForjaInAppWebView(
              // Match streamed.pk / ppv.is: embed lives in an iframe under the
              // catalog origin so document.referrer is set and ad scripts that
              // block top-level document parse are easier to isolate.
              initialData: _initialData,
              initialUserScripts: _initialUserScripts,
              initialSettings: _initialSettings,
              onWebViewCreated: (controller) {
                controller.addJavaScriptHandler(
                  handlerName: 'toggleFullscreen',
                  callback: (_) {
                    unawaited(_toggleFullscreen());
                  },
                );
              },
              onLoadStart: (_, _) {
                // Ad main-frame hijack attempts can fire load-start; do not
                // setState after the player is ready (rebuild churn + WK crash).
                if (!mounted || _ready || _loading) return;
                setState(() => _loading = true);
              },
              onLoadStop: (ctrl, _) async {
                _loadingWatchdog?.cancel();
                _clearLoading();
                try {
                  await ctrl.evaluateJavascript(source: _autoplayJs);
                  await ctrl.evaluateJavascript(source: _dblclickFullscreenJs);
                } catch (_) {}
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _focusBack());
              },
              onEnterFullscreen: (_) => unawaited(_enterFullscreen()),
              onExitFullscreen: (_) => unawaited(_exitFullscreen()),
              onCreateWindow: (_, action) async {
                // Keep a single hidden child; ignore extra ad spawns until closed.
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
                // Player CDNs and nested iframes leave embed.st — never cancel
                // subframe navigations (that caused blank/white players).
                if (action.isForMainFrame != true) {
                  return NavigationActionPolicy.ALLOW;
                }
                final url = action.request.url?.toString() ?? '';
                if (_liveEmbedAllowsNavigation(
                  url: url,
                  embedUrl: embedUrl,
                  referer: widget.referer,
                  origin: widget.origin,
                )) {
                  return NavigationActionPolicy.ALLOW;
                }
                debugPrint('[LiveMatches] blocked main-frame nav: $url');
                return NavigationActionPolicy.CANCEL;
              },
            ),
            if (_loading)
              Center(
                child: CircularProgressIndicator(
                  color: ForjaShellColors.sectionAccent,
                ),
              ),
            if (!_isFullscreen) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: _buildTopBar(),
                ),
              ),
              Positioned(
                top: _topBarTopPadding(context),
                right: 16,
                child: _buildSourceBadge(),
              ),
            ],
            // Off-screen host for ad window.open — required by some Streamed
            // embeds; never visible or interactive.
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
                      initialSettings: InAppWebViewSettings(
                        transparentBackground: true,
                        supportMultipleWindows: false,
                        javaScriptCanOpenWindowsAutomatically: false,
                      ),
                      onCloseWindow: (_) => _dismissAdWindow(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Streamed stream sheet ────────────────────────────────────────────────────

class _StreamedStreamSheet extends StatelessWidget {
  final _StreamedMatch match;
  final List<_StreamedStream> streams;
  final void Function(_StreamedStream) onStreamSelected;

  const _StreamedStreamSheet({
    required this.match,
    required this.streams,
    required this.onStreamSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
            match.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a stream:',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...streams.map(
            (stream) => shellFocusableTap(
              context: context,
              onTap: () => onStreamSelected(stream),
              borderRadius: 12,
              navLeftAlways: true,
              tvTabId: 'live_matches',
              tvZone: ShellTvZone.row,
              child: ListTile(
                leading: Icon(
                  stream.hd ? Icons.hd_rounded : Icons.play_circle_outline,
                  color: ForjaShellColors.sectionAccent,
                ),
                title: Text(
                  stream.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ],
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

  const _StreamedMatchCard({
    required this.match,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
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
    final hasSources = m.sources.isNotEmpty;
    final hasTeams = m.homeTeam != null && m.awayTeam != null;
    final canPlay = hasSources && m.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active = canPlay &&
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
            if (canPlay) ShellCardPlayOverlay(active: active, visible: active),
            _LiveMatchCornerBadge(
              label: m.categoryLabel.toUpperCase(),
              live: false,
              right: null,
              left: 8,
            ),
            if (m.isLive)
              const _LiveMatchCornerBadge(
                label: '● LIVE',
                live: true,
              )
            else if (m.timeLabel.isNotEmpty)
              _LiveMatchCornerBadge(
                label: m.timeLabel,
                live: false,
              ),
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

    if (!canPlay) return card;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
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
  const _DamiTvMatchCard({
    required this.stream,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
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
    final canPlay = hasIframe && s.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final active = canPlay &&
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
            if (canPlay) ShellCardPlayOverlay(active: active, visible: active),
            _LiveMatchCornerBadge(
              label: s.categoryName.toUpperCase(),
              live: false,
              right: null,
              left: 8,
            ),
            if (s.isLive)
              const _LiveMatchCornerBadge(
                label: '● LIVE',
                live: true,
              )
            else if (s.timeLabel.isNotEmpty)
              _LiveMatchCornerBadge(
                label: s.timeLabel,
                live: false,
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

    if (!canPlay) return card;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      onUpEdge: widget.onUpEdge,
      tvTabId: 'live_matches',
      tvRowId: 'grid',
      tvZone: ShellTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: card,
    );
  }
}
