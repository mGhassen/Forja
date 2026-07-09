import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:rust/rust.dart';

const _kYoutubeEmbedOrigin = 'https://com.forja.app';

class TrailerPlayerScreen extends StatefulWidget {
  const TrailerPlayerScreen({
    super.key,
    required this.youtubeKey,
    required this.title,
    this.movie,
    this.languageCode,
  });

  final String youtubeKey;
  final String title;
  final Movie? movie;
  final String? languageCode;

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  InAppWebViewController? _controller;
  bool _playing = false;
  bool _ended = false;
  bool _muted = false;
  bool _ready = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (PlayerPopupPanel.isShowing) {
      PlayerPopupPanel.dismiss();
      return true;
    }
    if (mounted) Navigator.maybePop(context);
    return true;
  }

  String _embedHtml() {
    final lang = widget.languageCode?.trim();
    final hasLang = lang != null && lang.isNotEmpty;
    final langPlayerVars = hasLang
        ? '''
          hl: '$lang',
          cc_lang_pref: '$lang','''
        : '';
    final captionProbeLangs = hasLang
        ? "'$lang','en','es','fr','de','ar','pt','it','ja','ko','zh','ru'"
        : "'en','es','fr','de','ar','pt','it','ja','ko','zh','ru'";
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
    #viewport { position: absolute; inset: 0; overflow: hidden; }
    #player { position: absolute; inset: 0; overflow: hidden; }
    #end-shield {
      position: absolute; inset: 0;
      background: #000; opacity: 0;
      z-index: 20; pointer-events: none;
      transition: opacity 0.25s ease;
    }
    #center-shield {
      position: absolute; left: 50%; top: 50%;
      width: 96px; height: 96px;
      transform: translate(-50%, -50%);
      border-radius: 50%; background: #000;
      opacity: 0; z-index: 18; pointer-events: none;
    }
  </style>
</head>
<body>
  <div id="viewport">
    <div id="player"></div>
    <div id="center-shield"></div>
    <div id="end-shield"></div>
  </div>
  <script>
    var tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);

    var player;
    var endGuardTimer = null;
    var progressTimer = null;
    var captionProbeLangs = [$captionProbeLangs];

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
        var iframeW, iframeH;
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

    function setCenterShield(visible) {
      var shield = document.getElementById('center-shield');
      if (shield) shield.style.opacity = visible ? '1' : '0';
    }

    function setEndShield(opacity) {
      var shield = document.getElementById('end-shield');
      if (shield) shield.style.opacity = String(opacity);
    }

    function clearEndGuard() {
      if (endGuardTimer) {
        clearInterval(endGuardTimer);
        endGuardTimer = null;
      }
    }

    function notifyState(playing, ended) {
      setCenterShield(!playing && !ended);
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('trailerState', playing, ended);
      }
    }

    function notifyProgress() {
      if (!player || !player.getCurrentTime || !player.getDuration) return;
      if (!window.flutter_inappwebview) return;
      try {
        var current = player.getCurrentTime() || 0;
        var duration = player.getDuration() || 0;
        window.flutter_inappwebview.callHandler('trailerProgress', current, duration);
      } catch (e) {}
    }

    function startProgressTimer() {
      if (progressTimer) return;
      progressTimer = setInterval(notifyProgress, 250);
    }

    function stopProgressTimer() {
      if (!progressTimer) return;
      clearInterval(progressTimer);
      progressTimer = null;
    }

    function finishTrailer(p) {
      clearEndGuard();
      setCenterShield(false);
      setEndShield(1);
      notifyState(false, true);
      notifyProgress();
      try { p.pauseVideo(); } catch (e) {}
    }

    function startEndGuard(p) {
      clearEndGuard();
      setEndShield(0);
      endGuardTimer = setInterval(function() {
        if (!p || !p.getCurrentTime || !p.getDuration) return;
        try {
          var t = p.getCurrentTime();
          var d = p.getDuration();
          if (d > 0 && t >= d - 0.35) finishTrailer(p);
        } catch (e) {}
      }, 100);
    }

    function ensureCaptionsModule() {
      try {
        if (player && player.loadModule) player.loadModule('captions');
      } catch (e) {}
    }

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        videoId: '${widget.youtubeKey}',
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 1,
          mute: 0,
          controls: 0,
          modestbranding: 1,
          rel: 0,
          loop: 0,
          playsinline: 1,
          fs: 0,
          iv_load_policy: 3,
          disablekb: 1,
          cc_load_policy: 0,
          enablejsapi: 1,$langPlayerVars
          origin: '$_kYoutubeEmbedOrigin',
          widget_referrer: '$_kYoutubeEmbedOrigin'
        },
        events: {
          onReady: function(e) {
            cropYoutubeChrome(e.target);
            setTimeout(function() { cropYoutubeChrome(e.target); }, 150);
            setTimeout(function() { cropYoutubeChrome(e.target); }, 600);
            try { e.target.playVideo(); } catch (err) {}
            startEndGuard(e.target);
            startProgressTimer();
            notifyProgress();
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('trailerReady');
            }
          },
          onStateChange: function(e) {
            var p = e.target;
            if (e.data === YT.PlayerState.PLAYING) {
              cropYoutubeChrome(p);
              setEndShield(0);
              startEndGuard(p);
              startProgressTimer();
              notifyState(true, false);
            } else if (e.data === YT.PlayerState.BUFFERING) {
              notifyState(true, false);
            } else if (e.data === YT.PlayerState.PAUSED) {
              clearEndGuard();
              notifyProgress();
              notifyState(false, false);
            } else if (e.data === YT.PlayerState.ENDED) {
              finishTrailer(p);
            }
          }
        }
      });
      window._ytPlayer = player;
    }

    window.trailerPlayPause = function() {
      if (!player || !player.getPlayerState) return;
      var state = player.getPlayerState();
      if (state === YT.PlayerState.PLAYING || state === YT.PlayerState.BUFFERING) {
        player.pauseVideo();
      } else {
        setEndShield(0);
        player.playVideo();
        startEndGuard(player);
      }
    };

    window.trailerReplay = function() {
      if (!player || !player.seekTo) return;
      setEndShield(0);
      setCenterShield(true);
      player.seekTo(0, true);
      player.playVideo();
      startEndGuard(player);
    };

    window.trailerSetMuted = function(muted) {
      if (!player) return;
      if (muted) player.mute();
      else player.unMute();
    };

    window.trailerSeekTo = function(seconds) {
      if (!player || !player.seekTo) return;
      setEndShield(0);
      var d = player.getDuration() || 0;
      var t = Math.max(0, seconds);
      if (d > 0) t = Math.min(t, d);
      player.seekTo(t, true);
      notifyProgress();
    };

    window.trailerSkip = function(delta) {
      if (!player || !player.getCurrentTime) return;
      window.trailerSeekTo((player.getCurrentTime() || 0) + delta);
    };

    window.trailerGetCaptionTracks = function() {
      if (!player) return [];
      ensureCaptionsModule();
      var seen = {};
      var out = [];
      for (var i = 0; i < captionProbeLangs.length; i++) {
        try {
          var list = player.getOption('captions', 'tracklist', { languageCode: captionProbeLangs[i] });
          if (!list) continue;
          for (var j = 0; j < list.length; j++) {
            var tr = list[j];
            if (!tr || !tr.languageCode) continue;
            var key = tr.languageCode + '|' + (tr.kind || '');
            if (seen[key]) continue;
            seen[key] = true;
            out.push({
              languageCode: tr.languageCode,
              languageName: tr.name || tr.languageName || tr.languageCode,
              kind: tr.kind || 'standard'
            });
          }
        } catch (e) {}
      }
      return out;
    };

    window.trailerGetActiveCaption = function() {
      if (!player) return null;
      ensureCaptionsModule();
      try {
        var tr = player.getOption('captions', 'track');
        return tr && tr.languageCode ? tr.languageCode : null;
      } catch (e) {
        return null;
      }
    };

    window.trailerSetCaptionTrack = function(languageCode) {
      if (!player) return;
      ensureCaptionsModule();
      try {
        if (!languageCode) {
          player.setOption('captions', 'track', {});
        } else {
          player.setOption('captions', 'track', { languageCode: languageCode });
        }
      } catch (e) {}
    };

    window.trailerGetAudioTracks = function() {
      if (!player || typeof player.getAvailableAudioTracks !== 'function') return [];
      try {
        return player.getAvailableAudioTracks().map(function(t) {
          return {
            id: t.id,
            label: t.displayName || t.id,
            isDefault: !!t.isDefault,
            isActive: !!t.isActive
          };
        });
      } catch (e) {
        return [];
      }
    };

    window.trailerSetAudioTrack = function(id) {
      if (!player || typeof player.setAudioTrack !== 'function') return;
      try { player.setAudioTrack(id); } catch (e) {}
    };

    window.addEventListener('resize', function() {
      if (player) cropYoutubeChrome(player);
    });
  </script>
</body>
</html>
''';
  }

  Future<void> _runJs(String source) async {
    await _controller?.evaluateJavascript(source: source);
  }

  Future<dynamic> _runJsJson(String expression) async {
    final raw = await _controller?.evaluateJavascript(
      source: 'JSON.stringify($expression)',
    );
    if (raw == null) return null;
    return jsonDecode(raw.toString());
  }

  Future<void> _togglePlayPause() async {
    if (_ended) {
      setState(() => _ended = false);
      await _runJs('window.trailerReplay && window.trailerReplay();');
      return;
    }
    await _runJs('window.trailerPlayPause && window.trailerPlayPause();');
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    await _runJs('window.trailerSetMuted(${next ? 'true' : 'false'});');
  }

  Future<void> _seek(Duration position) async {
    if (!_ready) return;
    await _runJs('window.trailerSeekTo(${position.inMilliseconds / 1000});');
  }

  Future<void> _skip(int seconds) async {
    if (!_ready) return;
    await _runJs('window.trailerSkip($seconds);');
  }

  Future<void> _showSubtitleMenu() async {
    if (!_ready) return;
    final tracksRaw = await _runJsJson('window.trailerGetCaptionTracks()');
    final active = await _runJsJson('window.trailerGetActiveCaption()');
    final tracks = _parseCaptionTracks(tracksRaw);
    final activeCode = active is String ? active : null;

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Subtitles',
      leadingIcon: Icons.subtitles_outlined,
      alignment: Alignment.bottomRight,
      margin: const EdgeInsets.only(right: 16, bottom: 120),
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          PlayerPopupListTile(
            label: 'Off',
            selected: activeCode == null,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await _runJs('window.trailerSetCaptionTrack(null);');
            },
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No subtitles available for this trailer.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ...tracks.map((track) {
              final code = track['languageCode'] as String;
              final name = track['languageName'] as String? ?? languageDisplayName(code);
              return PlayerPopupListTile(
                label: name,
                badge: code.toUpperCase(),
                selected: activeCode == code,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await _runJs("window.trailerSetCaptionTrack('$code');");
                },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showAudioMenu() async {
    if (!_ready) return;
    final tracksRaw = await _runJsJson('window.trailerGetAudioTracks()');
    final tracks = _parseAudioTracks(tracksRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      alignment: Alignment.bottomRight,
      margin: const EdgeInsets.only(right: 16, bottom: 120),
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No alternate audio tracks for this trailer.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ...tracks.map((track) {
              final id = track['id'] as String;
              final label = track['label'] as String;
              final selected = track['isActive'] as bool;
              return PlayerPopupListTile(
                label: label,
                selected: selected,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await _runJs("window.trailerSetAudioTrack('$id');");
                },
              );
            }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseCaptionTracks(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final code = item['languageCode']?.toString();
      if (code == null || code.isEmpty || seen.contains(code)) continue;
      seen.add(code);
      out.add({
        'languageCode': code,
        'languageName': item['languageName']?.toString() ?? languageDisplayName(code),
      });
    }
    out.sort((a, b) => compareLanguageCodes(
          a['languageCode'] as String,
          b['languageCode'] as String,
        ));
    return out;
  }

  List<Map<String, dynamic>> _parseAudioTracks(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => {
              'id': item['id']?.toString() ?? '',
              'label': item['label']?.toString() ?? 'Unknown',
              'isActive': item['isActive'] == true,
            })
        .where((t) => (t['id'] as String).isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InAppWebView(
            key: ValueKey('trailer-player-${widget.youtubeKey}'),
            initialData: InAppWebViewInitialData(
              data: _embedHtml(),
              baseUrl: WebUri(_kYoutubeEmbedOrigin),
            ),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              transparentBackground: false,
              disableVerticalScroll: true,
              disableHorizontalScroll: true,
              supportZoom: false,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'trailerReady',
                callback: (_) {
                  if (!mounted) return;
                  setState(() => _ready = true);
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'trailerState',
                callback: (args) {
                  if (!mounted || args.length < 2) return;
                  final playing = args[0] == true;
                  final ended = args[1] == true;
                  if (_playing == playing && _ended == ended) return;
                  setState(() {
                    _playing = playing;
                    _ended = ended;
                  });
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'trailerProgress',
                callback: (args) {
                  if (!mounted || args.length < 2) return;
                  final currentSec = (args[0] as num?)?.toDouble() ?? 0;
                  final durationSec = (args[1] as num?)?.toDouble() ?? 0;
                  final pos = Duration(milliseconds: (currentSec * 1000).round());
                  final dur = Duration(milliseconds: (durationSec * 1000).round());
                  if (_position == pos && _duration == dur) return;
                  setState(() {
                    _position = pos;
                    _duration = dur;
                  });
                },
              );
            },
          ),
          DesktopWindowChrome.overlayDragStrip(),
          Positioned(
            top: DesktopWindowChrome.isDesktop
                ? DesktopWindowChrome.topInset(context) + 6
                : MediaQuery.paddingOf(context).top + 6,
            left: 8,
            child: PlayerFlatIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PlayerOverlayGradient(isTop: true),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.movie != null)
                        PlayerTitleMeta(
                          title: widget.title,
                          movie: widget.movie,
                        )
                      else
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 12),
                      CustomSeekbar(
                        duration: _duration,
                        position: _position,
                        onSeek: _seek,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              PlayerFlatIconButton(
                                icon: _ended
                                    ? Icons.replay_rounded
                                    : _playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                tooltip: _ended
                                    ? 'Replay'
                                    : _playing
                                        ? 'Pause'
                                        : 'Play',
                                onPressed: () {
                                  if (!_ready) return;
                                  _togglePlayPause();
                                },
                              ),
                              const SizedBox(width: 2),
                              PlayerFlatIconButton(
                                icon: Icons.replay_10_rounded,
                                tooltip: 'Back 10s',
                                onPressed: () {
                                  if (!_ready) return;
                                  _skip(-10);
                                },
                              ),
                              const SizedBox(width: 2),
                              PlayerFlatIconButton(
                                icon: Icons.forward_10_rounded,
                                tooltip: 'Forward 10s',
                                onPressed: () {
                                  if (!_ready) return;
                                  _skip(10);
                                },
                              ),
                              const SizedBox(width: 2),
                              PlayerFlatIconButton(
                                icon: _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                tooltip: 'Mute',
                                onPressed: () {
                                  if (!_ready) return;
                                  _toggleMute();
                                },
                              ),
                              const SizedBox(width: 8),
                              PlayerTimeRange(
                                position: _position,
                                duration: _duration,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              PlayerFlatIconButton(
                                icon: Icons.audiotrack_rounded,
                                tooltip: 'Audio',
                                onPressed: _showAudioMenu,
                              ),
                              const SizedBox(width: 2),
                              PlayerFlatIconButton(
                                icon: Icons.subtitles_outlined,
                                tooltip: 'Subtitles',
                                onPressed: _showSubtitleMenu,
                              ),
                              if (!_ready) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Loading…',
                                  style: TextStyle(
                                    color: ForjaShellColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
