var SPECS = {
  api: 'https://api.dailymotion.com',
  origin: 'https://www.dailymotion.com',
  tmdbKey: '439c478a771f35c05022f9feabcca01c',
  searchLimit: 12,
  maxResolve: 6,
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var api = String(cfg.api || '').replace(/\/$/, '');
  var origin = String(cfg.origin || 'https://www.dailymotion.com').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var searchLimit = Math.max(1, Math.min(25, parseInt(cfg.searchLimit, 10) || 12));
  var maxResolve = Math.max(1, Math.min(12, parseInt(cfg.maxResolve, 10) || 6));
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var isTv = ctx.type !== 'movie';
  var tmdbId = String(ctx.tmdbId || '').trim();
  var season = parseInt(ctx.season, 10) || 1;
  var episode = parseInt(ctx.episode, 10) || 1;
  if (!api || !tmdbKey || !tmdbId) return Promise.resolve([]);

  function getJson(url, headers) {
    return ctx.fetch(url, { headers: headers || { 'User-Agent': ua, Accept: 'application/json' } }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }

  function pad2(n) {
    var s = String(n);
    return s.length >= 2 ? s : '0' + s;
  }

  function normalizeTitle(s) {
    return String(s || '')
      .toLowerCase()
      .replace(/['']/g, '')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function titleTokens(s) {
    return normalizeTitle(s)
      .split(' ')
      .filter(function (t) {
        return t.length > 1 && ['the', 'and', 'of', 'a', 'an'].indexOf(t) < 0;
      });
  }

  function scoreHit(hit, meta) {
    var title = normalizeTitle(hit.title);
    var want = normalizeTitle(meta.title);
    if (!title || !want) return 0;
    var score = 0;
    if (title === want || title.indexOf(want) >= 0 || want.indexOf(title) >= 0) score += 40;
    var tokens = titleTokens(meta.title);
    var matched = 0;
    for (var i = 0; i < tokens.length; i++) {
      if (title.indexOf(tokens[i]) >= 0) matched++;
    }
    if (tokens.length) score += Math.round((matched / tokens.length) * 30);
    if (meta.year && title.indexOf(String(meta.year)) >= 0) score += 15;
    var dur = parseInt(hit.duration, 10) || 0;
    if (isTv) {
      var epPat = new RegExp(
        '(?:s\\s*0*' +
          season +
          '\\s*e\\s*0*' +
          episode +
          '|season\\s*0*' +
          season +
          '.*?episode\\s*0*' +
          episode +
          '|0*' +
          season +
          'x0*' +
          episode +
          ')',
        'i',
      );
      if (epPat.test(hit.title || '')) score += 35;
      if (dur >= 15 * 60 && dur <= 90 * 60) score += 10;
      if (dur > 0 && dur < 8 * 60) score -= 25;
    } else {
      if (dur >= 50 * 60) score += 25;
      if (dur >= 80 * 60) score += 10;
      if (dur > 0 && dur < 20 * 60) score -= 40;
    }
    if (/trailer|teaser|clip|scene|ost|soundtrack|review|reaction|recap|behind the scenes/i.test(hit.title || '')) {
      score -= 50;
    }
    if (/full\s*(movie|film|episode)|watch\s+online/i.test(hit.title || '')) score += 8;
    var views = parseInt(hit.views_total, 10) || 0;
    if (views > 1000) score += 3;
    return score;
  }

  function tmdbMeta() {
    var kind = isTv ? 'tv' : 'movie';
    return getJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(tmdbId) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
    ).then(function (d) {
      var title = isTv ? d.name || d.original_name : d.title || d.original_title;
      var date = isTv ? d.first_air_date : d.release_date;
      var year = date ? parseInt(String(date).slice(0, 4), 10) : 0;
      return { title: String(title || '').trim(), year: year || 0 };
    });
  }

  function searchQueries(meta) {
    var q = [];
    var base = meta.title;
    if (!base) return q;
    if (isTv) {
      q.push(base + ' S' + pad2(season) + 'E' + pad2(episode));
      q.push(base + ' season ' + season + ' episode ' + episode);
      q.push(base + ' ' + season + 'x' + pad2(episode));
    } else {
      if (meta.year) q.push(base + ' ' + meta.year + ' full movie');
      q.push(base + ' full movie');
      if (meta.year) q.push(base + ' ' + meta.year);
    }
    return q;
  }

  function searchOnce(query) {
    var url =
      api +
      '/videos?search=' +
      encodeURIComponent(query) +
      '&fields=id,title,url,duration,views_total,language,channel' +
      '&limit=' +
      searchLimit +
      '&sort=relevance&password_protected=false&private=false';
    return getJson(url)
      .then(function (d) {
        return (d && d.list) || [];
      })
      .catch(function () {
        return [];
      });
  }

  function resolveHit(hit) {
    var videoUrl = hit.url || origin + '/video/' + hit.id;
    var label = 'Dailymotion · ' + String(hit.title || hit.id || '').slice(0, 48);
    return ctx.hop(videoUrl).then(function (rows) {
      return (rows || []).map(function (row) {
        return Object.assign({}, row, {
          name: label,
          quality: row.quality || 'Auto',
        });
      });
    });
  }

  return tmdbMeta()
    .then(function (meta) {
      if (!meta.title) return [];
      return Promise.all(searchQueries(meta).map(searchOnce)).then(function (lists) {
        var byId = {};
        for (var i = 0; i < lists.length; i++) {
          var list = lists[i] || [];
          for (var j = 0; j < list.length; j++) {
            var hit = list[j];
            if (!hit || !hit.id) continue;
            var sc = scoreHit(hit, meta);
            if (!byId[hit.id] || byId[hit.id].score < sc) {
              byId[hit.id] = { hit: hit, score: sc };
            }
          }
        }
        var ranked = Object.keys(byId)
          .map(function (id) {
            return byId[id];
          })
          .filter(function (x) {
            return x.score >= 35;
          })
          .sort(function (a, b) {
            return b.score - a.score;
          })
          .slice(0, maxResolve);

        return Promise.all(
          ranked.map(function (row) {
            return resolveHit(row.hit);
          }),
        ).then(function (chunks) {
          var out = [];
          var seen = {};
          for (var c = 0; c < chunks.length; c++) {
            var rows = chunks[c] || [];
            for (var r = 0; r < rows.length; r++) {
              var s = rows[r];
              if (!s || !s.url || seen[s.url]) continue;
              seen[s.url] = 1;
              out.push(s);
            }
          }
          return out;
        });
      });
    })
    .catch(function () {
      return [];
    });
}
