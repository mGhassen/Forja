import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/design/src/details_tokens.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hero/hero_facts_panel.dart';
import 'package:forja/shared/widgets/hero/hero_meta_line.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/hero/hero_watch_providers_row.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MediaDetailsHero extends StatefulWidget {
  const MediaDetailsHero({
    super.key,
    required this.movie,
    this.backdropPathOverride,
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
    this.lastAirDate,
    this.networks = const [],
    this.creators = const [],
    this.watchProviders = const [],
    this.bodyOverlap,
    this.pageBottomChild,
    this.seriesProgress,
    this.showSeasonRail = false,
  });

  final Movie movie;
  /// When set (e.g. TV season poster), replaces [Movie.backdropPath] for the hero image.
  final String? backdropPathOverride;
  final String? trailerYoutubeKey;
  /// TMDB ISO 639-1 original language - keeps YouTube player/captions in source lang.
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
  final String? lastAirDate;
  final List<String> networks;
  final List<String> creators;
  final List<WatchProvider> watchProviders;
  final double? bodyOverlap;
  /// Rendered on the page backdrop below hero chrome (e.g. TV season rail).
  final Widget? pageBottomChild;
  /// Series / season aggregate watched label (details only).
  final Widget? seriesProgress;
  /// When false, hero bleed matches episodes-only height (no season posters).
  final bool showSeasonRail;

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
  bool _trailerIsPlaying = false;
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
      _trailerIsPlaying = false;
      _trailerMuted = false;
      _trailerNeedsRestart = false;
      _webViewController = null;
      _trailerTimer?.cancel();
      _scheduleTrailer();
    }
    if (oldWidget.movie.id != widget.movie.id ||
        oldWidget.backdropPathOverride != widget.backdropPathOverride) {
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
    setState(() {
      _wantsTrailer = false;
      _trailerIsPlaying = false;
    });
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

  bool get _trailerShouldPlay =>
      _heroVisible && _wantsTrailer && _trailerReady && _hasTrailerKey;

  bool get _showTrailer => _trailerShouldPlay && _trailerIsPlaying;

  static String _trailerEmbedHtml(String videoKey, {String? languageCode}) {
    final lang = languageCode?.trim();
    final hasLang = lang != null && lang.isNotEmpty;
    final playerVars = <String, Object>{
      'autoplay': 1,
      'mute': 1,
      'controls': 0,
      'modestbranding': 1,
      'rel': 0,
      'loop': 0,
      'playsinline': 1,
      'fs': 0,
      'iv_load_policy': 3,
      'disablekb': 1,
      'cc_load_policy': 3,
      'enablejsapi': 1,
    };
    if (hasLang) {
      playerVars['hl'] = lang;
      playerVars['cc_lang_pref'] = lang;
    }
    final embedSrc = youtubeNocookieEmbedSrc(
      videoId: videoKey,
      playerVars: playerVars,
    );
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
    #end-shield {
      position: absolute;
      inset: 0;
      background: #000;
      opacity: 0;
      z-index: 20;
      pointer-events: none;
      transition: opacity 0.35s ease;
    }
    #center-shield {
      position: absolute;
      left: 50%;
      top: 50%;
      width: 96px;
      height: 96px;
      transform: translate(-50%, -50%);
      border-radius: 50%;
      background: #000;
      opacity: 0;
      z-index: 18;
      pointer-events: none;
    }
  </style>
</head>
<body>
  <div id="viewport">
    ${youtubeEmbedIframeHtml(embedSrc: embedSrc)}
    <div id="center-shield"></div>
    <div id="end-shield"></div>
  </div>
  <script>
    $youtubeIframeReferrerPatchJs

    var tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);

    var player;
    var volumeRampTimer = null;
    var endGuardTimer = null;
    window._ytVolume = 0;
    window._ytMuted = false;
    window._trailerFinished = false;
    window._trailerShouldPlay = false;
    window._audioStarted = false;
    var playGuardTimer = null;

    function onYouTubeIframeAPIReady() {
      patchYoutubeIframeReferrer(document.getElementById('player'));
      player = new YT.Player('player', {
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

    function clearEndGuard() {
      if (endGuardTimer) {
        clearInterval(endGuardTimer);
        endGuardTimer = null;
      }
    }

    function clearPlayGuard() {
      if (playGuardTimer) {
        clearInterval(playGuardTimer);
        playGuardTimer = null;
      }
    }

    function ensureTrailerPlaying(p) {
      if (!window._trailerShouldPlay || window._trailerFinished) return;
      try {
        var state = p.getPlayerState();
        if (state === YT.PlayerState.PAUSED ||
            state === YT.PlayerState.CUED ||
            state === YT.PlayerState.UNSTARTED) {
          p.playVideo();
        }
      } catch (e) {}
    }

    function startPlayGuard(p) {
      clearPlayGuard();
      playGuardTimer = setInterval(function() {
        if (!p || !p.getPlayerState) return;
        ensureTrailerPlaying(p);
      }, 200);
    }

    function setCenterShield(visible) {
      var shield = document.getElementById('center-shield');
      if (shield) shield.style.opacity = visible ? '1' : '0';
    }

    function setEndShield(opacity) {
      var shield = document.getElementById('end-shield');
      if (shield) shield.style.opacity = String(opacity);
    }

    function finishTrailer(p) {
      if (window._trailerFinished) return;
      window._trailerFinished = true;
      window._trailerShouldPlay = false;
      clearEndGuard();
      clearPlayGuard();
      setCenterShield(false);
      notifyPlayback(false);
      setEndShield(1);
      try {
        p.pauseVideo();
        p.seekTo(0, true);
      } catch (e) {}
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('trailerEnded');
      }
    }

    function startEndGuard(p) {
      clearEndGuard();
      window._trailerFinished = false;
      setEndShield(0);
      endGuardTimer = setInterval(function() {
        if (!p || !p.getCurrentTime || !p.getDuration) return;
        try {
          var t = p.getCurrentTime();
          var d = p.getDuration();
          if (!(d > 0)) return;
          var remaining = d - t;
          if (remaining <= 2.5) {
            setEndShield(Math.min(1, (2.5 - remaining) / 2.5));
          }
          if (remaining <= 0.35) {
            finishTrailer(p);
          }
        } catch (e) {}
      }, 100);
    }

    function notifyReady() {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('trailerReady');
      }
    }

    function notifyPlayback(playing) {
      setCenterShield(!playing && window._trailerShouldPlay && !window._trailerFinished);
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('trailerPlayback', playing);
      }
    }

    function beginAudioRamp(p) {
      if (window._audioStarted || window._ytMuted) return;
      window._audioStarted = true;
      try {
        p.unMute();
        p.setVolume(0);
        window._ytVolume = 0;
        startVolumeRamp(p, 0, 100, 3000);
      } catch (e) {}
    }

    function onPlayerReady(e) {
      var p = e.target;
      cropYoutubeChrome(p);
      disableCaptions(p);
      setTimeout(function() { cropYoutubeChrome(p); }, 150);
      setTimeout(function() { cropYoutubeChrome(p); }, 600);
      window._audioStarted = false;
      try {
        p.mute();
        p.playVideo();
      } catch (e) {}
      pickBestQuality(p);
      startEndGuard(p);
      startPlayGuard(p);
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

    function onPlayerStateChange(e) {
      var p = e.target;
      if (e.data === YT.PlayerState.PLAYING) {
        setCenterShield(false);
        notifyPlayback(true);
        beginAudioRamp(p);
        cropYoutubeChrome(p);
        disableCaptions(p);
        pickBestQuality(p);
        startEndGuard(p);
        startPlayGuard(p);
      }
      if (e.data === YT.PlayerState.PAUSED ||
          e.data === YT.PlayerState.CUED ||
          e.data === YT.PlayerState.UNSTARTED) {
        clearEndGuard();
        notifyPlayback(false);
        ensureTrailerPlaying(p);
      }
      if (e.data === YT.PlayerState.BUFFERING) {
        clearEndGuard();
        setCenterShield(window._trailerShouldPlay && !window._trailerFinished);
      }
      if (e.data === YT.PlayerState.ENDED) {
        notifyPlayback(false);
        finishTrailer(p);
      }
    }

    window.restartTrailer = function() {
      if (!player || !player.seekTo) return;
      if (volumeRampTimer) clearInterval(volumeRampTimer);
      clearEndGuard();
      window._trailerFinished = false;
      window._trailerShouldPlay = true;
      window._audioStarted = false;
      setEndShield(0);
      setCenterShield(true);
      cropYoutubeChrome(player);
      disableCaptions(player);
      player.seekTo(0, true);
      try {
        player.mute();
        player.playVideo();
      } catch (e) {}
      pickBestQuality(player);
      startEndGuard(player);
      startPlayGuard(player);
    };

    window.setTrailerShouldPlay = function(shouldPlay) {
      window._trailerShouldPlay = !!shouldPlay;
      if (!player) return;
      if (shouldPlay) {
        setCenterShield(true);
        ensureTrailerPlaying(player);
        startPlayGuard(player);
      } else {
        clearPlayGuard();
        setCenterShield(false);
        try { player.mute(); } catch (e) {}
      }
    };

    window.setTrailerMuted = function(muted) {
      window._ytMuted = muted;
      if (!player || !player.setVolume) return;
      if (muted) {
        player.mute();
      } else {
        player.unMute();
        player.setVolume(window._ytVolume || 100);
        window._audioStarted = true;
      }
    };

    window.setTrailerPlaying = function(playing) {
      window.setTrailerShouldPlay(playing);
      if (!player || !player.playVideo) return;
      if (playing) player.playVideo();
    };
  </script>
</body>
</html>''';
  }

  Future<void> _syncTrailerPlayback() async {
    final controller = _webViewController;
    if (controller == null) return;
    final shouldPlay = _trailerShouldPlay;
    if (shouldPlay && _trailerNeedsRestart) {
      _trailerNeedsRestart = false;
      await controller.evaluateJavascript(
        source: 'window.restartTrailer && window.restartTrailer();',
      );
    } else {
      await controller.evaluateJavascript(
        source:
            'window.setTrailerShouldPlay && window.setTrailerShouldPlay($shouldPlay);',
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
    final path = _effectiveBackdropPath;
    return path.isNotEmpty ? TmdbApi.getBackdropUrl(path) : '';
  }

  /// Primary path + TMDB screenshots (skipped when a season override is pinned).
  List<String> get _backdropUrls {
    final override = widget.backdropPathOverride?.trim();
    if (override != null && override.isNotEmpty) {
      final url = override.startsWith('http')
          ? override
          : TmdbApi.getBackdropUrl(override);
      return url.isEmpty ? const [] : [url];
    }
    final urls = <String>[];
    void addPath(String path) {
      final p = path.trim();
      if (p.isEmpty) return;
      urls.add(p.startsWith('http') ? p : TmdbApi.getBackdropUrl(p));
    }

    addPath(widget.movie.backdropPath);
    for (final shot in widget.movie.screenshots) {
      addPath(shot);
    }
    if (urls.isEmpty) addPath(widget.movie.posterPath);
    return RotatingHeroBackdrop.normalizeUrls(urls);
  }

  String get _effectiveBackdropPath {
    final override = widget.backdropPathOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    if (widget.movie.backdropPath.isNotEmpty) return widget.movie.backdropPath;
    return widget.movie.posterPath;
  }

  String? get _logoUrl => widget.movie.logoPath.isNotEmpty
      ? TmdbApi.getImageUrl(widget.movie.logoPath)
      : null;

  int? get _positionMs {
    final p = widget.progress;
    if (p == null || p['position'] == null) return null;
    return watchHistoryInt(p['position']);
  }

  int? get _durationMs {
    final p = widget.progress;
    if (p == null || p['duration'] == null) return null;
    return watchHistoryInt(p['duration']);
  }

  Color _shellBg(BuildContext context) => AppTheme.bgDark;

  Widget _buildBackdropMedia(Color shellBg) {
    final urls = _backdropUrls;
    if (urls.isEmpty) {
      return ColoredBox(color: shellBg);
    }

    return RotatingHeroBackdrop(
      imageUrls: urls,
      showColorTint: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEpisodeRail = widget.pageBottomChild != null;
    final h = widget.height ??
        DetailsTokens.heroHeight(
          context,
          showEpisodeRail: showEpisodeRail,
          showSeasonRail: widget.showSeasonRail,
        );
    final bleed = showEpisodeRail
        ? DetailsTokens.episodeRailBleed(showSeasonRail: widget.showSeasonRail)
        : 0.0;
    final totalH = h + bleed;
    final shellBg = _shellBg(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cinematicDesktop = viewportWidth >= 900;
    final contentInset =
        DetailsTokens.contentHorizontalPadding(viewportWidth);
    final heroContentTop = topInset + DetailsTokens.heroContentTopInset;
    final bodyOverlap =
        widget.bodyOverlap ?? DetailsTokens.heroBodyOverlap;
    final pageBleed = bleed > 0;

    return VisibilityDetector(
      key: ValueKey('media-hero-${widget.movie.id}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.15;
        if (_heroVisible == visible) return;
        setState(() => _heroVisible = visible);
        _syncTrailerPlayback();
      },
      child: SizedBox(
        height: totalH,
        width: double.infinity,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
            ColoredBox(color: shellBg),
            Positioned.fill(
              child: ClipRect(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _showTrailer ? 0 : 1,
                  child: _buildBackdropMedia(shellBg),
                ),
              ),
            ),
            if (cinematicDesktop)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _showTrailer ? 0 : 1,
                    child: _CinematicHeroBottomGradient(
                      shellBg: shellBg,
                      overlap: pageBleed ? 0 : bodyOverlap,
                      softFade: pageBleed,
                    ),
                  ),
                ),
              ),
            if (_hasTrailerKey && _showTrailer)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: h,
                child: ClipRect(
                  child: IgnorePointer(
                    child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ForjaInAppWebView(
                            key: ValueKey(
                              'trailer-${widget.trailerYoutubeKey}',
                            ),
                            initialData: InAppWebViewInitialData(
                              data: _trailerEmbedHtml(
                                widget.trailerYoutubeKey!,
                                languageCode: widget.trailerLanguageCode,
                              ),
                              baseUrl: WebUri(kYoutubeEmbedOrigin),
                            ),
                            initialSettings: InAppWebViewSettings(
                              mediaPlaybackRequiresUserGesture: false,
                              allowsInlineMediaPlayback: true,
                              transparentBackground: true,
                              disableVerticalScroll: true,
                              disableHorizontalScroll: true,
                              supportZoom: false,
                            ),
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
                                handlerName: 'trailerPlayback',
                                callback: (args) {
                                  final playing =
                                      args.isNotEmpty && args.first == true;
                                  if (!mounted ||
                                      _trailerIsPlaying == playing) {
                                    return;
                                  }
                                  setState(() => _trailerIsPlaying = playing);
                                },
                              );
                              controller.addJavaScriptHandler(
                                handlerName: 'trailerEnded',
                                callback: (_) => _onTrailerEnded(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (cinematicDesktop)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _showTrailer ? 0 : 1,
                    child: _CinematicHeroSideGradient(shellBg: shellBg),
                  ),
                ),
              ),
            if (!cinematicDesktop)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: (pageBleed ? totalH * 0.42 : h * 0.55 + bodyOverlap),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _showTrailer ? 0 : 1,
                    child: _HeroBottomFade(shellBg: shellBg, soft: pageBleed),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: heroContentTop,
              bottom: bleed +
                  DetailsTokens.heroContentToRailGap(h) +
                  bottomInset,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ShellTokens.bodyMaxWidthDesktop,
                        maxHeight: constraints.maxHeight,
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
                              status: widget.status,
                              lastAirDate: widget.lastAirDate,
                              networks: widget.networks,
                              creators: widget.creators,
                              watchProviders: widget.watchProviders,
                              certification: widget.certification,
                              imdbRating: widget.imdbRating,
                              actionRow: widget.actionRow,
                              positionMs: _positionMs,
                              durationMs: _durationMs,
                              seriesProgress: widget.seriesProgress,
                              availableWidth: constraints.maxWidth,
                              maxHeight: constraints.maxHeight,
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
                  );
                },
              ),
            ),
            if (widget.pageBottomChild != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ShellTokens.bodyMaxWidthDesktop,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        DetailsTokens.episodeSectionTopPadding,
                        0,
                        DetailsTokens.episodeSectionBottomPadding,
                      ),
                      child: widget.pageBottomChild!,
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

class _HeroBottomFade extends StatelessWidget {
  const _HeroBottomFade({required this.shellBg, this.soft = false});

  final Color shellBg;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: soft
              ? [
                  Colors.transparent,
                  shellBg.withValues(alpha: 0.18),
                  shellBg.withValues(alpha: 0.48),
                  shellBg.withValues(alpha: 0.78),
                  shellBg,
                ]
              : [
                  Colors.transparent,
                  shellBg.withValues(alpha: 0.45),
                  shellBg.withValues(alpha: 0.82),
                  shellBg,
                  shellBg,
                ],
          stops: soft
              ? const [0.0, 0.42, 0.68, 0.9, 1.0]
              : const [0.0, 0.35, 0.68, 0.92, 1.0],
        ),
      ),
    );
  }
}

class _CinematicHeroBottomGradient extends StatelessWidget {
  const _CinematicHeroBottomGradient({
    required this.shellBg,
    this.overlap = 0,
    this.softFade = false,
  });

  final Color shellBg;
  final double overlap;
  final bool softFade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction = softFade ? 0.42 : 0.55;
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: constraints.maxHeight * fraction + overlap,
              width: double.infinity,
              child: _HeroBottomFade(shellBg: shellBg, soft: softFade),
            ),
          ),
        );
      },
    );
  }
}

class _CinematicHeroSideGradient extends StatelessWidget {
  const _CinematicHeroSideGradient({required this.shellBg});

  final Color shellBg;

  @override
  Widget build(BuildContext context) {
    final fadeEnd = ShellTokens.heroImageGradientFadeEndFraction;

    return IgnorePointer(
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
            stops: [
              0.0,
              fadeEnd * 0.31,
              fadeEnd * 0.66,
              fadeEnd,
            ],
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
    this.status,
    this.lastAirDate,
    this.networks = const [],
    this.creators = const [],
    this.watchProviders = const [],
    this.certification,
    this.imdbRating,
    this.actionRow,
    this.positionMs,
    this.durationMs,
    this.seriesProgress,
    this.availableWidth,
    this.maxHeight,
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
  final String? status;
  final String? lastAirDate;
  final List<String> networks;
  final List<String> creators;
  final List<WatchProvider> watchProviders;
  final String? certification;
  final double? imdbRating;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;
  final Widget? seriesProgress;
  final double? availableWidth;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final leftColumnWidth =
        width * DetailsTokens.heroDescriptionWidthFraction;
    final mainColumn = _HeroMainColumn(
      movie: movie,
      logoUrl: logoUrl,
      directorName: directorName,
      certification: certification,
      imdbRating: imdbRating,
      watchProviders: watchProviders,
      actionRow: actionRow,
      positionMs: positionMs,
      durationMs: durationMs,
      seriesProgress: seriesProgress,
      maxContentWidth: compact ? (availableWidth ?? width) : leftColumnWidth,
      maxHeight: maxHeight,
    );

    if (compact) {
      return SizedBox(
        width: double.infinity,
        height: maxHeight,
        child: mainColumn,
      );
    }

    final factsPanel = HeroFactsPanel(
      movie: movie,
      status: status,
      budget: budget,
      revenue: revenue,
      languageCode: languageCode,
      spokenLanguages: spokenLanguages,
      productionCompanies: productionCompanies,
      originCountries: originCountries,
      lastAirDate: lastAirDate,
      networks: networks,
      creators: creators,
      positionMs: positionMs,
      durationMs: durationMs,
    );

    return SizedBox(
      width: double.infinity,
      height: maxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: leftColumnWidth,
              height: maxHeight,
              child: mainColumn,
            ),
          ),
          if (factsPanel.hasContent && maxHeight != null)
            Align(
              alignment: Alignment.bottomRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 300,
                  maxHeight: maxHeight!,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [factsPanel],
                  ),
                ),
              ),
            ),
        ],
      ),
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
    this.watchProviders = const [],
    this.actionRow,
    this.positionMs,
    this.durationMs,
    this.seriesProgress,
    this.maxHeight,
  });

  static const _overviewStyle = TextStyle(
    fontSize: 14,
    height: 1.6,
    color: Color(0xB8FFFFFF),
  );
  static const _titleBlockHeight = 120.0;
  static const _titleMinHeight = 32.0;
  static const _genreBlockHeight = 20.0;
  static const _metaBlockHeight = 24.0;
  static const _metaBlockHeightWrapped = 48.0;
  static const _directorBlockHeight = 20.0;
  static const _providersBlockHeight = HeroWatchProvidersRow.rowHeight;
  static const _overviewGap = 14.0;
  static const _actionGap = 18.0;
  static const _progressBlockHeight = 36.0;
  static const _seriesProgressBlockHeight = 28.0;

  final Movie movie;
  final String? logoUrl;
  final double maxContentWidth;
  final String? directorName;
  final String? certification;
  final double? imdbRating;
  final List<WatchProvider> watchProviders;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;
  final Widget? seriesProgress;
  final double? maxHeight;

  static double get _overviewSlotHeight =>
      _overviewStyle.fontSize! *
          _overviewStyle.height! *
          ShellTokens.heroOverviewMaxLinesDesktop +
      ShellTokens.heroOverviewReadMoreGap +
      _overviewStyle.fontSize! * _overviewStyle.height!;

  bool get _metaWraps => maxContentWidth < 480;

  double _metaHeight() =>
      _metaWraps ? _metaBlockHeightWrapped : _metaBlockHeight;

  double _footerReserve({
    required bool showProgress,
    required bool showSeriesProgress,
  }) {
    var reserved = 0.0;
    if (actionRow != null) reserved += _actionGap + ShellTokens.shellButtonHeight;
    if (showProgress) reserved += 14 + _progressBlockHeight;
    if (showSeriesProgress) {
      reserved += (showProgress ? 8 : 14) + _seriesProgressBlockHeight;
    }
    return reserved;
  }

  /// Meta stack only - actions + progress are reserved below in the column.
  double _metaUsedHeight({
    required bool showDirector,
    required bool showGenres,
    required bool showProviders,
    required bool showOverview,
    required bool showMetaLine,
    required double titleHeight,
  }) {
    var used = titleHeight;
    if (showGenres) used += 10 + _genreBlockHeight;
    if (showMetaLine) used += 14 + _metaHeight();
    if (showProviders) used += 10 + _providersBlockHeight;
    if (showDirector) used += 10 + _directorBlockHeight;
    if (showOverview) used += _overviewGap + _overviewSlotHeight;
    return used;
  }

  @override
  Widget build(BuildContext context) {
    final director = directorName?.trim();
    final hasDirector = director != null && director.isNotEmpty;
    final bounded = maxHeight != null && maxHeight!.isFinite && maxHeight! > 0;
    final hasProgress = positionMs != null && durationMs != null;

    var showDirector = hasDirector;
    var showGenres = movie.genres.isNotEmpty;
    var showProviders =
        kShowHeroWatchProviders && watchProviders.isNotEmpty;
    var showOverview = movie.overview.isNotEmpty;
    var showProgress = hasProgress;
    var showSeriesProgress = seriesProgress != null;
    var showMetaLine = true;
    var titleHeight = _titleBlockHeight;

    // Actions + progress under synopsis. Keep title + Play + meta (year /
    // type / cert / rating) first; drop secondary chrome and synopsis before
    // the meta row (720p ATV episode rail used to kill cert + ★). Never zero
    // the title while synopsis is still showing.
    double? metaBudget;
    if (bounded) {
      metaBudget = (maxHeight! -
              _footerReserve(
                showProgress: showProgress,
                showSeriesProgress: showSeriesProgress,
              ))
          .clamp(0.0, maxHeight!);

      bool overBudget() =>
          _metaUsedHeight(
            showDirector: showDirector,
            showGenres: showGenres,
            showProviders: showProviders,
            showOverview: showOverview,
            showMetaLine: showMetaLine,
            titleHeight: titleHeight,
          ) >
          metaBudget!;

      void refreshBudget() {
        metaBudget = (maxHeight! -
                _footerReserve(
                  showProgress: showProgress,
                  showSeriesProgress: showSeriesProgress,
                ))
            .clamp(0.0, maxHeight!);
      }

      if (overBudget()) showDirector = false;
      if (overBudget()) showProviders = false;
      if (overBudget()) showOverview = false;
      if (overBudget()) showGenres = false;
      if (overBudget()) showMetaLine = false;
      if (overBudget() && showSeriesProgress) {
        showSeriesProgress = false;
        refreshBudget();
      }
      if (overBudget() && showProgress) {
        showProgress = false;
        refreshBudget();
      }
      if (overBudget()) {
        final rest = _metaUsedHeight(
          showDirector: showDirector,
          showGenres: showGenres,
          showProviders: showProviders,
          showOverview: showOverview,
          showMetaLine: showMetaLine,
          titleHeight: 0,
        );
        titleHeight = (metaBudget! - rest).clamp(0.0, _titleBlockHeight);
        if (titleHeight < _titleMinHeight) {
          titleHeight = metaBudget!.clamp(0.0, _titleBlockHeight);
          if (titleHeight < _titleMinHeight) titleHeight = 0;
        }
      }
    }

    final overviewHeight = showOverview ? _overviewSlotHeight : 0.0;

    final metaColumn = <Widget>[
      if (titleHeight > 0)
        if (bounded)
          SizedBox(
            height: titleHeight,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: HeroTitle(
                movie: movie,
                logoUrl: logoUrl,
                slotHeight: titleHeight,
              ),
            ),
          )
        else
          HeroTitle(
            movie: movie,
            logoUrl: logoUrl,
          ),
      if (showGenres) ...[
        const SizedBox(height: 10),
        Text(
          movie.genres.take(4).join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.78),
            letterSpacing: 0.2,
          ),
        ),
      ],
      if (showMetaLine) ...[
        const SizedBox(height: 14),
        HeroMetaLine(
          movie: movie,
          certification: certification,
          imdbRating: imdbRating,
        ),
      ],
      if (showProviders) ...[
        const SizedBox(height: 10),
        HeroWatchProvidersRow(providers: watchProviders),
      ],
      if (showDirector) ...[
        const SizedBox(height: 10),
        Text(
          'Director: $director',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
      if (showOverview) ...[
        const SizedBox(height: _overviewGap),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: overviewHeight),
          child: Align(
            alignment: Alignment.topLeft,
            child: HeroOverviewText(
              overview: movie.overview,
              maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
              shrinkWrap: true,
              style: _overviewStyle,
            ),
          ),
        ),
      ],
    ];

    // Pack meta → actions → progress at the top (Play sits under synopsis).
    // Footer height is reserved in the meta budget so tight series chrome
    // (episode rail) never clips Play out of the focus tree.
    final footer = <Widget>[
      if (actionRow != null) ...[
        const SizedBox(height: _actionGap),
        DetailsHeroActionRowFit(child: actionRow!),
      ],
      if (showProgress) ...[
        const SizedBox(height: 14),
        SizedBox(
          width: 280,
          child: WatchProgressBar(
            positionMs: positionMs!,
            durationMs: durationMs!,
          ),
        ),
      ],
      if (showSeriesProgress) ...[
        SizedBox(height: showProgress ? 8 : 14),
        seriesProgress!,
      ],
    ];

    if (!bounded) {
      return SizedBox(
        width: maxContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [...metaColumn, ...footer],
        ),
      );
    }

    return SizedBox(
      width: maxContentWidth,
      height: maxHeight,
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [...metaColumn, ...footer],
        ),
      ),
    );
  }
}
