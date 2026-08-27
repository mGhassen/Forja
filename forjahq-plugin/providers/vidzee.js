function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://core.vidzee.wtf').replace(/\/$/, '');
  var origin = (cfg.origin || 'https://player.vidzee.wtf').replace(/\/$/, '');
  var servers = cfg.servers || ['dcloud', 'tik', 'ipcloud', 'v6:Hindi'];
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var isTv = ctx.type !== 'movie';
  var season = ctx.season || 1;
  var episode = ctx.episode || 1;
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    Origin: origin,
    Accept: 'application/json, text/plain, */*',
  };
  var playHeaders = {
    'User-Agent': ua,
    Referer: origin + '/',
    Origin: origin,
  };

  ctx.log(
    'start tmdb=' +
      tmdbId +
      ' type=' +
      (isTv ? 'tv' : 'movie') +
      ' servers=' +
      servers.join(','),
  );

  function streamUrl(sr) {
    var path = isTv
      ? '/streams/tv/' +
        encodeURIComponent(tmdbId) +
        '/' +
        encodeURIComponent(season) +
        '/' +
        encodeURIComponent(episode)
      : '/streams/movie/' + encodeURIComponent(tmdbId);
    return api + path + '?s=' + encodeURIComponent(sr) + '&e=0';
  }

  function one(sr) {
    var url = streamUrl(sr);
    ctx.log('GET ' + url);
    return ctx
      .fetch(url, { headers: headers })
      .then(function (r) {
        if (!r.ok) {
          ctx.log('server ' + sr + ' http ' + r.status);
          return [];
        }
        return r.json().then(function (data) {
          if (!data || typeof data !== 'object') return [];
          if (data.c) {
            ctx.log('server ' + sr + ' encrypted blob (e=0 expected)');
            return [];
          }
          var stream = typeof data.url === 'string' ? data.url.trim() : '';
          if (!/^https?:\/\//i.test(stream)) {
            ctx.log('server ' + sr + ' empty');
            return [];
          }
          var hdrs = Object.assign({}, playHeaders);
          if (data.headers && typeof data.headers === 'object') {
            Object.keys(data.headers).forEach(function (k) {
              hdrs[k] = String(data.headers[k]);
            });
          }
          var lang = data.language || '';
          ctx.log('server ' + sr + ' ok ' + stream.slice(0, 80));
          return [
            {
              url: stream,
              name: 'Vidzee ' + sr + (lang ? ' · ' + lang : ''),
              language: lang,
              headers: hdrs,
            },
          ];
        });
      })
      .catch(function (e) {
        ctx.error('server ' + sr + ': ' + (e && e.message ? e.message : e));
        return [];
      });
  }

  return Promise.all(servers.map(one)).then(function (groups) {
    var out = [].concat.apply([], groups);
    ctx.log('streams=' + out.length);
    return out;
  });
}
