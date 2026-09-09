// Shahid hub — catalog via api2.shahid.net (Kodi/yt-dlp shape).
// Playback: provider `shahid`. Host surface: shahid → KitDetails.

var SHAHID_UA =
  'Shahid/6.8.3.3660 CFNetwork/1220.1 Darwin/20.3.0 (iPhone/6s iOS/14.4) Safari/604.1';
var SHAHID_PROXY = 'https://api2.shahid.net/proxy';
var SHAHID_AES_KEY = 'gx8KSZyPdfJhXes7';

var SHAHID_DEFAULTS = { language: 'ar' };

var SHAHID_RAILS = {
  series_drama: {
    label: 'مسلسلات · دراما',
    productType: 'SERIES',
    genreId: 7876,
  },
  series_comedy: {
    label: 'مسلسلات · كوميديا',
    productType: 'SERIES',
    genreId: 7858,
  },
  series_ramadan: {
    label: 'رمضان',
    productType: 'SERIES',
    genreId: 10354,
  },
  movies_action: {
    label: 'أفلام · أكشن',
    productType: 'MOVIE',
    genreId: 7935,
  },
  movies_drama: {
    label: 'أفلام · دراما',
    productType: 'MOVIE',
    genreId: 7876,
  },
  movies_comedy: {
    label: 'أفلام · كوميديا',
    productType: 'MOVIE',
    genreId: 7858,
  },
};

var SHAHID_FEED_RAILS = [
  'series_drama',
  'series_comedy',
  'movies_action',
  'movies_drama',
  'movies_comedy',
];

var _shahidJwt = '';
var _shahidSessionId = '';

function shahidHeaders(sessionId, jwt, language) {
  var h = {
    'User-Agent': SHAHID_UA,
    'Shahid-Agent': SHAHID_UA,
    UUID: 'ios',
    language: language || 'ar',
  };
  if (jwt) h['S-Session'] = jwt;
  if (sessionId) h.Token = sessionId;
  return h;
}

function encryptPassword(ctx, password) {
  var C = ctx.crypto || globalThis.CryptoJS;
  if (!C || !C.AES) return '';
  var key = C.enc.Utf8.parse(SHAHID_AES_KEY);
  var padded = password;
  var bs = 16;
  var pad = bs - (padded.length % bs);
  for (var i = 0; i < pad; i++) padded += String.fromCharCode(pad);
  var encrypted = C.AES.encrypt(C.enc.Utf8.parse(padded), key, {
    mode: C.mode.ECB,
    padding: C.pad.NoPadding,
  });
  return C.enc.Base64.stringify(encrypted.ciphertext);
}

function getJwt(ctx) {
  if (_shahidJwt) return Promise.resolve(_shahidJwt);
  return ctx
    .fetch(SHAHID_PROXY + '/v2/session/ios', {
      method: 'POST',
      headers: shahidHeaders('', '', 'ar'),
      body: '{}',
    })
    .then(function (res) {
      return res.json();
    })
    .then(function (j) {
      _shahidJwt = (j && j.jwt) || '';
      return _shahidJwt;
    })
    .catch(function () {
      return '';
    });
}

function ensureAuth(ctx, cfg) {
  var email = String(cfg.email || '').trim();
  var password = String(cfg.password || '').trim();
  return getJwt(ctx).then(function (jwt) {
    if (!email || !password) return { jwt: jwt, sessionId: _shahidSessionId };
    if (_shahidSessionId) return { jwt: jwt, sessionId: _shahidSessionId };
    var enc = encryptPassword(ctx, password);
    if (!enc) return { jwt: jwt, sessionId: '' };
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/usersservice/validateLogin', {
        method: 'POST',
        headers: Object.assign(shahidHeaders('', jwt, cfg.language), {
          'Content-Type': 'application/json',
          UUID: 'web',
        }),
        body: JSON.stringify({
          email: email,
          password: enc,
          deviceType: 'Mobile',
          physicalDeviceType: 'IOS',
          isNewUser: false,
          captchaToken: 'c2hhaGlkLWF1dGgta2V5LXRva2Vu',
        }),
      })
      .then(function (res) {
        return res.json();
      })
      .then(function (j) {
        _shahidSessionId = ((j && j.user) || {}).sessionId || '';
        return { jwt: jwt, sessionId: _shahidSessionId };
      })
      .catch(function () {
        return { jwt: jwt, sessionId: '' };
      });
  });
}

function formatImg(url, kind) {
  url = String(url || '');
  if (!url) return '';
  var h = 450;
  var w = 300;
  if (kind === 'fanart' || kind === 'background') {
    h = 1080;
    w = 1920;
  } else if (kind === 'thumb') {
    h = 180;
    w = 320;
  }
  try {
    url = url
      .replace(/\{height\}/g, String(h))
      .replace(/\{width\}/g, String(w))
      .replace(/\{croppingPoint\}/g, 'mc');
  } catch (e) {}
  if (url.indexOf('/mediaObject') < 0) {
    url = url.replace('mediaObject', '/mediaObject');
  }
  return url;
}

function productFilterQuery(opts) {
  var filter = {
    pageNumber: String(opts.page || 0),
    pageSize: opts.pageSize || 30,
    productType: opts.productType || 'SERIES',
    sorts: [{ order: 'DESC', type: 'SORTDATE' }],
  };
  if (opts.genreId) filter.genres = [opts.genreId];
  return 'filter=' + encodeURIComponent(JSON.stringify(filter));
}

function metaOpen(id, productType) {
  return {
    surface: 'shahid',
    id: String(id),
    extract: {
      resolveType: 'shahid',
      panelCategory: 'shahid',
      ctx: {
        videoId: String(id),
        productType: String(productType || 'SERIES'),
      },
    },
  };
}

function productToMeta(item) {
  if (!item || !item.id) return null;
  var id = String(item.id);
  var productType = String(item.productType || item.type || 'SERIES').toUpperCase();
  var isMovie = productType === 'MOVIE';
  var img = item.image || {};
  var poster = formatImg(img.posterImage || img.thumbnailImage || '', 'poster');
  var bg = formatImg(
    img.thumbnailImage || img.posterImage || '',
    'background',
  );
  return {
    id: 'shahid:' + id,
    type: isMovie ? 'movie' : 'series',
    title: item.title || '',
    description: item.description || '',
    poster: poster,
    background: bg,
    open: metaOpen(id, productType),
  };
}

function fetchProducts(ctx, cfg, opts) {
  return ensureAuth(ctx, cfg).then(function (auth) {
    var q = productFilterQuery(opts);
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/product/filter?' + q, {
        headers: shahidHeaders(auth.sessionId, auth.jwt, cfg.language),
      })
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (j) {
        var list = ((j && j.productList) || {}).products || [];
        var items = [];
        for (var i = 0; i < list.length; i++) {
          var m = productToMeta(list[i]);
          if (m) items.push(m);
        }
        return {
          items: items,
          hasMore: !!(j && j.productList && j.productList.hasMore),
        };
      });
  });
}

function layout() {
  var rails = [];
  for (var i = 0; i < SHAHID_FEED_RAILS.length; i++) {
    var id = SHAHID_FEED_RAILS[i];
    var def = SHAHID_RAILS[id];
    if (!def) continue;
    rails.push({
      id: id,
      title: def.label,
      kind: 'poster',
    });
  }
  return hubOk('layout', {
    hero: { kind: 'none' },
    rails: rails,
  });
}

function feed(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var jobs = SHAHID_FEED_RAILS.map(function (railId) {
    var def = SHAHID_RAILS[railId];
    return fetchProducts(ctx, cfg, {
      productType: def.productType,
      genreId: def.genreId,
      page: 0,
      pageSize: 20,
    }).then(function (r) {
      return { id: railId, items: r.items };
    });
  });
  return Promise.all(jobs).then(function (rows) {
    var rails = {};
    for (var i = 0; i < rows.length; i++) {
      rails[rows[i].id] = { items: rows[i].items };
    }
    return hubOk('feed', { rails: rails });
  });
}

function rail(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var params = hubParams(ctx);
  var railId = String(params.railId || params.id || '');
  var def = SHAHID_RAILS[railId];
  if (!def) return Promise.resolve(hubItems('rail', []));
  var page = Number(params.page || 0) || 0;
  return fetchProducts(ctx, cfg, {
    productType: def.productType,
    genreId: def.genreId,
    page: page,
    pageSize: 30,
  }).then(function (r) {
    return hubItems('rail', r.items, null, {
      pageSize: 30,
      hasMore: r.hasMore,
    });
  });
}

function search(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var params = hubParams(ctx);
  var q = String(params.query || params.q || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  return ensureAuth(ctx, cfg).then(function (auth) {
    var body = {
      query: q,
      pageNumber: 0,
      pageSize: 30,
    };
    return ctx
      .fetch(
        SHAHID_PROXY +
          '/v2.1/search/grid?request=' +
          encodeURIComponent(JSON.stringify(body)),
        { headers: shahidHeaders(auth.sessionId, auth.jwt, cfg.language) },
      )
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (j) {
        var products =
          (j && j.productList && j.productList.products) ||
          (j && j.products) ||
          [];
        var items = [];
        for (var i = 0; i < products.length; i++) {
          var m = productToMeta(products[i]);
          if (m) items.push(m);
        }
        return hubItems('search', items);
      });
  });
}

function filters() {
  var options = [];
  var keys = Object.keys(SHAHID_RAILS);
  for (var i = 0; i < keys.length; i++) {
    var id = keys[i];
    var def = SHAHID_RAILS[id];
    options.push({
      id: id,
      label: def.label,
      filter: {
        op: 'eq',
        field: 'rail',
        value: id,
      },
    });
  }
  return hubOk('filters', { categories: options });
}

function details(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var params = hubParams(ctx);
  var id = String(params.id || '')
    .replace(/^shahid:/, '')
    .trim();
  if (!id) return Promise.resolve(hubFail('details', 'BAD_REQUEST', 'missing id'));

  return ensureAuth(ctx, cfg).then(function (auth) {
    var hdrs = shahidHeaders(auth.sessionId, auth.jwt, cfg.language);
    // Try playableAsset for series; product/id for movies.
    var showReq =
      'request=' +
      encodeURIComponent(JSON.stringify({ showId: id }));
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/playableAsset?' + showReq, {
        headers: hdrs,
      })
      .then(function (res) {
        if (res.ok) return res.json();
        var prodReq =
          'request=' +
          encodeURIComponent(
            JSON.stringify({
              id: id,
              productType: 'ASSET',
              productSubType: 'MOVIE',
            }),
          );
        return ctx
          .fetch(SHAHID_PROXY + '/v2/product/id?' + prodReq, {
            headers: hdrs,
          })
          .then(function (r2) {
            if (!r2.ok) throw new Error('HTTP ' + r2.status);
            return r2.json();
          });
      })
      .then(function (j) {
        var model = (j && j.productModel) || j || {};
        var show = model.show || model;
        var playlist = model.playlist || {};
        var title = show.title || model.title || '';
        var description = show.description || model.description || '';
        var img = show.image || model.image || {};
        var meta = {
          id: 'shahid:' + id,
          type: playlist.id ? 'series' : 'movie',
          title: title,
          description: description,
          poster: formatImg(img.posterImage || '', 'poster'),
          background: formatImg(
            img.thumbnailImage || img.posterImage || '',
            'background',
          ),
          open: metaOpen(id, playlist.id ? 'SERIES' : 'MOVIE'),
          videos: [],
        };

        if (!playlist.id) {
          // Movie / single asset — one playable video.
          meta.videos = [
            {
              id: 'shahid:' + id,
              title: title || 'Play',
              season: 0,
              episode: 1,
            },
          ];
          return hubOk('details', { meta: meta });
        }

        var plReq =
          'request=' +
          encodeURIComponent(
            JSON.stringify({
              playListId: playlist.id,
              pageNumber: 0,
              pageSize: 100,
              sorts: [{ order: 'ASC', type: 'SORTDATE' }],
            }),
          );
        return ctx
          .fetch(SHAHID_PROXY + '/v2.1/product/playlist?' + plReq, {
            headers: hdrs,
          })
          .then(function (res) {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
          })
          .then(function (pj) {
            var products =
              ((pj && pj.productList) || {}).products || [];
            var videos = [];
            for (var i = 0; i < products.length; i++) {
              var p = products[i];
              if (!p || !p.id) continue;
              videos.push({
                id: 'shahid:' + p.id,
                title: p.title || 'Episode ' + (i + 1),
                season: Number(p.seasonNumber) || 1,
                episode: Number(p.number || p.episodeNumber) || i + 1,
                thumbnail: formatImg(
                  (p.image && (p.image.thumbnailImage || p.image.posterImage)) ||
                    '',
                  'thumb',
                ),
              });
            }
            meta.videos = videos;
            return hubOk('details', { meta: meta });
          });
      });
  });
}

function handle(ctx) {
  var action = hubAction(ctx);
  if (action === 'layout') return Promise.resolve(layout());
  if (action === 'feed') return feed(ctx);
  if (action === 'rail') return rail(ctx);
  if (action === 'search') return search(ctx);
  if (action === 'filters') return Promise.resolve(filters());
  if (action === 'details') return details(ctx);
  return Promise.resolve(
    hubFail(action, 'UNSUPPORTED', 'unsupported action'),
  );
}

function extract(ctx) {
  return handle(ctx).catch(function (e) {
    return hubFail(
      hubAction(ctx),
      'UPSTREAM',
      (e && e.message) || String(e),
      true,
    );
  });
}
