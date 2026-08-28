var SPECS = {
  "origin": "https://animekai.to",
  "enc": "https://enc-dec.app/api",
  "db": "https://enc-dec.app/db/kai",
  "ajax": "https://animekai.to/ajax"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var HEADERS = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    Accept: 'application/json',
    Referer: cfg.origin + '/',
  };
  var API = cfg.enc;
  var DB = cfg.db;
  var AJAX = cfg.ajax;
  var isMovie = ctx.type === 'movie';
  var title = String(ctx.title || '');

  function getJson(url) {
    return ctx.fetch(url, { headers: HEADERS }).then(function (r) {
      return r.json();
    });
  }

  function postJson(url, body) {
    var payload = JSON.stringify(body);
    return ctx
      .fetch(url, {
        method: 'POST',
        headers: Object.assign({}, HEADERS, { 'Content-Type': 'application/json' }),
        body: payload,
      })
      .then(function (r) {
        return r.json();
      });
  }

  function encrypt(text) {
    return getJson(API + '/enc-kai?text=' + encodeURIComponent(text)).then(function (j) {
      return j.result;
    });
  }

  function decrypt(text) {
    return postJson(API + '/dec-kai', { text: text }).then(function (j) {
      return j.result;
    });
  }

  function parseHtml(html) {
    return postJson(API + '/parse-html', { text: html }).then(function (j) {
      return j.result;
    });
  }

  function findToken(db) {
    var episodes = (db && db.episodes) || {};
    var season = String(isMovie ? 1 : ctx.season || 1);
    var episode = String(isMovie ? 1 : ctx.episode || 1);
    var seasonMap = episodes[season] || episodes[1] || {};
    var ep = seasonMap[episode] || seasonMap[1];
    return ep && (ep.token || ep.eid) ? ep.token || ep.eid : null;
  }

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o)) o.forEach(function (e) { walk(e, urls); });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream', 'link'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  function lookup() {
    var q =
      DB +
      '/search?query=' +
      encodeURIComponent(title) +
      '&type=' +
      (isMovie ? 'movie' : 'tv') +
      (ctx.year ? '&year=' + ctx.year : '');
    return getJson(q).then(function (results) {
      return Array.isArray(results) && results.length ? results[0] : (results && results[0]) || results;
    });
  }

  if (!title && !ctx.tmdbId) return [];

  return lookup()
    .then(function (db) {
      var contentId = db && (db.kai_id || db.id || db.content_id);
      var token = findToken(db);
      var start = token
        ? Promise.resolve(token)
        : contentId
          ? encrypt(contentId).then(function (encId) {
              return getJson(AJAX + '/episodes/list?ani_id=' + contentId + '&_=' + encId);
            }).then(function (resp) {
              return parseHtml(resp.result);
            }).then(function (episodes) {
              var season = String(isMovie ? 1 : ctx.season || 1);
              var episode = String(isMovie ? 1 : ctx.episode || 1);
              var ep = ((episodes || {})[season] || {})[episode];
              return ep && ep.token;
            })
          : Promise.resolve(null);
      return start.then(function (epToken) {
        if (!epToken) return [];
        return encrypt(epToken)
          .then(function (encToken) {
            return getJson(AJAX + '/links/list?token=' + epToken + '&_=' + encToken);
          })
          .then(function (serversResp) {
            return parseHtml(serversResp.result);
          })
          .then(function (servers) {
            var tasks = [];
            Object.keys(servers || {}).forEach(function (kind) {
              var group = servers[kind] || {};
              Object.keys(group).forEach(function (key) {
                var lid = group[key] && group[key].lid;
                if (!lid) return;
                tasks.push(
                  encrypt(lid)
                    .then(function (encLid) {
                      return getJson(AJAX + '/links/view?id=' + lid + '&_=' + encLid);
                    })
                    .then(function (embedResp) {
                      return decrypt(embedResp.result);
                    })
                    .then(function (decrypted) {
                      var urls = [];
                      walk(decrypted, urls);
                      return Promise.all(
                        urls.map(function (u) {
                          if (/\.m3u8|\.mp4/i.test(u)) {
                            return Promise.resolve([
                              {
                                url: u,
                                name: 'AnimeKai ' + kind,
                                headers: HEADERS,
                              },
                            ]);
                          }
                          return ctx.hop(u);
                        }),
                      ).then(function (g) {
                        return [].concat.apply([], g);
                      });
                    })
                    .catch(function () {
                      return [];
                    }),
                );
              });
            });
            return Promise.all(tasks).then(function (groups) {
              var out = [].concat.apply([], groups);
              return out.length ? out : [];
            });
          });
      });
    })
    .catch(function () {
      return [];
    });
}
