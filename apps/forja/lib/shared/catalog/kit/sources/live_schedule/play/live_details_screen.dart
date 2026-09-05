part of '../live_sports_hub_page.dart';

enum _LiveMatchListTab { providers, liveTv }

/// Play/details host for match chrome (RFC-073) — hub state implements this.
abstract class _LiveSportsPlayHost {
  bool get mounted;
  BuildContext get context;

  Future<void> fillMatchDetailsProviders({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required List<_StreamedStreamChoice> choices,
    required bool Function() isStale,
    _IframeCatalogStream? iframeCatalogAnchor,
    bool force = false,
  });

  Future<_StreamedMatch> fillIptvSportsSources({
    required _StreamedMatch match,
    required _IptvSportsChannelsPanelController controller,
    required bool Function() isStale,
    bool loadBroadcastHints = true,
    bool force = false,
  });

  Future<void> playIptvSportsSources(
    _StreamedMatch match,
    List<IptvPlaySource> sources,
    IptvPlaySource picked,
  );

  _StreamedStreamChoice? choiceForPanelSource(
    IptvPlaySource picked,
    List<_StreamedStreamChoice> choices,
  );

  Future<void> openResolvedStreamChoice(_StreamedStreamChoice choice);

  Future<void> openPanelLiveEngineSource(IptvPlaySource picked);

  int cardViewersForMatch(_StreamedMatch match);
}

/// Match detail — catalog-kit hero + stream cards (replaces Sources-only flow).
class _LiveMatchDetailsScreen extends ConsumerStatefulWidget {
  const _LiveMatchDetailsScreen({
    required this.host,
    required this.match,
    this.iframeCatalogAnchor,
  });

  final _LiveSportsPlayHost host;
  final _StreamedMatch match;
  final _IframeCatalogStream? iframeCatalogAnchor;

  @override
  ConsumerState<_LiveMatchDetailsScreen> createState() =>
      _LiveMatchDetailsScreenState();
}

const _kLiveTvSearchCollapsed = 40.0;
const _kLiveTvSearchExpanded = 260.0;

class _LiveMatchDetailsScreenState
    extends ConsumerState<_LiveMatchDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final _IptvSportsChannelsPanelController _providersCtrl;
  late final _IptvSportsChannelsPanelController _liveTvCtrl;
  final _choices = <_StreamedStreamChoice>[];
  final _backFocus = FocusNode(debugLabel: 'live-match-details-back');
  final _heroPlayFocus = FocusNode(debugLabel: 'live-match-details-play');
  final _liveTvSearchCtrl = TextEditingController();
  final _liveTvSearchFocus =
      FocusNode(debugLabel: 'live-match-details-live-tv-search');
  late final AnimationController _liveTvSearchAnim;
  late final Animation<double> _liveTvSearchExpand;

  late _StreamedMatch _displayMatch;
  int _providersLoadGen = 0;
  int _liveTvLoadGen = 0;
  bool _providersRequested = false;
  bool _liveTvRequested = false;
  bool _detailsHeroInitialFocusDone = false;
  bool _liveTvSearchOpen = false;
  String _liveTvChannelQuery = '';
  _LiveMatchListTab _listTab = _LiveMatchListTab.providers;

  _IptvSportsChannelsPanelController get _activeCtrl =>
      _listTab == _LiveMatchListTab.providers ? _providersCtrl : _liveTvCtrl;

  bool get _showStreamsList => _listTab == _LiveMatchListTab.providers
      ? _providersRequested
      : _liveTvRequested;

  @override
  void initState() {
    super.initState();
    _displayMatch = widget.match;
    final iptvCtrl = ref.read(iptvControllerProvider);
    _providersCtrl = _IptvSportsChannelsPanelController(
      match: widget.match,
      panelTitle: 'Providers',
      emptyMessage: 'No provider streams available',
      searchingHint: 'Loading Forja Live and Stremio',
      iptvCtrl: iptvCtrl,
    );
    _liveTvCtrl = _IptvSportsChannelsPanelController(
      match: widget.match,
      panelTitle: 'Live TV',
      emptyMessage: 'No portal channels matched',
      searchingHint: 'Matching channels on your portal',
      iptvCtrl: iptvCtrl,
    );
    _liveTvSearchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _liveTvSearchExpand = CurvedAnimation(
      parent: _liveTvSearchAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _liveTvSearchFocus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _closeLiveTvSearch(clearQuery: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureTabLoaded(_LiveMatchListTab.providers);
    });
  }

  @override
  void dispose() {
    _providersLoadGen++;
    _liveTvLoadGen++;
    Engine.cancelLiveMatchesFetch();
    _providersCtrl.finishSearching();
    _liveTvCtrl.finishSearching();
    _providersCtrl.dispose();
    _liveTvCtrl.dispose();
    _backFocus.dispose();
    _heroPlayFocus.dispose();
    _liveTvSearchAnim.dispose();
    _liveTvSearchCtrl.dispose();
    _liveTvSearchFocus.dispose();
    super.dispose();
  }

  void _selectTab(_LiveMatchListTab tab) {
    setState(() => _listTab = tab);
    if (tab != _LiveMatchListTab.liveTv) {
      _closeLiveTvSearch(clearQuery: true);
    }
    _ensureTabLoaded(tab);
  }

  void _openLiveTvSearch() {
    if (_liveTvSearchOpen) {
      _liveTvSearchFocus.requestFocus();
      return;
    }
    setState(() => _liveTvSearchOpen = true);
    unawaited(_liveTvSearchAnim.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _liveTvSearchFocus.requestFocus();
    });
  }

  void _closeLiveTvSearch({bool clearQuery = false}) {
    if (!_liveTvSearchOpen && _liveTvChannelQuery.isEmpty) {
      if (_liveTvSearchAnim.value == 0) return;
    }
    _liveTvSearchFocus.unfocus();
    if (clearQuery) {
      _liveTvSearchCtrl.clear();
      _liveTvChannelQuery = '';
    }
    setState(() => _liveTvSearchOpen = false);
    unawaited(_liveTvSearchAnim.reverse());
  }

  void _onLiveTvSearchChanged(String value) {
    final next = value.trim();
    if (next == _liveTvChannelQuery) return;
    setState(() => _liveTvChannelQuery = next);
  }

  void _ensureTabLoaded(_LiveMatchListTab tab) {
    switch (tab) {
      case _LiveMatchListTab.providers:
        if (!_providersRequested) {
          unawaited(_loadProviders());
        }
        break;
      case _LiveMatchListTab.liveTv:
        if (!_liveTvRequested) {
          unawaited(_loadLiveTv());
        }
        break;
    }
  }

  Future<void> _loadProviders({bool force = false}) async {
    if (_providersRequested && !force) return;
    final gen = ++_providersLoadGen;
    final host = widget.host;
    if (mounted) {
      setState(() => _providersRequested = true);
    } else {
      _providersRequested = true;
    }
    if (force) _choices.clear();
    _providersCtrl.resetForLoad();
    _providersCtrl.beginSearching('Providers');
    try {
      if (!mounted || gen != _providersLoadGen || _providersCtrl.isDisposed) {
        return;
      }
      await host.fillMatchDetailsProviders(
        match: widget.match,
        iframeCatalogAnchor: widget.iframeCatalogAnchor,
        controller: _providersCtrl,
        choices: _choices,
        force: force,
        isStale: () =>
            !mounted ||
            gen != _providersLoadGen ||
            _providersCtrl.isDisposed,
      );
    } catch (e) {
      debugPrint('[LiveMatches] detail providers error: $e');
    } finally {
      if (mounted && gen == _providersLoadGen && !_providersCtrl.isDisposed) {
        _providersCtrl.finishSearching();
      }
    }
  }

  Future<void> _loadLiveTv({bool force = false}) async {
    if (_liveTvRequested && !force) return;
    final gen = ++_liveTvLoadGen;
    final host = widget.host;
    if (mounted) {
      setState(() => _liveTvRequested = true);
    } else {
      _liveTvRequested = true;
    }
    _liveTvCtrl.resetForLoad();
    _liveTvCtrl.beginSearching('Live TV');
    try {
      final display = await host.fillIptvSportsSources(
        match: widget.match,
        controller: _liveTvCtrl,
        force: force,
        isStale: () =>
            !mounted || gen != _liveTvLoadGen || _liveTvCtrl.isDisposed,
        loadBroadcastHints: false,
      );
      if (!mounted || gen != _liveTvLoadGen) return;
      setState(() => _displayMatch = display);
    } catch (e) {
      debugPrint('[LiveMatches] detail live tv error: $e');
    } finally {
      if (mounted && gen == _liveTvLoadGen && !_liveTvCtrl.isDisposed) {
        _liveTvCtrl.finishSearching();
      }
    }
  }

  void _retryActiveTab() {
    if (_listTab == _LiveMatchListTab.providers) {
      unawaited(_loadProviders(force: true));
    } else {
      unawaited(_loadLiveTv(force: true));
    }
  }

  void _onSourcePicked(IptvPlaySource picked, List<IptvPlaySource> all) {
    final host = widget.host;
    if (_listTab == _LiveMatchListTab.liveTv) {
      if (picked.liveSourceKind == IptvLiveSourceKind.stremio) {
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
        return;
      }
      unawaited(
        host.playIptvSportsSources(_displayMatch, all, picked),
      );
      return;
    }

    // Providers: play only the tapped row — never stuff sibling providers into
    // the player failover list (WatchFooty must not silently become Streamed).
    if (picked.liveSourceKind == IptvLiveSourceKind.stremio) {
      unawaited(
        IptvPtPlayerScreen.open(
          context,
          IptvPtPlayerScreen(
            sources: [picked],
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

    if (picked.liveSourceKind == IptvLiveSourceKind.liveEngine) {
      final hit = host.choiceForPanelSource(picked, _choices);
      if (hit != null) {
        unawaited(host.openResolvedStreamChoice(hit));
        return;
      }
      unawaited(host.openPanelLiveEngineSource(picked));
      return;
    }

    LiveMatchesEngine.engineResolveFailed();
  }

  Widget _buildToggleRow({required bool tvFocus}) {
    final showLiveTvSearch = _listTab == _LiveMatchListTab.liveTv;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DetailsHeroTvActionScope(
          tabId: MediaDetailsTv.tabId,
          itemCount: 2,
          onFocusUp: tvFocus ? _focusBack : null,
          onFocusDown: tvFocus ? () {} : null,
          child: HeroPillSegmentedChoice<_LiveMatchListTab>(
            segments: const [
              HeroPillSegment(
                value: _LiveMatchListTab.providers,
                label: 'Providers',
                icon: Icons.dns_rounded,
              ),
              HeroPillSegment(
                value: _LiveMatchListTab.liveTv,
                label: 'Live TV',
                icon: Icons.live_tv_rounded,
              ),
            ],
            selected: _listTab,
            onSelected: _selectTab,
            onUpEdge: tvFocus ? _focusBack : null,
            tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
            tvRowId: tvFocus ? MediaDetailsTv.heroRowId : null,
            tvItemIndexStart: 0,
          ),
        ),
        if (showLiveTvSearch) ...[
          const SizedBox(width: 16),
          _buildLiveTvExpandingSearch(tvFocus: tvFocus),
        ],
      ],
    );
  }

  Widget _buildLiveTvExpandingSearch({required bool tvFocus}) {
    return AnimatedBuilder(
      animation: _liveTvSearchExpand,
      builder: (context, _) {
        final t = _liveTvSearchExpand.value;
        final width = _kLiveTvSearchCollapsed +
            (_kLiveTvSearchExpanded - _kLiveTvSearchCollapsed) * t;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: _kLiveTvSearchCollapsed,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.hardEdge,
                children: [
                  Opacity(
                    opacity: t,
                    child: IgnorePointer(
                      ignoring: t < 0.55,
                      child: OverflowBox(
                        maxWidth: _kLiveTvSearchExpanded,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: _kLiveTvSearchExpanded,
                          child: _buildLiveTvSearchField(
                            context: context,
                            tvFocus: tvFocus,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (t < 0.95)
                    Opacity(
                      opacity: (1.0 - t * 1.4).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: t > 0.2,
                        child: _buildLiveTvSearchIcon(
                          context: context,
                          tvFocus: tvFocus,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveTvSearchIcon({
    required BuildContext context,
    required bool tvFocus,
  }) {
    return shellFocusableTap(
      context: context,
      onTap: _openLiveTvSearch,
      borderRadius: _kLiveTvSearchCollapsed / 2,
      scaleOnFocus: 1.0,
      child: Tooltip(
        message: 'Search channels',
        child: Container(
          width: _kLiveTvSearchCollapsed,
          height: _kLiveTvSearchCollapsed,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(_kLiveTvSearchCollapsed / 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(
            Icons.search_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveTvSearchField({
    required BuildContext context,
    required bool tvFocus,
  }) {
    return Container(
      height: _kLiveTvSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(_kLiveTvSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: tvFocus
                ? TvBrowseTextField(
                    controller: _liveTvSearchCtrl,
                    focusNode: _liveTvSearchFocus,
                    onChanged: _onLiveTvSearchChanged,
                    onEscape: () => _closeLiveTvSearch(clearQuery: true),
                    onSubmitted: (_) => _liveTvSearchFocus.unfocus(),
                    browsePlaceholder: 'Search channels…',
                    browseHintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13,
                    ),
                    caretHeight: 16,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  )
                : TextField(
                    controller: _liveTvSearchCtrl,
                    focusNode: _liveTvSearchFocus,
                    onChanged: _onLiveTvSearchChanged,
                    onSubmitted: (_) => _liveTvSearchFocus.unfocus(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    cursorColor: ForjaShellColors.sectionAccent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search channels…',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
          ),
          shellFocusableTap(
            context: context,
            onTap: () => _closeLiveTvSearch(clearQuery: true),
            borderRadius: 16,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamsListPanel({required bool tvFocus}) {
    final active = _activeCtrl;
    return ListenableBuilder(
      listenable: active,
      builder: (context, _) => _LiveMatchStreamsSection(
        controller: active,
        iptvCtrl: active.iptvCtrl,
        onSourcePicked: _onSourcePicked,
        onRetry: _retryActiveTab,
        tvFocus: tvFocus,
        inlineHero: true,
        browseByCategory: _listTab == _LiveMatchListTab.liveTv,
        channelQuery: _listTab == _LiveMatchListTab.liveTv
            ? _liveTvChannelQuery
            : '',
      ),
    );
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
    final viewers = widget.host.cardViewersForMatch(m);
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
    required double height,
  }) {
    return HubDetailsHero(
      backdropUrl: backdrop,
      title: _heroTitle,
      subtitle: _heroSubtitle,
      genres: const [],
      metaParts: _heroMetaParts,
      overview: '',
      height: height,
      actionRow: _buildToggleRow(tvFocus: tvFocus),
      belowActionRowFullWidth: true,
      belowActionRow: _showStreamsList
          ? ListenableBuilder(
              listenable: Listenable.merge([_providersCtrl, _liveTvCtrl]),
              builder: (context, _) =>
                  _buildStreamsListPanel(tvFocus: tvFocus),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvFocus = policy.useFocusableMoodChips;
    final backdrop = _streamedImageUrl(_displayMatch.poster);
    final viewport = MediaQuery.sizeOf(context);

    if (policy.heroPlayAutoFocus && !_detailsHeroInitialFocusDone) {
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
          // Do not wrap the whole hero in a ListenableBuilder — that can skip
          // rebuilds when only `_liveTvChannelQuery` changes (search filter).
          // Controllers notify via the streams panel ListenableBuilder instead.
          _buildHero(
            context: context,
            backdrop: backdrop,
            tvFocus: tvFocus,
            height: viewport.height,
          ),
          MediaDetailsBackButton(focusNode: _backFocus),
        ],
      ),
    );
  }
}

/// Empty key = **All** (every matched channel).
const _kLiveTvCategoryAll = '';

String _liveTvCategoryKey(IptvPlaySource source) {
  final cat = (source.pickerSubtitle ?? '').trim();
  return cat.isEmpty ? 'Other' : cat;
}

class _LiveTvCategoryBucket {
  const _LiveTvCategoryBucket({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;
}

/// Unique portal categories in match-rank order (first appearance).
List<_LiveTvCategoryBucket> _liveTvCategoriesFromSources(
  List<IptvPlaySource> sources,
) {
  final order = <String>[];
  final counts = <String, int>{};
  for (final s in sources) {
    final key = _liveTvCategoryKey(s);
    final prev = counts[key];
    if (prev == null) {
      order.add(key);
      counts[key] = 1;
    } else {
      counts[key] = prev + 1;
    }
  }
  return [
    for (final k in order)
      _LiveTvCategoryBucket(key: k, label: k, count: counts[k]!),
  ];
}

List<IptvPlaySource> _liveTvFilterByCategory(
  List<IptvPlaySource> sources,
  String selectedKey,
) {
  if (selectedKey == _kLiveTvCategoryAll) return sources;
  return [
    for (final s in sources)
      if (_liveTvCategoryKey(s) == selectedKey) s,
  ];
}

bool _liveTvSourceMatchesQuery(IptvPlaySource source, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = [
    source.chromeTitle,
    source.label,
    source.detail,
    source.pickerSubtitle,
  ].whereType<String>().map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty);
  for (final part in hay) {
    if (part.contains(q)) return true;
  }
  return false;
}

List<IptvPlaySource> _liveTvFilterByQuery(
  List<IptvPlaySource> sources,
  String query,
) {
  final q = query.trim();
  if (q.isEmpty) return sources;
  return [
    for (final s in sources)
      if (_liveTvSourceMatchesQuery(s, q)) s,
  ];
}

class _LiveMatchStreamsSection extends StatefulWidget {
  const _LiveMatchStreamsSection({
    required this.controller,
    required this.onSourcePicked,
    required this.onRetry,
    required this.tvFocus,
    this.iptvCtrl,
    this.inlineHero = false,
    this.browseByCategory = false,
    this.channelQuery = '',
  });

  final _IptvSportsChannelsPanelController controller;
  final IptvController? iptvCtrl;
  final void Function(IptvPlaySource picked, List<IptvPlaySource> all)
      onSourcePicked;
  final VoidCallback onRetry;
  final bool tvFocus;
  final bool inlineHero;
  /// Live TV: IPTV-style Categories | Channels split when wide enough.
  final bool browseByCategory;
  /// Live TV channel text filter (from expanding search next to the tab).
  final String channelQuery;

  @override
  State<_LiveMatchStreamsSection> createState() =>
      _LiveMatchStreamsSectionState();
}

class _LiveMatchStreamsSectionState extends State<_LiveMatchStreamsSection> {
  _IptvSportsChannelsPanelController get controller => widget.controller;

  /// [_kLiveTvCategoryAll] or a portal category label.
  String _selectedCategoryKey = _kLiveTvCategoryAll;

  String _effectiveCategoryKey(List<_LiveTvCategoryBucket> cats) {
    if (cats.length == 1) return cats.first.key;
    if (_selectedCategoryKey == _kLiveTvCategoryAll) return _kLiveTvCategoryAll;
    if (cats.any((c) => c.key == _selectedCategoryKey)) {
      return _selectedCategoryKey;
    }
    return _kLiveTvCategoryAll;
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildPortalBody(context);

    if (widget.inlineHero) {
      return _wrapInlineHeroPanel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInlineStatus(context),
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

  Widget _wrapInlineHeroPanel(Widget child) {
    // Soft edge fade — keep top opaque sooner so the scrim sits under the
    // first stream-card row (was fading through ~16% and leaving them bare).
    Shader fadeMask(Rect bounds, Alignment begin, Alignment end) {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.06, 0.88, 1.0],
      ).createShader(bounds);
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // Lift scrim above the panel so it covers the gap under the tab row
        // and sits behind the top stream cards.
        Positioned(
          left: 0,
          right: 0,
          top: -28,
          bottom: 0,
          child: IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) =>
                  fadeMask(bounds, Alignment.topCenter, Alignment.bottomCenter),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => fadeMask(
                  bounds,
                  Alignment.centerLeft,
                  Alignment.centerRight,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: child,
        ),
      ],
    );
  }

  Widget _buildInlineStatus(BuildContext context) {
    final sources = controller.sources;
    if (controller.searching && sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: ForjaShellColors.sectionAccent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _IptvSportsPanelCopy.searching(controller.searchPhase),
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.searchingHint,
                    style: TextStyle(
                      color: ForjaShellColors.cinematic.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final showStatus = !controller.searching || sources.isNotEmpty;
    final status = !showStatus
        ? null
        : controller.searching
            ? _IptvSportsPanelCopy.partial(sources.length, controller.searchPhase)
            : (sources.isEmpty
                ? null
                : _IptvSportsPanelCopy.ready(sources.length));
    if (status == null && !(!controller.searching && sources.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
          if (status != null)
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textPrimary
                      .withValues(alpha: 0.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (!controller.searching && sources.isEmpty)
            TextButton(
              onPressed: widget.onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
  Widget _buildHeader(BuildContext context) {
    final sources = controller.sources;
    final showStatus = !controller.searching || sources.isNotEmpty;
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
              child: ShellSectionTitle(title: controller.panelTitle),
            ),
            if (!controller.searching && sources.isEmpty)
              TextButton(
                onPressed: widget.onRetry,
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
      ],
    );
  }

  Widget _buildPortalBody(BuildContext context) {
    final sources = controller.sources;
    final emptyPad = widget.inlineHero ? 12.0 : 24.0;

    if (sources.isEmpty && !controller.searching) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: emptyPad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
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
      if (widget.inlineHero) return const SizedBox.shrink();
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

    if (widget.browseByCategory) {
      return _buildCategoryBrowse(context, sources);
    }
    return _buildSourcesGrid(context, sources);
  }

  Widget _buildCategoryBrowse(
    BuildContext context,
    List<IptvPlaySource> allSources,
  ) {
    final queried = _liveTvFilterByQuery(allSources, widget.channelQuery);
    final cats = _liveTvCategoriesFromSources(queried);
    final selected = _effectiveCategoryKey(cats);
    final filtered = _liveTvFilterByCategory(queried, selected);
    final showAll = cats.length >= 2;
    final searching = widget.channelQuery.trim().isNotEmpty;

    if (queried.isEmpty && searching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: ForjaShellColors.cinematic.textSecondary
                  .withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'No channels match “${widget.channelQuery.trim()}”',
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 520;
        if (!split) {
          return _buildSourcesGrid(
            context,
            filtered,
            allForPlay: allSources,
            hideCategorySubtitle: false,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: constraints.maxWidth >= 720 ? 200 : 168,
              child: _buildCategoryRail(
                context,
                cats: cats,
                showAll: showAll,
                allCount: queried.length,
                selectedKey: selected,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: ForjaShellColors.borderSubtle,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSourcesGrid(
                context,
                filtered,
                allForPlay: allSources,
                hideCategorySubtitle: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryRail(
    BuildContext context, {
    required List<_LiveTvCategoryBucket> cats,
    required bool showAll,
    required int allCount,
    required String selectedKey,
  }) {
    final rows = <({String key, String label, int count})>[
      if (showAll) (key: _kLiveTvCategoryAll, label: 'All', count: allCount),
      for (final c in cats) (key: c.key, label: c.label, count: c.count),
    ];

    return ListView.separated(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final row = rows[i];
        final selected = row.key == selectedKey;
        return _LiveTvCategoryRailRow(
          label: row.label,
          count: row.count,
          selected: selected,
          listIndex: i,
          onTap: () {
            if (_selectedCategoryKey == row.key) return;
            setState(() => _selectedCategoryKey = row.key);
          },
        );
      },
    );
  }

  /// Title + host footer + two provider lines (pad included).
  static const _kSourceCardMinHeight = 60.0;

  Widget _buildSourcesGrid(
    BuildContext context,
    List<IptvPlaySource> sources, {
    List<IptvPlaySource>? allForPlay,
    bool hideCategorySubtitle = false,
  }) {
    final playAll = allForPlay ?? sources;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = widget.inlineHero || constraints.maxWidth >= 720;
        final crossCount = wide ? 2 : 1;
        const gap = 10.0;

        if (crossCount == 1) {
          if (widget.inlineHero) {
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(height: gap),
              itemBuilder: (context, i) => _sourceCard(
                context,
                sources,
                i,
                allForPlay: playAll,
                hideCategorySubtitle: hideCategorySubtitle,
              ),
            );
          }
          return Wrap(
            runSpacing: gap,
            children: [
              for (var i = 0; i < sources.length; i++)
                SizedBox(
                  width: constraints.maxWidth,
                  child: _sourceCard(
                    context,
                    sources,
                    i,
                    allForPlay: playAll,
                    hideCategorySubtitle: hideCategorySubtitle,
                  ),
                ),
            ],
          );
        }

        final rowCount = (sources.length + 1) ~/ 2;
        if (widget.inlineHero) {
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: rowCount,
            itemBuilder: (context, row) {
              final left = row * 2;
              final right = left + 1;
              return Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _sourceCard(
                          context,
                          sources,
                          left,
                          allForPlay: playAll,
                          hideCategorySubtitle: hideCategorySubtitle,
                        ),
                      ),
                      const SizedBox(width: gap),
                      Expanded(
                        child: right < sources.length
                            ? _sourceCard(
                                context,
                                sources,
                                right,
                                allForPlay: playAll,
                                hideCategorySubtitle: hideCategorySubtitle,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < sources.length; i++)
              SizedBox(
                width: tileWidth,
                child: _sourceCard(
                  context,
                  sources,
                  i,
                  allForPlay: playAll,
                  hideCategorySubtitle: hideCategorySubtitle,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _sourceCard(
    BuildContext context,
    List<IptvPlaySource> sources,
    int i, {
    required List<IptvPlaySource> allForPlay,
    bool hideCategorySubtitle = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kSourceCardMinHeight),
      child: _sourceRow(
        context,
        sources,
        i,
        allForPlay: allForPlay,
        hideCategorySubtitle: hideCategorySubtitle,
      ),
    );
  }

  Widget _sourceRow(
    BuildContext context,
    List<IptvPlaySource> sources,
    int i, {
    required List<IptvPlaySource> allForPlay,
    bool hideCategorySubtitle = false,
  }) {
    return _IptvSportsChannelSheetRow(
      source: sources[i],
      iptvCtrl: widget.iptvCtrl,
      healthProbe: controller.healthProbe,
      hideCategorySubtitle: hideCategorySubtitle,
      onTap: () => widget.onSourcePicked(
        sources[i],
        List<IptvPlaySource>.from(allForPlay),
      ),
      tvItemIndex: widget.tvFocus ? i : null,
    );
  }
}

class _LiveTvCategoryRailRow extends StatefulWidget {
  const _LiveTvCategoryRailRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.listIndex,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final int listIndex;

  @override
  State<_LiveTvCategoryRailRow> createState() => _LiveTvCategoryRailRowState();
}

class _LiveTvCategoryRailRowState extends State<_LiveTvCategoryRailRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final lit = selected || _focused || _hovered;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? ForjaShellColors.sectionAccent.withValues(alpha: 0.18)
            : lit
                ? ForjaShellColors.surfaceElevated
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? ForjaShellColors.sectionAccent.withValues(alpha: 0.55)
              : _focused
                  ? ForjaShellColors.sectionAccent.withValues(alpha: 0.35)
                  : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? ForjaShellColors.cinematic.textPrimary
                    : ForjaShellColors.cinematic.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.count}',
            style: TextStyle(
              color: ForjaShellColors.cinematic.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      listIndex: widget.listIndex,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: tile,
    );
  }
}


Future<void> _openLiveMatchDetails({
  required _LiveSportsPlayHost host,
  required _StreamedMatch match,
  _IframeCatalogStream? iframeCatalogAnchor,
}) async {
  if (!host.mounted) return;
  await pushShellRoute(
    host.context,
    AppRouter.slideShellRoute(
      (_) => _LiveMatchDetailsScreen(
        host: host,
        match: match,
        iframeCatalogAnchor: iframeCatalogAnchor,
      ),
      settings: const RouteSettings(name: 'live_matches_detail'),
    ),
    shellTabId: LiveSportsHubPageState._tabId,
  );
}
