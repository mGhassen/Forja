// Shahid hub — catalog via api2.shahid.net.
// Playback: provider `shahid`. Host surface: shahid → KitDetails.
// Note: product/filter returns 400 on current API; browse uses top-ranking + related.

var SHAHID_UA =
  'Shahid/6.8.3.3660 CFNetwork/1220.1 Darwin/20.3.0 (iPhone/6s iOS/14.4) Safari/604.1';
var SHAHID_PROXY = 'https://api2.shahid.net/proxy';
var SHAHID_AES_KEY = 'gx8KSZyPdfJhXes7';
var SHAHID_GUEST_PROFILE = JSON.stringify({
  id: '00000000-0000-0000-0000-000000000000',
  ageRestriction: false,
  master: true,
});
var SHAHID_PROFILE_KEY = JSON.stringify({
  isAdult: true,
  ageRestriction: false,
});

var SHAHID_DEFAULTS = { language: 'ar' };

var SHAHID_RAILS = {
  top_series: {
    label: 'الأكثر مشاهدة · مسلسلات',
    kind: 'top',
    bucket: 'series',
  },
  top_movies: {
    label: 'الأكثر مشاهدة · أفلام',
    kind: 'top',
    bucket: 'movie',
  },
  more_series: {
    label: 'المزيد من المسلسلات',
    kind: 'related',
    bucket: 'series',
  },
  more_movies: {
    label: 'المزيد من الأفلام',
    kind: 'related',
    bucket: 'movie',
  },
};

var SHAHID_FEED_RAILS = [
  'top_series',
  'top_movies',
  'more_series',
  'more_movies',
];

var _shahidJwt = '';
var _shahidSessionId = '';
var _shahidCountry = '';

function shahidHeaders(sessionId, jwt, language) {
  var h = {
    'User-Agent': SHAHID_UA,
    'Shahid-Agent': SHAHID_UA,
    UUID: 'ios',
    language: String(language || 'ar').toUpperCase(),
    Accept: 'application/json',
    'shahid_os': 'WEB',
    profile: SHAHID_GUEST_PROFILE,
    'profile-key': SHAHID_PROFILE_KEY,
  };
  if (jwt) h['S-Session'] = jwt;
  if (sessionId) h.Token = sessionId;
  return h;
}

function apiQs(requestObj, country) {
  return (
    'request=' +
    encodeURIComponent(JSON.stringify(requestObj || {})) +
    '&country=' +
    encodeURIComponent(country || 'SA')
  );
}

function productsFromList(list) {
  if (!list) return [];
  if (Array.isArray(list)) return list;
  if (Array.isArray(list.products)) return list.products;
  return [];
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
      if (j && j.country) _shahidCountry = String(j.country);
      return _shahidJwt;
    })
    .catch(function () {
      return '';
    });
}

function sessionCountry(auth) {
  return _shahidCountry || (auth && auth.country) || 'SA';
}

function ensureAuth(ctx, cfg) {
  var cachedSession = String(cfg.sessionId || _shahidSessionId || '').trim();
  var cachedJwt = String(cfg.jwt || _shahidJwt || '').trim();
  if (cachedSession) _shahidSessionId = cachedSession;
  if (cachedJwt) _shahidJwt = cachedJwt;

  return getJwt(ctx).then(function (jwt) {
    var useJwt = cachedJwt || jwt || '';
    if (_shahidSessionId) {
      return { jwt: useJwt, sessionId: _shahidSessionId };
    }
    var email = String(cfg.email || '').trim();
    var password = String(cfg.password || '').trim();
    if (!email || !password) return { jwt: useJwt, sessionId: '' };
    var enc = encryptPassword(ctx, password);
    if (!enc) return { jwt: useJwt, sessionId: '' };
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/usersservice/validateLogin', {
        method: 'POST',
        headers: Object.assign(shahidHeaders('', useJwt, cfg.language), {
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
        return { jwt: useJwt, sessionId: _shahidSessionId };
      })
      .catch(function () {
        return { jwt: useJwt, sessionId: '' };
      });
  });
}

function authStatus(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var sessionId = String(cfg.sessionId || _shahidSessionId || '').trim();
  var label = String(cfg.email || cfg.label || '').trim();
  return hubOk('auth_status', {
    connected: !!sessionId,
    label: label || undefined,
  });
}

function authBegin() {
  // System browser + forja:// session handoff (bookmarklet). Already logged-in OK.
  return hubOk('auth_begin', {
    flow: 'browser',
    url: 'https://shahid.mbc.net/en',
    title: 'Sign in to Shahid',
    hint:
      'Opens Shahid in your browser. Already signed in is fine — Copy connect script, paste in that tab’s console (⌘⌥J), Enter.',
    methods: [
      {
        id: 'email',
        label: 'Email + password',
        fields: [
          { id: 'email', type: 'text', label: 'Email' },
          { id: 'password', type: 'password', label: 'Password' },
        ],
      },
      {
        id: 'phone',
        label: 'Phone + password',
        fields: [
          { id: 'phone', type: 'phone', label: 'Phone' },
          { id: 'password', type: 'password', label: 'Password' },
        ],
      },
    ],
  });
}

function authLoginFromSession(ctx, sessionId, labelHint) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  return getJwt(ctx).then(function (jwt) {
    var hdrs = Object.assign(shahidHeaders(sessionId, jwt, cfg.language), {
      Token: sessionId,
    });
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/usersservice', {
        method: 'GET',
        headers: hdrs,
      })
      .then(function (res) {
        return res.json().then(function (j) {
          if (!res.ok) {
            var msg =
              (j && j.message) ||
              (j && j.faults && j.faults[0] && j.faults[0].userMessage) ||
              'Session invalid';
            throw new Error(String(msg));
          }
          return j;
        });
      })
      .then(function (j) {
        var user = (j && j.user) || j || {};
        var sid = String(user.sessionId || sessionId || '').trim();
        if (!sid) {
          return hubFail('auth_login', 'AUTH_REQUIRED', 'no session returned');
        }
        _shahidSessionId = sid;
        _shahidJwt = jwt || '';
        var label = String(
          user.email ||
            user.userName ||
            user.communicationEmail ||
            labelHint ||
            '',
        ).trim();
        return hubOk('auth_login', {
          connected: true,
          label: label || 'Shahid',
          secrets: {
            sessionId: sid,
            jwt: jwt || '',
            email: String(user.email || '').trim(),
          },
        });
      })
      .catch(function () {
        // Profile GET can 401 on some regions; cookie token is still the session.
        if (sessionId.length < 8) {
          return hubFail('auth_login', 'AUTH_REQUIRED', 'Session invalid');
        }
        _shahidSessionId = sessionId;
        _shahidJwt = jwt || '';
        return hubOk('auth_login', {
          connected: true,
          label: labelHint || 'Shahid',
          secrets: {
            sessionId: sessionId,
            jwt: jwt || '',
          },
        });
      });
  });
}

function authLogin(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var params = hubParams(ctx);
  var fields = params.fields || {};
  var method = String(params.method || 'email');
  if (method === 'browser') {
    var sessionId = String(
      fields.sessionId || fields.token || '',
    ).trim();
    if (!sessionId) {
      return Promise.resolve(
        hubFail('auth_login', 'AUTH_REQUIRED', 'session token required'),
      );
    }
    return authLoginFromSession(
      ctx,
      sessionId,
      String(fields.label || fields.email || '').trim(),
    );
  }
  var email = String(fields.email || '').trim();
  var phone = String(fields.phone || '').trim();
  var password = String(fields.password || '').trim();
  var loginId = method === 'phone' ? phone : email;
  if (!loginId || !password) {
    return Promise.resolve(
      hubFail('auth_login', 'AUTH_REQUIRED', 'email/phone and password required'),
    );
  }
  return getJwt(ctx).then(function (jwt) {
    var enc = encryptPassword(ctx, password);
    if (!enc) {
      return hubFail('auth_login', 'UPSTREAM', 'crypto unavailable');
    }
    var body = {
      password: enc,
      deviceType: 'Mobile',
      physicalDeviceType: 'IOS',
      isNewUser: false,
      captchaToken: 'c2hhaGlkLWF1dGgta2V5LXRva2Vu',
    };
    if (method === 'phone') body.phoneNumber = phone;
    else body.email = email;
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/usersservice/validateLogin', {
        method: 'POST',
        headers: Object.assign(shahidHeaders('', jwt, cfg.language), {
          'Content-Type': 'application/json',
          UUID: 'web',
        }),
        body: JSON.stringify(body),
      })
      .then(function (res) {
        return res.json().then(function (j) {
          if (!res.ok) {
            var msg =
              (j && j.message) ||
              (j && j.faults && j.faults[0] && j.faults[0].userMessage) ||
              'Login failed';
            throw new Error(String(msg));
          }
          return j;
        });
      })
      .then(function (j) {
        var user = (j && j.user) || {};
        var sessionId = String(user.sessionId || '').trim();
        if (!sessionId) {
          return hubFail('auth_login', 'AUTH_REQUIRED', 'no session returned');
        }
        _shahidSessionId = sessionId;
        _shahidJwt = jwt || '';
        var label =
          String(user.email || user.userName || email || phone || '').trim();
        return hubOk('auth_login', {
          connected: true,
          label: label,
          secrets: {
            sessionId: sessionId,
            jwt: jwt || '',
            email: email || '',
            phone: phone || '',
          },
        });
      })
      .catch(function (e) {
        return hubFail(
          'auth_login',
          'AUTH_REQUIRED',
          (e && e.message) || String(e),
        );
      });
  });
}

function authLogout() {
  _shahidSessionId = '';
  _shahidJwt = '';
  return hubOk('auth_logout', { connected: false });
}

function formatImg(url, kind) {
  url = String(url || '');
  if (!url) return '';
  // Title logos: CDN default JPEG bakes a black matte; forced 3:1 crops
  // clip calligraphy. Original canvas + type=png keeps alpha.
  if (kind === 'logo') {
    var base = url.split('?')[0];
    if (base.indexOf('/mediaObject') < 0) {
      base = base.replace('mediaObject', '/mediaObject');
    }
    return base + '?type=png';
  }
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

function metaOpen(id, productType) {
  return {
    surface: 'shahid',
    id: String(id),
    extract: {
      resolveType: 'shahid',
      panelCategory: 'shahid',
      ctx: {
        videoId: String(id),
        productType: String(productType || 'SHOW'),
      },
    },
  };
}

function productToMeta(item) {
  if (!item || !item.id) return null;
  var id = String(item.id);
  var productType = String(
    item.productType || item.type || item.showType || 'SHOW',
  ).toUpperCase();
  var isMovie = productType === 'MOVIE';
  var img = item.image || {};
  var title = item.title || '';
  var poster = formatImg(img.posterImage || img.thumbnailImage || '', 'poster');
  var bg = formatImg(
    img.thumbnailImage || img.posterImage || item.mainImage || '',
    'background',
  );
  var logo = formatImg(item.logoTitleImage || '', 'logo');
  return {
    id: 'shahid:' + id,
    type: isMovie ? 'movie' : 'series',
    name: title,
    title: title,
    description: item.description || '',
    poster: poster,
    background: bg,
    logo: logo,
    open: metaOpen(id, isMovie ? 'MOVIE' : 'SHOW'),
  };
}

function mapProducts(list) {
  var items = [];
  var raw = productsFromList(list);
  for (var i = 0; i < raw.length; i++) {
    var m = productToMeta(raw[i]);
    if (m) items.push(m);
  }
  return items;
}

function fetchTopRanking(ctx, cfg, pageSize) {
  return ensureAuth(ctx, cfg).then(function (auth) {
    var country = sessionCountry(auth);
    var size = pageSize || 20;
    return ctx
      .fetch(
        SHAHID_PROXY +
          '/v2.1/product/top-ranking-by-type?' +
          apiQs({ productType: 'SERIES', country: country, pageSize: size }, country),
        { headers: shahidHeaders(auth.sessionId, auth.jwt, cfg.language) },
      )
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (j) {
        var top = (j && j.top) || {};
        return {
          series: mapProducts((top.series || {}).products),
          movies: mapProducts((top.movie || {}).products),
        };
      });
  });
}

function fetchRelated(ctx, cfg, seedId, productType, pageSize) {
  if (!seedId) return Promise.resolve({ items: [], hasMore: false });
  return ensureAuth(ctx, cfg).then(function (auth) {
    var country = sessionCountry(auth);
    return ctx
      .fetch(
        SHAHID_PROXY +
          '/v2.1/product/related?' +
          apiQs(
            {
              id: Number(seedId) || seedId,
              productType: productType || 'SHOW',
              pageNumber: 0,
              pageSize: pageSize || 30,
            },
            country,
          ),
        { headers: shahidHeaders(auth.sessionId, auth.jwt, cfg.language) },
      )
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (j) {
        var list = (j && j.productList) || [];
        return {
          items: mapProducts(list),
          hasMore: !!(list && list.hasMore),
        };
      });
  });
}

function fetchRailItems(ctx, cfg, railId) {
  var def = SHAHID_RAILS[railId];
  if (!def) return Promise.resolve({ items: [], hasMore: false });
  return fetchTopRanking(ctx, cfg, 30).then(function (top) {
    if (def.kind === 'top') {
      var items = def.bucket === 'movie' ? top.movies : top.series;
      return { items: items, hasMore: false };
    }
    var seedList = def.bucket === 'movie' ? top.movies : top.series;
    var seed = seedList && seedList[0];
    var seedId = seed && seed.open ? String(seed.open.id) : '';
    var pType = def.bucket === 'movie' ? 'MOVIE' : 'SHOW';
    return fetchRelated(ctx, cfg, seedId, pType, 30);
  });
}

function layout() {
  var widgets = [
    {
      type: 'hero',
      id: 'spotlight',
      title: 'Shahid',
      rail: 'top_series',
      bleed: 'top_movies',
    },
  ];
  for (var i = 0; i < SHAHID_FEED_RAILS.length; i++) {
    var id = SHAHID_FEED_RAILS[i];
    var def = SHAHID_RAILS[id];
    if (!def) continue;
    widgets.push({
      type: 'rail',
      id: id,
      title: def.label,
      rail: id,
      hideWhenBleed: id === 'top_series',
    });
  }
  return hubOk(
    'layout',
    {
      pages: {
        shahid: {
          feed: true,
          feedRails: SHAHID_FEED_RAILS.slice(),
          pageSize: 20,
          widgets: widgets,
        },
      },
    },
    { maxAge: 3600, swr: 86400 },
  );
}

function feed(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  return fetchTopRanking(ctx, cfg, 20).then(function (top) {
    var seriesSeed =
      top.series && top.series[0]
        ? String(top.series[0].open.id)
        : '';
    var movieSeed =
      top.movies && top.movies[0]
        ? String(top.movies[0].open.id)
        : '';
    return Promise.all([
      fetchRelated(ctx, cfg, seriesSeed, 'SHOW', 20),
      fetchRelated(ctx, cfg, movieSeed, 'MOVIE', 20),
    ]).then(function (more) {
      // KitShell expects rails[id] = MetaItem[], not { items: [...] }.
      return hubOk('feed', {
        rails: {
          top_series: top.series || [],
          top_movies: top.movies || [],
          more_series: (more[0] && more[0].items) || [],
          more_movies: (more[1] && more[1].items) || [],
        },
      });
    });
  });
}

function rail(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var params = hubParams(ctx);
  var railId = String(params.rail || params.railId || params.id || '');
  if (!SHAHID_RAILS[railId]) return Promise.resolve(hubItems('rail', []));
  return fetchRailItems(ctx, cfg, railId).then(function (r) {
    return hubItems('rail', r.items, null, {
      pageSize: 30,
      hasMore: r.hasMore,
    });
  });
}

function searchTab(ctx, auth, country, language, tab, q) {
  var body = {
    name: q,
    pageNumber: 0,
    pageSize: 30,
  };
  return ctx
    .fetch(
      SHAHID_PROXY +
        '/v2.1/search/' +
        tab +
        '?' +
        apiQs(body, country),
      { headers: shahidHeaders(auth.sessionId, auth.jwt, language) },
    )
    .then(function (res) {
      if (!res.ok) return [];
      return res.json().then(function (j) {
        return mapProducts((j && j.productList) || []);
      });
    })
    .catch(function () {
      return [];
    });
}

function search(ctx) {
  var cfg = hubConfig(ctx, SHAHID_DEFAULTS);
  var params = hubParams(ctx);
  var q = String(params.query || params.q || '').trim();
  if (!q) return Promise.resolve(hubItems('search', []));
  return ensureAuth(ctx, cfg).then(function (auth) {
    var country = sessionCountry(auth);
    return Promise.all([
      searchTab(ctx, auth, country, cfg.language, 'TV_SHOWS', q),
      searchTab(ctx, auth, country, cfg.language, 'MOVIES', q),
    ]).then(function (parts) {
      var seen = {};
      var items = [];
      for (var p = 0; p < parts.length; p++) {
        var list = parts[p] || [];
        for (var i = 0; i < list.length; i++) {
          var m = list[i];
          if (!m || seen[m.id]) continue;
          seen[m.id] = true;
          items.push(m);
        }
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
    var country = sessionCountry(auth);
    var showReq = apiQs({ showId: Number(id) || id }, country);
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/playableAsset?' + showReq, {
        headers: hdrs,
      })
      .then(function (res) {
        if (res.ok) return res.json();
        return ctx
          .fetch(
            SHAHID_PROXY +
              '/v2.1/product/id?' +
              apiQs({ id: Number(id) || id }, country),
            { headers: hdrs },
          )
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
          name: title,
          title: title,
          description: description,
          poster: formatImg(img.posterImage || '', 'poster'),
          background: formatImg(
            img.thumbnailImage ||
              img.posterImage ||
              show.mainImage ||
              model.mainImage ||
              '',
            'background',
          ),
          logo: formatImg(
            show.logoTitleImage || model.logoTitleImage || '',
            'logo',
          ),
          open: metaOpen(id, playlist.id ? 'SHOW' : 'MOVIE'),
          videos: [],
        };

        if (!playlist.id) {
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

        return ctx
          .fetch(
            SHAHID_PROXY +
              '/v2.1/product/playlist?' +
              apiQs(
                {
                  playListId: playlist.id,
                  pageNumber: 0,
                  pageSize: 100,
                  sorts: [{ order: 'ASC', type: 'SORTDATE' }],
                },
                country,
              ),
            { headers: hdrs },
          )
          .then(function (res) {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
          })
          .then(function (pj) {
            var products = productsFromList((pj && pj.productList) || []);
            var videos = [];
            for (var i = 0; i < products.length; i++) {
              var p = products[i];
              if (!p || !p.id) continue;
              videos.push({
                id: 'shahid:' + p.id,
                title:
                  p.title ||
                  p.episodeTitle ||
                  'Episode ' +
                    (Number(p.number || p.episodeNumber) || i + 1),
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
  if (action === 'auth_status') return Promise.resolve(authStatus(ctx));
  if (action === 'auth_begin') return Promise.resolve(authBegin());
  if (action === 'auth_login') return authLogin(ctx);
  if (action === 'auth_logout') return Promise.resolve(authLogout());
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
