import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('splitSourceButtonLines', () {
    test('Videasy · Yoru', () {
      final lines = splitSourceButtonLines('Videasy · Yoru');
      expect(lines.label, 'Videasy');
      expect(lines.server, 'Yoru');
    });

    test('never uses media title as server', () {
      expect(
        splitSourceButtonLines('Videasy · The Whisper Man - (2026)').server,
        isNull,
      );
      expect(
        splitSourceButtonLines(
          'The Whisper Man - (2026)',
          providerHint: 'Videasy',
        ).server,
        isNull,
      );
    });

    test('VidRock Astra', () {
      final lines = splitSourceButtonLines(
        'VidRock Astra',
        providerHint: 'VidRock',
      );
      expect(lines.label, 'VidRock');
      expect(lines.server, 'Astra');
    });
  });

  test('catalogStreamAddonIdentity keeps mirror only', () {
    expect(
      catalogStreamAddonIdentity({
        '_addonName': 'Videasy · Yoru',
        'title': 'The Whisper Man - (2026)',
      }),
      'Videasy · Yoru',
    );
    expect(
      catalogStreamAddonIdentity({
        '_addonName': 'Videasy · The Whisper Man - (2026)',
        'title': 'The Whisper Man - (2026)',
      }),
      'Videasy',
    );
  });
}
