// Live Sports Cards hub — landscape cards + details skin.
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
      default: 'airing|1h',
      items: [
        { id: 'airing|1h', label: 'Airing' },
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
              // ↓ from Catalog / Portals restores last schedule row (not All).
              focusDown: 'schedule',
              actions: liveSportsCatalogActions(),
            }),
            kitCategoryBar('kind', {
              source: 'live_schedule',
              dynamic: true,
              default: 'all',
              items: [{ id: 'all', label: 'All' }],
              focusUp: 'chrome',
              focusDown: 'schedule',
            }),
            kitList('schedule', {
              source: 'live_schedule',
              style: 'cards',
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

function liveSportsShapeRow(row) {
  if (!row || typeof row !== 'object') return null;
  var out = Object.assign({}, row);
  if (!out.name && out.title) out.name = out.title;
  if (!out.type) out.type = 'live_match';
  if (!out.open && out.id) {
    out.open = { surface: 'live', id: String(out.id) };
  }
  if (!out.sportMatchGame || typeof out.sportMatchGame !== 'object') {
    var title = String(out.title || out.name || '');
    var home = String(out.homeTeam || '');
    var away = String(out.awayTeam || '');
    var category = String(out.category || out.sport || '');
    var dateMs = Number(out.dateMs) || 0;
    out.sportMatchGame = {
      id: String(out.id || ''),
      title: title,
      homeTeam: home,
      awayTeam: away,
      sport: category,
      category: category,
      dateMs: dateMs,
    };
  }
  return out;
}

function liveSportsLoadFeed(ctx, params) {
  var host = ctx && ctx.host;
  var liveFeed = host && host.liveFeed;
  // Missing bridge → reject (empty ok envelope would skip host flutter_js fallback).
  if (!liveFeed || typeof liveFeed.load !== 'function') {
    return Promise.reject(new Error('HOST_LIVE_FEED_REQUIRED'));
  }
  return Promise.resolve(
    liveFeed.load({
      catalogFilter: (params && params.catalogFilter) || 'all',
      sportFilter: (params && params.sportFilter) || 'all',
      scheduleStatus: (params && params.scheduleStatus) || 'airing',
      scheduleHorizon: (params && params.scheduleHorizon) || 'h1',
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
    return hubOk('layout', liveSportsCardsLayout(), {
      maxAge: 3600,
      swr: 86400,
    });
  }
  if (action === 'feed' || action === 'rail') {
    return liveSportsLoadFeed(ctx, params).then(function (items) {
      return hubItems(action, items, { maxAge: 60, swr: 300 });
    });
  }
  return hubFail(
    action,
    'INVALID_ACTION',
    'live-sports-cards hub: layout + feed/rail only',
  );
}
