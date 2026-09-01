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
// Hourly mix — pick distinct TMDB pages in 1..max (Dart home_catalog_rotate).
var TMDB_HOME_ROTATE_MAX_PAGE = 5;

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
  var preserveRank = railId === 'spotlight' || railId === 'popular';
  var pageNums = preserveRank
    ? (function () {
        var fixed = [];
        for (var fp = 1; fp <= TMDB_HOME_FETCH_PAGES; fp++) fixed.push(fp);
        return fixed;
      })()
    : tmdbPickFetchPages(railId, TMDB_HOME_FETCH_PAGES, TMDB_HOME_ROTATE_MAX_PAGE);
  var pages = [];
  var pi;
  for (pi = 0; pi < pageNums.length; pi++) {
    pages.push(
      tmdbList(
        ctx,
        cfg,
        Object.assign({}, params, {
          rail: railId,
          page: pageNums[pi],
          limit: TMDB_HOME_RAIL_CAP,
          _poolPage: true,
        }),
      ).catch(function () {
        return [];
      }),
    );
  }
  return Promise.all(pages).then(function (chunks) {
    var merged = [];
    var i;
    for (i = 0; i < chunks.length; i++) merged = tmdbUniqueMetas(merged, chunks[i], 999);
    if (preserveRank) return merged;
    return tmdbSeededShuffle(merged, 'pool-' + railId);
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

function tmdbPickFetchPages(salt, count, maxPage) {
  var pages = [];
  var max = Number(maxPage) > 0 ? Number(maxPage) : TMDB_HOME_ROTATE_MAX_PAGE;
  var n = Number(count) > 0 ? Number(count) : TMDB_HOME_FETCH_PAGES;
  for (var i = 1; i <= max; i++) pages.push(i);
  var shuffled = tmdbSeededShuffle(pages, 'pages-' + String(salt || ''));
  var picked = shuffled.slice(0, Math.min(n, shuffled.length));
  picked.sort(function (a, b) {
    return a - b;
  });
  return picked;
}

function tmdbFetchRotatedList(ctx, cfg, params, salt, fetchOnePage) {
  var pageNums = tmdbPickFetchPages(
    salt,
    TMDB_HOME_FETCH_PAGES,
    TMDB_HOME_ROTATE_MAX_PAGE,
  );
  var limit = params.limit;
  return Promise.all(
    pageNums.map(function (p) {
      return fetchOnePage(p).catch(function () {
        return [];
      });
    }),
  ).then(function (chunks) {
    var merged = [];
    var i;
    for (i = 0; i < chunks.length; i++) {
      merged = tmdbUniqueMetas(merged, chunks[i], 999);
    }
    var shuffled = tmdbSeededShuffle(merged, 'pool-' + String(salt || ''));
    return hubClampList(shuffled, limit || TMDB_HOME_RAIL_CAP);
  });
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
        pageSize: TMDB_HOME_RAIL_CAP,
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
          {
            type: 'ranked',
            id: 'popular',
            title: 'Popular',
            rail: 'popular',
            style: 'numbered',
          },
          { type: 'continue', id: 'continue_watching', mergeHomeWatchHistory: true },
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

var TMDB_MOVIE_GENRE_NAMES = {
  28: 'Action',
  12: 'Adventure',
  16: 'Animation',
  35: 'Comedy',
  80: 'Crime',
  99: 'Documentary',
  18: 'Drama',
  10751: 'Family',
  14: 'Fantasy',
  36: 'History',
  27: 'Horror',
  10402: 'Music',
  9648: 'Mystery',
  10749: 'Romance',
  878: 'Sci-Fi',
  10770: 'TV Movie',
  53: 'Thriller',
  10752: 'War',
  37: 'Western',
};

var TMDB_TV_GENRE_NAMES = {
  10759: 'Action & Adventure',
  16: 'Animation',
  35: 'Comedy',
  80: 'Crime',
  99: 'Documentary',
  18: 'Drama',
  10751: 'Family',
  10762: 'Kids',
  9648: 'Mystery',
  10763: 'News',
  10764: 'Reality',
  10765: 'Sci-Fi & Fantasy',
  10766: 'Soap',
  10767: 'Talk',
  10768: 'War & Politics',
  37: 'Western',
};

function tmdbGenreNames(type, genreIds) {
  var map = type === 'tv' ? TMDB_TV_GENRE_NAMES : TMDB_MOVIE_GENRE_NAMES;
  var names = [];
  var ids = Array.isArray(genreIds) ? genreIds : [];
  for (var i = 0; i < ids.length; i++) {
    var label = map[Number(ids[i])];
    if (label) names.push(label);
  }
  return names;
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
    tmdbMediaType: type,
    badge: type === 'movie' ? 'FILM' : 'TV',
    open: {
      surface: 'tmdb',
      id: String(row.id),
      mediaType: type,
      extract: {
        resolveType: type === 'tv' ? 'tv' : 'movie',
        panelCategory: type === 'tv' ? 'tv' : 'movie',
        ctx: { tmdbId: Number(row.id) },
      },
    },
  };
  if (row.vote_average) meta.rating = Number(row.vote_average);
  var genreNames = tmdbGenreNames(type, row.genre_ids);
  if (genreNames.length) meta.genres = genreNames;
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

function tmdbFeaturedForPage(
  ctx,
  cfg,
  filter,
  typeFilter,
  watchProviders,
  genres,
  page,
  limit,
) {
  var win = tmdbMonthWindow();
  var hasProvider = !!watchProviders;

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
    if (month.length >= TMDB_HOME_RAIL_CAP) return month;
    return loadFeatured(null, null, null).then(function (popular) {
      return tmdbUniqueMetas(month, popular, limit);
    });
  });
}

function tmdbNewReleasesForPage(
  ctx,
  cfg,
  filter,
  typeFilter,
  watchProviders,
  page,
  limit,
) {
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

function tmdbList(ctx, cfg, params) {
  var railId = String(params.rail || 'spotlight');
  var filter = params.filter;
  var genres = hubFilterValues(filter, 'genre');
  var typeFilter = hubFilterValue(filter, 'type');
  var watchProviders = tmdbWatchProviderQuery(filter);
  if (typeFilter !== 'movie' && typeFilter !== 'tv') typeFilter = '';
  var page = Number(params.page) > 0 ? Number(params.page) : 1;
  var limit = params.limit;
  var poolPage = params._poolPage === true;

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
    if (!poolPage && page === 1) {
      return tmdbFetchRotatedList(ctx, cfg, params, 'featured', function (p) {
        return tmdbFeaturedForPage(
          ctx,
          cfg,
          filter,
          typeFilter,
          watchProviders,
          genres,
          p,
          TMDB_HOME_RAIL_CAP,
        );
      });
    }
    return tmdbFeaturedForPage(
      ctx,
      cfg,
      filter,
      typeFilter,
      watchProviders,
      genres,
      page,
      limit,
    );
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
    if (!poolPage && page === 1) {
      return tmdbFetchRotatedList(ctx, cfg, params, 'new_releases', function (p) {
        return tmdbNewReleasesForPage(
          ctx,
          cfg,
          filter,
          typeFilter,
          watchProviders,
          p,
          TMDB_HOME_RAIL_CAP,
        );
      });
    }
    return tmdbNewReleasesForPage(
      ctx,
      cfg,
      filter,
      typeFilter,
      watchProviders,
      page,
      limit,
    );
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

function tmdbBuildTvVideos(ctx, cfg, tvId, showJson) {
  var seasons = Array.isArray(showJson.seasons) ? showJson.seasons : [];
  var seasonNums = [];
  var si;
  for (si = 0; si < seasons.length; si++) {
    var sn = Number(seasons[si].season_number);
    if (sn >= 1) seasonNums.push(sn);
  }
  seasonNums.sort(function (a, b) {
    return a - b;
  });
  var maxSeasons = 25;
  if (seasonNums.length > maxSeasons) {
    seasonNums = seasonNums.slice(0, maxSeasons);
  }
  if (!seasonNums.length) return Promise.resolve([]);

  return Promise.all(
    seasonNums.map(function (sn) {
      return tmdbGet(ctx, cfg, '/tv/' + tvId + '/season/' + sn, {}).then(
        function (seasonJson) {
          var eps = Array.isArray(seasonJson.episodes)
            ? seasonJson.episodes
            : [];
          var out = [];
          var ei;
          for (ei = 0; ei < eps.length; ei++) {
            var ep = eps[ei];
            if (!ep || ep.episode_number == null) continue;
            var epNum = Math.round(Number(ep.episode_number));
            if (!epNum) continue;
            out.push({
              id: tvId + ':S' + sn + 'E' + epNum,
              season: sn,
              episode: epNum,
              title: String(ep.name || 'Episode ' + epNum).trim(),
              thumbnail: ep.still_path
                ? tmdbImage(cfg, ep.still_path, 'w300')
                : '',
            });
          }
          return out;
        },
      );
    }),
  ).then(function (nested) {
    var videos = [];
    var ni;
    for (ni = 0; ni < nested.length; ni++) {
      videos = videos.concat(nested[ni]);
    }
    videos.sort(function (a, b) {
      if (a.season !== b.season) return a.season - b.season;
      return a.episode - b.episode;
    });
    return videos;
  });
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
  var append =
    type === 'tv'
      ? 'external_ids,recommendations'
      : 'external_ids,recommendations';
  return tmdbGet(ctx, cfg, '/' + type + '/' + id, {
    append_to_response: append,
  }).then(function (json) {
    var meta = tmdbMeta(cfg, json, type);
    if (!meta) return hubFail('details', 'NOT_FOUND', type + ' ' + id);

    var ext = json.external_ids || {};
    if (ext.imdb_id) {
      meta.ids = meta.ids || {};
      meta.ids.imdb = String(ext.imdb_id);
    }

    var rails = {};
    var sideJobs = [];

    var recJson = json.recommendations;
    if (recJson && Array.isArray(recJson.results) && recJson.results.length) {
      rails.recommendations = {
        title: 'More Like This',
        items: tmdbMetas(cfg, recJson, type, TMDB_HOME_RAIL_CAP),
      };
    } else {
      sideJobs.push(
        tmdbGet(ctx, cfg, '/' + type + '/' + id + '/recommendations', {
          page: 1,
        }).then(function (rec) {
          rails.recommendations = {
            title: 'More Like This',
            items: tmdbMetas(cfg, rec, type, TMDB_HOME_RAIL_CAP),
          };
        }),
      );
    }

    if (
      type === 'movie' &&
      json.belongs_to_collection &&
      json.belongs_to_collection.id
    ) {
      var colId = Number(json.belongs_to_collection.id);
      sideJobs.push(
        tmdbGet(ctx, cfg, '/collection/' + colId, {}).then(function (col) {
          var parts = Array.isArray(col.parts) ? col.parts : [];
          if (!parts.length) return;
          rails.collection = {
            title: String(col.name || 'Collection').trim(),
            items: tmdbMetas(cfg, { results: parts }, 'movie', 30),
          };
        }),
      );
    }

    if (type === 'tv') {
      sideJobs.push(
        tmdbBuildTvVideos(ctx, cfg, id, json).then(function (videos) {
          if (videos.length) meta.videos = videos;
        }),
      );
    }

    return Promise.all(sideJobs).then(function () {
      var data = { meta: meta };
      if (Object.keys(rails).length) data.rails = rails;
      return hubOk('details', data, { maxAge: 3600, swr: 86400 });
    });
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

// --- RFC-058 structured search (port of Dart parseSearchQuery + searchStructured) ---

var TMDB_SEARCH_GENRE_ALIASES = [
  { aliases: ['science fiction', 'sci-fi', 'scifi', 'sci fi'], label: 'Science Fiction', movieIds: [878], tvIds: [10765] },
  { aliases: ['action & adventure', 'action and adventure'], label: 'Action & Adventure', movieIds: [28, 12], tvIds: [10759] },
  { aliases: ['tv movie', 'tv-movie'], label: 'TV Movie', movieIds: [10770], tvIds: [] },
  { aliases: ['war & politics', 'war and politics'], label: 'War & Politics', movieIds: [10752], tvIds: [10768] },
  { aliases: ['action'], label: 'Action', movieIds: [28], tvIds: [10759] },
  { aliases: ['adventure'], label: 'Adventure', movieIds: [12], tvIds: [10759] },
  { aliases: ['animation', 'anime'], label: 'Animation', movieIds: [16], tvIds: [16] },
  { aliases: ['comedy'], label: 'Comedy', movieIds: [35], tvIds: [35] },
  { aliases: ['crime'], label: 'Crime', movieIds: [80], tvIds: [80] },
  { aliases: ['documentary', 'docs'], label: 'Documentary', movieIds: [99], tvIds: [99] },
  { aliases: ['drama'], label: 'Drama', movieIds: [18], tvIds: [18] },
  { aliases: ['family'], label: 'Family', movieIds: [10751], tvIds: [10751] },
  { aliases: ['fantasy'], label: 'Fantasy', movieIds: [14], tvIds: [10765] },
  { aliases: ['history'], label: 'History', movieIds: [36], tvIds: [36] },
  { aliases: ['horror'], label: 'Horror', movieIds: [27], tvIds: [27] },
  { aliases: ['music', 'musical'], label: 'Music', movieIds: [10402], tvIds: [10402] },
  { aliases: ['mystery'], label: 'Mystery', movieIds: [9648], tvIds: [9648] },
  { aliases: ['romance', 'romantic'], label: 'Romance', movieIds: [10749], tvIds: [10749] },
  { aliases: ['thriller'], label: 'Thriller', movieIds: [53], tvIds: [53] },
  { aliases: ['war'], label: 'War', movieIds: [10752], tvIds: [10768] },
  { aliases: ['western'], label: 'Western', movieIds: [37], tvIds: [37] },
  { aliases: ['kids', 'children'], label: 'Kids', movieIds: [10751], tvIds: [10762] },
];

var TMDB_SEARCH_COUNTRY_ALIASES = [
  { aliases: ['united states', 'usa', 'u.s.', 'u.s.a.', 'america'], code: 'US', label: 'USA' },
  { aliases: ['united kingdom', 'uk', 'u.k.', 'britain', 'england'], code: 'GB', label: 'UK' },
  { aliases: ['france', 'french'], code: 'FR', label: 'France' },
  { aliases: ['germany', 'german'], code: 'DE', label: 'Germany' },
  { aliases: ['japan', 'japanese'], code: 'JP', label: 'Japan' },
  { aliases: ['south korea', 'korea', 'korean'], code: 'KR', label: 'Korea' },
  { aliases: ['india', 'indian', 'bollywood'], code: 'IN', label: 'India' },
  { aliases: ['italy', 'italian'], code: 'IT', label: 'Italy' },
  { aliases: ['spain', 'spanish'], code: 'ES', label: 'Spain' },
  { aliases: ['canada', 'canadian'], code: 'CA', label: 'Canada' },
  { aliases: ['australia', 'australian'], code: 'AU', label: 'Australia' },
  { aliases: ['china', 'chinese'], code: 'CN', label: 'China' },
  { aliases: ['brazil', 'brazilian'], code: 'BR', label: 'Brazil' },
  { aliases: ['mexico', 'mexican'], code: 'MX', label: 'Mexico' },
  { aliases: ['sweden', 'swedish'], code: 'SE', label: 'Sweden' },
  { aliases: ['norway', 'norwegian'], code: 'NO', label: 'Norway' },
  { aliases: ['denmark', 'danish'], code: 'DK', label: 'Denmark' },
  { aliases: ['turkey', 'turkish'], code: 'TR', label: 'Turkey' },
  { aliases: ['hong kong'], code: 'HK', label: 'Hong Kong' },
  { aliases: ['taiwan', 'taiwanese'], code: 'TW', label: 'Taiwan' },
  { aliases: ['thailand', 'thai'], code: 'TH', label: 'Thailand' },
];

var TMDB_YEAR_RANGE_RE = /\b((?:19|20)\d{2})\s*[-–—]\s*((?:19|20)\d{2})\b/;
var TMDB_YEAR_RE = /\b((?:19|20)\d{2})\b/;
var TMDB_SCORE_OP_RE = /(?:^|\s)(>=|<=|>|<)\s*(\d(?:\.\d)?)(?=\s|$)/g;
var TMDB_SCORE_RANGE_RE = /(?:^|\s)(\d(?:\.\d)?)\s*[-–—]\s*(\d(?:\.\d)?)(?=\s|$)/;
var TMDB_MEDIA_TYPE_RE = /(?:^|\s)(films?|movies?|series|shows?|tv)(?=\s|$)/i;

function tmdbEscapeRegExp(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function tmdbContainsGenreToken(lowerHaystack, alias) {
  if (alias.indexOf(' ') >= 0) {
    return new RegExp('(^|\\s)' + tmdbEscapeRegExp(alias) + '(\\s|$)').test(lowerHaystack);
  }
  var parts = lowerHaystack.split(/\s+/);
  return parts.indexOf(alias) >= 0;
}

function tmdbStripGenreToken(working, aliases) {
  var sorted = aliases.slice().sort(function (a, b) {
    return b.length - a.length;
  });
  var out = working;
  var i;
  for (i = 0; i < sorted.length; i++) {
    var re = new RegExp(
      '(^|\\s)' + tmdbEscapeRegExp(sorted[i]) + '(\\s|$)',
      'i',
    );
    var m = re.exec(out);
    if (!m) continue;
    out = out.substring(0, m.index) + ' ' + out.substring(m.index + m[0].length);
    break;
  }
  return out.replace(/\s+/g, ' ').trim();
}

function tmdbParseSearchQuery(raw) {
  var trimmed = String(raw || '').trim();
  if (!trimmed) {
    return {
      raw: raw,
      remainder: '',
      year: null,
      yearStart: null,
      yearEnd: null,
      movieGenreIds: [],
      tvGenreIds: [],
      matchedGenreLabel: null,
      mediaType: null,
      minScore: null,
      maxScore: null,
      originCountry: null,
    };
  }

  var working = trimmed;
  var year = null;
  var yearStart = null;
  var yearEnd = null;

  var range = TMDB_YEAR_RANGE_RE.exec(working);
  if (range) {
    yearStart = parseInt(range[1], 10);
    yearEnd = parseInt(range[2], 10);
    working = (working.substring(0, range.index) + ' ' + working.substring(range.index + range[0].length))
      .replace(/\s+/g, ' ')
      .trim();
  } else {
    var single = TMDB_YEAR_RE.exec(working);
    if (single) {
      year = parseInt(single[1], 10);
      working = (working.substring(0, single.index) + ' ' + working.substring(single.index + single[0].length))
        .replace(/\s+/g, ' ')
        .trim();
    }
  }

  working = working.replace(/\s+/g, ' ').trim();

  var minScore = null;
  var maxScore = null;
  var padded = ' ' + working + ' ';
  TMDB_SCORE_OP_RE.lastIndex = 0;
  var opMatch;
  while ((opMatch = TMDB_SCORE_OP_RE.exec(padded)) !== null) {
    var op = opMatch[1];
    var v = parseFloat(opMatch[2]);
    if (isNaN(v)) continue;
    if (op === '>' || op === '>=') {
      minScore = minScore == null ? v : v > minScore ? v : minScore;
    } else {
      maxScore = maxScore == null ? v : v < maxScore ? v : maxScore;
    }
  }
  working = working.replace(/(?:^|\s)(>=|<=|>|<)\s*(\d(?:\.\d)?)(?=\s|$)/g, ' ');
  working = working.replace(/\s+/g, ' ').trim();

  var scoreRange = TMDB_SCORE_RANGE_RE.exec(' ' + working + ' ');
  if (scoreRange) {
    var a = parseFloat(scoreRange[1]);
    var b = parseFloat(scoreRange[2]);
    if (!isNaN(a) && !isNaN(b) && a <= 10 && b <= 10) {
      var lo = a <= b ? a : b;
      var hi = a <= b ? b : a;
      minScore = minScore == null ? lo : minScore > lo ? minScore : lo;
      maxScore = maxScore == null ? hi : maxScore < hi ? maxScore : hi;
      working = (' ' + working + ' ').replace(TMDB_SCORE_RANGE_RE, ' ');
    }
  }
  working = working.replace(/\s+/g, ' ').trim();

  var mediaType = null;
  var mediaMatch = TMDB_MEDIA_TYPE_RE.exec(' ' + working + ' ');
  if (mediaMatch) {
    var tok = mediaMatch[1].toLowerCase();
    mediaType = tok.indexOf('film') === 0 || tok.indexOf('movie') === 0 ? 'movie' : 'tv';
    working = (' ' + working + ' ').replace(TMDB_MEDIA_TYPE_RE, ' ');
  }
  working = working.replace(/\s+/g, ' ').trim();

  var originCountry = null;
  if (working) {
    var lower = working.toLowerCase();
    var bestCountry = null;
    var bestCountryLen = 0;
    var ci;
    for (ci = 0; ci < TMDB_SEARCH_COUNTRY_ALIASES.length; ci++) {
      var c = TMDB_SEARCH_COUNTRY_ALIASES[ci];
      var cai;
      for (cai = 0; cai < c.aliases.length; cai++) {
        var calias = c.aliases[cai];
        if (calias.length < bestCountryLen) continue;
        if (!tmdbContainsGenreToken(lower, calias)) continue;
        bestCountry = c;
        bestCountryLen = calias.length;
      }
    }
    if (bestCountry) {
      originCountry = bestCountry.code;
      working = tmdbStripGenreToken(working, bestCountry.aliases);
    }
  }
  working = working.replace(/\s+/g, ' ').trim();

  var movieGenreIds = [];
  var tvGenreIds = [];
  var genreLabel = null;
  if (working) {
    var glower = working.toLowerCase();
    var bestGenre = null;
    var bestAliasLen = 0;
    var gi;
    for (gi = 0; gi < TMDB_SEARCH_GENRE_ALIASES.length; gi++) {
      var g = TMDB_SEARCH_GENRE_ALIASES[gi];
      var gai;
      for (gai = 0; gai < g.aliases.length; gai++) {
        var galias = g.aliases[gai];
        if (galias.length < bestAliasLen) continue;
        if (!tmdbContainsGenreToken(glower, galias)) continue;
        bestGenre = g;
        bestAliasLen = galias.length;
      }
    }
    if (bestGenre) {
      movieGenreIds = bestGenre.movieIds.slice();
      tvGenreIds = bestGenre.tvIds.slice();
      genreLabel = bestGenre.label;
      working = tmdbStripGenreToken(working, bestGenre.aliases);
    }
  }

  return {
    raw: raw,
    remainder: working.replace(/\s+/g, ' ').trim(),
    year: year,
    yearStart: yearStart,
    yearEnd: yearEnd,
    movieGenreIds: movieGenreIds,
    tvGenreIds: tvGenreIds,
    matchedGenreLabel: genreLabel,
    mediaType: mediaType,
    minScore: minScore,
    maxScore: maxScore,
    originCountry: originCountry,
  };
}

function tmdbParsedHasYear(p) {
  return p.year != null || (p.yearStart != null && p.yearEnd != null);
}

function tmdbParsedHasGenre(p) {
  return (p.movieGenreIds && p.movieGenreIds.length > 0) || (p.tvGenreIds && p.tvGenreIds.length > 0);
}

function tmdbParsedHasScore(p) {
  return p.minScore != null || p.maxScore != null;
}

function tmdbParsedHasStructuredFilters(p) {
  return (
    tmdbParsedHasYear(p) ||
    tmdbParsedHasGenre(p) ||
    tmdbParsedHasScore(p) ||
    !!p.mediaType ||
    !!p.originCountry
  );
}

function tmdbParsedYearBounds(p) {
  if (p.yearStart != null && p.yearEnd != null) {
    var a = p.yearStart <= p.yearEnd ? p.yearStart : p.yearEnd;
    var b = p.yearStart <= p.yearEnd ? p.yearEnd : p.yearStart;
    return [a, b];
  }
  if (p.year != null) return [p.year, p.year];
  return null;
}

function tmdbReleaseInYearBounds(releaseInfo, bounds) {
  if (!bounds) return true;
  var s = String(releaseInfo || '');
  if (s.length < 4) return false;
  var y = parseInt(s.substring(0, 4), 10);
  if (isNaN(y)) return false;
  return y >= bounds[0] && y <= bounds[1];
}

function tmdbMergeGenreIds(into, extras) {
  var i;
  for (i = 0; i < (extras || []).length; i++) {
    var n = Number(extras[i]);
    if (!n || into.indexOf(n) >= 0) continue;
    into.push(n);
  }
}

function tmdbSafeJson(promise) {
  return promise.catch(function () {
    return { results: [] };
  });
}

function tmdbSearchMultiPage(ctx, cfg, query, page) {
  return tmdbSafeJson(
    tmdbGet(ctx, cfg, '/search/multi', {
      query: query,
      page: page,
      include_adult: 'false',
    }),
  );
}

function tmdbResolvePersonId(ctx, cfg, text) {
  return tmdbSafeJson(
    tmdbGet(ctx, cfg, '/search/person', {
      query: text,
      page: 1,
      include_adult: 'false',
    }),
  ).then(function (json) {
    var hits = (json && json.results) || [];
    if (!hits.length) return null;
    var q = String(text || '').toLowerCase().trim();
    var tokens = q.split(/\s+/).filter(function (t) {
      return !!t;
    });
    var i;
    var lim = Math.min(8, hits.length);
    for (i = 0; i < lim; i++) {
      var name = String(hits[i].name || '').toLowerCase();
      if (name === q) return hits[i].id;
      if (
        tokens.length &&
        tokens.every(function (tok) {
          return name.indexOf(tok) >= 0;
        })
      ) {
        return hits[i].id;
      }
    }
    var top = hits[0];
    if (Number(top.popularity) >= 3) return top.id;
    return null;
  });
}

function tmdbBuildDiscoverQuery(parsed, bounds, page, genres, people, isTv) {
  var q = {
    page: page,
    sort_by: 'popularity.desc',
    include_adult: 'false',
  };
  if (genres && genres.length) q.with_genres = genres.join(',');
  if (people) q.with_people = people;
  var singleYear = bounds && bounds[0] === bounds[1] ? bounds[0] : null;
  var gte = bounds ? bounds[0] + '-01-01' : null;
  var lte = bounds ? bounds[1] + '-12-31' : null;
  if (singleYear != null) {
    if (isTv) q.first_air_date_year = singleYear;
    else q.primary_release_year = singleYear;
  } else if (gte && lte) {
    if (isTv) {
      q['first_air_date.gte'] = gte;
      q['first_air_date.lte'] = lte;
    } else {
      q['primary_release_date.gte'] = gte;
      q['primary_release_date.lte'] = lte;
    }
  }
  if (parsed.minScore != null) q['vote_average.gte'] = parsed.minScore;
  if (parsed.maxScore != null) q['vote_average.lte'] = parsed.maxScore;
  if (parsed.originCountry) q.with_origin_country = parsed.originCountry;
  return q;
}

function tmdbStructuredDiscoverMovie(ctx, cfg, query, filter) {
  var q = Object.assign({ include_adult: 'false' }, query || {});
  var providers = tmdbWatchProviderQuery(filter);
  if (providers) {
    q.with_watch_providers = providers;
    q.watch_region = String(cfg.region || 'US');
  }
  return tmdbSafeJson(tmdbGet(ctx, cfg, '/discover/movie', q));
}

function tmdbStructuredDiscoverTv(ctx, cfg, query, filter) {
  var q = Object.assign({ include_adult: 'false' }, query || {});
  var providers = tmdbWatchProviderQuery(filter);
  if (providers) {
    q.with_watch_providers = providers;
    q.watch_region = String(cfg.region || 'US');
  }
  return tmdbSafeJson(tmdbGet(ctx, cfg, '/discover/tv', q));
}

function tmdbStructuredSearch(ctx, cfg, params) {
  var trimmed = String(params.query || '').trim();
  var filter = params.filter;
  var hasChromeFilter = filter != null && filter !== '';
  if (!trimmed && !hasChromeFilter) return Promise.resolve([]);

  var parsed = trimmed
    ? tmdbParseSearchQuery(trimmed)
    : {
        raw: '',
        remainder: '',
        year: null,
        yearStart: null,
        yearEnd: null,
        movieGenreIds: [],
        tvGenreIds: [],
        matchedGenreLabel: null,
        mediaType: null,
        minScore: null,
        maxScore: null,
        originCountry: null,
      };
  var typeFilter = hubFilterValue(filter, 'type');
  if (typeFilter === 'movie' || typeFilter === 'tv') {
    parsed.mediaType = typeFilter;
  }
  var filterGenres = hubFilterValues(filter, 'genre');
  if (filterGenres.length) {
    tmdbMergeGenreIds(parsed.movieGenreIds, filterGenres);
    tmdbMergeGenreIds(parsed.tvGenreIds, filterGenres);
  }

  var bounds = tmdbParsedYearBounds(parsed);
  var hasPersonCandidate = parsed.remainder.trim().length >= 2;
  var runMulti =
    parsed.remainder.length > 0 || !tmdbParsedHasStructuredFilters(parsed);
  var limit = Number(params.limit) > 0 ? Number(params.limit) : 0;

  // Chunks: { json, forcedType, applyYear }
  var chunkPromises = [];

  function pushMulti(query, page) {
    chunkPromises.push(
      tmdbSearchMultiPage(ctx, cfg, query, page).then(function (json) {
        return {
          json: json,
          forcedType: '',
          applyYear:
            bounds != null || tmdbParsedHasScore(parsed) || !!parsed.mediaType,
        };
      }),
    );
  }

  if (runMulti) {
    pushMulti(trimmed, 1);
    pushMulti(trimmed, 2);
    if (
      parsed.remainder &&
      parsed.remainder.toLowerCase() !== trimmed.toLowerCase()
    ) {
      pushMulti(parsed.remainder, 1);
      pushMulti(parsed.remainder, 2);
    }
  }

  var personPromise = hasPersonCandidate
    ? tmdbResolvePersonId(ctx, cfg, parsed.remainder)
    : Promise.resolve(null);

  return personPromise.then(function (personId) {
    var discoverPages = 2;
    var wantMovies = !parsed.mediaType || parsed.mediaType === 'movie';
    var wantTv = !parsed.mediaType || parsed.mediaType === 'tv';
    var applyYearDiscover = tmdbParsedHasScore(parsed) || !!parsed.mediaType;

    function pushDiscover(isTv, genres, people) {
      var page;
      for (page = 1; page <= discoverPages; page++) {
        (function (tvFlag, pageNum) {
          var q = tmdbBuildDiscoverQuery(
            parsed,
            bounds,
            pageNum,
            genres,
            people,
            tvFlag,
          );
          var fetch = tvFlag
            ? tmdbStructuredDiscoverTv(ctx, cfg, q, filter)
            : tmdbStructuredDiscoverMovie(ctx, cfg, q, filter);
          chunkPromises.push(
            fetch.then(function (json) {
              return {
                json: json,
                forcedType: tvFlag ? 'tv' : 'movie',
                applyYear: applyYearDiscover,
              };
            }),
          );
        })(isTv, page);
      }
    }

    if (
      personId != null ||
      tmdbParsedHasGenre(parsed) ||
      bounds != null ||
      tmdbParsedHasScore(parsed) ||
      !!parsed.mediaType ||
      !!parsed.originCountry
    ) {
      if (tmdbParsedHasGenre(parsed)) {
        if (wantMovies && parsed.movieGenreIds.length) {
          pushDiscover(false, parsed.movieGenreIds, personId);
        }
        if (wantTv) {
          var tvGenres = parsed.tvGenreIds.length
            ? parsed.tvGenreIds
            : parsed.movieGenreIds;
          if (tvGenres.length) pushDiscover(true, tvGenres, personId);
        }
      } else if (personId != null) {
        if (wantMovies) pushDiscover(false, null, personId);
        if (wantTv) pushDiscover(true, null, personId);
      } else if (!hasPersonCandidate) {
        if (wantMovies) pushDiscover(false, null, null);
        if (wantTv) pushDiscover(true, null, null);
      }
    }

    return Promise.all(chunkPromises).then(function (chunks) {
      var seen = {};
      var out = [];

      function passesFilters(meta, applyYearFilter) {
        if (
          applyYearFilter &&
          bounds != null &&
          !tmdbReleaseInYearBounds(meta.releaseInfo, bounds)
        ) {
          return false;
        }
        if (parsed.mediaType && meta.type !== parsed.mediaType) return false;
        var score = Number(meta.rating) || 0;
        if (parsed.minScore != null && score < parsed.minScore) return false;
        if (parsed.maxScore != null && score > parsed.maxScore) return false;
        return true;
      }

      var ci;
      for (ci = 0; ci < chunks.length; ci++) {
        var chunk = chunks[ci];
        var rows = (chunk.json && chunk.json.results) || [];
        var ri;
        for (ri = 0; ri < rows.length; ri++) {
          var row = rows[ri];
          if (row && row.media_type === 'person') continue;
          var meta = tmdbMeta(cfg, row, chunk.forcedType || '');
          if (!meta) continue;
          if (!passesFilters(meta, chunk.applyYear)) continue;
          var key = meta.type + ':' + meta.ids.tmdb;
          if (seen[key]) continue;
          seen[key] = true;
          out.push(meta);
          if (limit > 0 && out.length >= limit) return out;
        }
      }
      return limit > 0 ? hubClampList(out, limit) : out;
    });
  });
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
    var hasFilter = params.filter != null && params.filter !== '';
    if (!q && !hasFilter) return hubItems('search', []);
    return wrap(
      tmdbStructuredSearch(ctx, cfg, params).then(function (items) {
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
      var pageSize =
        Number(params.limit) > 0 ? Number(params.limit) : TMDB_HOME_RAIL_CAP;
      return hubItems(
        'rail',
        items,
        { maxAge: 900, swr: 3600 },
        {
          pageSize: pageSize,
          hasMore: items.length >= pageSize,
        },
      )[0];
    }),
  );
}
