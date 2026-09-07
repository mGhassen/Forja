// Live Sports hub — list + right panel skin.
// Schedule rows: MetaRuntime `feed` (host may seed `params.scheduleItems`
// from catalog engine feeds until packs own aggregation fully).

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

function liveSportsLayout() {
  return {
    pages: {
      live_matches: {
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
              style: 'list',
              open: 'panel',
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
    return hubOk('layout', liveSportsLayout(), { maxAge: 3600, swr: 86400 });
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
    'live-sports hub: layout + feed/rail only',
  );
}
