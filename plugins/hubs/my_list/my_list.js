// My List hub — layout from catalog kit (`kit.stack`, `kit.menu`, `kit.tabs`, `kit.list`).
// Host feature `features/my_list` registers opaque source `my_list` (RFC-085).

var MY_LIST_KIND_ITEMS = [
  { id: 'movie', label: 'Film' },
  { id: 'tv', label: 'Series' },
  { id: 'anime', label: 'Anime' },
  { id: 'asian_drama', label: 'Asian Drama' },
];

var MY_LIST_STATUS_TABS = [
  { id: 'plantowatch', label: 'Plan to Watch' },
  { id: 'watching', label: 'Watching' },
  { id: 'hold', label: 'On Hold' },
  { id: 'completed', label: 'Completed' },
  { id: 'dropped', label: 'Dropped' },
];

function myListLayout() {
  return {
    pages: {
      mylist: {
        widgets: [
          kitStack(
            'page',
            { expand: true },
            [
              kitMenu('kind', MY_LIST_KIND_ITEMS, {
                toggle: true,
                focusDown: 'status',
              }),
              kitTabs('status', MY_LIST_STATUS_TABS, {
                default: 'plantowatch',
                focusUp: 'kind',
                focusDown: 'grid',
              }),
              kitList('grid', {
                source: 'my_list',
                kindMenu: 'kind',
                statusTab: 'status',
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
    return hubOk('layout', myListLayout(), { maxAge: 3600, swr: 86400 });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'my-list hub exposes layout; list data is host-registered for source my_list',
  );
}
