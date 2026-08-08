part of 'iptv_controller.dart';

mixin _IptvControllerLive on ChangeNotifier {
  IptvController get _c => this as IptvController;

  Future<void> startAliveCheck({bool force = false}) async {
    final p = _c.activePortal;
    final section = _c.activeSection;
    if (p == null || section != IptvSection.live) return;
    // Stalker create_link is per-stream and expires — no bulk URL probe.
    if (p.platform == IptvPortalPlatform.stalker) return;
    if (_c.isVerifyingAlive) return;
    if (!force && _c.aliveCheckedAt != null) return;

    final pkey = IptvAliveStore.portalKey(p.portal);
    final entries = _c.browserAllStreams
        .map((s) => MapEntry(s.streamId, IptvClient.streamUrl(p.portal, s)))
        .where((e) => e.value.isNotEmpty)
        .toList();
    if (entries.isEmpty) return;

    _c.isVerifyingAlive = true;
    _c.aliveChecked = 0;
    _c.aliveTotal = entries.length;
    _c.aliveCount = 0;
    final aliveSet = <String>{};
    _c._aliveCancel = false;
    notifyListeners();

    await IptvAliveChecker.launchCheck(
      streams: entries,
      onResult: (id, alive) async {
        if (alive) aliveSet.add(id);
        _c.streamHealth[id] = alive;
      },
      onProgress: (prog) async {
        _c.aliveChecked = prog.checked;
        _c.aliveTotal = prog.total;
        _c.aliveCount = prog.alive;
        notifyListeners();
      },
      onDone: () async {
        _c.aliveStreamIds = aliveSet;
        _c.aliveCheckedAt = DateTime.now().millisecondsSinceEpoch;
        await IptvAliveStore.save(
          pkey,
          AliveSnapshot(
            checkedAt: _c.aliveCheckedAt!,
            aliveIds: aliveSet,
          ),
        );
        _c.isVerifyingAlive = false;
        notifyListeners();
      },
      isCancelled: () => _c._aliveCancel,
    );
    if (_c._aliveCancel) {
      _c.isVerifyingAlive = false;
      notifyListeners();
    }
  }

  void stopAliveCheck() {
    _c._aliveCancel = true;
    _c.isVerifyingAlive = false;
    notifyListeners();
  }

  Future<void> recheckAlive() async {
    final p = _c.activePortal;
    if (p == null) return;
    await IptvAliveStore.clear(IptvAliveStore.portalKey(p.portal));
    _c.aliveStreamIds = const {};
    _c.aliveCheckedAt = null;
    _c.streamHealth.clear();
    _c._healthInFlight.clear();
    _c._healthQueue.clear();
    _c.cancelAllLazyChecks();
    notifyListeners();
    await startAliveCheck(force: true);
  }
  Future<void> openSeries(IptvStream s) async {
    final p = _c.activePortal;
    if (p == null) return;
    _c.activeSeries = s;
    _c.activeMovie = null;
    _c.view = IptvView.episodeList;
    _c.isLoading = true;
    _c.error = null;
    _c.episodes = const [];
    notifyListeners();
    try {
      _c.episodes = await IptvClient.seriesEpisodes(p.portal, s.streamId);
    } catch (e) {
      _c.error = '$e';
    } finally {
      _c.isLoading = false;
      notifyListeners();
    }
  }

  void openMovie(IptvStream s) {
    if (_c.activePortal == null) return;
    _c.activeMovie = s;
    _c.activeSeries = null;
    _c.episodes = const [];
    _c.error = null;
    _c.view = IptvView.movieDetails;
    notifyListeners();
  }
}
