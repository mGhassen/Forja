part of 'player_stream_menu.dart';

enum _StreamAudioFilter { sub, dub }

bool _matchesAudioFilter(
  String providerId,
  dynamic provider,
  _StreamAudioFilter filter,
) {
  final category = PlayerStreamMenu.providerAudioCategory(providerId, provider);
  if (category == null) return true;
  return category == filter.name;
}

class _StreamMenuOverlay extends StatefulWidget {
  const _StreamMenuOverlay({
    required this.readState,
    required this.onLoadProvider,
    required this.onSelectProvider,
    required this.onSelectSource,
    required this.onCheckSource,
    required this.onClose,
    this.onTogglePlayPause,
    this.providers,
    this.providerSourcesCache,
    this.providerLoadFailures,
    this.providerProbesNotifier,
    this.statusController,
    this.providersEnabled = true,
    this.refreshListenable,
    this.onReload,
    this.isReloading,
    this.movie,
    this.selectedSeason,
    this.selectedEpisode,
    this.hubEpisodeNumber,
    this.activeProvider,
    this.readUrlCheckStatuses,
  });

  final Map<String, dynamic>? providers;
  final ValueListenable<Map<String, List<StreamSource>>>? providerSourcesCache;
  final ValueListenable<Set<String>>? providerLoadFailures;
  final ValueListenable<List<StreamProviderProbe>>? providerProbesNotifier;
  final PlayerStatusController? statusController;
  final PlayerStreamMenuState Function() readState;
  final Future<List<StreamSource>?> Function(
    String providerId, {
    bool forceRefresh,
  }) onLoadProvider;
  final Future<List<StreamSource>?> Function(String providerId) onSelectProvider;
  final Future<void> Function(StreamSource source, int index) onSelectSource;
  final Future<bool> Function(StreamSource source, int index, [String? providerId])
      onCheckSource;
  final VoidCallback? onTogglePlayPause;
  final bool providersEnabled;
  final Listenable? refreshListenable;
  final Future<void> Function()? onReload;
  final ValueListenable<bool>? isReloading;
  final Movie? movie;
  final int? selectedSeason;
  final int? selectedEpisode;
  final num? hubEpisodeNumber;
  final String? activeProvider;
  final Map<String, PlayerSourceStatus> Function()? readUrlCheckStatuses;
  final VoidCallback onClose;

  @override
  State<_StreamMenuOverlay> createState() => _StreamMenuOverlayState();
}

class _StreamMenuOverlayState extends State<_StreamMenuOverlay> {
  /// Start open so the first paint includes the opaque scrim (anime / drama
  /// Source menu). Delayed open left the seek bar live under the overlay.
  bool _open = true;
  final Set<String> _loadingProviders = {};
  /// Providers whose stream branch is collapsed (loaded but hidden).
  final Set<String> _collapsedProviders = {};
  final Map<String, int> _loadGens = {};
  final Map<String, PlayerSourceStatus> _urlStatuses = {};
  _StreamAudioFilter? _audioFilter;

  Set<String> get _failedProviders =>
      widget.providerLoadFailures?.value ?? const {};

  @override
  void initState() {
    super.initState();
    ProviderScoreMemory.revision.addListener(_onScoreRevision);
    playerChromeCancelSeekScrubs();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await ProviderScoreMemory.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _initAudioFilterDefault();
      _open = true;
    });
  }

  void _initAudioFilterDefault() {
    if (!PlayerStreamMenu.hasSubDubProviders(widget.providers)) {
      _audioFilter = null;
      return;
    }
    final state = widget.readState();
    final currentId = state.currentProviderId;
    if (currentId != null && widget.providers!.containsKey(currentId)) {
      final cat = PlayerStreamMenu.providerAudioCategory(
        currentId,
        widget.providers![currentId],
      );
      _audioFilter = cat == 'dub'
          ? _StreamAudioFilter.dub
          : _StreamAudioFilter.sub;
      return;
    }
    _audioFilter = _StreamAudioFilter.sub;
  }

  @override
  void dispose() {
    ProviderScoreMemory.revision.removeListener(_onScoreRevision);
    super.dispose();
  }

  void _onScoreRevision() {
    if (!mounted) return;
    setState(() {});
  }

  void _setUrlStatus(String url, PlayerSourceStatus status) {
    if (!mounted) return;
    setState(() => _urlStatuses[url] = status);
  }

  List<MapEntry<String, dynamic>> _computeProviderOrder() {
    if (widget.providers == null || widget.providers!.isEmpty) {
      return const [];
    }
    final probes = widget.providerProbesNotifier?.value ?? const [];
    final scoreRows = PlayerStreamMenu._providerScoreRows(
      widget.movie,
      widget.providers,
    );
    return PlayerStreamMenu.orderedProviderEntriesForPanel(
      widget.providers!,
      scoreRows: scoreRows,
      probes: probes,
    );
  }

  bool get _hasProviders =>
      widget.providers != null && widget.providers!.isNotEmpty;

  List<StreamSource> _sectionSources({
    required String providerId,
    required PlayerStreamMenuState state,
    required Map<String, List<StreamSource>> cache,
  }) {
    return PlayerStreamMenu.sourcesForProvider(
      providerId: providerId,
      state: state,
      cache: cache,
    );
  }

  void _toggleServerExpanded(String providerId) {
    setState(() {
      if (_collapsedProviders.contains(providerId)) {
        _collapsedProviders.remove(providerId);
      } else {
        _collapsedProviders.add(providerId);
      }
    });
  }

  /// One server check at a time — drop other spinners and invalidate their gens.
  void _supersedeOtherServerLoads(String providerId) {
    final others = _loadingProviders.where((id) => id != providerId).toList();
    for (final id in others) {
      _loadGens[id] = (_loadGens[id] ?? 0) + 1;
      widget.statusController?.remove('provider-$id');
    }
    final probes = widget.providerProbesNotifier;
    if (probes is ValueNotifier<List<StreamProviderProbe>> &&
        probes.value.any(
          (p) =>
              p.id != providerId &&
              p.status == StreamProviderProbeStatus.trying,
        )) {
      probes.value = [
        for (final p in probes.value)
          if (p.id != providerId &&
              p.status == StreamProviderProbeStatus.trying)
            p.copyWith(status: StreamProviderProbeStatus.pending)
          else
            p,
      ];
    }
    if (others.isNotEmpty || !_loadingProviders.contains(providerId)) {
      setState(() {
        _loadingProviders
          ..removeWhere((id) => id != providerId)
          ..add(providerId);
      });
    }
  }

  Future<void> _loadServer(
    String providerId, {
    bool clearCache = false,
  }) async {
    if (!widget.providersEnabled) return;
    if (_loadingProviders.contains(providerId)) return;

    final gen = (_loadGens[providerId] ?? 0) + 1;
    _loadGens[providerId] = gen;
    _supersedeOtherServerLoads(providerId);
    setState(() {
      _loadingProviders.add(providerId);
      _collapsedProviders.remove(providerId);
    });

    if (clearCache) {
      final cache = widget.providerSourcesCache;
      if (cache is ValueNotifier<Map<String, List<StreamSource>>>) {
        final previous = cache.value[providerId];
        if (previous != null && previous.isNotEmpty) {
          setState(() {
            for (final source in previous) {
              _urlStatuses.remove(source.url);
            }
          });
        }
        final next = Map<String, List<StreamSource>>.from(cache.value)
          ..remove(providerId);
        cache.value = next;
      }
    }

    try {
      final sources = await widget.onLoadProvider(
        providerId,
        forceRefresh: clearCache,
      );
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() => _loadingProviders.remove(providerId));
      // Do not auto-probe every stream in the background while something is
      // already playing — user taps a row to check or switch.
    } catch (_) {
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() => _loadingProviders.remove(providerId));
    }
  }

  Future<void> _reloadServer(String providerId) async {
    await _loadServer(providerId, clearCache: true);
  }

  void _onServerRowTap({
    required String providerId,
    required bool isLoaded,
  }) {
    if (!widget.providersEnabled) return;
    if (_loadingProviders.contains(providerId)) return;
    if (isLoaded) {
      _toggleServerExpanded(providerId);
      return;
    }
    unawaited(_loadServer(providerId));
  }

  Widget _buildServerGroup({
    required String providerId,
    required dynamic provider,
    required PlayerStreamMenuState state,
    required List<StreamProviderProbe> probes,
    required Map<String, List<StreamSource>> cache,
  }) {
    final isCurrent = providerId == state.currentProviderId;
    final isPlaying = isCurrent && state.playbackConfirmed;
    final sectionSources = _sectionSources(
      providerId: providerId,
      state: state,
      cache: cache,
    );
    final isLoaded = sectionSources.isNotEmpty;
    final isExpanded = isLoaded && !_collapsedProviders.contains(providerId);
    final isReloading = _loadingProviders.contains(providerId);
    final status = PlayerStreamMenu._resolveProviderStatus(
      providerId,
      probes: probes,
      isCurrent: isCurrent,
      statusController: widget.statusController,
      playbackConfirmed: state.playbackConfirmed,
      loadingProviders: _loadingProviders,
      failedProviders: _failedProviders,
      hasLoadedSources: isLoaded,
    );
    final presentation =
        PlayerStreamMenu._serverPresentation(providerId, provider);
    final hideCategoryBadge =
        PlayerStreamMenu.hasSubDubProviders(widget.providers);
    final subtitle = PlayerStreamMenu._providerSubtitle(
      sourceCount: sectionSources.length,
      isPlaying: isPlaying,
    );
    final canInteract = widget.providersEnabled && !isReloading;
    final scoreScope = PlayerStreamMenu.scoreScope(
      movie: widget.movie,
      providers: widget.providers,
      selectedSeason: widget.selectedSeason,
      selectedEpisode: widget.selectedEpisode,
      hubEpisodeNumber: widget.hubEpisodeNumber,
      activeProvider: widget.activeProvider,
    );
    final mergedUrlStatuses = {
      ...?widget.readUrlCheckStatuses?.call(),
      ..._urlStatuses,
    };

    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: _ServerMenuHeader(
            label: presentation.label,
            subtitle: subtitle,
            status: status,
            isLoaded: isLoaded,
            isPlaying: isPlaying,
            isReloading: isReloading,
            showReload: (isLoaded || isReloading) && widget.providersEnabled,
            categoryBadge: presentation.categoryBadge,
            scoreScope: scoreScope,
            providerId: providerId,
            hideCategoryBadge: hideCategoryBadge,
            onTap: canInteract
                ? () => _onServerRowTap(
                      providerId: providerId,
                      isLoaded: isLoaded,
                    )
                : null,
            onReload: widget.providersEnabled && isLoaded && !isReloading
                ? () => unawaited(_reloadServer(providerId))
                : null,
          ),
        ),
        if (isExpanded)
          _ServerStreamBranch(
            child: PlayerStreamMenu._sourcesList(
              sources: sectionSources,
              state: state,
              useIndexedStatuses: isCurrent,
              providerId: providerId,
              serverLabel: presentation.label,
              urlStatuses: mergedUrlStatuses,
              onUrlStatus: _setUrlStatus,
              onCheckSource: widget.onCheckSource,
              onSelectSource: (source, index) async {
                if (!isCurrent) {
                  final loaded = await widget.onSelectProvider(providerId);
                  final pool = loaded ?? sectionSources;
                  final targetIndex =
                      pool.indexWhere((s) => s.url == source.url);
                  if (targetIndex >= 0) {
                    await widget.onSelectSource(pool[targetIndex], targetIndex);
                    return;
                  }
                }
                await widget.onSelectSource(source, index);
              },
              onTogglePlayPause: widget.onTogglePlayPause,
            ),
          ),
      ],
    );

    return SizedBox(width: double.infinity, child: group);
  }

  Widget _buildList() {
    final state = widget.readState();
    final probes = widget.providerProbesNotifier?.value ?? const [];
    final cache = widget.providerSourcesCache?.value ?? const {};

    // Clear stale loading flags when cache fills from outside the panel.
    final loadedWhileLoading = _loadingProviders
        .where((id) => (cache[id]?.isNotEmpty ?? false))
        .toList();
    if (loadedWhileLoading.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          for (final id in loadedWhileLoading) {
            _loadingProviders.remove(id);
          }
        });
      });
    }

    if (!_hasProviders) {
      final mergedUrlStatuses = {
        ...?widget.readUrlCheckStatuses?.call(),
        ..._urlStatuses,
      };
      return PlayerStreamMenu._sourcesList(
        sources: state.sources ?? const [],
        state: state,
        onCheckSource: widget.onCheckSource,
        onSelectSource: widget.onSelectSource,
        urlStatuses: mergedUrlStatuses,
        onUrlStatus: _setUrlStatus,
        useIndexedStatuses: true,
      );
    }

    final providerOrder = _computeProviderOrder();
    final orderedProviders = _audioFilter == null
        ? providerOrder
        : providerOrder
            .where(
              (e) => _matchesAudioFilter(
                e.key,
                e.value,
                _audioFilter!,
              ),
            )
            .toList();

    if (orderedProviders.isEmpty) {
      if (providerOrder.isEmpty) {
        return const SizedBox.shrink();
      }
      final filterLabel = _audioFilter?.name.toUpperCase() ?? 'matching';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No $filterLabel sources',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (var i = 0; i < orderedProviders.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          Builder(
            builder: (context) {
              final prev = i > 0 ? orderedProviders[i - 1] : null;
              final section = PlayerStreamMenu.panelSectionLabelFor(
                providerId: orderedProviders[i].key,
                provider: orderedProviders[i].value,
                previousProviderId: prev?.key,
                previousProvider: prev?.value,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (section != null) ...[
                    if (i > 0) const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                      child: Text(
                        section.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.55,
                        ),
                      ),
                    ),
                  ],
                  KeyedSubtree(
                    key: ValueKey(orderedProviders[i].key),
                    child: _buildServerGroup(
                      providerId: orderedProviders[i].key,
                      provider: orderedProviders[i].value,
                      state: state,
                      probes: probes,
                      cache: cache,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderTrailing() {
    return PlayerStreamMenu.reloadTrailing(
          onReload: widget.onReload,
          isReloading: widget.isReloading,
        ) ??
        const SizedBox.shrink();
  }

  Widget? _buildAudioFilterGroup() {
    if (!PlayerStreamMenu.hasSubDubProviders(widget.providers)) return null;
    Widget segment(String label, _StreamAudioFilter value) {
      return ForjaShellChip(
        label: label,
        selected: _audioFilter == value,
        onTap: () => setState(() => _audioFilter = value),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        radius: 6,
        fontSize: 11,
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ForjaShellColors.cinematic.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('SUB', _StreamAudioFilter.sub),
          const SizedBox(width: 3),
          segment('DUB', _StreamAudioFilter.dub),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final list = widget.refreshListenable == null
        ? _buildList()
        : ListenableBuilder(
            listenable: widget.refreshListenable!,
            builder: (context, _) => _buildList(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: 'Source',
          onClose: widget.onClose,
          leading: Icon(
            Icons.layers_outlined,
            color: ForjaShellColors.cinematic.textSecondary,
            size: 18,
          ),
          titleTrailing: _buildAudioFilterGroup(),
          trailing: _buildHeaderTrailing(),
        ),
        Expanded(child: list),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return playerOverlayShell(
      context: context,
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      child: _buildBody(),
    );
  }
}
