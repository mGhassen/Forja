import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/list/kit_list_card_kind.dart';

void main() {
  group('resolveKitListCardKind', () {
    test('honors pack cardKind aliases', () {
      expect(
        resolveKitListCardKind(packCardKind: 'channel', style: 'grid'),
        'channel',
      );
      expect(
        resolveKitListCardKind(packCardKind: 'liveChannel', style: 'list'),
        'channel',
      );
      expect(
        resolveKitListCardKind(packCardKind: 'channelList', style: 'grid'),
        'channelList',
      );
      expect(
        resolveKitListCardKind(packCardKind: 'eventCard', style: 'grid'),
        'event',
      );
      expect(
        resolveKitListCardKind(packCardKind: 'poster', style: 'list'),
        'poster',
      );
    });

    test('list style densifies event paint; channel paint → channelList', () {
      expect(
        resolveKitListCardKind(
          packCardKind: '',
          style: 'list',
          items: [
            {
              'paint': {'type': 'eventCard'},
            },
          ],
        ),
        'dense',
      );
      expect(
        resolveKitListCardKind(
          packCardKind: '',
          style: 'list',
          items: [
            {
              'paint': {'type': 'channelCard'},
            },
          ],
        ),
        'channelList',
      );
    });

    test('grid follows majority paint type', () {
      expect(
        resolveKitListCardKind(
          packCardKind: '',
          style: 'grid',
          items: [
            {
              'paint': {'type': 'channelCard'},
            },
            {
              'paint': {'type': 'channelCard'},
            },
          ],
        ),
        'channel',
      );
      expect(
        resolveKitListCardKind(
          packCardKind: '',
          style: 'grid',
          items: [
            {
              'paint': {'type': 'posterCard'},
            },
          ],
        ),
        'poster',
      );
      expect(
        resolveKitListCardKind(
          packCardKind: '',
          style: 'cards',
          items: [
            {
              'paint': {'type': 'eventCard'},
            },
          ],
        ),
        'event',
      );
    });

    test('empty list defaults poster; cards style defaults event', () {
      expect(
        resolveKitListCardKind(packCardKind: '', style: 'grid'),
        'poster',
      );
      expect(
        resolveKitListCardKind(packCardKind: '', style: 'cards'),
        'event',
      );
    });
  });

  group('kitListManagedOpen', () {
    test('openSetting or panelTabs only', () {
      expect(kitListManagedOpen({'open': 'panel'}), isFalse);
      expect(kitListManagedOpen({'panel': 'offline', 'open': 'panel'}), isFalse);
      expect(kitListManagedOpen({'openSetting': 'matchOpen'}), isTrue);
      expect(
        kitListManagedOpen({
          'panelTabs': [
            {'id': 'a'},
          ],
        }),
        isTrue,
      );
    });
  });
}
