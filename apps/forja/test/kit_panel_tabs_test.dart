import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/chrome/panel_tabs.dart';

void main() {
  test('panelTabsFromSpec reads pack tabs', () {
    final tabs = panelTabsFromSpec({
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
    expect(panelDefaultTabId({'panelTab': 'alpha'}, tabs), 'alpha');
    expect(panelBrowseTabIds(tabs), {'beta'});
    expect(panelTabLoadId(tabs, 'beta'), 'loadBeta');
    expect(panelTabLoadId(tabs, 'alpha'), 'alpha');
    expect(kitPanelTabIcon('dns'), Icons.dns_rounded);
    expect(kitPanelTabIcon('tv'), Icons.live_tv_rounded);
  });

  test('panelChromeFromLayouts uses first kit.list with panelTabs', () {
    final chrome = panelChromeFromLayouts([
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
    expect(panelTabsFromSpec({'source': 'test-feed'}), isEmpty);
    expect(panelChromeFromLayouts(const []).tabs, isEmpty);
  });
}
