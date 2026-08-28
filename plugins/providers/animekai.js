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
  var malId = Number(ctx.malId) || 0;
  var anilistId = Number(ctx.anilistId) || 0;

  function getJson(url, extraHeaders) {
    return ctx.fetch(url, {
      headers: Object.assign({}, HEADERS, extraHeaders || {}),
    }).then(function (r) {
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

  function seasonEpisodeKeys() {
    return {
      season: String(isMovie ? 1 : ctx.season || 1),
      episode: String(isMovie ? 1 : ctx.mappedEpisode || ctx.episode || 1),
    };
  }

  function findEpisode(db) {
    var episodes = (db && db.episodes) || {};
    var keys = seasonEpisodeKeys();
    var seasonMap = episodes[keys.season] || episodes[1] || {};
    return seasonMap[keys.episode] || seasonMap[1] || null;
  }

  function findToken(db) {
    var ep = findEpisode(db);
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

  function pickDbEntry(results) {
    if (!results) return null;
    var list = Array.isArray(results) ? results : [results];
    if (!list.length) return null;
    if (malId > 0) {
      for (var i = 0; i < list.length; i++) {
        var info = list[i] && list[i].info;
        if (info && String(info.mal_id) === String(malId)) return list[i];
      }
    }
    if (anilistId > 0) {
      for (var j = 0; j < list.length; j++) {
        var info2 = list[j] && list[j].info;
        if (info2 && String(info2.anilist_id) === String(anilistId)) return list[j];
      }
    }
    return list[0];
  }

  function lookup() {
    if (malId > 0) {
      return getJson(DB + '/find?mal_id=' + malId).then(pickDbEntry);
    }
    if (anilistId > 0) {
      return getJson(DB + '/find?anilist_id=' + anilistId).then(pickDbEntry);
    }
    var q =
      DB +
      '/search?query=' +
      encodeURIComponent(title) +
      '&type=' +
      (isMovie ? 'movie' : 'tv') +
      (ctx.year ? '&year=' + ctx.year : '');
    return getJson(q).then(pickDbEntry);
  }

  function languageLabel(kind) {
    if (kind === 'dub') return 'Dub';
    if (kind === 'softsub') return 'Softsub';
    return 'Sub';
  }

  function streamsFromDbSources(db, ep) {
    var mirrors = (db.info && db.info.mirrors) || {};
    var megaupMirrors = mirrors.megaup || [];
    var sources = ep && ep.sources;
    if (!sources || !megaupMirrors.length) return Promise.resolve([]);

    var tasks = [];
    Object.keys(sources).forEach(function (kind) {
      var group = sources[kind] || {};
      Object.keys(group).forEach(function (serverKey) {
        if (serverKey === 'skip') return;
        var media = group[serverKey];
        if (!media || typeof media !== 'string') return;
        var path = media.charAt(0) === '/' ? media.slice(1) : media;
        megaupMirrors.forEach(function (mirror) {
          var base = String(mirror).replace(/\/$/, '');
          var url = base + '/' + path;
          tasks.push(
            ctx
              .hop(url)
              .then(function (rows) {
                return (rows || []).map(function (row) {
                  return {
                    url: row.url,
                    name: row.name || 'AnimeKai ' + kind + ' ' + serverKey,
                    language: languageLabel(kind),
                    headers: row.headers || HEADERS,
                  };
                });
              })
              .catch(function () {
                return [];
              }),
          );
        });
      });
    });

    return Promise.all(tasks).then(function (groups) {
      var out = [];
      var seen = {};
      for (var i = 0; i < groups.length; i++) {
        var rows = groups[i] || [];
        for (var j = 0; j < rows.length; j++) {
          var row = rows[j];
          if (!row.url || seen[row.url]) continue;
          seen[row.url] = true;
          out.push(row);
        }
      }
      return out;
    });
  }

  function ajaxBases(db) {
    var bases = [{ origin: String(cfg.origin).replace(/\/$/, ''), ajax: String(AJAX).replace(/\/$/, '') }];
    var mirrors = db && db.info && db.info.mirrors && db.info.mirrors.animekai;
    if (Array.isArray(mirrors)) {
      mirrors.forEach(function (u) {
        var origin = String(u).replace(/\/$/, '');
        var ajax = origin + '/ajax';
        if (!bases.some(function (b) { return b.ajax === ajax; })) {
          bases.push({ origin: origin, ajax: ajax });
        }
      });
    }
    return bases;
  }

  function getJsonAjax(path, db) {
    var bases = ajaxBases(db);
    function tryAt(i) {
      if (i >= bases.length) return Promise.reject(new Error('ajax'));
      var b = bases[i];
      return getJson(b.ajax + path, { Referer: b.origin + '/' }).catch(function () {
        return tryAt(i + 1);
      });
    }
    return tryAt(0);
  }

  function streamsFromAjax(db, epToken) {
    return encrypt(epToken)
      .then(function (encToken) {
        return getJsonAjax('/links/list?token=' + epToken + '&_=' + encToken, db);
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
                  return getJsonAjax('/links/view?id=' + lid + '&_=' + encLid, db);
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
          return [].concat.apply([], groups);
        });
      });
  }

  if (!title && !ctx.tmdbId && !malId && !anilistId) return [];

  return lookup()
    .then(function (db) {
      if (!db) return [];
      var ep = findEpisode(db);
      if (!ep) return [];

      return streamsFromDbSources(db, ep).then(function (dbStreams) {
        if (dbStreams.length) return dbStreams;

        var info = db.info || {};
        var contentId = info.kai_id || db.kai_id || db.id || db.content_id;
        var token = ep.token || ep.eid || null;
        var start = token
          ? Promise.resolve(token)
          : contentId
            ? encrypt(contentId)
                .then(function (encId) {
                  return getJsonAjax('/episodes/list?ani_id=' + contentId + '&_=' + encId, db);
                })
                .then(function (resp) {
                  return parseHtml(resp.result);
                })
                .then(function (episodes) {
                  var keys = seasonEpisodeKeys();
                  var row = ((episodes || {})[keys.season] || {})[keys.episode];
                  return row && row.token;
                })
            : Promise.resolve(null);

        return start.then(function (epToken) {
          if (!epToken) return [];
          return streamsFromAjax(db, epToken);
        });
      });
    })
    .catch(function () {
      return [];
    });
}
