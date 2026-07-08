import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:rust/rust.dart';

const _kYoutubeEmbedOrigin = 'https://com.forja.app';

class TrailerPlayerScreen extends StatelessWidget {
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

  String _embedHtml() {
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
    #player {
      position: absolute;
      inset: 0;
    }
  </style>
</head>
<body>
  <div id="player"></div>
  <script>
    var tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);

    function onYouTubeIframeAPIReady() {
      new YT.Player('player', {
        videoId: '$youtubeKey',
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 1,
          mute: 0,
          controls: 1,
          modestbranding: 1,
          rel: 0,
          playsinline: 1,
          fs: 1,
          iv_load_policy: 3,
          enablejsapi: 1,$langPlayerVars
          origin: '$_kYoutubeEmbedOrigin',
          widget_referrer: '$_kYoutubeEmbedOrigin'
        },
        events: {
          onReady: function(e) {
            try { e.target.playVideo(); } catch (err) {}
          }
        }
      });
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InAppWebView(
            key: ValueKey('trailer-player-$youtubeKey'),
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
          ),
          Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      PlayerFlatIconButton(
                        icon: Icons.arrow_back,
                        label: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 56,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: IgnorePointer(
                    child: PlayerTitleMeta(
                      title: title,
                      movie: movie,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
