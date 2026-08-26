import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';

void main() {
  group('stream open status', () {
    test('labels for pipeline stages', () {
      expect(
        streamOpenStatusLabel(StreamOpenStatusStage.checking),
        'Checking stream…',
      );
      expect(
        streamOpenStatusLabel(StreamOpenStatusStage.preparing),
        'Preparing stream…',
      );
    });

    test('stream-open row counts as roulette entry', () {
      expect(
        isStatusRouletteEntry(
          const StatusRouletteEntry(
            id: kStreamOpenStatusId,
            label: 'Checking stream…',
            kind: StatusRouletteKind.loading,
          ),
        ),
        isTrue,
      );
    });
  });
}
