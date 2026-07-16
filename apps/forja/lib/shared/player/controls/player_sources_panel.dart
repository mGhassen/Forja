import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_filters.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel_chrome.dart';
import 'package:rust/rust.dart';

/// Right-side Sources panel in the player — same shell/chrome/tiles as
/// media-details Sources (torrent search list), not in-torrent file picker.
class PlayerSourcesPanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  /// Closes the Sources overlay.
  ///
  /// When [cancelEngine] is true (user closed the panel), abort in-flight
  /// Engine jobs (torrent search / Stremio HTTP). When false (user picked a
  /// source), stop scrapers/hosts only — the upcoming magnet resolve must not
  /// be cancelled. [dispose] must never cancel Engine jobs: it runs a frame
  /// after [dismiss] and would kill the fresh torrent job.
  static void dismiss({bool cancelEngine = true}) {
    DomainStreamProviderResolver.cancelAllPending(
      cancelEngineJobs: cancelEngine,
    );
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
  }

  static Future<void> show({
    required BuildContext context,
    required Movie movie,
    int? season,
    int? episode,
    String? currentMagnet,
    String? currentStreamUrl,

    /// `torrents` | `stremio` | `nuvio` — opens on the playing source kind.
    String? preferredKind,
    String? currentAddonBaseUrl,
    required Future<void> Function(TorrentResult result) onTorrentSelected,
    required Future<void> Function(Map<String, dynamic> stream)
    onStremioSelected,
  }) {
    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();
    playerChromeCancelSeekScrubs();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    // OverlayEntry is a sibling of the player route — not under ShellScope.
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
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
  final String? currentStreamUrl;
  final String? preferredKind;
  final String? currentAddonBaseUrl;
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
    return playerOverlayShell(
      context: context,
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      child: _PlayerSourcesBody(
        movie: widget.movie,
        season: widget.season,
        episode: widget.episode,
        currentMagnet: widget.currentMagnet,
        currentStreamUrl: widget.currentStreamUrl,
        preferredKind: widget.preferredKind,
        currentAddonBaseUrl: widget.currentAddonBaseUrl,
        onTorrentSelected: widget.onTorrentSelected,
        onStremioSelected: widget.onStremioSelected,
        onClose: widget.onClose,
      ),
    );
  }
}

class _PlayerSourcesBody extends StatefulWidget {
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
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
  final String? currentStreamUrl;
  final String? preferredKind;
  final String? currentAddonBaseUrl;
  final Future<void> Function(TorrentResult result) onTorrentSelected;
  final Future<void> Function(Map<String, dynamic> stream) onStremioSelected;
  final VoidCallback onClose;

  @override
  State<_PlayerSourcesBody> createState() => _PlayerSourcesBodyState();
}

class _PlayerSourcesBodyState extends State<_PlayerSourcesBody> {
  final _settings = SettingsService();
  final _stremio = StremioService();
  final _listScrollController = ScrollController();
  final _currentTileKey = GlobalKey();
  final _profile = PlatformPlayback.capabilities;

  List<TorrentResult> _results = [];
  List<Map<String, dynamic>> _stremioStreams = [];
  List<Map<String, dynamic>> _streamAddons = [];
  final Set<String> _loadedAddonBaseUrls = {};
  final Set<String> _completedAddonBaseUrls = {};

  List<Map<String, dynamic>> _nuvioStreams = [];
  List<NuvioAddon> _nuvioAddons = [];
  Set<String> _nuvioSelectedScraperIds = {};
  Set<String> _nuvioFetchedScraperIds = {};
  bool _nuvioFetching = false;
  int _nuvioFetchGen = 0;

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
  /// Once the user picks a Stremio addon in Filters → Providers, do not auto
  /// move off an empty/failed addon (Torrentio 403) onto one with results.
  bool _userPickedStremioProvider = false;

  bool _showTorrents = true;
  bool _showStremio = false;
  bool _showNuvio = false;
  String _kindFilter = 'torrents';
  String _selectedSourceId = 'forja';
  String _searchQuery = '';
  String _sortPreference = 'seeders';
  Set<String> _qualityFilters = {};
  Set<String> _languageFilters = {};
  Set<String> _techFilters = {};
  Set<String> _audioFilters = {};
  Set<String> _sizeFilters = {};

  bool _jackettConfigured = false;
  bool _prowlarrConfigured = false;
  bool _localTorrentEngine = true;

  bool get _showsTorrents => _kindFilter == 'torrents';
  bool get _showsStremio => _kindFilter == 'stremio';
  bool get _showsNuvio => _kindFilter == 'nuvio';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchGen++;
    _stremioGen++;
    _nuvioFetchGen++;
    // Shared cancel without Engine — [dismiss] already cancelled on user
    // close; on source pick, resolve starts before this dispose and must keep
    // its torrentStream job alive.
    DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
    _listScrollController.dispose();
    super.dispose();
  }

  static final _infoHashRe = RegExp(r'[0-9a-fA-F]{40}');

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
    }
    final current = _infoHashOf(widget.currentMagnet);
    if (current == null) return false;
    // Magnet-only session without a local stream URL yet — still Torrents.
    if (_isPlayingLocalTorrentMagnet()) return false;
    final hash = stream['infoHash']?.toString();
    if (hash != null && hash.isNotEmpty) {
      return _infoHashOf(hash) == current;
    }
    final url = stream['url']?.toString();
    return url != null && _isCurrentMagnet(url);
  }

  /// Single scroll target in merged lists — torrent row wins over Stremio when
  /// both share the same infoHash (Torrentio mirrors the active magnet).
  int? _currentItemIndex(
    List<TorrentResult> torrents,
    List<Map<String, dynamic>> stremio, {
    List<Map<String, dynamic>> nuvio = const [],
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
    return null;
  }

  void _requestScrollToCurrent() {
    _pendingScrollToCurrent = true;
    _scrollToCurrentAttempts = 0;
    _scheduleScrollToCurrent();
  }

  /// Playing Stremio addon baseUrl when known (caller + matched stream).
  String? _preferredStremioAddonBaseUrl([
    List<Map<String, dynamic>>? addons,
  ]) {
    final list = addons ?? _streamAddons;
    final base = widget.currentAddonBaseUrl;
    if (base != null &&
        base.isNotEmpty &&
        !base.startsWith('nuvio:') &&
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

  /// Move Filters → Providers off an empty addon when another has streams
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
      // Prefer the playing addon only when it already has rows — otherwise
      // [promoteStremioProviderId] keeps the list stuck on Torrentio 403.
      _syncStremioProviderSelection();
      return;
    }
    if (_kindFilter != 'nuvio') return;
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

      // Prefer precise ensureVisible when the tile is already mounted.
      final ctx = _currentTileKey.currentContext;
      if (ctx != null) {
        _pendingScrollToCurrent = false;
        _scrollToCurrentAttempts = 0;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      if (!_listScrollController.hasClients) return;

      final torrents =
          _showsTorrents ? _filteredTorrents : const <TorrentResult>[];
      final stremio = _showsStremio
          ? _visibleStremioStreams
          : const <Map<String, dynamic>>[];
      final nuvio =
          _showsNuvio ? _filteredNuvio : const <Map<String, dynamic>>[];
      final index = _currentItemIndex(torrents, stremio, nuvio: nuvio);
      // Lists still loading / wrong provider filter — keep pending.
      if (index == null) return;

      // Lazy ListView has not built the off-screen tile yet — jump by index
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
        // Estimate put us here but the tile still is not built — nudge once.
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
    final torrentOn = await _settings.isPlaySourceTorrentEnabled();
    final stremioOn = await _settings.isPlaySourceStremioEnabled();
    final local = _profile.localTorrentEngine;
    List<Map<String, dynamic>> addons = const [];
    if (stremioOn) {
      try {
        addons = await _stremio.getAddonsForResource('stream');
      } catch (_) {}
    }
    List<NuvioAddon> nuvioAddons = const [];
    // Nuvio is gated on Direct torrent (same as media-details Sources).
    if (torrentOn) {
      try {
        nuvioAddons = await NuvioService.instance.listSourcesPanelAddons();
      } catch (_) {}
    }
    if (!mounted) return;

    final hasStremio = stremioOn && addons.isNotEmpty;
    final hasTorrent = torrentOn;
    final hasNuvio = torrentOn && nuvioAddons.isNotEmpty;
    final kind = _resolveInitialKind(
      hasTorrent: hasTorrent,
      hasStremio: hasStremio,
      hasNuvio: hasNuvio,
    );

    setState(() {
      _sortPreference = sort;
      _jackettConfigured = jackett;
      _prowlarrConfigured = prowlarr;
      _localTorrentEngine = local;
      _showTorrents = hasTorrent;
      _showStremio = hasStremio;
      _showNuvio = hasNuvio;
      _nuvioAddons = nuvioAddons;
      // Filters → Providers starts empty; user picks scrapers.
      _nuvioSelectedScraperIds = {};
      _streamAddons = addons;
      _kindFilter = kind;
      _selectedSourceId = _sourceIdForKind(kind, addons);
      if (kind == 'nuvio') {
        final base = widget.currentAddonBaseUrl;
        if (base != null && base.startsWith('nuvio:')) {
          _nuvioSelectedScraperIds = {base.substring('nuvio:'.length)};
        }
      }
    });

    // Load only the selected kind(s) — no prefetch of other categories.
    _ensureVisibleKindsLoaded();
  }

  String get _catalogCacheKey => CatalogSourcesSessionCache.cacheKey(
    mediaId: widget.movie.id,
    mediaType: widget.movie.mediaType,
    season: widget.season,
    episode: widget.episode,
  );

  /// Hydrate from session TTL cache or fetch — only for kinds currently shown.
  void _ensureVisibleKindsLoaded({bool force = false}) {
    if (_showsTorrents) _ensureTorrentsLoaded(force: force);
    if (_showsStremio) _ensureStremioLoaded(force: force);
    if (_showsNuvio) unawaited(_ensureNuvioLoaded(force: force));
  }

  void _ensureTorrentsLoaded({bool force = false}) {
    if (!_showsTorrents) return;
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'torrents');
      unawaited(_runTorrentSearch());
      return;
    }
    if (_results.isNotEmpty || _searching) return;
    final cached = CatalogSourcesSessionCache.readTorrents(_catalogCacheKey);
    if (cached != null) {
      setState(() {
        _results = cached;
        _error = null;
      });
      _focusPlayingSourceIfNeeded();
      _requestScrollToCurrent();
      return;
    }
    unawaited(_runTorrentSearch());
  }

  void _ensureStremioLoaded({bool force = false}) {
    if (!_showsStremio) return;
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'stremio');
      unawaited(_fetchStremioStreams());
      return;
    }
    if (_stremioStreams.isNotEmpty || _stremioFetching) return;
    final cached = CatalogSourcesSessionCache.readStremio(_catalogCacheKey);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _stremioStreams = cached;
        _loadedAddonBaseUrls
          ..clear()
          ..addAll({
            for (final s in cached)
              if (s['_addonBaseUrl'] is String) s['_addonBaseUrl'] as String,
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
      return;
    }
    if (cached != null && cached.isEmpty) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'stremio');
    }
    unawaited(_fetchStremioStreams());
  }

  Future<void> _ensureNuvioLoaded({bool force = false}) async {
    if (!_showsNuvio) return;
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'nuvio');
      await _fetchNextNuvioScraper(reset: true);
      return;
    }
    if (_nuvioStreams.isNotEmpty || _nuvioFetching) return;
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
      return;
    }
    await _fetchNextNuvioScraper(reset: true);
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
    }
  }

  /// Stop in-flight work for kinds that are no longer selected.
  void _abortHiddenKindFetches(String keepKind) {
    if (keepKind != 'torrents' && _searching) {
      _searchGen++;
      _searching = false;
      _results = [];
    }
    if (keepKind != 'stremio' && _stremioFetching) {
      _stremioGen++;
      _stremioFetching = false;
      _stremioStreams = [];
      _loadedAddonBaseUrls.clear();
      _completedAddonBaseUrls.clear();
    }
    if (keepKind != 'nuvio' && _nuvioFetching) {
      _nuvioFetchGen++;
      _nuvioFetching = false;
      DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
      _nuvioStreams = [];
      _nuvioFetchedScraperIds = {};
    }
  }

  String _sourceIdForKind(String kind, List<Map<String, dynamic>> addons) {
    return switch (kind) {
      'stremio' =>
        _preferredStremioAddonBaseUrl(addons) ??
            (addons.isNotEmpty ? addons.first['baseUrl'] as String : 'forja'),
      'nuvio' => 'all_nuvio',
      'torrents' => 'forja',
      _ => 'forja',
    };
  }

  /// Prefer caller's kind when available; else Torrents → Nuvio → Stremio.
  String _resolveInitialKind({
    required bool hasTorrent,
    required bool hasStremio,
    required bool hasNuvio,
  }) {
    final preferred = _effectivePreferredKind();
    if (preferred == 'torrents' && hasTorrent) return 'torrents';
    if (preferred == 'nuvio' && hasNuvio) return 'nuvio';
    if (preferred == 'stremio' && hasStremio) return 'stremio';
    if (hasTorrent) return 'torrents';
    if (hasNuvio) return 'nuvio';
    if (hasStremio) return 'stremio';
    return 'torrents';
  }

  String _defaultStremioSourceId() {
    if (_streamAddons.isEmpty) return 'forja';
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
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    final preferred = widget.preferredKind;
    if (preferred == 'nuvio' ||
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
  /// within the current tab — never yank Torrents ↔ Stremio ↔ Nuvio.
  void _focusPlayingSourceIfNeeded() {
    if (!mounted) return;

    bool torrentsHit() =>
        _showTorrents && _results.any((r) => _isCurrentMagnet(r.magnet));
    bool nuvioHit() => _showNuvio && _nuvioStreams.any(_isCurrentStremio);
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
      final providerChanged = beforeAddon != _selectedSourceId ||
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
      } else if (_kindFilter == 'stremio' && stremioHit()) {
        finishOnKind('stremio', allowKindSwitch: false);
      }
      return;
    }

    // Already visible under the active filter — select provider + scroll.
    if (_kindFilter == 'torrents' && torrentsHit()) {
      finishOnKind('torrents', allowKindSwitch: true);
      return;
    }
    if (_kindFilter == 'nuvio' && nuvioHit()) {
      finishOnKind('nuvio', allowKindSwitch: true);
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
    } else if (stremioHit()) {
      finishOnKind('stremio', allowKindSwitch: true);
    } else if (torrentsHit()) {
      finishOnKind('torrents', allowKindSwitch: true);
    }
  }

  List<TorrentResult> get _filteredTorrents {
    final list = filterTorrentResults(
      _results,
      searchQuery: _searchQuery,
      qualityFilters: _qualityFilters,
      languageFilters: _languageFilters,
      techFilters: _techFilters,
      audioFilters: _audioFilters,
      sizeFilters: _sizeFilters,
    );
    return List<TorrentResult>.from(list)..sort(_compare);
  }

  List<Map<String, dynamic>> get _filteredStremio {
    final q = _searchQuery.trim().toLowerCase();
    return _stremioStreams.where((s) {
      if (q.isEmpty) return true;
      final blob =
          '${s['title'] ?? ''} ${s['name'] ?? ''} ${s['description'] ?? ''}'
              .toLowerCase();
      return blob.contains(q);
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
    final q = _searchQuery.trim().toLowerCase();
    return _nuvioStreams.where((s) {
      if (!_nuvioStreamSelected(s)) return false;
      if (q.isEmpty) return true;
      final blob =
          '${s['title'] ?? ''} ${s['name'] ?? ''} ${s['description'] ?? ''}'
              .toLowerCase();
      return blob.contains(q);
    }).toList();
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
  }

  Set<String> get _availableQualities => collectQualities(_filterNames);
  Set<String> get _availableLanguages => collectLanguages(_filterNames);
  Set<String> get _availableTech => collectTechTags(_filterNames);
  Set<String> get _availableSizes => collectSizeRanges(
    _results.map(
      (r) => r.sizeInBytes > 0
          ? r.sizeInBytes
          : TorrentReleaseMetadata.parseSizeBytes(r.size),
    ),
  );

  List<SourcesPanelProviderOption> get _providerOptions {
    if (_kindFilter == 'stremio') {
      return [
        for (final a in _streamAddons)
          SourcesPanelProviderOption(
            id: a['baseUrl'] as String,
            label: (a['name'] ?? 'Addon').toString(),
          ),
      ];
    }
    if (_kindFilter == 'nuvio') {
      return [
        for (final a in _nuvioAddons)
          for (final s in a.scrapers)
            if (s.enabled)
              SourcesPanelProviderOption(id: 'nuvio:${s.id}', label: s.name),
      ];
    }
    if (_kindFilter == 'torrents') {
      return [
        const SourcesPanelProviderOption(id: 'forja', label: 'Forja'),
        if (_jackettConfigured)
          const SourcesPanelProviderOption(id: 'jackett', label: 'Jackett'),
        if (_prowlarrConfigured)
          const SourcesPanelProviderOption(id: 'prowlarr', label: 'Prowlarr'),
      ];
    }
    return const [];
  }

  bool get _isFetching =>
      (_showsTorrents && _searching) ||
      (_showsStremio && _stremioFetching) ||
      (_showsNuvio && _nuvioFetching);

  Future<void> _runTorrentSearch() async {
    final gen = ++_searchGen;
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });

    try {
      final List<TorrentResult> found;
      final isTv = widget.movie.mediaType == 'tv';
      final season = widget.season ?? 1;
      final episode = widget.episode ?? 1;

      if (_selectedSourceId == 'jackett') {
        found = await _searchJackett(
          isTv: isTv,
          season: season,
          episode: episode,
        );
      } else if (_selectedSourceId == 'prowlarr') {
        found = await _searchProwlarr(
          isTv: isTv,
          season: season,
          episode: episode,
        );
      } else if (isTv) {
        found = await _searchForjaTv(season: season, episode: episode);
      } else {
        found = await _searchForjaMovie();
      }

      if (!mounted || gen != _searchGen) return;
      CatalogSourcesSessionCache.writeTorrents(_catalogCacheKey, found);
      setState(() {
        _results = found;
        _searching = false;
        if (found.isEmpty && !_showsStremio && !_showsNuvio) {
          _error = 'No torrents found';
        }
      });
      _focusPlayingSourceIfNeeded();
      _requestScrollToCurrent();
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searching = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _fetchStremioStreams() async {
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

    final gen = ++_stremioGen;
    setState(() {
      _stremioFetching = true;
      _stremioStreams = [];
      _loadedAddonBaseUrls.clear();
      _completedAddonBaseUrls.clear();
      _error = null;
    });

    var stremioId = imdb;
    if (widget.movie.mediaType == 'tv') {
      stremioId = '$imdb:${widget.season ?? 1}:${widget.episode ?? 1}';
    }
    final type = widget.movie.mediaType == 'tv' ? 'series' : 'movie';
    var pending = _streamAddons.length;

    void completeOne() {
      if (!mounted || gen != _stremioGen) return;
      pending--;
      if (pending <= 0) {
        CatalogSourcesSessionCache.writeStremio(
          _catalogCacheKey,
          _stremioStreams,
        );
        setState(() {
          _stremioFetching = false;
          _syncStremioProviderSelection();
          if (_stremioStreams.isEmpty && !_showsTorrents) {
            _error = 'No streams found from any addon';
          }
        });
      }
    }

    for (final addon in _streamAddons) {
      final baseUrl = addon['baseUrl'] as String;
      _stremio
          .getStreams(
            baseUrl: baseUrl,
            type: type,
            id: stremioId,
          )
          .then((streams) {
            if (!mounted || gen != _stremioGen) return;
            final tagged = filterStremioStreamsForProfile(
              streams.map((s) {
                if (s is Map<String, dynamic>) {
                  return <String, dynamic>{
                    ...s,
                    '_addonName': addon['name'] ?? 'Unknown',
                    '_addonBaseUrl': baseUrl,
                  };
                }
                return <String, dynamic>{
                  '_addonName': addon['name'],
                  '_addonBaseUrl': baseUrl,
                };
              }).toList(),
              _profile,
            );
            setState(() {
              _completedAddonBaseUrls.add(baseUrl);
              if (tagged.isNotEmpty) {
                _loadedAddonBaseUrls.add(baseUrl);
              }
              _stremioStreams.addAll(tagged);
              _syncStremioProviderSelection();
            });
            if (tagged.isNotEmpty) {
              _focusPlayingSourceIfNeeded();
              _requestScrollToCurrent();
            }
          })
          .catchError((_) {
            if (!mounted || gen != _stremioGen) return;
            setState(() {
              _completedAddonBaseUrls.add(baseUrl);
              _syncStremioProviderSelection();
            });
          })
          .whenComplete(completeOne);
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

  Future<void> _fetchNextNuvioScraper({bool reset = false}) async {
    if (_nuvioAddons.isEmpty || widget.movie.id <= 0) return;
    if (_nuvioFetching && !reset) return;
    if (reset) {
      DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
    }
    final fetchedIds = reset
        ? <String>{}
        : Set<String>.from(_nuvioFetchedScraperIds);
    final scraperId = nextNuvioScraperId(
      orderedIds: _orderedNuvioScraperIds,
      selectedIds: _nuvioSelectedScraperIds,
      fetchedIds: fetchedIds,
    );
    if (scraperId == null) return;
    final gen = ++_nuvioFetchGen;
    setState(() {
      _nuvioFetching = true;
      if (reset) {
        _nuvioStreams = [];
        _nuvioFetchedScraperIds = {};
      }
      _error = null;
    });
    final type = widget.movie.mediaType == 'tv' ? 'tv' : 'movie';
    final batch = await NuvioService.instance.runSourcesScraper(
      scraperId: scraperId,
      tmdbId: widget.movie.id.toString(),
      type: type,
      season: widget.movie.mediaType == 'tv' ? widget.season : null,
      episode: widget.movie.mediaType == 'tv' ? widget.episode : null,
    );
    if (!mounted || gen != _nuvioFetchGen) return;
    if (batch == null) {
      setState(() => _nuvioFetching = false);
      return;
    }
    setState(() {
      _nuvioFetchedScraperIds.add(scraperId);
      if (batch.streams.isNotEmpty) {
        _nuvioStreams.addAll(
          batch.streams.map(
            (s) => <String, dynamic>{
              ...s,
              '_nuvioScraperId': batch.scraperId,
              '_addonName': s['sourceName'] ?? batch.scraperName,
              '_addonBaseUrl': 'nuvio:${batch.scraperId}',
            },
          ),
        );
      }
      _nuvioFetching = false;
      if (_nuvioStreams.isEmpty && _pendingNuvioScraperIds.isEmpty) {
        _error = 'No streams found from selected Nuvio providers';
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
      } else if (kind == 'torrents') {
        _selectedSourceId = 'forja';
      }
    });
    _ensureVisibleKindsLoaded();
    _requestScrollToCurrent();
  }

  String get _year {
    final d = widget.movie.releaseDate;
    return d.length >= 4 ? d.substring(0, 4) : '';
  }

  Future<List<TorrentResult>> _searchForjaMovie() async {
    final query = _year.isNotEmpty
        ? '${widget.movie.title} $_year'
        : widget.movie.title;
    final results = (await Engine.searchTorrents(
      query,
    )).map(TorrentResult.fromJson).toList();
    return (await Engine.filterTorrents(
      results.map((r) => r.toJson()).toList(),
      widget.movie.title,
    )).map(TorrentResult.fromJson).toList();
  }

  Future<List<TorrentResult>> _searchForjaTv({
    required int season,
    required int episode,
  }) async {
    final s = season.toString().padLeft(2, '0');
    final e = episode.toString().padLeft(2, '0');
    final seasonQuery = '${widget.movie.title} S$s';
    final episodeQuery = '${widget.movie.title} S${s}E$e';
    final seasonRaw = (await Engine.searchTorrents(
      seasonQuery,
    )).map(TorrentResult.fromJson).toList();
    final episodeRaw = (await Engine.searchTorrents(
      episodeQuery,
    )).map(TorrentResult.fromJson).toList();
    final combined = <String, TorrentResult>{};
    for (final r in (await Engine.filterTorrents(
      episodeRaw.map((r) => r.toJson()).toList(),
      widget.movie.title,
      requiredSeason: season,
      requiredEpisode: episode,
    )).map(TorrentResult.fromJson)) {
      combined[r.magnet] = r;
    }
    for (final r in (await Engine.filterTorrents(
      seasonRaw.map((r) => r.toJson()).toList(),
      widget.movie.title,
      requiredSeason: season,
    )).map(TorrentResult.fromJson)) {
      combined[r.magnet] = r;
    }
    return combined.values.toList();
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

  void _onChipTap(String id) {
    if (id.startsWith('nuvio:')) {
      final scraperId = id.substring('nuvio:'.length);
      setState(() {
        _selectedSourceId = 'all_nuvio';
        if (_nuvioSelectedScraperIds.contains(scraperId)) {
          _nuvioSelectedScraperIds = Set<String>.from(_nuvioSelectedScraperIds)
            ..remove(scraperId);
        } else {
          _nuvioSelectedScraperIds = {..._nuvioSelectedScraperIds, scraperId};
        }
        _error = null;
      });
      return;
    }
    if (id == _selectedSourceId) return;
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
      // Streams already fetched; provider only filters which addon rows show.
    } else if (_kindFilter != 'nuvio') {
      unawaited(_runTorrentSearch());
    }
  }

  Future<void> _selectTorrent(TorrentResult result) async {
    if (_isCurrentMagnet(result.magnet)) {
      widget.onClose();
      return;
    }
    // Close without cancelling engine jobs — resolve starts immediately and
    // dispose must not abort the new torrentStream (see [dismiss]).
    PlayerSourcesPanel.dismiss(cancelEngine: false);
    await widget.onTorrentSelected(result);
  }

  Future<void> _selectStremio(Map<String, dynamic> stream) async {
    if (_isCurrentStremio(stream)) {
      widget.onClose();
      return;
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
    final torrents = _showsTorrents ? _filteredTorrents : <TorrentResult>[];
    final stremio = _showsStremio
        ? _visibleStremioStreams
        : <Map<String, dynamic>>[];
    final nuvio = _showsNuvio ? _filteredNuvio : <Map<String, dynamic>>[];
    final totalCount = torrents.length + stremio.length + nuvio.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TorrentSourcesPanelChrome(
          onClose: widget.onClose,
          kindFilter: _kindFilter,
          showTorrents: _showTorrents,
          showStremio: _showStremio,
          showNuvio: _showNuvio,
          onKindChanged: _onKindChanged,
          resultCount: totalCount,
          episodeLabel: _episodeLabel,
          isFetching: _isFetching,
          onCancelFetch: () {
            _searchGen++;
            _stremioGen++;
            _nuvioFetchGen++;
            DomainStreamProviderResolver.cancelAllPending();
            setState(() {
              _searching = false;
              _stremioFetching = false;
              _nuvioFetching = false;
            });
          },
          providerOptions: _providerOptions,
          selectedSourceId: _selectedSourceId,
          nuvioSelectedScraperIds: _nuvioSelectedScraperIds,
          onProviderTap: _onChipTap,
          searchQuery: _searchQuery,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
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
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _buildList(torrents, stremio, nuvio, totalCount: totalCount),
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
    List<Map<String, dynamic>> nuvio, {
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
    final remainingNuvioProviders = _showsNuvio
        ? _pendingNuvioScraperIds.length
        : 0;
    final showNuvioLoadNext = remainingNuvioProviders > 0;
    if (totalCount == 0 && !showNuvioLoadNext) {
      final emptyMsg = _showsNuvio && _nuvioSelectedScraperIds.isEmpty
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
        (_kindFilter == 'stremio' && _providerOptions.length > 1);

    _scheduleScrollToCurrent();

    final currentIndex = _currentItemIndex(torrents, stremio, nuvio: nuvio);

    return ListView.separated(
      controller: _listScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      itemCount: totalCount + (showNuvioLoadNext ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        if (showNuvioLoadNext && i == totalCount) {
          return SourcesLoadNextProviderButton(
            remainingProviders: remainingNuvioProviders,
            isLoading: _nuvioFetching,
            onPressed: _fetchNextNuvioScraper,
          );
        }
        if (i < torrents.length) {
          final r = torrents[i];
          final isCurrent = i == currentIndex;
          return KeyedSubtree(
            key: isCurrent ? _currentTileKey : null,
            child: TorrentSourceTile(
              result: r,
              highlightStart: isCurrent,
              onPlay: () => _selectTorrent(r),
            ),
          );
        }

        final j = i - torrents.length;
        final s = j < stremio.length ? stremio[j] : nuvio[j - stremio.length];
        final title = (s['title'] ?? s['name'] ?? 'Unknown Stream').toString();
        final description = (s['description'] ?? '').toString();
        final presentation = stremioTilePresentation(s, isResumable: false);
        final isCurrent = i == currentIndex;
        return KeyedSubtree(
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
            onTap: () => _selectStremio(s),
          ),
        );
      },
    );
  }
}
