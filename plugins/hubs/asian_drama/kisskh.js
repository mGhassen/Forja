// KissKH Asian drama hub — layout / rail / search / details (protocol 1).
// Row order matches the pre-CatalogShell Asian Drama hub.
// Ranked Popular is host-owned TMDB Asian TV (`host.popular_asian`).

var KISSKH_DEFAULTS = {
  base: 'https://kisskh.co',
  mirrors: ['https://kisskh.co'],
};

// Paths match crates/kisskh home_hero + home_rails.
var KISSKH_RAILS = {
  spotlight: '/DramaList/Show',
  latest: '/DramaList/LastUpdate?ispc=false',
  trending: '/DramaList/MostSearch?ispc=false',
  most_viewed: '/DramaList/MostView',
  upcoming: '/DramaList/Upcoming?ispc=false',
  anime: '/DramaList/Animate?ispc=false',
};

function kisskhLayout() {
  return {
    pages: {
      asian_drama: {
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'Spotlight',
            rail: 'spotlight',
            bleed: 'latest',
          },
          { type: 'host.continue', id: 'continue_watching' },
          {
            type: 'rail',
            id: 'latest',
            title: 'Latest Update',
            rail: 'latest',
            hideWhenBleed: true,
            aspect: 'landscape',
          },
          {
            type: 'rail',
            id: 'trending',
            title: 'Trending',
            rail: 'trending',
            aspect: 'landscape',
          },
          { type: 'host.popular_asian', id: 'popular' },
          {
            type: 'rail',
            id: 'most_viewed',
            title: 'Most Viewed',
            rail: 'most_viewed',
            aspect: 'landscape',
          },
          {
            type: 'rail',
            id: 'anime',
            title: 'Anime',
            rail: 'anime',
            aspect: 'landscape',
            hideWhenTypeFilter: true,
          },
          {
            type: 'rail',
            id: 'upcoming',
            title: 'Upcoming',
            rail: 'upcoming',
            aspect: 'landscape',
          },
        ],
      },
    },
  };
}

function kisskhCover(raw) {
  var url = String(raw || '').trim();
  if (!url) return '';
  return url.replace('media.themoviedb.org/t/p', 'image.tmdb.org/t/p');
}

function kisskhMeta(row) {
  if (!row || !row.id) return null;
  var name = String(row.title || '').trim();
  if (!name) return null;
  var ids = { kisskh: String(row.id) };
  var tmdb = row.tmdbID || row.tmdbId || row.tmdb_id;
  if (tmdb) ids.tmdb = String(tmdb);
  var release = String(row.releaseDate || '').trim();
  var meta = {
    id: 'kisskh:' + row.id,
    type: 'drama',
    name: name,
    poster: kisskhCover(row.thumbnail || row.cover),
    releaseInfo: release ? release.substring(0, 4) : '',
    ids: ids,
    open: { surface: 'drama', id: String(row.id) },
  };
  var label = String(row.label || '').trim();
  if (label) meta.badge = label;
  var desc = String(row.description || '').trim();
  if (desc) meta.description = hubStripHtml(desc);
  // Prefer movie search for Film / Hollywood; dramas default to TV.
  var kt = String(row.type || '').toLowerCase();
  if (kt === 'movie' || kt === 'hollywood') meta.tmdbMediaType = 'movie';
  else if (kt) meta.tmdbMediaType = 'tv';
  return meta;
}

function kisskhGet(ctx, cfg, path) {
  var bases = [cfg.base].concat(
    Array.isArray(cfg.mirrors) ? cfg.mirrors : [],
  );
  var seen = {};
  var ordered = [];
  for (var i = 0; i < bases.length; i++) {
    var b = String(bases[i] || '').replace(/\/$/, '');
    if (!b || seen[b]) continue;
    seen[b] = true;
    ordered.push(b);
  }

  function attempt(index) {
    if (index >= ordered.length) {
      return Promise.reject(new Error('all kisskh mirrors failed'));
    }
    var base = ordered[index];
    return ctx
      .fetch(base + '/api' + path, {
        headers: {
          Accept: 'application/json',
          Referer: base + '/',
          Origin: base,
        },
      })
      .then(function (res) {
        if (!res.ok) throw new Error('kisskh HTTP ' + res.status);
        return res.json();
      })
      .catch(function () {
        return attempt(index + 1);
      });
  }

  return attempt(0);
}

function kisskhList(ctx, cfg, path, limit) {
  return kisskhGet(ctx, cfg, path).then(function (raw) {
    var list = Array.isArray(raw) ? raw : raw && raw.data;
    var out = [];
    var rows = hubClampList(list, limit);
    for (var i = 0; i < rows.length; i++) {
      var meta = kisskhMeta(rows[i]);
      if (meta) out.push(meta);
    }
    return out;
  });
}

function kisskhExplorePath(params) {
  var type = hubFilterValue(params.filter, 'type') || '0';
  var country = hubFilterValue(params.filter, 'country') || '0';
  var page = Number(params.page) > 0 ? Number(params.page) : 1;
  var pageSize = Number(params.limit) > 0 ? Number(params.limit) : 24;
  return (
    '/DramaList/List?page=' +
    page +
    '&type=' +
    encodeURIComponent(type) +
    '&sub=0&country=' +
    encodeURIComponent(country) +
    '&status=0&order=1&pageSize=' +
    pageSize
  );
}

function kisskhChromeFiltered(params) {
  var type = hubFilterValue(params.filter, 'type');
  var country = hubFilterValue(params.filter, 'country');
  return !!(type || country);
}

function kisskhDetails(ctx, cfg, params) {
  var id = Number(String(params.id || '').split(':').pop());
  if (!id) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'details needs params.id'),
    );
  }
  return kisskhGet(ctx, cfg, '/DramaList/Drama/' + id + '?isq=false').then(
    function (raw) {
      var meta = kisskhMeta(raw);
      if (!meta) {
        return hubFail('details', 'NOT_FOUND', 'drama ' + id + ' not found');
      }
      return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
    },
  );
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, KISSKH_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', kisskhLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'details') {
    return kisskhDetails(ctx, cfg, params).catch(function (e) {
      return hubFail('details', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'search') {
    var q = String(params.query || '').trim();
    if (!q) return hubItems('search', []);
    return kisskhList(
      ctx,
      cfg,
      '/DramaList/Search?q=' + encodeURIComponent(q) + '&type=0',
      params.limit,
    )
      .then(function (items) {
        return hubItems('search', items, { maxAge: 300 });
      })
      .catch(function (e) {
        return hubFail('search', 'UPSTREAM', e && e.message, true);
      });
  }
  if (action !== 'rail') {
    return hubFail(action, 'INVALID_ACTION', 'kisskh has no action ' + action);
  }

  if (kisskhChromeFiltered(params)) {
    var railId = String(params.rail || '');
    if (railId === 'anime') return hubItems('rail', []);
    return kisskhList(ctx, cfg, kisskhExplorePath(params), params.limit)
      .then(function (items) {
        return hubItems('rail', items, { maxAge: 600, swr: 3600 });
      })
      .catch(function (e) {
        return hubFail('rail', 'UPSTREAM', e && e.message, true);
      });
  }

  var path = KISSKH_RAILS[String(params.rail || '')];
  if (!path) {
    return hubFail('rail', 'INVALID_PARAMS', 'unknown rail ' + params.rail);
  }
  return kisskhList(ctx, cfg, path, params.limit)
    .then(function (items) {
      return hubItems('rail', items, { maxAge: 600, swr: 3600 });
    })
    .catch(function (e) {
      return hubFail('rail', 'UPSTREAM', e && e.message, true);
    });
}
