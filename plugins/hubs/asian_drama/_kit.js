// Forja catalog hub kit — shared envelope + request helpers (protocol 1).
//
// Host sets first-class `ctx.action` / `ctx.params` / `ctx.auth` / `ctx.cache`
// / `ctx.kit` / `ctx.protocol` (R70-A12). Older hosts may still put the request
// under `ctx.config.__request` — prefer top-level, fall back for one release.

var HUB_KIT = 1;
var HUB_PROTOCOL = 1;

function hubRequest(ctx) {
  if (ctx && ctx.params && typeof ctx.params === 'object') {
    return {
      action: ctx.action,
      params: ctx.params,
      auth: ctx.auth,
      cache: ctx.cache,
      kit: ctx.kit,
      protocol: ctx.protocol,
    };
  }
  var cfg = (ctx && ctx.config) || {};
  return cfg.__request || {};
}

function hubAction(ctx) {
  return String((ctx && ctx.action) || hubRequest(ctx).action || '');
}

function hubParams(ctx) {
  if (ctx && ctx.params && typeof ctx.params === 'object') return ctx.params;
  return hubRequest(ctx).params || {};
}

function hubAuth(ctx) {
  if (ctx && ctx.auth && typeof ctx.auth === 'object') return ctx.auth;
  return hubRequest(ctx).auth || {};
}

function hubCache(ctx) {
  if (ctx && ctx.cache && typeof ctx.cache === 'object') return ctx.cache;
  return hubRequest(ctx).cache || {};
}

function hubConfig(ctx, defaults) {
  var cfg = Object.assign({}, defaults || {}, (ctx && ctx.config) || {});
  delete cfg.__request;
  return cfg;
}

function hubOk(action, data, cache) {
  var env = {
    ok: true,
    kit: HUB_KIT,
    protocol: HUB_PROTOCOL,
    action: action,
    data: data || {},
  };
  if (cache) env.cache = cache;
  return [env];
}

function hubItems(action, items, cache, paging) {
  var data = { items: items || [] };
  if (paging && typeof paging === 'object') {
    if (Number(paging.pageSize) > 0) data.pageSize = Number(paging.pageSize);
    if (typeof paging.hasMore === 'boolean') data.hasMore = paging.hasMore;
  }
  return hubOk(action, data, cache);
}

function hubFail(action, code, message, retryable) {
  return [
    {
      ok: false,
      kit: HUB_KIT,
      protocol: HUB_PROTOCOL,
      action: action || '',
      error: {
        code: code || 'UPSTREAM',
        message: String(message || ''),
        retryable: retryable === true,
      },
    },
  ];
}

function hubNotModified(action) {
  return [
    {
      ok: true,
      kit: HUB_KIT,
      protocol: HUB_PROTOCOL,
      action: action,
      notModified: true,
      data: {},
    },
  ];
}

function hubClampList(list, limit) {
  if (!Array.isArray(list)) return [];
  var n = Number(limit);
  if (!(n > 0) || n >= list.length) return list.slice();
  return list.slice(0, n);
}

function hubFilterLeaves(filter, field) {
  if (!filter || typeof filter !== 'object') return [];
  var op = String(filter.op || '');
  if (op === 'and' || op === 'or') {
    var out = [];
    var nodes = filter.nodes || [];
    for (var i = 0; i < nodes.length; i++) {
      out = out.concat(hubFilterLeaves(nodes[i], field));
    }
    return out;
  }
  if (String(filter.field || '') !== String(field || '')) return [];
  return [filter];
}

function hubFilterValues(filter, field) {
  var leaves = hubFilterLeaves(filter, field);
  var out = [];
  for (var i = 0; i < leaves.length; i++) {
    var leaf = leaves[i];
    var op = String(leaf.op || '');
    if (op === 'in' && Array.isArray(leaf.value)) {
      for (var j = 0; j < leaf.value.length; j++) {
        var v = leaf.value[j];
        if (v != null && String(v).trim()) out.push(String(v).trim());
      }
    } else if (leaf.value != null && String(leaf.value).trim()) {
      out.push(String(leaf.value).trim());
    }
  }
  return out;
}

function hubFilterValue(filter, field) {
  var values = hubFilterValues(filter, field);
  return values.length ? values[0] : '';
}


function hubStripHtml(html) {
  if (html == null) return '';
  return String(html)
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function hubNormalizeTitle(raw) {
  var t = String(raw || '').trim();
  if (!t) return t;
  t = t.replace(/[\(\[]\s*\d{4}\s*[\)\]]\s*$/g, '').trim();
  t = t.replace(
    /\b(HD|FHD|UHD|4K|1080p|720p|WEB-?DL|BluRay)\b/gi,
    ' ',
  );
  var pipe = t.indexOf('|');
  if (pipe > 0) t = t.substring(0, pipe);
  return t.replace(/\s+/g, ' ').trim();
}

function hubTmdbMatch(ctx, query) {
  query = query || {};
  var title = hubNormalizeTitle(query.title);
  if (!title) return Promise.resolve(null);
  var normalized = Object.assign({}, query, { title: title });
  function fetchJs() {
    return hubTmdbMatchFetch(ctx, normalized);
  }
  if (ctx && ctx.host && ctx.host.tmdb && typeof ctx.host.tmdb.match === 'function') {
    return Promise.resolve(ctx.host.tmdb.match(normalized))
      .then(function (hit) {
        if (hit && hit.id) return hit;
        return fetchJs();
      })
      .catch(function () {
        return fetchJs();
      });
  }
  return fetchJs();
}

function hubTmdbMultiTitle(hit) {
  if (!hit) return '';
  var mt = String(hit.media_type || '').toLowerCase();
  if (mt === 'movie') return String(hit.title || '').trim();
  return String(hit.name || hit.title || '').trim();
}

function hubTmdbMultiYear(hit) {
  var mt = String(hit.media_type || '').toLowerCase();
  var d = String(
    mt === 'movie' ? hit.release_date || '' : hit.first_air_date || '',
  );
  if (d.length < 4) return 0;
  return Number(d.slice(0, 4)) || 0;
}

function hubTmdbHitFromMultiRow(row) {
  if (!row || !row.id) return null;
  var mt = String(row.media_type || '').toLowerCase();
  if (mt !== 'movie' && mt !== 'tv') return null;
  var name = hubTmdbMultiTitle(row);
  var poster = row.poster_path
    ? 'https://image.tmdb.org/t/p/w500' + row.poster_path
    : '';
  var backdrop = row.backdrop_path
    ? 'https://image.tmdb.org/t/p/w1280' + row.backdrop_path
    : '';
  var overview = String(row.overview || '').trim();
  var rating = Number(row.vote_average);
  var year = hubTmdbMultiYear(row);
  return {
    id: Number(row.id),
    mediaType: mt,
    name: name,
    year: year > 0 ? year : null,
    poster: poster || null,
    backdrop: backdrop || null,
    overview: overview || null,
    rating: rating > 0 ? rating : null,
  };
}

function hubTmdbScoreMultiResults(results, queryTitle, wantMovie, wantYear, normalizeFn) {
  if (!Array.isArray(results) || !results.length) return null;
  var q = normalizeFn(String(queryTitle || ''));
  if (!q) return null;
  var qt = q.toLowerCase();
  var best = null;
  var bestScore = -1;
  for (var i = 0; i < results.length; i++) {
    var h = results[i];
    if (!h || !h.id) continue;
    var mt = String(h.media_type || '').toLowerCase();
    if (mt !== 'movie' && mt !== 'tv') continue;
    var ht = normalizeFn(hubTmdbMultiTitle(h)).toLowerCase();
    var s = 0;
    if (ht === qt) {
      s += 5;
    } else if (ht.indexOf(qt) === 0 || qt.indexOf(ht) === 0) {
      s += 2;
    } else if (ht.indexOf(qt) >= 0 || qt.indexOf(ht) >= 0) {
      s += 1;
    } else {
      continue;
    }
    if (wantMovie) {
      if (mt === 'movie') s += 3;
      else if (mt === 'tv') s += 1;
    } else {
      if (mt === 'tv') s += 3;
      else if (mt === 'movie') s += 1;
    }
    if (wantYear > 0) {
      var hy = hubTmdbMultiYear(h);
      if (hy === wantYear) s += 4;
      else if (hy && Math.abs(hy - wantYear) <= 1) s += 1;
    }
    if (s > bestScore) {
      bestScore = s;
      best = h;
    }
  }
  if (!best || bestScore < 2) return null;
  return hubTmdbHitFromMultiRow(best);
}

function hubTmdbMatchFetch(ctx, query) {
  query = query || {};
  var title = hubNormalizeTitle(query.title);
  if (!title) return Promise.resolve(null);
  var cfg = hubConfig(ctx, {});
  var key = String(cfg.apiKey || '').trim();
  if (!key) return Promise.resolve(null);
  var prefer = String(query.type || '').trim().toLowerCase();
  var wantMovie = prefer === 'movie';
  var year = Number(query.year) > 0 ? Number(query.year) : 0;
  var url =
    'https://api.themoviedb.org/3/search/multi?api_key=' +
    encodeURIComponent(key) +
    '&query=' +
    encodeURIComponent(title) +
    '&include_adult=false';
  return ctx
    .fetch(url)
    .then(function (res) {
      if (!res.ok) return null;
      return res.json();
    })
    .then(function (json) {
      if (!json || !Array.isArray(json.results)) return null;
      return hubTmdbScoreMultiResults(
        json.results,
        title,
        wantMovie,
        year,
        hubNormalizeTitle,
      );
    })
    .catch(function () {
      return null;
    });
}

function hubApplyTmdbHit(meta, hit) {
  if (!meta || !hit || !hit.id) return meta;
  meta.ids = Object.assign({}, meta.ids || {}, { tmdb: String(hit.id) });
  if (hit.imdb) {
    meta.ids.imdb = String(hit.imdb);
  }
  if (hit.mediaType) meta.tmdbMediaType = String(hit.mediaType);
  if (hit.backdrop) {
    meta.background = String(hit.backdrop);
    meta.bannerImage = '';
  } else if (hit.poster && !meta.poster) {
    meta.poster = String(hit.poster);
  }
  // Fill synopsis / score only when the pack left them empty (AniList keeps its own).
  if (hit.overview && !String(meta.description || '').trim()) {
    meta.description = String(hit.overview);
  }
  if (hit.rating != null && !(Number(meta.rating) > 0)) {
    meta.rating = Number(hit.rating);
  }
  if (hit.premiereDate && !String(meta.premiereDate || '').trim()) {
    meta.premiereDate = String(hit.premiereDate);
  }
  if (
    hit.premiereDate &&
    hubIsFutureIsoDate(hit.premiereDate) &&
    !String(meta.status || '').trim()
  ) {
    meta.status = 'NOT_YET_RELEASED';
  }
  meta._hubTmdbEnriched = true;
  return meta;
}

function hubEnrichPreferType(meta) {
  var prefer = String(meta.tmdbMediaType || '').toLowerCase();
  if (prefer === 'movie' || prefer === 'tv') return prefer;
  if (prefer === 'tvseries' || prefer === 'anime') return 'tv';
  var fmt = String(meta.badge || '').toUpperCase();
  if (fmt === 'MOVIE' || fmt === 'FILM' || fmt === 'HOLLYWOOD') return 'movie';
  if (fmt === 'TV' || fmt === 'SERIES' || fmt === 'TVSERIES' || fmt === 'ANIME') {
    return 'tv';
  }
  return 'tv';
}

function hubEnrichMetaTmdbId(meta) {
  if (!meta || !meta.ids) return 0;
  var raw = meta.ids.tmdb != null ? meta.ids.tmdb : meta.ids.TMDB;
  var n = Number(raw);
  return n > 0 ? n : 0;
}

function hubTmdbHitFromDetails(json, media) {
  if (!json || !json.id) return null;
  var poster = json.poster_path
    ? 'https://image.tmdb.org/t/p/w500' + json.poster_path
    : '';
  var backdrop = json.backdrop_path
    ? 'https://image.tmdb.org/t/p/w1280' + json.backdrop_path
    : '';
  var name = String(
    media === 'movie' ? json.title || '' : json.name || '',
  );
  var overview = String(json.overview || '').trim();
  var rating = Number(json.vote_average);
  var date = String(
    media === 'movie' ? json.release_date || '' : json.first_air_date || '',
  );
  return {
    id: Number(json.id),
    mediaType: media,
    name: name,
    year: date.length >= 4 ? Number(date.slice(0, 4)) || null : null,
    premiereDate: hubParseIsoDate(date),
    poster: poster || null,
    backdrop: backdrop || null,
    overview: overview || null,
    rating: rating > 0 ? rating : null,
    imdb: (function () {
      var ext = json.external_ids || {};
      var id = String(ext.imdb_id || '').trim();
      return id || null;
    })(),
  };
}

// Prefer KissKH/AniList embedded TMDB id (same as details) before title search.
function hubTmdbById(ctx, id, preferType) {
  var tid = Number(id);
  if (!(tid > 0)) return Promise.resolve(null);
  var primary = preferType === 'movie' ? 'movie' : 'tv';
  var secondary = primary === 'movie' ? 'tv' : 'movie';
  var cfg = hubConfig(ctx, {});
  var key = String(cfg.apiKey || '').trim();
  if (!key) return Promise.resolve(null);

  function fetchOne(media) {
    var url =
      'https://api.themoviedb.org/3/' +
      media +
      '/' +
      tid +
      '?api_key=' +
      encodeURIComponent(key) +
      '&append_to_response=external_ids';
    return ctx
      .fetch(url)
      .then(function (res) {
        if (!res.ok) return null;
        return res.json();
      })
      .then(function (json) {
        return hubTmdbHitFromDetails(json, media);
      })
      .catch(function () {
        return null;
      });
  }

  return fetchOne(primary).then(function (hit) {
    return hit || fetchOne(secondary);
  });
}

function hubParseIsoDate(raw) {
  var s = String(raw || '').trim();
  if (s.length >= 10 && /^\d{4}-\d{2}-\d{2}/.test(s)) return s.substring(0, 10);
  return '';
}

function hubIsFutureIsoDate(iso) {
  var s = hubParseIsoDate(iso);
  if (!s) return false;
  var parts = s.split('-');
  var y = Number(parts[0]);
  var m = Number(parts[1]);
  var d = Number(parts[2]);
  if (!(y > 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31)) return false;
  var air = new Date(y, m - 1, d);
  var now = new Date();
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return air.getTime() > today.getTime();
}

function hubTmdbEpisodeStillUrl(path) {
  var p = String(path || '').trim();
  if (!p) return '';
  if (p.indexOf('http') === 0) return p;
  return 'https://image.tmdb.org/t/p/w300' + p;
}

function hubTmdbSeasonEpisodeMap(ctx, tvId, season) {
  var cfg = hubConfig(ctx, {});
  var key = String(cfg.apiKey || '').trim();
  if (!key || !(Number(tvId) > 0) || !(Number(season) > 0)) {
    return Promise.resolve({});
  }
  var url =
    'https://api.themoviedb.org/3/tv/' +
    Number(tvId) +
    '/season/' +
    Number(season) +
    '?api_key=' +
    encodeURIComponent(key);
  return ctx
    .fetch(url)
    .then(function (res) {
      if (!res.ok) return {};
      return res.json();
    })
    .then(function (json) {
      var out = {};
      var eps = json && Array.isArray(json.episodes) ? json.episodes : [];
      for (var i = 0; i < eps.length; i++) {
        var e = eps[i] || {};
        var n = Number(e.episode_number);
        if (!(n > 0)) continue;
        out[n] = {
          still: e.still_path ? hubTmdbEpisodeStillUrl(e.still_path) : '',
          name: String(e.name || '').trim(),
          overview: String(e.overview || '').trim(),
          air_date: hubParseIsoDate(e.air_date),
          aired: e.air_date ? !hubIsFutureIsoDate(e.air_date) : undefined,
        };
      }
      return out;
    })
    .catch(function () {
      return {};
    });
}

function hubIsGenericEpisodeTitle(title) {
  return /^Episode\s+\d+$/i.test(String(title || '').trim());
}

// Details meta only — fill empty pack video thumbs/titles from matched TV season.
function hubEnrichMetaVideos(ctx, meta, hit) {
  if (!meta || !hit || !hit.id) return Promise.resolve(meta);
  if (String(hit.mediaType || '').toLowerCase() === 'movie') {
    return Promise.resolve(meta);
  }
  var videos = Array.isArray(meta.videos) ? meta.videos : [];
  if (!videos.length) return Promise.resolve(meta);

  var seasonSet = {};
  for (var i = 0; i < videos.length; i++) {
    var v = videos[i];
    if (!v || typeof v !== 'object') continue;
    var season = Number(v.season) > 0 ? Number(v.season) : 1;
    seasonSet[season] = true;
  }
  var seasonNums = Object.keys(seasonSet).map(Number).filter(function (n) {
    return n > 0;
  });
  if (!seasonNums.length) return Promise.resolve(meta);

  return Promise.all(
    seasonNums.map(function (season) {
      return hubTmdbSeasonEpisodeMap(ctx, hit.id, season);
    }),
  ).then(function (maps) {
    var epBySeason = {};
    for (var si = 0; si < seasonNums.length; si++) {
      epBySeason[seasonNums[si]] = maps[si] || {};
    }
    for (var vi = 0; vi < videos.length; vi++) {
      var vid = videos[vi];
      if (!vid || typeof vid !== 'object') continue;
      var s = Number(vid.season) > 0 ? Number(vid.season) : 1;
      var ep = Number(vid.episode) > 0 ? Number(vid.episode) : vi + 1;
      var extras = (epBySeason[s] || {})[ep];
      if (!extras) continue;
      if (!String(vid.thumbnail || '').trim() && extras.still) {
        vid.thumbnail = extras.still;
      }
      if (
        extras.name &&
        (!String(vid.title || '').trim() ||
          hubIsGenericEpisodeTitle(vid.title))
      ) {
        vid.title = extras.name;
      }
      if (!String(vid.overview || '').trim() && extras.overview) {
        vid.overview = extras.overview;
      }
      if (!String(vid.airDate || vid.air_date || '').trim() && extras.air_date) {
        vid.airDate = extras.air_date;
      }
      if (vid.aired == null && extras.air_date) {
        vid.aired = extras.aired !== false && !hubIsFutureIsoDate(extras.air_date);
      }
    }
    return meta;
  });
}

function hubTmdbFetchImdb(ctx, media, id) {
  var cfg = hubConfig(ctx, {});
  var key = String(cfg.apiKey || '').trim();
  var mid = Number(id);
  var kind = String(media || '').toLowerCase();
  if (!key || !(mid > 0) || (kind !== 'movie' && kind !== 'tv')) {
    return Promise.resolve('');
  }
  var url =
    'https://api.themoviedb.org/3/' +
    kind +
    '/' +
    mid +
    '/external_ids?api_key=' +
    encodeURIComponent(key);
  return ctx
    .fetch(url)
    .then(function (res) {
      if (!res.ok) return '';
      return res.json();
    })
    .then(function (json) {
      return String((json && json.imdb_id) || '').trim();
    })
    .catch(function () {
      return '';
    });
}

function hubTmdbAttachImdb(ctx, meta, hit) {
  if (!meta || !hit || !hit.id) return Promise.resolve(meta);
  if (meta.ids && meta.ids.imdb) return Promise.resolve(meta);
  if (hit.imdb) {
    meta.ids = Object.assign({}, meta.ids || {}, { imdb: String(hit.imdb) });
    return Promise.resolve(meta);
  }
  var media = String(hit.mediaType || meta.tmdbMediaType || 'tv').toLowerCase();
  return hubTmdbFetchImdb(ctx, media, hit.id).then(function (imdb) {
    if (imdb) {
      meta.ids = Object.assign({}, meta.ids || {}, { imdb: imdb });
    }
    return meta;
  });
}

function hubEnrichTmdb(ctx, items, limit) {
  if (!Array.isArray(items) || !items.length) return Promise.resolve(items || []);
  var n = Number(limit) > 0 ? Number(limit) : items.length;
  var head = items.slice(0, n);
  var tail = items.slice(n);
  return Promise.all(
    head.map(function (meta) {
      var prefer = hubEnrichPreferType(meta);
      var yearBit = String(meta.releaseInfo || '').split(' • ')[0];
      var year = Number(yearBit) || 0;
      var existingId = hubEnrichMetaTmdbId(meta);
      var start = existingId
        ? hubTmdbById(ctx, existingId, prefer)
        : Promise.resolve(null);
      return start.then(function (hit) {
        function finish(applied, matchedHit) {
          if (!applied || !matchedHit || !matchedHit.id) {
            return Promise.resolve(applied);
          }
          return hubEnrichMetaVideos(ctx, applied, matchedHit).then(
            function (withVideos) {
              return hubTmdbAttachImdb(ctx, withVideos, matchedHit);
            },
          );
        }
        if (hit) return finish(hubApplyTmdbHit(meta, hit), hit);
        return hubTmdbMatch(ctx, {
          title: meta.name,
          year: year,
          type: prefer,
        }).then(function (matched) {
          return finish(hubApplyTmdbHit(meta, matched), matched);
        });
      });
    }),
  ).then(function (enriched) {
    return enriched.concat(tail);
  });
}

