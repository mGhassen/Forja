import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// YouTube embed identity for WebView Referer/Origin (must match bundle id).
const _kYoutubeEmbedOrigin = 'https://com.forja.app';

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
  bool _wantsTrailer = false;
  bool _heroVisible = true;

  @override
  void initState() {
    super.initState();
    _scheduleTrailer();
  }

  @override
  void didUpdateWidget(MediaDetailsHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerYoutubeKey != widget.trailerYoutubeKey) {
      _wantsTrailer = false;
      _trailerTimer?.cancel();
      _scheduleTrailer();
    }
  }

  void _scheduleTrailer() {
    final key = widget.trailerYoutubeKey;
    if (key == null || key.isEmpty) return;
    _trailerTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _wantsTrailer = true);
    });
  }

  bool get _showTrailer {
    final key = widget.trailerYoutubeKey;
    return _heroVisible && _wantsTrailer && key != null && key.isNotEmpty;
  }

  static String _trailerEmbedUrl(String videoKey) =>
      'https://www.youtube.com/embed/$videoKey'
      '?autoplay=1&mute=1&controls=0&modestbranding=1&rel=0&playsinline=1'
      '&origin=${Uri.encodeComponent(_kYoutubeEmbedOrigin)}';

  static String _trailerEmbedHtml(String videoKey) {
    final src = _trailerEmbedUrl(videoKey);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="refresh" content="0;url=$src">
  <style>html,body{margin:0;background:#000}</style>
</head>
<body>
  <script>location.replace('$src');</script>
</body>
</html>''';
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

  String? get _logoUrl => widget.movie.logoPath.isNotEmpty
      ? TmdbApi.getImageUrl(widget.movie.logoPath)
      : null;

  int? get _positionMs => widget.progress?['position'] as int?;
  int? get _durationMs => widget.progress?['duration'] as int?;

  bool _isDesktopLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= ShellTokens.heroDesktopMinBodyWidth &&
        !widget.compact;
  }

  Color _shellBg(BuildContext context) {
    return AppTheme.isLightMode
        ? AppTheme.appBackground
        : Theme.of(context).scaffoldBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktopLayout(context);
    final h = widget.height ??
        (widget.compact
            ? 280.0
            : MediaQuery.sizeOf(context).height * 0.50);
    final shellBg = _shellBg(context);
    final imageStart = desktop
        ? ShellTokens.heroImageStartFraction
        : ShellTokens.heroImageStartFractionCompact;
    final textTop = desktop
        ? ShellTokens.heroTextColumnTopInsetDesktop
        : (widget.compact ? 16.0 : 8.0);

    return VisibilityDetector(
      key: ValueKey('media-hero-${widget.movie.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.15;
        if (_heroVisible == visible) return;
        setState(() => _heroVisible = visible);
      },
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            ColoredBox(color: shellBg),
            Positioned(
              left: MediaQuery.sizeOf(context).width * imageStart,
              top: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _showTrailer && widget.trailerYoutubeKey != null
                  ? InAppWebView(
                      key: ValueKey('trailer-${widget.trailerYoutubeKey}'),
                      initialData: InAppWebViewInitialData(
                        data: _trailerEmbedHtml(widget.trailerYoutubeKey!),
                        baseUrl: WebUri(_kYoutubeEmbedOrigin),
                      ),
                      initialSettings: InAppWebViewSettings(
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        transparentBackground: true,
                        disableVerticalScroll: true,
                        disableHorizontalScroll: true,
                        supportZoom: false,
                      ),
                    )
                        : _backdropUrl.isNotEmpty
                            ? CachedNetworkImage(
                                key: const ValueKey('backdrop'),
                                imageUrl: _backdropUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight,
                              )
                            : ColoredBox(
                                key: const ValueKey('fallback'),
                                color: const Color(0xFF141414),
                              ),
                  ),
                  _HeroImageGradients(shellBg: shellBg, compact: widget.compact),
                ],
              ),
            ),
            Positioned(
              left: ShellTokens.bodyHorizontalPadding,
              top: textTop,
              right: widget.compact ? 20 : 48,
              bottom: widget.compact ? 16 : 20,
              child: desktop
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRect(
                          child: Align(
                            alignment: Alignment(
                              -1,
                              ShellTokens.heroTextColumnVerticalAlign,
                            ),
                            child: SizedBox(
                              width: math.min(
                                MediaQuery.sizeOf(context).width * 0.38,
                                ShellTokens.heroTextColumnWidthDesktop,
                              ),
                              child: _buildDesktopTextColumn(
                                context,
                                maxHeight: constraints.maxHeight,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : _buildCompactTextColumn(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTextColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeroTitleBlock(
          movie: widget.movie,
          logoUrl: _logoUrl,
          compact: true,
        ),
        const SizedBox(height: 8),
        _HeroMetaRow(movie: widget.movie, singleLine: true),
        if (widget.movie.overview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.movie.overview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
        if (_positionMs != null && _durationMs != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 200,
            child: WatchProgressBar(
              positionMs: _positionMs!,
              durationMs: _durationMs!,
              compact: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopTextColumn(BuildContext context, {required double maxHeight}) {
    const overviewStyle = TextStyle(
      fontSize: ShellTokens.heroOverviewFontSizeDesktop,
      height: ShellTokens.heroOverviewLineHeightDesktop,
      letterSpacing: 0.1,
      color: Color(0x99FFFFFF),
    );
    const titleGap = 16.0;
    const overviewGap = 20.0;
    const minTitleHeight = 56.0;

    final overviewBlock = overviewGap + ShellTokens.heroOverviewSlotHeightDesktop;
    final baseWithoutOverview = titleGap +
        ShellTokens.heroMetaSlotHeightDesktop +
        (_positionMs != null ? 42.0 : 0.0);

    var titleHeight = widget.compact
        ? ShellTokens.heroTitleSlotHeightCompact
        : ShellTokens.heroTitleSlotHeightDesktop;
    final showOverview = widget.movie.overview.isNotEmpty &&
        titleHeight + baseWithoutOverview + overviewBlock <= maxHeight;

    if (!showOverview && titleHeight + baseWithoutOverview > maxHeight) {
      titleHeight = (maxHeight - baseWithoutOverview)
          .clamp(minTitleHeight, ShellTokens.heroTitleSlotHeightDesktop);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: titleHeight,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _HeroTitleBlock(
              movie: widget.movie,
              logoUrl: _logoUrl,
              desktop: true,
            ),
          ),
        ),
        const SizedBox(height: titleGap),
        SizedBox(
          height: ShellTokens.heroMetaSlotHeightDesktop,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _HeroMetaRow(movie: widget.movie, singleLine: true),
          ),
        ),
        if (showOverview) ...[
          SizedBox(height: overviewGap),
          SizedBox(
            height: ShellTokens.heroOverviewSlotHeightDesktop,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                widget.movie.overview,
                style: overviewStyle,
                maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        if (_positionMs != null && _durationMs != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: 280,
            child: WatchProgressBar(
              positionMs: _positionMs!,
              durationMs: _durationMs!,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroImageGradients extends StatelessWidget {
  const _HeroImageGradients({required this.shellBg, required this.compact});

  final Color shellBg;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fadeEnd = ShellTokens.heroImageGradientFadeEndFraction;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        shellBg,
                        shellBg.withValues(alpha: 0.72),
                        shellBg.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                      stops: [0.0, fadeEnd * 0.31, fadeEnd * 0.66, fadeEnd],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * (compact ? 0.65 : 0.55),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        shellBg.withValues(alpha: 0.45),
                        shellBg.withValues(alpha: 0.82),
                        shellBg,
                      ],
                      stops: const [0.0, 0.35, 0.68, 1.0],
                    ),
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

class _HeroTitleBlock extends StatelessWidget {
  const _HeroTitleBlock({
    required this.movie,
    required this.logoUrl,
    this.desktop = false,
    this.compact = false,
  });

  final Movie movie;
  final String? logoUrl;
  final bool desktop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bodyWidth = MediaQuery.sizeOf(context).width;
    final logoMaxHeight = compact
        ? ShellTokens.heroLogoMaxHeightCompact
        : desktop
            ? ShellTokens.heroLogoMaxHeightDesktop
            : 110.0;
    final maxWidth = compact
        ? bodyWidth * 0.72
        : desktop
            ? ShellTokens.heroTextColumnWidthDesktop
            : bodyWidth * 0.75;
    final title = _heroTitleText(movie, desktop: desktop, compact: compact);
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return SizedBox(
      width: maxWidth,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          height: logoMaxHeight,
          width: maxWidth,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: hasLogo
                ? CachedNetworkImage(
                    imageUrl: logoUrl!,
                    height: logoMaxHeight,
                    width: maxWidth,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    placeholder: (_, _) => title,
                    errorWidget: (_, _, _) => title,
                    fadeInDuration: const Duration(milliseconds: 250),
                    fadeOutDuration: Duration.zero,
                  )
                : title,
          ),
        ),
      ),
    );
  }
}

Widget _heroTitleText(
  Movie movie, {
  bool desktop = false,
  bool compact = false,
}) {
  final fontSize = compact ? 22.0 : desktop ? 32.0 : 28.0;
  return Text(
    movie.title,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.0,
      letterSpacing: -1.0,
      shadows: AppTheme.isLightMode
          ? null
          : [
              const Shadow(color: Colors.black, blurRadius: 40),
              Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 80),
            ],
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({required this.movie, this.singleLine = false});

  final Movie movie;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final rating = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            movie.voteAverage.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (!singleLine) return rating;

    return Row(
      children: [
        rating,
        if (movie.releaseDate.length >= 4) ...[
          const SizedBox(width: 10),
          Text(
            movie.releaseDate.substring(0, 4),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (movie.mediaType == 'tv') ...[
          const SizedBox(width: 10),
          _mediaTypeBadge('SERIES'),
        ] else if (movie.mediaType == 'movie') ...[
          const SizedBox(width: 10),
          _mediaTypeBadge('FILM'),
        ],
        if (movie.genres.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              movie.genres.take(3).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mediaTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
