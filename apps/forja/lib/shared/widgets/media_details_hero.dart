import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/movie_atmosphere.dart';
import 'package:forja/shared/widgets/media_details_backdrop.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _kYoutubeEmbedOrigin = 'https://com.forja.app';

class MediaDetailsHero extends StatefulWidget {
  const MediaDetailsHero({
    super.key,
    required this.movie,
    this.trailerYoutubeKey,
    this.progress,
    this.height,
    this.actionRow,
    this.trailerLanguageCode,
    this.tagline,
    this.certification,
    this.status,
    this.imdbRating,
    this.directorName,
    this.budget,
    this.revenue,
    this.languageCode,
    this.spokenLanguages = const [],
    this.productionCompanies = const [],
    this.originCountries = const [],
  });

  final Movie movie;
  final String? trailerYoutubeKey;
  /// TMDB ISO 639-1 original language — keeps YouTube player/captions in source lang.
  final String? trailerLanguageCode;
  final Map<String, dynamic>? progress;
  final double? height;
  final Widget? actionRow;
  final String? tagline;
  final String? certification;
  final String? status;
  final double? imdbRating;
  final String? directorName;
  final int? budget;
  final int? revenue;
  final String? languageCode;
  final List<String> spokenLanguages;
  final List<String> productionCompanies;
  final List<String> originCountries;

  @override
  State<MediaDetailsHero> createState() => _MediaDetailsHeroState();
}

class _MediaDetailsHeroState extends State<MediaDetailsHero> {
  static const _kBackdropBeatMinSeconds = 12;
  static const _kBackdropBeatMaxSeconds = 20;

  final math.Random _backdropRng = math.Random();

  Timer? _trailerTimer;
  bool _wantsTrailer = false;
  bool _trailerReady = false;
  bool _heroVisible = true;
  bool _imagePrecached = false;
  bool _trailerMuted = false;
  bool _trailerNeedsRestart = false;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _scheduleTrailer();
  }

  @override
  void didUpdateWidget(MediaDetailsHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerYoutubeKey != widget.trailerYoutubeKey ||
        oldWidget.trailerLanguageCode != widget.trailerLanguageCode) {
      _wantsTrailer = false;
      _trailerReady = false;
      _trailerMuted = false;
      _trailerNeedsRestart = false;
      _webViewController = null;
      _trailerTimer?.cancel();
      _scheduleTrailer();
    }
    if (oldWidget.movie.id != widget.movie.id) {
      _imagePrecached = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheBackdrop();
  }

  void _scheduleTrailer() {
    final key = widget.trailerYoutubeKey;
    if (key == null || key.isEmpty) return;
    _trailerTimer?.cancel();
    _trailerTimer = Timer(_randomBackdropBeat(), () {
      if (!mounted) return;
      setState(() => _wantsTrailer = true);
      _syncTrailerPlayback();
    });
  }

  Duration _randomBackdropBeat() {
    final span = _kBackdropBeatMaxSeconds - _kBackdropBeatMinSeconds + 1;
    final seconds = _kBackdropBeatMinSeconds + _backdropRng.nextInt(span);
    return Duration(seconds: seconds);
  }

  void _onTrailerEnded() {
    if (!mounted) return;
    setState(() => _wantsTrailer = false);
    _trailerNeedsRestart = true;
    unawaited(_syncTrailerPlayback());
    _scheduleTrailer();
  }

  void _precacheBackdrop() {
    if (_imagePrecached) return;
    final url = _backdropUrl;
    if (url.isEmpty) return;
    _imagePrecached = true;
    precacheImage(CachedNetworkImageProvider(url), context);
  }

  bool get _hasTrailerKey {
    final key = widget.trailerYoutubeKey;
    return key != null && key.isNotEmpty;
  }

  bool get _showTrailer =>
      _heroVisible && _wantsTrailer && _trailerReady && _hasTrailerKey;

  static String _trailerEmbedHtml(String videoKey, {String? languageCode}) {
    final lang = languageCode?.trim();
    final hasLang = lang != null && lang.isNotEmpty;
    final langPlayerVars = hasLang
        ? '''
          hl: '$lang',
          cc_lang_pref: '$lang','''
        : '';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0; padding: 0;
      width: 100%; height: 100%;
      background: #000;
      overflow: hidden;
    }
    #viewport {
      position: absolute;
      inset: 0;
      overflow: hidden;
    }
    #player {
      position: absolute;
      inset: 0;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <div id="viewport"><div id="player"></div></div>
  <script>
    var tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);

    var player;
    var volumeRampTimer = null;
    window._ytVolume = 0;
    window._ytMuted = false;

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        videoId: '$videoKey',
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 1,
          mute: 1,
          controls: 0,
          modestbranding: 1,
          rel: 0,
          playsinline: 1,
          fs: 0,
          iv_load_policy: 3,
          disablekb: 1,
          cc_load_policy: 3,
          enablejsapi: 1,$langPlayerVars
          origin: '$_kYoutubeEmbedOrigin',
          widget_referrer: '$_kYoutubeEmbedOrigin'
        },
        events: {
          onReady: onPlayerReady,
          onStateChange: onPlayerStateChange
        }
      });
      window._ytPlayer = player;
    }

    function pickBestQuality(p) {
      try {
        var levels = p.getAvailableQualityLevels();
        if (levels && levels.length) p.setPlaybackQuality(levels[0]);
      } catch (e) {}
    }

    function disableCaptions(p) {
      try {
        p.setOption('captions', 'track', {});
        p.setOption('captions', 'reload', true);
      } catch (e) {}
    }

    function cropYoutubeChrome(p) {
      try {
        var iframe = p.getIframe && p.getIframe();
        if (!iframe) return;
        var wrap = document.getElementById('viewport');
        var w = wrap ? wrap.clientWidth : window.innerWidth;
        var h = wrap ? wrap.clientHeight : window.innerHeight;
        if (!w || !h) return;
        var videoAspect = 16 / 9;
        var viewAspect = w / h;
        var iframeW;
        var iframeH;
        if (viewAspect > videoAspect) {
          iframeW = w;
          iframeH = w / videoAspect;
        } else {
          iframeH = h;
          iframeW = h * videoAspect;
        }
        var overscan = 1.42;
        iframeW *= overscan;
        iframeH *= overscan;
        iframe.style.position = 'absolute';
        iframe.style.left = '50%';
        iframe.style.top = '50%';
        iframe.style.width = iframeW + 'px';
        iframe.style.height = iframeH + 'px';
        iframe.style.maxWidth = 'none';
        iframe.style.maxHeight = 'none';
        iframe.style.border = '0';
        iframe.style.pointerEvents = 'none';
        iframe.style.transform = 'translate(-50%, -50%)';
        iframe.style.transformOrigin = 'center center';
      } catch (e) {}
    }

    function onPlayerReady(e) {
      var p = e.target;
      cropYoutubeChrome(p);
      disableCaptions(p);
      setTimeout(function() { cropYoutubeChrome(p); }, 150);
      setTimeout(function() { cropYoutubeChrome(p); }, 600);
      p.unMute();
      p.setVolume(0);
      window._ytVolume = 0;
      p.playVideo();
      pickBestQuality(p);
      startVolumeRamp(p, 0, 100, 3000);
      notifyReady();
    }

    function startVolumeRamp(p, from, to, durationMs) {
      if (volumeRampTimer) clearInterval(volumeRampTimer);
      var start = Date.now();
      volumeRampTimer = setInterval(function() {
        if (window._ytMuted) return;
        var t = Math.min(1, (Date.now() - start) / durationMs);
        var v = Math.round(from + (to - from) * t);
        window._ytVolume = v;
        p.setVolume(v);
        if (t >= 1) {
          clearInterval(volumeRampTimer);
          volumeRampTimer = null;
        }
      }, 50);
    }

    function notifyReady() {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('trailerReady');
      }
    }

    function onPlayerStateChange(e) {
      if (e.data === YT.PlayerState.PLAYING) {
        cropYoutubeChrome(e.target);
        disableCaptions(e.target);
        pickBestQuality(e.target);
      }
      if (e.data === YT.PlayerState.ENDED) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('trailerEnded');
        }
      }
    }

    window.restartTrailer = function() {
      if (!player || !player.seekTo) return;
      if (volumeRampTimer) clearInterval(volumeRampTimer);
      cropYoutubeChrome(player);
      disableCaptions(player);
      player.seekTo(0, true);
      if (window._ytMuted) {
        player.mute();
      } else {
        player.unMute();
        player.setVolume(0);
        window._ytVolume = 0;
        startVolumeRamp(player, 0, 100, 3000);
      }
      player.playVideo();
      pickBestQuality(player);
    };

    window.setTrailerMuted = function(muted) {
      window._ytMuted = muted;
      if (!player || !player.setVolume) return;
      if (muted) {
        player.mute();
      } else {
        player.unMute();
        player.setVolume(window._ytVolume || 100);
      }
    };

    window.setTrailerPlaying = function(playing) {
      if (!player || !player.playVideo) return;
      if (playing) player.playVideo();
      else player.pauseVideo();
    };
  </script>
</body>
</html>''';
  }

  Future<void> _syncTrailerPlayback() async {
    final controller = _webViewController;
    if (controller == null) return;
    if (_showTrailer) {
      if (_trailerNeedsRestart) {
        _trailerNeedsRestart = false;
        await controller.evaluateJavascript(
          source: 'window.restartTrailer && window.restartTrailer();',
        );
      } else {
        await controller.evaluateJavascript(
          source: 'window.setTrailerPlaying(true);',
        );
      }
    } else {
      await controller.evaluateJavascript(
        source: 'window.setTrailerPlaying(false);',
      );
    }
    await controller.evaluateJavascript(
      source: 'window.setTrailerMuted(${_trailerMuted ? 'true' : 'false'});',
    );
  }

  Future<void> _toggleTrailerMute() async {
    setState(() => _trailerMuted = !_trailerMuted);
    await _webViewController?.evaluateJavascript(
      source: 'window.setTrailerMuted(${_trailerMuted ? 'true' : 'false'});',
    );
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

  Color _shellBg(BuildContext context) {
    return AppTheme.isLightMode
        ? AppTheme.appBackground
        : Theme.of(context).scaffoldBackgroundColor;
  }

  InAppWebViewSettings get _webViewSettings => InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: false,
        disableVerticalScroll: true,
        disableHorizontalScroll: true,
        supportZoom: false,
      );

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? MediaQuery.sizeOf(context).height;
    final shellBg = _shellBg(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentInset =
        ShellTokens.detailsContentHorizontalPadding(viewportWidth);
    final heroContentTop = topInset + ShellTokens.detailsHeroContentTopInset;

    return VisibilityDetector(
      key: ValueKey('media-hero-${widget.movie.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.15;
        if (_heroVisible == visible) return;
        setState(() => _heroVisible = visible);
        _syncTrailerPlayback();
      },
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
            ColoredBox(color: shellBg),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _showTrailer ? 0 : 1,
              child: _backdropUrl.isNotEmpty
                  ? KenBurnsBackdrop(
                      imageUrl: _backdropUrl,
                      showColorTint: false,
                      cycleDuration: const Duration(seconds: 85),
                      minScale: 1.06,
                      maxScale: 1.28,
                    )
                  : const ColoredBox(color: Color(0xFF141414)),
            ),
            if (_hasTrailerKey)
              Positioned.fill(
                child: ClipRect(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: _showTrailer ? 1 : 0,
                      child: InAppWebView(
                      key: ValueKey('trailer-${widget.trailerYoutubeKey}'),
                      initialData: InAppWebViewInitialData(
                        data: _trailerEmbedHtml(
                          widget.trailerYoutubeKey!,
                          languageCode: widget.trailerLanguageCode,
                        ),
                        baseUrl: WebUri(_kYoutubeEmbedOrigin),
                      ),
                      initialSettings: _webViewSettings,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'trailerReady',
                          callback: (_) {
                            if (!mounted || _trailerReady) return;
                            setState(() => _trailerReady = true);
                            _syncTrailerPlayback();
                          },
                        );
                        controller.addJavaScriptHandler(
                          handlerName: 'trailerEnded',
                          callback: (_) => _onTrailerEnded(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const _HeroVignette(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.sizeOf(context).height * 0.58 +
                  ShellTokens.detailsHeroBodyOverlap,
              child: IgnorePointer(
                child: MediaDetailsBackdropScrim(
                  imageUrl: _backdropUrl.isNotEmpty ? _backdropUrl : null,
                  fallbackColor: shellBg,
                  blurSigma: 22,
                  gradientStops: const [0.0, 0.38, 0.72, 1.0],
                  gradientColors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: heroContentTop,
              bottom: 72 + bottomInset,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ShellTokens.bodyMaxWidthDesktop,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: contentInset),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _HeroLayout(
                          movie: widget.movie,
                          logoUrl: _logoUrl,
                          directorName: widget.directorName,
                          budget: widget.budget,
                          revenue: widget.revenue,
                          languageCode: widget.languageCode,
                          spokenLanguages: widget.spokenLanguages,
                          productionCompanies: widget.productionCompanies,
                          originCountries: widget.originCountries,
                          certification: widget.certification,
                          imdbRating: widget.imdbRating,
                          actionRow: widget.actionRow,
                          positionMs: _positionMs,
                          durationMs: _durationMs,
                        ),
                        if (_showTrailer)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _TrailerMuteButton(
                              muted: _trailerMuted,
                              onTap: _toggleTrailerMute,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TrailerMuteButton extends StatelessWidget {
  const _TrailerMuteButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _HeroVignette extends StatelessWidget {
  const _HeroVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.1,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.65),
            ],
            stops: const [0.45, 0.78, 1.0],
          ),
        ),
      ),
    );
  }
}

class _HeroLayout extends StatelessWidget {
  const _HeroLayout({
    required this.movie,
    required this.logoUrl,
    this.directorName,
    this.budget,
    this.revenue,
    this.languageCode,
    this.spokenLanguages = const [],
    this.productionCompanies = const [],
    this.originCountries = const [],
    this.certification,
    this.imdbRating,
    this.actionRow,
    this.positionMs,
    this.durationMs,
  });

  final Movie movie;
  final String? logoUrl;
  final String? directorName;
  final int? budget;
  final int? revenue;
  final String? languageCode;
  final List<String> spokenLanguages;
  final List<String> productionCompanies;
  final List<String> originCountries;
  final String? certification;
  final double? imdbRating;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final leftColumnWidth =
        width * ShellTokens.detailsHeroDescriptionWidthFraction;
    final mainColumn = _HeroMainColumn(
      movie: movie,
      logoUrl: logoUrl,
      directorName: directorName,
      certification: certification,
      imdbRating: imdbRating,
      actionRow: actionRow,
      positionMs: positionMs,
      durationMs: durationMs,
      maxContentWidth: compact ? width : leftColumnWidth,
    );
    final factsPanel = _HeroFactsPanel(
      movie: movie,
      budget: budget,
      revenue: revenue,
      languageCode: languageCode,
      spokenLanguages: spokenLanguages,
      productionCompanies: productionCompanies,
      originCountries: originCountries,
      positionMs: positionMs,
      durationMs: durationMs,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mainColumn,
          if (factsPanel.hasContent) ...[
            const SizedBox(height: 24),
            factsPanel,
          ],
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: leftColumnWidth,
            child: mainColumn,
          ),
        ),
        if (factsPanel.hasContent)
          Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(width: 300, child: factsPanel),
          ),
      ],
    );
  }
}

class _HeroMainColumn extends StatelessWidget {
  const _HeroMainColumn({
    required this.movie,
    required this.logoUrl,
    required this.maxContentWidth,
    this.directorName,
    this.certification,
    this.imdbRating,
    this.actionRow,
    this.positionMs,
    this.durationMs,
  });

  final Movie movie;
  final String? logoUrl;
  final double maxContentWidth;
  final String? directorName;
  final String? certification;
  final double? imdbRating;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final director = directorName?.trim();

    return SizedBox(
      width: maxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        _HeroTitle(movie: movie, logoUrl: logoUrl),
        if (movie.genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            movie.genres.take(4).join(' • '),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.78),
              letterSpacing: 0.2,
            ),
          ),
        ],
        if (actionRow != null) ...[
          const SizedBox(height: 18),
          actionRow!,
        ],
        const SizedBox(height: 14),
        _HeroMetaLine(
          movie: movie,
          certification: certification,
          imdbRating: imdbRating,
        ),
        if (director != null && director.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Director: $director',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
        if (movie.overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            movie.overview,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
        if (positionMs != null && durationMs != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 280,
            child: WatchProgressBar(
              positionMs: positionMs!,
              durationMs: durationMs!,
            ),
          ),
        ],
      ],
      ),
    );
  }
}

class _HeroFactsPanel extends StatelessWidget {
  const _HeroFactsPanel({
    required this.movie,
    this.budget,
    this.revenue,
    this.languageCode,
    this.spokenLanguages = const [],
    this.productionCompanies = const [],
    this.originCountries = const [],
    this.positionMs,
    this.durationMs,
  });

  final Movie movie;
  final int? budget;
  final int? revenue;
  final String? languageCode;
  final List<String> spokenLanguages;
  final List<String> productionCompanies;
  final List<String> originCountries;
  final int? positionMs;
  final int? durationMs;

  bool get hasContent =>
      _runtimeLabel.isNotEmpty ||
      _languageLabel.isNotEmpty ||
      _releaseLabel.isNotEmpty ||
      _productionLabel.isNotEmpty ||
      _originLabel.isNotEmpty ||
      _formatMoney(budget).isNotEmpty ||
      _formatMoney(revenue).isNotEmpty;

  String get _runtimeLabel {
    final runtime = _HeroMetaLine.formatRuntime(movie.runtime);
    if (runtime.isEmpty) return '';
    final remainingMs = (positionMs != null && durationMs != null)
        ? durationMs! - positionMs!
        : null;
    if (remainingMs != null && remainingMs > 0) {
      final ends = DateTime.now().add(Duration(milliseconds: remainingMs));
      final hour = ends.hour > 12 ? ends.hour - 12 : (ends.hour == 0 ? 12 : ends.hour);
      final minute = ends.minute.toString().padLeft(2, '0');
      final period = ends.hour >= 12 ? 'PM' : 'AM';
      return '$runtime • Ends $hour:$minute $period';
    }
    return runtime;
  }

  String get _languageLabel {
    final code = languageCode?.trim();
    if (code != null && code.isNotEmpty) return code.toUpperCase();
    if (spokenLanguages.isNotEmpty) {
      return spokenLanguages.first.length <= 3
          ? spokenLanguages.first.toUpperCase()
          : spokenLanguages.first;
    }
    return '';
  }

  String get _releaseLabel => _formatReleaseDate(movie.releaseDate);

  String get _productionLabel {
    final items = productionCompanies.where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return items.take(2).join(', ');
  }

  String get _originLabel {
    final items = originCountries.where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return items.take(2).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContent) return const SizedBox.shrink();

    final rows = <({String label, String value})>[
      if (_runtimeLabel.isNotEmpty) (label: 'Runtime', value: _runtimeLabel),
      if (_languageLabel.isNotEmpty) (label: 'Language', value: _languageLabel),
      if (_releaseLabel.isNotEmpty) (label: 'Release Date', value: _releaseLabel),
      if (_productionLabel.isNotEmpty) (label: 'Production', value: _productionLabel),
      if (_originLabel.isNotEmpty) (label: 'Origin', value: _originLabel),
      if (_formatMoney(budget).isNotEmpty) (label: 'Budget', value: _formatMoney(budget)),
      if (_formatMoney(revenue).isNotEmpty) (label: 'Revenue', value: _formatMoney(revenue)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            _FactRow(label: rows[i].label, value: rows[i].value),
          ],
        ],
      ),
    );
  }

  static String _formatReleaseDate(String iso) {
    if (iso.length < 10) return iso;
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _formatMoney(int? amount) {
    if (amount == null || amount <= 0) return '';
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '\$${buf.toString()}';
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.movie, required this.logoUrl});

  final Movie movie;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    if (hasLogo) {
      return CachedNetworkImage(
        imageUrl: logoUrl!,
        height: 64,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        placeholder: (_, _) => _chromaticTitle(movie),
        errorWidget: (_, _, _) => _chromaticTitle(movie),
      );
    }
    return _chromaticTitle(movie);
  }

  Widget _chromaticTitle(Movie movie) {
    const style = TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.0,
      letterSpacing: -1.2,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(-1.5, 0),
          child: Text(
            movie.title,
            style: style.copyWith(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Transform.translate(
          offset: const Offset(1.5, 0),
          child: Text(
            movie.title,
            style: style.copyWith(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          movie.title,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HeroMetaLine extends StatelessWidget {
  const _HeroMetaLine({
    required this.movie,
    this.certification,
    this.imdbRating,
  });

  final Movie movie;
  final String? certification;
  final double? imdbRating;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (movie.releaseDate.length >= 4) {
      items.add(_metaText(movie.releaseDate.substring(0, 4)));
    }
    final runtime = formatRuntime(movie.runtime);
    if (runtime.isNotEmpty) items.add(_metaText(runtime));
    final cert = certification?.trim();
    if (cert != null && cert.isNotEmpty) items.add(_CertBadge(label: cert));
    final rating = (imdbRating != null && imdbRating! > 0)
        ? imdbRating!
        : (movie.voteAverage > 0 ? movie.voteAverage : null);
    if (rating != null) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade400),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Text(
              '•',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            ),
          items[i],
        ],
      ],
    );
  }

  Widget _metaText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static String formatRuntime(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

class _CertBadge extends StatelessWidget {
  const _CertBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
