// AniList anime hub — layout / rail / search / details (protocol 1).
// Row order matches the pre-CatalogShell Anime hub.

var ANILIST_DEFAULTS = {
  graphql: 'https://graphql.anilist.co',
  perPage: 24,
};

var ANILIST_MEDIA_FIELDS = [
  'id',
  'idMal',
  'title { romaji english native }',
  'coverImage { extraLarge large }',
  'bannerImage',
  'description(asHtml: false)',
  'averageScore',
  'genres',
  'seasonYear',
  'format',
  'episodes',
  'status',
].join(' ');

// Matches AnimeService section sorts.
var ANILIST_RAILS = {
  spotlight: { sort: ['TRENDING_DESC'] },
  trending: { sort: ['TRENDING_DESC'] },
  top_10: { sort: ['TRENDING_DESC'], limit: 10 },
  top_airing: { sort: ['POPULARITY_DESC'], status: 'RELEASING' },
  popular: { sort: ['POPULARITY_DESC'] },
  latest_episodes: { sort: ['UPDATED_AT_DESC'], status: 'RELEASING' },
  top_rated: { sort: ['SCORE_DESC'] },
  most_favorited: { sort: ['FAVOURITES_DESC'] },
  latest_completed: { sort: ['END_DATE_DESC'], status: 'FINISHED' },
};

var ANILIST_MOODS = [
  { id: 'shonen', label: 'Shōnen', genre: 'Action', icon: 'local_fire_department', accent: '#F97316' },
  { id: 'romance', label: 'Romance', genre: 'Romance', icon: 'favorite', accent: '#EC4899' },
  { id: 'comedy', label: 'Comedy', genre: 'Comedy', icon: 'emoji_emotions', accent: '#FBBF24' },
  { id: 'mystery', label: 'Mystery', genre: 'Mystery', icon: 'psychology', accent: '#8B5CF6' },
  { id: 'thriller', label: 'Thriller', genre: 'Thriller', icon: 'dark_mode', accent: '#64748B' },
  { id: 'fantasy', label: 'Fantasy', genre: 'Fantasy', icon: 'auto_awesome', accent: '#A855F7' },
  { id: 'sliceLife', label: 'Slice of Life', genre: 'Slice of Life', icon: 'wb_sunny', accent: '#06B6D4' },
  { id: 'scifi', label: 'Sci-Fi', genre: 'Sci-Fi', icon: 'rocket_launch', accent: '#3B82F6' },
  { id: 'sports', label: 'Sports', genre: 'Sports', icon: 'sports_soccer', accent: '#22C55E' },
  { id: 'horror', label: 'Horror', genre: 'Horror', icon: 'bedtime', accent: '#7C3AED' },
];

function anilistLayout() {
  return {
    pages: {
      anime: {
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'Spotlight',
            rail: 'spotlight',
            bleed: 'trending',
          },
          { type: 'host.continue', id: 'continue_watching' },
          {
            type: 'mood',
            id: 'moods',
            title: 'Pick your vibe',
            options: ANILIST_MOODS,
            rail: 'trending',
          },
          {
            type: 'rail',
            id: 'trending',
            title: 'Trending Now',
            rail: 'trending',
            hideWhenBleed: true,
            // Films / Series / Categories — Trending duplicates Top Rated.
            hideWhenTypeFilter: true,
          },
          { type: 'rail', id: 'top_airing', title: 'Top Airing', rail: 'top_airing' },
          { type: 'ranked', id: 'top_10', title: 'Top 10 Today', rail: 'top_10', style: 'numbered' },
          { type: 'rail', id: 'popular', title: 'Most Popular', rail: 'popular' },
          { type: 'rail', id: 'latest_episodes', title: 'Latest Episodes', rail: 'latest_episodes' },
          { type: 'rail', id: 'top_rated', title: 'Top Rated', rail: 'top_rated' },
          { type: 'rail', id: 'most_favorited', title: 'Most Favorited', rail: 'most_favorited' },
          { type: 'rail', id: 'latest_completed', title: 'Recently Completed', rail: 'latest_completed' },
        ],
      },
    },
  };
}

function anilistTitle(t) {
  if (!t) return '';
  return String(t.romaji || t.english || t.native || '').trim();
}

function anilistTmdbSearchTitle(m) {
  if (!m || !m.title) return anilistTitle(m && m.title);
  var english = String(m.title.english || '').trim();
  var romaji = String(m.title.romaji || '').trim();
  return english || romaji || anilistTitle(m.title);
}

function anilistCardMeta(m) {
  // Same as pre-CatalogShell `_animeCardMeta`: year • FILM / year • N eps.
  var parts = [];
  if (m.seasonYear) parts.push(String(m.seasonYear));
  var fmt = String(m.format || '').toUpperCase();
  if (fmt === 'TV' || fmt === 'TV_SHORT') {
    if (m.episodes) parts.push(String(m.episodes) + ' eps');
  } else if (fmt === 'MOVIE') {
    parts.push('FILM');
  } else if (fmt) {
    parts.push(fmt.replace(/_/g, ' '));
  } else if (m.episodes) {
    parts.push(String(m.episodes) + ' eps');
  }
  return parts.join(' • ');
}

function anilistMeta(m) {
  if (!m || !m.id) return null;
  var name = anilistTitle(m.title);
  if (!name) return null;
  var cover = m.coverImage || {};
  var ids = { anilist: String(m.id) };
  if (m.idMal) ids.mal = String(m.idMal);
  var searchTitle = anilistTmdbSearchTitle(m);
  if (searchTitle) ids.tmdbSearch = searchTitle;
  var banner = String(m.bannerImage || '');
  var poster = String(cover.extraLarge || cover.large || '');
  var meta = {
    id: 'anilist:' + m.id,
    type: 'anime',
    name: name,
    poster: poster,
    // Prefer AniList banner for hero; cover fallback matches old bannerOrCover.
    background: banner || poster,
    description: hubStripHtml(m.description),
    releaseInfo: anilistCardMeta(m),
    genres: Array.isArray(m.genres) ? m.genres : [],
    ids: ids,
    open: { surface: 'anime', id: String(m.id) },
  };
  if (m.idMal) meta.open.mal = String(m.idMal);
  if (m.averageScore) meta.rating = Number(m.averageScore) / 10;
  if (m.format) meta.badge = String(m.format).replace(/_/g, ' ');
  var fmt = String(m.format || '').toUpperCase();
  if (fmt === 'MOVIE') meta.tmdbMediaType = 'movie';
  else if (fmt) meta.tmdbMediaType = 'tv';
  if (m.status) meta.status = String(m.status);
  if (m.episodes) meta.episodes = Number(m.episodes);
  if (banner) meta.bannerImage = banner;
  return meta;
}

function anilistQuery(ctx, cfg, query, variables) {
  return ctx
    .fetch(cfg.graphql, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ query: query, variables: variables || {} }),
    })
    .then(function (res) {
      if (!res.ok) throw new Error('anilist HTTP ' + res.status);
      return res.json();
    })
    .then(function (json) {
      if (json && json.errors && json.errors.length) {
        throw new Error(json.errors[0].message || 'anilist error');
      }
      return json && json.data ? json.data : {};
    });
}

function anilistPage(ctx, cfg, params) {
  var railId = String(params.rail || 'trending');
  var spec = ANILIST_RAILS[railId] || ANILIST_RAILS.trending;
  var genre = hubFilterValue(params.filter, 'genre');
  var format = hubFilterValue(params.filter, 'format');
  var formatNot = hubFilterValue(params.filter, 'format_not');
  var perPage = Number(params.limit) > 0
    ? Number(params.limit)
    : Number(spec.limit) > 0
      ? Number(spec.limit)
      : Number(cfg.perPage) || 24;

  var query =
    'query ($page: Int, $perPage: Int, $sort: [MediaSort], $genre: String, $status: MediaStatus, $format: MediaFormat, $formatNotIn: [MediaFormat], $search: String) {' +
    ' Page(page: $page, perPage: $perPage) {' +
    '  media(type: ANIME, isAdult: false, sort: $sort, genre: $genre, status: $status, format: $format, format_not_in: $formatNotIn, search: $search) {' +
    ANILIST_MEDIA_FIELDS +
    '  }' +
    ' }' +
    '}';

  var variables = {
    page: Number(params.page) > 0 ? Number(params.page) : 1,
    perPage: perPage,
    sort: spec.sort,
  };
  if (genre) variables.genre = genre;
  if (format) variables.format = format;
  if (formatNot) variables.formatNotIn = [formatNot];
  if (spec.status) variables.status = spec.status;
  var search = String(params.query || '').trim();
  if (search) {
    variables.search = search;
    variables.sort = ['SEARCH_MATCH'];
  }

  return anilistQuery(ctx, cfg, query, variables).then(function (data) {
    var list = (data.Page && data.Page.media) || [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var meta = anilistMeta(list[i]);
      if (!meta) continue;
      // Spotlight: prefer airing / finished (same as spotlightFromTrending).
      if (railId === 'spotlight') {
        var st = String(meta.status || '').toUpperCase();
        if (st && st !== 'RELEASING' && st !== 'FINISHED') continue;
      }
      out.push(meta);
    }
    if (railId === 'spotlight' && !out.length) {
      for (var j = 0; j < list.length; j++) {
        var m2 = anilistMeta(list[j]);
        if (m2) out.push(m2);
      }
    }
    if (Number(spec.limit) > 0) out = out.slice(0, Number(spec.limit));
    return out;
  });
}

function anilistDetails(ctx, cfg, params) {
  var id = Number(String(params.id || '').split(':').pop());
  if (!id) {
    return Promise.resolve(
      hubFail('details', 'INVALID_PARAMS', 'details needs params.id'),
    );
  }
  var query =
    'query ($id: Int) { Media(id: $id, type: ANIME) { ' +
    ANILIST_MEDIA_FIELDS +
    ' } }';
  return anilistQuery(ctx, cfg, query, { id: id }).then(function (data) {
    var meta = anilistMeta(data.Media);
    if (!meta) return hubFail('details', 'NOT_FOUND', 'anime ' + id + ' not found');
    return hubOk('details', { meta: meta }, { maxAge: 1800, swr: 3600 });
  });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var cfg = hubConfig(ctx, ANILIST_DEFAULTS);
  var params = hubParams(ctx);

  if (action === 'layout') {
    return hubOk('layout', anilistLayout(), { maxAge: 3600, swr: 86400 });
  }
  if (action === 'filters') {
    return hubOk('filters', {
      fields: [{ field: 'genre', label: 'Genre', options: ANILIST_MOODS }],
    }, { maxAge: 86400 });
  }
  if (action === 'details') {
    return anilistDetails(ctx, cfg, params).catch(function (e) {
      return hubFail('details', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action !== 'rail' && action !== 'search') {
    return hubFail(action, 'INVALID_ACTION', 'anilist has no action ' + action);
  }

  return anilistPage(ctx, cfg, params)
    .then(function (items) {
      return hubItems(action, items, { maxAge: 600, swr: 3600 });
    })
    .catch(function (e) {
      return hubFail(action, 'UPSTREAM', e && e.message, true);
    });
}
