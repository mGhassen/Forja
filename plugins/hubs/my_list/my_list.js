// My List hub — layout + feed via ctx.host.myList.load (RFC-097).

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

function myListKindFromRow(row) {
  if (!row || typeof row !== 'object') return 'movie';
  var simkl = row._simklType != null ? String(row._simklType) : '';
  if (simkl === 'anime') return 'anime';
  var mt = row.mediaType != null ? String(row.mediaType) : 'movie';
  if (mt === 'anime') return 'anime';
  if (mt === 'asian_drama' || mt === 'drama') return 'asian_drama';
  if (row.kisskhId != null) return 'asian_drama';
  var open = row.metaOpen || row.open || row.catalogOpen;
  if (open && typeof open === 'object') {
    if (String(open.surface || '') === 'drama') return 'asian_drama';
    var extract = open.extract;
    if (extract && typeof extract === 'object') {
      var panel = String(
        extract.panelCategory || extract.resolveType || '',
      );
      if (panel === 'drama') return 'asian_drama';
      var ctx = extract.ctx;
      if (ctx && typeof ctx === 'object' && ctx.kisskhId != null) {
        return 'asian_drama';
      }
    }
  }
  if (simkl === 'movies') return 'movie';
  if (simkl === 'shows') return 'tv';
  if (mt === 'tv' || mt === 'series') return 'tv';
  return 'movie';
}

function myListShapeRow(row) {
  if (!row || typeof row !== 'object') return null;
  var out = Object.assign({}, row);
  if (!out.name && out.title) out.name = out.title;
  var kind = myListKindFromRow(out);
  out.kind = kind;
  if (!out.type) out.type = kind;
  if (!out.listStatus && out.status) out.listStatus = String(out.status);
  // Prefer pack-emitted open; accept catalogOpen from host upsertCatalog.
  var storedOpen = out.open || out.metaOpen || out.catalogOpen;
  if (storedOpen && typeof storedOpen === 'object') {
    out.open = storedOpen;
    out.metaOpen = storedOpen;
  }
  return out;
}

function myListLoadFeed(ctx, params) {
  var host = ctx && ctx.host;
  var myList = host && host.myList;
  // Missing bridge → reject (empty ok envelope would skip host flutter_js fallback).
  if (!myList || typeof myList.load !== 'function') {
    return Promise.reject(new Error('HOST_MY_LIST_REQUIRED'));
  }
  var status =
    (params && (params.status || params.listStatus)) || 'plantowatch';
  var hiddenKeys = (params && params.hiddenKeys) || [];
  return Promise.resolve(
    myList.load({
      status: String(status),
      hiddenKeys: Array.isArray(hiddenKeys) ? hiddenKeys : [],
    }),
  ).then(function (rows) {
    if (!Array.isArray(rows)) return [];
    var out = [];
    for (var i = 0; i < rows.length; i++) {
      var shaped = myListShapeRow(rows[i]);
      if (shaped) out.push(shaped);
    }
    return out;
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var params = hubParams(ctx);
  if (action === 'layout') {
    return hubOk('layout', myListLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'feed' || action === 'rail') {
    return myListLoadFeed(ctx, params).then(function (items) {
      return hubItems(action, items, { maxAge: 30, swr: 120 });
    });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'my-list hub: layout + feed/rail only',
  );
}
