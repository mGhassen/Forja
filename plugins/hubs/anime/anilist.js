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

var ANILIST_DETAILS_FIELDS = [
  ANILIST_MEDIA_FIELDS,
  'nextAiringEpisode { episode airingAt }',
  'streamingEpisodes { title thumbnail }',
  'relations { edges { relationType(version: 2) node { ' +
    ANILIST_MEDIA_FIELDS +
    ' type } } }',
].join(' ');

var ANILIST_RELATION_KEEP = {
  SIDE_STORY: 0,
  SUMMARY: 1,
  ALTERNATIVE: 2,
  SPIN_OFF: 3,
  SEQUEL: 4,
  PREQUEL: 5,
  PARENT: 6,
  COMPILATION: 7,
  CONTAINS: 8,
  OTHER: 9,
};

var ANILIST_RELATION_TYPES = Object.keys(ANILIST_RELATION_KEEP);

var ANILIST_RELATION_FORMATS = {
  TV: true,
  TV_SHORT: true,
  MOVIE: true,
  OVA: true,
  ONA: true,
  SPECIAL: true,
};

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
        feed: true,
        pageSize: Number(ANILIST_DEFAULTS.perPage) || 24,
        widgets: [
          {
            type: 'hero',
            id: 'spotlight',
            title: 'Spotlight',
            rail: 'spotlight',
            bleed: 'trending',
          },
          { type: 'continue', id: 'continue_watching' },
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
          { type: 'ranked', id: 'top_10', title: 'Top 10 Today', rail: 'top_10', style: 'numbered', pageSize: 10 },
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
    open: {
      surface: 'anime',
      id: String(m.id),
      extract: {
        resolveType: 'anime',
        panelCategory: 'anime',
        ctx: {
          anilistId: Number(m.id),
          malId: m.idMal ? Number(m.idMal) : undefined,
        },
      },
    },
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

function anilistVideosFromMedia(m) {
  var stream = Array.isArray(m.streamingEpisodes) ? m.streamingEpisodes : [];
  if (stream.length) {
    var out = [];
    for (var i = 0; i < stream.length; i++) {
      var ep = stream[i] || {};
      var num = i + 1;
      out.push({
        id: String(num),
        episode: num,
        season: 1,
        title: String(ep.title || '').trim() || 'Episode ' + num,
        thumbnail: String(ep.thumbnail || '').trim(),
      });
    }
    return out;
  }
  var count = Number(m.episodes) || 0;
  if (count <= 0 && m.nextAiringEpisode && m.nextAiringEpisode.episode) {
    count = Number(m.nextAiringEpisode.episode);
  }
  if (count <= 0) return [];
  var videos = [];
  for (var j = 1; j <= count; j++) {
    videos.push({
      id: String(j),
      episode: j,
      season: 1,
      title: 'Episode ' + j,
    });
  }
  return videos;
}

function anilistRelatedFromMedia(m) {
  var edges =
    m &&
    m.relations &&
    Array.isArray(m.relations.edges)
      ? m.relations.edges
      : [];
  var out = [];
  var seen = {};
  for (var i = 0; i < edges.length; i++) {
    var e = edges[i] || {};
    var type = String(e.relationType || '');
    if (ANILIST_RELATION_TYPES.indexOf(type) < 0) continue;
    var node = e.node;
    if (!node || String(node.type || 'ANIME') !== 'ANIME') continue;
    var fmt = String(node.format || '').toUpperCase();
    if (!fmt || !ANILIST_RELATION_FORMATS[fmt]) continue;
    var id = Number(node.id);
    if (!(id > 0) || seen[id]) continue;
    seen[id] = true;
    var meta = anilistMeta(node);
    if (!meta) continue;
    meta.relationType = type;
    out.push(meta);
  }
  out.sort(function (a, b) {
    var ra = ANILIST_RELATION_KEEP[a.relationType] ?? 99;
    var rb = ANILIST_RELATION_KEEP[b.relationType] ?? 99;
    if (ra !== rb) return ra - rb;
    return String(a.name || '').localeCompare(String(b.name || ''));
  });
  return out;
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

function anilistRailItemsFromList(railId, list) {
  var out = [];
  for (var i = 0; i < list.length; i++) {
    var meta = anilistMeta(list[i]);
    if (!meta) continue;
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
  var spec = ANILIST_RAILS[railId] || ANILIST_RAILS.trending;
  if (Number(spec.limit) > 0) out = out.slice(0, Number(spec.limit));
  return out;
}

function anilistFeedQuery(cfg, params) {
  var genre = hubFilterValue(params.filter, 'genre');
  var format = hubFilterValue(params.filter, 'format');
  var formatNot = hubFilterValue(params.filter, 'format_not');
  var perPage = Number(cfg.perPage) || 24;
  var parts = [];
  for (var railId in ANILIST_RAILS) {
    if (!Object.prototype.hasOwnProperty.call(ANILIST_RAILS, railId)) continue;
    var spec = ANILIST_RAILS[railId];
    var limit = Number(spec.limit) > 0 ? Number(spec.limit) : perPage;
    var sort = spec.sort.join(', ');
    var status = spec.status ? ', status: ' + spec.status : '';
    parts.push(
      railId +
        ': Page(page: 1, perPage: ' +
        limit +
        ') { media(type: ANIME, isAdult: false, sort: [' +
        sort +
        ']' +
        status +
        ', genre: $genre, format: $format, format_not_in: $formatNotIn) { ' +
        ANILIST_MEDIA_FIELDS +
        ' } }',
    );
  }
  return (
    'query AnilistFeed($genre: String, $format: MediaFormat, $formatNotIn: [MediaFormat]) { ' +
    parts.join(' ') +
    ' }'
  );
}

function anilistFeedVariables(params) {
  var genre = hubFilterValue(params.filter, 'genre');
  var format = hubFilterValue(params.filter, 'format');
  var formatNot = hubFilterValue(params.filter, 'format_not');
  var variables = {};
  if (genre) variables.genre = genre;
  if (format) variables.format = format;
  if (formatNot) variables.formatNotIn = [formatNot];
  return variables;
}

function anilistFeed(ctx, cfg, params) {
  return anilistQuery(ctx, cfg, anilistFeedQuery(cfg, params), anilistFeedVariables(params))
    .then(function (data) {
      var rails = {};
      for (var railId in ANILIST_RAILS) {
        if (!Object.prototype.hasOwnProperty.call(ANILIST_RAILS, railId)) continue;
        var page = data[railId] || {};
        rails[railId] = anilistRailItemsFromList(railId, page.media || []);
      }
      return hubOk('feed', { rails: rails }, { maxAge: 600, swr: 3600 });
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
    return anilistRailItemsFromList(railId, list);
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
    ANILIST_DETAILS_FIELDS +
    ' } }';
  return anilistQuery(ctx, cfg, query, { id: id }).then(function (data) {
    var media = data.Media;
    var meta = anilistMeta(media);
    if (!meta) return hubFail('details', 'NOT_FOUND', 'anime ' + id + ' not found');
    var videos = anilistVideosFromMedia(media);
    if (videos.length) meta.videos = videos;
    var related = anilistRelatedFromMedia(media);
    var payload = { meta: meta };
    if (related.length) {
      payload.rails = {
        related: { title: 'Related', items: related },
      };
    }
    return hubOk('details', payload, { maxAge: 1800, swr: 3600 });
  });
}

function anilistCategoryOptions() {
  return ANILIST_MOODS.map(function (m) {
    return {
      id: m.id,
      label: m.label,
      genre: m.genre,
      filter: { op: 'eq', field: 'genre', value: m.genre },
    };
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
      fields: [{ field: 'genre', label: 'Genre', options: anilistCategoryOptions() }],
      media: {
        films: { op: 'eq', field: 'format', value: 'MOVIE' },
        series: { op: 'eq', field: 'format_not', value: 'MOVIE' },
      },
      play: [
        {
          id: 'audio',
          field: 'category',
          style: 'grouped',
          default: 'sub',
          options: [
            { id: 'sub', label: 'SUB', value: 'sub', icon: 'subtitles' },
            { id: 'dub', label: 'DUB', value: 'dub', icon: 'mic' },
          ],
        },
      ],
    }, { maxAge: 86400 });
  }
  if (action === 'details') {
    return anilistDetails(ctx, cfg, params).catch(function (e) {
      return hubFail('details', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action === 'feed') {
    return anilistFeed(ctx, cfg, params).catch(function (e) {
      return hubFail('feed', 'UPSTREAM', e && e.message, true);
    });
  }
  if (action !== 'rail' && action !== 'search') {
    return hubFail(action, 'INVALID_ACTION', 'anilist has no action ' + action);
  }

  return anilistPage(ctx, cfg, params)
    .then(function (items) {
      var perPage =
        Number(params.limit) > 0
          ? Number(params.limit)
          : Number(cfg.perPage) || 24;
      return hubItems(
        action,
        items,
        { maxAge: 600, swr: 3600 },
        { pageSize: perPage },
      );
    })
    .catch(function (e) {
      return hubFail(action, 'UPSTREAM', e && e.message, true);
    });
}
