import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

part 'player_stream_menu_overlay.dart';
part 'player_stream_menu_widgets.dart';

/// Live stream menu state — read after async provider switches.
class PlayerStreamMenuState {
  const PlayerStreamMenuState({
    required this.currentProviderId,
    required this.sources,
    required this.currentUrl,
    this.currentPlayingCatalogUrl,
    required this.current111477FileUrl,
    required this.is111477,
    this.sourceStatuses = const [],
    this.playbackConfirmed = false,
    this.mediaPlaying = false,
  });

  final String? currentProviderId;
  final List<StreamSource>? sources;
  final String? currentUrl;
  final String? currentPlayingCatalogUrl;
  final String? current111477FileUrl;
  final bool is111477;
  final List<PlayerSourceStatus> sourceStatuses;
  final bool playbackConfirmed;
  final bool mediaPlaying;
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
    required Future<bool> Function(StreamSource source, int index,
            [String? providerId])
        onCheckSource,
    VoidCallback? onTogglePlayPause,
    bool providersEnabled = true,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
    Listenable? refreshListenable,
    Future<void> Function()? onReload,
    ValueListenable<bool>? isReloading,
    Movie? movie,
    int? selectedSeason,
    int? selectedEpisode,
    num? hubEpisodeNumber,
    String? activeProvider,
    Map<String, PlayerSourceStatus> Function()? readUrlCheckStatuses,
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
          onCheckSource: onCheckSource,
          onTogglePlayPause: onTogglePlayPause,
          providersEnabled: providersEnabled,
          refreshListenable: refreshListenable,
          onReload: onReload,
          isReloading: isReloading,
          movie: movie,
          selectedSeason: selectedSeason,
          selectedEpisode: selectedEpisode,
          hubEpisodeNumber: hubEpisodeNumber,
          activeProvider: activeProvider,
          readUrlCheckStatuses: readUrlCheckStatuses,
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
    required Future<bool> Function(StreamSource source, int index,
            [String? providerId])
        onCheckSource,
    required Map<String, PlayerSourceStatus> urlStatuses,
    required void Function(String url, PlayerSourceStatus status)
        onUrlStatus,
    bool useIndexedStatuses = false,
    String? providerId,
    String? serverLabel,
    VoidCallback? onTogglePlayPause,
  }) {
    final statuses = state.sourceStatuses;
    final ordered = orderedSourceEntriesForPanel(sources);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in ordered)
          Builder(
            builder: (_) {
              final isCurrent = _isCurrentSource(entry.value, state);
              final isPlaying = isCurrent && state.playbackConfirmed;
              final url = entry.value.url;
              PlayerSourceStatus? status;
              if (urlStatuses.containsKey(url)) {
                status = urlStatuses[url];
              } else if (isPlaying) {
                // Playing implies the stream is up; green pause arrow marks "playing".
                status = PlayerSourceStatus.ready;
              } else if (useIndexedStatuses && entry.key < statuses.length) {
                final s = statuses[entry.key];
                // Indexed `ready` is not a URL check — leave null (gray) until verified.
                if (s == PlayerSourceStatus.checking ||
                    s == PlayerSourceStatus.failed ||
                    s == PlayerSourceStatus.active) {
                  status = s == PlayerSourceStatus.active
                      ? PlayerSourceStatus.ready
                      : s;
                }
              }
              return _FlatMenuRow(
                label: _streamRowLabel(entry.value, serverLabel: serverLabel),
                meta: entry.value.type.toUpperCase(),
                selected: isCurrent,
                isPlaying: isPlaying,
                mediaPlaying: isPlaying && state.mediaPlaying,
                status: status,
                onCheck: () async {
                  onUrlStatus(url, PlayerSourceStatus.checking);
                  final ok = await onCheckSource(
                    entry.value,
                    entry.key,
                    providerId,
                  );
                  onUrlStatus(
                    url,
                    ok
                        ? PlayerSourceStatus.ready
                        : PlayerSourceStatus.failed,
                  );
                },
                onPlay: () async {
                  dismiss();
                  await onSelectSource(entry.value, entry.key);
                },
                onTogglePlayPause:
                    isPlaying ? onTogglePlayPause : null,
              );
            },
          ),
      ],
    );
  }

  /// Stable panel order — settings provider priority only.
  /// Reliability scores drive resolve/probe order elsewhere, not this list.
  @visibleForTesting
  static List<MapEntry<String, dynamic>> orderedProviderEntriesForPanel(
    Map<String, dynamic> providers, {
    Map<String, ProviderOrderRow> scoreRows = const {},
    List<StreamProviderProbe> probes = const [],
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

    entries.sort((a, b) {
      final rankDiff = sortRank(a.key).compareTo(sortRank(b.key));
      if (rankDiff != 0) return rankDiff;
      final aCat = a.key.toLowerCase();
      final bCat = b.key.toLowerCase();
      final aSub = aCat.endsWith(':sub') ? 0 : aCat.endsWith(':dub') ? 1 : 2;
      final bSub = bCat.endsWith(':sub') ? 0 : bCat.endsWith(':dub') ? 1 : 2;
      return aSub.compareTo(bSub);
    });
    return entries;
  }

  /// Live list for the active server; cache fallback when reopening a session.
  static List<StreamSource> sourcesForProvider({
    required String providerId,
    required PlayerStreamMenuState state,
    required Map<String, List<StreamSource>> cache,
  }) {
    final isCurrent = providerId == state.currentProviderId;
    if (!isCurrent) return cache[providerId] ?? const <StreamSource>[];
    final live = state.sources;
    if (live != null && live.isNotEmpty) return live;
    return cache[providerId] ?? const <StreamSource>[];
  }

  static String _engineScoringId(String providerId, dynamic provider) {
    if (provider is AnimeEmbed) return provider.sourceKey;
    final lower = providerId.toLowerCase();
    if (lower.endsWith(':sub') || lower.endsWith(':dub')) {
      return providerId.substring(0, providerId.lastIndexOf(':'));
    }
    return providerId;
  }

  static SourceDomain _resolveProviderDomain(
    Movie? movie,
    Map<String, dynamic> providers,
  ) {
    if (providers.values.any((v) => v is AnimeEmbed)) {
      return SourceDomain.anime;
    }
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

  /// Per-title scope for reliability scores (film / episode / anime). Asian drama → null.
  static ProviderScoreScope? scoreScope({
    Movie? movie,
    Map<String, dynamic>? providers,
    int? selectedSeason,
    int? selectedEpisode,
    num? hubEpisodeNumber,
    String? activeProvider,
  }) {
    if (movie == null) return null;
    final prov = providers ?? const <String, dynamic>{};

    final active = (activeProvider ?? '').trim().toLowerCase();
    if (active == 'kisskh') return null;
    if (prov.isNotEmpty &&
        prov.keys.every((k) => k.trim().toLowerCase() == 'kisskh')) {
      return null;
    }

    final domain = _resolveProviderDomain(movie, prov);
    if (domain == SourceDomain.asianDrama) return null;

    if (domain == SourceDomain.anime ||
        hubEpisodeNumber != null ||
        prov.values.any((v) => v is AnimeEmbed)) {
      final anilistId = movie.id < 0 ? -movie.id : movie.id;
      final ep = (hubEpisodeNumber ?? selectedEpisode ?? 1).toInt();
      return ProviderScoreScope.anime(anilistId: anilistId, episode: ep);
    }

    if (movie.mediaType == 'tv') {
      return ProviderScoreScope.tv(
        tmdbId: movie.id,
        season: selectedSeason ?? 1,
        episode: selectedEpisode ?? 1,
      );
    }

    if (movie.mediaType == 'movie') {
      return ProviderScoreScope.movie(tmdbId: movie.id);
    }

    return null;
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
    final engineIds = <String>{
      for (final entry in providers.entries)
        _engineScoringId(entry.key, entry.value),
    };
    final settingsOrder = _settingsOrderForDomain(domain, engineIds);
    final base = SourceEngine.orderProviders(
      domain: domain,
      candidateIds: engineIds,
      settingsOrder: settingsOrder,
    ).rowById;
    return {
      for (final entry in providers.entries)
        entry.key: base[_engineScoringId(entry.key, entry.value)] ??
            ProviderOrderRow(
              id: entry.key,
              settingsRank: 999,
              domainScore: 0,
              effectiveRank: 999,
              maxDisplacement: 2,
              supported: true,
            ),
    };
  }

  static Widget _scoreDeltaLabel(int delta) {
    if (delta == 0) return const SizedBox.shrink();
    final color = delta > 0
        ? playerSourceStatusColor(PlayerSourceStatus.active)
        : playerSourceStatusColor(PlayerSourceStatus.failed)
            .withValues(alpha: 0.85);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        delta > 0 ? '+$delta' : '$delta',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }

  static Widget _scoreBadge({
    required ProviderScoreScope? scoreScope,
    required String providerId,
  }) {
    if (scoreScope == null) {
      return const SizedBox(width: _scoreColWidth, height: _badgeHeight);
    }
    final score = ProviderScoreMemory.scoreFor(scoreScope, providerId);
    final serverDelta =
        ProviderScoreMemory.serverVerdictFor(scoreScope, providerId);
    final streamDelta =
        ProviderScoreMemory.streamVerdictFor(scoreScope, providerId);
    final color = score >= 4
        ? playerSourceStatusColor(PlayerSourceStatus.active)
        : score >= 2
            ? Colors.white.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.52);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (serverDelta != null) _scoreDeltaLabel(serverDelta),
        if (streamDelta != null) _scoreDeltaLabel(streamDelta),
        Container(
          width: _scoreColWidth,
          height: _badgeHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  static const _badgeHeight = 20.0;
  static const _categoryColWidth = 44.0;
  static const _scoreColWidth = 34.0;

  static Widget _categoryBadge(String category) {
    final color = _categoryBadgeColor(category);
    return Container(
      width: _categoryColWidth,
      height: _badgeHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          height: 1.0,
        ),
      ),
    );
  }

  static Widget _serverTrailingBadges({
    required String? categoryBadge,
    required ProviderScoreScope? scoreScope,
    required String providerId,
    bool hideCategoryBadge = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!hideCategoryBadge) ...[
          if (categoryBadge != null)
            _categoryBadge(categoryBadge)
          else
            const SizedBox(width: _categoryColWidth, height: _badgeHeight),
          const SizedBox(width: 6),
        ],
        _scoreBadge(scoreScope: scoreScope, providerId: providerId),
      ],
    );
  }

  static bool hasSubDubProviders(Map<String, dynamic>? providers) {
    if (providers == null || providers.isEmpty) return false;
    for (final entry in providers.entries) {
      if (providerAudioCategory(entry.key, entry.value) != null) return true;
    }
    return false;
  }

  static String? providerAudioCategory(String providerId, dynamic provider) {
    if (provider is AnimeEmbed) return provider.category.toLowerCase();
    final lower = providerId.toLowerCase();
    if (lower.endsWith(':sub')) return 'sub';
    if (lower.endsWith(':dub')) return 'dub';
    return null;
  }

  /// Strip server name and SUB/DUB from stream titles — shown on the server row.
  static String _streamRowLabel(StreamSource source, {String? serverLabel}) {
    var title = source.title.trim();
    if (serverLabel != null && serverLabel.isNotEmpty) {
      for (final prefix in [
        '$serverLabel · ',
        '$serverLabel - ',
        '$serverLabel ',
      ]) {
        if (title.startsWith(prefix)) {
          title = title.substring(prefix.length).trim();
          break;
        }
      }
      if (title == serverLabel) title = '';
    }
    for (final cat in const ['SUB', 'DUB']) {
      final suffix = '· $cat';
      if (title.toUpperCase().endsWith(suffix)) {
        title = title.substring(0, title.length - suffix.length).trim();
      }
      if (title.toUpperCase() == cat) title = '';
    }
    return title;
  }

  /// Stable panel order — preserves resolver/extraction list order.
  @visibleForTesting
  static List<MapEntry<int, StreamSource>> orderedSourceEntriesForPanel(
    List<StreamSource> sources,
  ) =>
      sources.asMap().entries.toList();

  static bool _isCurrentSource(
    StreamSource source,
    PlayerStreamMenuState state,
  ) {
    if (state.is111477) {
      return source.url == state.current111477FileUrl;
    }
    final playUrl = state.currentUrl;
    final catalogUrl = state.currentPlayingCatalogUrl;
    return source.url == playUrl ||
        (catalogUrl != null &&
            catalogUrl.isNotEmpty &&
            source.url == catalogUrl);
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
        StreamProviderProbeStatus.skippedOnTv => PlayerSourceStatus.ready,
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

  static ({String label, String? categoryBadge}) _serverPresentation(
    String providerId,
    dynamic provider,
  ) {
    if (provider is AnimeEmbed) {
      return (
        label: provider.label,
        categoryBadge: provider.category.toUpperCase(),
      );
    }
    return (
      label: PlayerProviderMenu.snackbarLabel(providerId, provider),
      categoryBadge: null,
    );
  }

  static Color _categoryBadgeColor(String category) {
    return switch (category.toUpperCase()) {
      'SUB' => const Color(0xFF7C3AED),
      'DUB' => const Color(0xFFF59E0B),
      _ => ForjaShellColors.cinematic.textSecondary,
    };
  }

  // ── Status glyphs ─────────────────────────────────────────────────────
  // Server = solid filled dots (provider load / probe).
  // Stream = hollow ring / check (URL verified). Same meaning, different shape
  // so the two layers are not visually redundant.
  // Playing is the green play/pause arrow — never encoded in these glyphs.

  /// Server: solid green = up · solid gray = not checked · red X · spinner.
  static Widget _statusGlyph({
    required PlayerSourceStatus status,
    required bool isLoaded,
  }) {
    if (status == PlayerSourceStatus.checking) {
      return _checkingSpinner();
    }
    if (status == PlayerSourceStatus.failed) {
      return _failedIcon();
    }
    final up = isLoaded ||
        status == PlayerSourceStatus.ready ||
        status == PlayerSourceStatus.active;
    return _serverSolidDot(
      up ? playerSourceStatusColor(PlayerSourceStatus.ready) : _uncheckedGray,
    );
  }

  /// Stream: check = up · hollow ring = not checked · red X · spinner.
  static Widget _streamStatusGlyph({
    required PlayerSourceStatus? status,
  }) {
    if (status == null) return _streamHollowRing(_uncheckedGray);
    if (status == PlayerSourceStatus.checking) return _checkingSpinner();
    if (status == PlayerSourceStatus.failed) return _failedIcon();
    return _streamUpCheck();
  }

  static const Color _uncheckedGray = Color(0x3DFFFFFF); // white24

  static Widget _serverSolidDot(Color color) {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  static Widget _streamHollowRing(Color color) {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }

  static Widget _streamUpCheck() {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Icon(
        Icons.check_rounded,
        size: 14,
        color: playerSourceStatusColor(PlayerSourceStatus.ready),
      ),
    );
  }

  static Widget _failedIcon() {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Icon(
        Icons.cancel_rounded,
        size: _statusSlot,
        color: playerSourceStatusColor(PlayerSourceStatus.failed),
      ),
    );
  }

  static Widget _checkingSpinner() {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: playerSourceStatusColor(PlayerSourceStatus.checking),
          ),
        ),
      ),
    );
  }
}
