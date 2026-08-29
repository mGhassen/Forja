// Arabic hub — layout only. Rails answer empty until a source lands.

function arabicLayout() {
  return {
    pages: {
      arabic: {
        widgets: [
          { type: 'rail', id: 'trending', title: 'رائج · Trending', rail: 'trending' },
          { type: 'rail', id: 'series', title: 'مسلسلات · Series', rail: 'series' },
          { type: 'rail', id: 'movies', title: 'أفلام · Movies', rail: 'movies' },
        ],
      },
    },
  };
}

function extract(ctx) {
  var action = hubAction(ctx);

  if (action === 'layout') {
    return hubOk('layout', arabicLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'rail' || action === 'search') {
    return hubItems(action, [], { maxAge: 300 });
  }
  return hubFail(action, 'INVALID_ACTION', 'arabic hub has no action ' + action);
}
