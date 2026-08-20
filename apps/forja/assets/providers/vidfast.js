function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://vidfast.vc';
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var page =
    ctx.type === 'movie'
      ? origin + '/movie/' + tmdbId
      : origin + '/tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    'X-Requested-With': 'XMLHttpRequest',
  };

  ctx.log('start ' + page);

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  // Player session token (EncDec sample ~120 chars). Skip short RSC / Next.js junk.
  function pickToken(html) {
    var candidates = [];
    var re = /\\?"(?:en|token)\\?"\s*:\s*\\?"([A-Za-z0-9_\-]{80,})\\?"/g;
    var m;
    while ((m = re.exec(html))) candidates.push(m[1]);
    candidates.sort(function (a, b) {
      return b.length - a.length;
    });
    return candidates[0] || '';
  }

  return ctx
    .fetch(page, { headers: headers })
    .then(function (r) {
      ctx.log('page http ' + r.status);
      return r.text();
    })
    .then(function (html) {
      var text = pickToken(html);
      if (!text) {
        ctx.log(
          'no player token in HTML (SPA session — EncDec-only path needs sharoon7171/vidfast-pro-stream-resolver VM)',
        );
        return [];
      }
      ctx.log('enc-vidfast text len=' + text.length);
      return ctx
        .fetch(enc + '/enc-vidfast?text=' + encodeURIComponent(text), { headers: headers })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          var parts = validate(j);
          if (!parts || !parts.servers) {
            ctx.log('enc-vidfast miss');
            return [];
          }
          var hdrs = Object.assign({}, headers, { 'X-CSRF-Token': parts.token || '' });
          return ctx
            .fetch(parts.servers, { method: 'POST', headers: hdrs })
            .then(function (r) {
              ctx.log('servers POST http ' + r.status);
              return r.text().then(function (encServers) {
                return { status: r.status, body: encServers };
              });
            })
            .then(function (posted) {
              if (posted.status < 200 || posted.status >= 300 || !posted.body) {
                ctx.log(
                  'servers POST failed — token is not a live player session (needs VM probe, not bare EncDec)',
                );
                return [];
              }
              return ctx
                .fetch(enc + '/dec-vidfast', {
                  method: 'POST',
                  headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json' }),
                  body: JSON.stringify({ text: posted.body }),
                })
                .then(function (r) {
                  return r.json();
                })
                .then(function (dj) {
                  var servers = validate(dj) || [];
                  ctx.log('servers=' + (Array.isArray(servers) ? servers.length : 0));
                  var tasks = (Array.isArray(servers) ? servers : []).slice(0, 6).map(function (server) {
                    var data = server && server.data;
                    if (!data) return Promise.resolve([]);
                    return ctx
                      .fetch(parts.stream + '/' + data, { method: 'POST', headers: hdrs })
                      .then(function (r) {
                        return r.text();
                      })
                      .then(function (encStream) {
                        return ctx.fetch(enc + '/dec-vidfast', {
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
                            name: (server.name || 'VidFast') + '',
                            headers: { 'User-Agent': ua, Referer: origin + '/' },
                          };
                        });
                      })
                      .catch(function (e) {
                        ctx.error('server: ' + (e && e.message ? e.message : e));
                        return [];
                      });
                  });
                  return Promise.all(tasks).then(function (groups) {
                    var out = [].concat.apply([], groups);
                    ctx.log('streams=' + out.length);
                    return out;
                  });
                });
            });
        });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
