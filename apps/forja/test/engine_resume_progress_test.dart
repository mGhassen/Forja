import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';

void main() {
  group('enginePluginIdFromProgress', () {
    test('reads engine plugin from watch history sourceId', () {
      expect(
        enginePluginIdFromProgress({'sourceId': 'engine:videasy'}),
        'videasy',
      );
      expect(
        enginePluginIdFromProgress({'sourceId': 'engine:vidlink'}),
        'vidlink',
      );
    });

    test('returns null for non-engine sources', () {
      expect(enginePluginIdFromProgress({'sourceId': 'videasy'}), isNull);
      expect(enginePluginIdFromProgress({'sourceId': 'torrent'}), isNull);
      expect(enginePluginIdFromProgress(null), isNull);
    });
  });

  group('preferredEnginePluginForResume', () {
    test('pins engine plugin only when resume position is set', () {
      expect(
        preferredEnginePluginForResume(
          progress: {'sourceId': 'engine:videasy'},
          startPosition: const Duration(minutes: 5),
        ),
        'videasy',
      );
      expect(
        preferredEnginePluginForResume(
          progress: {'sourceId': 'engine:videasy'},
          startPosition: Duration.zero,
        ),
        isNull,
      );
      expect(
        preferredEnginePluginForResume(
          progress: {'sourceId': 'engine:videasy'},
          startPosition: null,
        ),
        isNull,
      );
    });
  });

  group('isEngineSavedProgress', () {
    test('detects engine rows', () {
      expect(
        isEngineSavedProgress({'sourceId': 'engine:miruro'}),
        isTrue,
      );
      expect(isEngineSavedProgress({'sourceId': 'vidsrcwin'}), isFalse);
    });
  });
}
