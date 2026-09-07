part of '../live_sports_hub_page.dart';

abstract final class _IptvSportsPanelCopy {
  static const empty = 'No channels matched this event';

  static String searching(String phase) {
    final p = phase.trim();
    if (p.isEmpty) return 'Searching channels…';
    return 'Searching $p…';
  }

  static String partial(int n, String phase) {
    final count = n == 1 ? '1 channel' : '$n channels';
    final p = phase.trim();
    if (p.isEmpty) return '$count found · still searching…';
    return '$count found · checking $p…';
  }

  static String ready(int n) {
    if (n <= 0) return empty;
    return n == 1 ? '1 channel ready' : '$n channels ready';
  }
}

class _IptvSportsChannelsPanelController extends ChangeNotifier {
  _IptvSportsChannelsPanelController({
    required this.match,
    this.panelTitle = 'Forja Sports',
    this.emptyMessage = _IptvSportsPanelCopy.empty,
    this.searchingHint = 'Matching channels from your portal',
    this.iptvCtrl,
  }) {
    healthProbe = IptvLazyUrlHealthProbe(
      delay: const Duration(milliseconds: 500),
      onResult: _mirrorProbeToCatalog,
    );
    unawaited(_hydrateIptvHealthCache());
  }

  final _StreamedMatch match;
  final String panelTitle;
  final String emptyMessage;
  final String searchingHint;
  final IptvController? iptvCtrl;
  final List<IptvPlaySource> sources = [];
  late final IptvLazyUrlHealthProbe healthProbe;
  bool searching = true;
  String searchPhase = '';
  _LiveBroadcastHints? broadcastHints;
  bool broadcastHintsLoading = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _mirrorProbeToCatalog(String key, bool ok) {
    final ctrl = iptvCtrl;
    if (ctrl == null || !ok) return;
    if (!sources.any((s) => (s.streamId ?? '').trim() == key)) return;
    if (ctrl.streamHealth[key] == true) return;
    ctrl.streamHealth[key] = ok;
    if (ok) {
      ctrl.aliveStreamIds = {...ctrl.aliveStreamIds, key};
    }
    ctrl.notifyListeners();
  }

  Future<void> _hydrateIptvHealthCache() async {
    final ctrl = iptvCtrl;
    final portal = ctrl?.activePortal;
    if (ctrl == null || portal == null) return;
    if (ctrl.aliveCheckedAt != null) return;
    final snap = await IptvAliveStore.load(
      IptvAliveStore.portalKey(portal.portal),
    );
    if (_disposed || snap == null) return;
    ctrl.aliveStreamIds = snap.aliveIds;
    ctrl.aliveCheckedAt = snap.checkedAt;
    for (final id in snap.aliveIds) {
      ctrl.streamHealth[id] = true;
    }
    ctrl.notifyListeners();
  }

  void beginSearching([String phase = '']) {
    if (_disposed) return;
    searching = true;
    final next = phase.trim();
    if (next.isNotEmpty) searchPhase = next;
    notifyListeners();
  }

  void resetForLoad() {
    if (_disposed) return;
    sources.clear();
    searching = false;
    searchPhase = '';
    broadcastHints = null;
    broadcastHintsLoading = false;
    notifyListeners();
  }

  void beginBroadcastHintsLoad() {
    if (_disposed) return;
    broadcastHintsLoading = true;
    broadcastHints = null;
    notifyListeners();
  }

  void setBroadcastHints(_LiveBroadcastHints hints) {
    if (_disposed) return;
    broadcastHints = hints;
    broadcastHintsLoading = false;
    notifyListeners();
  }

  void setSearchPhase(String phase) {
    if (_disposed) return;
    final next = phase.trim();
    if (searchPhase == next) return;
    searchPhase = next;
    notifyListeners();
  }

  void appendSources(Iterable<IptvPlaySource> next) {
    if (_disposed) return;
    final seen = <String>{
      for (final s in sources)
        () {
          final id = (s.streamId ?? '').trim();
          if (id.isNotEmpty) return 'id:$id';
          final url = s.url.trim();
          return url.isEmpty ? '' : 'url:$url';
        }(),
    }..remove('');
    var added = false;
    for (final s in next) {
      final id = (s.streamId ?? '').trim();
      final url = s.url.trim();
      final key = id.isNotEmpty
          ? 'id:$id'
          : (url.isEmpty ? '' : 'url:$url');
      if (key.isEmpty || !seen.add(key)) continue;
      sources.add(s);
      added = true;
    }
    if (added) notifyListeners();
  }

  void finishSearching() {
    if (_disposed) return;
    if (!searching) return;
    searching = false;
    searchPhase = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    healthProbe.dispose();
    super.dispose();
  }
}

/// Right-side overlay shell — dismiss clears any leftover focus claim.
abstract final class _IptvSportsChannelsPanel {
  static void dismiss() {
    ShellTvFocusCoordinator.setSourcesPanelDismiss(null);
  }
}

class _IptvSportsChannelSheetRow extends StatelessWidget {
  const _IptvSportsChannelSheetRow({
    required this.source,
    required this.healthProbe,
    this.iptvCtrl,
    required this.onTap,
    this.tvItemIndex,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onLeftEdge,
    this.hideCategorySubtitle = false,
  });

  final IptvPlaySource source;
  final IptvLazyUrlHealthProbe healthProbe;
  final IptvController? iptvCtrl;
  final VoidCallback onTap;
  final int? tvItemIndex;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  /// When the Live TV category rail is visible, skip repeating category on the row.
  final bool hideCategorySubtitle;

  bool get _isLivePluginRow =>
      source.liveSourceKind == IptvLiveSourceKind.liveEngine ||
      source.liveSourceKind == IptvLiveSourceKind.stremio;

  bool get _isPortalIptvRow =>
      source.liveSourceKind == IptvLiveSourceKind.iptvXtream ||
      source.liveSourceKind == IptvLiveSourceKind.iptvStalker;

  bool? _portalCatalogHealth() {
    final id = (source.streamId ?? '').trim();
    if (id.isEmpty || iptvCtrl == null) return null;
    return iptvCtrl!.healthFor(id);
  }

  IptvStream? get _epgStream {
    final streamId = (source.streamId ?? '').trim();
    final epgId = (source.epgChannelId ?? '').trim();
    if (streamId.isEmpty && epgId.isEmpty) return null;
    return IptvStream(
      streamId: streamId,
      name: source.chromeTitle,
      icon: source.logoUrl ?? '',
      categoryId: '',
      containerExt: 'ts',
      kind: 'live',
      epgChannelId: epgId,
    );
  }

  Widget? _epgFooter() {
    final ctrl = iptvCtrl;
    final stream = _epgStream;
    if (ctrl == null || stream == null) return null;
    return _IptvSportsEpgNowRow(stream: stream, ctrl: ctrl);
  }

  String get _probeKey => iptvLiveSourceProbeKey(source);

  void _recordPortalHealth(IptvController ctrl, String id, bool ok) {
    if (ctrl.streamHealth[id] == ok) return;
    ctrl.streamHealth[id] = ok;
    if (ok) {
      ctrl.aliveStreamIds = {...ctrl.aliveStreamIds, id};
    } else if (ctrl.aliveStreamIds.contains(id)) {
      ctrl.aliveStreamIds = {...ctrl.aliveStreamIds}..remove(id);
    }
    ctrl.notifyListeners();
  }

  /// Portal Live TV — resolve via Xtream/Stalker then alive-check (same as IPTV
  /// Live hover). Never HTTP-probe the catalog template URL (false Unavailable).
  Future<bool> _portalHoverProbe() async {
    final ctrl = iptvCtrl;
    final id = (source.streamId ?? '').trim();
    if (ctrl == null || id.isEmpty) return true;

    final known = ctrl.healthFor(id);
    if (known != null) return known;

    final portal = ctrl.activePortal;
    final stream = _epgStream;
    if (portal == null || stream == null) return true;

    try {
      final url = await IptvClient.resolvePlayUrl(
        portal.portal,
        stream,
        section: 'live',
      );
      if (url == null || url.isEmpty) {
        _recordPortalHealth(ctrl, id, false);
        return false;
      }
      final ok = await IptvAliveChecker.checkOne(url);
      _recordPortalHealth(ctrl, id, ok);
      return ok;
    } catch (_) {
      _recordPortalHealth(ctrl, id, false);
      return false;
    }
  }

  Future<bool> _hoverProbe() async {
    final probed = healthProbe.healthFor(_probeKey);
    if (probed != null) return probed;
    final id = (source.streamId ?? '').trim();
    if (id.isNotEmpty && iptvCtrl != null) {
      final fromCatalog = iptvCtrl!.healthFor(id);
      if (fromCatalog == true) return true;
    }
    // Stalker sports rows have no durable URL until create_link at play.
    if (source.url.trim().isEmpty) return true;
    final probeUrl = iptvLiveSourceProbeUrl(source);
    if (probeUrl == null) return true;
    return healthProbe.checkNow(_probeKey, probeUrl);
  }

  Future<bool> _liveHoverProbe() async {
    final probed = healthProbe.healthFor(_probeKey);
    if (probed != null) return probed;

    final bare = iptvLiveSourceProbeUrl(source);
    if (bare != null) {
      return healthProbe.checkNow(_probeKey, bare);
    }

    // Signed Streamed / WatchFooty / Stremio — bare alive-check false-fails
    // without Referer; probe the same way Sources panel does.
    final url = source.url.trim();
    final stremioHttp = source.liveSourceKind == IptvLiveSourceKind.stremio &&
        (url.toLowerCase().startsWith('http://') ||
            url.toLowerCase().startsWith('https://'));
    if (iptvLiveEnginePlayUrlReady(url) || stremioHttp) {
      final headers = LiveGoatUnlock.withWftyPlaybackReferer(
        url,
        Map<String, String>.from(source.headers),
      );
      final ok = await probeStreamSourceUrl(
        url,
        headers.isEmpty ? null : headers,
      );
      healthProbe.remember(_probeKey, ok);
      return ok;
    }

    // Embed / pending catalog pages — pre-9e66afdf: selectable, not dead.
    return iptvLiveSourceProbeSkipped(source);
  }

  String? _liveQualityBadge(IptvPlaySource source) {
    for (final text in [source.detail, source.label]) {
      final raw = (text ?? '').trim();
      if (raw.isEmpty) continue;
      final match = RegExp(
        r'\b(FHD|UHD|HD|4K|SD)\b',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null) return match.group(1)!.toUpperCase();
    }
    if (source.liveStreamHd) return 'HD';
    return null;
  }

  String? _liveEmbedHost(IptvPlaySource source) {
    final embed = (source.liveEngineEmbedUrl ?? '').trim();
    final url = source.url.trim();
    final probe = embed.isNotEmpty
        ? embed
        : (url.startsWith('pending:') ? '' : url);
    final host = Uri.tryParse(probe)?.host;
    if (host == null || host.isEmpty) return null;
    return host;
  }

  Widget _logo(BuildContext context) {
    const size = 40.0;
    final url = (source.logoUrl ?? '').trim();
    if (url.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.tv_rounded,
          color: ForjaShellColors.sectionAccent,
          size: size * 0.55,
        ),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (size * dpr).round().clamp(1, 512);
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: cacheW,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Icon(
          Icons.tv_rounded,
          color: ForjaShellColors.sectionAccent,
          size: size * 0.55,
        ),
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return Icon(
            Icons.tv_rounded,
            color: Colors.white24,
            size: size * 0.55,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Do not ListenableBuilder(healthProbe / iptvCtrl) around the tile —
    // mid-hover notifyListeners remounts MouseRegion and the status strip
    // never settles. Tile state + probeHealthCache seed are enough.
    final cachedHealth = _isPortalIptvRow
        ? _portalCatalogHealth()
        : healthProbe.healthFor(_probeKey);
    if (_isLivePluginRow) {
      final provider = (source.liveProviderBadge ?? '').trim().isNotEmpty
          ? source.liveProviderBadge!.trim()
          : (source.pickerSubtitle ?? '').trim();
      final qualityBadge = _liveQualityBadge(source);
      final viewers = source.liveViewerCount;
      final host = _liveEmbedHost(source);
      return SourcesPanelChannelTile(
        key: ValueKey('live-probe-$_probeKey'),
        title: source.pickerTitle,
        provider: provider.isEmpty ? null : provider,
        footer: host == null
            ? null
            : Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 11,
                ),
              ),
        badges: [
          ?qualityBadge,
        ],
        viewerCount: viewers > 0 ? viewers : null,
        onPlay: onTap,
        tvItemIndex: tvItemIndex,
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        onUpEdge: onUpEdge,
        onLeftEdge: onLeftEdge,
        // Always wire — embed/pending light green; ready URLs real-check.
        onHoverProbe: _liveHoverProbe,
        probeHealthCache: cachedHealth,
      );
    }
    final subtitle = hideCategorySubtitle ? null : source.pickerSubtitle;
    return SourcesPanelChannelTile(
      key: ValueKey('live-probe-$_probeKey'),
      title: source.pickerTitle,
      provider: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      leading: _logo(context),
      footer: _epgFooter(),
      badges: const [],
      onPlay: onTap,
      tvItemIndex: tvItemIndex,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      onHoverProbe: _isPortalIptvRow ? _portalHoverProbe : _hoverProbe,
      probeHealthCache: cachedHealth,
    );
  }
}

class _IptvSportsEpgNowRow extends StatelessWidget {
  const _IptvSportsEpgNowRow({required this.stream, required this.ctrl});

  final IptvStream stream;
  final IptvController ctrl;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpgEntry>>(
      future: ctrl.epgFor(stream),
      builder: (_, snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        final now = data.firstWhere((e) => e.isNow, orElse: () => data.first);
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: now.isNow
                    ? const Color(0xFFEF4444)
                    : IptvShellStyle.accent.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                now.isNow ? 'NOW' : 'NEXT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                now.title.isEmpty ? '-' : now.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Stream label helpers for play dispatch (legacy sheet UI deleted).
abstract final class _StreamedStreamSheet {
  static String sourceLabel(String source) {
    if (source.isEmpty) return '';
    return source[0].toUpperCase() + source.substring(1);
  }

  static String serverLabelFor(_StreamedMatch match) {
    if (match.isMut) return 'Mut';
    return _liveForjaPluginDisplayName(match.livePluginId);
  }

  static String streamTitle(_StreamedStream stream, String sourceLabel) {
    if (sourceLabel.isNotEmpty && stream.language.isNotEmpty) {
      return '$sourceLabel · ${stream.language}';
    }
    if (sourceLabel.isNotEmpty) return sourceLabel;
    if (stream.language.isNotEmpty) return stream.language;
    if (stream.streamNo > 0) return 'Stream ${stream.streamNo}';
    return 'Stream';
  }
}

class _LiveCancellableLoadingDialog extends StatefulWidget {
  const _LiveCancellableLoadingDialog({
    required this.messageListenable,
    required this.onCancel,
  });

  final ValueNotifier<String> messageListenable;
  final VoidCallback onCancel;

  @override
  State<_LiveCancellableLoadingDialog> createState() =>
      _LiveCancellableLoadingDialogState();
}

class _LiveCancellableLoadingDialogState
    extends State<_LiveCancellableLoadingDialog> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'live-loading-cancel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_cancelFocus.canRequestFocus) _cancelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    try {
      if (_cancelFocus.hasFocus) _cancelFocus.unfocus();
    } catch (_) {}
    _cancelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: ForjaShellColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ForjaShellColors.cinematic.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: widget.messageListenable,
              builder: (_, message, _) => Text(
                message,
                style: const TextStyle(color: ForjaShellColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            if (tvFocus)
              shellFocusableTap(
                context: context,
                onTap: widget.onCancel,
                focusNode: _cancelFocus,
                borderRadius: 24,
                scaleOnFocus: ShellTokens.focusActiveScale,
                ensureVisibleMode: ShellTvEnsureVisibleMode.item,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}
