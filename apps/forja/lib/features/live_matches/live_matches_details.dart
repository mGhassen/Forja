part of 'live_matches_screen.dart';

enum _LiveMatchPlayPath { engineChoices, iptvSports, stremioDirect }

/// Match detail — catalog-kit hero + stream cards (replaces Sources-only flow).
class _LiveMatchDetailsScreen extends ConsumerStatefulWidget {
  const _LiveMatchDetailsScreen({
    required this.host,
    required this.match,
    this.ppvAnchor,
  });

  final _LiveMatchesScreenState host;
  final _StreamedMatch match;
  final _DamiTvStream? ppvAnchor;

  @override
  ConsumerState<_LiveMatchDetailsScreen> createState() =>
      _LiveMatchDetailsScreenState();
}

class _LiveMatchDetailsScreenState
    extends ConsumerState<_LiveMatchDetailsScreen> {
  late final _IptvSportsChannelsPanelController _sourcesCtrl;
  final _choices = <_StreamedStreamChoice>[];
  final _scrollController = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'live-match-details-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'live-match-details-play');

  late _StreamedMatch _displayMatch;
  _LiveMatchPlayPath _playPath = _LiveMatchPlayPath.engineChoices;
  int _loadGen = 0;
  bool _detailsHeroInitialFocusDone = false;

  bool get _waitsForForjaCatalogIdle {
    final server = widget.host._server;
    return server == _LiveMatchesServer.all ||
        server == _LiveMatchesServer.forjaLive ||
        server == _LiveMatchesServer.iptvSports;
  }

  @override
  void initState() {
    super.initState();
    _displayMatch = widget.match;
    _sourcesCtrl = _IptvSportsChannelsPanelController(
      match: widget.match,
      panelTitle: 'Streams',
      emptyMessage: 'No streams available',
      searchingHint: 'Finding streams',
      iptvCtrl: ref.read(iptvControllerProvider),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleInitialLoad());
  }

  @override
  void dispose() {
    _loadGen++;
    Engine.cancelLiveMatchesFetch();
    _sourcesCtrl.dispose();
    _scrollController.dispose();
    _backFocus.dispose();
    _heroPlayFocus.dispose();
    super.dispose();
  }

  void _scheduleInitialLoad() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final anim = route?.animation;
    if (anim == null || anim.isCompleted) {
      unawaited(_loadSources());
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      anim.removeStatusListener(onStatus);
      if (mounted) unawaited(_loadSources());
    }

    anim.addStatusListener(onStatus);
  }

  Future<void> _awaitForjaGridCatalogIdle() async {
    if (!_waitsForForjaCatalogIdle) return;
    final host = widget.host;
    var spins = 0;
    while (mounted && spins < 120) {
      if (!(host as _LiveMatchesForjaLive)._forjaLiveCatalogBusy) return;
      if (spins == 0) {
        _sourcesCtrl.setSearchPhase('Loading schedule');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      spins++;
    }
  }

  Future<void> _loadSources() async {
    final gen = ++_loadGen;
    final host = widget.host;
    _choices.clear();
    _sourcesCtrl.resetForLoad();
    _playPath = _LiveMatchPlayPath.engineChoices;
    _sourcesCtrl.beginSearching('streams');
    try {
      await _awaitForjaGridCatalogIdle();
      if (!mounted || gen != _loadGen || _sourcesCtrl.isDisposed) return;

      final display = await host._fillMatchDetailsSources(
        match: widget.match,
        ppvAnchor: widget.ppvAnchor,
        controller: _sourcesCtrl,
        choices: _choices,
        isStale: () => !mounted || gen != _loadGen || _sourcesCtrl.isDisposed,
        onPlayPath: (path) {
          if (mounted) setState(() => _playPath = path);
        },
      );
      if (!mounted || gen != _loadGen) return;
      setState(() => _displayMatch = display);
    } catch (e) {
      debugPrint('[LiveMatches] detail sources error: $e');
    } finally {
      if (mounted && gen == _loadGen && !_sourcesCtrl.isDisposed) {
        _sourcesCtrl.finishSearching();
      }
    }
  }

  void _onSourcePicked(IptvPlaySource picked, List<IptvPlaySource> all) {
    final host = widget.host;
    switch (_playPath) {
      case _LiveMatchPlayPath.engineChoices:
        final hit = host._choiceForPanelSource(picked, _choices);
        if (hit == null) {
          LiveMatchesEngine.engineResolveFailed();
          return;
        }
        unawaited(host._openResolvedStreamChoice(hit, allChoices: _choices));
      case _LiveMatchPlayPath.iptvSports:
        if (picked.liveSourceKind == IptvLiveSourceKind.stremio) {
          final ordered = <IptvPlaySource>[
            picked,
            for (final s in all)
              if (!identical(s, picked) && s.url.trim() != picked.url.trim())
                s,
          ];
          unawaited(
            IptvPtPlayerScreen.open(
              context,
              IptvPtPlayerScreen(
                sources: ordered,
                title: _displayMatch.title,
                subtitle: _displayMatch.categoryLabel,
                titleTracksSource: true,
                engineContext: BuiltInPlayerContext.live,
                liveSourceKind: IptvLiveSourceKind.stremio,
              ),
            ),
          );
          return;
        }
        unawaited(
          host._playIptvSportsSources(_displayMatch, all, picked),
        );
      case _LiveMatchPlayPath.stremioDirect:
        final ordered = <IptvPlaySource>[
          picked,
          for (final s in all)
            if (!identical(s, picked) && s.url.trim() != picked.url.trim()) s,
        ];
        unawaited(
          IptvPtPlayerScreen.open(
            context,
            IptvPtPlayerScreen(
              sources: ordered,
              title: _displayMatch.title,
              subtitle: _displayMatch.categoryLabel,
              titleTracksSource: true,
              engineContext: BuiltInPlayerContext.live,
              liveSourceKind: IptvLiveSourceKind.stremio,
            ),
          ),
        );
    }
  }

  void _playFirstSource() {
    final sources = _sourcesCtrl.sources;
    if (sources.isEmpty) return;
    _onSourcePicked(sources.first, sources);
  }

  void _focusBack() {
    if (_backFocus.canRequestFocus) {
      _backFocus.requestFocus();
    } else {
      maybePopShellOverlay();
    }
  }

  String get _heroTitle {
    final m = _displayMatch;
    final home = (m.homeTeam ?? '').trim();
    final away = (m.awayTeam ?? '').trim();
    if (home.isNotEmpty && away.isNotEmpty) return '$home vs $away';
    return m.title;
  }

  String? get _heroSubtitle {
    final m = _displayMatch;
    final home = (m.homeTeam ?? '').trim();
    final away = (m.awayTeam ?? '').trim();
    if (home.isNotEmpty && away.isNotEmpty && m.title.trim().isNotEmpty) {
      return m.title.trim();
    }
    return null;
  }

  List<String> get _heroMetaParts {
    final m = _displayMatch;
    final viewers = widget.host._cardViewersForMatch(m);
    return [
      if (m.categoryLabel.trim().isNotEmpty) m.categoryLabel.trim(),
      if (m.isLive)
        'Live now'
      else if (m.scheduleLabel.isNotEmpty)
        m.scheduleLabel
      else if (m.timeLabel.isNotEmpty)
        m.timeLabel,
      if (viewers > 0) '$viewers watching',
    ];
  }

  Widget _buildHero({
    required BuildContext context,
    required String backdrop,
    required bool tvFocus,
    required double? height,
    bool chromeOnly = false,
  }) {
    final policy = ShellScope.inputPolicyOf(context);
    return HubDetailsHero(
      backdropUrl: backdrop,
      title: _heroTitle,
      subtitle: _heroSubtitle,
      genres: const [],
      metaParts: _heroMetaParts,
      overview: '',
      height: height,
      chromeOnly: chromeOnly,
      actionRow: DetailsHeroTvActionScope(
        tabId: MediaDetailsTv.tabId,
        itemCount: 1,
        onFocusUp: tvFocus ? _focusBack : null,
        child: HubDetailsPlayRow(
          label: 'Watch',
          enabled: _sourcesCtrl.sources.isNotEmpty,
          onPlay: _playFirstSource,
          focusNode: policy.heroPlayAutoFocus ? _heroPlayFocus : null,
          onUpEdge: tvFocus ? _focusBack : null,
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvItemIndex: 0,
        ),
      ),
    );
  }

  Widget _buildStreamsSection({required bool sideRail, required bool tvFocus}) {
    return ListenableBuilder(
      listenable: _sourcesCtrl,
      builder: (context, _) => _LiveMatchStreamsSection(
        controller: _sourcesCtrl,
        iptvCtrl: _sourcesCtrl.iptvCtrl,
        onSourcePicked: _onSourcePicked,
        onRetry: _loadSources,
        tvFocus: tvFocus,
        sideRail: sideRail,
        showInternationalTab: _playPath == _LiveMatchPlayPath.iptvSports,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final backdrop = _streamedImageUrl(_displayMatch.poster);
    final viewport = MediaQuery.sizeOf(context);
    final sideRail = viewport.width >= 900;

    if (policy.heroPlayAutoFocus &&
        !_detailsHeroInitialFocusDone &&
        _sourcesCtrl.sources.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _detailsHeroInitialFocusDone) return;
        if (_heroPlayFocus.context == null || !_heroPlayFocus.canRequestFocus) {
          return;
        }
        _heroPlayFocus.requestFocus();
        _detailsHeroInitialFocusDone = true;
      });
    }

    final body = sideRail
        ? _buildSideRailBody(
            backdrop: backdrop,
            viewport: viewport,
            tvFocus: tvFocus,
          )
        : MediaDetailsScrollPage(
            scrollController: _scrollController,
            tvHeroPlayFocus: _heroPlayFocus,
            tvBackFocus: _backFocus,
            bodyOverlap: 0,
            topSpacing: DetailsTokens.bodyTopSpacing,
            backgroundColor: AppTheme.bgDark,
            hero: ListenableBuilder(
              listenable: _sourcesCtrl,
              builder: (context, _) => _buildHero(
                context: context,
                backdrop: backdrop,
                tvFocus: tvFocus,
                height: DetailsTokens.heroHeight(context),
              ),
            ),
            sections: [
              _buildStreamsSection(sideRail: false, tvFocus: tvFocus),
            ],
          );

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }

  Widget _buildSideRailBody({
    required String backdrop,
    required Size viewport,
    required bool tvFocus,
  }) {
    final panelWidth = TorrentSourcesPanel.panelWidthOf(context) * 1.2;
    return Stack(
      fit: StackFit.expand,
      children: [
        HubDetailsHeroSurface(
          backdropUrl: backdrop,
          height: viewport.height,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _sourcesCtrl,
                builder: (context, _) => _buildHero(
                  context: context,
                  backdrop: backdrop,
                  tvFocus: tvFocus,
                  height: viewport.height,
                  chromeOnly: true,
                ),
              ),
            ),
            SizedBox(
              width: panelWidth,
              child: ForjaFrostedPanel(
                border: Border(
                  left: BorderSide(
                    color: ForjaShellColors.cinematic.borderSubtle,
                  ),
                ),
                child: _buildStreamsSection(sideRail: true, tvFocus: tvFocus),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveMatchStreamsSection extends StatefulWidget {
  const _LiveMatchStreamsSection({
    required this.controller,
    required this.onSourcePicked,
    required this.onRetry,
    required this.tvFocus,
    this.sideRail = false,
    this.iptvCtrl,
    this.showInternationalTab = false,
  });

  final _IptvSportsChannelsPanelController controller;
  final IptvController? iptvCtrl;
  final void Function(IptvPlaySource picked, List<IptvPlaySource> all)
      onSourcePicked;
  final VoidCallback onRetry;
  final bool tvFocus;
  final bool sideRail;
  final bool showInternationalTab;

  @override
  State<_LiveMatchStreamsSection> createState() =>
      _LiveMatchStreamsSectionState();
}

class _LiveMatchStreamsSectionState extends State<_LiveMatchStreamsSection> {
  static const _tabPortal = 'portal';
  static const _tabInternational = 'international';

  String _tab = _tabPortal;

  _IptvSportsChannelsPanelController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final body = widget.showInternationalTab && _tab == _tabInternational
        ? _buildInternationalBody(context)
        : _buildPortalBody(context);
    if (widget.sideRail) {
      return Padding(
        padding: DetailsTokens.sourcesPanelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: body),
          ],
        ),
      );
    }
    return MediaDetailsBody.padContent(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _buildTabStrip(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    const tabs = [_tabPortal, _tabInternational];
    String label(String key) => switch (key) {
          _tabPortal => 'Portal',
          _tabInternational => 'International TV',
          _ => key,
        };

    if (!tv) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < tabs.length; i++)
            ForjaShellChip(
              label: label(tabs[i]),
              selected: _tab == tabs[i],
              listIndex: i,
              onTap: () => setState(() => _tab = tabs[i]),
            ),
        ],
      );
    }

    return TvChipStrip(
      tabId: MediaDetailsTv.tabId,
      rowId: 'live-match-stream-tabs',
      sortOrder: 1,
      itemCount: tabs.length,
      resultsRowId: 'live-match-stream-list',
      builder: (context, edgesFor) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < tabs.length; i++)
              ForjaShellChip(
                label: label(tabs[i]),
                selected: _tab == tabs[i],
                listIndex: i,
                tvTabId: MediaDetailsTv.tabId,
                tvRowId: 'live-match-stream-tabs',
                onTap: () => setState(() => _tab = tabs[i]),
                onLeftEdge: edgesFor(i).onLeft,
                onRightEdge: edgesFor(i).onRight,
                onDownEdge: edgesFor(i).onDown,
                onUpEdge: edgesFor(i).onUp,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final sources = controller.sources;
    final onPortalTab =
        !widget.showInternationalTab || _tab == _tabPortal;
    final showStatus = onPortalTab &&
        (!controller.searching || sources.isNotEmpty);
    final status = !showStatus
        ? null
        : controller.searching
            ? _IptvSportsPanelCopy.partial(sources.length, controller.searchPhase)
            : (sources.isEmpty
                ? null
                : _IptvSportsPanelCopy.ready(sources.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ShellSectionTitle(title: 'Streams'),
            ),
            if (onPortalTab && !controller.searching && sources.isEmpty)
              TextButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
        if (widget.showInternationalTab) ...[
          const SizedBox(height: 10),
          _buildTabStrip(context),
        ],
        if (status != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (controller.searching) ...[
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
        if (widget.sideRail) const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildInternationalBody(BuildContext context) {
    if (controller.broadcastHintsLoading) {
      return _LiveBroadcastGuideLoading(sideRail: widget.sideRail);
    }

    final hints = controller.broadcastHints;
    if (hints == null || hints.isEmpty) {
      return _LiveBroadcastGuideEmpty(sideRail: widget.sideRail);
    }

    final sections = <_LiveBroadcastProviderSectionData>[
      if (hints.liveOnSat.isNotEmpty)
        _LiveBroadcastProviderSectionData(
          id: 'liveonsat',
          title: 'LiveOnSat',
          subtitle: 'Satellite & regional listings',
          icon: Icons.satellite_alt_rounded,
          accent: const Color(0xFF38BDF8),
          channels: hints.liveOnSat,
        ),
      if (hints.liveSoccerTv.isNotEmpty)
        _LiveBroadcastProviderSectionData(
          id: 'livesoccertv',
          title: 'Live Soccer TV',
          subtitle: 'International coverage',
          icon: Icons.public_rounded,
          accent: ForjaShellColors.sectionAccent,
          channels: hints.liveSoccerTv,
        ),
    ];

    final totalChannels =
        sections.fold<int>(0, (sum, s) => sum + s.channels.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _LiveBroadcastGuideIntro(
              channelCount: totalChannels,
              providerCount: sections.length,
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _LiveBroadcastProviderSection(
                data: sections[i],
                compact: widget.sideRail || !wide,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPortalBody(BuildContext context) {
    final sources = controller.sources;

    if (sources.isEmpty && !controller.searching) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: widget.sideRail ? 16 : 24),
        child: Column(
          mainAxisAlignment: widget.sideRail
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: ForjaShellColors.cinematic.textSecondary
                  .withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              controller.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ForjaShellColors.cinematic.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (sources.isEmpty && controller.searching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
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
                _IptvSportsPanelCopy.searching(controller.searchPhase),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                controller.searchingHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.sideRail) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: sources.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          return _IptvSportsChannelSheetRow(
            source: sources[i],
            iptvCtrl: widget.iptvCtrl,
            healthProbe: controller.healthProbe,
            onTap: () => widget.onSourcePicked(
              sources[i],
              List<IptvPlaySource>.from(sources),
            ),
            tvItemIndex: widget.tvFocus ? i : null,
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final crossCount = wide ? 2 : 1;
        const gap = 10.0;
        final tileWidth = crossCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < sources.length; i++)
              SizedBox(
                width: tileWidth,
                child: _IptvSportsChannelSheetRow(
                  source: sources[i],
                  iptvCtrl: widget.iptvCtrl,
                  healthProbe: controller.healthProbe,
                  onTap: () => widget.onSourcePicked(
                    sources[i],
                    List<IptvPlaySource>.from(sources),
                  ),
                  tvItemIndex: widget.tvFocus ? i : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LiveBroadcastProviderSectionData {
  const _LiveBroadcastProviderSectionData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.channels,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> channels;
}

class _LiveBroadcastGuideIntro extends StatelessWidget {
  const _LiveBroadcastGuideIntro({
    required this.channelCount,
    required this.providerCount,
  });

  final int channelCount;
  final int providerCount;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ForjaShellColors.sectionAccent.withValues(alpha: 0.14),
            cinematic.menuSurface.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: cinematic.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ForjaShellColors.sectionAccent.withValues(alpha: 0.16),
              border: Border.all(
                color: ForjaShellColors.sectionAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.live_tv_rounded,
              size: 18,
              color: ForjaShellColors.sectionAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Broadcast guide',
                  style: TextStyle(
                    color: cinematic.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$channelCount channel${channelCount == 1 ? '' : 's'} '
                  '· $providerCount source${providerCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: cinematic.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reference only — tune these channels on your local '
                  'provider or set-top box. Tap a name to copy.',
                  style: TextStyle(
                    color: cinematic.textSecondary.withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBroadcastGuideLoading extends StatelessWidget {
  const _LiveBroadcastGuideLoading({required this.sideRail});

  final bool sideRail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: sideRail ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LiveBroadcastGuideSkeleton(height: 72),
          const SizedBox(height: 12),
          _LiveBroadcastGuideSkeleton(height: 140),
          const SizedBox(height: 12),
          _LiveBroadcastGuideSkeleton(height: 100),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Scanning broadcast listings…',
              style: TextStyle(
                color: ForjaShellColors.cinematic.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBroadcastGuideSkeleton extends StatelessWidget {
  const _LiveBroadcastGuideSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: ForjaShellColors.surfaceElevated.withValues(alpha: 0.22),
        border: Border.all(
          color: ForjaShellColors.cinematic.borderSubtle.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _LiveBroadcastGuideEmpty extends StatelessWidget {
  const _LiveBroadcastGuideEmpty({required this.sideRail});

  final bool sideRail;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: sideRail ? 20 : 28),
      child: Column(
        mainAxisAlignment:
            sideRail ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cinematic.menuSurface.withValues(alpha: 0.6),
              border: Border.all(color: cinematic.borderSubtle),
            ),
            child: Icon(
              Icons.public_off_rounded,
              size: 26,
              color: cinematic.textSecondary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No broadcast listings',
            style: TextStyle(
              color: cinematic.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This fixture is not listed on LiveOnSat or Live Soccer TV\n'
            'international coverage for your region.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cinematic.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBroadcastProviderSection extends StatelessWidget {
  const _LiveBroadcastProviderSection({
    required this.data,
    required this.compact,
  });

  final _LiveBroadcastProviderSectionData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cinematic.menuSurface.withValues(alpha: 0.42),
        border: Border.all(color: cinematic.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  data.accent.withValues(alpha: 0.95),
                  data.accent.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: data.accent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: data.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(data.icon, size: 17, color: data.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          color: cinematic.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                      ),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          color: cinematic.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: data.accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: data.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    '${data.channels.length}',
                    style: TextStyle(
                      color: data.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: cinematic.borderSubtle.withValues(alpha: 0.65),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = compact ? 1 : 2;
                const gap = 8.0;
                final tileWidth = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final name in data.channels)
                      SizedBox(
                        width: tileWidth,
                        child: _LiveBroadcastChannelChip(
                          name: name,
                          accent: data.accent,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBroadcastChannelChip extends StatefulWidget {
  const _LiveBroadcastChannelChip({
    required this.name,
    required this.accent,
  });

  final String name;
  final Color accent;

  @override
  State<_LiveBroadcastChannelChip> createState() =>
      _LiveBroadcastChannelChipState();
}

class _LiveBroadcastChannelChipState extends State<_LiveBroadcastChannelChip> {
  bool _hovered = false;
  bool _copiedFlash = false;

  Color get _monogramColor {
    final hash = widget.name.hashCode.abs();
    const hues = [205.0, 165.0, 285.0, 28.0, 340.0, 130.0];
    final hue = hues[hash % hues.length];
    return HSLColor.fromAHSL(1, hue, 0.48, 0.44).toColor();
  }

  String get _monogram {
    final parts =
        widget.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      return list.first.characters.take(2).toString().toUpperCase();
    }
    return '${list.first.characters.first}${list[1].characters.first}'
        .toUpperCase();
  }

  Future<void> _copyName() async {
    await Clipboard.setData(ClipboardData(text: widget.name));
    if (!mounted) return;
    setState(() => _copiedFlash = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _copiedFlash = false);
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final borderColor = _copiedFlash
        ? widget.accent.withValues(alpha: 0.65)
        : _hovered
            ? widget.accent.withValues(alpha: 0.35)
            : cinematic.borderSubtle.withValues(alpha: 0.85);
    final bg = _hovered
        ? cinematic.menuSurface.withValues(alpha: 0.72)
        : ForjaShellColors.surfaceElevated.withValues(alpha: 0.28);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _copyName,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _monogramColor.withValues(alpha: 0.95),
                        _monogramColor.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _monogramColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _monogram,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cinematic.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _copiedFlash ? 'Copied' : 'Broadcaster',
                        style: TextStyle(
                          color: _copiedFlash
                              ? widget.accent
                              : cinematic.textSecondary.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    _copiedFlash
                        ? Icons.check_rounded
                        : Icons.content_copy_rounded,
                    key: ValueKey(_copiedFlash),
                    size: 16,
                    color: _copiedFlash
                        ? widget.accent
                        : cinematic.textSecondary.withValues(
                            alpha: _hovered ? 0.75 : 0.35,
                          ),
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

Future<void> _openLiveMatchDetails({
  required _LiveMatchesScreenState host,
  required _StreamedMatch match,
  _DamiTvStream? ppvAnchor,
}) async {
  if (!host.mounted) return;
  await pushShellRoute(
    host.context,
    AppRouter.slideShellRoute(
      (_) => _LiveMatchDetailsScreen(
        host: host,
        match: match,
        ppvAnchor: ppvAnchor,
      ),
      settings: const RouteSettings(name: 'live_matches_detail'),
    ),
    shellTabId: _LiveMatchesScreenState._tabId,
  );
}
