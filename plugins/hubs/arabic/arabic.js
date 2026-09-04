// Arabic hub — Larozaa only (protocol 1).
// Brstej → plugins/hubs/brstej. كرتون / DimaToon → plugins/hubs/cartoon.
// Playback: provider `larozaa` (types: arabic). Host surface: arabic.

var ARABIC_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

var ARABIC_DEFAULTS = {
  bootstrap: 'https://laaroza.website',
  mirrors: [
    'https://laaroza.website',
    'https://laaroza.pics',
    'https://larozza.yachts',
    'https://larozaa.bond',
    'https://larozaa.home',
    'https://larozaa.homes',
    'https://larozaa.com',
  ],
};

var ARABIC_RAILS = {
  trending: { kind: 'larozaa_browse', path: '/newvideos.php', group: true },
  latest: { kind: 'larozaa_browse', path: '/newvideos.php', group: true },
  series: { kind: 'larozaa_cat', cat: 'arabic-series46', group: true },
  movies: { kind: 'larozaa_cat', cat: 'arabic-movies35', movie: true },
  turkish: { kind: 'larozaa_cat', cat: 'turkish-3isk-seriess47', group: true },
  ramadan: { kind: 'larozaa_cat', cat: 'ramadan-2026', group: true },
  tv_programs: { kind: 'larozaa_cat', cat: 'tv-programs12', group: true },
  foreign_movies: { kind: 'larozaa_cat', cat: 'all_movies_13', movie: true },
  foreign_series: { kind: 'larozaa_cat', cat: 'english-series10', group: true },
  indian: { kind: 'larozaa_cat', cat: 'indian-movies9', movie: true },
  indian_series: { kind: 'larozaa_cat', cat: '11indian-series', group: true },
  asian_movies: { kind: 'larozaa_cat', cat: '6-asian-movies', movie: true },
  asian_series: { kind: 'larozaa_cat', cat: '6-asya', group: true },
  dubbed: { kind: 'larozaa_cat', cat: '7-aflammdblgh', movie: true },
  anime_movies: { kind: 'larozaa_cat', cat: 'anime-movies-7', movie: true },
  anime_series: { kind: 'larozaa_cat', cat: '6-anime-series', group: true },
  turkish_movies: { kind: 'larozaa_cat', cat: '8-aflam3isk', movie: true },
  plays: { kind: 'larozaa_cat', cat: 'masrh-5', group: true },
};

// Batched on open (home scrape usually seeds all of these). Remaining
// layout rails lazy-load via `rail` when CatalogShell scrolls them in.
var ARABIC_FEED_RAILS = [
  'trending',
  'latest',
  'series',
  'movies',
  'turkish',
];

// Sticky last-good origin for this JS VM (mirror walk is expensive).
var _arabicLarozaSticky = '';
var _arabicLarozaResolved = null;
var _arabicLarozaResolvePromise = null;

var ARABIC_HOME_SECTION_RAILS = {
  'أخر الاضافات': 'latest',
  'افلام عربي': 'movies',
  'مسلسلات تركية': 'turkish',
  'مسلسلات عربية': 'series',
};

function arabicCatFilter(value) {
  return { op: 'eq', field: 'cat', value: String(value) };
}

/** Categories menu — Larozaa `category.php?cat=` ids (same as rails). */
function arabicCategoryOptions() {
  return [
    {
      id: 'series',
      label: 'مسلسلات عربية',
      filter: arabicCatFilter('arabic-series46'),
    },
    {
      id: 'movies',
      label: 'أفلام عربية',
      filter: arabicCatFilter('arabic-movies35'),
    },
    {
      id: 'turkish',
      label: 'مسلسلات تركية',
      filter: arabicCatFilter('turkish-3isk-seriess47'),
    },
    {
      id: 'turkish_movies',
      label: 'أفلام تركية',
      filter: arabicCatFilter('8-aflam3isk'),
    },
    {
      id: 'foreign_series',
      label: 'مسلسلات أجنبية',
      filter: arabicCatFilter('english-series10'),
    },
    {
      id: 'foreign_movies',
      label: 'أفلام أجنبية',
      filter: arabicCatFilter('all_movies_13'),
    },
    {
      id: 'indian_series',
      label: 'مسلسلات هندية',
      filter: arabicCatFilter('11indian-series'),
    },
    {
      id: 'indian',
      label: 'أفلام هندية',
      filter: arabicCatFilter('indian-movies9'),
    },
    {
      id: 'asian_series',
      label: 'مسلسلات آسيوية',
      filter: arabicCatFilter('6-asya'),
    },
    {
      id: 'asian_movies',
      label: 'أفلام آسيوية',
      filter: arabicCatFilter('6-asian-movies'),
    },
    {
      id: 'anime_series',
      label: 'أنمي · مسلسلات',
      filter: arabicCatFilter('6-anime-series'),
    },
    {
      id: 'anime_movies',
      label: 'أنمي · أفلام',
      filter: arabicCatFilter('anime-movies-7'),
    },
    {
      id: 'dubbed',
      label: 'أفلام مدبلجة',
      filter: arabicCatFilter('7-aflammdblgh'),
    },
    {
      id: 'ramadan',
      label: 'رمضان 2026',
      filter: arabicCatFilter('ramadan-2026'),
    },
    {
      id: 'tv_programs',
      label: 'برامج تلفزيونية',
      filter: arabicCatFilter('tv-programs12'),
    },
    {
      id: 'plays',
      label: 'مسرحيات',
      filter: arabicCatFilter('masrh-5'),
    },
  ];
}

function arabicFilters() {
  return {
    fields: [
      { field: 'cat', label: 'Category', options: arabicCategoryOptions() },
    ],
    media: {
      films: { op: 'eq', field: 'kind', value: 'movie' },
      series: { op: 'eq', field: 'kind', value: 'series' },
    },
  };
}

function arabicSpecForCat(cat) {
  var keys = Object.keys(ARABIC_RAILS);
  for (var i = 0; i < keys.length; i++) {
    var spec = ARABIC_RAILS[keys[i]];
    if (spec && spec.cat === cat) return spec;
  }
  return null;
}

function arabicChromeFiltered(params) {
  return !!(
    hubFilterValue(params.filter, 'cat') ||
    hubFilterValue(params.filter, 'kind')
  );
}

function arabicExploreList(ctx, cfg, params) {
  var cat = hubFilterValue(params.filter, 'cat');
  var kind = hubFilterValue(params.filter, 'kind');
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  if (cat) {
    var spec = arabicSpecForCat(cat);
    var isMovie = !!(spec && spec.movie);
    if (kind === 'series') isMovie = false;
    else if (kind === 'movie') isMovie = true;
    return arabicLarozaList(
      ctx,
      cfg,
      '/category.php?cat=' + encodeURIComponent(cat),
      isMovie,
      limit,
      !isMovie && !!(spec && spec.group),
    );
  }
  if (kind === 'movie') {
    return arabicLarozaList(
      ctx,
      cfg,
      '/category.php?cat=arabic-movies35',
      true,
      limit,
      false,
    );
  }
  if (kind === 'series') {
    return arabicLarozaList(
      ctx,
      cfg,
      '/category.php?cat=arabic-series46',
      false,
      limit,
      true,
    );
  }
  return Promise.resolve([]);
}

function arabicFilteredFeed(ctx, cfg, params) {
  var total = 0;
  for (var i = 0; i < ARABIC_FEED_RAILS.length; i++) {
    total += arabicFeedRailLimit(ARABIC_FEED_RAILS[i], params);
  }
  var fetchParams = Object.assign({}, params, { limit: total, page: 1 });
  return arabicExploreList(ctx, cfg, fetchParams).then(function (all) {
    var rails = {};
    var offset = 0;
    for (var j = 0; j < ARABIC_FEED_RAILS.length; j++) {
      var railId = ARABIC_FEED_RAILS[j];
      var n = arabicFeedRailLimit(railId, params);
      rails[railId] = all.slice(offset, offset + n);
      offset += n;
    }
    if ((!rails.trending || !rails.trending.length) && rails.latest) {
      rails.trending = rails.latest.slice();
    }
    return hubOk('feed', { rails: rails }, { maxAge: 600, swr: 3600 });
  });
}

function arabicHeaders(referer) {
  var h = {
    'User-Agent': ARABIC_UA,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  if (referer) h.Referer = referer;
  return h;
}

function arabicLayout() {
  return {
    pages: {
      arabic: {
        feed: true,
        feedRails: ARABIC_FEED_RAILS.slice(),
        pageSize: 24,
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'رائج · Spotlight',
            rail: 'trending',
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
            type: 'rail',
            id: 'series',
            title: 'مسلسلات عربية',
            rail: 'series',
          },
          { type: 'rail', id: 'movies', title: 'أفلام عربية', rail: 'movies' },
          {
            type: 'rail',
            id: 'turkish',
            title: 'مسلسلات تركية',
            rail: 'turkish',
          },
          {
            type: 'rail',
            id: 'foreign_series',
            title: 'مسلسلات أجنبية',
            rail: 'foreign_series',
          },
          {
            type: 'rail',
            id: 'foreign_movies',
            title: 'أفلام أجنبية',
            rail: 'foreign_movies',
          },
          {
            type: 'rail',
            id: 'indian_series',
            title: 'مسلسلات هندية',
            rail: 'indian_series',
          },
          {
            type: 'rail',
            id: 'indian',
            title: 'أفلام هندية',
            rail: 'indian',
          },
          {
            type: 'rail',
            id: 'asian_series',
            title: 'مسلسلات آسيوية',
            rail: 'asian_series',
          },
          {
            type: 'rail',
            id: 'asian_movies',
            title: 'أفلام آسيوية',
            rail: 'asian_movies',
          },
          {
            type: 'rail',
            id: 'anime_series',
            title: 'أنمي · مسلسلات',
            rail: 'anime_series',
          },
          {
            type: 'rail',
            id: 'anime_movies',
            title: 'أنمي · أفلام',
            rail: 'anime_movies',
          },
          {
            type: 'rail',
            id: 'dubbed',
            title: 'أفلام مدبلجة',
            rail: 'dubbed',
          },
          {
            type: 'rail',
            id: 'turkish_movies',
            title: 'أفلام تركية',
            rail: 'turkish_movies',
          },
          { type: 'rail', id: 'ramadan', title: 'رمضان 2026', rail: 'ramadan' },
          {
            type: 'rail',
            id: 'tv_programs',
            title: 'برامج تلفزيونية',
            rail: 'tv_programs',
          },
          { type: 'rail', id: 'plays', title: 'مسرحيات', rail: 'plays' },
        ],
      },
    },
  };
}

function arabicAbs(base, url) {
  url = String(url || '').trim();
  if (!url || url.indexOf('data:') === 0) return '';
  if (/^https?:\/\//i.test(url)) return url;
  if (url.indexOf('//') === 0) return 'https:' + url;
  base = String(base || '').replace(/\/$/, '');
  if (url.charAt(0) === '/') return base + url;
  return base + '/' + url;
}

/** Larozaa movie titles: "مشاهدة فيلم …" or "فيلم Mayday…" — not episodes. */
function arabicIsLarozaMovieTitle(title) {
  title = String(title || '');
  if (title.indexOf('الحلقة') >= 0) return false;
  return /مشاهدة\s*فيلم/.test(title) || /(?:^|\s)فيلم\b/.test(title);
}

function arabicLarozaSerieIdFromHtml(html) {
  html = String(html || '');
  var m =
    /view-serie1?\.php\?ser=([a-zA-Z0-9]+)/.exec(html) ||
    /[?&]ser=([a-zA-Z0-9]+)/.exec(html);
  return m ? m[1] : '';
}

function arabicOrigin(url) {
  try {
    var u = new URL(String(url || ''));
    return u.protocol + '//' + u.host;
  } catch (e) {
    return '';
  }
}

function arabicIsLarozaHost(host) {
  // Live hosts rotate spelling: larozaa.bond → laaroza.pics, larozza.yachts, …
  return /la+r+o+z+a/i.test(String(host || ''));
}

function arabicHtml(ctx, html) {
  if (!ctx || typeof ctx.html !== 'function') return null;
  try {
    return ctx.html(html);
  } catch (e) {
    return null;
  }
}

function arabicEnsureLaroza(ctx, cfg) {
  if (_arabicLarozaResolved && _arabicLarozaResolved.origin) {
    return Promise.resolve(_arabicLarozaResolved);
  }
  if (_arabicLarozaResolvePromise) return _arabicLarozaResolvePromise;

  var boots = [_arabicLarozaSticky, cfg.bootstrap]
    .concat(Array.isArray(cfg.mirrors) ? cfg.mirrors : [])
    .map(function (b) {
      return String(b || '').replace(/\/$/, '');
    })
    .filter(Boolean);
  var seen = {};
  var ordered = [];
  for (var i = 0; i < boots.length; i++) {
    if (seen[boots[i]]) continue;
    seen[boots[i]] = true;
    ordered.push(boots[i]);
  }

  function attempt(index) {
    if (index >= ordered.length) {
      var fallback = ordered[0] || 'https://laaroza.website';
      return Promise.resolve({ origin: fallback, splashHtml: '' });
    }
    var boot = ordered[index];
    // Hit `/` only — long mirror chains exceed engine maxRedirects (8).
    // Keep splash HTML so feed home scrape skips a second `/` fetch.
    return ctx
      .fetch(boot + '/', { headers: arabicHeaders(boot + '/') })
      .then(function (res) {
        var origin = arabicOrigin(res.url || boot);
        var host = '';
        try {
          host = new URL(origin).host;
        } catch (e) { }
        if (!(origin && arabicIsLarozaHost(host))) {
          return attempt(index + 1);
        }
        return res.text().then(function (html) {
          return { origin: origin, splashHtml: String(html || '') };
        });
      })
      .catch(function () {
        return attempt(index + 1);
      });
  }

  _arabicLarozaResolvePromise = attempt(0)
    .then(function (resolved) {
      _arabicLarozaResolved = resolved;
      _arabicLarozaSticky = resolved.origin;
      _arabicLarozaResolvePromise = null;
      return resolved;
    })
    .catch(function (e) {
      _arabicLarozaResolvePromise = null;
      throw e;
    });
  return _arabicLarozaResolvePromise;
}

function arabicResolveLaroza(ctx, cfg) {
  return arabicEnsureLaroza(ctx, cfg).then(function (r) {
    return r.origin;
  });
}

function arabicFetchHtml(ctx, url, referer) {
  return ctx
    .fetch(url, { headers: arabicHeaders(referer || arabicOrigin(url) + '/') })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status + ' for ' + url);
      return res.text().then(function (html) {
        return { html: html, url: res.url || url };
      });
    });
}

function arabicImg($, el, base) {
  if (!el || !el.length) return '';
  var poster = el.attr('data-echo') || el.attr('data-src') || '';
  if (!poster || poster.indexOf('data:') === 0) poster = el.attr('src') || '';
  if (poster.indexOf('data:') === 0) poster = '';
  return arabicAbs(base, poster);
}

function arabicMeta(source, id, title, poster, opts) {
  opts = opts || {};
  title = String(title || '').trim();
  if (!title || !id) return null;
  var ids = {};
  ids[source] = String(id);
  if (opts.url) ids.url = String(opts.url);
  var open = {
    surface: 'arabic',
    id: String(id),
    source: String(source),
    extract: {
      resolveType: 'arabic',
      panelCategory: 'arabic',
      ctx: {
        videoId: String(id),
        source: String(source),
      },
    },
  };
  if (opts.url) open.url = String(opts.url);
  if (opts.isMovie) open.movie = true;
  var meta = {
    id: source + ':' + id,
    type: 'arabic',
    name: title,
    poster: String(poster || ''),
    ids: ids,
    open: open,
  };
  if (opts.isMovie) meta.badge = 'MOVIE';
  if (opts.description) meta.description = String(opts.description);
  return meta;
}

function arabicParseLarozaCards(ctx, html, base, isMovie) {
  var $ = arabicHtml(ctx, html);
  var out = [];
  var seen = {};
  if (!$) return arabicParseLarozaCardsRegex(html, base, isMovie);
  $(
    'li.col-xs-6.col-sm-4.col-md-3, li[class*="col-xs-6"], ul[class*="pm-ul"] > li',
  ).each(function () {
    var card = $(this);
    var a = card
      .find(
        'a[href*="video.php"], a[href*="serie.php"], a[href*="ser="], a[href]',
      )
      .first();
    if (!a.length) return;
    var href = a.attr('href') || '';
    if (
      href.indexOf('video.php') < 0 &&
      href.indexOf('serie') < 0 &&
      href.indexOf('ser=') < 0
    ) {
      return;
    }
    var title = (a.attr('title') || a.text() || '').trim();
    if (!title) return;
    var poster = arabicImg($, card.find('img').first(), base);
    var ser = /(?:\?|&)ser=([^&]+)/.exec(href);
    var vid = /(?:\?|&)vid=([^&]+)/.exec(href);
    var id = '';
    var movie = !!isMovie || arabicIsLarozaMovieTitle(title);
    if (ser) id = ser[1];
    else if (vid) id = movie ? vid[1] : 'ep:' + vid[1];
    if (!id || seen[id]) return;
    seen[id] = true;
    var meta = arabicMeta('larozaa', id, title, poster, {
      isMovie: movie && String(id).indexOf('ep:') !== 0,
      url: arabicAbs(base, href),
    });
    if (meta) out.push(meta);
  });
  return out;
}

function arabicParseLarozaCardsRegex(html, base, isMovie) {
  var out = [];
  var seen = {};
  var re =
    /<li[^>]*>[\s\S]*?<a[^>]+href="([^"]*(?:video\.php|serie\.php|[?&]ser=)[^"]*)"[^>]*(?:title="([^"]*)")?[\s\S]*?<\/li>/gi;
  var m;
  while ((m = re.exec(html))) {
    var block = m[0] || '';
    var href = m[1] || '';
    var title = (m[2] || '').trim();
    if (!title) {
      var tm = /title="([^"]+)"/i.exec(block);
      if (tm) title = (tm[1] || '').trim();
    }
    var poster = '';
    var echo = /data-echo="(https?:\/\/[^"]+)"/i.exec(block);
    if (echo) poster = echo[1];
    if (!poster) {
      var src = /(?:data-src|src)="(https?:\/\/[^"]+)"/i.exec(block);
      if (src) poster = src[1];
    }
    poster = arabicAbs(base, poster);
    if (!title) continue;
    var ser = /(?:\?|&)ser=([^&]+)/.exec(href);
    var vid = /(?:\?|&)vid=([^&]+)/.exec(href);
    var id = '';
    var movie = !!isMovie || arabicIsLarozaMovieTitle(title);
    if (ser) id = ser[1];
    else if (vid) id = movie ? vid[1] : 'ep:' + vid[1];
    if (!id || seen[id]) continue;
    seen[id] = true;
    var meta = arabicMeta('larozaa', id, title, poster, {
      isMovie: movie && String(id).indexOf('ep:') !== 0,
      url: arabicAbs(base, href),
    });
    if (meta) out.push(meta);
  }
  return out;
}

function arabicGroupLarozaSearch(items) {
  var episodeRe = /\s*الحلقة\s+\S+.*$/;
  var trailerRe = /\s*(HD|مترجم(ة)?|مدبلج(ة)?|اون لاين)\s*$/;
  function epNum(t) {
    var m = /الحلقة\s+(\d+)/.exec(t);
    return m ? Number(m[1]) : 9999;
  }
  function clean(t) {
    return String(t || '')
      .replace(episodeRe, '')
      .replace(trailerRe, '')
      .trim();
  }
  function norm(t) {
    return clean(t).toLowerCase().replace(/\s+/g, ' ').trim();
  }
  var repByKey = {};
  var repEp = {};
  var i;
  for (i = 0; i < items.length; i++) {
    var s = items[i];
    var t = s.name || '';
    if (t.indexOf('الحلقة') < 0) continue;
    var key = norm(t);
    if (!key) continue;
    var n = epNum(t);
    var rawId = String((s.ids && s.ids.larozaa) || '').replace(/^ep:/, '');
    if (!repByKey[key] || n < (repEp[key] || 9999)) {
      repByKey[key] = arabicMeta('larozaa', 'ep:' + rawId, clean(t), s.poster, {
        url: s.ids && s.ids.url,
      });
      repEp[key] = n;
    }
  }
  var out = [];
  var seenShow = {};
  var seenMovie = {};
  for (i = 0; i < items.length; i++) {
    s = items[i];
    t = s.name || '';
    if (t.indexOf('الحلقة') >= 0) {
      key = norm(t);
      if (!key || seenShow[key]) continue;
      seenShow[key] = true;
      if (repByKey[key]) out.push(repByKey[key]);
    } else {
      var mid = String((s.ids && s.ids.larozaa) || s.id);
      if (seenMovie[mid]) continue;
      seenMovie[mid] = true;
      out.push(s);
    }
  }
  return out;
}

function arabicLarozaList(ctx, cfg, path, isMovie, limit, group, baseOpt) {
  var baseP = baseOpt
    ? Promise.resolve(String(baseOpt).replace(/\/$/, ''))
    : arabicResolveLaroza(ctx, cfg);
  return baseP.then(function (base) {
    var url = base + path;
    if (path.indexOf('?') >= 0) url += '&page=1';
    else url += '?page=1';
    if (path.indexOf('category.php') >= 0 && path.indexOf('order=') < 0) {
      url += '&order=DESC';
    }
    return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
      var origin = arabicOrigin(got.url) || base;
      var items = arabicParseLarozaCards(ctx, got.html, origin, isMovie);
      if (group && !isMovie) items = arabicGroupLarozaSearch(items);
      return hubClampList(items, limit);
    });
  });
}

function arabicDiscoverHomePath(html) {
  var m = /href="([^"]*\/home\.\d+)"/i.exec(String(html || ''));
  if (m && m[1]) {
    var path = m[1];
    try {
      var u = new URL(path, 'https://laaroza.website/');
      return u.pathname || '/home.24';
    } catch (e) {
      if (path.charAt(0) === '/') return path;
    }
  }
  return '/home.24';
}

function arabicParseHomeSections(ctx, html, base) {
  var rails = {};
  var raw = String(html || '');
  var ulRe = /<ul[^>]*class="[^"]*pm-ul[^"]*"[^>]*>([\s\S]*?)<\/ul>/gi;
  var m;
  while ((m = ulRe.exec(raw))) {
    var back = raw.substring(Math.max(0, m.index - 900), m.index);
    var headingRe = /<h([23])[^>]*>([\s\S]*?)<\/h\1>/gi;
    var title = '';
    var hm;
    while ((hm = headingRe.exec(back))) {
      title = String(hm[2] || '')
        .replace(/<[^>]+>/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    }
    if (!title || title.indexOf("'+") >= 0 || title.indexOf('"+') >= 0) continue;
    var rail = ARABIC_HOME_SECTION_RAILS[title];
    if (!rail || rails[rail]) continue;
    var cardsHtml = '<ul class="pm-ul">' + (m[1] || '') + '</ul>';
    var isMovie = rail === 'movies';
    var items = arabicParseLarozaCards(ctx, cardsHtml, base, isMovie);
    if (!isMovie) items = arabicGroupLarozaSearch(items);
    if (items.length) rails[rail] = items;
  }
  return rails;
}

function arabicFetchHomeRails(ctx, cfg, limit) {
  return arabicEnsureLaroza(ctx, cfg).then(function (resolved) {
    var base = resolved.origin;
    // Prefer splash HTML from mirror probe — `/` is often gaza.N; catalog is /home.N.
    var splashP = resolved.splashHtml
      ? Promise.resolve({ html: resolved.splashHtml, url: base + '/' })
      : arabicFetchHtml(ctx, base + '/', base + '/');
    return splashP.then(function (splash) {
      var homePath = arabicDiscoverHomePath(splash.html);
      return arabicFetchHtml(ctx, base + homePath, base + '/').then(function (got) {
        var origin = arabicOrigin(got.url) || base;
        var rails = arabicParseHomeSections(ctx, got.html, origin);
        var out = { _base: base };
        var keys = Object.keys(rails);
        for (var i = 0; i < keys.length; i++) {
          out[keys[i]] = hubClampList(rails[keys[i]], limit);
        }
        if (out.latest && !out.trending) {
          out.trending = out.latest.slice();
        }
        return out;
      });
    });
  });
}

function arabicSearchLaroza(ctx, cfg, query, limit) {
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
    var url =
      base +
      '/search.php?keywords=' +
      encodeURIComponent(query) +
      '&page=1';
    return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
      var origin = arabicOrigin(got.url) || base;
      return hubClampList(
        arabicGroupLarozaSearch(
          arabicParseLarozaCards(ctx, got.html, origin, false),
        ),
        limit,
      );
    });
  });
}

function arabicRailItems(ctx, cfg, params) {
  var rail = String(params.rail || '');
  if (arabicChromeFiltered(params)) {
    return arabicExploreList(ctx, cfg, params)
      .then(function (items) {
        return hubItems('rail', items || [], { maxAge: 600, swr: 3600 });
      })
      .catch(function (e) {
        return hubFail('rail', 'UPSTREAM', e && e.message, true);
      });
  }
  var spec = ARABIC_RAILS[rail];
  if (!spec) {
    return Promise.resolve(
      hubFail('rail', 'INVALID_PARAMS', 'unknown rail ' + rail),
    );
  }
  var limit = params.limit;
  var p;
  if (spec.kind === 'larozaa_browse') {
    p = arabicLarozaList(ctx, cfg, spec.path, false, limit, !!spec.group);
  } else if (spec.kind === 'larozaa_cat') {
    p = arabicLarozaList(
      ctx,
      cfg,
      '/category.php?cat=' + encodeURIComponent(spec.cat),
      !!spec.movie,
      limit,
      !!spec.group,
    );
  } else {
    return Promise.resolve(
      hubFail('rail', 'INVALID_PARAMS', 'unknown rail kind'),
    );
  }
  return p
    .then(function (items) {
      return hubItems('rail', items || [], { maxAge: 600, swr: 3600 });
    })
    .catch(function (e) {
      return hubFail('rail', 'UPSTREAM', e && e.message, true);
    });
}

function arabicFeedRailLimit(railId, params) {
  var n = Number(params.limit);
  if (n > 0) return n;
  return 24;
}

function arabicLoadRailList(ctx, cfg, railId, limit) {
  var spec = ARABIC_RAILS[railId];
  if (!spec) return Promise.resolve([]);
  if (spec.kind === 'larozaa_browse') {
    return arabicLarozaList(ctx, cfg, spec.path, false, limit, !!spec.group);
  }
  if (spec.kind === 'larozaa_cat') {
    return arabicLarozaList(
      ctx,
      cfg,
      '/category.php?cat=' + encodeURIComponent(spec.cat),
      !!spec.movie,
      limit,
      !!spec.group,
    );
  }
  return Promise.resolve([]);
}

function arabicFeed(ctx, cfg, params) {
  if (arabicChromeFiltered(params)) {
    return arabicFilteredFeed(ctx, cfg, params);
  }
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  return arabicFetchHomeRails(ctx, cfg, limit)
    .catch(function () {
      return {};
    })
    .then(function (homeRails) {
      var jobs = [];
      for (var i = 0; i < ARABIC_FEED_RAILS.length; i++) {
        (function (railId) {
          var railLimit = arabicFeedRailLimit(railId, params);
          var seeded = homeRails[railId];
          if (seeded && seeded.length) {
            jobs.push(
              Promise.resolve({ rail: railId, items: seeded.slice(0, railLimit) }),
            );
            return;
          }
          jobs.push(
            arabicLoadRailList(ctx, cfg, railId, railLimit)
              .then(function (items) {
                return { rail: railId, items: items || [] };
              })
              .catch(function () {
                return { rail: railId, items: [] };
              }),
          );
        })(ARABIC_FEED_RAILS[i]);
      }
      return Promise.all(jobs).then(function (rows) {
        var rails = {};
        for (var k = 0; k < rows.length; k++) {
          rails[rows[k].rail] = rows[k].items;
        }
        if ((!rails.trending || !rails.trending.length) && rails.latest) {
          rails.trending = rails.latest.slice();
        }
        return hubOk('feed', { rails: rails }, { maxAge: 600, swr: 3600 });
      });
    });
}

function arabicSearch(ctx, cfg, params) {
  var q = String(params.query || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 40;
  return arabicSearchLaroza(ctx, cfg, q, limit)
    .then(function (items) {
      return hubItems('search', items || [], { maxAge: 300 });
    })
    .catch(function (e) {
      return hubFail('search', 'UPSTREAM', e && e.message, true);
    });
}

function arabicParseShowRef(params) {
  var raw = String(params.id || '').trim();
  var source = String(params.source || '').trim() || 'larozaa';
  var rest = raw;
  var colon = raw.indexOf(':');
  if (colon > 0) {
    var head = raw.substring(0, colon);
    if (head === 'larozaa') {
      source = 'larozaa';
      rest = raw.substring(colon + 1);
    } else if (head === 'brstej' || head === 'dimatoon') {
      // Wrong hub — do not rewrite as Larozaa.
      source = head;
      rest = raw.substring(colon + 1);
    }
  }
  var fullId =
    source === 'larozaa' ? 'larozaa:' + rest : source + ':' + rest;
  var url = String(params.url || '').trim();
  var isMovie =
    params.movie === true ||
    params.movie === 'true' ||
    params.isMovie === true;
  return {
    raw: raw,
    fullId: fullId,
    source: source,
    rest: rest,
    url: url,
    isMovie: isMovie,
  };
}

function arabicEpThumb($, a, base) {
  var img = a.find('img').first();
  if (!img.length) {
    var parent = a.parent();
    if (parent && parent.length) img = parent.find('img').first();
  }
  return arabicImg($, img, base);
}

function arabicMergeEpByVid(byId, order, vid, title, poster) {
  var existing = byId[vid];
  if (!existing) {
    order.push(vid);
    byId[vid] = { title: title, poster: poster };
  } else {
    if (!existing.title && title) existing.title = title;
    if (!existing.poster && poster) existing.poster = poster;
  }
}

function arabicLarozaEpisodesFromAnchors($, anchors, base) {
  var byId = {};
  var order = [];
  anchors.each(function () {
    var a = $(this);
    var href = a.attr('href') || '';
    var m = /vid=([^&]+)/.exec(href);
    if (!m) return;
    var vid = m[1];
    var title = (a.text() || '').trim();
    var poster = arabicEpThumb($, a, base);
    arabicMergeEpByVid(byId, order, vid, title, poster);
  });
  var videos = [];
  var reversed = order.slice().reverse();
  for (var i = 0; i < reversed.length; i++) {
    var vid = reversed[i];
    var e = byId[vid];
    var epTitle = e.title;
    if (!epTitle) epTitle = 'الحلقة ' + (i + 1);
    videos.push({
      id: 'larozaa:' + vid,
      title: epTitle,
      season: 1,
      episode: i + 1,
      thumbnail: e.poster || '',
    });
  }
  return videos;
}

function arabicParseLarozaShowHtml(ctx, html, base, seasonOffset) {
  var $ = arabicHtml(ctx, html);
  var title = '';
  var poster = '';
  var description = '';
  var videos = [];
  seasonOffset = seasonOffset || 0;
  if (!$) {
    return { title: title, poster: poster, description: description, videos: videos };
  }

  var titleEl = $('h2').first();
  if (!titleEl.length) titleEl = $('h1').first();
  title = (titleEl.text() || '').trim();

  var posterImg = $('img[src*="uploads/thumbs"]').first();
  if (!posterImg.length) posterImg = $('img[data-echo*="uploads/thumbs"]').first();
  if (posterImg.length) {
    poster = arabicImg($, posterImg, base);
  }

  var descEl = $('.pm-video-content').first();
  if (!descEl.length) descEl = $('.description').first();
  if (!descEl.length) descEl = $('.story').first();
  description = (descEl.text() || '').trim();

  var seasonButtons = $('.SeasonsBoxUL button.tablinks');
  if (seasonButtons.length) {
    seasonButtons.each(function (si) {
      var seasonNum = seasonOffset + si + 1;
      var tabId = 'Season' + (si + 1);
      var seasonDiv = $('#' + tabId);
      if (!seasonDiv.length) return;
      var byId = {};
      var order = [];
      seasonDiv.find('a[href*="video.php"]').each(function () {
        var a = $(this);
        var href = a.attr('href') || '';
        var m = /vid=([^&]+)/.exec(href);
        if (!m) return;
        arabicMergeEpByVid(
          byId,
          order,
          m[1],
          (a.text() || '').trim(),
          arabicEpThumb($, a, base),
        );
      });
      var reversed = order.slice().reverse();
      for (var i = 0; i < reversed.length; i++) {
        var vid = reversed[i];
        var e = byId[vid];
        videos.push({
          id: 'larozaa:' + vid,
          title: e.title || 'الحلقة ' + (i + 1),
          season: seasonNum,
          episode: i + 1,
          thumbnail: e.poster || '',
        });
      }
    });
  } else {
    var flat = arabicLarozaEpisodesFromAnchors(
      $,
      $('a[href*="video.php"]'),
      base,
    );
    for (var j = 0; j < flat.length; j++) {
      flat[j].season = seasonOffset + 1;
      videos.push(flat[j]);
    }
  }

  return { title: title, poster: poster, description: description, videos: videos };
}

function arabicDetailsLarozaMovieFromPage(ctx, ref, got, vid, pageUrl) {
  var origin = arabicOrigin(got.url) || '';
  var $ = arabicHtml(ctx, got.html);
  var title = '';
  var poster = '';
  var description = '';
  if ($) {
    var titleEl = $('h1, h2').first();
    title = (titleEl.text() || '').trim();
    var posterImg = $(
      'img[src*="uploads/thumbs"], img[data-echo*="uploads/thumbs"]',
    ).first();
    if (posterImg.length) poster = arabicImg($, posterImg, origin);
    var descEl = $('.pm-video-description, .pm-video-content').first();
    description = (descEl.text() || '').trim();
  }
  if (!title) {
    var tm = /<title[^>]*>([^<]+)/i.exec(got.html);
    if (tm) {
      title = String(tm[1] || '')
        .replace(/\s*[-|].*$/, '')
        .trim();
    }
  }
  var id = String(vid || ref.rest || '').replace(/^ep:/, '');
  var meta = arabicMeta('larozaa', id, title || id, poster, {
    description: description,
    isMovie: true,
    url: ref.url || pageUrl,
  });
  if (!meta) {
    return hubFail('details', 'NOT_FOUND', 'arabic id ' + ref.fullId);
  }
  meta.id = 'larozaa:' + id;
  meta.description = description || '';
  meta.videos = [
    {
      id: 'larozaa:' + id,
      title: title || id,
      season: 1,
      episode: 1,
      thumbnail: poster || '',
    },
  ];
  return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
}

function arabicDetailsLaroza(ctx, cfg, ref) {
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
    var rest = ref.rest;
    if (ref.isMovie && rest && rest.indexOf('ep:') !== 0) {
      var movieUrl = base + '/video.php?vid=' + encodeURIComponent(rest);
      return arabicFetchHtml(ctx, movieUrl, base + '/').then(function (got) {
        return arabicDetailsLarozaMovieFromPage(ctx, ref, got, rest, movieUrl);
      });
    }

    if (rest.indexOf('ep:') === 0) {
      var epVid = rest.substring(3);
      var epUrl = base + '/video.php?vid=' + encodeURIComponent(epVid);
      return arabicFetchHtml(ctx, epUrl, base + '/').then(function (got) {
        var serId = arabicLarozaSerieIdFromHtml(got.html);
        if (!serId) {
          // Movies on newvideos use video.php but no serie link — open as movie.
          return arabicDetailsLarozaMovieFromPage(ctx, ref, got, epVid, epUrl);
        }
        var url =
          base + '/view-serie1.php?ser=' + encodeURIComponent(serId);
        return arabicFetchHtml(ctx, url, base + '/').then(function (show) {
          var origin = arabicOrigin(show.url) || base;
          var parsed = arabicParseLarozaShowHtml(ctx, show.html, origin, 0);
          var name = parsed.title || rest || ref.fullId;
          var meta = arabicMeta('larozaa', serId, name, parsed.poster || '', {
            description: parsed.description,
            isMovie: false,
            url: ref.url,
          });
          if (!meta) {
            return hubFail('details', 'NOT_FOUND', 'arabic id ' + ref.fullId);
          }
          // Stable show id once resolved (not the episode stub).
          meta.id = 'larozaa:' + serId;
          meta.description = parsed.description || '';
          meta.videos = parsed.videos || [];
          return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
        });
      });
    }

    var url = base + '/view-serie1.php?ser=' + encodeURIComponent(rest);
    return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
      var origin = arabicOrigin(got.url) || base;
      var parsed = arabicParseLarozaShowHtml(ctx, got.html, origin, 0);
      var name = parsed.title || rest || ref.fullId;
      var meta = arabicMeta('larozaa', rest, name, parsed.poster || '', {
        description: parsed.description,
        isMovie: false,
        url: ref.url,
      });
      if (!meta) {
        return hubFail('details', 'NOT_FOUND', 'arabic id ' + ref.fullId);
      }
      meta.id = ref.fullId;
      meta.description = parsed.description || '';
      meta.videos = parsed.videos || [];
      return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
    });
  });
}

function arabicDetails(ctx, cfg, params) {
  var ref = arabicParseShowRef(params);
  if (!ref.rest && !ref.raw) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'details needs params.id'),
    );
  }
  if (ref.source && ref.source !== 'larozaa') {
    return Promise.resolve(
      hubFail(
        'details',
        'INVALID_PARAMS',
        'arabic hub is Larozaa-only (got ' + ref.source + ')',
      ),
    );
  }
  return arabicDetailsLaroza(ctx, cfg, ref).catch(function (e) {
    return hubFail('details', 'UPSTREAM', e && e.message, true);
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, ARABIC_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', arabicLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'filters') {
    return hubOk('filters', arabicFilters(), { maxAge: 86400 });
  }
  if (action === 'feed') {
    return arabicFeed(ctx, cfg, params).catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'details') {
    return arabicDetails(ctx, cfg, params);
  }
  if (action === 'search') {
    return arabicSearch(ctx, cfg, params).catch(function (e) {
      return hubFail('search', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'rail') {
    return arabicRailItems(ctx, cfg, params);
  }
  return hubFail(action, 'INVALID_ACTION', 'arabic hub has no action ' + action);
}
