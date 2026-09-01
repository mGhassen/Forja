// TMDB enrich companion — not a data source.
// Host runs this after iptv-vod (`"enrich": "iptv-enrich-tmdb"`).
// Portal meta stays primary; this pack owns match + apply only.

var ENRICH_TMDB_DEFAULTS = {
  rails: ['spotlight'],
  limit: 5,
};

function enrichTmdbRails(cfg) {
  var raw = cfg && cfg.rails;
  if (!Array.isArray(raw) || !raw.length) return ['spotlight'];
  var out = [];
  for (var i = 0; i < raw.length; i++) {
    var id = String(raw[i] || '').trim();
    if (id) out.push(id);
  }
  return out.length ? out : ['spotlight'];
}

function enrichTmdbLimit(cfg) {
  var n = Number(cfg && cfg.limit);
  return n > 0 ? n : 5;
}

function enrichTmdbShouldRail(cfg, params) {
  var rail = String(params.rail || '').trim();
  if (!rail) return true;
  var allowed = enrichTmdbRails(cfg);
  for (var i = 0; i < allowed.length; i++) {
    if (allowed[i] === rail) return true;
  }
  return false;
}

function extract(ctx) {
  var action = hubAction(ctx);
  if (action !== 'enrich') {
    return hubFail(
      action,
      'INVALID_ACTION',
      'iptv-enrich-tmdb only supports action enrich',
    );
  }

  var cfg = hubConfig(ctx, ENRICH_TMDB_DEFAULTS);
  var params = hubParams(ctx);

  if (params.meta && typeof params.meta === 'object') {
    return hubEnrichTmdb(ctx, [params.meta], 1)
      .then(function (items) {
        return hubOk(
          'enrich',
          { meta: items[0] || params.meta },
          { maxAge: 900, swr: 3600 },
        );
      })
      .catch(function (e) {
        return hubFail('enrich', 'UPSTREAM', e && e.message, true);
      });
  }

  var items = Array.isArray(params.items) ? params.items : [];
  if (!enrichTmdbShouldRail(cfg, params)) {
    return hubOk('enrich', { items: items });
  }

  return hubEnrichTmdb(ctx, items, enrichTmdbLimit(cfg))
    .then(function (out) {
      return hubOk('enrich', { items: out }, { maxAge: 600, swr: 3600 });
    })
    .catch(function (e) {
      return hubFail('enrich', 'UPSTREAM', e && e.message, true);
    });
}
