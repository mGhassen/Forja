import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/kit/kit_panel_tabs.dart';

void main() {
  test('kitPanelTabsFromSpec reads pack tabs', () {
    final tabs = kitPanelTabsFromSpec({
      'panelTab': 'alpha',
      'panelTabs': [
        {'id': 'alpha', 'label': 'Alpha', 'icon': 'dns'},
        {
          'id': 'beta',
          'label': 'Beta',
          'icon': 'tv',
          'browse': true,
          'action': 'loadBeta',
        },
      ],
    });
    expect(tabs.map((t) => t.id).toList(), ['alpha', 'beta']);
    expect(tabs.last.browse, isTrue);
    expect(kitPanelDefaultTabId({'panelTab': 'alpha'}, tabs), 'alpha');
    expect(kitPanelBrowseTabIds(tabs), {'beta'});
    expect(kitPanelTabLoadId(tabs, 'beta'), 'loadBeta');
    expect(kitPanelTabLoadId(tabs, 'alpha'), 'alpha');
    expect(kitPanelTabIcon('dns'), Icons.dns_rounded);
    expect(kitPanelTabIcon('tv'), Icons.live_tv_rounded);
  });

  test('kitPanelChromeFromLayouts uses first kit.list with panelTabs', () {
    final chrome = kitPanelChromeFromLayouts([
      {
        'type': 'kit.stack',
        'id': 'page',
        'children': [
          {'type': 'kit.topBar', 'id': 'chrome'},
          {
            'type': 'kit.list',
            'id': 'schedule',
            'source': 'test-feed',
            'panelTab': 'alpha',
            'panelTabs': [
              {'id': 'alpha', 'label': 'Alpha'},
              {'id': 'beta', 'label': 'Beta', 'browse': true},
            ],
          },
        ],
      },
    ]);
    expect(chrome.tabs.map((t) => t.id).toList(), ['alpha', 'beta']);
    expect(chrome.initial, 'alpha');
  });

  test('empty spec invents nothing', () {
    expect(kitPanelTabsFromSpec({'source': 'test-feed'}), isEmpty);
    expect(kitPanelChromeFromLayouts(const []).tabs, isEmpty);
  });
}
