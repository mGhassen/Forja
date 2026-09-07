// Live Sports hub — cards + details page skin.
// Same opaque `live_schedule` source; different kit composition.

function liveSportsCatalogActions() {
  return [
    {
      id: 'catalog',
      label: 'Catalog',
      icon: 'filter',
      items: [
        { id: 'all', label: 'All' },
        { id: 'streamed', label: 'Streamed' },
        { id: 'ppv', label: 'PPV' },
        { id: 'streamfree', label: 'StreamFree' },
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
              style: 'grid',
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

function extract(ctx) {
  var action = hubAction(ctx);
  if (action === 'layout') {
    return hubOk('layout', liveSportsCardsLayout(), {
      maxAge: 3600,
      swr: 86400,
    });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'live-sports-cards hub exposes layout for the Live Sports Cards tab',
  );
}
