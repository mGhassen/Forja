import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/platform/built_in_player_engine_fit.dart';
import 'package:rust/rust.dart';

void main() {
  group('builtInPlayerEngineUnsuitableReason', () {
    test('catalog VOD greys AVPlayer / VLC', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/master.m3u8',
        ),
        'Movies & series use MediaKit',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.vlc,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/file.mp4',
        ),
        'Movies & series use MediaKit',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.mediaKit,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/file.mp4',
        ),
        isNull,
      );
    });

    test('catalog VOD greys Exo for torrent / dual audio', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.exoPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'http://127.0.0.1:8090/stream',
          torrentLocalhost: true,
        ),
        'Torrent streams need MediaKit',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.exoPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/a.mp4',
          separateAudioUrl: true,
        ),
        'Separate audio needs MediaKit',
      );
    });

    test('Widevine greys MediaKit', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.mediaKit,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/dash.mpd',
          needsWidevine: true,
        ),
        'DRM needs ExoPlayer',
      );
    });

    test('IPTV live MPEG-TS greys AVPlayer / VLC; HLS allows them', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.iptvLive,
          streamUrl: 'http://portal/live/1/2/3.ts',
        ),
        'MPEG-TS needs MediaKit',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.iptvLive,
          streamUrl: 'https://cdn.example/live.m3u8',
        ),
        isNull,
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.vlc,
          surface: BuiltInPlayerMenuSurface.iptvVod,
          streamUrl: 'https://cdn.example/movie.m3u8',
        ),
        isNull,
      );
    });
  });
}
