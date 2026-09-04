// Arabic hub — Larozaa only (protocol 1).
// Brstej → plugins/hubs/brstej. كرتون / DimaToon → plugins/hubs/cartoon.
// Legacy details/stream kept for old brstej:/dimatoon: history ids.
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
  // Legacy only — not used for browse/search.
  dimatoon: 'https://www.dima-toon.com',
  brstej: 'https://uo.brstej.com',
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

var ARABIC_FEED_RAILS = [
  'trending',
  'latest',
  'series',
  'movies',
  'turkish',
  'foreign_series',
  'foreign_movies',
  'indian_series',
  'indian',
  'asian_series',
  'asian_movies',
  'anime_series',
  'anime_movies',
  'dubbed',
  'turkish_movies',
  'ramadan',
  'tv_programs',
  'plays',
];

var ARABIC_HOME_SECTION_RAILS = {
  'أخر الاضافات': 'latest',
  'افلام عربي': 'movies',
  'مسلسلات تركية': 'turkish',
  'مسلسلات عربية': 'series',
};

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

function arabicResolveLaroza(ctx, cfg) {
  var boots = [cfg.bootstrap]
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
      return Promise.resolve(ordered[0] || 'https://laaroza.website');
    }
    var boot = ordered[index];
    // Hit `/` only — long mirror chains exceed engine maxRedirects (8).
    return ctx
      .fetch(boot + '/', { headers: arabicHeaders(boot + '/') })
      .then(function (res) {
        var origin = arabicOrigin(res.url || boot);
        var host = '';
        try {
          host = new URL(origin).host;
        } catch (e) {}
        if (origin && arabicIsLarozaHost(host)) return origin;
        return attempt(index + 1);
      })
      .catch(function () {
        return attempt(index + 1);
      });
  }

  return attempt(0);
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

function arabicLarozaList(ctx, cfg, path, isMovie, limit, group) {
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
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
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
    // `/` is often a splash (gaza.N); catalog rows live on /home.N.
    return arabicFetchHtml(ctx, base + '/', base + '/').then(function (splash) {
      var homePath = arabicDiscoverHomePath(splash.html);
      return arabicFetchHtml(ctx, base + homePath, base + '/').then(function (got) {
        var origin = arabicOrigin(got.url) || base;
        var rails = arabicParseHomeSections(ctx, got.html, origin);
        var out = {};
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

function arabicSearchDimaToon(ctx, cfg, query, limit) {
  var base = String(cfg.dimatoon || ARABIC_DEFAULTS.dimatoon).replace(/\/$/, '');
  return ctx
    .fetch(base + '/wp-admin/admin-ajax.php', {
      method: 'POST',
      headers: Object.assign(arabicHeaders(base + '/'), {
        'Content-Type': 'application/x-www-form-urlencoded',
      }),
      body:
        'action=cartoon_search_action&term=' + encodeURIComponent(query),
    })
    .then(function (res) {
      if (!res.ok) return [];
      return res.text();
    })
    .then(function (html) {
      var $ = arabicHtml(ctx, html);
      var out = [];
      if ($) {
        $('.search-result-item').each(function () {
          var item = $(this);
          var a = item.find('a[href]').first();
          var img = item.find('img').first();
          if (!a.length) return;
          var href = a.attr('href') || '';
          var title = (a.text() || '').trim();
          var poster = img.length ? img.attr('src') || '' : '';
          if (!title || !href) return;
          var meta = arabicMeta('dimatoon', href, title, poster, { url: href });
          if (meta) out.push(meta);
        });
      }
      return hubClampList(out, limit);
    })
    .catch(function () {
      return [];
    });
}

function arabicStripBrstejPrefix(title) {
  return String(title || '')
    .replace(/^مسلسل\s+/, '')
    .trim();
}

function arabicStripBrstejEpisode(title) {
  var t = String(title || '').replace(/\s*الحلقة\s+.*$/, '');
  t = t.replace(/\s*(HD|مترجم(ة)?|مدبلج(ة)?)\s*$/, '');
  return t.trim();
}

function arabicNormBrstejTitle(title) {
  return arabicStripBrstejPrefix(arabicStripBrstejEpisode(title))
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function arabicParseBrstejSerieCards(ctx, html, base) {
  var $ = arabicHtml(ctx, html);
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
    var title = arabicStripBrstejPrefix(
      (a.attr('title') || a.text() || '').trim(),
    );
    if (!title) return;
    var meta = arabicMeta(
      'brstej',
      'serie:' + id,
      title,
      arabicImg($, card.find('img').first(), base),
      { url: arabicAbs(base, href) },
    );
    if (meta) out.push(meta);
  });
  return out;
}

function arabicParseBrstejEpisodeCards(ctx, html, base) {
  var $ = arabicHtml(ctx, html);
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
    var meta = arabicMeta(
      'brstej',
      'watch:' + m[1],
      title,
      arabicImg($, card.find('img').first(), base),
      { url: arabicAbs(base, href) },
    );
    if (meta) out.push(meta);
  });
  return out;
}

function arabicBrowseBrstej(ctx, cfg, limit) {
  var base = String(cfg.brstej || ARABIC_DEFAULTS.brstej).replace(/\/$/, '');
  return arabicFetchHtml(ctx, base + '/moslsalat.php?page=1', base + '/').then(
    function (got) {
      return hubClampList(
        arabicParseBrstejSerieCards(ctx, got.html, base),
        limit,
      );
    },
  );
}

function arabicSearchBrstej(ctx, cfg, query, limit) {
  var base = String(cfg.brstej || ARABIC_DEFAULTS.brstej).replace(/\/$/, '');
  var url =
    base +
    '/search.php?keywords=' +
    encodeURIComponent(query) +
    '&page=1';
  return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
    var episodes = arabicParseBrstejEpisodeCards(ctx, got.html, base);
    var byKey = {};
    var order = [];
    for (var i = 0; i < episodes.length; i++) {
      var ep = episodes[i];
      var key = arabicNormBrstejTitle(ep.name);
      if (!key) continue;
      if (!byKey[key]) {
        order.push(key);
        byKey[key] = arabicMeta(
          'brstej',
          ep.ids.brstej,
          arabicStripBrstejPrefix(arabicStripBrstejEpisode(ep.name)),
          ep.poster,
          { url: ep.ids.url },
        );
      }
    }
    var out = [];
    for (i = 0; i < order.length; i++) {
      if (byKey[order[i]]) out.push(byKey[order[i]]);
    }
    return hubClampList(out, limit);
  });
}

function arabicRailItems(ctx, cfg, params) {
  var rail = String(params.rail || '');
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
  var source = String(params.source || '').trim();
  var rest = raw;
  var colon = raw.indexOf(':');
  if (colon > 0) {
    var head = raw.substring(0, colon);
    if (head === 'larozaa' || head === 'dimatoon' || head === 'brstej') {
      source = source || head;
      rest = raw.substring(colon + 1);
    }
  }
  if (!source) source = 'larozaa';
  var fullId = source + ':' + rest;
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

function arabicParseVideoRef(raw) {
  raw = String(raw || '').trim();
  var colon = raw.indexOf(':');
  if (colon < 0) return { source: '', rest: raw };
  return {
    source: raw.substring(0, colon),
    rest: raw.substring(colon + 1),
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

function arabicDetailsDimaToon(ctx, cfg, ref) {
  var base = String(cfg.dimatoon || ARABIC_DEFAULTS.dimatoon).replace(/\/$/, '');
  var showUrl = ref.url || '';
  if (!showUrl && /^https?:\/\//i.test(ref.rest)) showUrl = ref.rest;
  if (!showUrl) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'dimatoon details needs params.url'),
    );
  }
  return arabicFetchHtml(ctx, showUrl, base + '/').then(function (got) {
    var $ = arabicHtml(ctx, got.html);
    var title = '';
    var poster = '';
    var description = '';
    var videos = [];
    if ($) {
      var titleEl = $('h1, .entry-title, .term-title').first();
      title = (titleEl.text() || '').trim();
      var imgEl = $('.cartoon-image img').first();
      poster = imgEl.length ? imgEl.attr('src') || '' : '';
      var storyEl = $('.brief-story').first();
      description = (storyEl.text() || '').trim();
      description = description.replace(/^قصة الكرتون\s*:\s*/, '');
      var epNum = 0;
      $('.episode-box a[href]').each(function () {
        var a = $(this);
        var href = a.attr('href') || '';
        var epTitle = (a.text() || '').trim();
        if (!href || !epTitle) return;
        epNum += 1;
        videos.push({
          id: 'dimatoon:' + href,
          title: epTitle,
          season: 1,
          episode: epNum,
          thumbnail: '',
        });
      });
    }
    var name = title || ref.rest || ref.fullId;
    var meta = arabicMeta('dimatoon', ref.rest, name, poster, {
      description: description,
      url: showUrl,
    });
    if (!meta) {
      return hubFail('details', 'NOT_FOUND', 'arabic id ' + ref.fullId);
    }
    meta.id = ref.fullId;
    meta.description = description;
    meta.videos = videos;
    return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
  });
}

function arabicBrstejEpisodeNumber(title) {
  var t = String(title || '');
  var m =
    /الحلقة\s+(\d+)/.exec(t) ||
    /<em>\s*(\d+)/.exec(t) ||
    /\b(\d{1,3})\b/.exec(t);
  return m ? Number(m[1]) : null;
}

function arabicParseBrstejEpisodeAnchors($, anchors, base) {
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
    var p = arabicEpThumb($, a, base);
    arabicMergeEpByVid(byId, order, vid, t, p);
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
      _n: arabicBrstejEpisodeNumber(e.title),
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

function arabicParseBrstejSerieHtml(ctx, html, base) {
  var $ = arabicHtml(ctx, html);
  var out = { title: '', poster: '', description: '', videos: [] };
  if (!$) return out;

  var title =
    ($('h1').first().text() || $('h2').first().text() || '').trim();
  out.title = arabicStripBrstejPrefix(title);

  var posterImg = $('img[src*="uploads/thumbs"]').first();
  if (!posterImg.length) posterImg = $('img[data-echo*="uploads/thumbs"]').first();
  if (posterImg.length) out.poster = arabicImg($, posterImg, base);

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
      var eps = arabicParseBrstejEpisodeAnchors(
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
    var eps = arabicParseBrstejEpisodeAnchors(
      $,
      $('#pm-grid a[href*="watch.php"]'),
      base,
    );
    for (var j = 0; j < eps.length; j++) out.videos.push(eps[j]);
  }
  return out;
}

function arabicParseBrstejWatchHtml(ctx, html, base) {
  var $ = arabicHtml(ctx, html);
  var out = { title: '', poster: '', description: '', videos: [] };
  if (!$) return out;

  var nameMeta = $('meta[itemprop="name"]').first();
  var title = nameMeta.length
    ? (nameMeta.attr('content') || '').trim()
    : ($('h1').first().text() || '').trim();
  out.title = arabicStripBrstejPrefix(arabicStripBrstejEpisode(title));

  var thumbMeta = $('meta[itemprop="thumbnailUrl"]').first();
  out.poster = thumbMeta.length
    ? (thumbMeta.attr('content') || '').trim()
    : '';
  if (!out.poster) {
    var img = $('img[src*="uploads/thumbs"]').first();
    if (img.length) out.poster = arabicImg($, img, base);
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
        ? arabicParseBrstejEpisodeAnchors(
            $,
            epDiv.find('a[href*="watch.php"]'),
            base,
          )
        : [];
      for (var i = 0; i < eps.length; i++) {
        eps[i].season = seasonNum;
        out.videos.push(eps[i]);
      }
    });
  } else {
    var eps = arabicParseBrstejEpisodeAnchors(
      $,
      $('.SeasonsEpisodes a[href*="watch.php"]'),
      base,
    );
    for (var j = 0; j < eps.length; j++) out.videos.push(eps[j]);
  }
  return out;
}

function arabicDetailsBrstej(ctx, cfg, ref) {
  var base = String(cfg.brstej || ARABIC_DEFAULTS.brstej).replace(/\/$/, '');
  var showId = ref.rest;
  var url;
  var fromWatch = false;
  if (showId.indexOf('watch:') === 0) {
    url = base + '/watch.php?vid=' + encodeURIComponent(showId.substring(6));
    fromWatch = true;
  } else if (showId.indexOf('serie:') === 0) {
    url = base + '/view-serie.php?id=' + encodeURIComponent(showId.substring(6));
  } else {
    url = base + '/view-serie.php?id=' + encodeURIComponent(showId);
  }
  return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
    var parsed = fromWatch
      ? arabicParseBrstejWatchHtml(ctx, got.html, base)
      : arabicParseBrstejSerieHtml(ctx, got.html, base);
    var name = parsed.title || showId;
    var meta = arabicMeta('brstej', showId, name, parsed.poster || '', {
      description: parsed.description,
      url: ref.url || url,
    });
    if (!meta) {
      return hubFail('details', 'NOT_FOUND', 'arabic id ' + ref.fullId);
    }
    meta.id = ref.fullId;
    meta.description = parsed.description || '';
    meta.videos = parsed.videos || [];
    return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
  });
}

function arabicDetails(ctx, cfg, params) {
  var ref = arabicParseShowRef(params);
  if (!ref.rest && !ref.raw) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'details needs params.id'),
    );
  }
  var p;
  if (ref.source === 'dimatoon') p = arabicDetailsDimaToon(ctx, cfg, ref);
  else if (ref.source === 'brstej') p = arabicDetailsBrstej(ctx, cfg, ref);
  else p = arabicDetailsLaroza(ctx, cfg, ref);
  return p.catch(function (e) {
    return hubFail('details', 'UPSTREAM', e && e.message, true);
  });
}

function arabicStreamLaroza(ctx, cfg, vid) {
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
    var raw = String(vid || '').replace(/^ep:/, '');
    var url = base + '/play.php?vid=' + encodeURIComponent(raw);
    var referer = base + '/video.php?vid=' + encodeURIComponent(raw);
    return arabicFetchHtml(ctx, url, referer).then(function (got) {
      var $ = arabicHtml(ctx, got.html);
      var streams = [];
      var seen = {};
      function push(name, embedUrl) {
        embedUrl = String(embedUrl || '').trim();
        if (!embedUrl || seen[embedUrl]) return;
        seen[embedUrl] = true;
        streams.push({
          name: name || 'Server ' + (streams.length + 1),
          url: embedUrl,
          type: 'embed',
        });
      }
      if ($) {
        $('.WatchList li').each(function () {
          var item = $(this);
          push(item.text(), item.attr('data-embed-url') || '');
        });
        if (!streams.length) {
          var iframe = $('iframe[src]').first();
          var src = iframe.length ? iframe.attr('src') || '' : '';
          if (src && src.indexOf('new_ads') < 0) push('Server 1', src);
        }
      }
      if (!streams.length) {
        var re = /data-embed-url="([^"]+)"/gi;
        var m;
        while ((m = re.exec(got.html))) {
          push('Server ' + (streams.length + 1), m[1]);
        }
      }
      return hubOk('stream', { streams: streams }, { maxAge: 120 });
    });
  });
}

function arabicDimaToonIsBlankMp4(url) {
  var u = String(url || '').toLowerCase();
  return !u || u.indexOf('blank.mp4') >= 0;
}

function arabicStreamDimaToon(ctx, cfg, episodeUrl) {
  var base = String(cfg.dimatoon || ARABIC_DEFAULTS.dimatoon).replace(/\/$/, '');
  return arabicFetchHtml(ctx, episodeUrl, base + '/').then(function (got) {
    var $ = arabicHtml(ctx, got.html);
    var src = '';
    if ($) {
      $('video source[src], source[src]').each(function () {
        if (src) return;
        var cand = $(this).attr('src') || '';
        if (cand && !arabicDimaToonIsBlankMp4(cand)) src = cand;
      });
    }
    if (!src && got.html) {
      var re = /https?:\/\/[^"'\\\s<>]+\.mp4[^"'\\\s<>]*/gi;
      var m;
      while ((m = re.exec(got.html))) {
        var cand = m[0].replace(/&amp;/g, '&');
        if (!arabicDimaToonIsBlankMp4(cand)) {
          src = cand;
          break;
        }
      }
    }
    var streams = [];
    if (src) {
      streams.push({ name: 'DimaToon', url: src, type: 'direct' });
    }
    return hubOk('stream', { streams: streams }, { maxAge: 120 });
  });
}

function arabicStreamBrstej(ctx, cfg, videoId) {
  var base = String(cfg.brstej || ARABIC_DEFAULTS.brstej).replace(/\/$/, '');
  var vid =
    videoId.indexOf('watch:') === 0 ? videoId.substring(6) : videoId;
  if (!vid || vid.indexOf('larozaa:') === 0 || vid.indexOf('dimatoon:') === 0) {
    return Promise.resolve(hubOk('stream', { streams: [] }, { maxAge: 60 }));
  }
  var url = base + '/play.php?vid=' + encodeURIComponent(vid);
  var referer = base + '/watch.php?vid=' + encodeURIComponent(vid);
  return arabicFetchHtml(ctx, url, referer).then(function (got) {
    var origin = arabicOrigin(got.url) || base;
    referer = origin + '/watch.php?vid=' + encodeURIComponent(vid);
    var $ = arabicHtml(ctx, got.html);
    var streams = [];
    var seen = {};
    function push(name, embedUrl) {
      embedUrl = String(embedUrl || '').trim();
      if (!embedUrl || seen[embedUrl]) return;
      seen[embedUrl] = true;
      streams.push({
        name: name || 'Server ' + (streams.length + 1),
        url: embedUrl,
        type: 'embed',
      });
    }
    if ($) {
      $('button[data-embed-url], .watchButton[data-embed-url]').each(function () {
        var b = $(this);
        push((b.text() || '').trim(), b.attr('data-embed-url') || '');
      });
      if (!streams.length) {
        var iframe = $('iframe[src]').first();
        var src = iframe.length ? iframe.attr('src') || '' : '';
        if (src) push('Server 1', src);
      }
    }
    if (!streams.length && got.html) {
      var re = /data-embed-url\s*=\s*["']([^"']+)["']/gi;
      var m;
      while ((m = re.exec(got.html))) {
        push('Server ' + (streams.length + 1), m[1]);
      }
    }
    return hubOk('stream', { streams: streams }, { maxAge: 120 });
  });
}

function arabicStream(ctx, cfg, params) {
  var raw = String(params.id || '').trim();
  if (!raw) {
    return Promise.resolve(
      hubFail('stream', 'INVALID_PARAMS', 'stream needs params.id'),
    );
  }
  var ref = arabicParseVideoRef(raw);
  var source = ref.source;
  var rest = ref.rest;
  // Allow bare ids with explicit params.source
  if (!source || (source !== 'larozaa' && source !== 'dimatoon' && source !== 'brstej')) {
    source = String(params.source || 'larozaa').trim() || 'larozaa';
    rest = raw.indexOf(source + ':') === 0 ? raw.substring(source.length + 1) : raw;
  }
  var p;
  if (source === 'dimatoon') p = arabicStreamDimaToon(ctx, cfg, rest);
  else if (source === 'brstej') p = arabicStreamBrstej(ctx, cfg, rest);
  else p = arabicStreamLaroza(ctx, cfg, rest);
  return p.catch(function (e) {
    return hubFail('stream', 'UPSTREAM', e && e.message, true);
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, ARABIC_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', arabicLayout(), { maxAge: 3600, swr: 86400 });
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
