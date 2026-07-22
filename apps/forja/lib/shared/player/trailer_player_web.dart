part of 'trailer_player_screen.dart';

mixin _TrailerPlayerWeb on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

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
      videoId: _s._trailer.key,
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
        // Contain — full frame visible, letterbox if needed. Never cover/overscan
        // (that zoomed the picture past the window).
        if (viewAspect > videoAspect) {
          iframeH = h;
          iframeW = h * videoAspect;
        } else {
          iframeW = w;
          iframeH = w / videoAspect;
        }
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
            ensureCaptionsModule();
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

    window.trailerSetVolume = function(volume) {
      if (!player || typeof player.setVolume !== 'function') return;
      var v = Math.max(0, Math.min(100, Number(volume) || 0));
      try {
        player.setVolume(v);
        if (v <= 0) player.mute();
        else player.unMute();
      } catch (e) {}
    };

    window.trailerGetVolume = function() {
      if (!player) return 100;
      try {
        if (player.isMuted && player.isMuted()) return 0;
        return typeof player.getVolume === 'function' ? player.getVolume() : 100;
      } catch (e) {
        return 100;
      }
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

    // WKWebView / WebView2 eat Flutter gestures over the platform view —
    // bridge pointer / double-click from the page instead.
    var lastTapAt = 0;
    var singleTapTimer = null;
    var lastPointerAt = 0;
    document.addEventListener('click', function(e) {
      if (!window.flutter_inappwebview) return;
      var now = Date.now();
      if (now - lastTapAt < 320) {
        lastTapAt = 0;
        if (singleTapTimer) { clearTimeout(singleTapTimer); singleTapTimer = null; }
        window.flutter_inappwebview.callHandler('trailerDoubleClick');
        return;
      }
      lastTapAt = now;
      if (singleTapTimer) clearTimeout(singleTapTimer);
      singleTapTimer = setTimeout(function() {
        singleTapTimer = null;
        window.flutter_inappwebview.callHandler('trailerTap');
      }, 320);
    }, true);

    document.addEventListener('mousemove', function() {
      if (!window.flutter_inappwebview) return;
      var now = Date.now();
      if (now - lastPointerAt < 180) return;
      lastPointerAt = now;
      window.flutter_inappwebview.callHandler('trailerPointer');
    }, true);

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
    await _s._controller?.evaluateJavascript(source: source);
  }

  Future<dynamic> _runJsJson(String expression) async {
    final raw = await _s._controller?.evaluateJavascript(
      source: 'JSON.stringify($expression)',
    );
    if (raw == null) return null;
    return jsonDecode(raw.toString());
  }

  Future<void> _togglePlayPause() async {
    if (_s._ended) {
      setState(() => _s._ended = false);
      await _runJs('window.trailerReplay && window.trailerReplay();');
      return;
    }
    await _runJs('window.trailerPlayPause && window.trailerPlayPause();');
  }

  Future<void> _toggleMute() async {
    final next = !_s._muted;
    setState(() {
      _s._muted = next;
      if (next) {
        if (_s._volume > 0) _s._volumeBeforeMute = _s._volume;
        _s._volume = 0;
      } else {
        _s._volume = _s._volumeBeforeMute > 0 ? _s._volumeBeforeMute : 100;
      }
    });
    await _runJs('window.trailerSetVolume(${_s._volume});');
  }

  Future<void> _setVolume(double volume) async {
    final next = volume.clamp(0.0, 100.0);
    setState(() {
      _s._volume = next;
      _s._muted = next <= 0;
      if (next > 0) _s._volumeBeforeMute = next;
    });
    await _runJs('window.trailerSetVolume($next);');
  }

  Future<void> _seek(Duration position) async {
    if (!_s._ready) return;
    if (_s._ended) setState(() => _s._ended = false);
    await _runJs('window.trailerSeekTo(${position.inMilliseconds / 1000});');
  }

  Future<void> _skip(int seconds) async {
    if (!_s._ready) return;
    await _runJs('window.trailerSkip($seconds);');
  }

  void _playTrailerAt(int index) {
    if (index < 0 || index >= widget.trailers.length) return;
    if (index == _s._currentIndex && !_s._ended) return;
    PlayerPopupPanel.dismiss();
    setState(() {
      _s._currentIndex = index;
      _s._controller = null;
      _s._playing = false;
      _s._ended = false;
      _s._ready = false;
      _s._muted = false;
      _s._volume = 100;
      _s._volumeBeforeMute = 100;
      _s._selectedQuality = 'auto';
      _s._position = Duration.zero;
      _s._duration = Duration.zero;
      _s._showControls = true;
    });
    _s._claimPlayFocus();
  }

  void _playNextTrailer() {
    if (!_s._hasNextTrailer) return;
    _playTrailerAt(_s._currentIndex + 1);
  }

}

