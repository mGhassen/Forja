// Live Sports hub — generic catalog kit layout. Feature host owns schedule
// browse/play via opaque `kit.list { source: live_schedule }` (RFC-085).

function liveSportsLayout() {
  return {
    pages: {
      live_matches: {
        widgets: [
          kitStack('page', { expand: true }, [
            kitList('grid', {
              source: 'live_schedule',
              style: 'list',
              expand: true,
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
