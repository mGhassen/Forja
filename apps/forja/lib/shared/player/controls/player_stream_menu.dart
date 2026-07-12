import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

/// Live stream menu state — read after async provider switches.
class PlayerStreamMenuState {
  const PlayerStreamMenuState({
    required this.currentProviderId,
    required this.sources,
    required this.currentUrl,
    required this.current111477FileUrl,
    required this.is111477,
    this.sourceStatuses = const [],
    this.playbackConfirmed = false,
  });

  final String? currentProviderId;
  final List<StreamSource>? sources;
  final String? currentUrl;
  final String? current111477FileUrl;
  final bool is111477;
  final List<PlayerSourceStatus> sourceStatuses;
  final bool playbackConfirmed;
}

/// Unified server + source picker — right-side panel with grouped providers.
class PlayerStreamMenu {
  static const _statusSlot = 18.0;

  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
  }

  static Widget? reloadTrailing({
    required Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
  }) {
    if (onReload == null) return null;
    Widget buildButton(bool loading) {
      if (loading) {
        return const Padding(
          padding: EdgeInsets.only(right: 4),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        );
      }
      return ForjaPlainIcon(
        icon: Icons.refresh_rounded,
        size: 20,
        color: Colors.white54,
        onTap: () => unawaited(onReload()),
      );
    }

    if (isReloading == null) return buildButton(false);
    return ValueListenableBuilder<bool>(
      valueListenable: isReloading,
      builder: (context, loading, _) => buildButton(loading),
    );
  }

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? providers,
    ValueListenable<Map<String, List<StreamSource>>>? providerSourcesCache,
    ValueListenable<Set<String>>? providerLoadFailures,
    ValueListenable<List<StreamProviderProbe>>? providerProbesNotifier,
    PlayerStatusController? statusController,
    required PlayerStreamMenuState Function() readState,
    required Future<List<StreamSource>?> Function(String providerId)
        onLoadProvider,
    required Future<List<StreamSource>?> Function(String providerId)
        onSelectProvider,
    required Future<void> Function(StreamSource source, int index)
        onSelectSource,
    bool providersEnabled = true,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
    Listenable? refreshListenable,
    Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
    Movie? movie,
  }) async {
    final initial = readState();
    final hasProviders = providers != null && providers.isNotEmpty;
    final hasSources = initial.sources != null && initial.sources!.isNotEmpty;

    if (!hasProviders && !hasSources) {
      ForjaToast.warning(
        'No streams available',
        duration: const Duration(seconds: 1),
      );
      return;
    }

    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerEpisodePanel.dismiss();
    PlayerHubEpisodePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    void close() => dismiss();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (context, _) => _StreamMenuOverlay(
          providers: providers,
          providerSourcesCache: providerSourcesCache,
          providerLoadFailures: providerLoadFailures,
          providerProbesNotifier: providerProbesNotifier,
          statusController: statusController,
          readState: readState,
          onLoadProvider: onLoadProvider,
          onSelectProvider: onSelectProvider,
          onSelectSource: onSelectSource,
          providersEnabled: providersEnabled,
          refreshListenable: refreshListenable,
          onReload: onReload,
          isReloading: isReloading,
          movie: movie,
          onClose: close,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }

  static Widget _sourcesList({
    required List<StreamSource> sources,
    required PlayerStreamMenuState state,
    required Future<void> Function(StreamSource source, int index)
        onSelectSource,
    bool useIndexedStatuses = false,
  }) {
    final statuses = state.sourceStatuses;
    final ordered = _orderedSourceEntries(
      sources,
      state,
      statuses: statuses,
      useStatuses: useIndexedStatuses,
    );
    return Column(
      children: [
        for (final entry in ordered)
          _FlatMenuRow(
            label: entry.value.title,
            meta: entry.value.type.toUpperCase(),
            selected: _isCurrentSource(entry.value, state),
            isPlaying: _isCurrentSource(entry.value, state) &&
                state.playbackConfirmed,
            status: useIndexedStatuses && entry.key < statuses.length
                ? statuses[entry.key]
                : PlayerSourceStatus.ready,
            onTap: () async {
              dismiss();
              await onSelectSource(entry.value, entry.key);
            },
          ),
      ],
    );
  }

  static List<MapEntry<String, dynamic>> _orderedProviderEntries(
    Map<String, dynamic> providers, {
    required PlayerStreamMenuState state,
    required List<StreamProviderProbe> probes,
    required Map<String, List<StreamSource>> cache,
    required Set<String> loadingProviders,
    required Set<String> failedProviders,
    PlayerStatusController? statusController,
    Map<String, ProviderOrderRow> scoreRows = const {},
  }) {
    final entries = providers.entries.toList();

    final probeIndex = <String, int>{};
    for (var i = 0; i < probes.length; i++) {
      probeIndex[probes[i].id] = i;
    }

    int sortRank(String providerId) {
      final row = scoreRows[providerId];
      if (row != null && row.supported) return row.effectiveRank;
      return probeIndex[providerId] ?? 999;
    }

    int sortScore(String providerId) =>
        scoreRows[providerId]?.domainScore ?? 0;

    int tier(String providerId) {
      final isCurrent = providerId == state.currentProviderId;
      if (isCurrent && state.playbackConfirmed) return 0;

      final status = _resolveProviderStatus(
        providerId,
        probes: probes,
        isCurrent: isCurrent,
        statusController: statusController,
        playbackConfirmed: state.playbackConfirmed,
        loadingProviders: loadingProviders,
        failedProviders: failedProviders,
      );
      final sectionSources = isCurrent
          ? (state.sources ?? const <StreamSource>[])
          : (cache[providerId] ?? const <StreamSource>[]);

      if (sectionSources.isNotEmpty ||
          status == PlayerSourceStatus.ready ||
          status == PlayerSourceStatus.active) {
        return 1;
      }
      if (status == PlayerSourceStatus.checking) return 2;
      if (status == PlayerSourceStatus.failed) return 4;
      return 3;
    }

    entries.sort((a, b) {
      final tierDiff = tier(a.key).compareTo(tier(b.key));
      if (tierDiff != 0) return tierDiff;
      final rankDiff = sortRank(a.key).compareTo(sortRank(b.key));
      if (rankDiff != 0) return rankDiff;
      return sortScore(b.key).compareTo(sortScore(a.key));
    });
    return entries;
  }

  static SourceDomain _resolveProviderDomain(
    Movie? movie,
    Map<String, dynamic> providers,
  ) {
    var animeSupported = 0;
    var streamingSupported = 0;
    for (final id in providers.keys) {
      if (SourceEngine.domainScore(id, SourceDomain.anime) > 0) {
        animeSupported++;
      }
      if (SourceEngine.domainScore(id, SourceDomain.movies) > 0 ||
          SourceEngine.domainScore(id, SourceDomain.series) > 0) {
        streamingSupported++;
      }
    }
    if (animeSupported > 0 && animeSupported >= streamingSupported) {
      return SourceDomain.anime;
    }
    if (movie?.mediaType == 'anime') return SourceDomain.anime;
    return SourceDomain.fromMediaType(movie?.mediaType);
  }

  static List<String> _settingsOrderForDomain(
    SourceDomain domain,
    Iterable<String> candidateIds,
  ) {
    final defaults = switch (domain) {
      SourceDomain.anime => SettingsService.defaultAnimeProviderOrder,
      SourceDomain.asianDrama => const ['kisskh'],
      _ => SettingsService.defaultStreamProviderOrder,
    };
    return SettingsService.mergeProviderOrder(candidateIds.toList(), defaults);
  }

  static Map<String, ProviderOrderRow> _providerScoreRows(
    Movie? movie,
    Map<String, dynamic>? providers,
  ) {
    if (providers == null || providers.isEmpty) return const {};
    final domain = _resolveProviderDomain(movie, providers);
    final settingsOrder = _settingsOrderForDomain(domain, providers.keys);
    return SourceEngine.orderProviders(
      domain: domain,
      candidateIds: providers.keys,
      settingsOrder: settingsOrder,
    ).rowById;
  }

  static Widget _scoreBadge(ProviderOrderRow? row) {
    if (row == null || !row.supported || row.domainScore <= 0) {
      return const SizedBox.shrink();
    }
    final score = row.domainScore;
    final color = score >= 90
        ? playerSourceStatusColor(PlayerSourceStatus.active)
        : score >= 75
            ? Colors.white.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.52);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$score',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  static List<MapEntry<int, StreamSource>> _orderedSourceEntries(
    List<StreamSource> sources,
    PlayerStreamMenuState state, {
    List<PlayerSourceStatus> statuses = const [],
    bool useStatuses = false,
  }) {
    final entries = sources.asMap().entries.toList();

    int tier(int index, StreamSource source) {
      if (_isCurrentSource(source, state) && state.playbackConfirmed) {
        return 0;
      }
      if (useStatuses && index < statuses.length) {
        return switch (statuses[index]) {
          PlayerSourceStatus.active => 0,
          PlayerSourceStatus.ready => 1,
          PlayerSourceStatus.checking => 2,
          PlayerSourceStatus.failed => 3,
        };
      }
      if (_isCurrentSource(source, state)) return 1;
      return 1;
    }

    entries.sort((a, b) {
      final tierDiff = tier(a.key, a.value).compareTo(tier(b.key, b.value));
      if (tierDiff != 0) return tierDiff;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  static bool _isCurrentSource(
    StreamSource source,
    PlayerStreamMenuState state,
  ) {
    return state.is111477
        ? source.url == state.current111477FileUrl
        : source.url == state.currentUrl;
  }

  static List<String>? _contentLanguage(dynamic provider) {
    if (provider is! Map) return null;
    final raw = provider['contentLanguage'];
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }

  static PlayerSourceStatus _resolveProviderStatus(
    String providerId, {
    required List<StreamProviderProbe> probes,
    required bool isCurrent,
    PlayerStatusController? statusController,
    bool playbackConfirmed = false,
    required Set<String> loadingProviders,
    required Set<String> failedProviders,
    bool hasLoadedSources = false,
  }) {
    if (isCurrent && playbackConfirmed) return PlayerSourceStatus.active;
    if (loadingProviders.contains(providerId)) {
      return PlayerSourceStatus.checking;
    }
    if (failedProviders.contains(providerId)) {
      return PlayerSourceStatus.failed;
    }
    if (hasLoadedSources) return PlayerSourceStatus.ready;

    final fromController = _providerStatusFromController(
      providerId,
      statusController,
    );
    if (fromController != null) return fromController;

    for (final probe in probes) {
      if (probe.id != providerId) continue;
      return switch (probe.status) {
        StreamProviderProbeStatus.pending => PlayerSourceStatus.ready,
        StreamProviderProbeStatus.trying => PlayerSourceStatus.checking,
        StreamProviderProbeStatus.failed => PlayerSourceStatus.failed,
        StreamProviderProbeStatus.success => PlayerSourceStatus.ready,
      };
    }
    return PlayerSourceStatus.ready;
  }

  static PlayerSourceStatus? _providerStatusFromController(
    String providerId,
    PlayerStatusController? statusController,
  ) {
    if (statusController == null) return null;
    for (final entry in statusController.entries) {
      if (entry.id != 'provider-$providerId') continue;
      return switch (entry.kind) {
        StatusRouletteKind.loading => PlayerSourceStatus.checking,
        StatusRouletteKind.success => PlayerSourceStatus.ready,
        StatusRouletteKind.failed => PlayerSourceStatus.failed,
        StatusRouletteKind.info => null,
      };
    }
    return null;
  }

  static String? _providerSubtitle({
    required int sourceCount,
    required bool isPlaying,
  }) {
    if (isPlaying) return 'Playing now';
    if (sourceCount > 0) {
      return '$sourceCount stream${sourceCount == 1 ? '' : 's'}';
    }
    return null;
  }

  static Widget _statusGlyph({
    required PlayerSourceStatus status,
    required bool isPlaying,
    required bool isLoaded,
  }) {
    // Playing state is shown on the active stream row — server keeps a dot.
    if (isPlaying) {
      return _statusGlyphFor(PlayerSourceStatus.active, dotOnly: true);
    }
    if (status == PlayerSourceStatus.checking) {
      return _statusGlyphFor(PlayerSourceStatus.checking);
    }
    if (isLoaded) {
      return _statusGlyphFor(PlayerSourceStatus.active, dotOnly: true);
    }
    if (status == PlayerSourceStatus.failed) {
      return _statusGlyphFor(PlayerSourceStatus.failed);
    }
    return const SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: Text(
          '...',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1,
          ),
        ),
      ),
    );
  }

  static Widget _statusGlyphFor(
    PlayerSourceStatus status, {
    bool dotOnly = false,
  }) {
    final color = playerSourceStatusColor(status);
    final Widget glyph = switch (status) {
      PlayerSourceStatus.active when !dotOnly => Icon(
          Icons.play_circle_filled_rounded,
          color: color,
          size: _statusSlot,
        ),
      PlayerSourceStatus.active => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      PlayerSourceStatus.failed => Icon(
          Icons.cancel_rounded,
          color: color,
          size: _statusSlot,
        ),
      PlayerSourceStatus.checking => SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      PlayerSourceStatus.ready => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
    };
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(child: glyph),
    );
  }
}

class _StreamMenuOverlay extends StatefulWidget {
  const _StreamMenuOverlay({
    required this.readState,
    required this.onLoadProvider,
    required this.onSelectProvider,
    required this.onSelectSource,
    required this.onClose,
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
  final bool providersEnabled;
  final Listenable? refreshListenable;
  final Future<void> Function()? onReload;
  final ValueListenable<bool>? isReloading;
  final Movie? movie;
  final VoidCallback onClose;

  @override
  State<_StreamMenuOverlay> createState() => _StreamMenuOverlayState();
}

class _StreamMenuOverlayState extends State<_StreamMenuOverlay> {
  bool _open = false;
  final Set<String> _loadingProviders = {};
  final Map<String, int> _loadGens = {};
  late final List<MapEntry<String, dynamic>> _frozenProviderOrder;
  late final Map<String, ProviderOrderRow> _scoreById;

  Set<String> get _failedProviders =>
      widget.providerLoadFailures?.value ?? const {};

  @override
  void initState() {
    super.initState();
    _scoreById = PlayerStreamMenu._providerScoreRows(
      widget.movie,
      widget.providers,
    );
    _frozenProviderOrder = _computeInitialProviderOrder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
  }

  List<MapEntry<String, dynamic>> _computeInitialProviderOrder() {
    if (widget.providers == null || widget.providers!.isEmpty) {
      return const [];
    }
    final state = widget.readState();
    final probes = widget.providerProbesNotifier?.value ?? const [];
    final cache = widget.providerSourcesCache?.value ?? const {};
    return PlayerStreamMenu._orderedProviderEntries(
      widget.providers!,
      state: state,
      probes: probes,
      cache: cache,
      loadingProviders: const {},
      failedProviders: _failedProviders,
      statusController: widget.statusController,
      scoreRows: _scoreById,
    );
  }

  bool get _hasProviders =>
      widget.providers != null && widget.providers!.isNotEmpty;

  List<StreamSource> _sectionSources({
    required String providerId,
    required PlayerStreamMenuState state,
    required Map<String, List<StreamSource>> cache,
  }) {
    final isCurrent = providerId == state.currentProviderId;
    return isCurrent
        ? (state.sources ?? const <StreamSource>[])
        : (cache[providerId] ?? const <StreamSource>[]);
  }

  Future<void> _tapServer({
    required String providerId,
    required PlayerStreamMenuState state,
    required Map<String, List<StreamSource>> cache,
  }) async {
    if (!widget.providersEnabled) return;

    final sources = _sectionSources(
      providerId: providerId,
      state: state,
      cache: cache,
    );
    if (sources.isNotEmpty || _loadingProviders.contains(providerId)) return;

    final gen = (_loadGens[providerId] ?? 0) + 1;
    _loadGens[providerId] = gen;
    setState(() => _loadingProviders.add(providerId));

    try {
      await widget.onLoadProvider(providerId);
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() => _loadingProviders.remove(providerId));
    } catch (_) {
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() => _loadingProviders.remove(providerId));
    }
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
    final flags = StreamProviderDisplay.countryFlags(
      providerId,
      contentLanguage: PlayerStreamMenu._contentLanguage(provider),
    );
    final fallbackName = switch (provider) {
      final Map<String, dynamic> map => map['name']?.toString(),
      _ => null,
    };
    final label = StreamProviderDisplay.playerLabel(
      providerId,
      fallbackName: fallbackName,
      contentLanguage: PlayerStreamMenu._contentLanguage(provider),
    );
    final subtitle = PlayerStreamMenu._providerSubtitle(
      sourceCount: sectionSources.length,
      isPlaying: isPlaying,
    );
    final canLoad = widget.providersEnabled &&
        !isLoaded &&
        status != PlayerSourceStatus.checking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: isPlaying
              ? playerSourceStatusColor(PlayerSourceStatus.active)
                  .withValues(alpha: 0.07)
              : Colors.transparent,
          child: InkWell(
            onTap: canLoad
                ? () => unawaited(
                      _tapServer(
                        providerId: providerId,
                        state: state,
                        cache: cache,
                      ),
                    )
                : null,
            hoverColor: ForjaShellColors.inkHover,
            splashColor: ForjaShellColors.inkSplash,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 30,
                    child: PlayerStreamMenu._scoreBadge(_scoreById[providerId]),
                  ),
                  PlayerStreamMenu._statusGlyph(
                    status: status,
                    isPlaying: isPlaying,
                    isLoaded: isLoaded,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (flags.isNotEmpty) ...[
                              Text(
                                flags,
                                style: const TextStyle(fontSize: 13, height: 1.25),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isPlaying
                                      ? Colors.white
                                      : status == PlayerSourceStatus.failed
                                          ? Colors.white.withValues(alpha: 0.42)
                                          : isLoaded
                                              ? Colors.white.withValues(alpha: 0.92)
                                              : Colors.white.withValues(alpha: 0.62),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  decoration: status == PlayerSourceStatus.failed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                color: isPlaying
                                    ? playerSourceStatusColor(
                                        PlayerSourceStatus.active,
                                      )
                                    : Colors.white.withValues(alpha: 0.42),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isLoaded)
          _ServerStreamBranch(
            child: PlayerStreamMenu._sourcesList(
              sources: sectionSources,
              state: state,
              useIndexedStatuses: isCurrent,
              onSelectSource: (source, index) async {
                PlayerStreamMenu.dismiss();
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
            ),
          ),
      ],
    );
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
      return PlayerStreamMenu._sourcesList(
        sources: state.sources ?? const [],
        state: state,
        onSelectSource: widget.onSelectSource,
        useIndexedStatuses: true,
      );
    }

    final orderedProviders = _frozenProviderOrder;

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 16),
      children: [
        for (var i = 0; i < orderedProviders.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.layers_outlined,
                color: ForjaShellColors.cinematic.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Source',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final trailing = PlayerStreamMenu.reloadTrailing(
                    onReload: widget.onReload,
                    isReloading: widget.isReloading,
                  );
                  if (trailing == null) return const SizedBox.shrink();
                  return trailing;
                },
              ),
              ForjaCloseButton(
                color: ForjaShellColors.cinematic.textSecondary,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: ForjaShellColors.cinematic.borderSubtle,
        ),
        const SizedBox(height: 4),
        Expanded(child: list),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TorrentSourcesPanel(
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      child: _buildBody(),
    );
  }
}

/// Indented stream list with a vertical branch line under its server.
class _ServerStreamBranch extends StatelessWidget {
  const _ServerStreamBranch({required this.child});

  final Widget child;

  static const _padLeft = 8.0;
  static const _gapAfterLine = 10.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _padLeft, bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: _gapAfterLine),
              child: Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _FlatMenuRow extends StatelessWidget {
  const _FlatMenuRow({
    required this.label,
    this.meta,
    this.selected = false,
    this.isPlaying = false,
    this.status = PlayerSourceStatus.ready,
    this.onTap,
  });

  final String label;
  final String? meta;
  final bool selected;
  final bool isPlaying;
  final PlayerSourceStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final failed = status == PlayerSourceStatus.failed;
    final disabled = onTap == null;

    return Material(
      color: isPlaying
          ? playerSourceStatusColor(PlayerSourceStatus.active)
              .withValues(alpha: 0.07)
          : selected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: ForjaShellColors.inkHover,
        splashColor: ForjaShellColors.inkSplash,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
          child: Row(
            children: [
              if (meta != null) ...[
                SizedBox(
                  width: 34,
                  child: Text(
                    meta!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ] else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: failed
                        ? Colors.white.withValues(alpha: 0.38)
                        : isPlaying
                            ? Colors.white
                            : selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: isPlaying || selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    decoration: failed ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white38,
                  ),
                ),
              ),
              if (status == PlayerSourceStatus.checking)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: playerSourceStatusColor(status),
                  ),
                )
              else if (status == PlayerSourceStatus.failed)
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: playerSourceStatusColor(status),
                )
              else if (disabled)
                Icon(
                  Icons.block_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.24),
                )
              else ...[
                if (selected) ...[
                  const Icon(Icons.check_rounded, color: Colors.white, size: 17),
                  const SizedBox(width: 8),
                ],
                Icon(
                  isPlaying
                      ? Icons.play_circle_filled_rounded
                      : Icons.play_circle_outline_rounded,
                  color: isPlaying
                      ? playerSourceStatusColor(PlayerSourceStatus.active)
                      : Colors.white.withValues(alpha: 0.52),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
