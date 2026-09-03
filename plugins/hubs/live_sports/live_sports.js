// Live Sports hub — generic catalog kit layout. Host owns modes, schedule
// merge, chrome, and play via `kit.list { source: live_schedule }` (RFC-071).

function liveSportsLayout() {
  return {
    pages: {
      live_matches: {
        widgets: [
          kitStack(
            'page',
            { expand: true },
            [
              kitList('grid', {
                source: 'live_schedule',
                expand: true,
              }),
            ],
          ),
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
    'live-sports hub only exposes layout — browse and play are host-owned',
  );
}
