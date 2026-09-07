// Live Sports hub — list + right panel skin.
// Composes kit primitives only; schedule data is opaque `live_schedule`.

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
      items: [
        { id: 'live', label: 'Live now' },
        { id: '1h', label: '1 hour' },
        { id: '3h', label: '3 hours' },
        { id: '6h', label: '6 hours' },
        { id: '12h', label: '12 hours' },
        { id: '24h', label: '24 hours' },
        { id: 'all', label: 'All' },
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

function extract(ctx) {
  var action = hubAction(ctx);
  if (action === 'layout') {
    return hubOk('layout', liveSportsLayout(), { maxAge: 3600, swr: 86400 });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'live-sports hub exposes layout; schedule browse is the live_matches feature',
  );
}
