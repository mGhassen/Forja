import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';

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
