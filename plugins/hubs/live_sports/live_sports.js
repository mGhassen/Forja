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
      // Host owns Status × Horizon sheet; token is `status|horizon`.
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
