import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel_chrome.dart';
import 'package:rust/rust.dart';

/// Right-side Sources panel in the player — same shell/chrome/tiles as
/// media-details Sources (torrent search list), not in-torrent file picker.
class PlayerSourcesPanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    // Cancel before unmount — do not wait for Overlay dispose (next frame).
    // Otherwise Nuvio JS keeps issuing fetches until the element drops.
    NuvioService.instance.cancelPending();
    Engine.cancelPendingResolve();
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
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
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

  List<Map<String, dynamic>> _nuvioStreams = [];
  List<NuvioAddon> _nuvioAddons = [];
  Set<String> _nuvioSelectedScraperIds = {};
  StreamSubscription<NuvioScraperResult>? _nuvioSub;
  bool _nuvioFetching = false;

  bool _searching = false;
  bool _stremioFetching = false;
  int _searchGen = 0;
  int _stremioGen = 0;
  String? _error;
  bool _pendingScrollToCurrent = true;

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
  int _visibleLimit = kSourcesListPageSize;

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
    _nuvioSub?.cancel();
    _nuvioSub = null;
    NuvioService.instance.cancelPending();
    Engine.cancelPendingResolve();
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

  bool _isCurrentStremio(Map<String, dynamic> stream) {
    final playUrl = widget.currentStreamUrl;
    if (playUrl != null && playUrl.isNotEmpty) {
      final url = stream['url']?.toString();
      if (url != null && url.isNotEmpty && url == playUrl) return true;
    }
    final current = _infoHashOf(widget.currentMagnet);
    if (current == null) return false;
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
    _scheduleScrollToCurrent();
  }

  void _scheduleScrollToCurrent() {
    if (!_pendingScrollToCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingScrollToCurrent) return;
      final ctx = _currentTileKey.currentContext;
      if (ctx == null) return;
      _pendingScrollToCurrent = false;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.15,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
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
    final nuvioScraperIds = <String>{
      for (final a in nuvioAddons)
        for (final s in a.scrapers)
          if (s.enabled) s.id,
    };
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
      _nuvioSelectedScraperIds = nuvioScraperIds;
      _streamAddons = addons;
      _kindFilter = kind;
      _selectedSourceId = kind == 'stremio'
          ? (addons.isNotEmpty
              ? addons.first['baseUrl'] as String
              : 'forja')
          : _sourceIdForKind(kind, addons);
      _resetVisibleLimit();
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
    if (force) {
      CatalogSourcesSessionCache.invalidate(
        _catalogCacheKey,
        kind: 'torrents',
      );
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
    if (force) {
      CatalogSourcesSessionCache.invalidate(
        _catalogCacheKey,
        kind: 'stremio',
      );
      unawaited(_fetchStremioStreams());
      return;
    }
    if (_stremioStreams.isNotEmpty || _stremioFetching) return;
    final cached = CatalogSourcesSessionCache.readStremio(_catalogCacheKey);
    if (cached != null) {
      setState(() {
        _stremioStreams = cached;
        _loadedAddonBaseUrls
          ..clear()
          ..addAll({
            for (final s in cached)
              if (s['_addonBaseUrl'] is String) s['_addonBaseUrl'] as String,
          });
        _error = null;
      });
      _focusPlayingSourceIfNeeded();
      _requestScrollToCurrent();
      return;
    }
    unawaited(_fetchStremioStreams());
  }

  Future<void> _ensureNuvioLoaded({bool force = false}) async {
    if (force) {
      CatalogSourcesSessionCache.invalidate(_catalogCacheKey, kind: 'nuvio');
      await _fetchAllNuvioStreams();
      return;
    }
    if (_nuvioStreams.isNotEmpty || _nuvioFetching) return;
    final cached = CatalogSourcesSessionCache.readNuvio(_catalogCacheKey);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _nuvioStreams = cached;
        _error = null;
      });
      _focusPlayingSourceIfNeeded();
      _requestScrollToCurrent();
      return;
    }
    await _fetchAllNuvioStreams();
  }

  void _reloadKind(String kind) {
    switch (kind) {
      case 'torrents':
        _ensureTorrentsLoaded(force: true);
      case 'stremio':
        _ensureStremioLoaded(force: true);
      case 'nuvio':
        unawaited(_ensureNuvioLoaded(force: true));
    }
  }

  String _sourceIdForKind(String kind, List<Map<String, dynamic>> addons) {
    return switch (kind) {
      'stremio' => addons.isNotEmpty
          ? addons.first['baseUrl'] as String
          : 'forja',
      'nuvio' => 'all_nuvio',
      'torrents' => 'forja',
      _ => 'forja',
    };
  }

  /// Prefer Torrents when available; never open on a merged All kind.
  String _resolveInitialKind({
    required bool hasTorrent,
    required bool hasStremio,
    required bool hasNuvio,
  }) {
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

  void _resetVisibleLimit() {
    _visibleLimit = kSourcesListPageSize;
  }

  String? _effectivePreferredKind() {
    final base = widget.currentAddonBaseUrl;
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    final preferred = widget.preferredKind;
    if (preferred == 'nuvio' ||
        preferred == 'stremio' ||
        preferred == 'torrents') {
      return preferred;
    }
    final magnet = widget.currentMagnet;
    if (magnet != null && magnet.isNotEmpty && preferred != 'stremio') {
      return 'torrents';
    }
    return preferred;
  }

  /// After lists update, scroll the playing source into view when it is
  /// already under the active kind; otherwise switch to the kind that has it.
  void _focusPlayingSourceIfNeeded() {
    if (!mounted) return;

    bool torrentsHit() =>
        _showTorrents && _results.any((r) => _isCurrentMagnet(r.magnet));
    bool nuvioHit() => _showNuvio && _nuvioStreams.any(_isCurrentStremio);
    bool stremioHit() =>
        _showStremio && _stremioStreams.any(_isCurrentStremio);

    // Already visible under the active filter — only scroll.
    if (_kindFilter == 'torrents' && torrentsHit()) {
      _requestScrollToCurrent();
      return;
    }
    if (_kindFilter == 'nuvio' && nuvioHit()) {
      _requestScrollToCurrent();
      return;
    }
    if (_kindFilter == 'stremio' && stremioHit()) {
      _requestScrollToCurrent();
      return;
    }

    void go(String kind) {
      if (_kindFilter == kind) {
        _requestScrollToCurrent();
        return;
      }
      setState(() {
        _kindFilter = kind;
        _selectedSourceId = _sourceIdForKind(kind, _streamAddons);
        if (kind == 'nuvio') {
          if (_nuvioSelectedScraperIds.isEmpty) {
            _nuvioSelectedScraperIds = {
              for (final a in _nuvioAddons)
                for (final s in a.scrapers)
                  if (s.enabled) s.id,
            };
          }
        }
      });
      _requestScrollToCurrent();
    }

    // Prefer the caller's kind when it already has the playing row.
    // While that kind is still loading, do not steal focus to a Torrentio
    // mirror under Torrents / Stremio.
    final preferred = _effectivePreferredKind();
    if (preferred == 'nuvio' && _showNuvio) {
      if (nuvioHit()) {
        go('nuvio');
        return;
      }
      if (_nuvioFetching) return;
    }
    if (preferred == 'stremio' && _showStremio) {
      if (stremioHit()) {
        go('stremio');
        return;
      }
      if (_stremioFetching) return;
    }
    if (preferred == 'torrents' && _showTorrents) {
      if (torrentsHit()) {
        go('torrents');
        return;
      }
      if (_searching) return;
    }

    // Discovery order: Nuvio before Stremio/Torrents so a Torrentio mirror of
    // the same infoHash does not steal a Nuvio / Stremio Direct session.
    if (nuvioHit()) {
      go('nuvio');
    } else if (stremioHit()) {
      go('stremio');
    } else if (torrentsHit()) {
      go('torrents');
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
              SourcesPanelProviderOption(
                id: 'nuvio:${s.id}',
                label: s.name,
              ),
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

  int get _visibleCount {
    var n = 0;
    if (_showsTorrents) n += _filteredTorrents.length;
    if (_showsStremio) n += _filteredStremio.length;
    if (_showsNuvio) n += _filteredNuvio.length;
    return n;
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
        found =
            await _searchJackett(isTv: isTv, season: season, episode: episode);
      } else if (_selectedSourceId == 'prowlarr') {
        found =
            await _searchProwlarr(isTv: isTv, season: season, episode: episode);
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
          if (_stremioStreams.isEmpty && !_showsTorrents) {
            _error = 'No streams found from any addon';
          }
        });
      }
    }

    for (final addon in _streamAddons) {
      _stremio
          .getStreams(
        baseUrl: addon['baseUrl'] as String,
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
                '_addonBaseUrl': addon['baseUrl'],
              };
            }
            return <String, dynamic>{
              '_addonName': addon['name'],
              '_addonBaseUrl': addon['baseUrl'],
            };
          }).toList(),
          _profile,
        );
        setState(() {
          if (tagged.isNotEmpty) {
            _loadedAddonBaseUrls.add(addon['baseUrl'] as String);
            if (_kindFilter == 'stremio' &&
                (_selectedSourceId == 'all_stremio' ||
                    !_loadedAddonBaseUrls.contains(_selectedSourceId))) {
              _selectedSourceId = addon['baseUrl'] as String;
            }
          }
          _stremioStreams.addAll(tagged);
        });
        if (tagged.isNotEmpty) {
          _focusPlayingSourceIfNeeded();
          _requestScrollToCurrent();
        }
      }).catchError((_) {
        // skip failed addon
      }).whenComplete(completeOne);
    }
  }

  Future<void> _fetchAllNuvioStreams() async {
    if (_nuvioAddons.isEmpty || widget.movie.id <= 0) return;
    await _nuvioSub?.cancel();
    _nuvioSub = null;
    NuvioService.instance.cancelPending();
    setState(() {
      _nuvioFetching = true;
      _nuvioStreams = [];
      _error = null;
    });
    final type = widget.movie.mediaType == 'tv' ? 'tv' : 'movie';
    final stream = NuvioService.instance.streamAll(
      tmdbId: widget.movie.id.toString(),
      type: type,
      season: widget.movie.mediaType == 'tv' ? widget.season : null,
      episode: widget.movie.mediaType == 'tv' ? widget.episode : null,
    );
    _nuvioSub = stream.listen(
      (batch) {
        if (!mounted) return;
        if (batch.streams.isEmpty) return;
        setState(() {
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
        });
        _focusPlayingSourceIfNeeded();
        _requestScrollToCurrent();
      },
      onError: (_) {},
      onDone: () {
        _nuvioSub = null;
        if (!mounted) return;
        CatalogSourcesSessionCache.writeNuvio(_catalogCacheKey, _nuvioStreams);
        setState(() {
          _nuvioFetching = false;
          if (_nuvioStreams.isEmpty && !_showsTorrents && !_showsStremio) {
            _error = 'No streams found from any Nuvio addon';
          }
        });
        _focusPlayingSourceIfNeeded();
      },
      cancelOnError: false,
    );
  }

  void _onKindChanged(String kind) {
    if (kind == _kindFilter) return;
    setState(() {
      _kindFilter = kind;
      _resetVisibleLimit();
      _qualityFilters = {};
      _languageFilters = {};
      _techFilters = {};
      _audioFilters = {};
      _sizeFilters = {};
      _searchQuery = '';
      if (kind == 'stremio') {
        _selectedSourceId = _defaultStremioSourceId();
      } else if (kind == 'nuvio') {
        _selectedSourceId = 'all_nuvio';
        _nuvioSelectedScraperIds = {
          for (final a in _nuvioAddons)
            for (final s in a.scrapers)
              if (s.enabled) s.id,
        };
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
    final query =
        _year.isNotEmpty ? '${widget.movie.title} $_year' : widget.movie.title;
    final results = (await Engine.searchTorrents(query))
        .map(TorrentResult.fromJson)
        .toList();
    return (await Engine.filterTorrents(
      results.map((r) => r.toJson()).toList(),
      widget.movie.title,
    ))
        .map(TorrentResult.fromJson)
        .toList();
  }

  Future<List<TorrentResult>> _searchForjaTv({
    required int season,
    required int episode,
  }) async {
    final s = season.toString().padLeft(2, '0');
    final e = episode.toString().padLeft(2, '0');
    final seasonQuery = '${widget.movie.title} S$s';
    final episodeQuery = '${widget.movie.title} S${s}E$e';
    final seasonRaw = (await Engine.searchTorrents(seasonQuery))
        .map(TorrentResult.fromJson)
        .toList();
    final episodeRaw = (await Engine.searchTorrents(episodeQuery))
        .map(TorrentResult.fromJson)
        .toList();
    final combined = <String, TorrentResult>{};
    for (final r in (await Engine.filterTorrents(
      episodeRaw.map((r) => r.toJson()).toList(),
      widget.movie.title,
      requiredSeason: season,
      requiredEpisode: episode,
    ))
        .map(TorrentResult.fromJson)) {
      combined[r.magnet] = r;
    }
    for (final r in (await Engine.filterTorrents(
      seasonRaw.map((r) => r.toJson()).toList(),
      widget.movie.title,
      requiredSeason: season,
    ))
        .map(TorrentResult.fromJson)) {
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
      ))
          .map(TorrentResult.fromJson);
      final episodeFiltered = (await Engine.filterTorrents(
        results[1].map((r) => r.toJson()).toList(),
        widget.movie.title,
        requiredSeason: season,
        requiredEpisode: episode,
      ))
          .map(TorrentResult.fromJson);
      for (final r in episodeFiltered) {
        combined[r.magnet] = r;
      }
      for (final r in seasonFiltered) {
        combined[r.magnet] = r;
      }
      return combined.values.toList();
    }

    final query =
        _year.isNotEmpty ? '${widget.movie.title} $_year' : widget.movie.title;
    final results = await jackett.search(baseUrl, apiKey, query);
    return (await Engine.filterTorrents(
      results.map((r) => r.toJson()).toList(),
      widget.movie.title,
    ))
        .map(TorrentResult.fromJson)
        .toList();
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
      final resolved =
          await prowlarr.resolveTagIndexerIds(baseUrl, apiKey, tagIds);
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
      ))
          .map(TorrentResult.fromJson);
      final episodeFiltered = (await Engine.filterTorrents(
        results[1].map((r) => r.toJson()).toList(),
        widget.movie.title,
        requiredSeason: season,
        requiredEpisode: episode,
      ))
          .map(TorrentResult.fromJson);
      for (final r in episodeFiltered) {
        combined[r.magnet] = r;
      }
      for (final r in seasonFiltered) {
        combined[r.magnet] = r;
      }
      return combined.values.toList();
    }

    final query =
        _year.isNotEmpty ? '${widget.movie.title} $_year' : widget.movie.title;
    final results = await prowlarr.search(
      baseUrl,
      apiKey,
      query,
      indexerIds: indexerIds,
    );
    return (await Engine.filterTorrents(
      results.map((r) => r.toJson()).toList(),
      widget.movie.title,
    ))
        .map(TorrentResult.fromJson)
        .toList();
  }

  void _onChipTap(String id) {
    if (id.startsWith('nuvio:')) {
      final scraperId = id.substring('nuvio:'.length);
      setState(() {
        _resetVisibleLimit();
        _selectedSourceId = 'all_nuvio';
        if (_nuvioSelectedScraperIds.contains(scraperId)) {
          _nuvioSelectedScraperIds = Set<String>.from(_nuvioSelectedScraperIds)
            ..remove(scraperId);
        } else {
          _nuvioSelectedScraperIds = {
            ..._nuvioSelectedScraperIds,
            scraperId,
          };
        }
        _error = null;
      });
      return;
    }
    if (id == _selectedSourceId) return;
    setState(() {
      _resetVisibleLimit();
      _selectedSourceId = id;
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
    // Close first so the player can show CHECKING SOURCES while resolving.
    widget.onClose();
    await widget.onTorrentSelected(result);
  }

  Future<void> _selectStremio(Map<String, dynamic> stream) async {
    if (_isCurrentStremio(stream)) {
      widget.onClose();
      return;
    }
    // Close first so the player can show CHECKING SOURCES while resolving.
    widget.onClose();
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
    final stremio =
        _showsStremio ? _visibleStremioStreams : <Map<String, dynamic>>[];
    final nuvio = _showsNuvio ? _filteredNuvio : <Map<String, dynamic>>[];
    final totalCount = torrents.length + stremio.length + nuvio.length;
    final visibleCount = totalCount < _visibleLimit ? totalCount : _visibleLimit;

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
            _nuvioSub?.cancel();
            _nuvioSub = null;
            NuvioService.instance.cancelPending();
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
          onSearchChanged: (q) => setState(() {
            _resetVisibleLimit();
            _searchQuery = q;
          }),
          availableQualities: _availableQualities,
          availableLanguages: _availableLanguages,
          availableTech: _availableTech,
          availableSizeRanges: _availableSizes,
          activeQualityFilters: _qualityFilters,
          activeLanguageFilters: _languageFilters,
          activeTechFilters: _techFilters,
          activeSizeFilters: _sizeFilters,
          onQualityFiltersChanged: (v) => setState(() {
            _resetVisibleLimit();
            _qualityFilters = v;
          }),
          onLanguageFiltersChanged: (v) => setState(() {
            _resetVisibleLimit();
            _languageFilters = v;
          }),
          onTechFiltersChanged: (v) => setState(() {
            _resetVisibleLimit();
            _techFilters = v;
          }),
          onSizeFiltersChanged: (v) => setState(() {
            _resetVisibleLimit();
            _sizeFilters = v;
          }),
          showAudioFilters: _showsTorrents,
          activeAudioFilters: _audioFilters,
          onAudioFiltersChanged: (v) => setState(() {
            _resetVisibleLimit();
            _audioFilters = v;
          }),
          sortPreference: _showsTorrents ? _sortPreference : null,
          onSortChanged: _showsTorrents
              ? (val) {
                  setState(() {
                    _resetVisibleLimit();
                    _sortPreference = val;
                  });
                  _settings.setSortPreference(val);
                }
              : null,
          showCacheLine: _showsTorrents && _localTorrentEngine,
          cacheRefreshToken:
              Object.hash(_openToken, _results.length, _searching),
          filterEnableBlur: false,
          onReloadKind: _reloadKind,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _buildList(
            torrents,
            stremio,
            nuvio,
            visibleCount: visibleCount,
            totalCount: totalCount,
          ),
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
    required int visibleCount,
    required int totalCount,
  }) {
    if (_isFetching && totalCount == 0) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
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

    final showAddonName = _showsNuvio ||
        (_kindFilter == 'stremio' && _providerOptions.length > 1);
    final showLoadMore = visibleCount < totalCount;

    _scheduleScrollToCurrent();

    final currentIndex =
        _currentItemIndex(torrents, stremio, nuvio: nuvio);

    return ListView.separated(
      controller: _listScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      itemCount: visibleCount + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        if (showLoadMore && i == visibleCount) {
          return SourcesLoadMoreButton(
            remaining: totalCount - visibleCount,
            onPressed: () => setState(() {
              _visibleLimit += kSourcesListPageSize;
            }),
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
        final s = j < stremio.length
            ? stremio[j]
            : nuvio[j - stremio.length];
        final title = (s['title'] ?? s['name'] ?? 'Unknown Stream').toString();
        final description = (s['description'] ?? '').toString();
        final presentation =
            stremioTilePresentation(s, isResumable: false);
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
