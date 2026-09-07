// Live Sports hub — generic catalog kit layout. Feature host owns schedule
// browse/play via opaque `kit.list { source: live_schedule }` (RFC-085).

var LIVE_SPORTS_HORIZON = [
  { id: 'live', label: 'Live' },
  { id: '1h', label: '1h' },
  { id: '3h', label: '3h' },
  { id: '6h', label: '6h' },
  { id: '12h', label: '12h' },
  { id: '24h', label: '24h' },
  { id: 'all', label: 'All' },
];

function liveSportsLayout() {
  return {
    pages: {
      live_matches: {
        widgets: [
          kitStack('page', { expand: true }, [
            kitMenu(
              'catalog',
              [{ id: 'all', label: 'All' }],
              { default: 'all', focusDown: 'horizon' },
            ),
            kitMenu('horizon', LIVE_SPORTS_HORIZON, {
              default: '24h',
              focusUp: 'catalog',
              focusDown: 'schedule',
            }),
            kitList('schedule', {
              source: 'live_schedule',
              style: 'list',
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
