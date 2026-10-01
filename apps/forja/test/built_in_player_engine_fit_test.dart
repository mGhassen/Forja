import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/platform/built_in_player_engine_fit.dart';
import 'package:rust/rust.dart';

void main() {
  group('builtInPlayerEngineUnsuitableReason', () {
    test('catalog VOD allows AVPlayer / VLC for normal and DASH streams', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/master.m3u8',
        ),
        isNull,
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/dash/x/index_web.mpd',
        ),
        isNull,
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.vlc,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/file.mp4',
        ),
        isNull,
      );
    });

    test('hard-blocks torrent / dual audio for AVPlayer / VLC / Exo', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'http://127.0.0.1:8090/stream',
          torrentLocalhost: true,
        ),
        'Torrent streams need MediaKit',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.vlc,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/a.mp4',
          separateAudioUrl: true,
        ),
        'Separate audio needs MediaKit',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.exoPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'http://127.0.0.1:8090/stream',
          torrentLocalhost: true,
        ),
        'Torrent streams need MediaKit',
      );
    });

    test('Widevine greys MediaKit and AVPlayer / VLC', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.mediaKit,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/dash.mpd',
          needsWidevine: true,
        ),
        'DRM needs ExoPlayer',
      );
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.catalogVod,
          streamUrl: 'https://cdn.example/dash.mpd',
          needsWidevine: true,
        ),
        'DRM needs ExoPlayer',
      );
    });

    test('IPTV MPEG-TS / HLS are not hard-blocked for AVPlayer / VLC', () {
      expect(
        builtInPlayerEngineUnsuitableReason(
          BuiltInPlayerEngine.avPlayer,
          surface: BuiltInPlayerMenuSurface.iptvLive,
          streamUrl: 'http://portal/live/1/2/3.ts',
        ),
        isNull,
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

  group('resolvePlayerMenuBuiltInSelection', () {
    test('keeps preferred when still visible', () {
      expect(
        resolvePlayerMenuBuiltInSelection(
          usingBuiltIn: true,
          preferred: BuiltInPlayerEngine.mediaKit,
          visible: const [
            BuiltInPlayerEngine.mediaKit,
            BuiltInPlayerEngine.exoPlayer,
          ],
        ),
        BuiltInPlayerEngine.mediaKit,
      );
    });

    test('falls back to MediaKit when preferred was filtered out', () {
      expect(
        resolvePlayerMenuBuiltInSelection(
          usingBuiltIn: true,
          preferred: BuiltInPlayerEngine.avPlayer,
          visible: const [BuiltInPlayerEngine.mediaKit],
        ),
        BuiltInPlayerEngine.mediaKit,
      );
    });

    test('external mode selects nothing built-in', () {
      expect(
        resolvePlayerMenuBuiltInSelection(
          usingBuiltIn: false,
          preferred: BuiltInPlayerEngine.mediaKit,
          visible: const [BuiltInPlayerEngine.mediaKit],
        ),
        isNull,
      );
    });
  });
}
