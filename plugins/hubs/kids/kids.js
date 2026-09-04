// Kids hub — Dimakids (dimakids.com) HTML catalog + search JSON.
// Seasons (الموسم / الجزء) group into one series card; details merges episodes.
// Playback: provider `dimakids`. Host surface: arabic.

var KIDS_DEFAULTS = {
  origin: 'https://www.dimakids.com',
  files: 'https://files.dimakids.com',
};

var KIDS_FEED_RAILS = ['spotlight', 'latest', 'movies', 'episodes'];

var KIDS_LETTERS = [
  { id: '0', label: 'ا' },
  { id: '1', label: 'ب' },
  { id: '2', label: 'ت' },
  { id: '3', label: 'ث' },
  { id: '4', label: 'ج' },
  { id: '5', label: 'ح' },
  { id: '6', label: 'خ' },
  { id: '7', label: 'د' },
  { id: '8', label: 'ذ' },
  { id: '9', label: 'ر' },
  { id: '10', label: 'ز' },
  { id: '11', label: 'س' },
  { id: '12', label: 'ش' },
  { id: '13', label: 'ص' },
  { id: '14', label: 'ض' },
  { id: '15', label: 'ط' },
  { id: '16', label: 'ع' },
  { id: '17', label: 'غ' },
  { id: '18', label: 'ف' },
  { id: '19', label: 'ق' },
  { id: '20', label: 'ك' },
  { id: '21', label: 'ل' },
  { id: '22', label: 'م' },
  { id: '23', label: 'ن' },
  { id: '24', label: 'ه' },
  { id: '25', label: 'و' },
  { id: '26', label: 'ي' },
];

var KIDS_ORDINAL = {
  الأول: 1,
  الاول: 1,
  الثاني: 2,
  الثالث: 3,
  الرابع: 4,
  الخامس: 5,
  السادس: 6,
  السابع: 7,
  الثامن: 8,
  التاسع: 9,
  العاشر: 10,
};

var KIDS_ORDINAL_RE =
  '(?:الأول|الاول|الثاني|الثالث|الرابع|الخامس|السادس|السابع|الثامن|التاسع|العاشر|\\d+)';

function kidsBase(cfg) {
  return String(cfg.origin || cfg.dimakids || KIDS_DEFAULTS.origin).replace(
    /\/$/,
    '',
  );
}

function kidsFiles(cfg) {
  return String(cfg.files || KIDS_DEFAULTS.files).replace(/\/$/, '');
}

function kidsHeaders(referer) {
  var h = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    Accept: 'application/json,text/html,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  if (referer) h.Referer = referer;
  return h;
}

function kidsHtml(ctx, raw) {
  if (!ctx || typeof ctx.html !== 'function') return null;
  try {
    return ctx.html(raw);
  } catch (e) {
    return null;
  }
}

function kidsStripZw(s) {
  return String(s || '')
    .replace(/[\u200b\u200c\u200d\ufeff]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function kidsAbs(base, href) {
  href = String(href || '').trim();
  if (!href) return '';
  if (/^https?:\/\//i.test(href)) return href.split('#')[0];
  if (href.charAt(0) === '/') return base + href.split('#')[0];
  return base + '/' + href.replace(/^\.\//, '').split('#')[0];
}

function kidsImg(cfg, src) {
  src = String(src || '').trim();
  if (!src) return '';
  if (/^https?:\/\//i.test(src)) return src;
  var files = kidsFiles(cfg);
  if (src.indexOf('images/') === 0 || src.indexOf('/images/') === 0) {
    return files + '/' + src.replace(/^\//, '');
  }
  return kidsAbs(kidsBase(cfg), src);
}

function kidsOrdinalValue(raw) {
  var t = kidsStripZw(raw).replace(/\s+/g, ' ');
  if (/^\d+$/.test(t)) return Number(t);
  if (KIDS_ORDINAL[t] != null) return KIDS_ORDINAL[t];
  return null;
}

function kidsSeriesTitle(name) {
  var t = kidsStripZw(name);
  var re = new RegExp(
    '\\s*(?:الموسم|الجزء)\\s+' + KIDS_ORDINAL_RE + '\\s*$',
  );
  return t.replace(re, '').trim() || t;
}

function kidsSeriesKey(name) {
  return kidsSeriesTitle(name).toLowerCase();
}

function kidsSeasonNumber(name) {
  var t = kidsStripZw(name);
  var re = new RegExp(
    '(?:الموسم|الجزء)\\s+(' + KIDS_ORDINAL_RE + ')\\s*$',
  );
  var m = re.exec(t);
  if (!m) return 1;
  return kidsOrdinalValue(m[1]) || 1;
}

function kidsSlugify(subtitle) {
  return kidsStripZw(subtitle).replace(/\s+/g, '-');
}

function kidsSeriesPageUrl(base, subtitle, id) {
  var slug = kidsSlugify(subtitle);
  if (slug) return base + '/' + slug + '-' + id + '-anime-streaming.html';
  return base + '/' + id + '-anime-streaming.html';
}

function kidsMoviePageUrl(base, id, subtitle) {
  // Search UI uses movie-{id}; slug form also works when known.
  if (subtitle) {
    var slug = kidsSlugify(subtitle);
    if (slug && slug.indexOf('movie-') !== 0) {
      return base + '/' + slug + '-' + id + '-movies-streaming.html';
    }
  }
  return base + '/movie-' + id + '-movies-streaming.html';
}

function kidsParseSeriesUrl(url) {
  var path = '';
  try {
    path = new URL(String(url || '')).pathname;
  } catch (e) {
    path = String(url || '');
  }
  var m = /\/([^/]+)-(\d+)-anime-streaming\.html$/i.exec(path);
  if (!m) return null;
  return { slug: m[1], id: m[2], url: String(url || '').split('#')[0] };
}

function kidsParseMovieUrl(url) {
  var path = '';
  try {
    path = new URL(String(url || '')).pathname;
  } catch (e) {
    path = String(url || '');
  }
  var m =
    /\/(?:movie-)?([^/]*?)-?(\d+)-movies-streaming\.html$/i.exec(path) ||
    /\/movie-(\d+)-movies-streaming\.html$/i.exec(path);
  if (!m) return null;
  if (m.length === 2) return { id: m[1], url: String(url || '').split('#')[0] };
  return { slug: m[1], id: m[2], url: String(url || '').split('#')[0] };
}

function kidsMeta(kind, opaqueId, title, poster, opts) {
  opts = opts || {};
  title = kidsStripZw(title);
  if (!title || !opaqueId) return null;
  var id = String(opaqueId);
  var url = String(opts.url || '');
  var seasonUrls = Array.isArray(opts.seasonUrls) ? opts.seasonUrls : [];
  var open = {
    surface: 'arabic',
    id: id,
    source: 'dimakids',
    extract: {
      resolveType: 'arabic',
      panelCategory: 'arabic',
      ctx: {
        videoId: url || id,
        source: 'dimakids',
      },
    },
  };
  if (url) open.url = url;
  if (seasonUrls.length) open.seasonUrls = seasonUrls;
  if (opts.movie) open.movie = true;
  var meta = {
    id: 'dimakids:' + id,
    type: 'arabic',
    name: title,
    poster: String(poster || ''),
    ids: { dimakids: id },
    open: open,
  };
  if (url) meta.ids.url = url;
  if (opts.description) meta.description = String(opts.description);
  if (opts.badge) meta.badge = String(opts.badge);
  return meta;
}

function kidsLetterFilter(value) {
  return { op: 'eq', field: 'letter', value: String(value) };
}

function kidsFilters() {
  return {
    menus: [
      {
        id: 'films',
        label: 'Films',
        filter: { op: 'eq', field: 'kind', value: 'movie' },
      },
      {
        id: 'series',
        label: 'Series',
        filter: { op: 'eq', field: 'kind', value: 'series' },
      },
    ],
    fields: [
      {
        field: 'letter',
        label: 'Letter',
        options: KIDS_LETTERS.map(function (L) {
          return {
            id: 'letter_' + L.id,
            label: L.label,
            filter: kidsLetterFilter(L.id),
          };
        }),
      },
    ],
  };
}

function kidsLayout() {
  return {
    pages: {
      kids: {
        feed: true,
        feedRails: KIDS_FEED_RAILS.slice(),
        pageSize: 24,
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'أحدث المسلسلات',
            rail: 'spotlight',
            bleed: 'latest',
          },
          { type: 'continue', id: 'continue_watching' },
          {
            type: 'rail',
            id: 'latest',
            title: 'مسلسلات جديدة',
            rail: 'latest',
            hideWhenBleed: true,
            aspect: 'portrait',
          },
          {
            type: 'rail',
            id: 'movies',
            title: 'أفلام جديدة',
            rail: 'movies',
            aspect: 'portrait',
          },
          {
            type: 'rail',
            id: 'episodes',
            title: 'الحلقات الجديدة',
            rail: 'episodes',
            aspect: 'portrait',
          },
        ],
      },
    },
  };
}

function kidsFetchText(ctx, url, referer) {
  return ctx.fetch(url, { headers: kidsHeaders(referer) }).then(function (res) {
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.text().then(function (body) {
      return { body: body, url: res.url || url };
    });
  });
}

function kidsFetchJson(ctx, url, referer) {
  return ctx.fetch(url, { headers: kidsHeaders(referer) }).then(function (res) {
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  });
}

function kidsPushRawSeries(out, seen, href, title, poster) {
  if (!href || !title || seen[href]) return;
  seen[href] = true;
  var ser = kidsParseSeriesUrl(href);
  out.push({
    id: ser ? ser.id : href,
    name: title,
    link: href,
    poster: poster,
    season: kidsSeasonNumber(title),
    seriesTitle: kidsSeriesTitle(title),
    seriesKey: kidsSeriesKey(title),
  });
}

function kidsParseCatalogCards(ctx, cfg, base, body, kind) {
  var out = [];
  var seen = {};
  var $ = kidsHtml(ctx, body);
  if ($) {
    var sel =
      kind === 'movie'
        ? 'a[href*="-movies-streaming.html"]'
        : 'a[href*="-anime-streaming.html"]';
    $(sel).each(function () {
      var a = $(this);
      var href = kidsAbs(base, a.attr('href') || '');
      if (!href || seen[href]) return;
      var title = kidsStripZw(
        a.attr('title') || a.find('img').attr('alt') || a.text() || '',
      );
      var poster = kidsImg(cfg, a.find('img').first().attr('src') || '');
      if (!title) return;
      if (kind === 'movie') {
        seen[href] = true;
        var mov = kidsParseMovieUrl(href);
        var mid = mov ? mov.id : href;
        var meta = kidsMeta('movie', 'movie:' + mid, title, poster, {
          url: href,
          movie: true,
        });
        if (meta) out.push(meta);
      } else {
        kidsPushRawSeries(out, seen, href, title, poster);
      }
    });
    return out;
  }
  var re =
    kind === 'movie'
      ? /href=["']([^"']+-movies-streaming\.html)["'][^>]*title=["']([^"']*)["'][\s\S]{0,800}?src=["']([^"']+)["']/gi
      : /href=["']([^"']+-anime-streaming\.html)["'][^>]*title=["']([^"']*)["'][\s\S]{0,800}?src=["']([^"']+)["']/gi;
  var m;
  while ((m = re.exec(String(body || '')))) {
    var href = kidsAbs(base, m[1]);
    var title = kidsStripZw(m[2]);
    var poster = kidsImg(cfg, m[3]);
    if (!href || !title || seen[href]) continue;
    if (kind === 'movie') {
      seen[href] = true;
      var mov2 = kidsParseMovieUrl(href);
      var mid2 = mov2 ? mov2.id : href;
      var meta2 = kidsMeta('movie', 'movie:' + mid2, title, poster, {
        url: href,
        movie: true,
      });
      if (meta2) out.push(meta2);
    } else {
      kidsPushRawSeries(out, seen, href, title, poster);
    }
  }
  return out;
}

function kidsGroupSeries(rawSeasons, opts) {
  opts = opts || {};
  var byKey = {};
  var order = [];
  for (var i = 0; i < (rawSeasons || []).length; i++) {
    var t = rawSeasons[i];
    if (!t || !t.seriesKey) continue;
    var g = byKey[t.seriesKey];
    if (!g) {
      g = {
        key: t.seriesKey,
        title: t.seriesTitle,
        seasons: [],
        maxId: 0,
      };
      byKey[t.seriesKey] = g;
      order.push(t.seriesKey);
    }
    g.seasons.push(t);
    var nid = Number(t.id) || 0;
    if (nid > g.maxId) g.maxId = nid;
  }
  var groups = [];
  for (var o = 0; o < order.length; o++) {
    var group = byKey[order[o]];
    group.seasons.sort(function (a, b) {
      return (a.season || 1) - (b.season || 1);
    });
    var posterTerm = group.seasons[0];
    for (var s = 0; s < group.seasons.length; s++) {
      if (Number(group.seasons[s].id) === group.maxId) {
        posterTerm = group.seasons[s];
        break;
      }
    }
    var seasonUrls = group.seasons.map(function (x) {
      return x.link;
    });
    var seasonCount = group.seasons.length;
    var badge = seasonCount > 1 ? seasonCount + ' مواسم' : '';
    var meta = kidsMeta(
      'series',
      'series:' + group.key,
      group.title,
      posterTerm.poster,
      {
        url: posterTerm.link,
        badge: badge,
        seasonUrls: seasonUrls,
      },
    );
    if (!meta) continue;
    meta._maxId = group.maxId;
    groups.push(meta);
  }
  groups.sort(function (a, b) {
    return (b._maxId || 0) - (a._maxId || 0);
  });
  for (var c = 0; c < groups.length; c++) delete groups[c]._maxId;
  return hubClampList(groups, opts.limit || 24);
}

function kidsParseHomepageEpisodes(ctx, cfg, base, body, limit) {
  var $ = kidsHtml(ctx, body);
  var out = [];
  var seen = {};
  function pushEp(href, title, poster) {
    if (out.length >= limit) return;
    if (!href || !title || seen[href]) return;
    var m = /\/([^/]+)-(\d+)-(\d+)\.html$/i.exec(href);
    if (!m) return;
    seen[href] = true;
    var seriesUrl = base + '/' + m[1] + '-' + m[2] + '-anime-streaming.html';
    var meta = kidsMeta(
      'series',
      'series:' + kidsSeriesKey(title),
      kidsSeriesTitle(title) || title,
      poster,
      {
        url: seriesUrl,
        seasonUrls: [seriesUrl],
        badge: 'حلقة جديدة',
      },
    );
    if (meta) out.push(meta);
  }
  if ($) {
    $('a[href*=".html"]').each(function () {
      var a = $(this);
      var href = kidsAbs(base, a.attr('href') || '');
      if (!/-(\d+)-(\d+)\.html$/i.test(href)) return;
      if (/anime-streaming|movies-streaming/i.test(href)) return;
      var img = a.find('img').first();
      pushEp(
        href,
        kidsStripZw(a.attr('title') || img.attr('alt') || a.text() || ''),
        kidsImg(cfg, img.attr('src') || ''),
      );
    });
  }
  return hubClampList(out, limit);
}

function kidsLoadSeriesList(ctx, cfg, base, opts) {
  opts = opts || {};
  var letter = String(opts.letter || '').trim();
  var path = letter !== '' ? letter + '-tri.html' : 'cartoon.php';
  return kidsFetchText(ctx, base + '/' + path, base + '/').then(function (got) {
    var raw = kidsParseCatalogCards(ctx, cfg, base, got.body, 'series');
    return kidsGroupSeries(raw, { limit: opts.limit || 24 });
  });
}

function kidsLoadMovies(ctx, cfg, base, limit) {
  return kidsFetchText(ctx, base + '/movies.php', base + '/').then(function (got) {
    return hubClampList(
      kidsParseCatalogCards(ctx, cfg, base, got.body, 'movie'),
      limit || 24,
    );
  });
}

function kidsLoadHome(ctx, cfg, base) {
  return kidsFetchText(ctx, base + '/index.php', base + '/').then(function (got) {
    return {
      body: got.body,
      series: kidsGroupSeries(
        kidsParseCatalogCards(ctx, cfg, base, got.body, 'series'),
        { limit: 40 },
      ),
      movies: hubClampList(
        kidsParseCatalogCards(ctx, cfg, base, got.body, 'movie'),
        24,
      ),
      episodes: kidsParseHomepageEpisodes(ctx, cfg, base, got.body, 24),
    };
  });
}

function kidsSearch(ctx, cfg, params) {
  var q = String(params.query || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  var base = kidsBase(cfg);
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 40;
  var url =
    base + '/search_results.php?q=' + encodeURIComponent(q) + '&ajax=1';
  return kidsFetchJson(ctx, url, base + '/')
    .then(function (data) {
      var out = [];
      var results = (data && data.results) || {};
      var series = results.series || [];
      var movies = results.movies || [];
      var rawSeasons = [];
      for (var i = 0; i < series.length; i++) {
        var s = series[i];
        if (!s || !s.id) continue;
        var title = kidsStripZw(s.title || '');
        var href = kidsSeriesPageUrl(base, s.subtitle || '', s.id);
        rawSeasons.push({
          id: s.id,
          name: title,
          link: href,
          poster: kidsImg(cfg, s.image || ''),
          season: kidsSeasonNumber(title),
          seriesTitle: kidsSeriesTitle(title),
          seriesKey: kidsSeriesKey(title),
        });
      }
      out = out.concat(kidsGroupSeries(rawSeasons, { limit: limit }));
      for (var m = 0; m < movies.length; m++) {
        var mv = movies[m];
        if (!mv || !mv.id) continue;
        var mtitle = kidsStripZw(mv.title || '');
        var murl = kidsMoviePageUrl(base, mv.id, mv.subtitle || '');
        var meta = kidsMeta('movie', 'movie:' + mv.id, mtitle, kidsImg(cfg, mv.image || ''), {
          url: murl,
          movie: true,
        });
        if (meta) out.push(meta);
      }
      return hubItems('search', hubClampList(out, limit), { maxAge: 300 });
    })
    .catch(function (e) {
      return hubFail('search', 'UPSTREAM', e && e.message, true);
    });
}

function kidsParseSeasonUrls(params) {
  var raw = params.seasonUrls;
  if (Array.isArray(raw) && raw.length) {
    return raw
      .map(function (x) {
        return String(x || '').trim();
      })
      .filter(Boolean);
  }
  if (typeof raw === 'string' && raw.trim()) {
    try {
      var parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return kidsParseSeasonUrls({ seasonUrls: parsed });
    } catch (e) {}
  }
  return [];
}

function kidsVideosFromSeriesPage(ctx, cfg, base, pageUrl, season) {
  return kidsFetchText(ctx, pageUrl, base + '/').then(function (got) {
    var $ = kidsHtml(ctx, got.body);
    var videos = [];
    var seen = {};
    if ($) {
      $('a[href*=".html"]').each(function () {
        var a = $(this);
        var href = kidsAbs(base, a.attr('href') || '');
        if (!/-(\d+)-(\d+)\.html$/i.test(href)) return;
        if (/anime-streaming|movies-streaming/i.test(href)) return;
        if (seen[href]) return;
        seen[href] = true;
        var item = a.find('.episode-item').first();
        var nEl = item.find('.episode-number').first();
        var tEl = item.find('.cinema-title').first();
        var n = nEl.length ? Number(kidsStripZw(nEl.text() || '')) : null;
        var title = kidsStripZw(
          tEl.text() || a.attr('title') || (n != null ? 'الحلقة ' + n : ''),
        );
        var thumb = kidsImg(cfg, a.find('img').attr('src') || '');
        if (!title) return;
        videos.push({
          id: 'dimakids:' + href,
          title: title,
          season: season || 1,
          episode: n != null && !isNaN(n) ? n : videos.length + 1,
          thumbnail: thumb,
        });
      });
    }
    videos.sort(function (a, b) {
      return (a.episode || 0) - (b.episode || 0);
    });
    return { url: got.url || pageUrl, videos: videos, body: got.body };
  });
}

function kidsPageTitle(body, fallback) {
  var m = /<title>([^<]+)<\/title>/i.exec(String(body || ''));
  if (!m) return kidsStripZw(fallback || '');
  var t = kidsStripZw(m[1].split('-')[0] || m[1]);
  return t || kidsStripZw(fallback || '');
}

function kidsPagePoster(cfg, body) {
  var raw = String(body || '');
  var m =
    /property=["']og:image["']\s+content=["']([^"']+)["']/i.exec(raw) ||
    /content=["']([^"']+)["']\s+property=["']og:image["']/i.exec(raw);
  if (m) return kidsImg(cfg, m[1]);
  m = /(https?:\/\/files\.dimakids\.com\/images\/anime\/(?:cat|film)_[^"'\s>]+\.jpg)/i.exec(
    raw,
  );
  return m ? m[1] : '';
}

function kidsDetails(ctx, cfg, params) {
  var base = kidsBase(cfg);
  var raw = String(params.id || '').trim();
  if (raw.indexOf('dimakids:') === 0) raw = raw.substring(9);
  var url = String(params.url || '').trim();
  var seasonUrls = kidsParseSeasonUrls(params);

  if (raw.indexOf('movie:') === 0 || params.movie === true || params.movie === 'true') {
    var mid = raw.indexOf('movie:') === 0 ? raw.substring(6) : raw;
    var murl = url || kidsMoviePageUrl(base, mid);
    return kidsFetchText(ctx, murl, base + '/').then(function (got) {
      var title = kidsPageTitle(got.body, mid);
      var poster = kidsPagePoster(cfg, got.body);
      var meta = kidsMeta('movie', 'movie:' + mid, title, poster, {
        url: got.url || murl,
        movie: true,
      });
      if (!meta) return hubFail('details', 'NOT_FOUND', 'movie ' + mid);
      meta.videos = [
        {
          id: 'dimakids:' + (got.url || murl),
          title: title,
          season: 1,
          episode: 1,
          thumbnail: poster,
        },
      ];
      return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
    });
  }

  if (!seasonUrls.length && url && /anime-streaming\.html/i.test(url)) {
    seasonUrls = [url];
  }
  if (!seasonUrls.length && url && /-\d+\.html$/i.test(url)) {
    // Recent-episode card: climb to series streaming page.
    var climbed = url.replace(/-\d+\.html(?:#.*)?$/i, '-anime-streaming.html');
    seasonUrls = [climbed];
  }
  if (!seasonUrls.length && raw.indexOf('series:') === 0) {
    // Search/browse without seasonUrls — try homepage+cartoon merge by key.
    var key = raw.substring(7);
    return kidsLoadSeriesList(ctx, cfg, base, { limit: 400 }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].open && list[i].open.id === 'series:' + key) {
          return kidsDetails(
            ctx,
            cfg,
            Object.assign({}, params, {
              id: list[i].open.id,
              url: list[i].open.url,
              seasonUrls: list[i].open.seasonUrls || [],
            }),
          );
        }
      }
      return hubFail('details', 'NOT_FOUND', 'series ' + key);
    });
  }
  if (!seasonUrls.length) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'kids details needs url'),
    );
  }

  return Promise.all(
    seasonUrls.map(function (u, idx) {
      return kidsVideosFromSeriesPage(ctx, cfg, base, u, idx + 1).then(
        function (part) {
          part.seasonUrl = u;
          return part;
        },
      );
    }),
  ).then(function (parts) {
    var videos = [];
    var poster = '';
    var title = '';
    var seasonCount = parts.length;
    for (var p = 0; p < parts.length; p++) {
      var part = parts[p];
      if (!title) title = kidsPageTitle(part.body, '');
      if (!poster) poster = kidsPagePoster(cfg, part.body);
      // Re-number season from page title when multi-season.
      var season = kidsSeasonNumber(kidsPageTitle(part.body, ''));
      for (var v = 0; v < (part.videos || []).length; v++) {
        var ep = part.videos[v];
        ep.season = seasonCount > 1 ? season : 1;
        videos.push(ep);
      }
    }
    videos.sort(function (a, b) {
      if ((a.season || 1) !== (b.season || 1)) {
        return (a.season || 1) - (b.season || 1);
      }
      return (a.episode || 0) - (b.episode || 0);
    });
    var seriesTitle = kidsSeriesTitle(title) || title || raw;
    var seriesKey =
      raw.indexOf('series:') === 0 ? raw.substring(7) : kidsSeriesKey(seriesTitle);
    var badge =
      videos.length > 0
        ? videos.length +
          ' حلقة' +
          (seasonCount > 1 ? ' · ' + seasonCount + ' مواسم' : '')
        : '';
    var meta = kidsMeta('series', 'series:' + seriesKey, seriesTitle, poster, {
      url: seasonUrls[0],
      badge: badge,
      seasonUrls: seasonUrls,
    });
    if (!meta) return hubFail('details', 'NOT_FOUND', 'series ' + seriesKey);
    meta.videos = videos;
    return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
  });
}

function kidsRail(ctx, cfg, params) {
  var base = kidsBase(cfg);
  var rail = String(params.rail || params.id || '').trim();
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  var kind = hubFilterValue(params.filter, 'kind');
  var letter = hubFilterValue(params.filter, 'letter');

  if (kind === 'movie') {
    if (rail === 'episodes') {
      return Promise.resolve(hubItems('rail', [], { maxAge: 600, swr: 3600 }));
    }
    return kidsLoadMovies(ctx, cfg, base, limit)
      .then(function (items) {
        return hubItems('rail', items, { maxAge: 600, swr: 3600 });
      })
      .catch(function (e) {
        return hubFail('rail', 'UPSTREAM', e && e.message, true);
      });
  }

  if (rail === 'movies') {
    if (kind === 'series') {
      return Promise.resolve(hubItems('rail', [], { maxAge: 600, swr: 3600 }));
    }
    return kidsLoadMovies(ctx, cfg, base, limit)
      .then(function (items) {
        return hubItems('rail', items, { maxAge: 600, swr: 3600 });
      })
      .catch(function (e) {
        return hubFail('rail', 'UPSTREAM', e && e.message, true);
      });
  }

  if (rail === 'episodes') {
    if (letter) {
      return Promise.resolve(hubItems('rail', [], { maxAge: 600, swr: 3600 }));
    }
    return kidsLoadHome(ctx, cfg, base)
      .then(function (home) {
        return hubItems(
          'rail',
          hubClampList(home.episodes || [], limit),
          { maxAge: 600, swr: 3600 },
        );
      })
      .catch(function (e) {
        return hubFail('rail', 'UPSTREAM', e && e.message, true);
      });
  }

  if (rail === 'spotlight' || rail === 'latest') {
    return kidsLoadSeriesList(ctx, cfg, base, {
      letter: letter,
      limit: limit,
    })
      .then(function (items) {
        return hubItems('rail', items, { maxAge: 600, swr: 3600 });
      })
      .catch(function (e) {
        return hubFail('rail', 'UPSTREAM', e && e.message, true);
      });
  }

  return Promise.resolve(
    hubFail('rail', 'INVALID_PARAMS', 'unknown rail ' + rail),
  );
}

function kidsFeed(ctx, cfg, params) {
  var base = kidsBase(cfg);
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  var kind = hubFilterValue(params.filter, 'kind');
  var letter = hubFilterValue(params.filter, 'letter');

  if (kind === 'movie') {
    return kidsLoadMovies(ctx, cfg, base, limit).then(function (movies) {
      return hubOk(
        'feed',
        {
          rails: {
            spotlight: movies,
            latest: [],
            movies: movies,
            episodes: [],
          },
        },
        { maxAge: 600, swr: 3600 },
      );
    });
  }

  return Promise.all([
    kidsLoadSeriesList(ctx, cfg, base, { letter: letter, limit: limit }),
    letter
      ? Promise.resolve([])
      : kidsLoadMovies(ctx, cfg, base, limit).catch(function () {
          return [];
        }),
    letter
      ? Promise.resolve([])
      : kidsLoadHome(ctx, cfg, base)
          .then(function (h) {
            return h.episodes || [];
          })
          .catch(function () {
            return [];
          }),
  ]).then(function (parts) {
    var series = parts[0] || [];
    var movies = kind === 'series' ? [] : parts[1] || [];
    var episodes = kind === 'series' ? [] : parts[2] || [];
    return hubOk(
      'feed',
      {
        rails: {
          spotlight: series.slice(0, limit),
          latest: series.slice(0, limit),
          movies: movies.slice(0, limit),
          episodes: episodes.slice(0, limit),
        },
      },
      { maxAge: 600, swr: 3600 },
    );
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, KIDS_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', kidsLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'filters') {
    return hubOk('filters', kidsFilters(), { maxAge: 86400 });
  }
  if (action === 'feed') {
    return kidsFeed(ctx, cfg, params).catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'rail') {
    return kidsRail(ctx, cfg, params);
  }
  if (action === 'search') {
    return kidsSearch(ctx, cfg, params);
  }
  if (action === 'details') {
    return kidsDetails(ctx, cfg, params).catch(function (e) {
      return hubFail('details', 'UPSTREAM', e && e.message, true);
    });
  }
  return hubFail(action || 'unknown', 'UNSUPPORTED', 'unsupported action');
}
