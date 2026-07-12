import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:rust/rust.dart';

class TrailerPlayerScreen extends StatefulWidget {
  const TrailerPlayerScreen({
    super.key,
    required this.trailers,
    required this.initialIndex,
    this.movie,
    this.languageCode,
  });

  final List<MediaTrailer> trailers;
  final int initialIndex;
  final Movie? movie;
  final String? languageCode;

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  InAppWebViewController? _controller;
  late int _currentIndex;
  bool _playing = false;
  bool _ended = false;
  bool _muted = false;
  bool _ready = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final FocusNode _playFocus = FocusNode(debugLabel: 'trailer-play');
  final FocusNode _nextTrailerFocus = FocusNode(debugLabel: 'trailer-next');
  bool _tvFocus = false;
  bool _initialFocusClaimed = false;

  MediaTrailer get _trailer => widget.trailers[_currentIndex];

  bool get _hasNextTrailer => _currentIndex < widget.trailers.length - 1;

  MediaTrailer? get _nextTrailer =>
      _hasNextTrailer ? widget.trailers[_currentIndex + 1] : null;

  bool get _showReplayControl => _ended && _hasNextTrailer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _playFocus.dispose();
    _nextTrailerFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv == _tvFocus) return;
    _tvFocus = tv;
    if (tv && !_initialFocusClaimed) {
      _initialFocusClaimed = true;
      _claimPlayFocus();
    }
  }

  void _claimPlayFocus() {
    if (!_tvFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playFocus.canRequestFocus) return;
      _playFocus.requestFocus();
    });
  }

  void _focusNextTrailerIfNeeded() {
    if (!_tvFocus || !_ended || !_hasNextTrailer) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_nextTrailerFocus.canRequestFocus) return;
      _nextTrailerFocus.requestFocus();
    });
  }

  void _exitTrailer() {
    if (PlayerPopupPanel.isShowing) {
      PlayerPopupPanel.dismiss();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_tvFocus) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    _exitTrailer();
    return true;
  }

  String _embedHtml() {
    final lang = widget.languageCode?.trim();
    final hasLang = lang != null && lang.isNotEmpty;
    final playerVars = <String, Object>{
      'autoplay': 1,
      'mute': 0,
      'controls': 0,
      'modestbranding': 1,
      'rel': 0,
      'loop': 0,
      'playsinline': 1,
      'fs': 0,
      'iv_load_policy': 3,
      'disablekb': 1,
      'cc_load_policy': 0,
      'enablejsapi': 1,
    };
    if (hasLang) {
      playerVars['hl'] = lang;
      playerVars['cc_lang_pref'] = lang;
    }
    final embedSrc = youtubeNocookieEmbedSrc(
      videoId: _trailer.key,
      playerVars: playerVars,
    );
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
    var endGuardTimer = null;
    var progressTimer = null;
    var captionProbeLangs = [$captionProbeLangs];
    var captionsApiReady = false;
    var captionsVisible = false;
    var pendingCaptionLang = undefined;

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
        // Heavy overscan hides YouTube chrome but also clips bottom captions.
        var overscan = captionsVisible ? 1.06 : 1.42;
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
        iframe.style.transform = captionsVisible
          ? 'translate(-50%, -58%)'
          : 'translate(-50%, -50%)';
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

    function applyCaptionTrack(languageCode) {
      if (!player) return;
      ensureCaptionsModule();
      if (!captionsApiReady) {
        pendingCaptionLang = languageCode;
        return;
      }
      try {
        if (!languageCode) {
          player.setOption('captions', 'track', {});
          captionsVisible = false;
        } else {
          player.setOption('captions', 'track', { languageCode: languageCode });
          try { player.setOption('captions', 'reload', true); } catch (e2) {}
          captionsVisible = true;
        }
        cropYoutubeChrome(player);
      } catch (e) {}
    }

    function flushPendingCaptionTrack() {
      if (pendingCaptionLang === undefined) return;
      var lang = pendingCaptionLang;
      pendingCaptionLang = undefined;
      applyCaptionTrack(lang);
    }

    function onCaptionsApiChange() {
      if (!player || typeof player.setOption !== 'function') return;
      captionsApiReady = true;
      flushPendingCaptionTrack();
    }

    function onYouTubeIframeAPIReady() {
      patchYoutubeIframeReferrer(document.getElementById('player'));
      player = new YT.Player('player', {
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
          },
          onApiChange: function() {
            onCaptionsApiChange();
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
      applyCaptionTrack(languageCode || null);
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

    window.trailerGetPlaybackRate = function() {
      if (!player || typeof player.getPlaybackRate !== 'function') return 1;
      try { return player.getPlaybackRate(); } catch (e) { return 1; }
    };

    window.trailerSetPlaybackRate = function(rate) {
      if (!player || typeof player.setPlaybackRate !== 'function') return;
      try { player.setPlaybackRate(rate); } catch (e) {}
    };

    window.trailerGetAvailablePlaybackRates = function() {
      if (!player || typeof player.getAvailablePlaybackRates !== 'function') return [1];
      try { return player.getAvailablePlaybackRates(); } catch (e) { return [1]; }
    };

    window.trailerGetPlaybackQuality = function() {
      if (!player || typeof player.getPlaybackQuality !== 'function') return 'auto';
      try { return player.getPlaybackQuality(); } catch (e) { return 'auto'; }
    };

    window.trailerGetAvailableQualityLevels = function() {
      if (!player || typeof player.getAvailableQualityLevels !== 'function') return [];
      try { return player.getAvailableQualityLevels(); } catch (e) { return []; }
    };

    window.trailerSetPlaybackQuality = function(quality) {
      if (!player || typeof player.setPlaybackQuality !== 'function') return;
      try { player.setPlaybackQuality(quality); } catch (e) {}
    };

    window.addEventListener('resize', function() {
      if (player) cropYoutubeChrome(player);
    });

    document.addEventListener('keydown', function(e) {
      if (e.key !== 'Escape' || !window.flutter_inappwebview) return;
      e.preventDefault();
      window.flutter_inappwebview.callHandler('trailerEscape');
    }, true);
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
    if (_ended) setState(() => _ended = false);
    await _runJs('window.trailerSeekTo(${position.inMilliseconds / 1000});');
  }

  Future<void> _skip(int seconds) async {
    if (!_ready) return;
    await _runJs('window.trailerSkip($seconds);');
  }

  void _playNextTrailer() {
    if (!_hasNextTrailer) return;
    PlayerPopupPanel.dismiss();
    setState(() {
      _currentIndex++;
      _controller = null;
      _playing = false;
      _ended = false;
      _ready = false;
      _muted = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _claimPlayFocus();
  }

  Future<void> _showSubtitleMenu(BuildContext anchorContext) async {
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
      anchorContext: anchorContext,
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

  Future<void> _showAudioMenu(BuildContext anchorContext) async {
    if (!_ready) return;
    final tracksRaw = await _runJsJson('window.trailerGetAudioTracks()');
    final tracks = _parseAudioTracks(tracksRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          if (tracks.isEmpty)
            PlayerPopupListTile(
              label: _defaultAudioLabel(),
              badge: _defaultAudioBadge(),
              selected: true,
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

  Future<void> _showQualityMenu(BuildContext anchorContext) async {
    if (!_ready) return;
    final currentRaw = await _runJsJson('window.trailerGetPlaybackQuality()');
    final levelsRaw = await _runJsJson('window.trailerGetAvailableQualityLevels()');
    final current = currentRaw is String ? currentRaw : 'auto';
    final levels = _parseQualityLevels(levelsRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          if (levels.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No quality options for this trailer.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ...levels.map((level) {
              return PlayerPopupListTile(
                label: _qualityLabel(level),
                badge: level == 'auto' ? 'AUTO' : null,
                selected: level == current,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await _runJs("window.trailerSetPlaybackQuality('$level');");
                },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showSpeedMenu(BuildContext anchorContext) async {
    if (!_ready) return;
    final rateRaw = await _runJsJson('window.trailerGetPlaybackRate()');
    final ratesRaw = await _runJsJson('window.trailerGetAvailablePlaybackRates()');
    final currentRate = rateRaw is num ? rateRaw.toDouble() : 1.0;
    final rates = _parsePlaybackRates(ratesRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Playback speed',
      leadingIcon: Icons.speed_rounded,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: rates.map((rate) {
          final selected = (rate - currentRate).abs() < 0.01;
          return PlayerPopupListTile(
            label: '${_formatRate(rate)}x',
            selected: selected,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await _runJs('window.trailerSetPlaybackRate($rate);');
            },
          );
        }).toList(),
      ),
    );
  }

  String _defaultAudioLabel() {
    final lang = widget.languageCode?.trim();
    if (lang != null && lang.isNotEmpty) {
      return languageDisplayName(lang);
    }
    return 'Original';
  }

  String? _defaultAudioBadge() {
    final lang = widget.languageCode?.trim();
    if (lang != null && lang.isNotEmpty) return lang.toUpperCase();
    return null;
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

  List<double> _parsePlaybackRates(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const [1.0];
    final rates = raw
        .whereType<num>()
        .map((r) => r.toDouble())
        .where((r) => r > 0)
        .toSet()
        .toList()
      ..sort();
    return rates.isEmpty ? const [1.0] : rates;
  }

  List<String> _parseQualityLevels(dynamic raw) {
    if (raw is! List) return const [];
    const order = [
      'highres',
      'hd1080',
      'hd720',
      'large',
      'medium',
      'small',
      'tiny',
      'auto',
    ];
    final levels = raw
        .map((e) => e?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    levels.sort((a, b) {
      final ai = order.indexOf(a);
      final bi = order.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return levels;
  }

  String _formatRate(double rate) {
    if (rate == rate.roundToDouble()) return rate.toStringAsFixed(0);
    return rate.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _qualityLabel(String code) {
    switch (code) {
      case 'highres':
        return '4K';
      case 'hd1080':
        return '1080p';
      case 'hd720':
        return '720p';
      case 'large':
        return '480p';
      case 'medium':
        return '360p';
      case 'small':
        return '240p';
      case 'tiny':
        return '144p';
      case 'auto':
        return 'Auto';
      default:
        return code;
    }
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
    final tvFocus = _tvFocus;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitTrailer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ForjaInAppWebView(
              key: ValueKey('trailer-player-${_trailer.key}'),
              initialData: InAppWebViewInitialData(
                data: _embedHtml(),
                baseUrl: WebUri(kYoutubeEmbedOrigin),
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
                    if (ended) _focusNextTrailerIfNeeded();
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
                controller.addJavaScriptHandler(
                  handlerName: 'trailerEscape',
                  callback: (_) => _exitTrailer(),
                );
              },
            ),
            DesktopWindowChrome.overlayDragStrip(),
            _buildChromeOverlay(tvFocus: tvFocus),
          ],
        ),
      ),
    );
  }

  Widget _buildChromeOverlay({required bool tvFocus}) {
    final layers = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: DesktopWindowChrome.isDesktop
              ? DesktopWindowChrome.topInset(context) + 6
              : MediaQuery.paddingOf(context).top + 6,
          left: 8,
          child: PlayerFlatIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            tvFocusable: tvFocus,
            onPressed: _exitTrailer,
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExcludeFocus(
            child: PlayerOverlayGradient(isTop: true),
          ),
        ),
        if (_ended && _hasNextTrailer) _buildUpNextOverlay(tvFocus: tvFocus),
        _buildBottomChrome(tvFocus: tvFocus),
      ],
    );

    if (!tvFocus) return layers;
    return Positioned.fill(
      child: FocusScope(
        debugLabel: 'trailer-player-chrome',
        child: FocusTraversalGroup(child: layers),
      ),
    );
  }

  Widget _buildUpNextOverlay({required bool tvFocus}) {
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Next Trailer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );

    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Up next',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _nextTrailer!.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              if (tvFocus)
                FocusableControl(
                  focusNode: _nextTrailerFocus,
                  onTap: _playNextTrailer,
                  borderRadius: 8,
                  child: button,
                )
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _playNextTrailer,
                    borderRadius: BorderRadius.circular(8),
                    child: button,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomChrome({required bool tvFocus}) {
    final excludeFromTraversal = tvFocus && _ended && _hasNextTrailer;
    final chrome = Positioned(
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
                    title: _trailer.name,
                    movie: widget.movie,
                  )
                else
                  Text(
                    _trailer.name,
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
                  tvFocusable: tvFocus,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          focusNode: tvFocus ? _playFocus : null,
                          icon: _showReplayControl
                              ? Icons.replay_rounded
                              : _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                          tooltip: _showReplayControl
                              ? 'Replay'
                              : _playing
                                  ? 'Pause'
                                  : 'Play',
                          onPressed: () {
                            if (!_ready) return;
                            unawaited(_togglePlayPause());
                          },
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          icon: Icons.replay_10_rounded,
                          tooltip: 'Back 10s',
                          onPressed: () {
                            if (!_ready) return;
                            unawaited(_skip(-10));
                          },
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          icon: Icons.forward_10_rounded,
                          tooltip: 'Forward 10s',
                          onPressed: () {
                            if (!_ready) return;
                            unawaited(_skip(10));
                          },
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          icon: _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          tooltip: 'Mute',
                          onPressed: () {
                            if (!_ready) return;
                            unawaited(_toggleMute());
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
                          tvFocusable: tvFocus,
                          icon: Icons.audiotrack_rounded,
                          tooltip: 'Audio',
                          onPressedWithContext: _showAudioMenu,
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          icon: Icons.subtitles_outlined,
                          tooltip: 'Subtitles',
                          onPressedWithContext: _showSubtitleMenu,
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          icon: Icons.hd_outlined,
                          tooltip: 'Quality',
                          onPressedWithContext: _showQualityMenu,
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          tvFocusable: tvFocus,
                          icon: Icons.speed_rounded,
                          tooltip: 'Playback speed',
                          onPressedWithContext: _showSpeedMenu,
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
    );

    if (!excludeFromTraversal) return chrome;
    return ExcludeFocus(child: chrome);
  }
}
