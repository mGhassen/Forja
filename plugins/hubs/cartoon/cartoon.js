// كرتون hub — DimaToon (dima-toon.com) via WP REST + site ajax.
// Playback: Forja provider `dimatoon` (types: arabic). Host surface: arabic.

var CARTOON_DEFAULTS = {
  origin: 'https://www.dima-toon.com',
};

var CARTOON_FEED_RAILS = ['spotlight', 'latest', 'popular', 'episodes'];

function cartoonBase(cfg) {
  return String(cfg.origin || cfg.dimatoon || CARTOON_DEFAULTS.origin).replace(
    /\/$/,
    '',
  );
}

function cartoonHeaders(referer) {
  var h = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    Accept: 'application/json,text/html,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  if (referer) h.Referer = referer;
  return h;
}

function cartoonHtml(ctx, raw) {
  if (!ctx || typeof ctx.html !== 'function') return null;
  try {
    return ctx.html(raw);
  } catch (e) {
    return null;
  }
}

function cartoonPosterFromDescription(desc) {
  var m = /src=["']([^"']+)["']/i.exec(String(desc || ''));
  return m ? m[1] : '';
}

function cartoonStripZw(s) {
  return String(s || '')
    .replace(/[\u200b\u200c\u200d\ufeff]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function cartoonEpNumber(title) {
  var t = cartoonStripZw(title);
  var m = /الحلقة\s*(\d+)/.exec(t) || /\b(\d{1,4})\s*$/.exec(t);
  return m ? Number(m[1]) : null;
}

function cartoonMeta(termId, title, poster, opts) {
  opts = opts || {};
  title = cartoonStripZw(title);
  if (!title || !termId) return null;
  var id = String(termId);
  var url = String(opts.url || '');
  var open = {
    surface: 'arabic',
    id: id,
    source: 'dimatoon',
    extract: {
      resolveType: 'arabic',
      panelCategory: 'arabic',
      ctx: {
        videoId: url || id,
        source: 'dimatoon',
      },
    },
  };
  if (url) open.url = url;
  var meta = {
    id: 'dimatoon:' + id,
    type: 'arabic',
    name: title,
    poster: String(poster || ''),
    ids: { dimatoon: id },
    open: open,
  };
  if (url) meta.ids.url = url;
  if (opts.description) meta.description = String(opts.description);
  if (opts.badge) meta.badge = String(opts.badge);
  return meta;
}

function cartoonLayout() {
  return {
    pages: {
      cartoon: {
        feed: true,
        feedRails: CARTOON_FEED_RAILS.slice(),
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
            title: 'أضيف حديثًا',
            rail: 'latest',
            hideWhenBleed: true,
            aspect: 'portrait',
          },
          {
            type: 'ranked',
            id: 'popular',
            title: 'الأكثر حلقات',
            rail: 'popular',
            aspect: 'portrait',
          },
          {
            type: 'rail',
            id: 'episodes',
            title: 'أحدث الحلقات',
            rail: 'episodes',
            aspect: 'portrait',
          },
        ],
      },
    },
  };
}

function cartoonFetchJson(ctx, url, referer) {
  return ctx.fetch(url, { headers: cartoonHeaders(referer) }).then(function (res) {
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json().then(function (data) {
      var totalPages = 1;
      try {
        var h =
          res.headers && typeof res.headers.get === 'function'
            ? res.headers.get('X-WP-TotalPages')
            : null;
        if (h) totalPages = Math.max(1, Number(h) || 1);
      } catch (e) {}
      return { data: data, totalPages: totalPages, url: res.url || url };
    });
  });
}

function cartoonTermToMeta(term) {
  if (!term || !term.id) return null;
  var poster = cartoonPosterFromDescription(term.description);
  var desc = String(term.description || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (desc.length > 280) desc = desc.substring(0, 277) + '…';
  var count = Number(term.count) || 0;
  return cartoonMeta(term.id, term.name, poster, {
    url: term.link || '',
    description: desc,
    badge: count > 0 ? count + ' حلقة' : '',
  });
}

function cartoonListTerms(ctx, base, opts) {
  opts = opts || {};
  var page = Number(opts.page) > 0 ? Number(opts.page) : 1;
  var limit = Number(opts.limit) > 0 ? Number(opts.limit) : 24;
  var orderby = opts.orderby || 'id';
  var order = opts.order || 'desc';
  var q = String(opts.search || '').trim();
  var url =
    base +
    '/wp-json/wp/v2/cartoon?per_page=' +
    encodeURIComponent(String(limit)) +
    '&page=' +
    encodeURIComponent(String(page)) +
    '&orderby=' +
    encodeURIComponent(orderby) +
    '&order=' +
    encodeURIComponent(order) +
    '&_fields=id,name,link,description,count';
  if (q) url += '&search=' + encodeURIComponent(q);
  return cartoonFetchJson(ctx, url, base + '/').then(function (got) {
    var rows = Array.isArray(got.data) ? got.data : [];
    var out = [];
    for (var i = 0; i < rows.length; i++) {
      var meta = cartoonTermToMeta(rows[i]);
      if (meta) out.push(meta);
    }
    return out;
  });
}

function cartoonFetchEpisodesPage(ctx, base, cartoonId, page) {
  var url =
    base +
    '/wp-json/wp/v2/cartoon-episode?cartoon=' +
    encodeURIComponent(String(cartoonId)) +
    '&per_page=100&page=' +
    encodeURIComponent(String(page)) +
    '&orderby=date&order=asc&_fields=id,title,link,featured_media,date';
  return cartoonFetchJson(ctx, url, base + '/');
}

function cartoonFetchAllEpisodes(ctx, base, cartoonId) {
  function page(n, acc) {
    return cartoonFetchEpisodesPage(ctx, base, cartoonId, n).then(function (got) {
      var rows = Array.isArray(got.data) ? got.data : [];
      var next = acc.concat(rows);
      if (n < got.totalPages && rows.length) return page(n + 1, next);
      if (rows.length === 100) return page(n + 1, next);
      return next;
    });
  }
  return page(1, []);
}

function cartoonRecentEpisodeMetas(ctx, base, limit) {
  var url =
    base +
    '/wp-json/wp/v2/cartoon-episode?per_page=' +
    encodeURIComponent(String(limit)) +
    '&orderby=date&order=desc&_fields=id,title,link,featured_media,cartoon';
  return cartoonFetchJson(ctx, url, base + '/')
    .then(function (got) {
      var rows = Array.isArray(got.data) ? got.data : [];
      var termIds = [];
      var seen = {};
      for (var i = 0; i < rows.length; i++) {
        var cartoons = rows[i].cartoon || [];
        var tid = cartoons[0];
        if (!tid || seen[tid]) continue;
        seen[tid] = true;
        termIds.push(tid);
      }
      if (!termIds.length) return [];
      return Promise.all(
        termIds.slice(0, limit).map(function (id) {
          return cartoonFetchJson(
            ctx,
            base +
              '/wp-json/wp/v2/cartoon/' +
              encodeURIComponent(String(id)) +
              '?_fields=id,name,link,description,count',
            base + '/',
          )
            .then(function (t) {
              return cartoonTermToMeta(t.data);
            })
            .catch(function () {
              return null;
            });
        }),
      ).then(function (metas) {
        return metas.filter(Boolean);
      });
    })
    .catch(function () {
      return [];
    });
}

function cartoonSearchAjax(ctx, base, query, limit) {
  return ctx
    .fetch(base + '/wp-admin/admin-ajax.php', {
      method: 'POST',
      headers: Object.assign(cartoonHeaders(base + '/'), {
        'Content-Type': 'application/x-www-form-urlencoded',
      }),
      body: 'action=cartoon_search_action&term=' + encodeURIComponent(query),
    })
    .then(function (res) {
      if (!res.ok) return [];
      return res.text();
    })
    .then(function (body) {
      var $ = cartoonHtml(ctx, body);
      var out = [];
      var seen = {};
      if ($) {
        $('.search-result-item').each(function () {
          var item = $(this);
          var a = item.find('a[href]').first();
          var img = item.find('img').first();
          if (!a.length) return;
          var href = a.attr('href') || '';
          var title = cartoonStripZw(a.text() || '');
          var poster = img.length ? img.attr('src') || '' : '';
          if (!title || !href || seen[href]) return;
          seen[href] = true;
          // Prefer stable WP term id when link ends with /cartoon/slug/
          var meta = cartoonMeta(href, title, poster, { url: href });
          if (meta) out.push(meta);
        });
      }
      return hubClampList(out, limit);
    })
    .catch(function () {
      return [];
    });
}

function cartoonRail(ctx, cfg, params) {
  var base = cartoonBase(cfg);
  var rail = String(params.rail || params.id || '').trim();
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  var page = Number(params.page) > 0 ? Number(params.page) : 1;
  var p;
  if (rail === 'spotlight' || rail === 'latest') {
    p = cartoonListTerms(ctx, base, {
      page: page,
      limit: limit,
      orderby: 'id',
      order: 'desc',
    });
  } else if (rail === 'popular') {
    p = cartoonListTerms(ctx, base, {
      page: page,
      limit: limit,
      orderby: 'count',
      order: 'desc',
    });
  } else if (rail === 'episodes') {
    p = cartoonRecentEpisodeMetas(ctx, base, limit);
  } else {
    return Promise.resolve(
      hubFail('rail', 'INVALID_PARAMS', 'unknown rail ' + rail),
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

function cartoonFeed(ctx, cfg, params) {
  var base = cartoonBase(cfg);
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 24;
  var jobs = [
    cartoonListTerms(ctx, base, {
      page: 1,
      limit: limit,
      orderby: 'id',
      order: 'desc',
    }).then(function (items) {
      return { rail: 'spotlight', items: items };
    }),
    cartoonListTerms(ctx, base, {
      page: 1,
      limit: limit,
      orderby: 'id',
      order: 'desc',
    }).then(function (items) {
      return { rail: 'latest', items: items };
    }),
    cartoonListTerms(ctx, base, {
      page: 1,
      limit: limit,
      orderby: 'count',
      order: 'desc',
    }).then(function (items) {
      return { rail: 'popular', items: items };
    }),
    cartoonRecentEpisodeMetas(ctx, base, limit).then(function (items) {
      return { rail: 'episodes', items: items };
    }),
  ];
  return Promise.all(
    jobs.map(function (j) {
      return j.catch(function () {
        return null;
      });
    }),
  ).then(function (rows) {
    var rails = {};
    for (var i = 0; i < rows.length; i++) {
      if (!rows[i]) continue;
      rails[rows[i].rail] = rows[i].items || [];
    }
    return hubOk('feed', { rails: rails }, { maxAge: 600, swr: 3600 });
  });
}

function cartoonSearch(ctx, cfg, params) {
  var q = String(params.query || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  var base = cartoonBase(cfg);
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 40;
  return Promise.all([
    cartoonSearchAjax(ctx, base, q, limit).catch(function () {
      return [];
    }),
    cartoonListTerms(ctx, base, {
      page: 1,
      limit: limit,
      orderby: 'count',
      order: 'desc',
      search: q,
    }).catch(function () {
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
        // Also dedupe by show URL when ajax used URL as id
        var urlKey = (it.ids && it.ids.url) || '';
        if (urlKey && seen[urlKey]) continue;
        seen[it.id] = true;
        if (urlKey) seen[urlKey] = true;
        out.push(it);
      }
    }
    return hubItems('search', hubClampList(out, limit), { maxAge: 300 });
  });
}

function cartoonResolveShowId(ctx, base, params) {
  var raw = String(params.id || '').trim();
  if (raw.indexOf('dimatoon:') === 0) raw = raw.substring(9);
  var url = String(params.url || '').trim();
  if (/^\d+$/.test(raw)) {
    return Promise.resolve({ id: raw, url: url });
  }
  // URL-as-id from ajax search — resolve term via link slug or fetch HTML.
  var showUrl = url || raw;
  if (!/^https?:\/\//i.test(showUrl)) {
    return Promise.resolve({ id: '', url: showUrl });
  }
  var slug = '';
  try {
    var u = new URL(showUrl);
    var parts = u.pathname.split('/').filter(Boolean);
    if (parts[0] === 'cartoon' && parts[1]) {
      try {
        slug = decodeURIComponent(parts[1]);
      } catch (e) {
        slug = parts[1];
      }
    }
  } catch (e) {}
  if (!slug) return Promise.resolve({ id: '', url: showUrl });
  var api =
    base +
    '/wp-json/wp/v2/cartoon?slug=' +
    encodeURIComponent(slug) +
    '&_fields=id,name,link,description,count';
  return cartoonFetchJson(ctx, api, base + '/')
    .then(function (got) {
      var rows = Array.isArray(got.data) ? got.data : [];
      if (!rows.length) return { id: '', url: showUrl };
      return {
        id: String(rows[0].id),
        url: rows[0].link || showUrl,
        term: rows[0],
      };
    })
    .catch(function () {
      return { id: '', url: showUrl };
    });
}

function cartoonDetails(ctx, cfg, params) {
  var base = cartoonBase(cfg);
  return cartoonResolveShowId(ctx, base, params).then(function (ref) {
    if (!ref.id) {
      return hubFail('details', 'INVALID_PARAMS', 'cartoon details needs id');
    }
    var termP = ref.term
      ? Promise.resolve(ref.term)
      : cartoonFetchJson(
          ctx,
          base +
            '/wp-json/wp/v2/cartoon/' +
            encodeURIComponent(ref.id) +
            '?_fields=id,name,link,description,count',
          base + '/',
        ).then(function (got) {
          return got.data;
        });
    return Promise.all([
      termP,
      cartoonFetchAllEpisodes(ctx, base, ref.id),
    ]).then(function (pair) {
      var term = pair[0];
      var eps = pair[1] || [];
      var meta = cartoonTermToMeta(term);
      if (!meta) {
        return hubFail('details', 'NOT_FOUND', 'cartoon ' + ref.id);
      }
      meta.id = 'dimatoon:' + ref.id;
      var videos = [];
      for (var i = 0; i < eps.length; i++) {
        var ep = eps[i];
        var title = cartoonStripZw(
          (ep.title && ep.title.rendered) || ep.title || '',
        );
        var href = ep.link || '';
        if (!href || !title) continue;
        var n = cartoonEpNumber(title);
        videos.push({
          id: 'dimatoon:' + href,
          title: title,
          season: 1,
          episode: n != null ? n : i + 1,
          thumbnail: '',
        });
      }
      videos.sort(function (a, b) {
        return (a.episode || 0) - (b.episode || 0);
      });
      for (var j = 0; j < videos.length; j++) {
        if (!videos[j].episode) videos[j].episode = j + 1;
      }
      meta.videos = videos;
      if (ref.url) {
        meta.open.url = ref.url;
        meta.ids.url = ref.url;
      }
      return hubOk('details', { meta: meta }, { maxAge: 900, swr: 3600 });
    });
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, CARTOON_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', cartoonLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'feed') {
    return cartoonFeed(ctx, cfg, params).catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'rail') {
    return cartoonRail(ctx, cfg, params);
  }
  if (action === 'search') {
    return cartoonSearch(ctx, cfg, params).catch(function (e) {
      return hubFail('search', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'details') {
    return cartoonDetails(ctx, cfg, params).catch(function (e) {
      return hubFail('details', 'UPSTREAM', e && e.message, true);
    });
  }
  return hubFail(action || 'unknown', 'UNSUPPORTED', 'unsupported action');
}
