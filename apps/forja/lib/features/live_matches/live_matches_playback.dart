part of 'live_matches_screen.dart';

mixin _LiveMatchesPlayback on State<LiveMatchesScreen> {

  Future<void> _openStreamedMatch(_StreamedMatch match) async {
    if (match.sources.isEmpty) {
      ForjaToast.info('Stream not yet available for this event');
      return;
    }
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: ForjaShellColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ForjaShellColors.cinematic.borderSubtle,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: ForjaShellColors.sectionAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading streams…',
                  style: TextStyle(color: ForjaShellColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final streams = <_StreamedStream>[];
    try {
      for (final source in match.sources) {
        streams.addAll(await _fetchStreamedStreams(source));
      }
    } catch (e) {
      debugPrint('[LiveMatches] Streamed resolve error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: ForjaShellColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ForjaShellColors.cinematic.borderSubtle,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: ForjaShellColors.sectionAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connecting to stream…',
                  style: const TextStyle(color: ForjaShellColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    String? playUrl;
    try {
      playUrl = await _resolvePpvPlayUrl(s.iframe);
    } catch (e) {
      debugPrint('[LiveMatches] PPV resolve error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

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
