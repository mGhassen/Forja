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
    if (/videasy|player\.videasy/i.test(u)) {
      return ctx.host('videasy').then(function (rows) {
        return (rows || []).map(function (r) {
          return Object.assign({}, r, { name: '4K · ' + (r.name || name) });
        });
      });
    }
    if (/cinesrc/i.test(u) || /cinesrc/i.test(name)) {
      return ctx.hop(u).then(function (rows) {
        if (rows && rows.length) return rows;
        return [];
      });
    }
    if (/\.m3u8|\.mp4/i.test(u) || /ice.*m3u8=/i.test(u)) {
      return Promise.resolve([
        { url: u, name: name, headers: { 'User-Agent': ua, Referer: origin + '/' } },
      ]);
    }
    return ctx.hop(u).then(function (rows) {
      return rows && rows.length
        ? rows
        : [{ url: u, name: name, headers: { 'User-Agent': ua, Referer: origin + '/' } }];
    });
  }

  return ctx
    .fetch(embed, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var servers = parseServers(html);
      if (!servers.length) return ctx.host('vidsrcsbs');
      return Promise.all(servers.slice(0, 8).map(handleNested)).then(function (groups) {
        var out = [].concat.apply([], groups).filter(function (r) {
          return r && r.url;
        });
        return out.length ? out : ctx.host('vidsrcsbs');
      });
    })
    .catch(function () {
      return ctx.host('vidsrcsbs');
    });
}
