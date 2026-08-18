function extract(ctx) {
  var cfg = ctx.config || {};
  var BASE = cfg.base;
  if (!BASE) return Promise.resolve([]);
  var ua =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var isMovie = ctx.type === 'movie';
  var tmdbId = String(ctx.tmdbId);
  var season = ctx.season || 1;
  var episode = ctx.episode || 1;

  function playHeaders(referer) {
    return {
      'User-Agent': ua,
      Referer: referer,
      Origin: BASE,
    };
  }

  function apiUrl() {
    return isMovie
      ? BASE + '/api/movie/' + tmdbId
      : BASE + '/api/tv/' + tmdbId + '/' + season + '/' + episode;
  }

  function subtitleApiUrl() {
    var subs = (ctx.config && ctx.config.subs) || '';
    if (!subs) return '';
    return isMovie
      ? subs + '/search?id=' + encodeURIComponent(tmdbId)
      : subs +
          '/search?id=' +
          encodeURIComponent(tmdbId) +
          '&season=' +
          season +
          '&episode=' +
          episode;
  }

  function fetchJson(url, referer) {
    return ctx
      .fetch(url, {
        headers: {
          'User-Agent': ua,
          Accept: 'application/json, text/plain, */*',
          Referer: referer || BASE + '/',
          Origin: BASE,
        },
      })
      .then(function (r) {
        if (!r.ok) throw new Error('http ' + r.status);
        return r.json();
      });
  }

  function fetchText(url, referer) {
    return ctx
      .fetch(url, {
        headers: {
          'User-Agent': ua,
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          Referer: referer || BASE + '/',
        },
      })
      .then(function (r) {
        if (!r.ok) throw new Error('http ' + r.status);
        return r.text();
      });
  }

  function qualityFromRes(res) {
    if (!res) return 'Auto';
    var parts = String(res).match(/(\d+)x(\d+)/);
    if (!parts) return 'Auto';
    var h = parseInt(parts[2], 10);
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    return 'Auto';
  }

  function qualityFromUrl(url) {
    var m = String(url || '').match(/rendition=([^&]+)/i);
    if (m) return m[1];
    return 'Auto';
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

  function buildMasterUrl(base, token, expires) {
    var sep = base.indexOf('?') >= 0 ? '&' : '?';
    return base + sep + 'token=' + token + '&expires=' + expires + '&h=1&lang=en';
  }

  function parseMasterFromHtml(html) {
    if (!html || html.indexOf('masterPlaylist') < 0) return null;
    var urlMatch = html.match(/url:\s*['"]([^'"]+)['"]/);
    var tokenMatch = html.match(/['"]?token['"]?\s*:\s*['"]([^'"]+)['"]/);
    var expiresMatch = html.match(/['"]?expires['"]?\s*:\s*['"]([^'"]+)['"]/);
    if (urlMatch && tokenMatch && expiresMatch) {
      return buildMasterUrl(urlMatch[1], tokenMatch[1], expiresMatch[1]);
    }
    var m3u8 = html.match(/(https?:\/\/[^'"\s]+\.m3u8[^'"\s]*)/);
    if (m3u8) return m3u8[1];
    var scripts = html.match(/<script[^>]*>([\s\S]*?)<\/script>/gi) || [];
    for (var i = 0; i < scripts.length; i++) {
      var hit = scripts[i].match(/(https?:\/\/[^'"\s]+(?:\.m3u8|playlist)[^'"\s]*)/);
      if (hit) return hit[1];
    }
    return null;
  }

  function parseM3u8Variants(text, masterUrl, referer) {
    var lines = String(text || '')
      .split('\n')
      .map(function (l) {
        return l.trim();
      });
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
      } else if (info && line && line.charAt(0) !== '#') {
        var url = resolveRelative(line, masterUrl);
        var q = qualityFromRes(info.resolution) || qualityFromUrl(url);
        var row = {
          url: url,
          name: 'Vixsrc',
          quality: q && q !== 'Auto' ? q : '',
          headers: playHeaders(referer),
        };
        var c = String(info.codecs || '').toLowerCase();
        if (c.indexOf('mp4a') >= 0 || c.indexOf('aac') >= 0) row.audio = 'AAC';
        out.push(row);
        info = null;
      }
    }
    return out;
  }

  function pickEnglishSubtitle(tracks) {
    if (!tracks || !tracks.length) return null;
    var encodings = ['ASCII', 'UTF-8', 'CP1252', 'CP1250', 'CP850'];
    for (var e = 0; e < encodings.length; e++) {
      for (var i = 0; i < tracks.length; i++) {
        var t = tracks[i];
        var display = String(t.display || t.language || t.label || '');
        if (display.indexOf('English') >= 0 && t.url && t.encoding === encodings[e]) {
          return t.url;
        }
      }
    }
    for (var j = 0; j < tracks.length; j++) {
      var row = tracks[j];
      if (row && row.url && String(row.display || '').indexOf('English') >= 0) {
        return row.url;
      }
    }
    return null;
  }

  function attachSubtitle(rows, subUrl) {
    if (!subUrl) return rows;
    return rows.map(function (row) {
      return {
        url: row.url,
        name: row.name || 'Vixsrc',
        quality: row.quality,
        audio: row.audio,
        headers: row.headers,
        subtitles: [{ url: subUrl, language: 'en', name: 'English' }],
      };
    });
  }

  function rowsFromMaster(masterUrl, embedUrl) {
    var referer = embedUrl || BASE + '/';
    return fetchText(masterUrl, referer).then(function (body) {
      var variants = parseM3u8Variants(body, masterUrl, referer);
      if (variants.length) return variants;
      return [
        {
          url: masterUrl,
          name: 'Vixsrc',
          headers: playHeaders(referer),
        },
      ];
    });
  }

  function resolveFromEmbed(embedUrl) {
    return fetchText(embedUrl, BASE + '/').then(function (html) {
      var master = parseMasterFromHtml(html);
      if (!master) return [];
      return rowsFromMaster(master, embedUrl);
    });
  }

  function resolveFromApi() {
    return fetchJson(apiUrl(), BASE + '/').then(function (data) {
      var src = data && data.src;
      if (!src) return [];
      var embedPath = src.charAt(0) === '/' ? src : '/' + src;
      return resolveFromEmbed(BASE + embedPath);
    });
  }

  function resolveLegacyPage() {
    var pageUrl = isMovie
      ? BASE + '/movie/' + tmdbId
      : BASE + '/tv/' + tmdbId + '/' + season + '/' + episode;
    return fetchText(pageUrl, BASE + '/').then(function (html) {
      var master = parseMasterFromHtml(html);
      if (!master) return [];
      return rowsFromMaster(master, pageUrl);
    });
  }

  return resolveFromApi()
    .catch(function () {
      return resolveLegacyPage();
    })
    .then(function (rows) {
      if (!rows || !rows.length) return [];
      var subUrl = subtitleApiUrl();
      if (!subUrl) return rows;
      return fetchJson(subUrl, BASE + '/')
        .then(function (tracks) {
          var sub = pickEnglishSubtitle(Array.isArray(tracks) ? tracks : []);
          return attachSubtitle(rows, sub);
        })
        .catch(function () {
          return rows;
        });
    })
    .catch(function () {
      return [];
    });
}
