import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/player/providers/player_resolve_providers.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel_chrome.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:rust/rust.dart';

/// Right-side Sources panel in the player - same shell/chrome/tiles as
/// media-details Sources (torrent search list), not in-torrent file picker.
class PlayerSourcesPanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  /// Closes the Sources overlay.
  ///
  /// When [cancelEngine] is true (user closed the panel), abort in-flight
  /// Engine jobs (torrent search / Stremio HTTP). When false (user picked a
  /// source), stop scrapers/hosts only - the upcoming magnet resolve must not
  /// be cancelled. [dispose] must never cancel Engine jobs: it runs a frame
  /// after [dismiss] and would kill the fresh torrent job.
  static void dismiss({bool cancelEngine = true}) {
    DomainStreamProviderResolver.cancelAllPending(
      cancelEngineJobs: cancelEngine,
    );
    final wasShowing = _entry != null;
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
    if (wasShowing) playerMenuRestoreReturnFocus();
  }

  static Future<void> show({
    required BuildContext context,
    required Movie movie,
    int? season,
    int? episode,
    String? currentMagnet,
    String? currentStreamUrl,

    /// `torrents` | `stremio` | `nuvio` - opens on the playing source kind.
    String? preferredKind,
    String? currentAddonBaseUrl,
    int? anilistId,
    int? malId,
    int? kisskhId,
    int? kisskhEpisodeId,

    /// Soft Forja category for this panel: movie | tv | anime | drama.
    String? engineCategory,
    required Future<void> Function(TorrentResult result) onTorrentSelected,
    required Future<void> Function(Map<String, dynamic> stream)
    onStremioSelected,

    /// Movies / hub details on TV: frosted side panel, not player dialog.
    bool detailsHost = false,
  }) {
    playerMenuCaptureReturnFocus(context);
    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();
    playerChromeCancelSeekScrubs();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    // OverlayEntry is a sibling of the player route - not under ShellScope.
    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (context, _) => _PlayerSourcesOverlay(
          movie: movie,
          season: season,
          episode: episode,
          currentMagnet: currentMagnet,
          currentStreamUrl: currentStreamUrl,
          preferredKind: preferredKind,
          currentAddonBaseUrl: currentAddonBaseUrl,
          anilistId: anilistId,
          malId: malId,
          kisskhId: kisskhId,
          kisskhEpisodeId: kisskhEpisodeId,
          engineCategory: engineCategory,
          detailsHost: detailsHost,
          onTorrentSelected: onTorrentSelected,
          onStremioSelected: onStremioSelected,
          onClose: dismiss,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

class _PlayerSourcesOverlay extends StatefulWidget {
  const _PlayerSourcesOverlay({
    required this.movie,
    required this.onTorrentSelected,
    required this.onStremioSelected,
    required this.onClose,
    this.season,
    this.episode,
    this.currentMagnet,
    this.currentStreamUrl,
    this.preferredKind,
    this.currentAddonBaseUrl,
    this.anilistId,
    this.malId,
    this.kisskhId,
    this.kisskhEpisodeId,
    this.engineCategory,
    this.detailsHost = false,
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
  final String? currentStreamUrl;
  final String? preferredKind;
  final String? currentAddonBaseUrl;
  final int? anilistId;
  final int? malId;
  final int? kisskhId;
  final int? kisskhEpisodeId;
  final String? engineCategory;
  final bool detailsHost;
  final Future<void> Function(TorrentResult result) onTorrentSelected;
  final Future<void> Function(Map<String, dynamic> stream) onStremioSelected;
  final VoidCallback onClose;

  @override
  State<_PlayerSourcesOverlay> createState() => _PlayerSourcesOverlayState();
}

class _PlayerSourcesOverlayState extends State<_PlayerSourcesOverlay> {
  final bool _open = true;

  @override
  void initState() {
    super.initState();
    playerChromeCancelSeekScrubs();
  }

  @override
  Widget build(BuildContext context) {
    final detailsHost = widget.detailsHost;
    return playerOverlayShell(
      context: context,
      isOpen: _open,
      onClose: widget.onClose,
      detailsHost: detailsHost,
      enableBlur: false,
      contentPadding: detailsHost
          ? null
          : const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SourcesPanelTv.wrapBody(
        context: context,
        onClose: widget.onClose,
        includeOverlayScope: detailsHost,
        child: _PlayerSourcesBody(
          movie: widget.movie,
          season: widget.season,
          episode: widget.episode,
          currentMagnet: widget.currentMagnet,
          currentStreamUrl: widget.currentStreamUrl,
          preferredKind: widget.preferredKind,
          currentAddonBaseUrl: widget.currentAddonBaseUrl,
          anilistId: widget.anilistId,
          malId: widget.malId,
          kisskhId: widget.kisskhId,
          kisskhEpisodeId: widget.kisskhEpisodeId,
          engineCategory: widget.engineCategory,
          onTorrentSelected: widget.onTorrentSelected,
          onStremioSelected: widget.onStremioSelected,
          onClose: widget.onClose,
        ),
      ),
    );
  }
}

class _PlayerSourcesBody extends ConsumerStatefulWidget {
  const _PlayerSourcesBody({
    required this.movie,
    required this.onTorrentSelected,
    required this.onStremioSelected,
    required this.onClose,
    this.season,
    this.episode,
    this.currentMagnet,
    this.currentStreamUrl,
    this.preferredKind,
    this.currentAddonBaseUrl,
    this.anilistId,
    this.malId,
    this.kisskhId,
    this.kisskhEpisodeId,
    this.engineCategory,
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
  final String? currentStreamUrl;
  final String? preferredKind;
  final String? currentAddonBaseUrl;
  final int? anilistId;
  final int? malId;
  final int? kisskhId;
  final int? kisskhEpisodeId;
  final String? engineCategory;
  final Future<void> Function(TorrentResult result) onTorrentSelected;
  final Future<void> Function(Map<String, dynamic> stream) onStremioSelected;
  final VoidCallback onClose;

  @override
  ConsumerState<_PlayerSourcesBody> createState() => _PlayerSourcesBodyState();
}

class _PlayerSourcesBodyState extends ConsumerState<_PlayerSourcesBody> {
  final _settings = SettingsService();
  final _stremio = StremioService();
  final _listScrollController = ScrollController();
  final _currentTileKey = GlobalKey();
  final _profile = PlatformPlayback.capabilities;

  List<TorrentResult> _results = [];
  final Set<String> _torrentFetchedProviderIds = {};
  final Set<String> _torrentInFlightProviderIds = {};
  List<Map<String, dynamic>> _stremioStreams = [];
  List<Map<String, dynamic>> _streamAddons = [];
  final Set<String> _loadedAddonBaseUrls = {};
  final Set<String> _completedAddonBaseUrls = {};

  List<Map<String, dynamic>> _nuvioStreams = [];
  List<NuvioAddon> _nuvioAddons = [];
  Set<String> _nuvioSelectedScraperIds = {};
  Set<String> _nuvioFetchedScraperIds = {};
  /// Soft-cancelled while in-flight — discard late results.
  final Set<String> _nuvioDiscardScraperIds = {};
  bool _nuvioFetching = false;
  int _nuvioFetchGen = 0;
  Set<String> _nuvioInFlightScraperIds = {};
  final Set<Future<void>> _nuvioPoolTasks = {};
  int _nuvioPoolLimit = kNuvioScraperBatchDesktop;

  List<Map<String, dynamic>> _engineStreams = [];
  List<EnginePack> _enginePacks = [];
  Set<String> _engineSelectedPluginIds = {};
  Set<String> _engineFetchedPluginIds = {};
  /// Soft-cancelled while in-flight — discard late results without abortAll.
  final Set<String> _engineDiscardPluginIds = {};
  Set<String>? _engineVisibleCategories;
  bool _engineFetching = false;
  int _engineFetchGen = 0;
  Set<String> _engineInFlightPluginIds = {};
  final Set<Future<void>> _enginePoolTasks = {};
  int _enginePoolLimit = kEngineSourcesBatchDesktop;

  /// Soft Forja panel bucket. Prefer explicit hub category; else infer anime /
  /// drama from the playing `engine:` plugin so player Sources reuse the same
  /// chip prefs + session cache as details/hub.
  String get _enginePanelCategory {
    final explicit = widget.engineCategory?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return EngineCategories.panelCategoryFor(
        mediaType: widget.movie.mediaType,
        panelCategory: explicit,
        hasAnimeIds: (widget.anilistId ?? 0) > 0 || (widget.malId ?? 0) > 0,
      );
    }
    final inferred = _panelCategoryFromPlayingEnginePlugin();
    if (inferred != null) return inferred;
    return EngineCategories.panelCategoryFor(
      mediaType: widget.movie.mediaType,
      hasAnimeIds: (widget.anilistId ?? 0) > 0 || (widget.malId ?? 0) > 0,
    );
  }

  /// Anime/drama-only plugins → that bucket. Movie/TV dual plugins fall through
  /// to [mediaType] so TMDB details keep movie vs tv prefs.
  String? _panelCategoryFromPlayingEnginePlugin() {
    final base = widget.currentAddonBaseUrl;
    if (base == null || !base.startsWith('engine:')) return null;
    final pluginId = base.substring('engine:'.length);
    if (pluginId.isEmpty) return null;
    for (final pack in _enginePacks) {
      for (final p in pack.plugins) {
        if (p.id != pluginId) continue;
        final types = p.types.map((t) => t.toLowerCase()).toSet();
        if (types.contains(EngineCategories.anime)) {
          return EngineCategories.anime;
        }
        if (types.contains(EngineCategories.drama)) {
          return EngineCategories.drama;
        }
        return null;
      }
    }
    return null;
  }

  /// Engine extract type — keep `anime` / `drama` (do not coerce to movie).
  String get _engineResolveType {
    final t = widget.movie.mediaType.toLowerCase();
    if (t == 'tv' || t == 'series') return 'tv';
    if (t == 'anime' || _enginePanelCategory == EngineCategories.anime) {
      return 'anime';
    }
    if (t == 'drama' || _enginePanelCategory == EngineCategories.drama) {
      return 'drama';
    }
    return 'movie';
  }

  bool get _engineNeedsEpisode {
    final t = _engineResolveType;
    return t == 'tv' || t == 'anime' || t == 'drama';
  }

  Set<String> get _effectiveEngineCategories =>
      _engineVisibleCategories ??
      EngineCategories.defaultsForPanelCategory(_enginePanelCategory);

  bool _searching = false;
  bool _stremioFetching = false;
  int _searchGen = 0;
  int _stremioGen = 0;
  String? _error;
  bool _pendingScrollToCurrent = true;
  int _scrollToCurrentAttempts = 0;

  /// Once the user taps Torrents / Stremio / Nuvio, never auto-steal the kind
  /// back to the playing source (e.g. Torrents magnet → Nuvio click).
  bool _userPickedKind = false;

  /// Once the user picks a Stremio addon chip, do not auto
  /// move off an empty/failed addon (Torrentio 403) onto one with results.
  bool _userPickedStremioProvider = false;

  bool _showTorrents = true;
  bool _showStremio = false;
  bool _showNuvio = false;
  bool _showEngine = false;
  String _kindFilter = 'engine';
  String _selectedSourceId = TorrentSearchProviders.knaben;
  String _searchQuery = '';
  String _sortPreference = 'seeders';
  Set<String> _qualityFilters = {};
  Set<String> _languageFilters = {};
  Set<String> _techFilters = {};
  Set<String> _audioFilters = {};
  Set<String> _sizeFilters = {};

  bool _jackettConfigured = false;
  bool _prowlarrConfigured = false;
  List<String> _enabledTorrentProviders = List<String>.from(
    TorrentSearchProviders.all,
  );
  bool _localTorrentEngine = true;

  bool get _showsTorrents => _kindFilter == 'torrents';
  bool get _showsStremio => _kindFilter == 'stremio';
  bool get _showsNuvio => _kindFilter == 'nuvio';
  bool get _showsEngine => _kindFilter == 'engine';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!mounted) return;
    ref.read(playerSourcesSessionProvider.notifier).mutate((s) {
      s.isSearchingTorrents = _searching;
      s.isFetchingStremio = _stremioFetching;
      s.isFetchingNuvio = _nuvioFetching;
      s.torrents = List<TorrentResult>.from(_results);
      s.stremioStreams = List<dynamic>.from(_stremioStreams);
      s.nuvioStreams = List<Map<String, dynamic>>.from(_nuvioStreams);
    });
    final resolve = ref.read(playerResolveStatusProvider.notifier);
    if (_searching || _stremioFetching || _nuvioFetching || _engineFetching) {
      resolve.setLoading('sources');
    } else if (_results.isNotEmpty ||
        _stremioStreams.isNotEmpty ||
        _nuvioStreams.isNotEmpty ||
        _engineStreams.isNotEmpty) {
      resolve.setReady();
    }
  }

  @override
  void dispose() {
    _searchGen++;
    _stremioGen++;
    _nuvioFetchGen++;
    _engineFetchGen++;
    // Shared cancel without Engine - [dismiss] already cancelled on user
    // close; on source pick, resolve starts before this dispose and must keep
    // its torrentStream job alive.
    DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
    _listScrollController.dispose();
    super.dispose();
  }

  static final _infoHashRe = RegExp(r'[0-9a-fA-F]{40}');

  Key _playerStreamTileKey(Map<String, dynamic> s) {
    final url = s['url']?.toString() ?? '';
    if (url.isNotEmpty) return ValueKey(url);
    final hash = s['infoHash']?.toString() ?? '';
    if (hash.isNotEmpty) return ValueKey('ih:$hash');
    return ValueKey(
      '${s['_addonBaseUrl']}|${s['title'] ?? s['name']}|${s['description']}',
    );
  }

  String? _infoHashOf(String? magnetOrHash) {
    if (magnetOrHash == null || magnetOrHash.isEmpty) return null;
    return _infoHashRe.firstMatch(magnetOrHash)?.group(0)?.toLowerCase();
  }

  bool _isCurrentMagnet(String magnet) {
    final current = _infoHashOf(widget.currentMagnet);
    final other = _infoHashOf(magnet);
    if (current != null && other != null) return current == other;
    final raw = widget.currentMagnet?.toLowerCase();
    return raw != null && raw.isNotEmpty && magnet.toLowerCase() == raw;
  }

  /// Local-engine magnet session (incl. Stremio/Torrentio magnets).
  /// Sources panel ownership is the Torrents tab, not Stremio/Nuvio mirrors.
  bool _isPlayingLocalTorrentMagnet() {
    final magnet = widget.currentMagnet;
    if (magnet == null || magnet.isEmpty) return false;
    final url = widget.currentStreamUrl;
    if (url != null && url.isNotEmpty) {
      return isLocalTorrentStreamUrl(url);
    }
    return magnet.toLowerCase().startsWith('magnet:');
  }

  bool _isCurrentStremio(Map<String, dynamic> stream) {
    final playUrl = widget.currentStreamUrl;
    if (playUrl != null && playUrl.isNotEmpty) {
      final url = stream['url']?.toString();
      if (url != null && url.isNotEmpty && url == playUrl) return true;
      // Local torrent URL: Torrents tab owns the "playing" highlight via
      // infoHash. Do not mark Torrentio/Stremio/Nuvio rows as current.
      if (isLocalTorrentStreamUrl(playUrl)) return false;
      // Remote HTTP session: identity is the play URL only — do not treat a
      // different URL as current just because infoHash matches.
      return false;
    }
    final current = _infoHashOf(widget.currentMagnet);
    if (current == null) return false;
    // Magnet-only session without a local stream URL yet - still Torrents.
    if (_isPlayingLocalTorrentMagnet()) return false;
    final hash = stream['infoHash']?.toString();
    if (hash != null && hash.isNotEmpty) {
      return _infoHashOf(hash) == current;
    }
    final url = stream['url']?.toString();
    return url != null && _isCurrentMagnet(url);
  }

  /// Single scroll target in merged lists - torrent row wins over Stremio when
  /// both share the same infoHash (Torrentio mirrors the active magnet).
  int? _currentItemIndex(
    List<TorrentResult> torrents,
    List<Map<String, dynamic>> stremio, {
    List<Map<String, dynamic>> nuvio = const [],
    List<Map<String, dynamic>> engine = const [],
  }) {
    for (var i = 0; i < torrents.length; i++) {
      if (_isCurrentMagnet(torrents[i].magnet)) return i;
    }
    final stremioOffset = torrents.length;
    for (var i = 0; i < stremio.length; i++) {
      if (_isCurrentStremio(stremio[i])) return stremioOffset + i;
    }
    final nuvioOffset = stremioOffset + stremio.length;
    for (var i = 0; i < nuvio.length; i++) {
      if (_isCurrentStremio(nuvio[i])) return nuvioOffset + i;
    }
    final engineOffset = nuvioOffset + nuvio.length;
    for (var i = 0; i < engine.length; i++) {
      if (_isCurrentStremio(engine[i])) return engineOffset + i;
    }
    return null;
  }

  void _resetListScroll({bool allowScrollToCurrent = false}) {
    _pendingScrollToCurrent = allowScrollToCurrent;
    _scrollToCurrentAttempts = 0;
    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }
    if (allowScrollToCurrent) {
      _scheduleScrollToCurrent();
    }
  }

  void _requestScrollToCurrent() {
    if (_listScrollController.hasClients && _listScrollController.offset > 8) {
      return;
    }
    _pendingScrollToCurrent = true;
    _scrollToCurrentAttempts = 0;
    _scheduleScrollToCurrent();
  }

  /// Playing Stremio addon baseUrl when known (caller + matched stream).
  String? _preferredStremioAddonBaseUrl([List<Map<String, dynamic>>? addons]) {
    final list = addons ?? _streamAddons;
    final base = widget.currentAddonBaseUrl;
    if (base != null &&
        base.isNotEmpty &&
        !base.startsWith('nuvio:') &&
        !base.startsWith('engine:') &&
        list.any((a) => a['baseUrl'] == base)) {
      return base;
    }
    for (final s in _stremioStreams) {
      if (!_isCurrentStremio(s)) continue;
      final url = s['_addonBaseUrl']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  List<String> get _stremioAddonBaseUrlsInOrder => [
    for (final a in _streamAddons)
      if (a['baseUrl'] is String) a['baseUrl'] as String,
  ];

  /// Move Stremio provider chip off an empty addon when another has streams
  /// (e.g. Torrentio Cloudflare 403, YTS OK). Respects a manual provider tap.
  void _syncStremioProviderSelection() {
    if (_kindFilter != 'stremio') return;
    final next = promoteStremioProviderId(
      currentId: _selectedSourceId,
      preferredId: _preferredStremioAddonBaseUrl(),
      addonBaseUrlsInOrder: _stremioAddonBaseUrlsInOrder,
      loadedIds: _loadedAddonBaseUrls,
      completedIds: _completedAddonBaseUrls,
      fetching: _stremioFetching,
      userPicked: _userPickedStremioProvider,
    );
    if (next != null) _selectedSourceId = next;
  }

  /// Ensure the filtered Stremio / Nuvio list includes the playing row.
  void _selectPlayingProviderIfNeeded() {
    if (_kindFilter == 'stremio') {
      // Prefer the playing addon only when it already has rows - otherwise
      // [promoteStremioProviderId] keeps the list stuck on Torrentio 403.
      _syncStremioProviderSelection();
      return;
    }
    if (_kindFilter != 'nuvio' && _kindFilter != 'engine') return;
    if (_kindFilter == 'engine') {
      final base = widget.currentAddonBaseUrl;
      String? pluginId;
      if (base != null && base.startsWith('engine:')) {
        pluginId = base.substring('engine:'.length);
      } else {
        for (final s in _engineStreams) {
          if (!_isCurrentStremio(s)) continue;
          final id = s['_enginePluginId'] as String?;
          if (id != null && id.isNotEmpty) {
            pluginId = id;
            break;
          }
          final sBase = s['_addonBaseUrl']?.toString();
          if (sBase != null && sBase.startsWith('engine:')) {
            pluginId = sBase.substring('engine:'.length);
            break;
          }
        }
      }
      if (pluginId == null || pluginId.isEmpty) return;
      if (_engineSelectedPluginIds.contains(pluginId)) return;
      _engineSelectedPluginIds = {..._engineSelectedPluginIds, pluginId};
      return;
    }
    final base = widget.currentAddonBaseUrl;
    String? scraperId;
    if (base != null && base.startsWith('nuvio:')) {
      scraperId = base.substring('nuvio:'.length);
    } else {
      for (final s in _nuvioStreams) {
        if (!_isCurrentStremio(s)) continue;
        final id = s['_nuvioScraperId'] as String?;
        if (id != null && id.isNotEmpty) {
          scraperId = id;
          break;
        }
        final sBase = s['_addonBaseUrl']?.toString();
        if (sBase != null && sBase.startsWith('nuvio:')) {
          scraperId = sBase.substring('nuvio:'.length);
          break;
        }
      }
    }
    if (scraperId == null || scraperId.isEmpty) return;
    if (_nuvioSelectedScraperIds.contains(scraperId)) return;
    _nuvioSelectedScraperIds = {..._nuvioSelectedScraperIds, scraperId};
  }

  void _scheduleScrollToCurrent() {
    if (!_pendingScrollToCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingScrollToCurrent) return;

      final torrents = _showsTorrents
          ? _filteredTorrents
          : const <TorrentResult>[];
      final stremio = _showsStremio
          ? _visibleStremioStreams
          : const <Map<String, dynamic>>[];
      final nuvio = _showsNuvio
          ? _filteredNuvio
          : const <Map<String, dynamic>>[];
      final engine = _showsEngine
          ? _filteredEngine
          : const <Map<String, dynamic>>[];
      final index = _currentItemIndex(
        torrents,
        stremio,
        nuvio: nuvio,
        engine: engine,
      );
      // Lists still loading / wrong provider filter - keep pending.
      if (index == null) return;

      if (index == 0) {
        _pendingScrollToCurrent = false;
        _scrollToCurrentAttempts = 0;
        if (_listScrollController.hasClients) {
          _listScrollController.jumpTo(0);
        }
        return;
      }

      // Prefer precise ensureVisible when the tile is already mounted.
      final ctx = _currentTileKey.currentContext;
      if (ctx != null) {
        _pendingScrollToCurrent = false;
        _scrollToCurrentAttempts = 0;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      if (!_listScrollController.hasClients) return;

      // Lazy ListView has not built the off-screen tile yet - jump by index
      // so the next frame mounts it and ensureVisible can finish.
      _scrollToCurrentAttempts++;
      if (_scrollToCurrentAttempts > 10) {
        _pendingScrollToCurrent = false;
        return;
      }
      const stride = 98.0; // ~tile height + separator
      final maxExtent = _listScrollController.position.maxScrollExtent;
      final target = (index * stride).clamp(0.0, maxExtent);
      if ((_listScrollController.offset - target).abs() < 1.0) {
        // Estimate put us here but the tile still is not built - nudge once.
        final nudged = (target + 160.0).clamp(0.0, maxExtent);
        if ((nudged - target).abs() < 1.0) {
          _pendingScrollToCurrent = false;
          return;
        }
        _listScrollController.jumpTo(nudged);
        return;
      }
      _listScrollController.jumpTo(target);
    });
  }

  Future<void> _bootstrap() async {
    final sort = await _settings.getSortPreference();
    final jackett = await _settings.isJackettConfigured();
    final prowlarr = await _settings.isProwlarrConfigured();
    final enabledProviders = await _settings.getEnabledTorrentProviders();
    final lanReady = await PlaySourceEffective.lanDesktopReady();
    final torrentOn = await PlaySourceEffective.torrent(_settings, lanReady);
    final stremioOn = await PlaySourceEffective.stremio(_settings, lanReady);
    final nuvioOn = await PlaySourceEffective.nuvio(_settings, lanReady);
    final engineOn = await PlaySourceEffective.engine(_settings, lanReady);
    final local = _profile.localTorrentEngine;
    List<NuvioAddon> nuvioAddons = const [];
    Set<String> nuvioSelected = {};
    if (nuvioOn) {
      try {
        nuvioAddons = await NuvioService.instance.listSourcesPanelAddons();
        nuvioSelected = await NuvioService.instance
            .loadSourcesSelectedScraperIds(
              enabledIds: enabledNuvioScraperIds(nuvioAddons),
            );
      } catch (_) {}
    }
    if (!mounted) return;

    final hasNuvio = nuvioOn && nuvioAddons.isNotEmpty;
    final hasEngine = engineOn;
    final kind = _resolveInitialKind(
      hasTorrent: torrentOn,
      hasStremio: stremioOn,
      hasNuvio: hasNuvio,
      hasEngine: hasEngine,
    );

    List<Map<String, dynamic>> addons = const [];
    if (stremioOn && kind == 'stremio') {
      try {
        addons = await _stremio.getAddonsForResource('stream');
      } catch (_) {}
    }
    if (!mounted) return;

    final hasStremio = stremioOn && (kind != 'stremio' || addons.isNotEmpty);

    List<EnginePack> enginePacks = const [];
    Set<String> engineSelected = {};
    if (engineOn && kind == 'engine') {
      try {
        enginePacks = await EngineService.instance.listSourcesPanelPacks();
        // Assign before reading [_enginePanelCategory] so anime/drama can be
        // inferred from the playing engine plugin.
        _enginePacks = enginePacks;
        final enabledIds = enabledEnginePluginIds(enginePacks);
        final panelCategory = _enginePanelCategory;
        final scope = EngineCategories.matchingPluginIds(
          packs: enginePacks,
          categories: EngineCategories.defaultsForPanelCategory(panelCategory),
        );
        engineSelected = EngineCategories.scopeSelectionIfFullAll(
          selected: await EngineService.instance.loadSourcesSelectedPluginIds(
            enabledIds: enabledIds,
            panelCategory: panelCategory,
            selectAllScopeIds: scope,
          ),
          enabledIds: enabledIds,
          scope: scope,
        );
      } catch (_) {}
    }
    if (!mounted) return;

    setState(() {
      _sortPreference = sort;
      _jackettConfigured = jackett;
      _prowlarrConfigured = prowlarr;
      _enabledTorrentProviders = enabledProviders;
      _localTorrentEngine = local;
      _showTorrents = torrentOn;
      _showStremio = hasStremio;
      _showNuvio = hasNuvio;
      _showEngine = hasEngine;
      _nuvioAddons = nuvioAddons;
      _nuvioSelectedScraperIds = nuvioSelected;
      _enginePacks = enginePacks;
      _engineSelectedPluginIds = engineSelected;
      _streamAddons = addons;
      _kindFilter = kind;
      _selectedSourceId = _sourceIdForKind(kind, addons);
      if (kind == 'nuvio') {
        final base = widget.currentAddonBaseUrl;
        if (base != null && base.startsWith('nuvio:')) {
          _nuvioSelectedScraperIds = {
            ..._nuvioSelectedScraperIds,
            base.substring('nuvio:'.length),
          };
        }
      }
      if (kind == 'engine') {
        final base = widget.currentAddonBaseUrl;
        if (base != null && base.startsWith('engine:')) {
          _engineSelectedPluginIds = {
            ..._engineSelectedPluginIds,
            base.substring('engine:'.length),
          };
        }
      }
    });

    // Load only the selected kind(s) - no prefetch of other categories.
    _ensureVisibleKindsLoaded();
    // Hydrate addons in the background when Torrents opened first so search
    // is not blocked on sequential manifest fetches.
    if (stremioOn) unawaited(_refreshStreamAddons());
  }

  String get _catalogCacheKey => CatalogSourcesSessionCache.cacheKey(
    mediaId: widget.movie.id,
    mediaType: widget.movie.mediaType,
    season: widget.season,
    episode: widget.episode,
  );

  /// Hydrate from session TTL cache or fetch - only for the active kind.
  void _ensureVisibleKindsLoaded({bool force = false}) {
    if (_showsTorrents) _ensureTorrentsLoaded(force: force);
    if (_showsStremio) _ensureStremioLoaded(force: force);
    if (_showsNuvio) unawaited(_ensureNuvioLoaded(force: force));
    if (_showsEngine) unawaited(_ensureEngineLoaded(force: force));
  }

  Future<void> _ensureEngineMetadata() async {
    if (!_showEngine) return;
    try {
      final packs = await EngineService.instance.listSourcesPanelPacks();
      if (!mounted) return;
      // Packs first so [_enginePanelCategory] can infer anime/drama from the
      // playing engine plugin before loading chip selection prefs.
      _enginePacks = packs;
      final enabledIds = enabledEnginePluginIds(packs);
      final panelCategory = _enginePanelCategory;
      final scope = EngineCategories.matchingPluginIds(
        packs: packs,
        categories: EngineCategories.defaultsForPanelCategory(panelCategory),
      );
      final saved = EngineCategories.scopeSelectionIfFullAll(
        selected: await EngineService.instance.loadSourcesSelectedPluginIds(
          enabledIds: enabledIds,
          panelCategory: panelCategory,
          selectAllScopeIds: scope,
        ),
        enabledIds: enabledIds,
        scope: scope,
      );
      if (!mounted) return;
      setState(() {
        _enginePacks = packs;
        _engineSelectedPluginIds = filterEngineSelectedPluginIds(
          savedIds: saved,
          enabledIds: enabledIds,
        );
      });
    } catch (_) {}
  }

  void _ensureTorrentsLoaded({bool force = false}) {
    if (!_showsTorrents) return;
    if (force) {
      unawaited(_runTorrentSearch(force: true));
      return;
    }
    if (_searching) return;
    final cached = CatalogSourcesSessionCache.readTorrents(_catalogCacheKey);
    if (cached != null && _results.isEmpty) {
      setState(() {
        _results = cached;
        TorrentSearchProviders.addFetchedFromResultSources(
          _torrentFetchedProviderIds,
          cached.map((r) => r.source),
        );
        _error = null;
      });
      _focusPlayingSourceIfNeeded();
      _requestScrollToCurrent();
    }
    unawaited(_runTorrentSearch());
  }

  Future<void> _refreshStreamAddons() async {
    try {
      final stremioOn = await _settings.isPlaySourceStremioEnabled();
      if (!stremioOn) return;
      final addons = await _stremio.getAddonsForResource('stream');
      if (!mounted) return;
      setState(() {
        _streamAddons = addons;
        _showStremio = addons.isNotEmpty;
        if (_kindFilter == 'stremio' &&
            !_streamAddons.any(
              (a) => a['baseUrl']?.toString() == _selectedSourceId,
            )) {
          _userPickedStremioProvider = false;
          _selectedSourceId = _sourceIdForKind('stremio', addons);
        }
      });
    } catch (_) {}
  }

  void _ensureStremioLoaded({bool force = false}) {
    unawaited(
      _refreshStreamAddons().then((_) {
        if (!mounted || !_showsStremio) return;
        if (force) {
          unawaited(_fetchStremioStreams(refresh: true));
          return;
        }
        if (_stremioFetching) return;
        final cached = CatalogSourcesSessionCache.readStremio(_catalogCacheKey);
        if (cached != null && cached.isNotEmpty) {
          setState(() {
            _stremioStreams = cached;
            _loadedAddonBaseUrls
              ..clear()
              ..addAll({
                for (final s in cached)
                  if (s['_addonBaseUrl'] is String)
                    s['_addonBaseUrl'] as String,
              });
            _completedAddonBaseUrls
              ..clear()
              ..addAll(_loadedAddonBaseUrls);
            _error = null;
            _userPickedStremioProvider = false;
            _syncStremioProviderSelection();
          });
          _focusPlayingSourceIfNeeded();
          _requestScrollToCurrent();
        } else if (cached != null && cached.isEmpty) {
          CatalogSourcesSessionCache.invalidate(
            _catalogCacheKey,
            kind: 'stremio',
          );
        }
        unawaited(_fetchStremioStreams());
      }),
    );
  }

  Future<void> _ensureNuvioLoaded({bool force = false}) async {
    if (!_showsNuvio) return;
    if (_nuvioSelectedScraperIds.isEmpty) return;
    if (force) {
      await _fetchNextNuvioScraper(refresh: true);
      return;
    }
    if (_nuvioFetching) return;
    if (_nuvioStreams.isEmpty) {
      final cached = CatalogSourcesSessionCache.readNuvio(_catalogCacheKey);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _nuvioStreams = cached.streams;
          _nuvioFetchedScraperIds = cached.fetchedScraperIds;
          _error = null;
        });
        _focusPlayingSourceIfNeeded();
        _requestScrollToCurrent();
      }
    }
    if (_pendingNuvioScraperIds.isNotEmpty) {
      await _fetchNextNuvioScraper();
    }
  }

  Future<void> _ensureEngineLoaded({bool force = false}) async {
    if (!_showsEngine) return;
    await _ensureEngineMetadata();
    if (!mounted || !_showsEngine) return;
    if (_engineSelectedPluginIds.isEmpty) return;
    if (force) {
      await _fetchNextEnginePlugin(refresh: true);
      return;
    }
    if (_engineFetching) return;
    if (_engineStreams.isEmpty) {
      final cached = CatalogSourcesSessionCache.readEngine(_catalogCacheKey);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _engineStreams = cached.streams;
          _engineFetchedPluginIds = cached.fetchedPluginIds;
          _error = null;
        });
        _focusPlayingSourceIfNeeded();
        _requestScrollToCurrent();
      }
    }
    final pending = nextEnginePluginId(
      orderedIds: _orderedEnginePluginIds,
      selectedIds: _engineSelectedPluginIds,
      fetchedIds: _engineFetchedPluginIds,
    );
    if (pending != null) {
      await _fetchNextEnginePlugin();
    }
  }

  void _reloadKind(String kind) {
    if (kind != _kindFilter) return;
    switch (kind) {
      case 'torrents':
        _ensureTorrentsLoaded(force: true);
      case 'stremio':
        _ensureStremioLoaded(force: true);
      case 'nuvio':
        unawaited(_ensureNuvioLoaded(force: true));
      case 'engine':
        unawaited(_ensureEngineLoaded(force: true));
    }
  }

  /// Stop in-flight work for kinds that are no longer selected.
  void _abortHiddenKindFetches(String keepKind) {
    if (keepKind != 'torrents' && _searching) {
      _searchGen++;
      _searching = false;
      _results = [];
      _torrentFetchedProviderIds.clear();
      _torrentInFlightProviderIds.clear();
    }
    if (keepKind != 'stremio' && _stremioFetching) {
      _stremioGen++;
      _stremioFetching = false;
      _stremioStreams = [];
      _loadedAddonBaseUrls.clear();
      _completedAddonBaseUrls.clear();
    }
    if (keepKind != 'nuvio' && _nuvioFetching) {
      _nuvioAbortWork(clearFetched: true);
      _nuvioStreams = [];
    }
    if (keepKind != 'engine' && _engineFetching) {
      _engineAbortWork(clearFetched: true);
      _engineStreams = [];
    }
  }

  String _sourceIdForKind(String kind, List<Map<String, dynamic>> addons) {
    return switch (kind) {
      'stremio' =>
        _preferredStremioAddonBaseUrl(addons) ??
            (addons.isNotEmpty
                ? addons.first['baseUrl'] as String
                : TorrentSearchProviders.allId),
      'nuvio' => 'all_nuvio',
      'engine' => 'all_engine',
      'torrents' => TorrentSearchProviders.defaultChipId(
        _enabledTorrentProviders,
      ),
      _ => TorrentSearchProviders.allId,
    };
  }

  /// Prefer caller's kind when available; else Forja → Torrents → Stremio → Nuvio.
  String _resolveInitialKind({
    required bool hasTorrent,
    required bool hasStremio,
    required bool hasNuvio,
    required bool hasEngine,
  }) {
    final preferred = _effectivePreferredKind();
    if (preferred == 'engine' && hasEngine) return 'engine';
    if (preferred == 'torrents' && hasTorrent) return 'torrents';
    if (preferred == 'stremio' && hasStremio) return 'stremio';
    if (preferred == 'nuvio' && hasNuvio) return 'nuvio';
    if (hasEngine) return 'engine';
    if (hasTorrent) return 'torrents';
    if (hasStremio) return 'stremio';
    if (hasNuvio) return 'nuvio';
    return 'torrents';
  }

  String _defaultStremioSourceId() {
    if (_streamAddons.isEmpty) return TorrentSearchProviders.allId;
    for (final a in _streamAddons) {
      final base = a['baseUrl'] as String?;
      if (base != null && _loadedAddonBaseUrls.contains(base)) return base;
    }
    return _streamAddons.first['baseUrl'] as String;
  }

  String? _effectivePreferredKind() {
    // Local magnet playback owns Torrents even when the magnet came from
    // Stremio/Torrentio (preferredKind stays 'stremio' on the player).
    if (_isPlayingLocalTorrentMagnet()) return 'torrents';
    final base = widget.currentAddonBaseUrl;
    if (base != null && base.startsWith('engine:')) return 'engine';
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    final preferred = widget.preferredKind;
    if (preferred == 'nuvio' ||
        preferred == 'engine' ||
        preferred == 'stremio' ||
        preferred == 'torrents') {
      return preferred;
    }
    final magnet = widget.currentMagnet;
    if (magnet != null && magnet.isNotEmpty) {
      return 'torrents';
    }
    return preferred;
  }

  /// After lists update, scroll the playing source into view when it is
  /// already under the active kind; otherwise switch to the kind that has it.
  ///
  /// After a manual kind tap ([_userPickedKind]), only scroll/select provider
  /// within the current tab - never yank Torrents ↔ Stremio ↔ Nuvio.
  void _focusPlayingSourceIfNeeded() {
    if (!mounted) return;

    bool torrentsHit() =>
        _showTorrents && _results.any((r) => _isCurrentMagnet(r.magnet));
    bool nuvioHit() => _showNuvio && _nuvioStreams.any(_isCurrentStremio);
    bool engineHit() => _showEngine && _engineStreams.any(_isCurrentStremio);
    bool stremioHit() => _showStremio && _stremioStreams.any(_isCurrentStremio);

    void finishOnKind(String kind, {required bool allowKindSwitch}) {
      final needsKind = allowKindSwitch && _kindFilter != kind;
      final beforeAddon = _selectedSourceId;
      final beforeNuvio = Set<String>.from(_nuvioSelectedScraperIds);
      if (needsKind) {
        _kindFilter = kind;
        _selectedSourceId = _sourceIdForKind(kind, _streamAddons);
      }
      _selectPlayingProviderIfNeeded();
      final providerChanged =
          beforeAddon != _selectedSourceId ||
          beforeNuvio.length != _nuvioSelectedScraperIds.length ||
          !beforeNuvio.containsAll(_nuvioSelectedScraperIds);
      if (needsKind || providerChanged) {
        setState(() {});
        if (needsKind) _ensureVisibleKindsLoaded();
      }
      _requestScrollToCurrent();
    }

    // Manual kind: stay on the tab the user opened.
    if (_userPickedKind) {
      if (_kindFilter == 'torrents' && torrentsHit()) {
        finishOnKind('torrents', allowKindSwitch: false);
      } else if (_kindFilter == 'nuvio' && nuvioHit()) {
        finishOnKind('nuvio', allowKindSwitch: false);
      } else if (_kindFilter == 'engine' && engineHit()) {
        finishOnKind('engine', allowKindSwitch: false);
      } else if (_kindFilter == 'stremio' && stremioHit()) {
        finishOnKind('stremio', allowKindSwitch: false);
      }
      return;
    }

    // Already visible under the active filter - select provider + scroll.
    if (_kindFilter == 'torrents' && torrentsHit()) {
      finishOnKind('torrents', allowKindSwitch: true);
      return;
    }
    if (_kindFilter == 'nuvio' && nuvioHit()) {
      finishOnKind('nuvio', allowKindSwitch: true);
      return;
    }
    if (_kindFilter == 'engine' && engineHit()) {
      finishOnKind('engine', allowKindSwitch: true);
      return;
    }
    if (_kindFilter == 'stremio' && stremioHit()) {
      finishOnKind('stremio', allowKindSwitch: true);
      return;
    }

    // Prefer the caller's kind when it already has the playing row.
    // While that kind is still loading, do not steal focus to a Torrentio
    // mirror under Torrents / Stremio.
    final preferred = _effectivePreferredKind();
    if (preferred == 'nuvio' && _showNuvio) {
      if (nuvioHit()) {
        finishOnKind('nuvio', allowKindSwitch: true);
        return;
      }
      if (_nuvioFetching) return;
    }
    if (preferred == 'engine' && _showEngine) {
      if (engineHit()) {
        finishOnKind('engine', allowKindSwitch: true);
        return;
      }
      if (_engineFetching) return;
    }
    if (preferred == 'stremio' && _showStremio) {
      if (stremioHit()) {
        finishOnKind('stremio', allowKindSwitch: true);
        return;
      }
      if (_stremioFetching) return;
    }
    if (preferred == 'torrents' && _showTorrents) {
      if (torrentsHit()) {
        finishOnKind('torrents', allowKindSwitch: true);
        return;
      }
      if (_searching) return;
      // Keep Torrents even when the playing magnet is not in indexer results
      // (common for Stremio/Torrentio magnets streamed via local engine).
      finishOnKind('torrents', allowKindSwitch: true);
      return;
    }

    // Discovery order: Nuvio before Stremio/Torrents so a Torrentio mirror of
    // the same infoHash does not steal a Nuvio / Stremio Direct session.
    if (nuvioHit()) {
      finishOnKind('nuvio', allowKindSwitch: true);
    } else if (engineHit()) {
      finishOnKind('engine', allowKindSwitch: true);
    } else if (stremioHit()) {
      finishOnKind('stremio', allowKindSwitch: true);
    } else if (torrentsHit()) {
      finishOnKind('torrents', allowKindSwitch: true);
    }
  }

  List<TorrentResult> get _filteredTorrents {
    final list =
        filterTorrentResults(
          _results,
          searchQuery: _searchQuery,
          qualityFilters: _qualityFilters,
          languageFilters: _languageFilters,
          techFilters: _techFilters,
          audioFilters: _audioFilters,
          sizeFilters: _sizeFilters,
        ).where(
          (r) => TorrentSearchProviders.matchesResultSource(
            _selectedSourceId,
            r.source,
          ),
        );
    return List<TorrentResult>.from(list)..sort(_compare);
  }

  double _streamSizeBytes(Map<String, dynamic> s) {
    final label = TorrentReleaseMetadata.resolveStreamSizeLabel(s);
    if (label != null) {
      final bytes = TorrentReleaseMetadata.parseSizeBytes(label);
      if (bytes > 0) return bytes;
    }
    final hints = s['behaviorHints'];
    if (hints is Map) {
      final videoSize = hints['videoSize'] ?? hints['video_size'];
      if (videoSize is num && videoSize > 0) return videoSize.toDouble();
      final parsed = double.tryParse(videoSize?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final blob =
        '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''} ${s['size'] ?? ''}';
    return TorrentReleaseMetadata.parseSizeBytes(blob);
  }

  /// Quality / language / tech / size / search — same contract as details Sources.
  bool _matchesStreamFilters(Map<String, dynamic> s) {
    final name = '${s['title'] ?? s['name'] ?? ''} ${s['description'] ?? ''}';
    if (!TorrentReleaseMetadata.parse(name).matchesFiltersForName(
      name,
      searchQuery: _searchQuery,
      qualityFilters: _qualityFilters,
      languageFilters: _languageFilters,
      techFilters: _techFilters,
      audioFilters: _audioFilters,
    )) {
      return false;
    }
    return TorrentReleaseMetadata.matchesSizeFilters(
      _streamSizeBytes(s),
      _sizeFilters,
    );
  }

  List<Map<String, dynamic>> get _filteredStremio {
    return _stremioStreams.where((s) {
      if (_selectedSourceId.isNotEmpty &&
          _selectedSourceId != 'all_stremio' &&
          s['_addonBaseUrl'] != _selectedSourceId) {
        return false;
      }
      return _matchesStreamFilters(s);
    }).toList();
  }

  bool _nuvioStreamSelected(Map<String, dynamic> s) {
    final id = s['_nuvioScraperId'] as String?;
    if (id != null) return _nuvioSelectedScraperIds.contains(id);
    final base = s['_addonBaseUrl']?.toString();
    if (base != null && base.startsWith('nuvio:')) {
      return _nuvioSelectedScraperIds.contains(base.substring('nuvio:'.length));
    }
    return false;
  }

  List<Map<String, dynamic>> get _filteredNuvio {
    return _nuvioStreams
        .where((s) => _nuvioStreamSelected(s) && _matchesStreamFilters(s))
        .toList();
  }

  bool _engineStreamSelected(Map<String, dynamic> s) {
    final id = s['_enginePluginId'] as String?;
    if (id != null) return _engineSelectedPluginIds.contains(id);
    final base = s['_addonBaseUrl']?.toString();
    if (base != null && base.startsWith('engine:')) {
      return _engineSelectedPluginIds.contains(
        base.substring('engine:'.length),
      );
    }
    return false;
  }

  List<Map<String, dynamic>> get _filteredEngine {
    return _engineStreams
        .where((s) => _engineStreamSelected(s) && _matchesStreamFilters(s))
        .toList();
  }

  int _compare(TorrentResult a, TorrentResult b) {
    switch (_sortPreference) {
      case 'size':
        return b.sizeInBytes.compareTo(a.sizeInBytes);
      case 'name':
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'seeders':
      default:
        return b.seedersCount.compareTo(a.seedersCount);
    }
  }

  Iterable<String> get _filterNames sync* {
    if (_showsTorrents) {
      for (final r in _results) {
        yield r.name;
      }
    }
    if (_showsStremio) {
      for (final s in _stremioStreams) {
        yield '${s['title'] ?? ''} ${s['name'] ?? ''} ${s['description'] ?? ''}';
      }
    }
    if (_showsNuvio) {
      for (final s in _nuvioStreams) {
        if (!_nuvioStreamSelected(s)) continue;
        yield '${s['title'] ?? ''} ${s['name'] ?? ''} ${s['description'] ?? ''}';
      }
    }
    if (_showsEngine) {
      for (final s in _engineStreams) {
        if (!_engineStreamSelected(s)) continue;
        yield '${s['title'] ?? ''} ${s['name'] ?? ''} ${s['description'] ?? ''}';
      }
    }
  }

  Set<String> get _availableQualities => collectQualities(_filterNames);
  Set<String> get _availableLanguages => collectLanguages(_filterNames);
  Set<String> get _availableTech => collectTechTags(_filterNames);
  Set<String> get _availableSizes {
    final sizes = <double>[];
    if (_showsTorrents) {
      for (final r in _results) {
        final bytes = r.sizeInBytes > 0
            ? r.sizeInBytes
            : TorrentReleaseMetadata.parseSizeBytes(r.size);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_showsStremio) {
      for (final s in _stremioStreams) {
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_showsNuvio) {
      for (final s in _nuvioStreams) {
        if (!_nuvioStreamSelected(s)) continue;
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    if (_showsEngine) {
      for (final s in _engineStreams) {
        if (!_engineStreamSelected(s)) continue;
        final bytes = _streamSizeBytes(s);
        if (bytes > 0) sizes.add(bytes);
      }
    }
    return collectSizeRanges(sizes);
  }

  List<SourcesPanelProviderOption> get _providerOptions {
    if (_kindFilter == 'stremio') {
      return [
        for (final a in _streamAddons)
          if ((a['baseUrl']?.toString().trim() ?? '').isNotEmpty)
            SourcesPanelProviderOption(
              id: a['baseUrl'].toString().trim(),
              label: (a['name'] ?? 'Addon').toString(),
            ),
      ];
    }
    if (_kindFilter == 'nuvio') {
      return [
        const SourcesPanelProviderOption(id: 'all_nuvio', label: 'All'),
        for (final a in _nuvioAddons)
          for (final s in a.scrapers)
            if (s.enabled)
              SourcesPanelProviderOption(id: 'nuvio:${s.id}', label: s.name),
      ];
    }
    if (_kindFilter == 'engine') {
      final cats = _effectiveEngineCategories;
      return [
        const SourcesPanelProviderOption(id: 'all_engine', label: 'All'),
        for (final a in _enginePacks)
          for (final s in a.plugins)
            if (EngineCategories.pluginChipVisible(
              plugin: s,
              visibleCategories: cats,
              selectedPluginIds: _engineSelectedPluginIds,
            ))
              SourcesPanelProviderOption(id: 'engine:${s.id}', label: s.name),
      ];
    }
    if (_kindFilter == 'torrents') {
      return torrentProviderChipOptions(
        enabledProviders: _enabledTorrentProviders,
        jackettConfigured: _jackettConfigured,
        prowlarrConfigured: _prowlarrConfigured,
      );
    }
    return const [];
  }

  Set<String> get _loadingChipIds {
    switch (_kindFilter) {
      case 'torrents':
        return _torrentInFlightProviderIds;
      case 'nuvio':
        return !_nuvioWorkActive
            ? const <String>{}
            : {
                for (final id in _nuvioSelectedScraperIds)
                  if (!_nuvioFetchedScraperIds.contains(id))
                    'nuvio:$id',
              };
      case 'engine':
        return {
          for (final id in _engineLoadingPluginIds) EngineIds.pluginChip(id),
        };
      case 'stremio':
        return !_stremioFetching
            ? const <String>{}
            : {_selectedSourceId};
      default:
        return const <String>{};
    }
  }

  bool get _isFetching =>
      (_showsTorrents && _searching) ||
      (_showsStremio && _stremioFetching) ||
      (_showsNuvio && _nuvioFetching) ||
      (_showsEngine && _engineFetching);

  void _abortTorrentSearch() {
    if (!_searching) return;
    setState(() {
      _searchGen++;
      _searching = false;
      _torrentInFlightProviderIds.clear();
    });
  }

  void Function(String id) _onTorrentProviderDone(
    int gen, {
    required int hitsNeeded,
  }) {
    final hits = <String, int>{};
    return (id) {
      if (!mounted || gen != _searchGen) return;
      hits[id] = (hits[id] ?? 0) + 1;
      if (hits[id]! >= hitsNeeded) {
        setState(() {
          _torrentFetchedProviderIds.add(id);
          _torrentInFlightProviderIds.remove(id);
        });
      }
    };
  }

  Future<void> _runTorrentSearch({bool force = false}) async {
    if (TorrentSearchProviders.isNoneChip(_selectedSourceId)) {
      _searchGen++;
      setState(() {
        _searching = false;
        _torrentInFlightProviderIds.clear();
      });
      return;
    }
    final gen = ++_searchGen;
    if (force) {
      final enabledForRefresh = TorrentSearchProviders.enabledForChip(
        _selectedSourceId,
        _enabledTorrentProviders,
      );
      _torrentFetchedProviderIds.removeAll(enabledForRefresh);
    }
    final isTv = widget.movie.mediaType == 'tv';
    final season = widget.season ?? 1;
    final episode = widget.episode ?? 1;

    if (_selectedSourceId == 'jackett' || _selectedSourceId == 'prowlarr') {
      setState(() {
        _searching = true;
        _error = null;
        _torrentInFlightProviderIds
          ..clear()
          ..add(_selectedSourceId);
      });
      try {
        if (_selectedSourceId == 'jackett') {
          await _finishTorrentSearch(
            gen,
            await _searchJackett(isTv: isTv, season: season, episode: episode),
            merge: force,
          );
        } else {
          await _finishTorrentSearch(
            gen,
            await _searchProwlarr(isTv: isTv, season: season, episode: episode),
            merge: force,
          );
        }
      } catch (e) {
        if (!mounted || gen != _searchGen) return;
        setState(() {
          _searching = false;
          _torrentInFlightProviderIds.clear();
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    }

    final enabled = force
        ? TorrentSearchProviders.enabledForChip(
            _selectedSourceId,
            _enabledTorrentProviders,
          )
        : TorrentSearchProviders.missingEnabledForChip(
            chipId: _selectedSourceId,
            settingsEnabled: _enabledTorrentProviders,
            fetchedProviderIds: _torrentFetchedProviderIds,
          );
    if (enabled.isEmpty) {
      setState(() {
        _searching = false;
        _torrentInFlightProviderIds.clear();
      });
      return;
    }
    final replace = _results.isEmpty;
    setState(() {
      _searching = true;
      _error = null;
      if (replace) _results = [];
      _torrentInFlightProviderIds
        ..clear()
        ..addAll(enabled);
    });

    try {
      if (isTv) {
        await _searchForjaTvProgressive(
          gen,
          season: season,
          episode: episode,
          enabledProviders: enabled,
          replace: replace,
        );
      } else {
        await _searchForjaMovieProgressive(
          gen,
          enabledProviders: enabled,
          replace: replace,
        );
      }
      if (!mounted || gen != _searchGen) return;
      await _finishTorrentSearch(gen, _results);
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searching = false;
        _torrentInFlightProviderIds.clear();
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _finishTorrentSearch(
    int gen,
    List<TorrentResult> found, {
    bool merge = false,
  }) async {
    if (!mounted || gen != _searchGen) return;
    setState(() {
      if (merge) {
        _mergeTorrentResults(found);
      } else {
        _results = found;
      }
      _searching = false;
      _torrentInFlightProviderIds.clear();
      if (_results.isEmpty && !_showsStremio && !_showsNuvio) {
        _error = 'No torrents found';
      }
    });
    CatalogSourcesSessionCache.writeTorrents(_catalogCacheKey, _results);
    _focusPlayingSourceIfNeeded();
    _requestScrollToCurrent();
  }

  void _mergeTorrentResults(List<TorrentResult> batch) {
    final byMagnet = <String, TorrentResult>{
      for (final r in _results) r.magnet: r,
    };
    for (final r in batch) {
      if (r.magnet.isEmpty) continue;
      final existing = byMagnet[r.magnet];
      if (existing == null || r.seedersCount > existing.seedersCount) {
        byMagnet[r.magnet] = r;
      }
    }
    _results = byMagnet.values.toList();
  }

  Future<void> _searchForjaMovieProgressive(
    int gen, {
    List<String>? enabledProviders,
    bool replace = true,
  }) async {
    final query = _year.isNotEmpty
        ? '${widget.movie.title} $_year'
        : widget.movie.title;
    var closed = false;
    var paintSeq = 0;
    final raw = await Engine.searchTorrentsProgressive(
      query,
      imdbId: widget.movie.imdbId,
      enabledProviders: enabledProviders,
      isCancelled: () => !mounted || gen != _searchGen || closed,
      onProviderDone: _onTorrentProviderDone(gen, hitsNeeded: 1),
      onPartial: (batch) {
        if (closed) return;
        final seq = ++paintSeq;
        unawaited(() async {
          if (!mounted || gen != _searchGen || closed) return;
          final filtered = (await Engine.filterTorrents(
            batch,
            widget.movie.title,
          )).map(TorrentResult.fromJson).toList();
          if (!mounted || gen != _searchGen || closed || seq != paintSeq) {
            return;
          }
          setState(() {
            if (replace) {
              _results = filtered;
            } else {
              _mergeTorrentResults(filtered);
            }
          });
        }());
      },
    );
    closed = true;
    if (!mounted || gen != _searchGen) return;
    final filtered = (await Engine.filterTorrents(
      raw,
      widget.movie.title,
    )).map(TorrentResult.fromJson).toList();
    if (!mounted || gen != _searchGen) return;
    setState(() {
      if (replace) {
        _results = filtered;
      } else {
        _mergeTorrentResults(filtered);
      }
    });
  }

  Future<void> _searchForjaTvProgressive(
    int gen, {
    required int season,
    required int episode,
    List<String>? enabledProviders,
    bool replace = true,
  }) async {
    final s = season.toString().padLeft(2, '0');
    final e = episode.toString().padLeft(2, '0');
    final seasonQuery = '${widget.movie.title} S$s';
    final episodeQuery = '${widget.movie.title} S${s}E$e';
    var closed = false;
    var paintSeq = 0;
    var seasonSoFar = <Map<String, dynamic>>[];
    var episodeSoFar = <Map<String, dynamic>>[];

    Future<void> paint(int seq) async {
      if (!mounted || gen != _searchGen || closed) return;
      final episodeFiltered = (await Engine.filterTorrents(
        episodeSoFar,
        widget.movie.title,
        requiredSeason: season,
        requiredEpisode: episode,
      )).map(TorrentResult.fromJson);
      if (!mounted || gen != _searchGen || closed || seq != paintSeq) return;
      final seasonFiltered = (await Engine.filterTorrents(
        seasonSoFar,
        widget.movie.title,
        requiredSeason: season,
      )).map(TorrentResult.fromJson);
      if (!mounted || gen != _searchGen || closed || seq != paintSeq) return;
      final combined = <String, TorrentResult>{};
      for (final r in episodeFiltered) {
        combined[r.magnet] = r;
      }
      for (final r in seasonFiltered) {
        combined.putIfAbsent(r.magnet, () => r);
      }
      setState(() {
        if (replace) {
          _results = combined.values.toList();
        } else {
          _mergeTorrentResults(combined.values.toList());
        }
      });
    }

    final onDone = _onTorrentProviderDone(gen, hitsNeeded: 2);
    await Future.wait([
      Engine.searchTorrentsProgressive(
        seasonQuery,
        imdbId: widget.movie.imdbId,
        season: season,
        enabledProviders: enabledProviders,
        isCancelled: () => !mounted || gen != _searchGen || closed,
        onProviderDone: onDone,
        onPartial: (batch) {
          if (closed) return;
          seasonSoFar = batch;
          unawaited(paint(++paintSeq));
        },
      ),
      Engine.searchTorrentsProgressive(
        episodeQuery,
        imdbId: widget.movie.imdbId,
        season: season,
        episode: episode,
        enabledProviders: enabledProviders,
        isCancelled: () => !mounted || gen != _searchGen || closed,
        onProviderDone: onDone,
        onPartial: (batch) {
          if (closed) return;
          episodeSoFar = batch;
          unawaited(paint(++paintSeq));
        },
      ),
    ]);
    closed = true;
    if (!mounted || gen != _searchGen) return;
    final episodeFiltered = (await Engine.filterTorrents(
      episodeSoFar,
      widget.movie.title,
      requiredSeason: season,
      requiredEpisode: episode,
    )).map(TorrentResult.fromJson);
    if (!mounted || gen != _searchGen) return;
    final seasonFiltered = (await Engine.filterTorrents(
      seasonSoFar,
      widget.movie.title,
      requiredSeason: season,
    )).map(TorrentResult.fromJson);
    if (!mounted || gen != _searchGen) return;
    final combined = <String, TorrentResult>{};
    for (final r in episodeFiltered) {
      combined[r.magnet] = r;
    }
    for (final r in seasonFiltered) {
      combined.putIfAbsent(r.magnet, () => r);
    }
    setState(() {
      if (replace) {
        _results = combined.values.toList();
      } else {
        _mergeTorrentResults(combined.values.toList());
      }
    });
  }

  Future<void> _fetchStremioStreams({
    bool reset = false,
    bool refresh = false,
  }) async {
    if (!_showsStremio) return;
    if (_streamAddons.isEmpty) return;
    final imdb = widget.movie.imdbId ?? '';
    if (imdb.isEmpty) {
      setState(() {
        _stremioFetching = false;
        if (!_showsTorrents) _error = 'No IMDb id for Stremio streams';
      });
      return;
    }

    Map<String, dynamic>? addon;
    for (final a in _streamAddons) {
      if (a['baseUrl'] == _selectedSourceId) {
        addon = a;
        break;
      }
    }
    addon ??= _streamAddons.first;
    final baseUrl = addon['baseUrl'] as String;
    final addonName = addon['name'] ?? 'Unknown';

    if (_stremioFetching && !reset && !refresh) {
      _stremioGen++;
      _stremioFetching = false;
    }

    if (!reset && !refresh && _completedAddonBaseUrls.contains(baseUrl)) {
      setState(() => _syncStremioProviderSelection());
      return;
    }

    final gen = ++_stremioGen;
    setState(() {
      _stremioFetching = true;
      _error = null;
      if (reset) {
        _stremioStreams = [];
        _loadedAddonBaseUrls.clear();
        _completedAddonBaseUrls.clear();
      } else if (refresh) {
        _completedAddonBaseUrls.remove(baseUrl);
        _loadedAddonBaseUrls.remove(baseUrl);
      }
    });

    var stremioId = imdb;
    if (widget.movie.mediaType == 'tv') {
      stremioId = '$imdb:${widget.season ?? 1}:${widget.episode ?? 1}';
    }
    final type = widget.movie.mediaType == 'tv' ? 'series' : 'movie';
    try {
      final streams = await _stremio.getStreams(
        baseUrl: baseUrl,
        type: type,
        id: stremioId,
      );
      if (!mounted || gen != _stremioGen) return;
      final tagged = filterStremioStreamsForProfile(
        streams.map((s) {
          if (s is Map<String, dynamic>) {
            return <String, dynamic>{
              ...s,
              '_addonName': addonName,
              '_addonBaseUrl': baseUrl,
            };
          }
          return <String, dynamic>{
            '_addonName': addonName,
            '_addonBaseUrl': baseUrl,
          };
        }).toList(),
        _profile,
      );
      setState(() {
        _completedAddonBaseUrls.add(baseUrl);
        if (tagged.isNotEmpty) _loadedAddonBaseUrls.add(baseUrl);
        _stremioStreams.removeWhere((s) => s['_addonBaseUrl'] == baseUrl);
        _stremioStreams.addAll(tagged);
        _stremioFetching = false;
        _syncStremioProviderSelection();
      });
      CatalogSourcesSessionCache.writeStremio(
        _catalogCacheKey,
        _stremioStreams,
      );
      if (tagged.isNotEmpty) {
        _focusPlayingSourceIfNeeded();
        _requestScrollToCurrent();
      }
    } catch (_) {
      if (!mounted || gen != _stremioGen) return;
      setState(() {
        _completedAddonBaseUrls.add(baseUrl);
        _stremioFetching = false;
        _syncStremioProviderSelection();
        if (_stremioStreams.isEmpty && !_showsTorrents) {
          _error = 'No streams found in $addonName';
        }
      });
    }
  }

  List<String> get _orderedNuvioScraperIds => [
    for (final addon in _nuvioAddons)
      for (final scraper in addon.scrapers)
        if (scraper.enabled) scraper.id,
  ];

  List<String> get _pendingNuvioScraperIds => [
    for (final id in _orderedNuvioScraperIds)
      if (_nuvioSelectedScraperIds.contains(id) &&
          !_nuvioFetchedScraperIds.contains(id))
        id,
  ];

  bool get _nuvioWorkActive =>
      _nuvioFetching ||
      _nuvioInFlightScraperIds.isNotEmpty ||
      _nuvioPoolTasks.isNotEmpty;

  void _nuvioAbortWork({bool clearFetched = false}) {
    _nuvioFetchGen++;
    _nuvioFetching = false;
    _nuvioInFlightScraperIds.clear();
    _nuvioPoolTasks.clear();
    _nuvioDiscardScraperIds.clear();
    DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
    if (clearFetched) _nuvioFetchedScraperIds.clear();
  }

  Future<void> _runAndApplyNuvioScraper({
    required String scraperId,
    required String type,
    required int gen,
  }) async {
    NuvioScraperResult? batch;
    try {
      batch = await NuvioService.instance.runSourcesScraper(
        scraperId: scraperId,
        tmdbId: widget.movie.id.toString(),
        type: type,
        season: widget.movie.mediaType == 'tv' ? widget.season : null,
        episode: widget.movie.mediaType == 'tv' ? widget.episode : null,
      );
    } catch (e) {
      debugPrint('[Nuvio] scraper $scraperId failed: $e');
    }
    if (!mounted || gen != _nuvioFetchGen) return;
    if (_nuvioDiscardScraperIds.remove(scraperId)) {
      if (mounted) {
        setState(() => _nuvioInFlightScraperIds.remove(scraperId));
      }
      return;
    }
    if (!_nuvioSelectedScraperIds.contains(scraperId)) return;
    setState(() {
      _nuvioFetchedScraperIds.add(scraperId);
      _nuvioStreams.removeWhere(
        (s) => nuvioStreamBelongsToScraper(s, scraperId),
      );
      if (batch != null && batch.streams.isNotEmpty) {
        final result = batch;
        _nuvioStreams.addAll(
          result.streams.map(
            (s) => <String, dynamic>{
              ...s,
              '_nuvioScraperId': result.scraperId,
              '_addonName': s['sourceName'] ?? result.scraperName,
              '_addonBaseUrl': 'nuvio:${result.scraperId}',
            },
          ),
        );
      }
    });
    CatalogSourcesSessionCache.writeNuvio(
      _catalogCacheKey,
      _nuvioStreams,
      fetchedScraperIds: _nuvioFetchedScraperIds,
    );
    _focusPlayingSourceIfNeeded();
    _requestScrollToCurrent();
  }

  void _nuvioFillPool({required int gen, required String type}) {
    if (!mounted || gen != _nuvioFetchGen) return;
    final slots = _nuvioPoolLimit - _nuvioInFlightScraperIds.length;
    if (slots <= 0) return;
    final next = nextNuvioScraperBatch(
      orderedIds: _orderedNuvioScraperIds,
      selectedIds: _nuvioSelectedScraperIds,
      fetchedIds: {..._nuvioFetchedScraperIds, ..._nuvioInFlightScraperIds},
      limit: slots,
    );
    for (final id in next) {
      _nuvioStartScraper(scraperId: id, type: type, gen: gen);
    }
  }

  void _nuvioStartScraper({
    required String scraperId,
    required String type,
    required int gen,
  }) {
    if (!mounted || gen != _nuvioFetchGen) return;
    if (_nuvioInFlightScraperIds.contains(scraperId) ||
        _nuvioFetchedScraperIds.contains(scraperId)) {
      return;
    }
    setState(() => _nuvioInFlightScraperIds.add(scraperId));
    late final Future<void> task;
    task = () async {
      try {
        await _runAndApplyNuvioScraper(
          scraperId: scraperId,
          type: type,
          gen: gen,
        );
      } finally {
        _nuvioPoolTasks.remove(task);
        if (!mounted || gen != _nuvioFetchGen) return;
        setState(() => _nuvioInFlightScraperIds.remove(scraperId));
        _nuvioFillPool(gen: gen, type: type);
      }
    }();
    _nuvioPoolTasks.add(task);
  }

  Future<void> _nuvioDrainPool({required int gen, required String type}) async {
    while (mounted && gen == _nuvioFetchGen) {
      while (_nuvioPoolTasks.isNotEmpty && mounted && gen == _nuvioFetchGen) {
        await Future.wait(List<Future<void>>.of(_nuvioPoolTasks));
      }
      if (!mounted || gen != _nuvioFetchGen) return;
      if (_pendingNuvioScraperIds.isEmpty) break;
      _nuvioFillPool(gen: gen, type: type);
      if (_nuvioPoolTasks.isEmpty) break;
    }
  }

  Future<void> _fetchNextNuvioScraper({
    bool reset = false,
    bool refresh = false,
  }) async {
    if (_nuvioAddons.isEmpty || widget.movie.id <= 0) return;
    final type = widget.movie.mediaType == 'tv' ? 'tv' : 'movie';
    if (_nuvioFetching && !reset && !refresh) {
      if (_nuvioPoolTasks.isNotEmpty || _pendingNuvioScraperIds.isEmpty) {
        _nuvioFillPool(gen: _nuvioFetchGen, type: type);
        return;
      }
      refresh = true;
    }
    if (reset || refresh) {
      DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
      _nuvioPoolTasks.clear();
    }
    final gen = ++_nuvioFetchGen;
    _nuvioPoolLimit = nuvioSourcesBatchLimit(tv: SourcesPanelTv.isTv(context));
    setState(() {
      _nuvioFetching = true;
      if (reset) {
        _nuvioStreams = [];
        _nuvioFetchedScraperIds = {};
        _nuvioInFlightScraperIds.clear();
      } else if (refresh) {
        _nuvioFetchedScraperIds.removeAll(_nuvioSelectedScraperIds);
        _nuvioInFlightScraperIds.clear();
      }
      _error = null;
    });
    _nuvioFillPool(gen: gen, type: type);
    await _nuvioDrainPool(gen: gen, type: type);
    if (!mounted || gen != _nuvioFetchGen) return;
    final stillPending = _pendingNuvioScraperIds.isNotEmpty;
    setState(() {
      _nuvioFetching = stillPending;
      if (!stillPending) _nuvioInFlightScraperIds.clear();
      if (!stillPending && _nuvioStreams.isEmpty) {
        _error = 'No streams found from selected Nuvio providers';
      }
    });
  }

  List<String> get _orderedEnginePluginIds =>
      orderedEnginePluginIds(_enginePacks);

  List<String> get _pendingEnginePluginIds => [
    for (final id in _orderedEnginePluginIds)
      if (_engineSelectedPluginIds.contains(id) &&
          !_engineFetchedPluginIds.contains(id))
        id,
  ];

  bool get _engineWorkActive =>
      _engineFetching ||
      _engineInFlightPluginIds.isNotEmpty ||
      _enginePoolTasks.isNotEmpty;

  Set<String> get _engineLoadingPluginIds {
    if (!_engineWorkActive) return const {};
    return {
      for (final id in _engineSelectedPluginIds)
        if (!_engineFetchedPluginIds.contains(id)) id,
    };
  }

  void _engineAbortWork({bool clearFetched = false}) {
    _engineFetchGen++;
    _engineFetching = false;
    _engineInFlightPluginIds.clear();
    _enginePoolTasks.clear();
    _engineDiscardPluginIds.clear();
    EngineService.instance.cancelPending();
    if (clearFetched) _engineFetchedPluginIds.clear();
  }

  Future<void> _runAndApplyEnginePlugin({
    required String pluginId,
    required String type,
    required int gen,
  }) async {
    EngineExtractResult? batch;
    try {
      batch = await EngineService.instance.runPluginIsolated(
        pluginId: pluginId,
        tmdbId: widget.movie.id.toString(),
        type: type,
        season: _engineNeedsEpisode ? widget.season : null,
        episode: _engineNeedsEpisode ? widget.episode : null,
        title: widget.movie.title,
        year: _year,
        movie: widget.movie,
        malId: widget.malId,
        anilistId: widget.anilistId,
        kisskhId: widget.kisskhId,
        kisskhEpisodeId: widget.kisskhEpisodeId,
        allowHostFallback: false,
      );
    } catch (e) {
      debugPrint('[engine] plugin $pluginId failed: $e');
    }
    if (!mounted || gen != _engineFetchGen) {
      if (mounted) {
        setState(() => _engineInFlightPluginIds.remove(pluginId));
      } else {
        _engineInFlightPluginIds.remove(pluginId);
      }
      return;
    }
    if (_engineDiscardPluginIds.remove(pluginId)) {
      if (mounted) {
        setState(() => _engineInFlightPluginIds.remove(pluginId));
      }
      return;
    }
    if (!_engineSelectedPluginIds.contains(pluginId)) {
      setState(() => _engineInFlightPluginIds.remove(pluginId));
      return;
    }
    setState(() {
      _engineFetchedPluginIds.add(pluginId);
      _engineInFlightPluginIds.remove(pluginId);
      _engineStreams.removeWhere(
        (s) => engineStreamBelongsToPlugin(s, pluginId),
      );
      if (batch != null && batch.streams.isNotEmpty) {
        _engineStreams.addAll(batch.streams);
      }
    });
    CatalogSourcesSessionCache.writeEngine(
      _catalogCacheKey,
      _engineStreams,
      fetchedPluginIds: _engineFetchedPluginIds,
    );
    _focusPlayingSourceIfNeeded();
    _requestScrollToCurrent();
  }

  void _engineFillPool({required int gen, required String type}) {
    if (!mounted || gen != _engineFetchGen) return;
    final slots = _enginePoolLimit - _engineInFlightPluginIds.length;
    if (slots <= 0) return;
    final next = nextEnginePluginBatch(
      orderedIds: _orderedEnginePluginIds,
      selectedIds: _engineSelectedPluginIds,
      fetchedIds: {..._engineFetchedPluginIds, ..._engineInFlightPluginIds},
      limit: slots,
    );
    if (next.isEmpty) return;
    final started = <String>[];
    setState(() {
      for (final id in next) {
        if (_engineInFlightPluginIds.contains(id) ||
            _engineFetchedPluginIds.contains(id)) {
          continue;
        }
        _engineInFlightPluginIds.add(id);
        started.add(id);
      }
    });
    for (final id in started) {
      _engineLaunchPlugin(pluginId: id, type: type, gen: gen);
    }
  }

  void _engineLaunchPlugin({
    required String pluginId,
    required String type,
    required int gen,
  }) {
    late final Future<void> task;
    task = () async {
      try {
        await _runAndApplyEnginePlugin(
          pluginId: pluginId,
          type: type,
          gen: gen,
        );
      } finally {
        _enginePoolTasks.remove(task);
        if (!mounted || gen != _engineFetchGen) return;
        setState(() => _engineInFlightPluginIds.remove(pluginId));
        _engineFillPool(gen: gen, type: type);
      }
    }();
    _enginePoolTasks.add(task);
  }

  Future<void> _engineDrainPool({required int gen, required String type}) async {
    while (mounted && gen == _engineFetchGen) {
      while (_enginePoolTasks.isNotEmpty && mounted && gen == _engineFetchGen) {
        await Future.wait(List<Future<void>>.of(_enginePoolTasks));
      }
      if (!mounted || gen != _engineFetchGen) return;
      if (_pendingEnginePluginIds.isEmpty) break;
      _engineFillPool(gen: gen, type: type);
      if (_enginePoolTasks.isEmpty) {
        break;
      }
    }
  }

  Future<void> _fetchNextEnginePlugin({
    bool reset = false,
    bool refresh = false,
  }) async {
    if (_enginePacks.isEmpty || widget.movie.id <= 0) return;
    final type = _engineResolveType;
    if (_engineFetching && !reset && !refresh) {
      if (_enginePoolTasks.isNotEmpty || _pendingEnginePluginIds.isEmpty) {
        _engineFillPool(gen: _engineFetchGen, type: type);
        return;
      }
      refresh = true;
    }
    if (reset || refresh) {
      EngineService.instance.cancelPending();
      _enginePoolTasks.clear();
    }
    _engineFetching = true;
    final gen = ++_engineFetchGen;
    _enginePoolLimit = engineSourcesBatchLimit(
      tv: SourcesPanelTv.isTv(context),
    );
    setState(() {
      if (reset) {
        _engineStreams = [];
        _engineFetchedPluginIds = {};
        _engineInFlightPluginIds.clear();
      } else if (refresh) {
        _engineFetchedPluginIds.removeAll(_engineSelectedPluginIds);
        _engineInFlightPluginIds.clear();
      }
      _error = null;
    });
    _engineFillPool(gen: gen, type: type);
    await _engineDrainPool(gen: gen, type: type);
    if (!mounted || gen != _engineFetchGen) return;
    final stillPending = _pendingEnginePluginIds.isNotEmpty;
    setState(() {
      _engineFetching = stillPending;
      if (!stillPending) _engineInFlightPluginIds.clear();
      if (!stillPending && _engineStreams.isEmpty) {
        _error = 'No streams found from selected Forja plugins';
      }
    });
  }

  void _onKindChanged(String kind) {
    if (kind == _kindFilter) return;
    _userPickedKind = true;
    setState(() {
      _abortHiddenKindFetches(kind);
      _kindFilter = kind;
      _qualityFilters = {};
      _languageFilters = {};
      _techFilters = {};
      _audioFilters = {};
      _sizeFilters = {};
      _searchQuery = '';
      if (kind == 'stremio') {
        _userPickedStremioProvider = false;
        _selectedSourceId =
            _preferredStremioAddonBaseUrl() ?? _defaultStremioSourceId();
        _syncStremioProviderSelection();
      } else if (kind == 'nuvio') {
        _selectedSourceId = 'all_nuvio';
        _selectPlayingProviderIfNeeded();
      } else if (kind == 'engine') {
        _selectedSourceId = 'all_engine';
        _selectPlayingProviderIfNeeded();
      } else if (kind == 'torrents') {
        _selectedSourceId = TorrentSearchProviders.defaultChipId(
          _enabledTorrentProviders,
        );
      }
    });
    _resetListScroll(allowScrollToCurrent: true);
    _ensureVisibleKindsLoaded();
  }

  String get _year {
    final d = widget.movie.releaseDate;
    return d.length >= 4 ? d.substring(0, 4) : '';
  }

  Future<List<TorrentResult>> _searchJackett({
    required bool isTv,
    required int season,
    required int episode,
  }) async {
    final baseUrl = await _settings.getJackettBaseUrl();
    final apiKey = await _settings.getJackettApiKey();
    if (baseUrl == null || apiKey == null) {
      throw Exception('Jackett is not configured');
    }
    final jackett = JackettService();
    if (isTv) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      final results = await Future.wait([
        jackett.search(baseUrl, apiKey, '${widget.movie.title} S$s'),
        jackett.search(baseUrl, apiKey, '${widget.movie.title} S${s}E$e'),
      ]);
      final combined = <String, TorrentResult>{};
      final seasonFiltered = (await Engine.filterTorrents(
        results[0].map((r) => r.toJson()).toList(),
        widget.movie.title,
        requiredSeason: season,
      )).map(TorrentResult.fromJson);
      final episodeFiltered = (await Engine.filterTorrents(
        results[1].map((r) => r.toJson()).toList(),
        widget.movie.title,
        requiredSeason: season,
        requiredEpisode: episode,
      )).map(TorrentResult.fromJson);
      for (final r in episodeFiltered) {
        combined[r.magnet] = r;
      }
      for (final r in seasonFiltered) {
        combined[r.magnet] = r;
      }
      return combined.values.toList();
    }

    final query = _year.isNotEmpty
        ? '${widget.movie.title} $_year'
        : widget.movie.title;
    final results = await jackett.search(baseUrl, apiKey, query);
    return (await Engine.filterTorrents(
      results.map((r) => r.toJson()).toList(),
      widget.movie.title,
    )).map(TorrentResult.fromJson).toList();
  }

  Future<List<TorrentResult>> _searchProwlarr({
    required bool isTv,
    required int season,
    required int episode,
  }) async {
    final baseUrl = await _settings.getProwlarrBaseUrl();
    final apiKey = await _settings.getProwlarrApiKey();
    if (baseUrl == null || apiKey == null) {
      throw Exception('Prowlarr is not configured');
    }
    final prowlarr = ProwlarrService();
    List<int>? indexerIds;
    final tagIds = await _settings.getProwlarrTagIds();
    if (tagIds.isNotEmpty) {
      final resolved = await prowlarr.resolveTagIndexerIds(
        baseUrl,
        apiKey,
        tagIds,
      );
      if (resolved.isNotEmpty) indexerIds = resolved;
    }

    if (isTv) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      final results = await Future.wait([
        prowlarr.search(
          baseUrl,
          apiKey,
          '${widget.movie.title} S$s',
          indexerIds: indexerIds,
        ),
        prowlarr.search(
          baseUrl,
          apiKey,
          '${widget.movie.title} S${s}E$e',
          indexerIds: indexerIds,
        ),
      ]);
      final combined = <String, TorrentResult>{};
      final seasonFiltered = (await Engine.filterTorrents(
        results[0].map((r) => r.toJson()).toList(),
        widget.movie.title,
        requiredSeason: season,
      )).map(TorrentResult.fromJson);
      final episodeFiltered = (await Engine.filterTorrents(
        results[1].map((r) => r.toJson()).toList(),
        widget.movie.title,
        requiredSeason: season,
        requiredEpisode: episode,
      )).map(TorrentResult.fromJson);
      for (final r in episodeFiltered) {
        combined[r.magnet] = r;
      }
      for (final r in seasonFiltered) {
        combined[r.magnet] = r;
      }
      return combined.values.toList();
    }

    final query = _year.isNotEmpty
        ? '${widget.movie.title} $_year'
        : widget.movie.title;
    final results = await prowlarr.search(
      baseUrl,
      apiKey,
      query,
      indexerIds: indexerIds,
    );
    return (await Engine.filterTorrents(
      results.map((r) => r.toJson()).toList(),
      widget.movie.title,
    )).map(TorrentResult.fromJson).toList();
  }

  bool _nuvioStreamFromScraper(Map<String, dynamic> s, String scraperId) {
    final id = s['_nuvioScraperId'] as String?;
    if (id != null) return id == scraperId;
    final base = s['_addonBaseUrl'] as String?;
    return base == 'nuvio:$scraperId';
  }

  /// Chip loading ✕ — soft-cancel that provider without killing sibling jobs.
  void _onChipCancel(String id) {
    if (id == 'all_engine' || id.startsWith('engine:')) {
      final ids = id == 'all_engine'
          ? Set<String>.from(_engineLoadingPluginIds)
          : {id.substring('engine:'.length)};
      if (ids.isEmpty) return;
      setState(() {
        for (final pluginId in ids) {
          _engineDiscardPluginIds.add(pluginId);
          _engineInFlightPluginIds.remove(pluginId);
          _engineFetchedPluginIds.add(pluginId);
        }
        if (_pendingEnginePluginIds.isEmpty &&
            _engineInFlightPluginIds.isEmpty) {
          _engineFetching = false;
        }
      });
      CatalogSourcesSessionCache.writeEngine(
        _catalogCacheKey,
        _engineStreams,
        fetchedPluginIds: _engineFetchedPluginIds,
      );
      if (_pendingEnginePluginIds.isNotEmpty) {
        unawaited(_fetchNextEnginePlugin());
      }
      return;
    }
    if (id == 'all_nuvio' || id.startsWith('nuvio:')) {
      final ids = id == 'all_nuvio'
          ? {
              for (final s in _nuvioSelectedScraperIds)
                if (!_nuvioFetchedScraperIds.contains(s)) s,
            }
          : {id.substring('nuvio:'.length)};
      if (ids.isEmpty) return;
      setState(() {
        for (final scraperId in ids) {
          _nuvioDiscardScraperIds.add(scraperId);
          _nuvioInFlightScraperIds.remove(scraperId);
          _nuvioFetchedScraperIds.add(scraperId);
        }
        if (_pendingNuvioScraperIds.isEmpty &&
            _nuvioInFlightScraperIds.isEmpty) {
          _nuvioFetching = false;
        }
      });
      CatalogSourcesSessionCache.writeNuvio(
        _catalogCacheKey,
        _nuvioStreams,
        fetchedScraperIds: _nuvioFetchedScraperIds,
      );
      if (_pendingNuvioScraperIds.isNotEmpty) {
        unawaited(_fetchNextNuvioScraper());
      }
      return;
    }
    if (_kindFilter == 'stremio') {
      _stremioGen++;
      setState(() => _stremioFetching = false);
      return;
    }
    if (_kindFilter == 'torrents') {
      setState(() {
        _torrentInFlightProviderIds.remove(id);
        _torrentFetchedProviderIds.add(id);
        if (_torrentInFlightProviderIds.isEmpty) _searching = false;
      });
    }
  }

  /// Chip refresh — re-run that provider only (kind-tab parity).
  void _onChipReload(String id) {
    if (id == 'all_engine') {
      unawaited(_ensureEngineLoaded(force: true));
      return;
    }
    if (id.startsWith('engine:')) {
      final pluginId = id.substring('engine:'.length);
      setState(() {
        _engineDiscardPluginIds.remove(pluginId);
        _engineFetchedPluginIds.remove(pluginId);
        _engineStreams = _engineStreams
            .where((s) => !engineStreamBelongsToPlugin(s, pluginId))
            .toList();
        _error = null;
      });
      CatalogSourcesSessionCache.writeEngine(
        _catalogCacheKey,
        _engineStreams,
        fetchedPluginIds: _engineFetchedPluginIds,
      );
      unawaited(_fetchNextEnginePlugin());
      return;
    }
    if (id == 'all_nuvio') {
      unawaited(_ensureNuvioLoaded(force: true));
      return;
    }
    if (id.startsWith('nuvio:')) {
      final scraperId = id.substring('nuvio:'.length);
      setState(() {
        _nuvioDiscardScraperIds.remove(scraperId);
        _nuvioFetchedScraperIds.remove(scraperId);
        _nuvioStreams = _nuvioStreams
            .where((s) => !_nuvioStreamFromScraper(s, scraperId))
            .toList();
        _error = null;
      });
      CatalogSourcesSessionCache.writeNuvio(
        _catalogCacheKey,
        _nuvioStreams,
        fetchedScraperIds: _nuvioFetchedScraperIds,
      );
      unawaited(_fetchNextNuvioScraper());
      return;
    }
    if (_kindFilter == 'stremio') {
      unawaited(_fetchStremioStreams(refresh: true));
      return;
    }
    if (_kindFilter == 'torrents') {
      setState(() {
        _torrentFetchedProviderIds.remove(id);
        if (TorrentSearchProviders.isAllChip(_selectedSourceId) ||
            _selectedSourceId == id) {
          // keep selection
        } else {
          _selectedSourceId = id;
        }
      });
      unawaited(_runTorrentSearch(force: true));
    }
  }

  void _onChipTap(String id) {
    _resetListScroll();
    if (id == 'all_nuvio') {
      final enabled = enabledNuvioScraperIds(_nuvioAddons);
      if (enabled.isEmpty) return;
      final next = nextNuvioSelectedAfterAllTap(
        selectedIds: _nuvioSelectedScraperIds,
        enabledIds: enabled,
      );
      final clearing = next.isEmpty;
      setState(() {
        _selectedSourceId = 'all_nuvio';
        _error = null;
        _nuvioSelectedScraperIds = next;
        if (clearing) {
          _nuvioAbortWork(clearFetched: true);
        }
      });
      unawaited(NuvioService.instance.saveSourcesSelectedScraperIds(next));
      if (!clearing) {
        unawaited(_fetchNextNuvioScraper());
      }
      return;
    }
    if (id.startsWith('nuvio:')) {
      final scraperId = id.substring('nuvio:'.length);
      final wasSelected = _nuvioSelectedScraperIds.contains(scraperId);
      final fetched = _nuvioFetchedScraperIds.contains(scraperId);
      if (wasSelected &&
          !fetched &&
          !_nuvioInFlightScraperIds.contains(scraperId)) {
        unawaited(_fetchNextNuvioScraper());
        return;
      }
      setState(() {
        _selectedSourceId = 'all_nuvio';
        _error = null;
        if (wasSelected) {
          _nuvioSelectedScraperIds = Set<String>.from(_nuvioSelectedScraperIds)
            ..remove(scraperId);
          _nuvioStreams = _nuvioStreams
              .whereType<Map<String, dynamic>>()
              .where((s) => !_nuvioStreamFromScraper(s, scraperId))
              .toList();
          _nuvioFetchedScraperIds = Set<String>.from(_nuvioFetchedScraperIds)
            ..remove(scraperId);
          _nuvioInFlightScraperIds.remove(scraperId);
          if (_nuvioSelectedScraperIds.isEmpty) {
            _nuvioAbortWork(clearFetched: true);
          }
        } else {
          _nuvioSelectedScraperIds = {..._nuvioSelectedScraperIds, scraperId};
          _nuvioFetchedScraperIds = Set<String>.from(_nuvioFetchedScraperIds)
            ..remove(scraperId);
        }
      });
      CatalogSourcesSessionCache.writeNuvio(
        _catalogCacheKey,
        _nuvioStreams,
        fetchedScraperIds: _nuvioFetchedScraperIds,
      );
      unawaited(
        NuvioService.instance.saveSourcesSelectedScraperIds(
          _nuvioSelectedScraperIds,
        ),
      );
      if (!wasSelected) {
        unawaited(_fetchNextNuvioScraper());
      }
      return;
    }
    if (id == 'all_engine') {
      final cats = _effectiveEngineCategories;
      final visible = <String>{
        for (final a in _enginePacks)
          for (final s in a.plugins)
            if (EngineCategories.pluginChipVisible(
              plugin: s,
              visibleCategories: cats,
              selectedPluginIds: _engineSelectedPluginIds,
            ))
              s.id,
      };
      if (visible.isEmpty) return;
      final prev = _engineSelectedPluginIds;
      final next = nextEngineSelectedAfterAllTap(
        selectedIds: prev,
        enabledIds: visible,
      );
      final clearing = next.isEmpty;
      final refetch = clearing
          ? const <String>{}
          : enginePluginIdsToRefetchOnAllExpand(
              previousSelectedIds: prev,
              nextSelectedIds: next,
              fetchedIds: _engineFetchedPluginIds,
              streams: _engineStreams,
            );
      setState(() {
        _selectedSourceId = 'all_engine';
        _error = null;
        _engineSelectedPluginIds = next;
        if (refetch.isNotEmpty) {
          _engineFetchedPluginIds = Set<String>.from(_engineFetchedPluginIds)
            ..removeAll(refetch);
        }
        if (clearing) {
          _engineAbortWork(clearFetched: true);
          DomainStreamProviderResolver.cancelAllPending(
            cancelEngineJobs: false,
          );
        }
      });
      unawaited(
        EngineService.instance.saveSourcesSelectedPluginIds(
          next,
          panelCategory: _enginePanelCategory,
        ),
      );
      if (!clearing) {
        unawaited(_fetchNextEnginePlugin());
      }
      return;
    }
    if (id.startsWith('engine:')) {
      final pluginId = id.substring('engine:'.length);
      final wasSelected = _engineSelectedPluginIds.contains(pluginId);
      final fetched = _engineFetchedPluginIds.contains(pluginId);
      if (wasSelected &&
          !fetched &&
          !_engineInFlightPluginIds.contains(pluginId)) {
        unawaited(_fetchNextEnginePlugin());
        return;
      }
      setState(() {
        _selectedSourceId = 'all_engine';
        _error = null;
        if (wasSelected) {
          _engineSelectedPluginIds = Set<String>.from(_engineSelectedPluginIds)
            ..remove(pluginId);
          _engineStreams = _engineStreams
              .where((s) => s['_enginePluginId'] != pluginId)
              .toList();
          _engineFetchedPluginIds = Set<String>.from(_engineFetchedPluginIds)
            ..remove(pluginId);
          _engineInFlightPluginIds.remove(pluginId);
          if (_engineSelectedPluginIds.isEmpty) {
            _engineAbortWork(clearFetched: true);
          }
        } else {
          _engineSelectedPluginIds = {..._engineSelectedPluginIds, pluginId};
          _engineFetchedPluginIds = Set<String>.from(_engineFetchedPluginIds)
            ..remove(pluginId);
        }
      });
      CatalogSourcesSessionCache.writeEngine(
        _catalogCacheKey,
        _engineStreams,
        fetchedPluginIds: _engineFetchedPluginIds,
      );
      unawaited(
        EngineService.instance.saveSourcesSelectedPluginIds(
          _engineSelectedPluginIds,
          panelCategory: _enginePanelCategory,
        ),
      );
      if (!wasSelected) {
        unawaited(_fetchNextEnginePlugin());
      }
      return;
    }
    if (id == TorrentSearchProviders.allId) {
      final prev = _selectedSourceId;
      final next = TorrentSearchProviders.nextIdAfterAllTap(prev);
      if (next == prev) return;
      setState(() => _selectedSourceId = next);
      _abortTorrentSearch();
      if (TorrentSearchProviders.isAllChip(next)) {
        unawaited(
          _runTorrentSearch(force: prev == 'jackett' || prev == 'prowlarr'),
        );
      }
      return;
    }
    if (id == _selectedSourceId) return;
    final prev = _selectedSourceId;
    setState(() {
      _selectedSourceId = id;
      if (_kindFilter == 'stremio') _userPickedStremioProvider = true;
      _qualityFilters = {};
      _languageFilters = {};
      _techFilters = {};
      _audioFilters = {};
      _sizeFilters = {};
      _searchQuery = '';
    });
    if (_kindFilter == 'stremio') {
      unawaited(_fetchStremioStreams());
    } else if (_kindFilter == 'torrents') {
      final toIndexer = id == 'jackett' || id == 'prowlarr';
      final fromIndexer = prev == 'jackett' || prev == 'prowlarr';
      if (toIndexer ||
          fromIndexer ||
          TorrentSearchProviders.isBuiltinSearchChip(id)) {
        _abortTorrentSearch();
        unawaited(_runTorrentSearch(force: fromIndexer || toIndexer));
      }
    }
  }

  Future<void> _selectTorrent(TorrentResult result) async {
    if (_isCurrentMagnet(result.magnet)) {
      widget.onClose();
      return;
    }
    // ATV: pair/offline dialog first. Do not dismiss or start local resolve.
    if (!await ensureLanP2pPlayback(context)) return;
    if (!mounted) return;
    // Close without cancelling engine jobs - resolve starts immediately and
    // dispose must not abort the new torrentStream (see [dismiss]).
    PlayerSourcesPanel.dismiss(cancelEngine: false);
    await widget.onTorrentSelected(result);
  }

  Future<void> _selectStremio(Map<String, dynamic> stream) async {
    if (_isCurrentStremio(stream)) {
      widget.onClose();
      return;
    }
    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    final debridService = await settings.getDebridService();
    if (!mounted) return;
    final precheck = classifyStremioStream(
      stream,
      PlatformPlayback.capabilities,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (precheck == null) {
      if (!await ensureLanP2pPlayback(context)) return;
      if (!mounted) return;
    }
    PlayerSourcesPanel.dismiss(cancelEngine: false);
    await widget.onStremioSelected(stream);
  }

  String? get _episodeLabel {
    if (widget.movie.mediaType != 'tv') return null;
    final s = (widget.season ?? 1).toString().padLeft(2, '0');
    final e = (widget.episode ?? 1).toString().padLeft(2, '0');
    return 'S${s}E$e';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerSourcesSessionProvider);
    ref.watch(playerResolveStatusProvider);
    final torrents = _showsTorrents ? _filteredTorrents : <TorrentResult>[];
    final stremio = _showsStremio
        ? _visibleStremioStreams
        : <Map<String, dynamic>>[];
    final nuvio = _showsNuvio ? _filteredNuvio : <Map<String, dynamic>>[];
    final engine = _showsEngine ? _filteredEngine : <Map<String, dynamic>>[];
    final totalCount =
        torrents.length + stremio.length + nuvio.length + engine.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TorrentSourcesPanelChrome(
          kindFilter: _kindFilter,
          showTorrents: _showTorrents,
          showStremio: _showStremio,
          showNuvio: _showNuvio,
          showEngine: _showEngine,
          onKindChanged: _onKindChanged,
          resultCount: totalCount,
          isFetching: _isFetching,
          onCancelFetch: () {
            _searchGen++;
            _stremioGen++;
            _nuvioFetchGen++;
            _engineFetchGen++;
            DomainStreamProviderResolver.cancelAllPending();
            EngineService.instance.cancelPending();
            DomainStreamProviderResolver.cancelAllPending(
              cancelEngineJobs: false,
            );
            setState(() {
              _searching = false;
              _torrentInFlightProviderIds.clear();
              _stremioFetching = false;
              _nuvioFetching = false;
              _nuvioInFlightScraperIds.clear();
              _nuvioPoolTasks.clear();
              _engineFetching = false;
              _engineInFlightPluginIds.clear();
              _enginePoolTasks.clear();
            });
          },
          providerOptions: _providerOptions,
          selectedSourceId: _selectedSourceId,
          nuvioSelectedScraperIds: _nuvioSelectedScraperIds,
          engineSelectedPluginIds: _engineSelectedPluginIds,
          loadingChipIds: _loadingChipIds,
          onProviderTap: _onChipTap,
          onProviderCancel: _onChipCancel,
          onProviderReload: _onChipReload,
          searchQuery: _searchQuery,
          onSearchChanged: (q) {
            setState(() => _searchQuery = q);
            _resetListScroll();
          },
          availableQualities: _availableQualities,
          availableLanguages: _availableLanguages,
          availableTech: _availableTech,
          availableSizeRanges: _availableSizes,
          activeQualityFilters: _qualityFilters,
          activeLanguageFilters: _languageFilters,
          activeTechFilters: _techFilters,
          activeSizeFilters: _sizeFilters,
          onQualityFiltersChanged: (v) => setState(() => _qualityFilters = v),
          onLanguageFiltersChanged: (v) => setState(() => _languageFilters = v),
          onTechFiltersChanged: (v) => setState(() => _techFilters = v),
          onSizeFiltersChanged: (v) => setState(() => _sizeFilters = v),
          showEngineCategories: _kindFilter == 'engine',
          engineVisibleCategories: _effectiveEngineCategories,
          engineCategoryMediaType: _enginePanelCategory,
          onEngineCategoriesChanged: (v) =>
              setState(() => _engineVisibleCategories = v),
          showAudioFilters: _showsTorrents,
          activeAudioFilters: _audioFilters,
          onAudioFiltersChanged: (v) => setState(() => _audioFilters = v),
          sortPreference: _showsTorrents ? _sortPreference : null,
          onSortChanged: _showsTorrents
              ? (val) {
                  setState(() => _sortPreference = val);
                  _settings.setSortPreference(val);
                }
              : null,
          showCacheLine: _showsTorrents && _localTorrentEngine,
          cacheRefreshToken: Object.hash(
            _openToken,
            _results.length,
            _searching,
          ),
          filterEnableBlur: false,
          onReloadKind: _reloadKind,
          sourcesPanelOpen: true,
          onFocusList: () {
            final cur =
                _currentItemIndex(
                  torrents,
                  stremio,
                  nuvio: nuvio,
                  engine: engine,
                ) ??
                0;
            final max = totalCount > 0 ? totalCount - 1 : 0;
            SourcesPanelTv.focusListItem(index: cur.clamp(0, max));
          },
        ),
        Expanded(
          child: _buildList(
            torrents,
            stremio,
            nuvio,
            engine,
            totalCount: totalCount,
          ),
        ),
        SourcesPanelMetaFooter(
          episodeLabel: _episodeLabel,
          resultCount: totalCount,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _visibleStremioStreams {
    final filtered = _filteredStremio;
    if (_kindFilter != 'stremio') return filtered;
    if (_selectedSourceId.isEmpty || _selectedSourceId == 'all_stremio') {
      return filtered;
    }
    return filtered
        .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
        .toList();
  }

  // Stable-ish token so cache line can refresh when panel content changes.
  int get _openToken => identityHashCode(this);

  Widget _buildList(
    List<TorrentResult> torrents,
    List<Map<String, dynamic>> stremio,
    List<Map<String, dynamic>> nuvio,
    List<Map<String, dynamic>> engine, {
    required int totalCount,
  }) {
    if (_isFetching && totalCount == 0) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }
    if (_error != null && totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _reloadKind(_kindFilter),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (totalCount == 0) {
      final emptyMsg =
          (_showsNuvio && _nuvioSelectedScraperIds.isEmpty) ||
              (_showsEngine && _engineSelectedPluginIds.isEmpty) ||
              (_showsTorrents &&
                  TorrentSearchProviders.isNoneChip(_selectedSourceId))
          ? 'Select at least one provider'
          : 'No matching sources';
      return Center(
        child: Text(
          emptyMsg,
          style: TextStyle(
            color: ForjaShellColors.cinematic.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    final showAddonName =
        _showsNuvio ||
        _showsEngine ||
        (_kindFilter == 'stremio' && _providerOptions.length > 1);

    if (!_isFetching) _scheduleScrollToCurrent();

    final currentIndex = _currentItemIndex(
      torrents,
      stremio,
      nuvio: nuvio,
      engine: engine,
    );

    final tv = SourcesPanelTv.isTv(context);
    final list = ListView.separated(
      controller: _listScrollController,
      primary: false,
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      itemCount: totalCount,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final tvIndex = tv ? i : null;
        final onUp = i == 0 ? SourcesPanelTv.focusProvidersItem : null;
        if (i < torrents.length) {
          final r = torrents[i];
          final isCurrent = i == currentIndex;
          return KeyedSubtree(
            key: ValueKey(r.magnet.isEmpty ? r.name : r.magnet),
            child: KeyedSubtree(
              key: isCurrent ? _currentTileKey : null,
              child: TorrentSourceTile(
                result: r,
                highlightStart: isCurrent,
                tvItemIndex: tvIndex,
                onUpEdge: onUp,
                onPlay: () => _selectTorrent(r),
              ),
            ),
          );
        }

        final j = i - torrents.length;
        final Map<String, dynamic> s;
        if (j < stremio.length) {
          s = stremio[j];
        } else if (j < stremio.length + nuvio.length) {
          s = nuvio[j - stremio.length];
        } else {
          s = engine[j - stremio.length - nuvio.length];
        }
        final title = (s['title'] ?? s['name'] ?? 'Unknown Stream').toString();
        final description = (s['description'] ?? '').toString();
        final presentation = stremioTilePresentation(s, isResumable: false);
        final isCurrent = i == currentIndex;
        return KeyedSubtree(
          key: _playerStreamTileKey(s),
          child: KeyedSubtree(
            key: isCurrent ? _currentTileKey : null,
            child: StremioSourceTile(
              title: title,
              description: description,
              leadingIcon: presentation.leadingIcon,
              leadingColor: presentation.leadingColor,
              isExternal: presentation.isExternal,
              addonName: s['_addonName']?.toString(),
              showAddonName: showAddonName,
              sizeText: s['size']?.toString(),
              seeders: s['seeders']?.toString() ?? s['seeds']?.toString(),
              stream: s,
              highlightStart: isCurrent,
              tvItemIndex: tvIndex,
              onUpEdge: onUp,
              onTap: () => _selectStremio(s),
            ),
          ),
        );
      },
    );

    if (!tv) return list;
    return TvCatalogRow(
      tabId: SourcesPanelTv.tabId,
      rowId: SourcesPanelTv.listRowId,
      sortOrder: SourcesPanelTv.listSort,
      itemCount: totalCount,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: SourcesPanelTv.focusProvidersItem,
      child: list,
    );
  }
}
