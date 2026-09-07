// Live Sports hub — list + right panel skin.
// Schedule rows: MetaRuntime `feed` composes via ctx.host.liveFeed.load.

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
      live_sports: {
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

function liveSportsShapeRow(row) {
  if (!row || typeof row !== 'object') return null;
  var out = Object.assign({}, row);
  if (!out.name && out.title) out.name = out.title;
  if (!out.type) out.type = 'live_match';
  if (!out.open && out.id) {
    out.open = { surface: 'live', id: String(out.id) };
  }
  return out;
}

function liveSportsLoadFeed(ctx, params) {
  var host = ctx && ctx.host;
  var liveFeed = host && host.liveFeed;
  if (!liveFeed || typeof liveFeed.load !== 'function') {
    return Promise.resolve([]);
  }
  return Promise.resolve(
    liveFeed.load({
      catalogFilter: (params && params.catalogFilter) || 'all',
      sportFilter: (params && params.sportFilter) || 'all',
      scheduleStatus: (params && params.scheduleStatus) || 'both',
      scheduleHorizon: (params && params.scheduleHorizon) || 'h24',
    }),
  ).then(function (rows) {
    if (!Array.isArray(rows)) return [];
    var out = [];
    for (var i = 0; i < rows.length; i++) {
      var shaped = liveSportsShapeRow(rows[i]);
      if (shaped) out.push(shaped);
    }
    return out;
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var params = hubParams(ctx);
  if (action === 'layout') {
    return hubOk('layout', liveSportsLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'feed' || action === 'rail') {
    return liveSportsLoadFeed(ctx, params).then(function (items) {
      return hubItems(action, items, { maxAge: 60, swr: 300 });
    });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'live-sports hub: layout + feed/rail only',
  );
}
