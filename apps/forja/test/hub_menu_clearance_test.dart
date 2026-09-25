import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/runtime/kit/hub_menu_clearance.dart';

EnginePlugin _hub(List<String> capabilities) {
  return EnginePlugin(
    id: 'hub-a',
    name: 'Hub A',
    entry: 'entry.js',
    kind: 'catalog',
    capabilities: capabilities,
  );
}

void main() {
  test('leading rail clears a visible menu', () {
    expect(
      hubFirstSectionTopInset(
        menuVisible: true,
        leadingIsHero: false,
        menuHeight: 59,
      ),
      59,
    );
  });

  test('leading hero stays under the menu', () {
    expect(
      hubFirstSectionTopInset(
        menuVisible: true,
        leadingIsHero: true,
        menuHeight: 59,
      ),
      0,
    );
  });

  test('no inset when the shell menu is absent', () {
    expect(
      hubFirstSectionTopInset(
        menuVisible: false,
        leadingIsHero: false,
        menuHeight: 59,
      ),
      0,
    );
  });

  test('search or filters mount the shell menu', () {
    expect(
      hubShellTopBarVisible(_hub(['nav', 'layout', 'search']), hasVerticalFilters: false),
      isTrue,
    );
    expect(
      hubShellTopBarVisible(_hub(['nav', 'layout', 'filters']), hasVerticalFilters: false),
      isTrue,
    );
  });

  test('layout-only hubs keep chrome in the body', () {
    expect(
      hubShellTopBarVisible(
        _hub(['nav', 'layout', 'livetv']),
        hasVerticalFilters: false,
      ),
      isFalse,
    );
    expect(
      hubShellTopBarVisible(
        _hub(['nav', 'layout']),
        hasVerticalFilters: false,
      ),
      isFalse,
    );
  });

  test('vertical filters alone still mount the menu', () {
    expect(
      hubShellTopBarVisible(null, hasVerticalFilters: true),
      isTrue,
    );
    expect(
      hubShellTopBarVisible(null, hasVerticalFilters: false),
      isFalse,
    );
  });
}
