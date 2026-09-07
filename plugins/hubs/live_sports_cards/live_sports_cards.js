// Live Sports Cards hub — landscape cards + details skin.
// Same MetaRuntime feed contract as live_sports (scheduleItems).

function liveSportsCatalogActions() {
  return [
    {
      id: 'catalog',
      label: 'Catalog',
      icon: 'filter',
      dynamicCatalogs: true,
      items: [
        { id: 'all', label: 'All' },
      ],
    },
    {
      id: 'horizon',
      label: 'Schedule',
      icon: 'schedule',
      default: 'both|24h',
      items: [
        { id: 'both|24h', label: '24h' },
      ],
    },
    {
      id: 'refresh',
      label: 'Refresh',
      icon: 'refresh',
      action: 'refresh',
    },
  ];
}

function liveSportsCardsLayout() {
  return {
    pages: {
      live_sports_cards: {
        widgets: [
          kitStack('page', { expand: true }, [
            kitTopBar('chrome', {
              focusDown: 'kind',
              actions: liveSportsCatalogActions(),
            }),
            kitCategoryBar('kind', {
              source: 'live_schedule',
              dynamic: true,
              default: 'all',
              focusUp: 'chrome',
              focusDown: 'schedule',
            }),
            kitList('schedule', {
              source: 'live_schedule',
              style: 'cards',
              open: 'details',
              expand: true,
              kindMenu: 'kind',
              catalogMenu: 'catalog',
              horizonMenu: 'horizon',
            }),
          ]),
        ],
      },
    },
  };
}

function liveSportsFeedItems(params) {
  var raw = params && params.scheduleItems;
  if (!Array.isArray(raw)) return [];
  var out = [];
  for (var i = 0; i < raw.length; i++) {
    var row = raw[i];
    if (!row || typeof row !== 'object') continue;
    out.push(row);
  }
  return out;
}

function extract(ctx) {
  var action = hubAction(ctx);
  var params = hubParams(ctx);
  if (action === 'layout') {
    return hubOk('layout', liveSportsCardsLayout(), {
      maxAge: 3600,
      swr: 86400,
    });
  }
  if (action === 'feed' || action === 'rail') {
    return hubItems(action, liveSportsFeedItems(params), {
      maxAge: 60,
      swr: 300,
    });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'live-sports-cards hub: layout + feed/rail only',
  );
}
