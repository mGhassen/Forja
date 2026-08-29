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

function hubItems(action, items, cache) {
  return hubOk(action, { items: items || [] }, cache);
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
  if (ctx && ctx.host && ctx.host.tmdb && typeof ctx.host.tmdb.match === 'function') {
    return Promise.resolve(ctx.host.tmdb.match(normalized)).then(function (hit) {
      return hit && hit.id ? hit : null;
    }).catch(function () { return null; });
  }
  return hubTmdbMatchFetch(ctx, normalized);
}

function hubTmdbMatchFetch(ctx, query) {
  query = query || {};
  var title = hubNormalizeTitle(query.title);
  if (!title) return Promise.resolve(null);
  var cfg = hubConfig(ctx, {});
  var key = String(cfg.apiKey || '').trim();
  if (!key) return Promise.resolve(null);
  var prefer = String(query.type || '').trim().toLowerCase();
  var primary = prefer === 'movie' ? 'movie' : 'tv';
  var secondary = primary === 'movie' ? 'tv' : 'movie';
  var year = Number(query.year) > 0 ? Number(query.year) : 0;

  function search(media) {
    var url =
      'https://api.themoviedb.org/3/search/' +
      media +
      '?api_key=' +
      encodeURIComponent(key) +
      '&query=' +
      encodeURIComponent(title) +
      '&include_adult=false';
    return ctx.fetch(url).then(function (res) {
      if (!res.ok) return null;
      return res.json();
    }).then(function (json) {
      if (!json || !Array.isArray(json.results) || !json.results.length) return null;
      return hubTmdbPick(json.results, media, year);
    }).catch(function () { return null; });
  }

  return search(primary).then(function (hit) {
    return hit || search(secondary);
  });
}

function hubTmdbPick(results, media, year) {
  function yearOf(m) {
    var d = String(
      media === 'movie' ? m.release_date || '' : m.first_air_date || '',
    );
    if (d.length < 4) return 0;
    return Number(d.slice(0, 4)) || 0;
  }
  function withBackdrop(list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].backdrop_path) return list[i];
    }
    return list.length ? list[0] : null;
  }
  var chosen = null;
  if (year > 0) {
    var exact = [];
    var near = [];
    for (var i = 0; i < results.length; i++) {
      var y = yearOf(results[i]);
      if (y === year) exact.push(results[i]);
      else if (y && Math.abs(y - year) <= 1) near.push(results[i]);
    }
    chosen = withBackdrop(exact) || withBackdrop(near) || withBackdrop(results);
  } else {
    chosen = withBackdrop(results);
  }
  if (!chosen || !chosen.id) return null;
  var name = String(
    media === 'movie' ? chosen.title || '' : chosen.name || '',
  );
  var poster = chosen.poster_path
    ? 'https://image.tmdb.org/t/p/w500' + chosen.poster_path
    : '';
  var backdrop = chosen.backdrop_path
    ? 'https://image.tmdb.org/t/p/w1280' + chosen.backdrop_path
    : '';
  var overview = String(chosen.overview || '').trim();
  var rating = Number(chosen.vote_average);
  return {
    id: Number(chosen.id),
    mediaType: media,
    name: name,
    year: yearOf(chosen) || null,
    poster: poster || null,
    backdrop: backdrop || null,
    overview: overview || null,
    rating: rating > 0 ? rating : null,
  };
}

function hubApplyTmdbHit(meta, hit) {
  if (!meta || !hit || !hit.id) return meta;
  meta.ids = Object.assign({}, meta.ids || {}, { tmdb: String(hit.id) });
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
    poster: poster || null,
    backdrop: backdrop || null,
    overview: overview || null,
    rating: rating > 0 ? rating : null,
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
      encodeURIComponent(key);
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
        if (hit) return hubApplyTmdbHit(meta, hit);
        return hubTmdbMatch(ctx, {
          title: meta.name,
          year: year,
          type: prefer,
        }).then(function (matched) {
          return hubApplyTmdbHit(meta, matched);
        });
      });
    }),
  ).then(function (enriched) {
    return enriched.concat(tail);
  });
}

