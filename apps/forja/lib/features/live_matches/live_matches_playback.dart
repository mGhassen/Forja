part of 'live_matches_screen.dart';

mixin _LiveMatchesPlayback on ConsumerState<LiveMatchesScreen> {
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
          _openStreamedEmbed(streamed, stream);
        },
      ),
    );
  }

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    if (match.sources.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    final streams = <_StreamedStream>[];
    final ok = await _runWithCancellableLoading(
      'Loading streams…',
      () async {
        try {
          for (final source in match.sources) {
            streams.addAll(await _fetchStreamedStreams(source));
          }
        } catch (e) {
          debugPrint('[LiveMatches] Streamed resolve error: $e');
        }
      },
    );
    if (!ok) return;

    if (streams.isEmpty) {
      ForjaToast.info('No streams available for this event');
      return;
    }

    if (streams.length == 1) {
      _openStreamedEmbed(match, streams.first);
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
          _openStreamedEmbed(match, stream);
        },
      ),
    );
  }

  void _openStreamedEmbed(_StreamedMatch match, _StreamedStream stream) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveMatchesEmbedPlayerScreen(
          embedUrl: stream.embedUrl,
          title: match.title,
          subtitle: match.categoryLabel,
          badgeLabel: 'Streamed',
          referer: _streamedReferer,
          origin: _streamedBase,
        ),
      ),
    );
  }

  Future<void> _openDamiTvStream(_DamiTvStream s) async {
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
