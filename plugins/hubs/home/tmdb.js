// TMDB movie / TV hub — layout / rail / search / details (protocol 1).
//
// Needs a v3 key. The host injects `TMDB_API_KEY` from dart-define at
// runCatalog time (R70-A14). Pack config stays empty.

var TMDB_DEFAULTS = {
  base: 'https://api.themoviedb.org/3',
  imageBase: 'https://image.tmdb.org/t/p',
  apiKey: '',
  language: 'en-US',
  region: '',
};

var TMDB_RAILS = {
  spotlight: { path: '/trending/all/day', type: '' },
  featured: { special: 'featured' },
  popular: { special: 'popular' },
  new_releases: { special: 'new_releases' },
  discover: { special: 'discover' },
};

// Same moods as the pre-CatalogShell Home hub (icons + dual movie/tv genres).
var TMDB_MOODS = [
  { id: 'mind', label: 'Mind-Bending', icon: 'psychology', accent: '#8B5CF6', movieGenres: [878, 9648], tvGenres: [10765, 9648] },
  { id: 'feel', label: 'Feel-Good', icon: 'wb_sunny', accent: '#FBBF24', movieGenres: [35, 10751], tvGenres: [35, 10751] },
  { id: 'dark', label: 'Dark Thrillers', icon: 'dark_mode', accent: '#64748B', movieGenres: [53, 80], tvGenres: [80, 9648] },
  { id: 'romance', label: 'Romance', icon: 'favorite', accent: '#EC4899', movieGenres: [10749], tvGenres: [18] },
  { id: 'horror', label: 'Horror', icon: 'bedtime', accent: '#7C3AED', movieGenres: [27], tvGenres: [10765, 9648] },
  { id: 'action', label: 'Action', icon: 'local_fire_department', accent: '#F97316', movieGenres: [28, 12], tvGenres: [10759] },
  { id: 'animated', label: 'Animated', icon: 'brush', accent: '#06B6D4', movieGenres: [16], tvGenres: [16] },
  { id: 'drama', label: 'Drama', icon: 'theaters', accent: '#3B82F6', movieGenres: [18], tvGenres: [18] },
];

function tmdbLayout() {
  return {
    pages: {
      home: {
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'Spotlight',
            rail: 'spotlight',
            bleed: 'featured',
          },
          {
            type: 'rail',
            id: 'featured',
            title: 'Featured This Month',
            rail: 'featured',
            hideWhenBleed: true,
          },
          { type: 'ranked', id: 'popular', title: 'Popular', rail: 'popular', style: 'numbered' },
          { type: 'host.continue', id: 'continue_watching' },
          {
            type: 'mood',
            id: 'moods',
            title: "What's your mood?",
            options: TMDB_MOODS,
            rail: 'discover',
          },
          { type: 'host.because', id: 'because' },
          { type: 'host.trakt', id: 'trakt' },
          {
            type: 'rail',
            id: 'new_releases',
            title: 'New Releases',
            rail: 'new_releases',
          },
          { type: 'host.genre_rows', id: 'genre_rows' },
        ],
      },
    },
  };
}

function tmdbImage(cfg, path, size) {
  var p = String(path || '').trim();
  if (!p) return '';
  if (/^https?:\/\//i.test(p)) return p;
  return String(cfg.imageBase).replace(/\/$/, '') + '/' + size + p;
}

function tmdbMeta(cfg, row, forcedType) {
  if (!row || !row.id) return null;
  var type = String(forcedType || row.media_type || '').trim();
  if (type !== 'movie' && type !== 'tv') {
    type = row.title ? 'movie' : 'tv';
  }
  var name = String(row.title || row.name || '').trim();
  if (!name) return null;
  var release = String(row.release_date || row.first_air_date || '').trim();
  var meta = {
    id: 'tmdb:' + type + ':' + row.id,
    type: type,
    name: name,
    poster: tmdbImage(cfg, row.poster_path, 'w500'),
    background: tmdbImage(cfg, row.backdrop_path, 'w1280'),
    description: String(row.overview || '').trim(),
    releaseInfo: release ? release.substring(0, 4) : '',
    ids: { tmdb: String(row.id) },
    open: { surface: 'tmdb', id: String(row.id), mediaType: type },
  };
  if (row.vote_average) meta.rating = Number(row.vote_average);
  return meta;
}

function tmdbGet(ctx, cfg, path, query) {
  var url = String(cfg.base).replace(/\/$/, '') + path;
  var sep = url.indexOf('?') >= 0 ? '&' : '?';
  var qs = ['api_key=' + encodeURIComponent(cfg.apiKey)];
  if (cfg.language) qs.push('language=' + encodeURIComponent(cfg.language));
  if (cfg.region) qs.push('region=' + encodeURIComponent(cfg.region));
  var extra = query || {};
  for (var k in extra) {
    if (!Object.prototype.hasOwnProperty.call(extra, k)) continue;
    var v = extra[k];
    if (v === null || v === undefined || v === '') continue;
    qs.push(encodeURIComponent(k) + '=' + encodeURIComponent(String(v)));
  }
  return ctx
    .fetch(url + sep + qs.join('&'), {
      headers: { Accept: 'application/json' },
    })
    .then(function (res) {
      if (res.status === 401) throw new Error('TMDB_UNAUTHORIZED');
      if (!res.ok) throw new Error('tmdb HTTP ' + res.status);
      return res.json();
    });
}

function tmdbMonthWindow() {
  var now = new Date();
  var y = now.getFullYear();
  var m = now.getMonth() + 1;
  var pad = function (n) {
    return (n < 10 ? '0' : '') + n;
  };
  var last = new Date(y, m, 0).getDate();
  return {
    gte: y + '-' + pad(m) + '-01',
    lte: y + '-' + pad(m) + '-' + pad(last),
  };
}

function tmdbMergeLists(cfg, movieJson, tvJson, limit) {
  var movies = tmdbMetas(cfg, movieJson, 'movie', limit);
  var shows = tmdbMetas(cfg, tvJson, 'tv', limit);
  var merged = movies.concat(shows);
  merged.sort(function (a, b) {
    return (Number(b.rating) || 0) - (Number(a.rating) || 0);
  });
  return hubClampList(merged, limit);
}

function tmdbList(ctx, cfg, params) {
  var railId = String(params.rail || 'spotlight');
  var genres = hubFilterValues(params.filter, 'genre');
  var typeFilter = hubFilterValue(params.filter, 'type');
  if (typeFilter !== 'movie' && typeFilter !== 'tv') typeFilter = '';
  var page = Number(params.page) > 0 ? Number(params.page) : 1;
  var limit = params.limit;

  // Mood discover — movie genres from selected mood option (host merges tv).
  if (railId === 'discover' || genres.length) {
    var moodId = hubFilterValue(params.filter, 'mood');
    var movieGenres = genres.slice();
    var tvGenres = genres.slice();
    if (moodId) {
      for (var i = 0; i < TMDB_MOODS.length; i++) {
        if (TMDB_MOODS[i].id === moodId) {
          movieGenres = TMDB_MOODS[i].movieGenres.map(String);
          tvGenres = TMDB_MOODS[i].tvGenres.map(String);
          break;
        }
      }
    }
    var mediaType = typeFilter || 'movie';
    var g = mediaType === 'tv' ? tvGenres : movieGenres;
    if (!g.length && genres.length) g = genres;
    return tmdbGet(ctx, cfg, '/discover/' + mediaType, {
      sort_by: String(params.sort || 'popularity.desc'),
      with_genres: g.join(','),
      page: page,
      include_adult: 'false',
      'vote_count.gte': 50,
    }).then(function (json) {
      return tmdbMetas(cfg, json, mediaType, limit);
    });
  }

  if (railId === 'featured') {
    var win = tmdbMonthWindow();
    return Promise.all([
      typeFilter === 'tv'
        ? Promise.resolve({ results: [] })
        : tmdbGet(ctx, cfg, '/discover/movie', {
            'primary_release_date.gte': win.gte,
            'primary_release_date.lte': win.lte,
            sort_by: 'popularity.desc',
            'vote_average.gte': 6,
            page: page,
            include_adult: 'false',
          }),
      typeFilter === 'movie'
        ? Promise.resolve({ results: [] })
        : tmdbGet(ctx, cfg, '/discover/tv', {
            'first_air_date.gte': win.gte,
            'first_air_date.lte': win.lte,
            sort_by: 'popularity.desc',
            'vote_average.gte': 6,
            page: page,
            include_adult: 'false',
          }),
    ]).then(function (pair) {
      return tmdbMergeLists(cfg, pair[0], pair[1], limit);
    });
  }

  if (railId === 'popular') {
    return Promise.all([
      typeFilter === 'tv'
        ? Promise.resolve({ results: [] })
        : tmdbGet(ctx, cfg, '/movie/popular', { page: page }),
      typeFilter === 'movie'
        ? Promise.resolve({ results: [] })
        : tmdbGet(ctx, cfg, '/tv/popular', { page: page }),
    ]).then(function (pair) {
      return tmdbMergeLists(cfg, pair[0], pair[1], limit);
    });
  }

  if (railId === 'new_releases') {
    return Promise.all([
      typeFilter === 'tv'
        ? Promise.resolve({ results: [] })
        : tmdbGet(ctx, cfg, '/movie/now_playing', { page: page }),
      typeFilter === 'movie'
        ? Promise.resolve({ results: [] })
        : tmdbGet(ctx, cfg, '/tv/on_the_air', { page: page }),
    ]).then(function (pair) {
      return tmdbMergeLists(cfg, pair[0], pair[1], limit);
    });
  }

  if (typeFilter) {
    return tmdbGet(ctx, cfg, '/trending/' + typeFilter + '/day', {
      page: page,
    }).then(function (json) {
      return tmdbMetas(cfg, json, typeFilter, limit);
    });
  }

  var spec = TMDB_RAILS[railId];
  if (!spec || !spec.path) {
    return Promise.reject(new Error('unknown rail ' + railId));
  }
  return tmdbGet(ctx, cfg, spec.path, { page: page }).then(function (json) {
    return tmdbMetas(cfg, json, spec.type, limit);
  });
}

function tmdbMetas(cfg, json, forcedType, limit) {
  var rows = hubClampList(json && json.results, limit);
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    if (row && row.media_type === 'person') continue;
    var meta = tmdbMeta(cfg, row, forcedType);
    if (meta) out.push(meta);
  }
  return out;
}

function tmdbDetails(ctx, cfg, params) {
  var raw = String(params.id || '').split(':');
  var id = Number(raw.pop());
  var type = raw.length ? raw.pop() : 'movie';
  if (!id) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'details needs params.id'),
    );
  }
  if (type !== 'movie' && type !== 'tv') type = 'movie';
  return tmdbGet(ctx, cfg, '/' + type + '/' + id, {}).then(function (json) {
    var meta = tmdbMeta(cfg, json, type);
    if (!meta) return hubFail('details', 'NOT_FOUND', type + ' ' + id);
    return hubOk('details', { meta: meta }, { maxAge: 3600, swr: 86400 });
  });
}

function tmdbAuthFailure(action) {
  return hubFail(
    action,
    'AUTH_REQUIRED',
    'TMDB API key missing — set apiKey in the Home hub config',
    false,
  );
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, TMDB_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', tmdbLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'filters') {
    return hubOk('filters', {
      fields: [{ field: 'genre', label: 'Genre', options: TMDB_MOODS }],
    }, { maxAge: 86400 });
  }
  if (!String(cfg.apiKey || '').trim()) {
    return tmdbAuthFailure(action);
  }

  function wrap(promise) {
    return promise.catch(function (e) {
      var msg = (e && e.message) || 'tmdb failed';
      if (msg === 'TMDB_UNAUTHORIZED') return tmdbAuthFailure(action)[0];
      return hubFail(action, 'UPSTREAM', msg, true)[0];
    }).then(function (v) {
      return Array.isArray(v) ? v : [v];
    });
  }

  if (action === 'details') {
    return wrap(tmdbDetails(ctx, cfg, params).then(function (env) {
      return env[0];
    }));
  }
  if (action === 'search') {
    var q = String(params.query || '').trim();
    if (!q) return hubItems('search', []);
    return wrap(
      tmdbGet(ctx, cfg, '/search/multi', {
        query: q,
        page: Number(params.page) > 0 ? Number(params.page) : 1,
        include_adult: 'false',
      })
        .then(function (json) {
          return tmdbMetas(cfg, json, '', params.limit);
        })
        .then(function (items) {
          return hubItems('search', items, { maxAge: 300 })[0];
        }),
    );
  }
  if (action !== 'rail') {
    return hubFail(action, 'INVALID_ACTION', 'tmdb has no action ' + action);
  }
  return wrap(
    tmdbList(ctx, cfg, params).then(function (items) {
      return hubItems('rail', items, { maxAge: 900, swr: 3600 })[0];
    }),
  );
}
