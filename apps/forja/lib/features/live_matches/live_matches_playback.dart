part of 'live_matches_screen.dart';

mixin _LiveMatchesPlayback on ConsumerState<LiveMatchesScreen> {
  _LiveMatchesScreenState get _s => this as _LiveMatchesScreenState;

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

  Future<void> _openStremioSportMatch(_StreamedMatch match) async {
    if (!mounted) return;
    final sources = <IptvPlaySource>[];
    final ok = await _runWithCancellableLoading('Loading streams…', () async {
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
          sources.add(
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
    final sources = <IptvPlaySource>[];
    final ok = await _runWithCancellableLoading(
      'Matching IPTV channels…',
      () async {
        try {
          sources.addAll(await _resolveIptvSportsStreams(enriched));
        } catch (e) {
          debugPrint('[LiveMatches] IPTV sports resolve error: $e');
        }
      },
    );
    if (!ok) return;
    if (sources.isEmpty) {
      ForjaToast.info('No matching IPTV channels for this event');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _IptvSportsChannelSheet(
        match: enriched,
        sources: sources,
        onChannelSelected: (picked) {
          Navigator.pop(context);
          unawaited(_playIptvSportsSources(enriched, sources, picked));
        },
      ),
    );
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
          title: picked.pickerTitle,
          subtitle: '${match.title} · ${match.categoryLabel}',
          logoUrl: picked.logoUrl,
          titleTracksSource: true,
          engineContext: BuiltInPlayerContext.live,
        ),
      ),
    );
  }

  Future<void> _openIptvSportsFromPpv(_DamiTvStream s) async {
    final match = _StreamedMatch(
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
    await _openIptvSportsMatch(match);
  }

  Future<void> _openIptvSportsFromCdn(_CdnSportEvent event) async {
    final title = '${event.homeTeam} vs ${event.awayTeam}'.trim();
    final startMs = int.tryParse(event.start) ?? 0;
    final match = _StreamedMatch(
      id: 'cdn:${event.gameID}',
      title: title.isEmpty ? event.tournament : title,
      category: event.sport,
      dateMs: startMs > 1e12 ? startMs : (startMs > 0 ? startMs * 1000 : 0),
      poster: event.homeTeamIMG.isNotEmpty
          ? event.homeTeamIMG
          : event.awayTeamIMG,
      popular: false,
      airing: event.isLive,
      homeTeam: event.homeTeam,
      awayTeam: event.awayTeam,
      homeBadge: event.homeTeamIMG,
      awayBadge: event.awayTeamIMG,
      sources: const [],
    );
    await _openIptvSportsMatch(match);
  }

  Future<void> _openStreamedEmbed(
    _StreamedMatch match,
    _StreamedStream stream,
  ) async {
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
    if (s.iframe.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

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

  void _openCdnChannel(_CdnChannel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: channel.url,
          title: channel.name,
          badgeLabel: 'CDN Live',
        ),
      ),
    );
  }

  void _openCdnSportEvent(_CdnSportEvent event) {
    if (_s._server == _LiveMatchesServer.iptvSports) {
      unawaited(_openIptvSportsFromCdn(event));
      return;
    }
    if (event.channels.isEmpty) {
      ForjaToast.info('No channels available for this event');
      return;
    }
    if (event.channels.length == 1) {
      _openCdnChannel(event.channels.first);
      return;
    }
    // Show channel selection
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CdnChannelSheet(
        event: event,
        onChannelSelected: (ch) {
          Navigator.pop(context);
          _openCdnChannel(ch);
        },
      ),
    );
  }
}
