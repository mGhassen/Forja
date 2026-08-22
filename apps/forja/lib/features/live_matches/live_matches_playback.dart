part of 'live_matches_screen.dart';

mixin _LiveMatchesPlayback on ConsumerState<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

  /// Leanback TV: never offer PPV / Streamed / Mut embed rows — only native.
  bool get _tvNativeLiveOnly =>
      ShellScope.metricsOf(context).usesTvDensity;

  /// Stremio catalog/stream fallback — All, Stremio, Forja Sports only.
  bool get _offerStremioPlayFallback =>
      _s._server == _LiveMatchesServer.all ||
      _s._server == _LiveMatchesServer.stremio ||
      _s._server == _LiveMatchesServer.iptvSports;

  /// Loading dialog that Back / Cancel can dismiss. Returns `false` if cancelled.
  Future<bool> _runWithCancellableLoading(
    String message,
    Future<void> Function() action,
  ) async {
    if (!mounted) return false;
    var cancelled = false;
    var closingOurselves = false;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          // Imperative pop in [finally] also invokes this - don't treat that
          // as user cancel or play never continues after a successful resolve.
          if (didPop && !closingOurselves) cancelled = true;
        },
        child: _LiveCancellableLoadingDialog(
          message: message,
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
    try {
      await action();
    } finally {
      if (mounted && !cancelled) {
        closingOurselves = true;
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }
    return !cancelled && mounted;
  }

  Future<void> _openMergedMatch(
    _DamiTvStream ppv,
    _StreamedMatch streamed,
  ) async {
    if (_s._server == _LiveMatchesServer.iptvSports) {
      await _openIptvSportsMatch(streamed);
      return;
    }
    if (_tvNativeLiveOnly) {
      await _openTvNativeSourcesOnly(streamed);
      return;
    }
    if (!mounted) return;
    final streams = <_StreamedStream>[];
    final ok = await _runWithCancellableLoading(
      'Loading PPV and Streamed sources…',
      () async {
        try {
          for (final source in streamed.sources) {
            streams.addAll(await _fetchStreamedStreams(source));
          }
        } catch (e) {
          debugPrint('[LiveMatches] Merged Streamed resolve error: $e');
        }
      },
    );
    if (!ok) return;

    final hasPpv = ppv.iframe.isNotEmpty;
    if (!hasPpv && streams.isEmpty) {
      ForjaToast.info('No streams available for this event');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MergedMatchStreamSheet(
        title: streamed.title.isNotEmpty ? streamed.title : ppv.name,
        ppv: hasPpv ? ppv : null,
        streamed: streams,
        onPpvSelected: () {
          Navigator.pop(context);
          unawaited(_openDamiTvStream(ppv));
        },
        onStreamedSelected: (stream) {
          Navigator.pop(context);
          unawaited(_openStreamedEmbed(streamed, stream));
        },
      ),
    );
  }

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    if (_s._server == _LiveMatchesServer.iptvSports || match.isIptvSports) {
      await _openIptvSportsMatch(match);
      return;
    }
    if (match.isStremio) {
      await _openStremioSportMatch(match);
      return;
    }
    if (_tvNativeLiveOnly) {
      await _openTvNativeSourcesOnly(match);
      return;
    }
    final catalogMatches = _streamedMatchesForEvent(match, _s._streamedMatches);
    if (catalogMatches.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    final choices = _catalogStreamChoices(catalogMatches);
    if (choices.isEmpty) {
      if (catalogMatches.any((m) => m.sportMatchGame != null)) {
        await _openIptvSportsMatch(match);
        return;
      }
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StreamedStreamSheet(
        match: match,
        choices: choices,
        onChoiceSelected: (choice) {
          Navigator.pop(context);
          unawaited(_playStreamChoice(match, choice));
        },
      ),
    );
  }

  List<_StreamedStreamChoice> _catalogStreamChoices(
    List<_StreamedMatch> catalogMatches,
  ) {
    final out = <_StreamedStreamChoice>[];
    final seen = <String>{};

    for (final m in catalogMatches) {
      final pluginLabel = m.isForjaLive
          ? _liveForjaPluginDisplayName(m.livePluginId).toLowerCase()
          : '';

      for (final stream in m.inlineStreams) {
        final url = stream.embedUrl.trim();
        if (url.isEmpty || !seen.add('url:$url')) continue;
        out.add(_StreamedStreamChoice(catalogMatch: m, stream: stream));
      }

      for (final ref in m.sources) {
        final key = 'ref:${m.livePluginId}:${ref.source}:${ref.id}';
        if (!seen.add(key)) continue;
        final label = pluginLabel.isNotEmpty ? pluginLabel : ref.source;
        out.add(
          _StreamedStreamChoice(
            catalogMatch: m,
            stream: _StreamedStream(
              id: ref.id,
              streamNo: 1,
              language: '',
              hd: false,
              embedUrl: '',
              source: label,
              viewers: 0,
            ),
          ),
        );
      }
    }
    return out;
  }

  Future<void> _playStreamChoice(
    _StreamedMatch anchor,
    _StreamedStreamChoice choice,
  ) async {
    if (!choice.needsResolve) {
      await _openStreamedEmbed(
        _forjaLivePlayMatch(anchor, choice.stream),
        choice.stream,
      );
      return;
    }

    final resolved = <_StreamedStream>[];
    final ok = await _runWithCancellableLoading('Resolving stream…', () async {
      resolved.addAll(
        await _resolveCatalogStreamChoice(choice.catalogMatch, choice.stream),
      );
    });
    if (!ok || !mounted) return;

    if (resolved.isEmpty) {
      ForjaToast.info('No streams available for this source');
      return;
    }
    if (resolved.length == 1) {
      await _openStreamedEmbed(
        _forjaLivePlayMatch(anchor, resolved.first),
        resolved.first,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StreamedStreamSheet(
        match: anchor,
        choices: [
          for (final stream in resolved)
            _StreamedStreamChoice(
              catalogMatch: choice.catalogMatch,
              stream: stream,
            ),
        ],
        onChoiceSelected: (picked) {
          Navigator.pop(context);
          unawaited(
            _openStreamedEmbed(
              _forjaLivePlayMatch(anchor, picked.stream),
              picked.stream,
            ),
          );
        },
      ),
    );
  }

  Future<List<_StreamedStream>> _resolveCatalogStreamChoice(
    _StreamedMatch catalogMatch,
    _StreamedStream placeholder,
  ) async {
    _StreamedSourceRef? ref;
    for (final s in catalogMatch.sources) {
      if (s.id == placeholder.id) {
        ref = s;
        break;
      }
    }
    if (ref == null) return const [];

    if (catalogMatch.isForjaLive) {
      return _forjaLiveStreamsFromSource(catalogMatch, ref);
    }
    return _fetchStreamedStreams(ref);
  }

  _StreamedMatch _forjaLivePlayMatch(
    _StreamedMatch anchor,
    _StreamedStream stream,
  ) {
    final url = stream.embedUrl.trim();
    if (url.isNotEmpty) {
      for (final m in _streamedMatchesForEvent(anchor, _s._streamedMatches)) {
        if (m.inlineStreams.any((s) => s.embedUrl.trim() == url)) return m;
      }
    }
    final sourceKey = stream.source.trim().toLowerCase();
    if (sourceKey.isNotEmpty) {
      for (final m in _streamedMatchesForEvent(anchor, _s._streamedMatches)) {
        if (!m.isForjaLive) continue;
        if (_liveForjaPluginDisplayName(m.livePluginId).toLowerCase() ==
            sourceKey) {
          return m;
        }
      }
    }
    return anchor;
  }

  String _streamPlaySubtitle(_StreamedMatch match, _StreamedStream stream) {
    final source = _StreamedStreamSheet.sourceLabel(stream.source);
    if (source.isNotEmpty) return source;
    return match.categoryLabel;
  }

  Future<List<_StreamedStream>> _forjaLiveStreamsFromSource(
    _StreamedMatch match,
    _StreamedSourceRef source,
  ) async {
    final pluginId = match.livePluginId.isNotEmpty
        ? match.livePluginId
        : 'live-streamed';
    final label = _liveForjaPluginDisplayName(pluginId).toLowerCase();

    if (pluginId == 'live-streamed') {
      final rows = await _fetchStreamedStreams(source);
      if (rows.isNotEmpty) return rows;
    }

    final rows = await EngineService.instance.runLivePlugin(
      pluginId: pluginId,
      action: 'resolve',
      params: {
        'matchId': source.id,
        'eventId': match.id,
        'source': source.source,
        'category': match.category,
        'title': match.title,
        'stream': '1',
      },
    );
    if (rows.isEmpty) return [];

    final out = <_StreamedStream>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row['webviewOnly'] == true) {
        final embed = (row['embedUrl'] ?? '').toString().trim();
        if (embed.isEmpty) continue;
        out.add(
          _StreamedStream(
            id: source.id,
            streamNo: i + 1,
            language: '',
            hd: false,
            embedUrl: embed,
            source: label,
            viewers: 0,
          ),
        );
        continue;
      }
      final url = (row['url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      final name = (row['name'] ?? row['title'] ?? label).toString().trim();
      out.add(
        _StreamedStream(
          id: source.id,
          streamNo: i + 1,
          language: '',
          hd: false,
          embedUrl: url,
          source: name.isEmpty ? label : name.toLowerCase(),
          viewers: 0,
        ),
      );
    }
    return out;
  }

  /// TV All (and any PPV/Streamed card path): picker = Forja Sports ∪ Stremio only.
  Future<void> _openTvNativeSourcesOnly(_StreamedMatch match) async {
    if (!mounted) return;
    final ctrl = ref.read(iptvControllerProvider);
    final portal = ctrl.activePortal;
    if (portal != null &&
        portal.portal.platform == IptvPortalPlatform.xtream) {
      await LiveMatchesIptvSportsConfig.ensureArmed(portalKey: portal.key);
    } else {
      await LiveMatchesIptvSportsConfig.ensureArmed();
    }
    if (!mounted) return;

    final espnPayload = _findEspnGameForMatch(match, _s._espnGames);
    final enriched = espnPayload == null
        ? match
        : _copyStreamedMatch(
            match,
            sportMatchGame: espnPayload,
            homeTeam: (espnPayload['homeTeam'] as String?)?.trim().isNotEmpty ==
                    true
                ? espnPayload['homeTeam'] as String
                : match.homeTeam,
            awayTeam: (espnPayload['awayTeam'] as String?)?.trim().isNotEmpty ==
                    true
                ? espnPayload['awayTeam'] as String
                : match.awayTeam,
          );

    final panel = _IptvSportsChannelsPanel.show(
      context: context,
      match: enriched,
      panelTitle: 'Sources',
      iptvCtrl: ctrl,
      onChannelSelected: (picked, all) {
        unawaited(_playIptvSportsSources(enriched, all, picked));
      },
    );
    panel.setSearchPhase('Forja Sports');

    Future<void> addForja() async {
      try {
        await _resolveIptvSportsStreams(
          enriched,
          onPartial: (batch) {
            if (panel.isDisposed) return;
            panel.appendSources([
              for (final s in batch)
                IptvPlaySource(
                  url: s.url,
                  label: s.label,
                  detail: _tvNativeSourceDetail('Forja Sports', s.detail),
                  logoUrl: s.logoUrl,
                  streamId: s.streamId,
                  headers: s.headers,
                  liveSourceKind: IptvLiveSourceKind.iptvXtream,
                ),
            ]);
          },
        );
      } catch (e) {
        debugPrint('[LiveMatches] TV Forja Sports resolve error: $e');
      }
    }

    Future<void> addStremio() async {
      if (!_offerStremioPlayFallback) return;
      try {
        final stremio = await _resolveStremioStreamsMatching(enriched);
        if (panel.isDisposed) return;
        panel.appendSources([
          for (final s in stremio)
            IptvPlaySource(
              url: s.url,
              label: s.label,
              detail: _tvNativeSourceDetail('Stremio', s.detail),
              logoUrl: s.logoUrl,
              streamId: s.streamId,
              headers: s.headers,
              liveSourceKind: IptvLiveSourceKind.stremio,
            ),
        ]);
      } catch (e) {
        debugPrint('[LiveMatches] TV Stremio resolve error: $e');
      }
    }

    // Serial on TV: parallel Forja Sports (Xtream + EPG) + Stremio OOMs leanback.
    await addForja();
    if (panel.isDisposed) return;
    panel.setSearchPhase('Stremio');
    await addStremio();
    if (!panel.isDisposed) panel.finishSearching();
  }

  String _tvNativeSourceDetail(String server, String? detail) {
    final d = (detail ?? '').trim();
    return d.isEmpty ? server : '$server · $d';
  }

  Future<List<IptvPlaySource>> _resolveStremioStreamsMatching(
    _StreamedMatch match,
  ) async {
    if (match.isStremio) {
      return _stremioPlaySourcesFor(match);
    }
    final catalog = await _fetchStremioSportMatches();
    final hits = catalog.where((m) => _sameStreamedEvent(match, m)).toList();
    if (hits.isEmpty) return const [];
    final out = <IptvPlaySource>[];
    final seenUrls = <String>{};
    for (final hit in hits.take(3)) {
      for (final s in await _stremioPlaySourcesFor(hit)) {
        if (!seenUrls.add(s.url)) continue;
        out.add(s);
      }
    }
    return out;
  }

  Future<List<IptvPlaySource>> _stremioPlaySourcesFor(
    _StreamedMatch match,
  ) async {
    final out = <IptvPlaySource>[];
    try {
      final raw = await StremioService().getStreams(
        baseUrl: match.stremioBaseUrl,
        type: match.stremioType,
        id: match.id,
      );
      for (final s in raw) {
        if (s is! Map) continue;
        final url = s['url']?.toString();
        if (!StremioService.isPlayableLiveUrl(url)) continue;
        final name = (s['name'] ?? s['title'] ?? 'Stream').toString().trim();
        out.add(
          IptvPlaySource(
            url: url!,
            label: name.isEmpty ? 'Stream' : name,
            headers: StremioService.liveStreamRequestHeaders(s),
            liveSourceKind: IptvLiveSourceKind.stremio,
          ),
        );
      }
    } catch (e) {
      debugPrint('[LiveMatches] Stremio stream error: $e');
    }
    return out;
  }

  Future<void> _openStremioSportMatch(_StreamedMatch match) async {
    if (!mounted) return;
    final sources = <IptvPlaySource>[];
    final ok = await _runWithCancellableLoading('Loading streams…', () async {
      sources.addAll(await _stremioPlaySourcesFor(match));
    });
    if (!ok) return;
    if (sources.isEmpty) {
      ForjaToast.info('No playable streams for this event');
      return;
    }
    if (!mounted) return;
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: sources,
        title: match.title,
        subtitle: match.categoryLabel,
        engineContext: BuiltInPlayerContext.live,
        liveSourceKind: IptvLiveSourceKind.stremio,
      ),
    );
  }

  Future<void> _openIptvSportsMatch(_StreamedMatch match) async {
    if (!mounted) return;
    final iptvCtrl = ref.read(iptvControllerProvider);
    final espnPayload = _findEspnGameForMatch(match, _s._espnGames);
    final enriched = espnPayload == null
        ? match
        : _copyStreamedMatch(
            match,
            sportMatchGame: espnPayload,
            homeTeam: (espnPayload['homeTeam'] as String?)?.trim().isNotEmpty ==
                    true
                ? espnPayload['homeTeam'] as String
                : match.homeTeam,
            awayTeam: (espnPayload['awayTeam'] as String?)?.trim().isNotEmpty ==
                    true
                ? espnPayload['awayTeam'] as String
                : match.awayTeam,
          );

    final panel = _IptvSportsChannelsPanel.show(
      context: context,
      match: enriched,
      iptvCtrl: iptvCtrl,
      onChannelSelected: (picked, all) {
        unawaited(_playIptvSportsSources(enriched, all, picked));
      },
    );
    panel.setSearchPhase('Forja Sports');

    try {
      await _resolveIptvSportsStreams(
        enriched,
        onPartial: (batch) {
          if (panel.isDisposed) return;
          panel.appendSources(batch);
        },
      );
    } catch (e) {
      debugPrint('[LiveMatches] IPTV sports resolve error: $e');
    } finally {
      if (!panel.isDisposed) panel.finishSearching();
    }
  }

  Future<void> _playIptvSportsSources(
    _StreamedMatch match,
    List<IptvPlaySource> sources,
    IptvPlaySource picked,
  ) async {
    if (!mounted) return;
    final ordered = <IptvPlaySource>[
      picked,
      for (final s in sources)
        if (!identical(s, picked) && s.url != picked.url) s,
    ];
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: ordered,
        title: _iptvSportsMatchChromeTitle(match),
        subtitle: picked.pickerTitle,
        logoUrl: picked.logoUrl,
        titleTracksSource: true,
        engineContext: BuiltInPlayerContext.iptv,
        liveSourceKind: IptvLiveSourceKind.iptvXtream,
      ),
    );
  }

  /// Match first, kickoff time when known — channel sits in the subtitle.
  String _iptvSportsMatchChromeTitle(_StreamedMatch match) {
    final name = match.title.trim();
    final kickoff = _iptvSportsKickoffLabel(match.dateMs);
    if (name.isEmpty) return kickoff.isEmpty ? 'Live' : kickoff;
    if (kickoff.isEmpty) return name;
    return '$name · $kickoff';
  }

  String _iptvSportsKickoffLabel(int dateMs) {
    if (dateMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm';
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return time;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day} $time';
  }

  Future<void> _openIptvSportsFromPpv(_DamiTvStream s) async {
    await _openIptvSportsMatch(_streamedMatchFromPpv(s));
  }

  _StreamedMatch _streamedMatchFromPpv(_DamiTvStream s) => _StreamedMatch(
        id: 'ppv:${s.id}',
        title: s.name,
        category: s.categoryName,
        dateMs: s.startsAt > 0 ? s.startsAt * 1000 : 0,
        poster: s.poster,
        popular: false,
        airing: s.isLive,
        homeTeam: s.homeTeam,
        awayTeam: s.awayTeam,
        homeBadge: s.homeBadge,
        awayBadge: s.awayBadge,
        sources: const [],
      );

  Future<void> _openEngineNativeStream({
    required String title,
    required String subtitle,
    required String url,
    Map<String, String> headers = const {},
    String label = 'Live',
  }) async {
    final playUrl = await LiveMatchesEngine.proxyPlayUrl(
      url: url,
      headers: headers,
    );
    if (!mounted) return;
    if (playUrl == null || playUrl.isEmpty) {
      LiveMatchesEngine.engineResolveFailed();
      return;
    }
    await IptvPtPlayerScreen.open(
      context,
      IptvPtPlayerScreen(
        sources: [
          IptvPlaySource(
            url: playUrl,
            label: label,
            liveSourceKind: IptvLiveSourceKind.liveEngine,
          ),
        ],
        title: title,
        subtitle: subtitle,
        engineContext: BuiltInPlayerContext.live,
        liveSourceKind: IptvLiveSourceKind.liveEngine,
      ),
    );
  }

  Future<bool> _tryEngineStreamedOpen(
    _StreamedMatch match,
    _StreamedStream stream,
  ) async {
    if (!await LiveMatchesEngine.isEngineResolveMode()) return false;

    final embed = stream.embedUrl.trim();
    if (embed.isNotEmpty &&
        RegExp(r'\.m3u8|\.mp4', caseSensitive: false).hasMatch(embed)) {
      await _openEngineNativeStream(
        title: match.title,
        subtitle: _streamPlaySubtitle(match, stream),
        url: embed,
        headers: _liveEmbedStreamHeaders(
          embed,
          catalogReferer: match.isForjaLive
              ? _forjaLiveCdnReferer(embed)
              : _streamedReferer,
        ),
        label: match.isForjaLive ? 'Forja Live' : 'Streamed',
      );
      return true;
    }

    final pluginId = match.isForjaLive && match.livePluginId.isNotEmpty
        ? match.livePluginId
        : 'live-streamed';
    LiveEngineResolveResult? result;
    final ok = await _runWithCancellableLoading('Resolving stream…', () async {
      result = await LiveMatchesEngine.resolve(
        pluginId: pluginId,
        params: {
          'embedUrl': embed,
          'url': embed,
          'source': stream.source,
          'matchId': stream.id,
          'stream': stream.streamNo.toString(),
          'category': match.category,
          'title': match.title,
        },
      );
    });
    if (!ok) return true;
    if (result == null || (!result!.playable && result!.embedUrl.isEmpty)) {
      LiveMatchesEngine.engineResolveFailed();
      return true;
    }
    if (!result!.playable) {
      LiveMatchesEngine.engineResolveFailed(
        'Engine could not resolve this stream — switch to Sniff in Settings → Forja Sports',
      );
      return true;
    }
    await _openEngineNativeStream(
      title: match.title,
      subtitle: _streamPlaySubtitle(match, stream),
      url: result!.url,
      headers: result!.headers,
      label: result!.label.isNotEmpty ? result!.label : 'Streamed',
    );
    return true;
  }

  Future<bool> _tryEnginePpvOpen(_DamiTvStream s) async {
    if (!await LiveMatchesEngine.isEngineResolveMode()) return false;
    LiveEngineResolveResult? result;
    final ok = await _runWithCancellableLoading('Resolving stream…', () async {
      result = await LiveMatchesEngine.resolve(
        pluginId: 'live-ppv',
        params: {
          'matchId': s.id.toString(),
          'embedUrl': s.iframe,
          'iframe': s.iframe,
          'title': s.name,
          'category': s.categoryName,
        },
      );
    });
    if (!ok) return true;
    if (result == null || !result!.playable) {
      LiveMatchesEngine.engineResolveFailed();
      return true;
    }
    await _openEngineNativeStream(
      title: s.name,
      subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
      url: result!.url,
      headers: result!.headers,
      label: 'PPV',
    );
    return true;
  }

  Future<void> _openStreamedEmbed(
    _StreamedMatch match,
    _StreamedStream stream,
  ) async {
    if (await _tryEngineStreamedOpen(match, stream)) return;

    final catalogBase = match.isMut
        ? _mutBase
        : (match.isForjaLive
            ? (Uri.tryParse(stream.embedUrl)?.origin ?? _streamedBase)
            : _streamedBase);
    final catalogReferer = match.isMut
        ? _mutReferer
        : (match.isForjaLive
            ? _forjaLiveWrapperReferer(
                stream.embedUrl,
                pluginId: match.livePluginId,
              )
            : _streamedReferer);
    final proxyReferer = match.isForjaLive
        ? _forjaLiveCdnReferer(stream.embedUrl)
        : null;
    final embedUrl = await liveEmbedResolveNestedPlayerUrl(
      stream.embedUrl,
      catalogReferer: catalogReferer,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: embedUrl,
          title: match.title,
          subtitle: match.categoryLabel,
          badgeLabel: match.isForjaLive ? 'Forja Live' : (match.isMut ? 'Mut' : 'Streamed'),
          referer: catalogReferer,
          origin: catalogBase,
          proxyReferer: proxyReferer,
        ),
      ),
    );
  }

  Future<void> _openDamiTvStream(_DamiTvStream s) async {
    if (_s._server == _LiveMatchesServer.iptvSports) {
      await _openIptvSportsFromPpv(s);
      return;
    }
    if (_tvNativeLiveOnly) {
      await _openTvNativeSourcesOnly(_streamedMatchFromPpv(s));
      return;
    }
    if (s.iframe.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    if (await _tryEnginePpvOpen(s)) return;

    // embedindia feeds only play inside their embed page (ppv.is uses the same
    // iframe). Native mpv cannot reuse the sniffed m3u8 token.
    if (_ppvEmbedRequiresWebView(s.iframe)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _LiveMatchesEmbedPlayerScreen(
            embedUrl: s.iframe,
            title: s.name,
            subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
            badgeLabel: 'PPV',
          ),
        ),
      );
      return;
    }

    String? playUrl;
    final ok = await _runWithCancellableLoading(
      'Connecting to stream…',
      () async {
        try {
          playUrl = await _resolvePpvPlayUrl(s.iframe);
        } catch (e) {
          debugPrint('[LiveMatches] PPV resolve error: $e');
        }
      },
    );
    if (!ok) return;

    if (playUrl != null) {
      await IptvPtPlayerScreen.open(
        context,
        IptvPtPlayerScreen(
          sources: [
            IptvPlaySource(
              url: playUrl!,
              label: 'PPV',
              liveSourceKind: IptvLiveSourceKind.liveEngine,
            ),
          ],
          title: s.name,
          subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
          engineContext: BuiltInPlayerContext.live,
          liveSourceKind: IptvLiveSourceKind.liveEngine,
        ),
      );
      return;
    }

    ForjaToast.info('Opening embed player…');
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: s.iframe,
          title: s.name,
          subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
          badgeLabel: 'PPV',
        ),
      ),
    );
  }

}
