import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/media/details/providers/details_providers.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// Async play / resolve ownership for media details (RFC-047 deep slice).
///
/// Hero Play / Direct / Sources panel read this via [detailsPlaySessionProvider].
/// Ephemeral panel chrome (search query, filter chips) stays on the screen.
@immutable
class DetailsPlaySources {
  const DetailsPlaySources({
    required this.torrent,
    required this.stremio,
    required this.nuvio,
    required this.engine,
    required this.engineAutoStart,
    required this.webstreaming,
  });

  /// First paint before prefs hydrate — matches platform defaults (Forja only).
  const DetailsPlaySources.pending()
      : torrent = false,
        stremio = false,
        nuvio = false,
        engine = true,
        engineAutoStart = false,
        webstreaming = false;

  final bool torrent;
  final bool stremio;
  final bool nuvio;
  final bool engine;
  final bool engineAutoStart;
  final bool webstreaming;

  DetailsPlaySources copyWith({
    bool? torrent,
    bool? stremio,
    bool? nuvio,
    bool? engine,
    bool? engineAutoStart,
    bool? webstreaming,
  }) {
    return DetailsPlaySources(
      torrent: torrent ?? this.torrent,
      stremio: stremio ?? this.stremio,
      nuvio: nuvio ?? this.nuvio,
      engine: engine ?? this.engine,
      engineAutoStart: engineAutoStart ?? this.engineAutoStart,
      webstreaming: webstreaming ?? this.webstreaming,
    );
  }
}

/// Mutable session bag — Notifier bumps [DetailsPlaySessionNotifier] revision
/// so [ref.watch] rebuilds; callers mutate fields then [bump].
class DetailsPlaySession {
  DetailsPlaySources playSources = const DetailsPlaySources.pending();

  List<TorrentResult> torrents = [];
  bool isSearching = false;
  int torrentSearchGen = 0;
  final Set<String> torrentFetchedProviderIds = {};
  final Set<String> torrentInFlightProviderIds = {};
  String? errorMessage;

  List<Map<String, dynamic>> streamAddons = [];
  List<dynamic> stremioStreams = [];
  List<Map<String, dynamic>> allCombinedStremioStreams = [];
  bool isStremioFetching = false;
  int stremioFetchGen = 0;
  final Set<String> loadedAddonBaseUrls = {};
  final Set<String> completedAddonBaseUrls = {};
  bool userPickedStremioProvider = false;

  List<Map<String, dynamic>> nuvioStreams = [];
  bool isNuvioFetching = false;
  bool hasNuvioAddons = false;
  Set<String> nuvioFetchedScraperIds = {};
  int nuvioFetchGen = 0;
  Set<String> nuvioInFlightScraperIds = {};
  List<NuvioAddon> nuvioAddons = [];
  Set<String> nuvioSelectedScraperIds = {};
  bool nuvioSelectionHydrated = false;

  List<Map<String, dynamic>> engineStreams = [];
  bool isEngineFetching = false;
  bool hasEnginePacks = false;
  Set<String> engineFetchedPluginIds = {};
  int engineFetchGen = 0;
  Set<String> engineInFlightPluginIds = {};
  List<EnginePack> enginePacks = [];
  Set<String> engineSelectedPluginIds = {};
  bool engineSelectionHydrated = false;

  final Map<String, dynamic> webstreamingProviders = {
    ...StreamProviders.providers,
  };
  List<String> webstreamingProviderOrder = [];
  List<StreamSource> webstreamingStreams = [];
  String? webstreamingActiveProviderId;
  bool isWebstreamingOnlyExtracting = false;
  bool webstreamingOnlyExtractionCancelled = false;
  int webstreamingPlayGen = 0;

  bool isEngineAutoExtracting = false;
  bool engineAutoExtractionCancelled = false;
  int engineAutoPlayGen = 0;

  String selectedSourceId = '';
  String panelKindFilter = EngineIds.kind;

  /// Last green-play / panel pick — restores Forja/Nuvio chip on Sources open.
  String? playingPanelKind;
  String? playingAddonBaseUrl;
  String? playingCatalogUrl;

  /// Per-kind Stremio addon / torrent chip id — [selectedSourceId] is active tab only.
  Map<String, String> panelSourceIdByKind = {};

  DetailsResolveStatus get resolveStatus {
    if (isSearching ||
        isStremioFetching ||
        isNuvioFetching ||
        isEngineFetching ||
        isWebstreamingOnlyExtracting ||
        isEngineAutoExtracting) {
      return DetailsResolveStatus.loading;
    }
    if (errorMessage != null &&
        torrents.isEmpty &&
        stremioStreams.isEmpty &&
        nuvioStreams.isEmpty &&
        engineStreams.isEmpty &&
        webstreamingStreams.isEmpty) {
      return DetailsResolveStatus.error;
    }
    if (torrents.isNotEmpty ||
        stremioStreams.isNotEmpty ||
        nuvioStreams.isNotEmpty ||
        engineStreams.isNotEmpty ||
        webstreamingStreams.isNotEmpty) {
      return DetailsResolveStatus.ready;
    }
    return DetailsResolveStatus.idle;
  }
}

class DetailsPlaySessionNotifier
    extends AutoDisposeFamilyNotifier<int, DetailsMetaKey> {
  late final DetailsPlaySession session;

  @override
  int build(DetailsMetaKey arg) {
    session = DetailsPlaySession();
    // Re-load play-source toggles when Settings / cloud pull bumps revision.
    ref.listen(playSourceRevisionProvider, (_, _) {
      unawaited(loadPlaySources());
    });
    ref.listen(accountFeaturesRevisionProvider, (_, _) {
      unawaited(loadPlaySources());
    });
    unawaited(loadPlaySources());
    return 0;
  }

  void bump() => state++;

  /// Batch mutate then notify watchers once.
  void mutate(void Function(DetailsPlaySession s) fn) {
    fn(session);
    bump();
  }

  Future<void> loadPlaySources() async {
    final settings = SettingsService();
    final lanReady = await PlaySourceEffective.lanDesktopReady();
    final next = DetailsPlaySources(
      torrent: await PlaySourceEffective.torrent(settings, lanReady),
      stremio: await PlaySourceEffective.stremio(settings, lanReady),
      nuvio: await PlaySourceEffective.nuvio(settings, lanReady),
      engine: await PlaySourceEffective.engine(settings, lanReady),
      engineAutoStart: await settings.isPlaySourceEngineAutoStartEnabled(),
      webstreaming: await PlaySourceEffective.webstreaming(settings),
    );
    session.playSources = next;
    bump();
  }
}

/// Per-title play / resolve session (autoDispose when details route pops).
final detailsPlaySessionProvider = NotifierProvider.autoDispose
    .family<DetailsPlaySessionNotifier, int, DetailsMetaKey>(
  DetailsPlaySessionNotifier.new,
);

/// Convenience: watch session bag (depends on revision int).
DetailsPlaySession watchDetailsPlaySession(
  WidgetRef ref,
  DetailsMetaKey key,
) {
  ref.watch(detailsPlaySessionProvider(key));
  return ref.read(detailsPlaySessionProvider(key).notifier).session;
}

DetailsPlaySession readDetailsPlaySession(
  WidgetRef ref,
  DetailsMetaKey key,
) {
  return ref.read(detailsPlaySessionProvider(key).notifier).session;
}

DetailsPlaySessionNotifier detailsPlaySessionNotifier(
  WidgetRef ref,
  DetailsMetaKey key,
) {
  return ref.read(detailsPlaySessionProvider(key).notifier);
}
