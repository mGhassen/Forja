function extract(ctx) {
  var api = 'https://api.speedracelight.com';
  var origin = 'https://player.videasy.to';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    Origin: origin,
    Accept: 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };
  var playHeaders = {
    'User-Agent': ua,
    Referer: origin + '/',
    Origin: origin,
  };
  var mirrors = [
    { endpoint: 'cdn', name: 'Yoru' },
    { endpoint: 'downloader2', name: 'Cypher' },
    { endpoint: 'm4uhd', name: 'Breach' },
    { endpoint: 'vsrc', name: 'Neon' },
    { endpoint: 'hdmovie', name: 'Vyse', qualityFilter: 'English' },
    { endpoint: 'meine', name: 'Killjoy', language: 'german' },
    { endpoint: 'hdmovie', name: 'Fade', qualityFilter: 'Hindi' },
    { endpoint: 'lamovie', name: 'Omen' },
    { endpoint: 'superflix', name: 'Raze' },
  ];
  var isMovie = ctx.type === 'movie';
  var tmdbId = String(ctx.tmdbId);

  function parseSources(json, mirror) {
    var srcs = (json && json.sources) || [];
    var out = [];
    var dash = [];
    for (var i = 0; i < srcs.length; i++) {
      var s = srcs[i];
      var url = (s.url || s.file || '').toString();
      if (!url) continue;
      var quality = (s.quality || s.label || s.title || 'auto').toString();
      if (mirror.qualityFilter && quality !== mirror.qualityFilter) continue;
      var type = (s.type || (url.indexOf('.m3u8') >= 0 ? 'hls' : 'video')).toString();
      var row = {
        url: url,
        title: mirror.name + ' · ' + quality,
        headers: playHeaders,
      };
      out.push(row);
      if (type === 'dash' || url.toLowerCase().indexOf('.mpd') >= 0) dash.push(row);
    }
    var preferDash = mirror.endpoint === 'vsrc' || mirror.endpoint === 'neon2';
    return preferDash && dash.length ? dash : out;
  }

  function probe(mirror, seed) {
    var q =
      'title=' +
      encodeURIComponent(ctx.title || '') +
      '&mediaType=' +
      (isMovie ? 'movie' : 'tv') +
      '&tmdbId=' +
      encodeURIComponent(tmdbId) +
      '&seasonId=' +
      (ctx.season || 1) +
      '&episodeId=' +
      (ctx.episode || 1) +
      '&enc=2&seed=' +
      encodeURIComponent(seed);
    if (ctx.year) q += '&year=' + encodeURIComponent(String(ctx.year).substring(0, 4));
    if (mirror.language) q += '&language=' + encodeURIComponent(mirror.language);
    return ctx
      .fetch(api + '/' + mirror.endpoint + '/sources-with-title?' + q, { headers: headers })
      .then(function (r) {
        return r.text();
      })
      .then(function (body) {
        body = (body || '').trim();
        if (!body || body.length < 50 || body.charAt(0) === '{' || body.charAt(0) === '<') {
          return [];
        }
        try {
          return parseSources(JSON.parse(ctx.streamcrypto.decrypt(body, seed, tmdbId)), mirror);
        } catch (e) {
          return [];
        }
      })
      .catch(function () {
        return [];
      });
  }

  return ctx
    .fetch(api + '/seed?mediaId=' + encodeURIComponent(tmdbId), { headers: headers })
    .then(function (r) {
      return r.json();
    })
    .then(function (seedJson) {
      var seed = seedJson && seedJson.seed;
      if (!seed) return [];
      return Promise.all(
        mirrors.map(function (mirror) {
          return probe(mirror, seed);
        }),
      ).then(function (chunks) {
        var out = [];
        for (var i = 0; i < chunks.length; i++) {
          var rows = chunks[i] || [];
          for (var j = 0; j < rows.length; j++) out.push(rows[j]);
        }
        return out;
      });
    });
}
