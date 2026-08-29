var SPECS = {
  "origin": "https://xprime.tv",
  "backend": "https://backend.xprime.tv",
  "enc": "https://enc-dec.app/api",
  "tmdbKey": "439c478a771f35c05022f9feabcca01c",
  "servers": [
    "primebox",
    "rage"
  ]
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var backend = cfg.backend.replace(/\/$/, '');
  var enc = cfg.enc.replace(/\/$/, '');
  var origin = cfg.origin;
  var servers = Array.isArray(cfg.servers) ? cfg.servers : [];
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    Origin: origin,
    Referer: origin + '/',
  };
  var isTv = ctx.type !== 'movie';

  function getJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.json();
    });
  }

  function getText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function getTmdbDetails() {
    var kind = isTv ? 'tv' : 'movie';
    return getJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey) +
        '&append_to_response=external_ids',
      { Accept: 'application/json' },
    ).then(function (data) {
      return {
        title: isTv ? data.name : data.title,
        year: String((isTv ? data.first_air_date : data.release_date) || '').substring(0, 4),
        imdbId: (data.external_ids && data.external_ids.imdb_id) || ctx.imdbId || '',
      };
    });
  }

  function turnstileToken() {
    return getJson(enc + '/enc-xprime', { Accept: 'application/json' }).then(function (j) {
      return (j && j.result) || '';
    });
  }

  function decryptResponse(text) {
    return ctx
      .fetch(enc + '/dec-xprime', {
        method: 'POST',
        headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
        body: JSON.stringify({ text: text }),
      })
      .then(function (r) {
        return r.json();
      })
      .then(function (j) {
        if (j && j.status === 200 && j.result) return j.result;
        return null;
      });
  }

  function qualityFromName(q) {
    var s = String(q || '').toLowerCase();
    if (s.indexOf('4k') >= 0 || s.indexOf('2160') >= 0) return '4K';
    if (s.indexOf('1440') >= 0) return '1440p';
    if (s.indexOf('1080') >= 0 || s.indexOf('fhd') >= 0) return '1080p';
    if (s.indexOf('720') >= 0 || s.indexOf('hd') >= 0) return '720p';
    if (s.indexOf('480') >= 0) return '480p';
    if (s.indexOf('360') >= 0) return '360p';
    if (s.indexOf('240') >= 0) return '240p';
    return 'Unknown';
  }

  function parseM3u8(content, baseUrl) {
    var lines = String(content || '').split('\n').map(function (line) { return line.trim(); }).filter(Boolean);
    var streams = [];
    var current = null;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.indexOf('#EXT-X-STREAM-INF:') === 0) {
        current = { bandwidth: null, resolution: null, url: null };
        var bw = line.match(/BANDWIDTH=(\d+)/);
        var rs = line.match(/RESOLUTION=(\d+x\d+)/);
        if (bw) current.bandwidth = parseInt(bw[1], 10);
        if (rs) current.resolution = rs[1];
      } else if (current && line.charAt(0) !== '#') {
        try {
          current.url = new URL(line, baseUrl).toString();
        } catch (e) {
          current.url = line;
        }
        streams.push(current);
        current = null;
      }
    }
    return streams;
  }

  function qualityFromStream(stream) {
    if (stream.resolution) {
      var m = String(stream.resolution).match(/x(\d+)/);
      return qualityFromName(m ? m[1] + 'p' : '');
    }
    if (stream.bandwidth) {
      var mbps = stream.bandwidth / 1000000;
      if (mbps >= 15) return '4K';
      if (mbps >= 8) return '1440p';
      if (mbps >= 5) return '1080p';
      if (mbps >= 3) return '720p';
      if (mbps >= 1.5) return '480p';
      if (mbps >= 0.8) return '360p';
    }
    return 'Unknown';
  }

  function resolvePlaylist(link) {
    return getText(link.url, {
      Accept: 'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
    })
      .then(function (content) {
        if (content.indexOf('#EXT-X-STREAM-INF:') >= 0) {
          return parseM3u8(content, link.url).map(function (stream) {
            return {
              url: stream.url,
              name: link.name.replace(/\s-\sUnknown$/, '') + ' - ' + qualityFromStream(stream),
              quality: qualityFromStream(stream),
              headers: headers,
              subtitles: link.subtitles || [],
            };
          });
        }
        return [link];
      })
      .catch(function () {
        return [link];
      });
  }

  function processPrimebox(data, serverName) {
    var links = [];
    var subtitles = [];
    if (data && data.has_subtitles && Array.isArray(data.subtitles)) {
      data.subtitles.forEach(function (sub) {
        if (sub && sub.file) subtitles.push({ url: String(sub.file).trim(), lang: sub.label || 'Unknown' });
      });
    }
    if (data && data.streams && Array.isArray(data.available_qualities)) {
      data.available_qualities.forEach(function (quality) {
        var url = data.streams[quality];
        if (!url) return;
        links.push({
          url: String(url).trim(),
          name: 'XPRIME ' + serverName + ' - ' + qualityFromName(quality),
          quality: qualityFromName(quality),
          type: 'VIDEO',
          headers: headers,
          subtitles: subtitles,
        });
      });
    }
    return links;
  }

  function processOther(data, serverName) {
    var links = [];
    if (serverName === 'rage' && data && data.success && Array.isArray(data.qualities)) {
      data.qualities.forEach(function (q) {
        if (!q || !q.url) return;
        links.push({
          url: q.url,
          name: 'XPRIME ' + serverName + ' - ' + qualityFromName(q.quality),
          quality: qualityFromName(q.quality),
          type: 'VIDEO',
          headers: headers,
          subtitles: [],
        });
      });
      return links;
    }
    if (data && data.url) {
      links.push({
        url: data.url,
        name: 'XPRIME ' + serverName + ' - ' + qualityFromName(data.quality || data.url),
        quality: qualityFromName(data.quality || data.url),
        type: 'M3U8',
        headers: headers,
        subtitles: [],
      });
    }
    return links;
  }

  function queryFor(serverName, info, turnstile) {
    if (serverName === 'rage') {
      var rageUrl = backend + '/rage?id=' + encodeURIComponent(String(ctx.tmdbId || ''));
      if (isTv) {
        rageUrl +=
          '&season=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&episode=' +
          encodeURIComponent(String(ctx.episode || 1));
      }
      rageUrl += '&turnstile=' + encodeURIComponent(turnstile);
      return rageUrl;
    }
    var params = [];
    params.push('name=' + encodeURIComponent(info.title || ''));
    if (serverName === 'primebox') {
      if (info.year) params.push('fallback_year=' + encodeURIComponent(info.year));
      if (isTv) {
        params.push('season=' + encodeURIComponent(String(ctx.season || 1)));
        params.push('episode=' + encodeURIComponent(String(ctx.episode || 1)));
      }
    } else {
      if (info.year) params.push('year=' + encodeURIComponent(info.year));
      if (info.imdbId) {
        params.push('id=' + encodeURIComponent(info.imdbId));
        params.push('imdb=' + encodeURIComponent(info.imdbId));
      }
      if (isTv) {
        params.push('season=' + encodeURIComponent(String(ctx.season || 1)));
        params.push('episode=' + encodeURIComponent(String(ctx.episode || 1)));
      }
    }
    params.push('turnstile=' + encodeURIComponent(turnstile));
    return backend + '/' + serverName + '?' + params.join('&');
  }

  return Promise.all([getTmdbDetails(), turnstileToken()])
    .then(function (pair) {
      var info = pair[0];
      var turnstile = pair[1];
      if (!info.title || !turnstile) return [];
      var tasks = servers.map(function (serverName) {
        return getText(queryFor(serverName, info, turnstile))
          .then(function (responseText) {
            if (!responseText) return [];
            var parsedDirect = null;
            var isEncrypted =
              responseText.indexOf('{') < 0 ||
              responseText.indexOf('AQAA') === 0 ||
              responseText.indexOf('UklGR') === 0;
            if (isEncrypted) {
              return decryptResponse(responseText).then(function (data) {
                if (!data) return [];
                return serverName === 'primebox'
                  ? processPrimebox(data, serverName)
                  : processOther(data, serverName);
              });
            }
            try {
              parsedDirect = JSON.parse(responseText);
            } catch (e) {
              parsedDirect = null;
            }
            if (!parsedDirect) return [];
            return serverName === 'primebox'
              ? processPrimebox(parsedDirect, serverName)
              : processOther(parsedDirect, serverName);
          })
          .catch(function () {
            return [];
          });
      });
      return Promise.all(tasks).then(function (groups) {
        var links = [].concat.apply([], groups);
        var m3u8Links = links.filter(function (link) { return link.type === 'M3U8'; });
        var directLinks = links.filter(function (link) { return link.type !== 'M3U8'; });
        return Promise.all(m3u8Links.map(resolvePlaylist)).then(function (resolved) {
          var finalLinks = directLinks.concat([].concat.apply([], resolved));
          var seen = {};
          finalLinks = finalLinks.filter(function (link) {
            if (!link || !link.url || seen[link.url]) return false;
            seen[link.url] = true;
            return true;
          });
          finalLinks.sort(function (a, b) {
            var order = { '4K': 6, '1440p': 5, '1080p': 4, '720p': 3, '480p': 2, '360p': 1, '240p': 0, Unknown: -1 };
            return (order[b.quality] || -1) - (order[a.quality] || -1);
          });
          return finalLinks;
        });
      });
    })
    .catch(function () {
      return [];
    });
}
