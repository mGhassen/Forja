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
  // Same mwVault proxy as vidlink.pro (module 5196 / mooncase mp prefix).
  var MWVAULT_PROXY = 'https://noon.mooncase.online/';
  var MWVAULT_KEEP_QUERY = {
    auth: 1,
    expires: 1,
    hash: 1,
    key: 1,
    sign: 1,
    t: 1,
    token: 1,
  };

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
        var codecs = line.match(/CODECS="([^"]+)"/i);
        if (bw) info.bandwidth = parseInt(bw[1], 10);
        if (res) info.resolution = res[1];
        if (codecs) info.codecs = codecs[1];
      } else if (info && line.charAt(0) !== '#') {
        var url = resolveRelative(line, baseUrl);
        var row = { url: url, quality: qualityFromRes(info.resolution) };
        var c = String(info.codecs || '').toLowerCase();
        if (c.indexOf('mp4a') >= 0 || c.indexOf('aac') >= 0) row.audio = 'AAC';
        out.push(row);
        info = null;
      }
    }
    return out;
  }

  function decodeQueryKey(pair) {
    var k = pair.split('=')[0];
    try {
      return decodeURIComponent(String(k).replace(/\+/g, ' ')).toLowerCase();
    } catch (e) {
      return String(k).toLowerCase();
    }
  }

  function normalizeHeaderMap(raw) {
    if (!raw || typeof raw !== 'object') return {};
    var out = {};
    for (var k in raw) {
      if (!Object.prototype.hasOwnProperty.call(raw, k)) continue;
      var v = raw[k];
      if (typeof v !== 'string' || /[\0\r\n]/.test(k + v)) return null;
      out[k] = v;
    }
    return out;
  }

  function headersParam(raw) {
    var map = normalizeHeaderMap(raw);
    if (map === null) return null;
    var keys = Object.keys(map).sort();
    var sorted = {};
    for (var i = 0; i < keys.length; i++) {
      sorted[keys[i]] = map[keys[i]];
    }
    // vidlink.pro mwVault mp proxy expects URL-encoded JSON, not base64url.
    return encodeURIComponent(JSON.stringify(sorted));
  }

  function parseHttpUrl(url) {
    var m = String(url || '').match(/^(https?):\/\/([^/?#]+)([^?#]*)(\?([^#]*))?/);
    if (!m) return null;
    return {
      origin: m[1] + '://' + m[2],
      pathname: m[3] || '/',
      search: m[5] || '',
    };
  }

  function queryHasProxyParams(search) {
    return String(search || '')
      .split('&')
      .filter(Boolean)
      .some(function (pair) {
        var k = decodeQueryKey(pair);
        return k === 'headers' || k === 'host';
      });
  }

  function keepMwVaultQuery(search) {
    return String(search || '')
      .split('&')
      .filter(Boolean)
      .filter(function (pair) {
        return MWVAULT_KEEP_QUERY[decodeQueryKey(pair)];
      })
      .join('&');
  }

  function buildMwVaultMpProxy(url, hdrs) {
    var parsed = parseHttpUrl(url);
    var headersEnc = headersParam(hdrs);
    if (!parsed || headersEnc === null || queryHasProxyParams(parsed.search)) {
      return null;
    }
    var parts = [];
    var kept = keepMwVaultQuery(parsed.search);
    if (kept) parts.push(kept);
    parts.push('headers=' + headersEnc); // already encodeURIComponent(JSON)
    parts.push('host=' + encodeURIComponent(parsed.origin));
    var base = MWVAULT_PROXY.replace(/\/?$/, '/');
    return base + 'mp' + parsed.pathname + '?' + parts.join('&');
  }

  function headersForUrl(url, upstream) {
    var host = String(url || '').toLowerCase();
    if (host.indexOf('hakunaymatata.com') >= 0) {
      var hakuna = { 'User-Agent': headers['User-Agent'] };
      if (upstream) {
        for (var hk in upstream) {
          if (!Object.prototype.hasOwnProperty.call(upstream, hk)) continue;
          var lk = String(hk).toLowerCase();
          if (lk === 'referer' || lk === 'origin') continue;
          if (typeof upstream[hk] === 'string' && upstream[hk]) hakuna[hk] = upstream[hk];
        }
      }
      return hakuna;
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
      var hdrs = headersForUrl(url, upstream);
      var playUrl = url;
      var useSeekProxy = false;
      if (needsProxy) {
        var proxied = buildMwVaultMpProxy(url, hdrs);
        if (proxied) {
          playUrl = proxied;
          hdrs = {};
        } else {
          useSeekProxy = true;
        }
      }
      var q = quality && quality !== 'Auto' ? quality : '';
      var row = {
        url: playUrl,
        name: 'Vidlink',
        quality: q,
        headers: hdrs,
      };
      if (useSeekProxy) row.requiresProxy = true;
      out.push(row);
    }
    var stream = data.stream;
    var playlistUrl = stream && stream.playlist;
    var isDash =
      (stream && stream.deliveryType === 'dash') ||
      (playlistUrl && String(playlistUrl).indexOf('.mpd') >= 0);
    if (isDash && playlistUrl) {
      // Native player sends CloudFront cookies; mooncase /mp is a browser CORS
      // shim and 428s these MovieBox progressive URLs.
      push(playlistUrl, 'Auto', stream.playlistHeaders || {}, false);
      return Promise.resolve(out);
    }
    if (stream && stream.qualities) {
      var quals = stream.qualities;
      for (var k in quals) {
        if (!Object.prototype.hasOwnProperty.call(quals, k)) continue;
        var q = quals[k];
        if (q && q.url) push(q.url, k, q.headers, q.requiresProxy === true);
      }
      if (playlistUrl) playlists.push(playlistUrl);
    } else if (playlistUrl) {
      playlists.push(playlistUrl);
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
          var item = items[j];
          push(item.url, item.quality, null, false);
          if (item.audio && out.length) out[out.length - 1].audio = item.audio;
        }
      }
      if (!out.length && playlists.length) push(playlists[0], 'Auto', null, false);
      return out;
    });
  }

  function log(msg) {
    try {
      console.log('[vidlink] ' + msg);
    } catch (e) { }
  }

  function peekJson(r, label) {
    return r.text().then(function (text) {
      log(
        label +
        ' status=' +
        r.status +
        ' ok=' +
        r.ok +
        ' len=' +
        (text ? String(text).length : 0),
      );
      try {
        return text ? JSON.parse(text) : null;
      } catch (e) {
        log(
          label +
          ' parse fail ' +
          (e && e.message ? e.message : e) +
          ' body=' +
          String(text || '').substring(0, 160),
        );
        return null;
      }
    });
  }

  function tmdbMeta() {
    if (ctx.title) {
      return Promise.resolve({ title: ctx.title, year: ctx.year || '' });
    }
    var ep = isTv ? 'tv' : 'movie';
    return req('https://api.themoviedb.org/3/' + ep + '/' + tmdbId + '?api_key=' + TMDB_KEY)
      .then(function (r) {
        return peekJson(r, 'tmdb');
      })
      .then(function (d) {
        return {
          title: isTv ? d.name : d.title,
          year: ((isTv ? d.first_air_date : d.release_date) || '').substring(0, 4),
        };
      });
  }

  log(
    'extract tmdb=' +
    tmdbId +
    ' type=' +
    ctx.type +
    ' title=' +
    (ctx.title ? 'yes' : 'no'),
  );

  return tmdbMeta()
    .then(function () {
      return req(ENC + '/enc-vidlink?text=' + encodeURIComponent(tmdbId)).then(function (r) {
        return peekJson(r, 'enc');
      });
    })
    .then(function (enc) {
      var id = enc && enc.result;
      if (!id) {
        log('no enc result keys=' + (enc ? Object.keys(enc).join(',') : 'null'));
        return [];
      }
      var url =
        isTv && ctx.season && ctx.episode
          ? API + '/tv/' + id + '/' + ctx.season + '/' + ctx.episode + '?multiLang=0'
          : API + '/movie/' + id;
      return req(url, {
        headers: { 'X-Playback-Environment': 'dash-hevc' },
      }).then(function (r) {
        return peekJson(r, 'api');
      });
    })
    .then(function (data) {
      if (!data) {
        log('api json null');
        return [];
      }
      var stream = data.stream || {};
      log(
        'api shape source=' +
        (data.sourceId || '') +
        ' delivery=' +
        (stream.deliveryType || '') +
        ' playlist=' +
        (stream.playlist ? 'yes' : 'no') +
        ' qualities=' +
        (stream.qualities ? 'yes' : 'no'),
      );
      return rowsFromData(data, ctx.title || 'Vidlink');
    })
    .then(function (rows) {
      log('rows=' + ((rows && rows.length) || 0));
      return rows;
    })
    .catch(function (e) {
      log('fail ' + (e && e.message ? e.message : String(e)));
      return [];
    });
}
