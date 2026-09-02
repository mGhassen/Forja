// KissKH Asian drama hub — layout / rail / search / details (protocol 1).
// Row order matches the pre-CatalogShell Asian Drama hub.
// Ranked Popular comes from the KissKH `most_viewed` rail (pack JS).

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
        feed: true,
        feedRails: [
          'spotlight',
          'latest',
          'trending',
          'most_viewed',
          'upcoming',
        ],
        pageSize: 24,
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'Spotlight',
            rail: 'spotlight',
            bleed: 'latest',
          },
          { type: 'continue', id: 'continue_watching' },
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
          {
            type: 'ranked',
            id: 'popular',
            title: 'Popular',
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

function kisskhInferMediaType(row) {
  var kt = String(row.type || '').trim().toLowerCase();
  if (kt === 'movie' || kt === 'hollywood') return 'movie';
  if (kt === 'tvseries' || kt === 'anime' || kt === 'tv') return 'tv';
  var label = String(row.label || '').trim().toUpperCase();
  if (label === 'MOVIE' || label === 'FILM' || label === 'HOLLYWOOD') {
    return 'movie';
  }
  if (
    label === 'TV' ||
    label === 'SERIES' ||
    label === 'TVSERIES' ||
    label === 'ANIME'
  ) {
    return 'tv';
  }
  return '';
}

function kisskhMeta(row) {
  if (!row || !row.id) return null;
  var name = String(row.title || '').trim();
  if (!name) return null;
  var ids = { kisskh: String(row.id) };
  var tmdb = row.tmdbID || row.tmdbId || row.tmdb_id;
  if (tmdb) ids.tmdb = String(tmdb);
  var release = String(row.releaseDate || '').trim();
  var premiere = hubParseIsoDate(release);
  var meta = {
    id: 'kisskh:' + row.id,
    type: 'drama',
    name: name,
    poster: kisskhCover(row.thumbnail || row.cover),
    releaseInfo: release ? release.substring(0, 4) : '',
    ids: ids,
    open: {
      surface: 'drama',
      id: String(row.id),
      // Host: open.torrentEp → search Title 05 (not SxxExx).
      torrentEp: true,
      extract: {
        resolveType: 'drama',
        panelCategory: 'drama',
        ctx: { kisskhId: Number(row.id) },
      },
    },
  };
  if (premiere) meta.premiereDate = premiere;
  var label = String(row.label || '').trim();
  if (label) meta.badge = label;
  var desc = String(row.description || '').trim();
  if (desc) meta.description = hubStripHtml(desc);
  var mediaType = kisskhInferMediaType(row);
  if (mediaType) meta.tmdbMediaType = mediaType;
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
      var eps = Array.isArray(raw.episodes) ? raw.episodes : [];
      var videos = [];
      for (var i = 0; i < eps.length; i++) {
        var ep = eps[i];
        if (!ep || ep.id == null || ep.number == null) continue;
        var num = Math.round(Number(ep.number));
        if (!num) continue;
        var airRaw = hubParseIsoDate(
          ep.airDate || ep.airdate || ep.releaseDate || ep.released,
        );
        var entry = {
          id: String(ep.id),
          episode: num,
          season: 1,
          title: 'Episode ' + num,
        };
        if (airRaw) {
          entry.airDate = airRaw;
          if (hubIsFutureIsoDate(airRaw)) entry.aired = false;
        }
        videos.push(entry);
      }
      videos.sort(function (a, b) {
        return a.episode - b.episode;
      });
      if (videos.length) meta.videos = videos;
      else if (
        meta.premiereDate &&
        hubIsFutureIsoDate(meta.premiereDate)
      ) {
        meta.status = 'NOT_YET_RELEASED';
      }
      var bg = String(raw.thumbnail || raw.cover || '').trim();
      if (bg) meta.background = kisskhCover(bg);
      var desc = String(raw.description || '').trim();
      if (desc) meta.description = hubStripHtml(desc);
      return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
    },
  );
}

function kisskhCountryFilter(value) {
  return { op: 'eq', field: 'country', value: String(value) };
}

function kisskhCategoryOptions() {
  return [
    {
      id: 'chinese',
      label: 'Chinese',
      value: '1',
      filter: kisskhCountryFilter('1'),
    },
    {
      id: 'korea',
      label: 'South Korea',
      value: '2',
      filter: kisskhCountryFilter('2'),
    },
    {
      id: 'japan',
      label: 'Japan',
      value: '3',
      filter: kisskhCountryFilter('3'),
    },
    {
      id: 'hongkong',
      label: 'Hong Kong',
      value: '4',
      filter: kisskhCountryFilter('4'),
    },
    {
      id: 'thailand',
      label: 'Thailand',
      value: '5',
      filter: kisskhCountryFilter('5'),
    },
    {
      id: 'taiwan',
      label: 'Taiwan',
      value: '7',
      filter: kisskhCountryFilter('7'),
    },
    {
      id: 'philippines',
      label: 'Philippines',
      value: '8',
      filter: kisskhCountryFilter('8'),
    },
    {
      id: 'indonesia',
      label: 'Indonesia',
      value: '9',
      filter: kisskhCountryFilter('9'),
    },
  ];
}

function kisskhFilters() {
  return {
    fields: [
      {
        field: 'country',
        label: 'Country',
        options: kisskhCategoryOptions(),
      },
    ],
    media: {
      films: { op: 'eq', field: 'type', value: '2' },
      series: { op: 'eq', field: 'type', value: '1' },
    },
  };
}

var KISSKH_FEED_SLICES = [
  { rail: 'spotlight', limit: 5 },
  { rail: 'latest', limit: 24 },
  { rail: 'trending', limit: 24 },
  { rail: 'most_viewed', limit: 24 },
  { rail: 'upcoming', limit: 24 },
];

function kisskhFeedLimit(railId, params) {
  for (var i = 0; i < KISSKH_FEED_SLICES.length; i++) {
    if (KISSKH_FEED_SLICES[i].rail === railId) {
      return KISSKH_FEED_SLICES[i].limit;
    }
  }
  var n = Number(params.limit);
  return n > 0 ? n : 24;
}

function kisskhFilteredFeed(ctx, cfg, params) {
  var total = 0;
  for (var i = 0; i < KISSKH_FEED_SLICES.length; i++) {
    total += KISSKH_FEED_SLICES[i].limit;
  }
  var fetchParams = Object.assign({}, params, { limit: total, page: 1 });
  return kisskhList(ctx, cfg, kisskhExplorePath(fetchParams), total).then(
    function (all) {
      var rails = {};
      var offset = 0;
      for (var j = 0; j < KISSKH_FEED_SLICES.length; j++) {
        var spec = KISSKH_FEED_SLICES[j];
        rails[spec.rail] = all.slice(offset, offset + spec.limit);
        offset += spec.limit;
      }
      return hubOk('feed', { rails: rails }, { maxAge: 600, swr: 3600 });
    },
  );
}

function kisskhUnfilteredFeed(ctx, cfg, params) {
  var jobs = [];
  for (var i = 0; i < KISSKH_FEED_SLICES.length; i++) {
    (function (spec) {
      var path = KISSKH_RAILS[spec.rail];
      if (!path) return;
      jobs.push(
        kisskhList(ctx, cfg, path, kisskhFeedLimit(spec.rail, params)).then(
          function (items) {
            return { rail: spec.rail, items: items };
          },
        ),
      );
    })(KISSKH_FEED_SLICES[i]);
  }
  return Promise.all(jobs).then(function (rows) {
    var rails = {};
    for (var k = 0; k < rows.length; k++) {
      rails[rows[k].rail] = rows[k].items;
    }
    return hubOk('feed', { rails: rails }, { maxAge: 600, swr: 3600 });
  });
}

function kisskhFeed(ctx, cfg, params) {
  if (kisskhChromeFiltered(params)) {
    return kisskhFilteredFeed(ctx, cfg, params);
  }
  return kisskhUnfilteredFeed(ctx, cfg, params);
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, KISSKH_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', kisskhLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'filters') {
    return hubOk('filters', kisskhFilters(), { maxAge: 86400 });
  }
  if (action === 'feed') {
    return kisskhFeed(ctx, cfg, params).catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
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
        var pageSize = Number(params.limit) > 0 ? Number(params.limit) : 24;
        return hubItems('rail', items, { maxAge: 600, swr: 3600 }, { pageSize: pageSize });
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
      var pageSize = Number(params.limit) > 0 ? Number(params.limit) : 24;
      return hubItems('rail', items, { maxAge: 600, swr: 3600 }, { pageSize: pageSize });
    })
    .catch(function (e) {
      return hubFail('rail', 'UPSTREAM', e && e.message, true);
    });
}
