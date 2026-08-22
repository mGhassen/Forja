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
    if (match.sources.isEmpty && match.inlineStreams.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    final streams = <_StreamedStream>[];
    if (match.inlineStreams.isNotEmpty) {
      streams.addAll(match.inlineStreams);
    } else {
      final ok = await _runWithCancellableLoading('Loading streams…', () async {
        try {
          for (final source in match.sources) {
            streams.addAll(await _fetchStreamedStreams(source));
          }
        } catch (e) {
          debugPrint('[LiveMatches] Streamed resolve error: $e');
        }
      });
      if (!ok) return;
    }

    if (streams.isEmpty) {
      ForjaToast.info('No streams available for this event');
      return;
    }

    if (streams.length == 1) {
      unawaited(_openStreamedEmbed(match, streams.first));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StreamedStreamSheet(
        match: match,
        streams: streams,
        onStreamSelected: (stream) {
          Navigator.pop(context);
          unawaited(_openStreamedEmbed(match, stream));
        },
      ),
    );
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
      onChannelSelected: (picked, all) {
        unawaited(_playIptvSportsSources(enriched, all, picked));
      },
    );
    panel.setSearchPhase('Forja Sports');

    Future<void> addForja() async {
      try {
        final forja = await _resolveIptvSportsStreams(enriched);
        if (panel.isDisposed) return;
        panel.appendSources([
          for (final s in forja)
            IptvPlaySource(
              url: s.url,
              label: s.label,
              detail: _tvNativeSourceDetail('Forja Sports', s.detail),
              logoUrl: s.logoUrl,
              streamId: s.streamId,
              headers: s.headers,
            ),
        ]);
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen(
          sources: sources,
          title: match.title,
          subtitle: match.categoryLabel,
          engineContext: BuiltInPlayerContext.live,
        ),
      ),
    );
  }

  Future<void> _openIptvSportsMatch(_StreamedMatch match) async {
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
      onChannelSelected: (picked, all) {
        unawaited(_playIptvSportsSources(enriched, all, picked));
      },
    );
    panel.setSearchPhase('Forja Sports');

    try {
      final sources = await _resolveIptvSportsStreams(enriched);
      if (panel.isDisposed) return;
      panel.appendSources(sources);
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen(
          sources: ordered,
          title: _iptvSportsMatchChromeTitle(match),
          subtitle: picked.pickerTitle,
          logoUrl: picked.logoUrl,
          titleTracksSource: true,
          engineContext: BuiltInPlayerContext.live,
        ),
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IptvPtPlayerScreen(
          sources: [IptvPlaySource(url: playUrl, label: label)],
          title: title,
          subtitle: subtitle,
          engineContext: BuiltInPlayerContext.live,
        ),
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
        subtitle: match.categoryLabel,
        url: embed,
        headers: _liveEmbedStreamHeaders(
          embed,
          catalogReferer: _streamedReferer,
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
      subtitle: match.categoryLabel,
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

    final catalogBase = match.isMut ? _mutBase : _streamedBase;
    final catalogReferer = match.isMut ? _mutReferer : _streamedReferer;
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
          badgeLabel: match.isMut ? 'Mut' : 'Streamed',
          referer: catalogReferer,
          origin: catalogBase,
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IptvPtPlayerScreen(
            sources: [IptvPlaySource(url: playUrl!, label: 'PPV')],
            title: s.name,
            subtitle: s.league.isNotEmpty ? s.league : s.categoryName,
            engineContext: BuiltInPlayerContext.live,
          ),
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
