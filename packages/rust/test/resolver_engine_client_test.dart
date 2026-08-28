import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('buildRequest passes maxInFlight and webstreamr settings', () async {
    final request = await ResolverEngineClient.buildRequest(
      domain: SourceDomain.movies,
      movie: Movie(
        id: 575265,
        title: 'Test',
        overview: '',
        posterPath: '',
        backdropPath: '',
        releaseDate: '2024-01-01',
        voteAverage: 0,
        mediaType: 'movie',
      ),
      season: 1,
      episode: 1,
      providers: {'webstreamr': {}, 'vidsrc': {}},
      maxInFlight: 3,
    );
    final settings = request['settings'] as Map<String, dynamic>;
    expect(settings['maxInFlight'], 3);
    final wsConfig = Map<String, String>.from(
      settings['webstreamrConfig'] as Map,
    );
    expect(wsConfig['multi'], 'on');
    expect(wsConfig['de'], 'on');
    expect(settings.containsKey('webstreamrTmdbAccessToken'), isTrue);
  });

  test('continueWithHost payload shape', () {
    final payload = jsonEncode({
      'sessionId': 're-1',
      'hostResults': [
        {
          'providerId': 'videasy',
          'sourcesJson':
              '[{"url":"https://example.com/a.m3u8","title":"A","container":"hls"}]',
        },
      ],
    });
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    expect(decoded['sessionId'], 're-1');
    expect((decoded['hostResults'] as List).length, 1);
  });
}
