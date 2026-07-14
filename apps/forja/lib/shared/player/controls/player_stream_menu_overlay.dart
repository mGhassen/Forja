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
  final Future<List<StreamSource>?> Function(String providerId) onLoadProvider;
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
  bool _open = false;
  final Set<String> _loadingProviders = {};
  /// Providers whose stream branch is collapsed (loaded but hidden).
  final Set<String> _collapsedProviders = {};
  final Map<String, int> _loadGens = {};
  final Map<String, PlayerSourceStatus> _urlStatuses = {};
  _StreamAudioFilter? _audioFilter;
  bool _useEmbed = false;

  Set<String> get _failedProviders =>
      widget.providerLoadFailures?.value ?? const {};

  @override
  void initState() {
    super.initState();
    ProviderScoreMemory.revision.addListener(_onScoreRevision);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await ProviderScoreMemory.ensureLoaded();
    final useEmbed = await SettingsService().getPlayerWebViewUseEmbed();
    if (!mounted) return;
    setState(() {
      _useEmbed = useEmbed;
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

  Future<void> _loadServer(
    String providerId, {
    bool clearCache = false,
  }) async {
    if (!widget.providersEnabled) return;
    if (_loadingProviders.contains(providerId)) return;

    final gen = (_loadGens[providerId] ?? 0) + 1;
    _loadGens[providerId] = gen;
    setState(() {
      _loadingProviders.add(providerId);
      _collapsedProviders.remove(providerId);
    });

    if (clearCache) {
      final cache = widget.providerSourcesCache;
      if (cache is ValueNotifier<Map<String, List<StreamSource>>>) {
        final next = Map<String, List<StreamSource>>.from(cache.value)
          ..remove(providerId);
        cache.value = next;
      }
    }

    try {
      await widget.onLoadProvider(providerId);
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() => _loadingProviders.remove(providerId));
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
          child: Builder(
            builder: (context) {
              final tvFocus =
                  ShellScope.inputPolicyOf(context).useFocusableMoodChips;
              final header = _ServerMenuHeader(
                label: presentation.label,
                subtitle: subtitle,
                status: status,
                isLoaded: isLoaded,
                isPlaying: isPlaying,
                isReloading: isReloading,
                showReload:
                    (isLoaded || isReloading) && widget.providersEnabled,
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
              );
              if (!tvFocus || !canInteract) return header;
              return shellFocusableTap(
                context: context,
                onTap: () => _onServerRowTap(
                  providerId: providerId,
                  isLoaded: isLoaded,
                ),
                borderRadius: 8,
                showFocusBorder: true,
                ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                child: header,
              );
            },
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
      ],
    );
  }

  Future<void> _setUseEmbed(bool value) async {
    setState(() => _useEmbed = value);
    await SettingsService().setPlayerWebViewUseEmbed(value);
  }

  Widget? _buildUseEmbedHeaderControl() {
    if (!_hasProviders || isAndroidTvHeadlessWebViewBlocked) return null;
    return InkWell(
      onTap: () => unawaited(_setUseEmbed(!_useEmbed)),
      borderRadius: BorderRadius.circular(6),
      hoverColor: ForjaShellColors.inkHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: _useEmbed,
                onChanged: (v) {
                  if (v == null) return;
                  unawaited(_setUseEmbed(v));
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return ForjaShellColors.cinematic.textPrimary;
                  }
                  return Colors.transparent;
                }),
                checkColor: Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Embed',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTrailing() {
    final embed = _buildUseEmbedHeaderControl();
    final reload = PlayerStreamMenu.reloadTrailing(
      onReload: widget.onReload,
      isReloading: widget.isReloading,
    );
    if (embed == null && reload == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?embed,
        if (embed != null && reload != null) const SizedBox(width: 4),
        ?reload,
      ],
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
          trailing: _buildHeaderTrailing(),
        ),
        if (PlayerStreamMenu.hasSubDubProviders(widget.providers))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ForjaShellChip(
                  label: 'SUB',
                  selected: _audioFilter == _StreamAudioFilter.sub,
                  onTap: () => setState(
                    () => _audioFilter = _StreamAudioFilter.sub,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  radius: 8,
                  fontSize: 12,
                ),
                const SizedBox(width: 8),
                ForjaShellChip(
                  label: 'DUB',
                  selected: _audioFilter == _StreamAudioFilter.dub,
                  onTap: () => setState(
                    () => _audioFilter = _StreamAudioFilter.dub,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  radius: 8,
                  fontSize: 12,
                ),
              ],
            ),
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
