function extract(ctx) {
  var cfg = ctx.config || {};
  var api = cfg.api;
  var origin = cfg.origin;
  var mirrors = cfg.mirrors || [];
  if (!api || !origin) return Promise.resolve([]);
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
  var isMovie = ctx.type === 'movie';
  var tmdbId = String(ctx.tmdbId);

  function isResolution(q) {
    return /^(4k|2160p?|1440p|1080p?|720p?|480p?|360p?)$/i.test(String(q || ''));
  }

  function languageFor(mirror, quality) {
    if (mirror.language === 'german') return 'German';
    var q = String(quality || '');
    if (mirror.qualityFilter === 'English' || q === 'English') return 'English';
    if (mirror.qualityFilter === 'Hindi' || q === 'Hindi') return 'Hindi';
    return '';
  }

  // API often returns demuxed media playlists (index-s2160p-v1-a1.m3u8). Open the
  // sibling master — seek stalls forever on the child (peakstorm / Videasy CDN).
  function preferHlsMaster(url) {
    var u = String(url || '');
    if (!/index-s\d+p-v\d+-a\d+\.m3u8/i.test(u)) return u;
    var withSd = u.replace(/\/sd\/\d+\/index-s\d+p-v\d+-a\d+\.m3u8/i, '/master.m3u8');
    if (withSd !== u) return withSd;
    return u.replace(/\/index-s\d+p-v\d+-a\d+\.m3u8/i, '/master.m3u8');
  }

  function parseSources(json, mirror) {
    var srcs = (json && json.sources) || [];
    var out = [];
    var dash = [];
    for (var i = 0; i < srcs.length; i++) {
      var s = srcs[i];
      var url = preferHlsMaster((s.url || s.file || '').toString());
      if (!url) continue;
      var quality = (s.quality || s.label || s.title || '').toString();
      if (mirror.qualityFilter && quality !== mirror.qualityFilter) continue;
      var type = (s.type || (url.indexOf('.m3u8') >= 0 ? 'hls' : 'video')).toString();
      var row = {
        url: url,
        name: mirror.name,
        quality: isResolution(quality) ? quality : '',
        language: languageFor(mirror, quality),
        type: type,
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
          return parseSources(JSON.parse(ctx.crypto.streamDecrypt(body, seed, tmdbId)), mirror);
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
      ctx.log('seed status=' + r.status + ' ok=' + r.ok);
      return r.json();
    })
    .then(function (seedJson) {
      var seed = seedJson && seedJson.seed;
      if (!seed) {
        ctx.error('no seed');
        return [];
      }
      ctx.log('mirrors=' + mirrors.length);
      return Promise.all(
        mirrors.map(function (mirror) {
          return probe(mirror, seed);
        }),
      ).then(function (chunks) {
        var rows = [];
        for (var i = 0; i < chunks.length; i++) {
          var part = chunks[i] || [];
          for (var j = 0; j < part.length; j++) rows.push(part[j]);
        }
        ctx.log('rawRows=' + rows.length);
        return rows;
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
