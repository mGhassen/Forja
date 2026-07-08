import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MediaDetailsHero extends StatefulWidget {
  const MediaDetailsHero({
    super.key,
    required this.movie,
    this.trailerYoutubeKey,
    this.progress,
    this.height,
    this.compact = false,
  });

  final Movie movie;
  final String? trailerYoutubeKey;
  final Map<String, dynamic>? progress;
  final double? height;
  final bool compact;

  @override
  State<MediaDetailsHero> createState() => _MediaDetailsHeroState();
}

class _MediaDetailsHeroState extends State<MediaDetailsHero> {
  Timer? _trailerTimer;
  bool _showTrailer = false;
  bool _heroVisible = true;
  InAppWebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _scheduleTrailer();
  }

  @override
  void didUpdateWidget(MediaDetailsHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerYoutubeKey != widget.trailerYoutubeKey) {
      _showTrailer = false;
      _trailerTimer?.cancel();
      _scheduleTrailer();
    }
  }

  void _scheduleTrailer() {
    final key = widget.trailerYoutubeKey;
    if (key == null || key.isEmpty) return;
    _trailerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _heroVisible) setState(() => _showTrailer = true);
    });
  }

  @override
  void dispose() {
    _trailerTimer?.cancel();
    super.dispose();
  }

  String get _backdropUrl {
    final path = widget.movie.backdropPath.isNotEmpty
        ? widget.movie.backdropPath
        : widget.movie.posterPath;
    return path.isNotEmpty ? TmdbApi.getBackdropUrl(path) : '';
  }

  String _metaLine() {
    final parts = <String>[];
    if (widget.movie.genres.isNotEmpty) {
      parts.add(widget.movie.genres.take(2).join(' | '));
    }
    if (widget.movie.runtime > 0) {
      parts.add(WatchProgressBar.formatMinutes(widget.movie.runtime * 60000));
    }
    if (widget.movie.releaseDate.length >= 4) {
      parts.add(widget.movie.releaseDate.substring(0, 4));
    }
    return parts.join(' | ');
  }

  int? get _positionMs => widget.progress?['position'] as int?;
  int? get _durationMs => widget.progress?['duration'] as int?;

  @override
  Widget build(BuildContext context) {
    final h = widget.height ??
        (widget.compact ? 280.0 : MediaQuery.sizeOf(context).height * 0.42);
    final logoUrl = widget.movie.logoPath.isNotEmpty
        ? TmdbApi.getImageUrl(widget.movie.logoPath)
        : null;

    return VisibilityDetector(
      key: ValueKey('media-hero-${widget.movie.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.15;
        if (_heroVisible == visible) return;
        _heroVisible = visible;
        if (!visible) {
          _webController?.pause();
        } else if (_showTrailer) {
          _webController?.resume();
        }
      },
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: _showTrailer && widget.trailerYoutubeKey != null
                  ? InAppWebView(
                      key: ValueKey('trailer-${widget.trailerYoutubeKey}'),
                      initialUrlRequest: URLRequest(
                        url: WebUri(
                          'https://www.youtube.com/embed/${widget.trailerYoutubeKey}'
                          '?autoplay=1&mute=1&controls=0&modestbranding=1&rel=0&playsinline=1',
                        ),
                      ),
                      initialSettings: InAppWebViewSettings(
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                      ),
                      onWebViewCreated: (c) => _webController = c,
                    )
                  : _backdropUrl.isNotEmpty
                      ? CachedNetworkImage(
                          key: const ValueKey('backdrop'),
                          imageUrl: _backdropUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : ColoredBox(
                          key: const ValueKey('fallback'),
                          color: const Color(0xFF141414),
                        ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: ShellTokens.bodyHorizontalPadding,
              right: 24,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logoUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CachedNetworkImage(
                        imageUrl: logoUrl,
                        height: 48,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    )
                  else
                    Text(
                      widget.movie.title,
                      style: TextStyle(
                        fontSize: widget.compact ? 22 : 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (logoUrl != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.movie.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (_metaLine().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _metaLine(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_positionMs != null && _durationMs != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: widget.compact ? 200 : 280,
                      child: WatchProgressBar(
                        positionMs: _positionMs!,
                        durationMs: _durationMs!,
                        compact: widget.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
