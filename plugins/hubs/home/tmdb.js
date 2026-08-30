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

// Pack-owned logos under plugins/hubs/home/logos — vertical_filters widget.
var TMDB_VERTICAL_FILTERS = [
  { id: 'netflix', label: 'Netflix', logo: 'logos/netflix.svg', tileColor: '#000000', inset: 0.16, filter: { field: 'watch_provider', value: 8 } },
  { id: 'disney', label: 'Disney+', logo: 'logos/disneyplus.svg', tileColor: '#FFFFFF', inset: 0.12, filter: { field: 'watch_provider', value: 337 } },
  { id: 'prime', label: 'Prime Video', logo: 'logos/primevideo.svg', tileColor: '#000000', inset: 0.14, filter: { field: 'watch_provider', value: 9 } },
  { id: 'apple', label: 'Apple TV+', logo: 'logos/appletv.svg', tileColor: '#000000', inset: 0.2, filter: { field: 'watch_provider', value: 350 } },
  { id: 'max', label: 'Max', logo: 'logos/max.svg', tileColor: '#002BE7', inset: 0.18, forceWhiteLogo: true, filter: { field: 'watch_provider', value: 1899 } },
  { id: 'hulu', label: 'Hulu', logo: 'logos/hulu.svg', tileColor: '#000000', inset: 0.2, filter: { field: 'watch_provider', value: 15 } },
  { id: 'paramount', label: 'Paramount+', logo: 'logos/paramountplus.svg', tileColor: '#0064FF', inset: 0.14, forceWhiteLogo: true, filter: { field: 'watch_provider', value: 2303 } },
  { id: 'peacock', label: 'Peacock', logo: 'logos/peacock.svg', tileColor: '#FFFFFF', inset: 0.14, filter: { field: 'watch_provider', value: 386 } },
  { id: 'crunchyroll', label: 'Crunchyroll', logo: 'logos/crunchyroll.svg', tileColor: '#000000', inset: 0.16, filter: { field: 'watch_provider', value: 283 } },
  { id: 'tubi', label: 'Tubi', logo: 'logos/tubi.svg', tileColor: '#4B0082', inset: 0.18, filter: { field: 'watch_provider', value: 73 } },
];

var TMDB_WATCH_FAMILIES = {
  8: [8, 1796, 175],
  337: [337, 122, 619],
  9: [9, 119],
  350: [350],
  1899: [1899, 384, 118, 27, 425, 616, 483],
  15: [15],
  2303: [2303, 531, 1770],
  386: [386, 387],
  283: [283],
  73: [73],
};

// TV originals often land on with_networks before watch-provider tags exist.
var TMDB_TV_NETWORK_FAMILIES = {
  8: [213],
  337: [2739],
  9: [1024],
  350: [2552],
  1899: [49, 6783, 8304],
  15: [453],
  2303: [4330],
  386: [3353],
  283: [1112],
};

var TMDB_HOME_RAIL_CAP = 20;
var TMDB_HOME_HERO_CAP = 5;
var TMDB_HOME_FETCH_PAGES = 2;

// Visual priority for pack feed claim (spotlight → featured → popular → new).
var TMDB_FEED_CLAIM = [
  { id: 'spotlight', cap: TMDB_HOME_HERO_CAP, mode: 'exclusive' },
  { id: 'featured', cap: TMDB_HOME_RAIL_CAP, mode: 'exclusive' },
  { id: 'popular', cap: TMDB_HOME_RAIL_CAP, mode: 'exclusive' },
  { id: 'new_releases', cap: TMDB_HOME_RAIL_CAP, mode: 'exclusive' },
];

function tmdbWatchProviderQuery(filter) {
  var chip = hubFilterValue(filter, 'watch_provider');
  if (!chip) return '';
  var id = Number(chip);
  if (!id) return '';
  var ids = TMDB_WATCH_FAMILIES[id] || [id];
  return ids.join('|');
}

function tmdbTvNetworkQuery(filter) {
  var chip = hubFilterValue(filter, 'watch_provider');
  if (!chip) return '';
  var id = Number(chip);
  if (!id) return '';
  var ids = TMDB_TV_NETWORK_FAMILIES[id] || [];
  return ids.join('|');
}

function tmdbUniqueRows(primary, extra) {
  var out = [];
  var seen = {};
  function add(row) {
    if (!row || !row.id) return;
    var type = row.media_type || (row.title ? 'movie' : 'tv');
    var key = type + ':' + row.id;
    if (seen[key]) return;
    seen[key] = true;
    out.push(row);
  }
  var i;
  for (i = 0; i < (primary || []).length; i++) add(primary[i]);
  for (i = 0; i < (extra || []).length; i++) add(extra[i]);
  return out;
}

function tmdbDiscoverMovie(ctx, cfg, query, filter) {
  var q = Object.assign({ include_adult: 'false' }, query || {});
  var providers = tmdbWatchProviderQuery(filter);
  if (providers) {
    q.with_watch_providers = providers;
    q.watch_region = String(cfg.region || 'US');
  }
  var genres = hubFilterValues(filter, 'genre');
  if (genres.length) q.with_genres = genres.join(',');
  return tmdbGet(ctx, cfg, '/discover/movie', q);
}

function tmdbDiscoverTv(ctx, cfg, query, filter) {
  var q = Object.assign({ include_adult: 'false' }, query || {});
  var providers = tmdbWatchProviderQuery(filter);
  var networks = tmdbTvNetworkQuery(filter);
  var genres = hubFilterValues(filter, 'genre');
  if (genres.length) q.with_genres = genres.join(',');
  if (providers) {
    q.with_watch_providers = providers;
    q.watch_region = String(cfg.region || 'US');
  }
  if (!networks) {
    return tmdbGet(ctx, cfg, '/discover/tv', q);
  }
  var providerFetch = providers
    ? tmdbGet(ctx, cfg, '/discover/tv', q)
    : Promise.resolve({ results: [] });
  var networkQ = Object.assign({}, q);
  delete networkQ.with_watch_providers;
  delete networkQ.watch_region;
  networkQ.with_networks = networks;
  return providerFetch.then(function (providerJson) {
    return tmdbGet(ctx, cfg, '/discover/tv', networkQ).then(function (networkJson) {
      return {
        results: tmdbUniqueRows(
          providerJson && providerJson.results,
          networkJson && networkJson.results,
        ),
      };
    });
  });
}

function tmdbInterleaveMetas(cfg, movieJson, tvJson, limit) {
  var movies = (movieJson && movieJson.results) || [];
  var shows = (tvJson && tvJson.results) || [];
  var out = [];
  var seen = {};
  function pushMeta(row, type) {
    if (row && row.media_type === 'person') return;
    var meta = tmdbMeta(cfg, row, type);
    if (!meta) return;
    var key = meta.type + ':' + meta.ids.tmdb;
    if (seen[key]) return;
    seen[key] = true;
    out.push(meta);
  }
  var cap = Number(limit) > 0 ? Number(limit) : TMDB_HOME_RAIL_CAP;
  var maxLen = Math.max(movies.length, shows.length);
  for (var i = 0; i < maxLen && out.length < cap; i++) {
    if (i < movies.length) pushMeta(movies[i], 'movie');
    if (out.length >= cap) break;
    if (i < shows.length) pushMeta(shows[i], 'tv');
  }
  return out;
}

function tmdbFetchMixed(ctx, cfg, filter, typeFilter, movieQuery, tvQuery, limit) {
  var movieFetch =
    typeFilter === 'tv'
      ? Promise.resolve({ results: [] })
      : tmdbDiscoverMovie(ctx, cfg, movieQuery, filter);
  var tvFetch =
    typeFilter === 'movie'
      ? Promise.resolve({ results: [] })
      : tmdbDiscoverTv(ctx, cfg, tvQuery, filter);
  return Promise.all([movieFetch, tvFetch]).then(function (pair) {
    return tmdbInterleaveMetas(cfg, pair[0], pair[1], limit);
  });
}

function tmdbUniqueMetas(primary, extra, limit) {
  var seen = {};
  var out = [];
  function addItem(item) {
    var key = tmdbMetaKey(item);
    if (!key || seen[key]) return;
    seen[key] = true;
    out.push(item);
  }
  var i;
  for (i = 0; i < (primary || []).length; i++) addItem(primary[i]);
  for (i = 0; i < (extra || []).length; i++) addItem(extra[i]);
  return hubClampList(out, limit);
}

function tmdbMetaKey(item) {
  if (!item || !item.ids || !item.ids.tmdb) return '';
  return String(item.type || '') + ':' + String(item.ids.tmdb);
}

function tmdbClaimRails(pools, specs) {
  var claimed = {};
  var out = {};
  for (var s = 0; s < specs.length; s++) {
    var spec = specs[s];
    var pool = pools[spec.id] || [];
    var cap = spec.cap > 0 ? spec.cap : TMDB_HOME_RAIL_CAP;
    var mode = spec.mode || 'exclusive';
    var selected = [];
    for (var i = 0; i < pool.length; i++) {
      if (selected.length >= cap) break;
      var key = tmdbMetaKey(pool[i]);
      if (!key) continue;
      if (mode === 'exclusive' && claimed[key]) continue;
      selected.push(pool[i]);
      if (mode !== 'overlayIgnore') claimed[key] = true;
    }
    out[spec.id] = selected;
  }
  return out;
}

function tmdbListPool(ctx, cfg, params, railId) {
  var pages = [];
  for (var p = 1; p <= TMDB_HOME_FETCH_PAGES; p++) {
    pages.push(
      tmdbList(
        ctx,
        cfg,
        Object.assign({}, params, {
          rail: railId,
          page: p,
          limit: TMDB_HOME_RAIL_CAP,
        }),
      ),
    );
  }
  return Promise.all(pages).then(function (chunks) {
    var merged = [];
    for (var i = 0; i < chunks.length; i++) merged = tmdbUniqueMetas(merged, chunks[i], 999);
    return merged;
  });
}

function tmdbHomeFeed(ctx, cfg, params) {
  var ids = TMDB_FEED_CLAIM.map(function (s) {
    return s.id;
  });
  return Promise.all(
    ids.map(function (id) {
      return tmdbListPool(ctx, cfg, params, id);
    }),
  ).then(function (results) {
    var pools = {};
    for (var i = 0; i < ids.length; i++) pools[ids[i]] = results[i];
    return hubOk(
      'feed',
      { rails: tmdbClaimRails(pools, TMDB_FEED_CLAIM) },
      { maxAge: 900, swr: 3600 },
    );
  });
}

var TMDB_GENRE_ROWS = [
  { id: 'action', label: 'Action', movieGenres: [28], tvGenres: [10759] },
  { id: 'adventure', label: 'Adventure', movieGenres: [12], tvGenres: [10759] },
  { id: 'animation', label: 'Animation', movieGenres: [16], tvGenres: [16] },
  { id: 'comedy', label: 'Comedy', movieGenres: [35], tvGenres: [35] },
  { id: 'crime', label: 'Crime', movieGenres: [80], tvGenres: [80] },
  { id: 'documentary', label: 'Documentary', movieGenres: [99], tvGenres: [99] },
  { id: 'drama', label: 'Drama', movieGenres: [18], tvGenres: [18] },
  { id: 'family', label: 'Family', movieGenres: [10751], tvGenres: [10751] },
  { id: 'fantasy', label: 'Fantasy', movieGenres: [14], tvGenres: [10765] },
  { id: 'horror', label: 'Horror', movieGenres: [27], tvGenres: [9648] },
  { id: 'music', label: 'Music', movieGenres: [10402], tvGenres: [10402] },
  { id: 'mystery', label: 'Mystery', movieGenres: [9648], tvGenres: [9648] },
  { id: 'romance', label: 'Romance', movieGenres: [10749], tvGenres: [10749] },
  { id: 'scifi', label: 'Sci-Fi', movieGenres: [878], tvGenres: [10765] },
  { id: 'thriller', label: 'Thriller', movieGenres: [53], tvGenres: [80] },
  { id: 'war', label: 'War', movieGenres: [10752], tvGenres: [10768] },
];

function tmdbHourBucket() {
  return Math.floor(Date.now() / 3600000);
}

function tmdbSeededShuffle(list, salt) {
  var out = list.slice();
  var seed = tmdbHourBucket() + '|' + salt;
  var h = 0;
  for (var i = 0; i < seed.length; i++) {
    h = ((h << 5) - h + seed.charCodeAt(i)) | 0;
  }
  for (var j = out.length - 1; j > 0; j--) {
    h = ((h << 5) - h + j) | 0;
    var k = Math.abs(h) % (j + 1);
    var tmp = out[j];
    out[j] = out[k];
    out[k] = tmp;
  }
  return out;
}

function tmdbPickGenreRows(count) {
  return tmdbSeededShuffle(TMDB_GENRE_ROWS, 'genre-rows').slice(0, count);
}

function tmdbGenreRowSpec(params) {
  var genreRowId = String(
    (params && (params.genreRow || params.genre)) || '',
  ).trim();
  if (!genreRowId) return null;
  for (var i = 0; i < TMDB_GENRE_ROWS.length; i++) {
    if (TMDB_GENRE_ROWS[i].id === genreRowId) return TMDB_GENRE_ROWS[i];
  }
  return null;
}

function tmdbGenreDiscover(ctx, cfg, params, filter, spec, typeFilter) {
  var movieGenres = spec.movieGenres || [];
  var tvGenres = spec.tvGenres || [];
  var page = Number(params.page) > 0 ? Number(params.page) : 1;
  var limit = params.limit;
  var movieQ = {
    sort_by: 'popularity.desc',
    with_genres: movieGenres.join(','),
    page: page,
    'vote_count.gte': 50,
  };
  var tvQ = {
    sort_by: 'popularity.desc',
    with_genres: tvGenres.join(','),
    page: page,
    'vote_count.gte': 50,
  };
  if (typeFilter === 'movie') {
    return tmdbDiscoverMovie(ctx, cfg, movieQ, filter).then(function (json) {
      return tmdbMetas(cfg, json, 'movie', limit);
    });
  }
  if (typeFilter === 'tv') {
    return tmdbDiscoverTv(ctx, cfg, tvQ, filter).then(function (json) {
      return tmdbMetas(cfg, json, 'tv', limit);
    });
  }
  return Promise.all([
    tmdbDiscoverMovie(ctx, cfg, movieQ, filter),
    tmdbDiscoverTv(ctx, cfg, tvQ, filter),
  ]).then(function (pair) {
    return tmdbInterleaveMetas(cfg, pair[0], pair[1], limit || TMDB_HOME_RAIL_CAP);
  });
}

function tmdbPickBecauseSeed(seeds, shuffleKey) {
  if (!seeds || !seeds.length) return null;
  var key = String(shuffleKey || '0');
  var h = 0;
  for (var i = 0; i < key.length; i++) {
    h = ((h << 5) - h + key.charCodeAt(i)) | 0;
  }
  var idx = Math.abs(h) % seeds.length;
  return seeds[idx];
}

function tmdbBecause(ctx, cfg, params) {
  var seeds = (params && params.resumeSeeds) || [];
  if (!seeds.length) {
    return Promise.resolve(
      hubOk('rail', { items: [], heading: '', canShuffle: false }, { maxAge: 300 }),
    );
  }
  var seed = tmdbPickBecauseSeed(seeds, params.shuffleKey);
  if (!seed) {
    return Promise.resolve(
      hubOk('rail', { items: [], heading: '', canShuffle: false }, { maxAge: 300 }),
    );
  }
  var meta = seed.meta || {};
  var tmdbId = meta.ids && meta.ids.tmdb;
  var mediaType = String(meta.type || 'movie').trim();
  if (mediaType !== 'tv') mediaType = 'movie';
  if (!tmdbId) {
    return Promise.resolve(
      hubOk('rail', { items: [], heading: '', canShuffle: false }, { maxAge: 300 }),
    );
  }
  var path =
    mediaType === 'tv'
      ? '/tv/' + tmdbId + '/recommendations'
      : '/movie/' + tmdbId + '/recommendations';
  var title = String(seed.title || meta.name || '').trim();
  return tmdbGet(ctx, cfg, path, { page: 1 }).then(function (json) {
    return hubOk(
      'rail',
      {
        items: tmdbMetas(cfg, json, mediaType, TMDB_HOME_RAIL_CAP),
        heading: title ? 'Because you watched ' + title : 'Because you watched',
        seedPoster: String(meta.poster || meta.background || ''),
        canShuffle: seeds.length > 1,
      },
      { maxAge: 900, swr: 3600 },
    );
  });
}

function tmdbLayout() {
  var genreWidgets = tmdbPickGenreRows(3).map(function (g) {
    return {
      type: 'rail',
      id: 'genre_' + g.id,
      title: g.label,
      rail: 'genre',
      params: { genreRow: g.id },
    };
  });
  return {
    pages: {
      home: {
        feed: true,
        widgets: [
          {
            type: 'vertical_filters',
            id: 'watch_providers',
            showSelectedInTopBar: true,
            options: TMDB_VERTICAL_FILTERS,
          },
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
          { type: 'continue', id: 'continue_watching' },
          {
            type: 'mood',
            id: 'moods',
            title: "What's your mood?",
            options: TMDB_MOODS,
            rail: 'discover',
          },
          { type: 'because', id: 'because', rail: 'because' },
          { type: 'trakt', id: 'trakt' },
          {
            type: 'rail',
            id: 'new_releases',
            title: 'New Releases',
            rail: 'new_releases',
          },
        ].concat(genreWidgets),
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
  var filter = params.filter;
  var genres = hubFilterValues(filter, 'genre');
  var typeFilter = hubFilterValue(filter, 'type');
  var watchProviders = tmdbWatchProviderQuery(filter);
  if (typeFilter !== 'movie' && typeFilter !== 'tv') typeFilter = '';
  var page = Number(params.page) > 0 ? Number(params.page) : 1;
  var limit = params.limit;

  if (railId === 'genre') {
    var genreSpec = tmdbGenreRowSpec(params);
    if (!genreSpec) return Promise.resolve([]);
    return tmdbGenreDiscover(ctx, cfg, params, filter, genreSpec, typeFilter);
  }

  // Mood discover — separate movie/tv genre lists from the mood option.
  if (railId === 'discover') {
    var moodId = hubFilterValue(filter, 'mood');
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
    var discoverQ = {
      sort_by: String(params.sort || 'popularity.desc'),
      with_genres: g.join(','),
      page: page,
      'vote_count.gte': 50,
    };
    if (mediaType === 'tv') {
      return tmdbDiscoverTv(ctx, cfg, discoverQ, filter).then(function (json) {
        return tmdbMetas(cfg, json, 'tv', limit);
      });
    }
    return tmdbDiscoverMovie(ctx, cfg, discoverQ, filter).then(function (json) {
      return tmdbMetas(cfg, json, 'movie', limit);
    });
  }

  if (railId === 'featured') {
    var win = tmdbMonthWindow();
    var hasProvider = !!watchProviders;
    var hasGenre = genres.length > 0;

    function loadFeatured(dateGte, dateLte, minRating) {
      var movieQ = { sort_by: 'popularity.desc', page: page };
      var tvQ = { sort_by: 'popularity.desc', page: page };
      if (dateGte && dateLte) {
        movieQ['primary_release_date.gte'] = dateGte;
        movieQ['primary_release_date.lte'] = dateLte;
        tvQ['first_air_date.gte'] = dateGte;
        tvQ['first_air_date.lte'] = dateLte;
      }
      if (minRating != null) {
        movieQ['vote_average.gte'] = minRating;
        tvQ['vote_average.gte'] = minRating;
      }
      return tmdbFetchMixed(ctx, cfg, filter, typeFilter, movieQ, tvQ, limit);
    }

    return loadFeatured(win.gte, win.lte, hasProvider ? null : 6).then(function (month) {
      var needsFill = hasProvider || hasGenre;
      if (!needsFill || month.length >= TMDB_HOME_RAIL_CAP) return month;
      return loadFeatured(null, null, null).then(function (popular) {
        return tmdbUniqueMetas(month, popular, limit);
      });
    });
  }

  if (railId === 'popular') {
    if (watchProviders) {
      var popularQ = {
        sort_by: 'popularity.desc',
        page: page,
        'vote_count.gte': 100,
      };
      return tmdbFetchMixed(ctx, cfg, filter, typeFilter, popularQ, popularQ, limit);
    }
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
    if (watchProviders) {
      return tmdbFetchMixed(
        ctx,
        cfg,
        filter,
        typeFilter,
        { sort_by: 'primary_release_date.desc', page: page },
        { sort_by: 'first_air_date.desc', page: page },
        limit,
      );
    }
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
    if (watchProviders) {
      var typedQ = {
        sort_by: 'popularity.desc',
        page: page,
        'vote_count.gte': 50,
      };
      if (typeFilter === 'movie') {
        return tmdbDiscoverMovie(ctx, cfg, typedQ, filter).then(function (json) {
          return tmdbMetas(cfg, json, 'movie', limit);
        });
      }
      return tmdbDiscoverTv(ctx, cfg, typedQ, filter).then(function (json) {
        return tmdbMetas(cfg, json, 'tv', limit);
      });
    }
    return tmdbGet(ctx, cfg, '/trending/' + typeFilter + '/day', { page: page }).then(
      function (json) {
        return tmdbMetas(cfg, json, typeFilter, limit);
      },
    );
  }

  var spec = TMDB_RAILS[railId];
  if (!spec || !spec.path) {
    return Promise.reject(new Error('unknown rail ' + railId));
  }
  if (watchProviders && railId === 'spotlight') {
    var spotlightQ = {
      sort_by: 'popularity.desc',
      page: page,
      'vote_count.gte': 50,
    };
    return tmdbFetchMixed(ctx, cfg, filter, typeFilter, spotlightQ, spotlightQ, limit);
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
      media: {
        films: { op: 'eq', field: 'type', value: 'movie' },
        series: { op: 'eq', field: 'type', value: 'tv' },
      },
      genreRows: TMDB_GENRE_ROWS,
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
  if (action === 'feed') {
    return wrap(
      tmdbHomeFeed(ctx, cfg, params).then(function (env) {
        return env[0];
      }),
    );
  }
  if (action !== 'rail') {
    return hubFail(action, 'INVALID_ACTION', 'tmdb has no action ' + action);
  }
  if (String(params.rail || '') === 'because') {
    return wrap(
      tmdbBecause(ctx, cfg, params).then(function (env) {
        return env[0];
      }),
    );
  }
  return wrap(
    tmdbList(ctx, cfg, params).then(function (items) {
      return hubItems('rail', items, { maxAge: 900, swr: 3600 })[0];
    }),
  );
}
