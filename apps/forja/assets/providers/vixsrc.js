function extract(ctx) {
  var BASE = 'https://vixsrc.to';
  var ua =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var isMovie = ctx.type === 'movie';
  var tmdbId = String(ctx.tmdbId);
  var apiUrl = isMovie
    ? BASE + '/api/movie/' + tmdbId
    : BASE +
      '/api/tv/' +
      tmdbId +
      '/' +
      (ctx.season || 1) +
      '/' +
      (ctx.episode || 1);
  var pageHeaders = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    Referer: BASE + '/',
    Origin: BASE,
  };

  function parseMaster(html, embedUrl) {
    if (!html || html.indexOf('masterPlaylist') < 0) return null;
    var urlMatch = html.match(/url:\s*['"]([^'"]+)['"]/);
    var tokenMatch = html.match(/['"]?token['"]?\s*:\s*['"]([^'"]+)['"]/);
    var expiresMatch = html.match(/['"]?expires['"]?\s*:\s*['"]([^'"]+)['"]/);
    if (!urlMatch || !tokenMatch || !expiresMatch) return null;
    var base = urlMatch[1];
    var token = tokenMatch[1];
    var expires = expiresMatch[1];
    var master =
      base.indexOf('?') >= 0
        ? base + '&token=' + token + '&expires=' + expires + '&h=1&lang=en'
        : base + '?token=' + token + '&expires=' + expires + '&h=1&lang=en';
    return {
      url: master,
      headers: {
        'User-Agent': ua,
        Referer: embedUrl,
        Origin: BASE,
      },
    };
  }

  return ctx
    .fetch(apiUrl, { headers: pageHeaders })
    .then(function (r) {
      return r.json();
    })
    .then(function (data) {
      var src = data && data.src;
      if (!src) return [];
      var embedPath = src.charAt(0) === '/' ? src : '/' + src;
      var embedUrl = BASE + embedPath;
      return ctx
        .fetch(embedUrl, {
          headers: {
            'User-Agent': ua,
            Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            Referer: BASE + '/',
          },
        })
        .then(function (r) {
          return r.text();
        })
        .then(function (html) {
          var row = parseMaster(html, embedUrl);
          if (!row) return [];
          return [{ url: row.url, title: 'Vixsrc · Auto', headers: row.headers }];
        });
    })
    .catch(function () {
      return [];
    });
}
