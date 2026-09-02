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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSources());
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

  Future<void> _loadSources() async {
    final gen = ++_loadGen;
    final host = widget.host;
    _playPath = _LiveMatchPlayPath.engineChoices;
    _sourcesCtrl.setSearchPhase('streams');
    try {
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

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final backdrop = _streamedImageUrl(_displayMatch.poster);

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

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListenableBuilder(
            listenable: _sourcesCtrl,
            builder: (context, _) {
              return MediaDetailsScrollPage(
                scrollController: _scrollController,
                tvHeroPlayFocus: _heroPlayFocus,
                tvBackFocus: _backFocus,
                bodyOverlap: 0,
                topSpacing: DetailsTokens.bodyTopSpacing,
                backgroundColor: AppTheme.bgDark,
                hero: HubDetailsHero(
                  backdropUrl: backdrop,
                  title: _heroTitle,
                  subtitle: _heroSubtitle,
                  genres: const [],
                  metaParts: _heroMetaParts,
                  overview: '',
                  height: DetailsTokens.heroHeight(context),
                  actionRow: DetailsHeroTvActionScope(
                    tabId: MediaDetailsTv.tabId,
                    itemCount: 1,
                    onFocusUp: tvFocus ? _focusBack : null,
                    child: HubDetailsPlayRow(
                      label: 'Watch',
                      enabled: _sourcesCtrl.sources.isNotEmpty,
                      onPlay: _playFirstSource,
                      focusNode:
                          policy.heroPlayAutoFocus ? _heroPlayFocus : null,
                      onUpEdge: tvFocus ? _focusBack : null,
                      tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
                      tvItemIndex: 0,
                    ),
                  ),
                ),
                sections: [
                  _LiveMatchStreamsSection(
                    controller: _sourcesCtrl,
                    iptvCtrl: _sourcesCtrl.iptvCtrl,
                    onSourcePicked: _onSourcePicked,
                    onRetry: _loadSources,
                    tvFocus: tvFocus,
                  ),
                ],
              );
            },
          ),
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }
}

class _LiveMatchStreamsSection extends StatelessWidget {
  const _LiveMatchStreamsSection({
    required this.controller,
    required this.onSourcePicked,
    required this.onRetry,
    required this.tvFocus,
    this.iptvCtrl,
  });

  final _IptvSportsChannelsPanelController controller;
  final IptvController? iptvCtrl;
  final void Function(IptvPlaySource picked, List<IptvPlaySource> all)
      onSourcePicked;
  final VoidCallback onRetry;
  final bool tvFocus;

  @override
  Widget build(BuildContext context) {
    final sources = controller.sources;
    final showStatus = !controller.searching || sources.isNotEmpty;
    final status = !showStatus
        ? null
        : controller.searching
            ? _IptvSportsPanelCopy.partial(sources.length, controller.searchPhase)
            : (sources.isEmpty
                ? null
                : _IptvSportsPanelCopy.ready(sources.length));

    return MediaDetailsBody.padContent(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ShellSectionTitle(title: 'Streams'),
              ),
              if (!controller.searching && sources.isEmpty)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
            ],
          ),
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
          const SizedBox(height: 12),
          if (sources.isEmpty && !controller.searching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
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
            )
          else if (sources.isEmpty && controller.searching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
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
            )
          else
            LayoutBuilder(
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
                          iptvCtrl: iptvCtrl,
                          healthProbe: controller.healthProbe,
                          onTap: () => onSourcePicked(
                            sources[i],
                            List<IptvPlaySource>.from(sources),
                          ),
                          tvItemIndex: tvFocus ? i : null,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
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
