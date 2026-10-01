import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart';
import 'package:forja/shell/bus/shell_bus.dart';

void main() {
  tearDown(() {
    PackFiltersRegistry.clearForTest();
    ShellBus.hubSelectedMenuIdFor('stremio').value = null;
  });

  test('catalogChromeTypeFilterValue reads pack menu type eq', () {
    PackFiltersRegistry.seedFromJson('stremio-hub', {
      'menus': [
        {
          'id': 'movie',
          'label': 'Movies',
          'filter': {'op': 'eq', 'field': 'type', 'value': 'movie'},
          'hideTypeFilterRails': true,
        },
        {
          'id': 'anime',
          'label': 'Anime',
          'filter': {'op': 'eq', 'field': 'type', 'value': 'anime'},
          'hideTypeFilterRails': true,
        },
      ],
    });

    expect(
      catalogChromeTypeFilterValue(tabId: 'stremio', pluginId: 'stremio-hub'),
      isNull,
    );

    ShellBus.hubSelectedMenuIdFor('stremio').value = 'anime';
    expect(
      catalogChromeTypeFilterValue(tabId: 'stremio', pluginId: 'stremio-hub'),
      'anime',
    );

    ShellBus.hubSelectedMenuIdFor('stremio').value = 'movie';
    expect(
      catalogChromeTypeFilterValue(tabId: 'stremio', pluginId: 'stremio-hub'),
      'movie',
    );
  });
}
