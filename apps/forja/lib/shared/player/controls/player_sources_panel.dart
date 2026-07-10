import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
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
    Uint8List? frozenFrame,
  }) {
    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    _entry = OverlayEntry(
      builder: (_) => _PlayerSourcesOverlay(
        movie: movie,
        season: season,
        episode: episode,
        currentMagnet: currentMagnet,
        onTorrentSelected: onTorrentSelected,
        onClose: dismiss,
        frozenFrame: frozenFrame,
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
    required this.onClose,
    this.season,
    this.episode,
    this.currentMagnet,
    this.frozenFrame,
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? currentMagnet;
  final Future<void> Function(TorrentResult result) onTorrentSelected;
  final VoidCallback onClose;
  final Uint8List? frozenFrame;

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
      frozenFrame: widget.frozenFrame,
      child: _PlayerSourcesBody(
        movie: widget.movie,
        season: widget.season,
        episode: widget.episode,
        currentMagnet: widget.currentMagnet,
        onTorrentSelected: widget.onTorrentSelected,
        onClose: widget.onClose,
      ),
    );
  }
}

class _PlayerSourcesBody extends StatefulWidget {
  const _PlayerSourcesBody({
    required this.movie,
    required this.onTorrentSelected,
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
  final VoidCallback onClose;

  @override
  State<_PlayerSourcesBody> createState() => _PlayerSourcesBodyState();
}

class _PlayerSourcesBodyState extends State<_PlayerSourcesBody> {
  final _settings = SettingsService();
  final _chipsScrollController = ScrollController();

  List<TorrentResult> _results = [];
  bool _searching = false;
  int _searchGen = 0;
  String? _error;
  String? _switchingMagnet;

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchGen++;
    _chipsScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final sort = await _settings.getSortPreference();
    final jackett = await _settings.isJackettConfigured();
    final prowlarr = await _settings.isProwlarrConfigured();
    final local = PlatformPlayback.capabilities.localTorrentEngine;
    if (!mounted) return;
    setState(() {
      _sortPreference = sort;
      _jackettConfigured = jackett;
      _prowlarrConfigured = prowlarr;
      _localTorrentEngine = local;
    });
    await _runSearch();
  }

  List<TorrentResult> get _filtered {
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

  Set<String> get _availableQualities =>
      collectQualities(_results.map((r) => r.name));
  Set<String> get _availableLanguages =>
      collectLanguages(_results.map((r) => r.name));
  Set<String> get _availableTech =>
      collectTechTags(_results.map((r) => r.name));
  Set<String> get _availableSizes => collectSizeRanges(
        _results.map(
          (r) => r.sizeInBytes > 0
              ? r.sizeInBytes
              : TorrentReleaseMetadata.parseSizeBytes(r.size),
        ),
      );

  List<Map<String, dynamic>> get _providerChips {
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

  Future<void> _runSearch() async {
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
        found = await _searchJackett(isTv: isTv, season: season, episode: episode);
      } else if (_selectedSourceId == 'prowlarr') {
        found = await _searchProwlarr(isTv: isTv, season: season, episode: episode);
      } else if (isTv) {
        found = await _searchForjaTv(season: season, episode: episode);
      } else {
        found = await _searchForjaMovie();
      }

      if (!mounted || gen != _searchGen) return;
      setState(() {
        _results = found;
        _searching = false;
        if (found.isEmpty) {
          _error = 'No torrents found';
        }
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searching = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
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
    _runSearch();
  }

  Future<void> _select(TorrentResult result) async {
    final current = widget.currentMagnet?.toLowerCase();
    if (current != null &&
        current.isNotEmpty &&
        result.magnet.toLowerCase() == current) {
      widget.onClose();
      return;
    }
    setState(() => _switchingMagnet = result.magnet);
    try {
      await widget.onTorrentSelected(result);
      widget.onClose();
    } catch (_) {
      if (mounted) setState(() => _switchingMagnet = null);
    }
  }

  String? get _episodeLabel {
    if (widget.movie.mediaType != 'tv') return null;
    final s = (widget.season ?? 1).toString().padLeft(2, '0');
    final e = (widget.episode ?? 1).toString().padLeft(2, '0');
    return 'S${s}E$e';
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ShellTokens.isTvLayout(context);
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TorrentSourcesPanelChrome(
          onClose: widget.onClose,
          kindFilter: _kindFilter,
          showTorrents: true,
          showStremio: false,
          showNuvio: false,
          onKindChanged: (v) => setState(() => _kindFilter = v),
          resultCount: filtered.length,
          episodeLabel: _episodeLabel,
          isFetching: _searching,
          onCancelFetch: () {
            _searchGen++;
            setState(() => _searching = false);
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
          showAudioFilters: true,
          activeAudioFilters: _audioFilters,
          onAudioFiltersChanged: (v) => setState(() => _audioFilters = v),
          sortPreference: _sortPreference,
          onSortChanged: (val) {
            setState(() => _sortPreference = val);
            _settings.setSortPreference(val);
          },
          showCacheLine: _localTorrentEngine,
          cacheRefreshToken: Object.hash(_openToken, _results.length, _searching),
        ),
        SizedBox(height: isTv ? 10 : 8),
        Expanded(child: _buildList(filtered)),
      ],
    );
  }

  // Stable-ish token so cache line can refresh when panel content changes.
  int get _openToken => identityHashCode(this);

  Widget _buildList(List<TorrentResult> filtered) {
    if (_searching && filtered.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    if (_error != null && filtered.isEmpty) {
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
              TextButton(onPressed: _runSearch, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No matching torrents',
          style: TextStyle(
            color: ForjaShellColors.cinematic.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    final current = widget.currentMagnet?.toLowerCase();
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = filtered[i];
        final isCurrent =
            current != null && r.magnet.toLowerCase() == current;
        final switching = _switchingMagnet == r.magnet;
        final tile = TorrentSourceTile(
          result: r,
          highlightStart: isCurrent,
          onPlay: () => _select(r),
        );
        if (!switching) return tile;
        return Stack(
          children: [
            Opacity(opacity: 0.55, child: IgnorePointer(child: tile)),
            const Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
