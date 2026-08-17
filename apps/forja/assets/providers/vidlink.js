function extract(ctx) {
  var TMDB_KEY = '68e094699525b18a70bab2f86b1fa706';
  var ENC = 'https://enc-dec.app/api';
  var API = 'https://vidlink.pro/api/b';
  var headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    Referer: 'https://vidlink.pro/',
    Origin: 'https://vidlink.pro',
  };
  var isTv = ctx.type === 'tv';
  var tmdbId = String(ctx.tmdbId);

  function req(url, opts) {
    opts = opts || {};
    return ctx.fetch(url, {
      headers: Object.assign({}, headers, opts.headers || {}),
      method: opts.method || 'GET',
    });
  }

  function qualityFromRes(res) {
    if (!res) return 'Auto';
    var parts = String(res).split('x');
    var h = parseInt(parts[1], 10);
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    return 'Auto';
  }

  function resolveRelative(line, baseUrl) {
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
        var bw = line.match(/BANDWIDTH=(\d+)/);
        var res = line.match(/RESOLUTION=(\d+x\d+)/);
        if (bw) info.bandwidth = parseInt(bw[1], 10);
        if (res) info.resolution = res[1];
      } else if (info && line.charAt(0) !== '#') {
        var url = resolveRelative(line, baseUrl);
        out.push({ url: url, quality: qualityFromRes(info.resolution) });
        info = null;
      }
    }
    return out;
  }

  function headersForUrl(url, upstream) {
    var host = String(url || '').toLowerCase();
    if (host.indexOf('hakunaymatata.com') >= 0) {
      return { 'User-Agent': headers['User-Agent'] };
    }
    var out = {
      'User-Agent': headers['User-Agent'],
      Referer: headers.Referer,
      Origin: headers.Origin,
    };
    if (upstream) {
      for (var k in upstream) {
        if (Object.prototype.hasOwnProperty.call(upstream, k)) out[k] = upstream[k];
      }
    }
    return out;
  }

  function rowsFromData(data, title) {
    var out = [];
    var playlists = [];
    function push(url, quality, upstream, needsProxy) {
      if (!url) return;
      var row = {
        url: url,
        title: 'Vidlink · ' + (quality || 'Auto'),
        headers: headersForUrl(url, upstream),
      };
      if (needsProxy) row.requiresProxy = true;
      out.push(row);
    }
    if (data.stream && data.stream.qualities) {
      var quals = data.stream.qualities;
      for (var k in quals) {
        if (!Object.prototype.hasOwnProperty.call(quals, k)) continue;
        var q = quals[k];
        if (q && q.url) push(q.url, k, q.headers, q.requiresProxy === true);
      }
      if (data.stream.playlist) playlists.push(data.stream.playlist);
    } else if (data.stream && data.stream.playlist) {
      playlists.push(data.stream.playlist);
    } else if (data.url) {
      push(data.url, 'Auto', null, false);
    }
    if (!playlists.length) return Promise.resolve(out);
    return Promise.all(
      playlists.map(function (pl) {
        return req(pl, { headers: headers })
          .then(function (r) {
            return r.text();
          })
          .then(function (text) {
            return parseM3u8(text, pl);
          })
          .catch(function () {
            return [{ url: pl, quality: 'Auto' }];
          });
      }),
    ).then(function (groups) {
      for (var g = 0; g < groups.length; g++) {
        var items = groups[g] || [];
        for (var j = 0; j < items.length; j++) {
          push(items[j].url, items[j].quality, null, false);
        }
      }
      if (!out.length && playlists.length) push(playlists[0], 'Auto', null, false);
      return out;
    });
  }

  function tmdbMeta() {
    if (ctx.title) {
      return Promise.resolve({ title: ctx.title, year: ctx.year || '' });
    }
    var ep = isTv ? 'tv' : 'movie';
    return req('https://api.themoviedb.org/3/' + ep + '/' + tmdbId + '?api_key=' + TMDB_KEY)
      .then(function (r) {
        return r.json();
      })
      .then(function (d) {
        return {
          title: isTv ? d.name : d.title,
          year: ((isTv ? d.first_air_date : d.release_date) || '').substring(0, 4),
        };
      });
  }

  return tmdbMeta()
    .then(function () {
      return req(ENC + '/enc-vidlink?text=' + encodeURIComponent(tmdbId)).then(function (r) {
        return r.json();
      });
    })
    .then(function (enc) {
      var id = enc && enc.result;
      if (!id) return [];
      var url =
        isTv && ctx.season && ctx.episode
          ? API + '/tv/' + id + '/' + ctx.season + '/' + ctx.episode
          : API + '/movie/' + id;
      return req(url).then(function (r) {
        return r.json();
      });
    })
    .then(function (data) {
      if (!data) return [];
      return rowsFromData(data, ctx.title || 'Vidlink');
    })
    .catch(function () {
      return [];
    });
}
