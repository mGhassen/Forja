import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_release_metadata.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel_chrome.dart';
import 'package:rust/rust.dart';

/// Right-side Sources panel in the player — same shell/chrome/tiles as
/// media-details Sources (torrent search list), not in-torrent file picker.
class PlayerSourcesPanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
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
    required Future<void> Function(TorrentResult result) onTorrentSelected,
    required Future<void> Function(Map<String, dynamic> stream)
        onStremioSelected,
  }) {
    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();

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
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
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
    return TorrentSourcesPanel(
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      child: playerSidePanelTvScope(
        context: context,
        onClose: widget.onClose,
        child: _PlayerSourcesBody(
          movie: widget.movie,
          season: widget.season,
          episode: widget.episode,
          currentMagnet: widget.currentMagnet,
          onTorrentSelected: widget.onTorrentSelected,
          onStremioSelected: widget.onStremioSelected,
          onClose: widget.onClose,
        ),
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
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
  final Future<void> Function(TorrentResult result) onTorrentSelected;
  final Future<void> Function(Map<String, dynamic> stream) onStremioSelected;
  final VoidCallback onClose;

  @override
  State<_PlayerSourcesBody> createState() => _PlayerSourcesBodyState();
}

class _PlayerSourcesBodyState extends State<_PlayerSourcesBody> {
  final _settings = SettingsService();
  final _stremio = StremioService();
  final _chipsScrollController = ScrollController();
  final _listScrollController = ScrollController();
  final _currentTileKey = GlobalKey();
  final _profile = PlatformPlayback.capabilities;

  List<TorrentResult> _results = [];
  List<Map<String, dynamic>> _stremioStreams = [];
  List<Map<String, dynamic>> _streamAddons = [];
  final Set<String> _loadedAddonBaseUrls = {};

  bool _searching = false;
  bool _stremioFetching = false;
  int _searchGen = 0;
  int _stremioGen = 0;
  String? _error;
  bool _pendingScrollToCurrent = true;

  bool _showTorrents = true;
  bool _showStremio = false;
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

  bool get _showsTorrents =>
      _kindFilter == 'torrents' || _kindFilter == 'all';
  bool get _showsStremio =>
      _kindFilter == 'stremio' || _kindFilter == 'all';
  bool get _showsMerged => _kindFilter == 'all';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchGen++;
    _stremioGen++;
    _chipsScrollController.dispose();
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
    List<Map<String, dynamic>> stremio,
  ) {
    for (var i = 0; i < torrents.length; i++) {
      if (_isCurrentMagnet(torrents[i].magnet)) return i;
    }
    final offset = torrents.length;
    for (var i = 0; i < stremio.length; i++) {
      if (_isCurrentStremio(stremio[i])) return offset + i;
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
    if (!mounted) return;

    final hasStremio = stremioOn && addons.isNotEmpty;
    final hasTorrent = torrentOn;
    String kind;
    if (hasTorrent && hasStremio) {
      kind = 'all';
    } else if (hasStremio) {
      kind = 'stremio';
    } else {
      kind = 'torrents';
    }

    setState(() {
      _sortPreference = sort;
      _jackettConfigured = jackett;
      _prowlarrConfigured = prowlarr;
      _localTorrentEngine = local;
      _showTorrents = hasTorrent;
      _showStremio = hasStremio;
      _streamAddons = addons;
      _kindFilter = kind;
      _selectedSourceId = kind == 'stremio'
          ? (addons.length > 1 ? 'all_stremio' : (addons.isNotEmpty ? addons.first['baseUrl'] as String : 'forja'))
          : 'forja';
    });

    if (_showsTorrents) unawaited(_runTorrentSearch());
    if (_showsStremio) unawaited(_fetchStremioStreams());
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

  List<Map<String, dynamic>> get _providerChips {
    if (_kindFilter == 'stremio') {
      final chips = <Map<String, dynamic>>[];
      if (_streamAddons.length > 1) {
        chips.add({'id': 'all_stremio', 'label': '⚡ All'});
      }
      for (final a in _streamAddons) {
        if (_loadedAddonBaseUrls.contains(a['baseUrl'])) {
          chips.add({'id': a['baseUrl'], 'label': a['name']});
        }
      }
      return chips;
    }
    if (_kindFilter == 'torrents') {
      final chips = <Map<String, dynamic>>[
        {'id': 'forja', 'label': 'Forja'},
      ];
      if (_jackettConfigured) {
        chips.add({'id': 'jackett', 'label': '🔍 Jackett'});
      }
      if (_prowlarrConfigured) {
        chips.add({'id': 'prowlarr', 'label': '🔍 Prowlarr'});
      }
      return chips;
    }
    return const [];
  }

  int get _visibleCount {
    var n = 0;
    if (_showsTorrents) n += _filteredTorrents.length;
    if (_showsStremio) n += _filteredStremio.length;
    return n;
  }

  bool get _isFetching =>
      (_showsTorrents && _searching) || (_showsStremio && _stremioFetching);

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
      setState(() {
        _results = found;
        _searching = false;
        if (found.isEmpty && !_showsStremio) {
          _error = 'No torrents found';
        }
      });
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
          }
          _stremioStreams.addAll(tagged);
        });
        if (tagged.isNotEmpty) _requestScrollToCurrent();
      }).catchError((_) {
        // skip failed addon
      }).whenComplete(completeOne);
    }
  }

  void _onKindChanged(String kind) {
    if (kind == _kindFilter) return;
    setState(() {
      _kindFilter = kind;
      _qualityFilters = {};
      _languageFilters = {};
      _techFilters = {};
      _audioFilters = {};
      _sizeFilters = {};
      _searchQuery = '';
      if (kind == 'stremio') {
        _selectedSourceId = _streamAddons.length > 1
            ? 'all_stremio'
            : (_streamAddons.isNotEmpty
                ? _streamAddons.first['baseUrl'] as String
                : 'all_stremio');
      } else if (kind == 'torrents') {
        _selectedSourceId = 'forja';
      }
    });
    if (_showsTorrents && _results.isEmpty) unawaited(_runTorrentSearch());
    if (_showsStremio && _stremioStreams.isEmpty) {
      unawaited(_fetchStremioStreams());
    }
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
    if (id == _selectedSourceId) return;
    setState(() {
      _selectedSourceId = id;
      _qualityFilters = {};
      _languageFilters = {};
      _techFilters = {};
      _audioFilters = {};
      _sizeFilters = {};
      _searchQuery = '';
    });
    if (_kindFilter == 'stremio') {
      // Streams already fetched; chip only filters which addon rows show.
      setState(() {
        if (id == 'all_stremio') {
          // keep full list from last fetch — re-fetch to rebuild cleanly
          unawaited(_fetchStremioStreams());
        } else {
          unawaited(_fetchStremioStreams());
        }
      });
    } else {
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
    final stremio = _showsStremio ? _visibleStremioStreams : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TorrentSourcesPanelChrome(
          onClose: widget.onClose,
          kindFilter: _kindFilter,
          showTorrents: _showTorrents,
          showStremio: _showStremio,
          showNuvio: false,
          onKindChanged: _onKindChanged,
          resultCount: _visibleCount,
          episodeLabel: _episodeLabel,
          isFetching: _isFetching,
          onCancelFetch: () {
            _searchGen++;
            _stremioGen++;
            setState(() {
              _searching = false;
              _stremioFetching = false;
            });
          },
          providerChips: _providerChips,
          selectedSourceId: _selectedSourceId,
          chipsScrollController: _chipsScrollController,
          onChipTap: _onChipTap,
          onScrollBack: () {
            _chipsScrollController.animateTo(
              (_chipsScrollController.offset - 160).clamp(
                0.0,
                _chipsScrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
            );
          },
          onScrollForward: () {
            _chipsScrollController.animateTo(
              (_chipsScrollController.offset + 160).clamp(
                0.0,
                _chipsScrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
            );
          },
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
          cacheRefreshToken:
              Object.hash(_openToken, _results.length, _searching),
          filterEnableBlur: false,
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildList(torrents, stremio)),
      ],
    );
  }

  List<Map<String, dynamic>> get _visibleStremioStreams {
    final filtered = _filteredStremio;
    if (_kindFilter != 'stremio') return filtered;
    if (_selectedSourceId == 'all_stremio') return filtered;
    return filtered
        .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
        .toList();
  }

  // Stable-ish token so cache line can refresh when panel content changes.
  int get _openToken => identityHashCode(this);

  Widget _buildList(
    List<TorrentResult> torrents,
    List<Map<String, dynamic>> stremio,
  ) {
    final count = torrents.length + stremio.length;
    if (_isFetching && count == 0) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    if (_error != null && count == 0) {
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
                onPressed: () {
                  if (_showsTorrents) unawaited(_runTorrentSearch());
                  if (_showsStremio) unawaited(_fetchStremioStreams());
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (count == 0) {
      return Center(
        child: Text(
          'No matching sources',
          style: TextStyle(
            color: ForjaShellColors.cinematic.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    final showAddonName = _showsMerged || _selectedSourceId == 'all_stremio';

    _scheduleScrollToCurrent();

    final currentIndex = _currentItemIndex(torrents, stremio);

    return ListView.separated(
      controller: _listScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
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

        final s = stremio[i - torrents.length];
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
