function extract(ctx) {
  var cfg = ctx.config || {};
  var HEADERS = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    Connection: 'keep-alive',
  };
  var API = cfg.enc;
  var DB = cfg.db;
  var ajaxList = [];
  function pushAjax(raw) {
    var v = String(raw || '').replace(/\/$/, '');
    if (!v || ajaxList.indexOf(v) >= 0) return;
    ajaxList.push(v);
  }
  pushAjax(cfg.ajax);
  (Array.isArray(cfg.ajaxMirrors) ? cfg.ajaxMirrors : []).forEach(pushAjax);
  if (!API || !DB || !ajaxList.length) return Promise.resolve([]);
  var AJAX = ajaxList[0];
  var isMovie = ctx.type === 'movie';
  var mediaType = isMovie ? 'movie' : 'tv';

  function ajaxHeaders() {
    var origin = AJAX.replace(/\/ajax$/, '/');
    return Object.assign({}, HEADERS, {
      Referer: origin,
      Accept: 'application/json',
    });
  }

  function getJson(url) {
    return ctx.fetch(url, { headers: ajaxHeaders() }).then(function (r) {
      return r.json();
    });
  }

  function postJson(url, body, extra) {
    var payload = JSON.stringify(body);
    var headers = Object.assign({}, HEADERS, extra || {}, {
      'Content-Type': 'application/json',
      'Content-Length': String(payload.length),
    });
    return ctx.fetch(url, { method: 'POST', headers: headers, body: payload }).then(function (r) {
      return r.json();
    });
  }

  function encrypt(text) {
    return getJson(API + '/enc-movies-flix?text=' + encodeURIComponent(text)).then(function (j) {
      return j.result;
    });
  }

  function decrypt(text) {
    return postJson(API + '/dec-movies-flix', { text: text }).then(function (j) {
      return j.result;
    });
  }

  function parseHtml(html) {
    return postJson(API + '/parse-html', { text: html }).then(function (j) {
      return j.result;
    });
  }

  function decryptRapid(embedUrl) {
    var media = embedUrl.replace('/e/', '/media/').replace('/e2/', '/media/');
    return getJson(media).then(function (mediaJson) {
      var encrypted = mediaJson && mediaJson.result;
      if (!encrypted) throw new Error('no rapid media');
      return postJson(API + '/dec-rapid', { text: encrypted, agent: HEADERS['User-Agent'] });
    }).then(function (j) {
      return j.result;
    });
  }

  function formatRapid(rapid) {
    var streams = [];
    (rapid.sources || []).forEach(function (src) {
      var file = src && src.file;
      if (file) {
        streams.push({
          url: file,
          quality: file.indexOf('.m3u8') >= 0 ? 'Adaptive' : 'Auto',
          serverType: 'YFlix',
        });
      }
    });
    return streams;
  }

  function findEid(db) {
    var info = db.info || {};
    var episodes = db.episodes || {};
    if (isMovie) {
      var s1 = episodes['1'] || episodes[1] || {};
      var e1 = s1['1'] || s1[1];
      return e1 && e1.eid ? e1.eid : null;
    }
    var season = String(ctx.season || 1);
    var episode = String(ctx.episode || 1);
    var seasonMap = episodes[season] || {};
    var ep = seasonMap[episode];
    if (ep && ep.eid) return ep.eid;
    var seasons = Object.keys(episodes);
    if (!seasons.length) return null;
    var firstSeason = seasons[0];
    var eps = episodes[firstSeason] || {};
    var keys = Object.keys(eps);
    if (!keys.length) return null;
    return eps[keys[0]].eid;
  }

  function fetchStreamsOn(ajaxBase, eid) {
    AJAX = ajaxBase;
    return encrypt(eid)
      .then(function (encEid) {
        return getJson(AJAX + '/links/list?eid=' + eid + '&_=' + encEid);
      })
      .then(function (serversResp) {
        if (!serversResp || !serversResp.result) throw new Error('empty servers');
        return parseHtml(serversResp.result);
      })
      .then(function (servers) {
        var tasks = [];
        Object.keys(servers || {}).forEach(function (serverType) {
          var group = servers[serverType] || {};
          Object.keys(group).forEach(function (serverKey) {
            var lid = group[serverKey].lid;
            tasks.push(
              encrypt(lid)
                .then(function (encLid) {
                  return getJson(AJAX + '/links/view?id=' + lid + '&_=' + encLid);
                })
                .then(function (embedResp) {
                  return decrypt(embedResp.result);
                })
                .then(function (decrypted) {
                  if (
                    !decrypted ||
                    !decrypted.url ||
                    (decrypted.url.indexOf('rapidshare.cc') < 0 &&
                      decrypted.url.indexOf('rapidshare.work') < 0)
                  ) {
                    return [];
                  }
                  return decryptRapid(decrypted.url).then(formatRapid);
                })
                .then(function (items) {
                  return (items || []).map(function (s) {
                    return {
                      url: s.url,
                      name: 'YFlix ' + serverType,
                      quality: s.quality || '',
                      headers: ajaxHeaders(),
                    };
                  });
                })
                .catch(function () {
                  return [];
                }),
            );
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
      });
  }

  function fetchStreams(eid) {
    function tryAt(i) {
      if (i >= ajaxList.length) return Promise.resolve([]);
      return fetchStreamsOn(ajaxList[i], eid).then(function (rows) {
        if (rows && rows.length) return rows;
        return tryAt(i + 1);
      }).catch(function () {
        return tryAt(i + 1);
      });
    }
    return tryAt(0);
  }

  return getJson(DB + '/find?tmdb_id=' + ctx.tmdbId + '&type=' + mediaType)
    .then(function (results) {
      if (!results || !results.length) return [];
      var db = results[0];
      var eid = findEid(db);
      if (!eid) return [];
      return fetchStreams(eid);
    })
    .catch(function () {
      return [];
    });
}
