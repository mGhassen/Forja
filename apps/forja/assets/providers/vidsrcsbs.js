function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://vidsrc.sbs';
  var tmdbId = String(ctx.tmdbId);
  var embed =
    ctx.type === 'movie'
      ? origin + '/embed/movie/' + tmdbId
      : origin + '/embed/tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: origin + '/', Accept: 'text/html,application/xhtml+xml' };

  ctx.log('start ' + embed);

  function parseServers(html) {
    var m = html.match(/servers\s*:\s*(\[[\s\S]*?\])/);
    if (!m) return [];
    try {
      return JSON.parse(m[1]);
    } catch (e) {
      return [];
    }
  }

  function handleNested(server) {
    var u = (server && (server.url || server.src || server.embed)) || '';
    if (!u) return Promise.resolve([]);
    var name = (server && (server.name || server.title)) || 'VidSrc.sbs';
    ctx.log('mirror ' + name + ' ' + u.slice(0, 100));
    if (/\.m3u8|\.mp4/i.test(u) || /ice.*m3u8=/i.test(u)) {
      return Promise.resolve([
        { url: u, name: name, headers: { 'User-Agent': ua, Referer: origin + '/' } },
      ]);
    }
    return ctx.hop(u).then(function (rows) {
      if (rows && rows.length) return rows;
      ctx.log('hop empty for ' + name);
      return [];
    });
  }

  return ctx
    .fetch(embed, { headers: headers })
    .then(function (r) {
      ctx.log('embed http ' + r.status);
      return r.text();
    })
    .then(function (html) {
      if (/just a moment|cf-challenge|challenge-platform/i.test(html)) {
        ctx.log('cloudflare challenge');
        return [];
      }
      var servers = parseServers(html);
      ctx.log('CFG.servers=' + servers.length);
      if (!servers.length) return [];
      return Promise.all(servers.slice(0, 8).map(handleNested)).then(function (groups) {
        var out = [].concat.apply([], groups).filter(function (r) {
          return r && r.url;
        });
        ctx.log('streams=' + out.length);
        return out;
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
