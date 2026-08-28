function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://anime-dunya.com').replace(/\/$/, '');
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Accept: 'text/html,application/xhtml+xml' };
  var isTv = ctx.type !== 'movie';
  var epNum = isTv ? ctx.episode || 1 : 1;

  function fetchText(url) {
    return ctx.fetch(url, { headers: hdrs }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, { Accept: 'application/json' }) }).then(function (r) {
      return r.json();
    });
  }

  function resolveMal() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) return Promise.resolve(fromHost.malId);
    if (!isTv) {
      return fetchJson(
        'https://api.themoviedb.org/3/movie/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
      )
        .then(function (d) {
          var title = d.title || d.original_title || '';
          if (!title) return null;
          return fetchJson(jikan + '?q=' + encodeURIComponent(title) + '&type=movie&limit=1').then(function (j) {
            return j && j.data && j.data[0] ? j.data[0].mal_id : null;
          });
        })
        .catch(function () {
          return null;
        });
    }
    var imdbP = ctx.imdbId
      ? Promise.resolve(String(ctx.imdbId))
      : fetchJson(
          'https://api.themoviedb.org/3/tv/' +
            encodeURIComponent(String(ctx.tmdbId || '')) +
            '/external_ids?api_key=' +
            encodeURIComponent(tmdbKey),
        )
          .then(function (d) {
            return (d && d.imdb_id) || '';
          })
          .catch(function () {
            return '';
          });
    return imdbP.then(function (imdbId) {
      if (!imdbId) return null;
      return fetchJson(
        mapApi +
          '?id=' +
          encodeURIComponent(imdbId) +
          '&s=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&e=' +
          encodeURIComponent(String(epNum)),
      )
        .then(function (m) {
          return m && m.mal_id ? m.mal_id : null;
        })
        .catch(function () {
          return null;
        });
    });
  }

  function extractStream(html) {
    var match = html.match(/\\?"stream\\?":\s*/);
    if (!match) return null;
    var idx = match.index;
    var matchLen = match[0].length;
    var braceCount = 0;
    var started = false;
    var result = '';
    for (var i = idx + matchLen; i < html.length; i++) {
      var ch = html.charAt(i);
      if (ch === '{') {
        braceCount++;
        started = true;
      } else if (ch === '}') {
        braceCount--;
      }
      if (started) {
        result += ch;
        if (braceCount === 0) break;
      }
    }
    try {
      var cleanStr = result.replace(/\\u0026/g, '&').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
      return JSON.parse(cleanStr);
    } catch (e) {
      var sourceMatch = html.match(/"source"\s*:\s*"([^"]+)"/);
      if (sourceMatch) return { source: sourceMatch[1].replace(/\\/g, '') };
      return null;
    }
  }

  return resolveMal()
    .then(function (mal) {
      if (!mal) return [];
      return fetchText(base + '/en/play/' + mal + '/' + epNum).then(function (html) {
        var streamData = extractStream(html);
        if (!streamData || !streamData.source) return [];
        var subtitles = (streamData.subtitles || []).map(function (s) {
          return { url: s.src, lang: s.srclang || s.label || 'en' };
        });
        return [
          {
            url: streamData.source,
            name: 'AnimeDunya',
            headers: hdrs,
            language: 'Sub',
            subtitles: subtitles,
          },
        ];
      });
    })
    .catch(function () {
      return [];
    });
}
