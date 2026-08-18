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

  function qualityFromRes(res) {
    if (!res) return '';
    var parts = String(res).match(/(\d+)x(\d+)/);
    if (!parts) return '';
    var h = parseInt(parts[2], 10);
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    return '';
  }

  function languageFor(mirror, quality) {
    if (mirror.language === 'german') return 'German';
    var q = String(quality || '');
    if (mirror.qualityFilter === 'English' || q === 'English') return 'English';
    if (mirror.qualityFilter === 'Hindi' || q === 'Hindi') return 'Hindi';
    return '';
  }

  function resolveRelative(line, baseUrl) {
    if (!line) return '';
    if (line.indexOf('http') === 0) return line;
    var base = String(baseUrl || '');
    if (line.charAt(0) === '/') {
      var host = base.match(/^https?:\/\/[^/]+/);
      return host ? host[0] + line : line;
    }
    var slash = base.lastIndexOf('/');
    return (slash >= 0 ? base.substring(0, slash + 1) : base + '/') + line;
  }

  function parseM3u8(text, baseUrl) {
    var lines = String(text || '')
      .split('\n')
      .map(function (l) {
        return l.trim();
      })
      .filter(Boolean);
    var out = [];
    var info = null;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.indexOf('#EXT-X-STREAM-INF:') === 0) {
        info = {};
        var res = line.match(/RESOLUTION=(\d+x\d+)/i);
        var codecs = line.match(/CODECS="([^"]+)"/i);
        if (res) info.resolution = res[1];
        if (codecs) info.codecs = codecs[1];
      } else if (info && line.charAt(0) !== '#') {
        var row = { url: resolveRelative(line, baseUrl), quality: qualityFromRes(info.resolution) };
        var c = String(info.codecs || '').toLowerCase();
        if (c.indexOf('mp4a') >= 0 || c.indexOf('aac') >= 0) row.audio = 'AAC';
        out.push(row);
        info = null;
      }
    }
    return out;
  }

  function parseSources(json, mirror) {
    var srcs = (json && json.sources) || [];
    var out = [];
    var dash = [];
    for (var i = 0; i < srcs.length; i++) {
      var s = srcs[i];
      var url = (s.url || s.file || '').toString();
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

  function expandRow(row) {
    var type = String(row.type || '').toLowerCase();
    var url = String(row.url || '');
    var low = url.toLowerCase();
    var isHls = type === 'hls' || low.indexOf('.m3u8') >= 0 || low.indexOf('m3u8') >= 0;
    if (!isHls || isResolution(row.quality)) {
      return Promise.resolve([row]);
    }
    return ctx
      .fetch(url, { headers: playHeaders })
      .then(function (r) {
        return r.text();
      })
      .then(function (body) {
        var variants = parseM3u8(body, url);
        if (!variants.length) return [row];
        return variants.map(function (v) {
          return {
            url: v.url,
            name: row.name,
            quality: v.quality || row.quality,
            language: row.language,
            audio: v.audio,
            headers: playHeaders,
          };
        });
      })
      .catch(function () {
        return [row];
      });
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
        var rows = [];
        for (var i = 0; i < chunks.length; i++) {
          var part = chunks[i] || [];
          for (var j = 0; j < part.length; j++) rows.push(part[j]);
        }
        return Promise.all(rows.map(expandRow)).then(function (groups) {
          var out = [];
          for (var g = 0; g < groups.length; g++) {
            var list = groups[g] || [];
            for (var k = 0; k < list.length; k++) out.push(list[k]);
          }
          return out;
        });
      });
    });
}
