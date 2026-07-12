import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:rust/rust.dart';
import 'helpers/rust_engine.dart';

class _RecordingResolver extends StreamProviderResolver {
  int calls = 0;

  @override
  Future<StreamProviderResolveResult?> resolve({
    required String key,
    required Movie movie,
    required int season,
    required int episode,
    required Map<String, dynamic> providers,
    bool Function()? isCancelled,
  }) async {
    calls++;
    if (key == 'kisskh') {
      return StreamProviderResolveResult(
        streamUrl: 'https://cdn.example/stream.m3u8',
        sources: [
          StreamSource(
            url: 'https://cdn.example/stream.m3u8',
            title: 'kisskh',
            type: 'hls',
          ),
        ],
      );
    }
    return null;
  }
}

void main() {
  setUpAll(() async {
    await initRustForAppTests();
  });

  final movie = Movie(
    id: 1,
    title: 'Test Drama',
    posterPath: '',
    backdropPath: '',
    voteAverage: 0,
    releaseDate: '',
    mediaType: 'tv',
  );

  group('PlaybackEngine resolver selection', () {
    test('kisskh skips failed-url blocklist during ranking', () async {
      PlaybackSelection.recordFailedUrl('https://cdn.example/stream.m3u8');
      addTearDown(PlaybackSelection.clearFailedUrls);

      final resolver = _RecordingResolver();
      final hit = await PlaybackEngine.resolveStreamingRace(
        providers: {
          'kisskh': {'dramaId': 1},
        },
        movie: movie,
        season: 1,
        episode: 1,
        resolver: resolver,
        maxInFlight: 1,
      );
      expect(hit, isNotNull);
      expect(hit!.streamUrl, 'https://cdn.example/stream.m3u8');
    });

    test('single kisskh provider uses custom resolver at high maxInFlight', () async {
      final resolver = _RecordingResolver();
      final hit = await PlaybackEngine.resolveStreamingRace(
        providers: {
          'kisskh': {'dramaId': 1},
        },
        movie: movie,
        season: 1,
        episode: 1,
        resolver: resolver,
        maxInFlight: 6,
      );
      expect(resolver.calls, 1);
      expect(hit, isNotNull);
      expect(hit!.providerId, 'kisskh');
      expect(hit.streamUrl, contains('.m3u8'));
    });
  });
}
