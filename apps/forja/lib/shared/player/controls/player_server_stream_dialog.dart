import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:rust/rust.dart';

/// Two-column Sources dialog — left servers, right streams for the selected server.
///
/// Used by ExoPlayer (phone + Android TV). MediaKit keeps its accordion panel.
class PlayerServerStreamDialog {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    final wasShowing = _entry != null;
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
    if (wasShowing) playerMenuRestoreReturnFocus();
  }

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic>? providers,
    required String? currentProviderId,
    required String? currentUrl,
    required List<StreamSource>? currentSources,
    required ValueListenable<Map<String, List<StreamSource>>>
        providerSourcesCache,
    required Future<List<StreamSource>?> Function(
      String providerId, {
      bool forceRefresh,
    }) onLoadServer,
    required Future<void> Function(
      String providerId,
      StreamSource source,
      int index,
    ) onSelectStream,
    required Future<bool> Function(
      StreamSource source,
      int index, [
      String? providerId,
    ]) onCheckStream,
    Movie? movie,
    BuildContext? anchorContext,
  }) async {
    final hasProviders = providers != null && providers.isNotEmpty;
    final hasSources = currentSources != null && currentSources.isNotEmpty;
    if (!hasProviders && !hasSources) {
      ForjaToast.warning(
        'No streams available',
        duration: const Duration(seconds: 1),
      );
      return;
    }

    playerMenuCaptureReturnFocus(context);
    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerStreamMenu.dismiss();
    PlayerEpisodePanel.dismiss();
    PlayerHubEpisodePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();
    playerChromeCancelSeekScrubs();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    void close() => dismiss();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (ctx, _) => _ServerStreamDialogOverlay(
          providers: providers,
          currentProviderId: currentProviderId,
          currentUrl: currentUrl,
          currentSources: currentSources,
          providerSourcesCache: providerSourcesCache,
          onLoadServer: onLoadServer,
          onSelectStream: onSelectStream,
          onCheckStream: onCheckStream,
          movie: movie,
          onClose: close,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

class _ServerStreamDialogOverlay extends StatefulWidget {
  const _ServerStreamDialogOverlay({
    required this.providers,
    required this.currentProviderId,
    required this.currentUrl,
    required this.currentSources,
    required this.providerSourcesCache,
    required this.onLoadServer,
    required this.onSelectStream,
    required this.onCheckStream,
    required this.onClose,
    this.movie,
  });

  final Map<String, dynamic>? providers;
  final String? currentProviderId;
  final String? currentUrl;
  final List<StreamSource>? currentSources;
  final ValueListenable<Map<String, List<StreamSource>>> providerSourcesCache;
  final Future<List<StreamSource>?> Function(
    String providerId, {
    bool forceRefresh,
  }) onLoadServer;
  final Future<void> Function(
    String providerId,
    StreamSource source,
    int index,
  ) onSelectStream;
  final Future<bool> Function(
    StreamSource source,
    int index, [
    String? providerId,
  ]) onCheckStream;
  final Movie? movie;
  final VoidCallback onClose;

  @override
  State<_ServerStreamDialogOverlay> createState() =>
      _ServerStreamDialogOverlayState();
}

class _ServerStreamDialogOverlayState extends State<_ServerStreamDialogOverlay> {
  final bool _open = true;
  late String? _selectedServerId;
  final Set<String> _loadingServers = {};
  final Set<String> _failedServers = {};
  final Map<String, PlayerSourceStatus> _urlStatuses = {};
  final Map<String, int> _loadGens = {};

  @override
  void initState() {
    super.initState();
    _selectedServerId = widget.currentProviderId;
    if (_selectedServerId == null || _selectedServerId!.isEmpty) {
      final entries = _orderedServers();
      if (entries.isNotEmpty) {
        _selectedServerId = entries.first.key;
      }
    }
    final id = _selectedServerId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_ensureServerLoaded(id));
      });
    }
  }

  List<MapEntry<String, dynamic>> _orderedServers() {
    final providers = widget.providers;
    if (providers == null || providers.isEmpty) {
      final current = widget.currentProviderId;
      if (current != null && current.isNotEmpty) {
        return [MapEntry(current, <String, dynamic>{'name': current})];
      }
      return const [];
    }
    return PlayerStreamMenu.serversForPanel(providers);
  }

  List<StreamSource> _streamsFor(String providerId) {
    if (providerId == widget.currentProviderId) {
      final live = widget.currentSources;
      if (live != null && live.isNotEmpty) return live;
    }
    return widget.providerSourcesCache.value[providerId] ??
        const <StreamSource>[];
  }

  PlayerSourceStatus _serverStatus(String providerId) {
    if (_loadingServers.contains(providerId)) {
      return PlayerSourceStatus.checking;
    }
    if (_failedServers.contains(providerId)) {
      return PlayerSourceStatus.failed;
    }
    if (_streamsFor(providerId).isNotEmpty) {
      return providerId == widget.currentProviderId
          ? PlayerSourceStatus.active
          : PlayerSourceStatus.ready;
    }
    return PlayerSourceStatus.unchecked;
  }

  Future<void> _ensureServerLoaded(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _streamsFor(providerId).isNotEmpty) {
      setState(() {
        _failedServers.remove(providerId);
        _selectedServerId = providerId;
      });
      return;
    }

    final gen = (_loadGens[providerId] ?? 0) + 1;
    _loadGens[providerId] = gen;
    setState(() {
      _selectedServerId = providerId;
      _loadingServers.add(providerId);
      _failedServers.remove(providerId);
    });

    try {
      final sources = await widget.onLoadServer(
        providerId,
        forceRefresh: forceRefresh,
      );
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() {
        _loadingServers.remove(providerId);
        if (sources == null || sources.isEmpty) {
          _failedServers.add(providerId);
        } else {
          _failedServers.remove(providerId);
        }
      });
      if (sources != null && sources.isNotEmpty) {
        unawaited(_probeStreams(providerId, sources));
      }
    } catch (_) {
      if (!mounted || (_loadGens[providerId] ?? 0) != gen) return;
      setState(() {
        _loadingServers.remove(providerId);
        _failedServers.add(providerId);
      });
    }
  }

  Future<void> _probeStreams(
    String providerId,
    List<StreamSource> sources,
  ) async {
    for (var i = 0; i < sources.length; i++) {
      if (!mounted || _selectedServerId != providerId) return;
      final source = sources[i];
      final playing = providerId == widget.currentProviderId &&
          streamSourceMatchesPlaying(
            source,
            playUrl: widget.currentUrl,
            catalogUrl: source.url,
          );
      if (playing) {
        setState(() => _urlStatuses[source.url] = PlayerSourceStatus.active);
        continue;
      }
      setState(() => _urlStatuses[source.url] = PlayerSourceStatus.checking);
      final ok = await widget.onCheckStream(source, i, providerId);
      if (!mounted || _selectedServerId != providerId) return;
      setState(() {
        _urlStatuses[source.url] =
            ok ? PlayerSourceStatus.ready : PlayerSourceStatus.failed;
      });
    }
  }

  String _serverLabel(String providerId) {
    final provider = widget.providers?[providerId];
    return PlayerProviderMenu.snackbarLabel(providerId, provider);
  }

  String? _serverBadge(String providerId) {
    final provider = widget.providers?[providerId];
    if (provider is AnimeEmbed) {
      return provider.category.toUpperCase();
    }
    return null;
  }

  Widget _buildServersColumn() {
    final servers = _orderedServers();
    if (servers.isEmpty) {
      return const Center(
        child: Text(
          'No servers',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 12),
      children: [
        for (final entry in servers)
          PlayerPopupListTile(
            label: _serverLabel(entry.key),
            badge: _serverBadge(entry.key),
            selected: entry.key == _selectedServerId,
            status: _serverStatus(entry.key),
            onTap: () => unawaited(_ensureServerLoaded(entry.key)),
          ),
      ],
    );
  }

  Widget _buildStreamsColumn() {
    final serverId = _selectedServerId;
    if (serverId == null || serverId.isEmpty) {
      return const Center(
        child: Text(
          'Select a server',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    if (_loadingServers.contains(serverId)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PlayerPopupTokens.accent,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Checking server…',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final streams = _streamsFor(serverId);
    if (streams.isEmpty) {
      final failed = _failedServers.contains(serverId);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              failed ? 'No streams found' : 'Tap the server to check',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => unawaited(
                _ensureServerLoaded(serverId, forceRefresh: true),
              ),
              child: Text(
                failed ? 'Retry' : 'Check',
                style: const TextStyle(color: PlayerPopupTokens.accent),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 12),
      children: [
        for (var i = 0; i < streams.length; i++)
          Builder(
            builder: (_) {
              final source = streams[i];
              final playing = serverId == widget.currentProviderId &&
                  (streamSourceMatchesPlaying(
                        source,
                        playUrl: widget.currentUrl,
                        catalogUrl: source.url,
                      ) ||
                      (widget.currentUrl == source.url));
              final status = playing
                  ? PlayerSourceStatus.active
                  : (_urlStatuses[source.url] ?? PlayerSourceStatus.unchecked);
              final type = source.type.trim().toUpperCase();
              return PlayerPopupListTile(
                label: source.title.trim().isEmpty
                    ? 'Stream ${i + 1}'
                    : source.title,
                badge: type.isEmpty ? null : type,
                badgeColor: playerSourceBadgeColor(type),
                selected: playing,
                status: status,
                onTap: () async {
                  PlayerServerStreamDialog.dismiss();
                  await widget.onSelectStream(serverId, source, i);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: 'Sources',
          onClose: widget.onClose,
          leading: Icon(
            Icons.layers_outlined,
            color: ForjaShellColors.cinematic.textSecondary,
            size: 18,
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
                      child: Text(
                        'Servers',
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(child: _buildServersColumn()),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: PlayerPopupTokens.border,
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 14, 0),
                      child: Text(
                        _selectedServerId == null
                            ? 'Streams'
                            : 'Streams · ${_serverLabel(_selectedServerId!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: widget.providerSourcesCache,
                        builder: (context, _) => _buildStreamsColumn(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = playerTvUsesCenteredDialogs(context);
    if (!tv) {
      return playerOverlayShell(
        context: context,
        isOpen: _open,
        onClose: widget.onClose,
        enableBlur: false,
        child: _buildBody(),
      );
    }

    if (!_open) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.88).clamp(560.0, 960.0);
    final maxHeight = size.height * 0.82;

    return PlayerPopupPanel.tvFocusableOverlay(
      overlayContext: context,
      onDismiss: widget.onClose,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: maxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PlayerPopupTokens.shellBg,
                      borderRadius: BorderRadius.circular(
                        PlayerPopupTokens.shellRadius,
                      ),
                      border: Border.all(color: PlayerPopupTokens.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        PlayerPopupTokens.shellRadius,
                      ),
                      child: playerSidePanelTvScope(
                        context: context,
                        onClose: widget.onClose,
                        child: FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: _buildBody(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
