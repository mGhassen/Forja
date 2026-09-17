import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/kit/hub_page_focus.dart';

void main() {
  test('HubPageFocus.parse reads enter/restore/pageBack', () {
    final f = HubPageFocus.parse({
      'focus': {
        'enter': 'cats',
        'restore': 'cats',
        'restoreMode': 'remembered',
        'pageBack': ['items', 'cats'],
      },
    });
    expect(f.enter, 'cats');
    expect(f.restore, 'cats');
    expect(f.restoreRemembered, isTrue);
    expect(f.pageBack, ['items', 'cats']);
    expect(f.isEmpty, isFalse);
  });

  test('HubPageFocus.parse restoreMode first', () {
    final f = HubPageFocus.parse({
      'focus': {'restore': 'kind', 'restoreMode': 'first'},
    });
    expect(f.restoreRemembered, isFalse);
  });

  test('HubPageFocus.parse empty', () {
    expect(HubPageFocus.parse(null).isEmpty, isTrue);
    expect(HubPageFocus.parse({}).isEmpty, isTrue);
    expect(HubPageFocus.parse({'focus': {}}).isEmpty, isTrue);
  });
}
