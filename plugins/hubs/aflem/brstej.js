// Brstej hub — browse / search / details (protocol 1).
// Aflem hub — scrape Brstej (uo.brstej.com). Playback: provider `brstej`.
// Host surface: arabic.

var BRSTEJ_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

var BRSTEJ_DEFAULTS = {
  origin: 'https://uo.brstej.com',
};

var BRSTEJ_FEED_RAILS = ['spotlight', 'latest', 'series'];

function brstejCatFilter(value) {
  return { op: 'eq', field: 'cat', value: String(value) };
}

/** Curated region / type categories (not per-show dump pages). */
var BRSTEJ_CATEGORY_OPTIONS = [
  {
    id: 'arabic',
    label: 'مسلسلات عربية',
    path: '/category.php?cat=arab8-2025',
    kind: 'series',
    filter: brstejCatFilter('arab8-2025'),
  },
  {
    id: 'egyptian',
    label: 'مسلسلات مصرية',
    path: '/category.php?cat=eg8-2025',
    kind: 'series',
    filter: brstejCatFilter('eg8-2025'),
  },
  {
    id: 'shami',
    label: 'مسلسلات شامية',
    path: '/category.php?cat=syy5-2025',
    kind: 'series',
    filter: brstejCatFilter('syy5-2025'),
  },
  {
    id: 'gulf',
    label: 'مسلسلات خليجية',
    path: '/category.php?cat=5a7-2024',
    kind: 'series',
    filter: brstejCatFilter('5a7-2024'),
  },
  {
    id: 'turkish',
    label: 'مسلسلات تركية',
    path: '/category.php?cat=ty9-2025',
    kind: 'series',
    filter: brstejCatFilter('ty9-2025'),
  },
  {
    id: 'prestige',
    label: 'مسلسلات برستيج',
    path: '/cat03.php?cat=prss7-2025',
    kind: 'series',
    filter: brstejCatFilter('prss7-2025'),
  },
  {
    id: 'indian',
    label: 'مسلسلات هندية',
    path: '/category.php?cat=2ind2-2025',
    kind: 'series',
    filter: brstejCatFilter('2ind2-2025'),
  },
  {
    id: 'asian',
    label: 'مسلسلات آسيوية',
    path: '/category.php?cat=asia',
    kind: 'series',
    filter: brstejCatFilter('asia'),
  },
  {
    id: 'foreign',
    label: 'مسلسلات أجنبية',
    path: '/category.php?cat=english1-2025',
    kind: 'series',
    filter: brstejCatFilter('english1-2025'),
  },
  {
    id: 'anime',
    label: 'مسلسلات أنمي',
    path: '/category.php?cat=anmei',
    kind: 'series',
    filter: brstejCatFilter('anmei'),
  },
  {
    id: 'ramadan',
    label: 'رمضان 2026',
    path: '/category.php?cat=ramdan2026',
    kind: 'series',
    filter: brstejCatFilter('ramdan2026'),
  },
  {
    id: 'movies_ar',
    label: 'أفلام عربية',
    path: '/category.php?cat=aflam02-2024',
    kind: 'movie',
    filter: brstejCatFilter('aflam02-2024'),
  },
  {
    id: 'movies_foreign',
    label: 'أفلام أجنبية',
    path: '/category.php?cat=aflamajnby3-2024',
    kind: 'movie',
    filter: brstejCatFilter('aflamajnby3-2024'),
  },
  {
    id: 'movies_tr',
    label: 'أفلام تركية',
    path: '/category.php?cat=turkish3-movies2024',
    kind: 'movie',
    filter: brstejCatFilter('turkish3-movies2024'),
  },
  {
    id: 'movies_in',
    label: 'أفلام هندية',
    path: '/category.php?cat=hindi1-moviess',
    kind: 'movie',
    filter: brstejCatFilter('hindi1-moviess'),
  },
  {
    id: 'movies_anime',
    label: 'أفلام أنمي',
    path: '/category.php?cat=anime1',
    kind: 'movie',
    filter: brstejCatFilter('anime1'),
  },
  {
    id: 'tv',
    label: 'برامج تلفزيونية',
    path: '/category.php?cat=tv4-2024',
    kind: 'series',
    filter: brstejCatFilter('tv4-2024'),
  },
];

function brstejFilters() {
  return {
    menus: [
      {
        id: 'films',
        label: 'Films',
        filter: { op: 'eq', field: 'kind', value: 'movie' },
        hideTypeFilterRails: true,
      },
      {
        id: 'series',
        label: 'Series',
        filter: { op: 'eq', field: 'kind', value: 'series' },
        hideTypeFilterRails: true,
      },
    ],
    fields: [
      {
        field: 'cat',
        label: 'Category',
        options: BRSTEJ_CATEGORY_OPTIONS.map(function (o) {
          return { id: o.id, label: o.label, filter: o.filter };
        }),
      },
    ],
  };
}

function brstejOptionForCat(cat) {
  for (var i = 0; i < BRSTEJ_CATEGORY_OPTIONS.length; i++) {
    if (BRSTEJ_CATEGORY_OPTIONS[i].filter.value === String(cat)) {
      return BRSTEJ_CATEGORY_OPTIONS[i];
    }
  }
  return null;
}

function brstejChromeFiltered(params) {
  return !!(
    hubFilterValue(params.filter, 'cat') ||
    hubFilterValue(params.filter, 'kind')
  );
}

function brstejBase(cfg) {
  return String(cfg.origin || cfg.brstej || BRSTEJ_DEFAULTS.origin).replace(
    /\/$/,
    '',
  );
}

function brstejHeaders(referer) {
  var h = {
    'User-Agent': BRSTEJ_UA,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  if (referer) h.Referer = referer;
  return h;
}

function brstejAbs(base, url) {
  url = String(url || '').trim();
  if (!url || url.indexOf('data:') === 0) return '';
  if (/^https?:\/\//i.test(url)) return url;
  if (url.indexOf('//') === 0) return 'https:' + url;
  base = String(base || '').replace(/\/$/, '');
  if (url.charAt(0) === '/') return base + url;
  return base + '/' + url;
}

function brstejOrigin(url) {
  try {
    var u = new URL(String(url || ''));
    return u.protocol + '//' + u.host;
  } catch (e) {
    return '';
  }
}

function brstejHtml(ctx, raw) {
  if (!ctx || typeof ctx.html !== 'function') return null;
  try {
    return ctx.html(raw);
  } catch (e) {
    return null;
  }
}

function brstejFetchHtml(ctx, url, referer) {
  return ctx
    .fetch(url, { headers: brstejHeaders(referer || brstejOrigin(url) + '/') })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status + ' for ' + url);
      return res.text().then(function (html) {
        return { html: html, url: res.url || url };
      });
    });
}

function brstejImg($, el, base) {
  if (!el || !el.length) return '';
  var poster = el.attr('data-echo') || el.attr('data-src') || '';
  if (!poster || poster.indexOf('data:') === 0) poster = el.attr('src') || '';
  if (poster.indexOf('data:') === 0) poster = '';
  return brstejAbs(base, poster);
}

function brstejMeta(id, title, poster, opts) {
  opts = opts || {};
  title = String(title || '').trim();
  if (!title || !id) return null;
  var open = {
    surface: 'arabic',
    id: String(id),
    source: 'brstej',
    extract: {
      resolveType: 'arabic',
      panelCategory: 'arabic',
      ctx: {
        videoId: String(id),
        source: 'brstej',
      },
    },
  };
  if (opts.url) open.url = String(opts.url);
  var meta = {
    id: 'brstej:' + id,
    type: 'arabic',
    name: title,
    poster: String(poster || ''),
    ids: { brstej: String(id) },
    open: open,
  };
  if (opts.url) meta.ids.url = String(opts.url);
  if (opts.description) meta.description = String(opts.description);
  return meta;
}

function brstejLayout() {
  return {
    pages: {
      aflem: {
        feed: true,
        feedRails: BRSTEJ_FEED_RAILS.slice(),
        pageSize: 24,
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'أحدث المسلسلات',
            rail: 'spotlight',
            bleed: 'latest',
          },
          {
            type: 'rail',
            id: 'latest',
            title: 'أخر الاضافات',
            rail: 'latest',
            hideWhenBleed: true,
          },
          { type: 'continue', id: 'continue_watching' },
          {
            type: 'ranked',
            id: 'series',
            title: 'مسلسلات',
            rail: 'series',
            style: 'numbered',
          },
        ],
      },
    },
  };
}

function brstejStripPrefix(title) {
  return String(title || '')
    .replace(/^مسلسل\s+/, '')
    .trim();
}

function brstejStripEpisode(title) {
  var t = String(title || '').replace(/\s*الحلقة\s+.*$/, '');
  t = t.replace(/\s*(HD|مترجم(ة)?|مدبلج(ة)?)\s*$/, '');
  return t.trim();
}

function brstejNormTitle(title) {
  return brstejStripPrefix(brstejStripEpisode(title))
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function brstejParseSerieCards(ctx, html, base) {
  var $ = brstejHtml(ctx, html);
  var out = [];
  var seen = {};
  if (!$) return out;
  $('li[class*="col-xs-6"]').each(function () {
    var card = $(this);
    var a = card.find('a[href*="view-serie.php"]').first();
    if (!a.length) a = card.find('a[href]').first();
    if (!a.length) return;
    var href = a.attr('href') || '';
    var m = /view-serie\.php\?id=(\d+)/.exec(href);
    if (!m) return;
    var id = m[1];
    if (seen[id]) return;
    seen[id] = true;
    var title = brstejStripPrefix((a.attr('title') || a.text() || '').trim());
    if (!title) return;
    var meta = brstejMeta(
      'serie:' + id,
      title,
      brstejImg($, card.find('img').first(), base),
      { url: brstejAbs(base, href) },
    );
    if (meta) out.push(meta);
  });
  return out;
}

function brstejParseEpisodeCards(ctx, html, base) {
  var $ = brstejHtml(ctx, html);
  var out = [];
  if (!$) return out;
  $('li[class*="col-xs-6"]').each(function () {
    var card = $(this);
    var a = card.find('a[href*="watch.php"][title]').first();
    if (!a.length) a = card.find('a[href*="watch.php"]').first();
    if (!a.length) return;
    var href = a.attr('href') || '';
    var m = /watch\.php\?vid=([^&"\s]+)/.exec(href);
    if (!m) return;
    var title = (a.attr('title') || a.text() || '').trim();
    if (!title) return;
    var meta = brstejMeta(
      'watch:' + m[1],
      title,
      brstejImg($, card.find('img').first(), base),
      { url: brstejAbs(base, href) },
    );
    if (meta) out.push(meta);
  });
  return out;
}

function brstejBrowseSeries(ctx, cfg, limit) {
  var base = brstejBase(cfg);
  return brstejFetchHtml(ctx, base + '/moslsalat.php?page=1', base + '/').then(
    function (got) {
      var origin = brstejOrigin(got.url) || base;
      return hubClampList(brstejParseSerieCards(ctx, got.html, origin), limit);
    },
  );
}

function brstejIsMovieTitle(title) {
  title = String(title || '');
  if (title.indexOf('الحلقة') >= 0) return false;
  return /مشاهدة\s*فيلم/.test(title) || /(?:^|\s)فيلم\b/.test(title);
}

function brstejStripMoviePrefix(title) {
  return String(title || '')
    .replace(/^مشاهدة\s*فيلم\s+/i, '')
    .replace(/^فيلم\s+/i, '')
    .replace(/\s*(اون\s*لاين|كامل|HD).*$/i, '')
    .trim();
}

/** Category pages list watch.php cards — group episodes → series, keep movies. */
function brstejGroupCategoryCards(episodes, asMovies) {
  var byKey = {};
  var order = [];
  for (var i = 0; i < (episodes || []).length; i++) {
    var ep = episodes[i];
    if (!ep || !ep.name) continue;
    var movie = asMovies || brstejIsMovieTitle(ep.name);
    if (movie) {
      var mid = (ep.ids && ep.ids.brstej) || '';
      if (!mid || byKey[mid]) continue;
      order.push(mid);
      byKey[mid] = brstejMeta(
        mid.indexOf('watch:') === 0 ? mid : 'watch:' + mid,
        brstejStripMoviePrefix(ep.name),
        ep.poster,
        { url: ep.ids && ep.ids.url },
      );
      if (byKey[mid]) byKey[mid].badge = 'MOVIE';
      continue;
    }
    var key = brstejNormTitle(ep.name);
    if (!key) continue;
    if (!byKey[key]) {
      order.push(key);
      byKey[key] = brstejMeta(
        ep.ids.brstej,
        brstejStripPrefix(brstejStripEpisode(ep.name)),
        ep.poster,
        { url: ep.ids.url },
      );
    }
  }
  var out = [];
  for (var j = 0; j < order.length; j++) {
    if (byKey[order[j]]) out.push(byKey[order[j]]);
  }
  return out;
}

function brstejBrowsePath(ctx, cfg, path, opts) {
  opts = opts || {};
  var base = brstejBase(cfg);
  var url;
  if (/[?&]page=/.test(path)) {
    url = base + path;
  } else if (path.indexOf('?') >= 0) {
    url = base + path + '&page=1';
  } else {
    url = base + path + '?page=1';
  }
  return brstejFetchHtml(ctx, url, base + '/').then(function (got) {
    var origin = brstejOrigin(got.url) || base;
    var series = brstejParseSerieCards(ctx, got.html, origin);
    if (series.length) return hubClampList(series, opts.limit);
    var episodes = brstejParseEpisodeCards(ctx, got.html, origin);
    return hubClampList(
      brstejGroupCategoryCards(episodes, !!opts.asMovies),
      opts.limit,
    );
  });
}

function brstejExploreList(ctx, cfg, params) {
  var cat = hubFilterValue(params.filter, 'cat');
  var kind = hubFilterValue(params.filter, 'kind');
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  if (cat) {
    var opt = brstejOptionForCat(cat);
    var path = opt
      ? opt.path
      : '/category.php?cat=' + encodeURIComponent(cat);
    var asMovies =
      kind === 'movie' || (opt && opt.kind === 'movie' && kind !== 'series');
    return brstejBrowsePath(ctx, cfg, path, {
      limit: limit,
      asMovies: asMovies,
    });
  }
  if (kind === 'movie') {
    return brstejBrowsePath(ctx, cfg, '/category.php?cat=aflam02-2024', {
      limit: limit,
      asMovies: true,
    });
  }
  if (kind === 'series') {
    return brstejBrowseSeries(ctx, cfg, limit);
  }
  return Promise.resolve([]);
}

function brstejFilteredFeed(ctx, cfg, params) {
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  return brstejExploreList(
    ctx,
    cfg,
    Object.assign({}, params, { limit: Math.max(limit * 2, 48) }),
  ).then(function (items) {
    var list = items || [];
    return hubOk(
      'feed',
      {
        rails: {
          spotlight: list.slice(0, limit),
          latest: list.slice(0, limit),
          series: list.slice(0, Math.min(10, limit)),
        },
      },
      { maxAge: 600, swr: 3600 },
    );
  });
}

function brstejSearch(ctx, cfg, params) {
  var q = String(params.query || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 40;
  var base = brstejBase(cfg);
  var url =
    base + '/search.php?keywords=' + encodeURIComponent(q) + '&page=1';
  return brstejFetchHtml(ctx, url, base + '/').then(function (got) {
    var origin = brstejOrigin(got.url) || base;
    var episodes = brstejParseEpisodeCards(ctx, got.html, origin);
    var byKey = {};
    var order = [];
    for (var i = 0; i < episodes.length; i++) {
      var ep = episodes[i];
      var key = brstejNormTitle(ep.name);
      if (!key) continue;
      if (!byKey[key]) {
        order.push(key);
        byKey[key] = brstejMeta(
          ep.ids.brstej,
          brstejStripPrefix(brstejStripEpisode(ep.name)),
          ep.poster,
          { url: ep.ids.url },
        );
      }
    }
    var out = [];
    for (i = 0; i < order.length; i++) {
      if (byKey[order[i]]) out.push(byKey[order[i]]);
    }
    return hubItems('search', hubClampList(out, limit), { maxAge: 300 });
  });
}

function brstejRailItems(ctx, cfg, params) {
  var rail = String(params.rail || '');
  if (
    rail !== 'spotlight' &&
    rail !== 'latest' &&
    rail !== 'series'
  ) {
    return Promise.resolve(
      hubFail('rail', 'INVALID_PARAMS', 'unknown rail ' + rail),
    );
  }
  var load = brstejChromeFiltered(params)
    ? brstejExploreList(ctx, cfg, params)
    : brstejBrowseSeries(ctx, cfg, params.limit);
  return load
    .then(function (items) {
      return hubItems('rail', items, { maxAge: 600, swr: 3600 });
    })
    .catch(function (e) {
      return hubFail('rail', 'UPSTREAM', e && e.message, true);
    });
}

function brstejFeed(ctx, cfg, params) {
  if (brstejChromeFiltered(params)) {
    return brstejFilteredFeed(ctx, cfg, params).catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
  }
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  return brstejBrowseSeries(ctx, cfg, Math.max(limit, 24))
    .then(function (items) {
      var list = items || [];
      return hubOk(
        'feed',
        {
          rails: {
            spotlight: list.slice(0, limit),
            latest: list.slice(0, limit),
            series: list.slice(0, Math.min(10, limit)),
          },
        },
        { maxAge: 600, swr: 3600 },
      );
    })
    .catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
}

function brstejEpThumb($, a, base) {
  var img = a.find('img').first();
  if (!img.length) {
    var parent = a.parent();
    if (parent && parent.length) img = parent.find('img').first();
  }
  return brstejImg($, img, base);
}

function brstejMergeEpByVid(byId, order, vid, title, poster) {
  var existing = byId[vid];
  if (!existing) {
    order.push(vid);
    byId[vid] = { title: title, poster: poster };
  } else {
    if (!existing.title && title) existing.title = title;
    if (!existing.poster && poster) existing.poster = poster;
  }
}

function brstejEpisodeNumber(title) {
  var t = String(title || '');
  var m =
    /الحلقة\s+(\d+)/.exec(t) ||
    /<em>\s*(\d+)/.exec(t) ||
    /\b(\d{1,3})\b/.exec(t);
  return m ? Number(m[1]) : null;
}

function brstejParseEpisodeAnchors($, anchors, base) {
  var byId = {};
  var order = [];
  anchors.each(function () {
    var a = $(this);
    var href = a.attr('href') || '';
    var m = /watch\.php\?vid=([^&"\s]+)/.exec(href);
    if (!m) return;
    var vid = m[1];
    var t = (a.attr('title') || '').trim();
    if (!t) {
      var em = a.find('em').first();
      if (em.length) t = 'الحلقة ' + (em.text() || '').trim();
      else t = (a.text() || '').replace(/\s+/g, ' ').trim();
    }
    brstejMergeEpByVid(byId, order, vid, t, brstejEpThumb($, a, base));
  });
  var list = [];
  for (var i = 0; i < order.length; i++) {
    var vid = order[i];
    var e = byId[vid];
    list.push({
      id: 'brstej:watch:' + vid,
      title: e.title || '',
      season: 1,
      episode: i + 1,
      thumbnail: e.poster || '',
      _n: brstejEpisodeNumber(e.title),
    });
  }
  list.sort(function (a, b) {
    if (a._n == null && b._n == null) return 0;
    if (a._n == null) return 1;
    if (b._n == null) return -1;
    return a._n - b._n;
  });
  for (i = 0; i < list.length; i++) {
    list[i].episode = i + 1;
    delete list[i]._n;
  }
  return list;
}

function brstejParseSerieHtml(ctx, html, base) {
  var $ = brstejHtml(ctx, html);
  var out = { title: '', poster: '', description: '', videos: [] };
  if (!$) return out;

  var title = ($('h1').first().text() || $('h2').first().text() || '').trim();
  out.title = brstejStripPrefix(title);

  var posterImg = $('img[src*="uploads/thumbs"]').first();
  if (!posterImg.length) posterImg = $('img[data-echo*="uploads/thumbs"]').first();
  if (posterImg.length) out.poster = brstejImg($, posterImg, base);

  var descEl = $('.pm-video-description').first();
  if (!descEl.length) descEl = $('.description').first();
  if (!descEl.length) descEl = $('.story').first();
  out.description = (descEl.text() || '').trim();

  var seasonButtons = $('.SeasonsBoxUL button.tablinks');
  if (seasonButtons.length) {
    seasonButtons.each(function (si) {
      var seasonNum = si + 1;
      var seasonDiv = $('#Season' + seasonNum);
      if (!seasonDiv.length) return;
      var eps = brstejParseEpisodeAnchors(
        $,
        seasonDiv.find('a[href*="watch.php"]'),
        base,
      );
      for (var i = 0; i < eps.length; i++) {
        eps[i].season = seasonNum;
        out.videos.push(eps[i]);
      }
    });
  } else {
    var eps = brstejParseEpisodeAnchors(
      $,
      $('#pm-grid a[href*="watch.php"]'),
      base,
    );
    for (var j = 0; j < eps.length; j++) out.videos.push(eps[j]);
  }
  return out;
}

function brstejParseWatchHtml(ctx, html, base) {
  var $ = brstejHtml(ctx, html);
  var out = { title: '', poster: '', description: '', videos: [] };
  if (!$) return out;

  var nameMeta = $('meta[itemprop="name"]').first();
  var title = nameMeta.length
    ? (nameMeta.attr('content') || '').trim()
    : ($('h1').first().text() || '').trim();
  out.title = brstejStripPrefix(brstejStripEpisode(title));

  var thumbMeta = $('meta[itemprop="thumbnailUrl"]').first();
  out.poster = thumbMeta.length ? (thumbMeta.attr('content') || '').trim() : '';
  if (!out.poster) {
    var img = $('img[src*="uploads/thumbs"]').first();
    if (img.length) out.poster = brstejImg($, img, base);
  }

  var descMeta = $('meta[itemprop="description"]').first();
  out.description = descMeta.length
    ? (descMeta.attr('content') || '').trim()
    : '';

  var seasonLis = $('.SeasonsBoxUL li[data-serie]');
  if (seasonLis.length) {
    seasonLis.each(function (si) {
      var li = $(this);
      var n = li.attr('data-serie') || String(si + 1);
      var seasonNum = Number(n) || si + 1;
      var epDiv = $('.SeasonsEpisodes[data-serie="' + n + '"]');
      var eps = epDiv.length
        ? brstejParseEpisodeAnchors($, epDiv.find('a[href*="watch.php"]'), base)
        : [];
      for (var i = 0; i < eps.length; i++) {
        eps[i].season = seasonNum;
        out.videos.push(eps[i]);
      }
    });
  } else {
    var eps = brstejParseEpisodeAnchors(
      $,
      $('.SeasonsEpisodes a[href*="watch.php"]'),
      base,
    );
    for (var j = 0; j < eps.length; j++) out.videos.push(eps[j]);
  }
  return out;
}

function brstejParseShowRef(params) {
  var raw = String(params.id || '').trim();
  var source = String(params.source || '').trim();
  var rest = raw;
  var colon = raw.indexOf(':');
  if (colon > 0) {
    var head = raw.substring(0, colon);
    if (head === 'brstej') {
      source = 'brstej';
      rest = raw.substring(colon + 1);
    }
  }
  if (!source) source = 'brstej';
  return {
    raw: raw,
    fullId: 'brstej:' + rest,
    source: source,
    rest: rest,
    url: String(params.url || '').trim(),
  };
}

function brstejDetails(ctx, cfg, params) {
  var ref = brstejParseShowRef(params);
  if (!ref.rest && !ref.raw) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'details needs params.id'),
    );
  }
  var base = brstejBase(cfg);
  var showId = ref.rest;
  var url;
  var fromWatch = false;
  if (showId.indexOf('watch:') === 0) {
    url = base + '/watch.php?vid=' + encodeURIComponent(showId.substring(6));
    fromWatch = true;
  } else if (showId.indexOf('serie:') === 0) {
    url =
      base + '/view-serie.php?id=' + encodeURIComponent(showId.substring(6));
  } else {
    url = base + '/view-serie.php?id=' + encodeURIComponent(showId);
  }
  return brstejFetchHtml(ctx, url, base + '/')
    .then(function (got) {
      var origin = brstejOrigin(got.url) || base;
      var parsed = fromWatch
        ? brstejParseWatchHtml(ctx, got.html, origin)
        : brstejParseSerieHtml(ctx, got.html, origin);
      var name = parsed.title || showId;
      var meta = brstejMeta(showId, name, parsed.poster || '', {
        description: parsed.description,
        url: ref.url || url,
      });
      if (!meta) {
        return hubFail('details', 'NOT_FOUND', 'brstej id ' + ref.fullId);
      }
      meta.id = ref.fullId;
      meta.description = parsed.description || '';
      meta.videos = parsed.videos || [];
      return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
    })
    .catch(function (e) {
      return hubFail('details', 'UPSTREAM', e && e.message, true);
    });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, BRSTEJ_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', brstejLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'filters') {
    return hubOk('filters', brstejFilters(), { maxAge: 86400 });
  }
  if (action === 'feed') {
    return brstejFeed(ctx, cfg, params);
  }
  if (action === 'details') {
    return brstejDetails(ctx, cfg, params);
  }
  if (action === 'search') {
    return brstejSearch(ctx, cfg, params).catch(function (e) {
      return hubFail('search', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'rail') {
    return brstejRailItems(ctx, cfg, params);
  }
  return hubFail(action, 'INVALID_ACTION', 'aflem hub has no action ' + action);
}
