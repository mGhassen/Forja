// Arabic hub — Larozaa + DimaToon + Brstej (protocol 1).
// Browse / search / details / stream all live in this pack. Host only
// renders CatalogShell + surface:arabic details UI and resolves embeds.

var ARABIC_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

var ARABIC_DEFAULTS = {
  bootstrap: 'https://larozaa.bond',
  mirrors: [
    'https://larozaa.bond',
    'https://larozaa.home',
    'https://larozaa.homes',
    'https://larozaa.com',
    'https://laaroza.pics',
  ],
  dimatoon: 'https://www.dima-toon.com',
  brstej: 'https://hd1.brstej.com',
};

var ARABIC_RAILS = {
  trending: { kind: 'larozaa_browse', path: '/moslslat4.php' },
  series: { kind: 'larozaa_cat', cat: 'arabic-series46' },
  movies: { kind: 'larozaa_cat', cat: 'arabic-movies33', movie: true },
  turkish: { kind: 'larozaa_cat', cat: 'turkish-3isk-seriess47' },
  ramadan: { kind: 'larozaa_cat', cat: 'ramadan-2026' },
  tv_programs: { kind: 'larozaa_cat', cat: 'tv-programs12' },
  foreign_movies: { kind: 'larozaa_cat', cat: 'all_movies_13', movie: true },
  indian: { kind: 'larozaa_cat', cat: 'indian-movies9', movie: true },
  dubbed: { kind: 'larozaa_cat', cat: '7-aflammdblgh', movie: true },
  anime_movies: { kind: 'larozaa_cat', cat: 'anime-movies-7', movie: true },
  brstej: { kind: 'brstej_browse' },
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
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'رائج · Spotlight',
            rail: 'trending',
            bleed: 'brstej',
          },
          {
            type: 'ranked',
            id: 'brstej',
            title: 'Brstej · أحدث',
            rail: 'brstej',
            style: 'numbered',
            hideWhenBleed: true,
          },
          { type: 'host.continue', id: 'continue_watching' },
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
          { type: 'rail', id: 'ramadan', title: 'رمضان 2026', rail: 'ramadan' },
          {
            type: 'rail',
            id: 'tv_programs',
            title: 'برامج تلفزيونية',
            rail: 'tv_programs',
          },
          {
            type: 'rail',
            id: 'foreign_movies',
            title: 'أفلام أجنبية',
            rail: 'foreign_movies',
          },
          {
            type: 'rail',
            id: 'indian',
            title: 'أفلام هندية',
            rail: 'indian',
          },
          {
            type: 'rail',
            id: 'dubbed',
            title: 'أفلام مدبلجة',
            rail: 'dubbed',
          },
          {
            type: 'rail',
            id: 'anime_movies',
            title: 'أنمي',
            rail: 'anime_movies',
          },
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
      return Promise.resolve(ordered[0] || 'https://larozaa.bond');
    }
    var boot = ordered[index];
    return ctx
      .fetch(boot, { headers: arabicHeaders(boot + '/') })
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
  $('li.col-xs-6.col-sm-4.col-md-3, li[class*="col-xs-6"]').each(function () {
    var card = $(this);
    var a = card.find('a[href]').first();
    if (!a.length) return;
    var href = a.attr('href') || '';
    var title = (a.attr('title') || a.text() || '').trim();
    if (!title) return;
    var poster = arabicImg($, card.find('img').first(), base);
    var ser = /ser=([^&]+)/.exec(href);
    var vid = /vid=([^&]+)/.exec(href);
    var id = '';
    var movie = !!isMovie || href.indexOf('video.php') >= 0;
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
    /<li[^>]*class="[^"]*col-xs-6[^"]*"[^>]*>[\s\S]*?<a[^>]+href="([^"]+)"[^>]*(?:title="([^"]*)")?[\s\S]*?<\/li>/gi;
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
    var ser = /ser=([^&]+)/.exec(href);
    var vid = /vid=([^&]+)/.exec(href);
    var id = '';
    var movie = !!isMovie || href.indexOf('video.php') >= 0;
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

function arabicLarozaList(ctx, cfg, path, isMovie, limit) {
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
    var url = base + path;
    if (path.indexOf('?') >= 0) url += '&page=1';
    else url += '?page=1';
    if (path.indexOf('category.php') >= 0 && path.indexOf('order=') < 0) {
      url += '&order=DESC';
    }
    return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
      var origin = arabicOrigin(got.url) || base;
      return hubClampList(
        arabicParseLarozaCards(ctx, got.html, origin, isMovie),
        limit,
      );
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
    p = arabicLarozaList(ctx, cfg, spec.path, false, limit);
  } else if (spec.kind === 'larozaa_cat') {
    p = arabicLarozaList(
      ctx,
      cfg,
      '/category.php?cat=' + encodeURIComponent(spec.cat),
      !!spec.movie,
      limit,
    );
  } else if (spec.kind === 'brstej_browse') {
    p = arabicBrowseBrstej(ctx, cfg, limit);
  } else {
    return Promise.resolve(
      hubFail('rail', 'INVALID_PARAMS', 'unknown rail kind'),
    );
  }
  return p
    .then(function (items) {
      if ((!items || !items.length) && rail === 'trending') {
        return arabicBrowseBrstej(ctx, cfg, limit).then(function (fallback) {
          return hubItems('rail', fallback || [], { maxAge: 600, swr: 3600 });
        });
      }
      return hubItems('rail', items, { maxAge: 600, swr: 3600 });
    })
    .catch(function (e) {
      if (rail === 'trending') {
        return arabicBrowseBrstej(ctx, cfg, limit)
          .then(function (fallback) {
            return hubItems('rail', fallback || [], { maxAge: 300, swr: 900 });
          })
          .catch(function () {
            return hubFail('rail', 'UPSTREAM', e && e.message, true);
          });
      }
      return hubFail('rail', 'UPSTREAM', e && e.message, true);
    });
}

function arabicSearch(ctx, cfg, params) {
  var q = String(params.query || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 40;
  var per = Math.max(8, Math.ceil(limit / 3));
  return Promise.all([
    arabicSearchLaroza(ctx, cfg, q, per).catch(function () {
      return [];
    }),
    arabicSearchDimaToon(ctx, cfg, q, per),
    arabicSearchBrstej(ctx, cfg, q, per).catch(function () {
      return [];
    }),
  ]).then(function (parts) {
    var out = [];
    var seen = {};
    for (var p = 0; p < parts.length; p++) {
      var list = parts[p] || [];
      for (var i = 0; i < list.length; i++) {
        var it = list[i];
        if (!it || !it.id || seen[it.id]) continue;
        seen[it.id] = true;
        out.push(it);
      }
    }
    return hubItems('search', hubClampList(out, limit), { maxAge: 300 });
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

function arabicDetailsLaroza(ctx, cfg, ref) {
  return arabicResolveLaroza(ctx, cfg).then(function (base) {
    var rest = ref.rest;
    var resolveEp =
      rest.indexOf('ep:') === 0
        ? arabicFetchHtml(
            ctx,
            base + '/video.php?vid=' + encodeURIComponent(rest.substring(3)),
            base + '/',
          ).then(function (got) {
            var m = /view-serie1?\.php\?ser=([a-zA-Z0-9]+)/.exec(got.html);
            if (!m) {
              throw new Error('Could not resolve series id from ' + rest);
            }
            return m[1];
          })
        : Promise.resolve(rest);

    return resolveEp.then(function (serId) {
      var url = base + '/view-serie1.php?ser=' + encodeURIComponent(serId);
      return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
        var origin = arabicOrigin(got.url) || base;
        var parsed = arabicParseLarozaShowHtml(ctx, got.html, origin, 0);
        if (
          (!parsed.videos || !parsed.videos.length) &&
          ref.isMovie &&
          rest &&
          rest.indexOf('ep:') !== 0
        ) {
          parsed.videos = [
            {
              id: 'larozaa:' + rest,
              title: parsed.title || rest,
              season: 1,
              episode: 1,
              thumbnail: parsed.poster || '',
            },
          ];
        }
        var name = parsed.title || rest || ref.fullId;
        var meta = arabicMeta('larozaa', rest, name, parsed.poster || '', {
          description: parsed.description,
          isMovie: ref.isMovie,
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
    var url = base + '/play.php?vid=' + encodeURIComponent(vid);
    return arabicFetchHtml(ctx, url, base + '/').then(function (got) {
      var $ = arabicHtml(ctx, got.html);
      var streams = [];
      if ($) {
        $('.WatchList li').each(function () {
          var item = $(this);
          var embedUrl = item.attr('data-embed-url') || '';
          if (!embedUrl) return;
          var name = (item.text() || '').trim();
          streams.push({
            name: name || 'Server ' + (streams.length + 1),
            url: embedUrl,
            type: 'embed',
          });
        });
        if (!streams.length) {
          var iframe = $('iframe[src]').first();
          var src = iframe.length ? iframe.attr('src') || '' : '';
          if (src) {
            streams.push({ name: 'Server 1', url: src, type: 'embed' });
          }
        }
      }
      return hubOk('stream', { streams: streams }, { maxAge: 120 });
    });
  });
}

function arabicStreamDimaToon(ctx, cfg, episodeUrl) {
  var base = String(cfg.dimatoon || ARABIC_DEFAULTS.dimatoon).replace(/\/$/, '');
  return arabicFetchHtml(ctx, episodeUrl, base + '/').then(function (got) {
    var $ = arabicHtml(ctx, got.html);
    var src = '';
    if ($) {
      var source = $('source[src]').first();
      if (source.length) src = source.attr('src') || '';
    }
    if (!src) {
      var m = /https?:\/\/[^"\s]+\.mp4[^"\s]*/.exec(got.html);
      if (m) src = m[0];
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
  var url = base + '/play.php?vid=' + encodeURIComponent(vid);
  var referer = base + '/watch.php?vid=' + encodeURIComponent(vid);
  return arabicFetchHtml(ctx, url, referer).then(function (got) {
    var $ = arabicHtml(ctx, got.html);
    var streams = [];
    if ($) {
      $('button[data-embed-url]').each(function () {
        var b = $(this);
        var embed = b.attr('data-embed-url') || '';
        if (!embed) return;
        var name = (b.text() || '').trim();
        streams.push({
          name: name || 'Server ' + (streams.length + 1),
          url: embed,
          type: 'embed',
        });
      });
      if (!streams.length) {
        var iframe = $('iframe[src]').first();
        var src = iframe.length ? iframe.attr('src') || '' : '';
        if (src) {
          streams.push({ name: 'Server 1', url: src, type: 'embed' });
        }
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
  if (action === 'details') {
    return arabicDetails(ctx, cfg, params);
  }
  if (action === 'stream') {
    return arabicStream(ctx, cfg, params);
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
