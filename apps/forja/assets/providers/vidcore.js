function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://vidcore.net';
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var page =
    ctx.type === 'movie'
      ? origin + '/movie/' + tmdbId + '/'
      : origin + '/tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1) + '/';
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    'X-Requested-With': 'XMLHttpRequest',
  };

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  return ctx
    .fetch(page, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var text = (html.match(/\\"(?:en|token)\\":\\"([^\\"]+)\\"/) ||
        html.match(/"(?:en|token)":"([^"]+)"/) ||
        [])[1];
      if (!text) return ctx.host('vidcore');
      return ctx
        .fetch(enc + '/enc-vidcore?text=' + encodeURIComponent(text), { headers: headers })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          var parts = validate(j);
          if (!parts) return ctx.host('vidcore');
          var hdrs = Object.assign({}, headers, { 'X-CSRF-Token': parts.token || '' });
          return ctx
            .fetch(parts.servers, { method: 'POST', headers: hdrs })
            .then(function (r) {
              return r.text();
            })
            .then(function (encServers) {
              return ctx
                .fetch(enc + '/dec-vidcore', {
                  method: 'POST',
                  headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json' }),
                  body: JSON.stringify({ text: encServers }),
                })
                .then(function (r) {
                  return r.json();
                })
                .then(function (dj) {
                  var servers = validate(dj) || [];
                  var tasks = (Array.isArray(servers) ? servers : []).slice(0, 6).map(function (server) {
                    var data = server && server.data;
                    if (!data) return Promise.resolve([]);
                    return ctx
                      .fetch(parts.stream + '/' + data, { method: 'POST', headers: hdrs })
                      .then(function (r) {
                        return r.text();
                      })
                      .then(function (encStream) {
                        return ctx.fetch(enc + '/dec-vidcore', {
                          method: 'POST',
                          headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json' }),
                          body: JSON.stringify({ text: encStream }),
                        });
                      })
                      .then(function (r) {
                        return r.json();
                      })
                      .then(function (sj) {
                        var stream = validate(sj);
                        var urls = [];
                        function walk(o) {
                          if (!o) return;
                          if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
                          else if (Array.isArray(o)) o.forEach(walk);
                          else if (typeof o === 'object') {
                            ['url', 'file', 'src', 'stream'].forEach(function (k) {
                              if (o[k]) walk(o[k]);
                            });
                          }
                        }
                        walk(stream);
                        return urls.map(function (u) {
                          return {
                            url: u,
                            name: (server.name || 'VidCore') + '',
                            headers: { 'User-Agent': ua, Referer: origin + '/' },
                          };
                        });
                      })
                      .catch(function () {
                        return [];
                      });
                  });
                  return Promise.all(tasks).then(function (groups) {
                    var out = [].concat.apply([], groups);
                    return out.length ? out : ctx.host('vidcore');
                  });
                });
            });
        });
    })
    .catch(function () {
      return ctx.host('vidcore');
    });
}
