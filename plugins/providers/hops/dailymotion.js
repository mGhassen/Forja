function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var cfg = ctx.config || {};
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var origin = 'https://www.dailymotion.com/';
  var sessionCookies = { family_filter: 'off', ff: 'off' };
  var chromeFetch =
    typeof ctx.chromeFetch === 'function' ? ctx.chromeFetch.bind(ctx) : ctx.fetch.bind(ctx);

  function row(u, extra) {
    extra = extra || {};
    var headers = Object.assign(
      { 'User-Agent': ua, Referer: extra.referer || origin },
      extra.headers || {},
    );
    return {
      url: u,
      name: extra.name || cfg.name || 'Dailymotion',
      quality: extra.quality || '',
      headers: headers,
      subtitles: extra.subtitles || undefined,
    };
  }

  function storeCookies(headers) {
    if (!headers) return;
    var raw =
      typeof headers.getSetCookie === 'function'
        ? headers.getSetCookie()
        : [headers.get && headers.get('set-cookie')].filter(Boolean);
    for (var i = 0; i < raw.length; i++) {
      var parts = String(raw[i] || '').split(/,(?=[^;,]+=)/);
      for (var j = 0; j < parts.length; j++) {
        var pair = parts[j].split(';')[0].trim();
        var eq = pair.indexOf('=');
        if (eq > 0) sessionCookies[pair.slice(0, eq)] = pair.slice(eq + 1);
      }
    }
  }

  function cookieHeader() {
    var out = [];
    for (var k in sessionCookies) {
      if (!Object.prototype.hasOwnProperty.call(sessionCookies, k)) continue;
      out.push(k + '=' + sessionCookies[k]);
    }
    return out.join('; ');
  }

  function browserHeaders(extra) {
    return Object.assign(
      {
        'User-Agent': ua,
        Accept: '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        Referer: origin,
        Origin: 'https://www.dailymotion.com',
        Cookie: cookieHeader(),
      },
      extra || {},
    );
  }

  function videoId(raw) {
    var s = String(raw || '').trim();
    if (!s) return '';
    if (/^[a-zA-Z0-9]+$/.test(s) && s.length >= 5 && s.length <= 12) return s;
    var m =
      s.match(/dailymotion\.com\/(?:embed\/)?video\/([a-zA-Z0-9]+)/i) ||
      s.match(/dailymotion\.com\/live\/([a-zA-Z0-9]+)/i) ||
      s.match(/dai\.ly\/([a-zA-Z0-9]+)/i) ||
      s.match(/[?&#]video=([a-zA-Z0-9]+)/i) ||
      s.match(/\/player(?:\/[^/?#]*)?\?(?:[^#]*&)?video=([a-zA-Z0-9]+)/i);
    return m ? m[1] : '';
  }

  function qualityLabel(key) {
    var k = String(key || '').replace(/@\d+/g, '');
    if (!k || k.toLowerCase() === 'auto') return 'Auto';
    if (/^\d+$/.test(k)) return k + 'p';
    return k;
  }

  function collectSubtitles(meta) {
    var subs = meta && meta.subtitles;
    var data = subs && subs.data;
    if (!data || typeof data !== 'object') return [];
    var out = [];
    for (var lang in data) {
      if (!Object.prototype.hasOwnProperty.call(data, lang)) continue;
      var info = data[lang] || {};
      var urls = info.urls || [];
      if (!urls[0]) continue;
      out.push({ url: urls[0], lang: lang, label: info.label || lang });
    }
    return out;
  }

  function resolveRelative(line, baseUrl) {
    if (!line) return '';
    if (/^https?:\/\//i.test(line)) return line;
    if (line.indexOf('//') === 0) return 'https:' + line;
    try {
      return new URL(line, baseUrl).toString();
    } catch (e) {
      return line;
    }
  }

  function isDirectorMaster(u) {
    return /cdndirector\.dailymotion\.com/i.test(String(u || ''));
  }

  // Expand fingerprinted master → playable dmcdn media playlists.
  function expandMaster(masterUrl, subs) {
    return chromeFetch(masterUrl, {
      headers: browserHeaders({ Accept: 'application/vnd.apple.mpegurl,*/*' }),
    })
      .then(function (r) {
        if (!r.ok) return [];
        return r.text().then(function (text) {
          var lines = String(text || '').split('\n');
          var out = [];
          var info = null;
          var seen = {};
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            if (line.indexOf('#EXT-X-STREAM-INF:') === 0) {
              info = {};
              var name = line.match(/NAME="([^"]+)"/i);
              var res = line.match(/RESOLUTION=(\d+)x(\d+)/i);
              if (name) info.quality = qualityLabel(name[1]);
              else if (res) info.quality = qualityLabel(res[2]);
              else info.quality = 'Auto';
            } else if (line.charAt(0) !== '#') {
              var abs = resolveRelative(line, masterUrl);
              if (abs && !seen[abs]) {
                seen[abs] = 1;
                out.push(
                  row(abs, {
                    quality: (info && info.quality) || 'Auto',
                    subtitles: subs.length ? subs : undefined,
                  }),
                );
              }
              info = null;
            }
          }
          return out;
        });
      })
      .catch(function () {
        return [];
      });
  }

  function streamsFromMeta(meta) {
    if (!meta || meta.error) return Promise.resolve([]);
    var qualities = meta.qualities || {};
    var subs = collectSubtitles(meta);
    var direct = [];
    var masters = [];
    var seen = {};

    function takeDirect(u, quality) {
      if (!u || seen[u] || isDirectorMaster(u)) return;
      seen[u] = 1;
      direct.push(
        row(u, {
          quality: quality,
          subtitles: subs.length ? subs : undefined,
        }),
      );
    }

    function takeMaster(u) {
      if (!u || seen[u]) return;
      seen[u] = 1;
      masters.push(u);
    }

    var keys = Object.keys(qualities);
    keys.sort(function (a, b) {
      var na = parseInt(String(a).replace(/@\d+/g, ''), 10);
      var nb = parseInt(String(b).replace(/@\d+/g, ''), 10);
      if (isNaN(na) && isNaN(nb)) return 0;
      if (isNaN(na)) return 1;
      if (isNaN(nb)) return -1;
      return nb - na;
    });

    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (String(key).toLowerCase() === 'auto') continue;
      var list = qualities[key] || [];
      for (var j = 0; j < list.length; j++) {
        var m = list[j] || {};
        if (!m.url || m.type === 'application/vnd.lumberjack.manifest') continue;
        if (m.type === 'video/mp4' || /\.mp4(\?|$)/i.test(m.url)) {
          takeDirect(m.url, qualityLabel(key));
        } else if (
          m.type === 'application/x-mpegURL' ||
          /\.m3u8(\?|$)/i.test(m.url)
        ) {
          if (isDirectorMaster(m.url)) takeMaster(m.url);
          else takeDirect(m.url, qualityLabel(key));
        }
      }
    }

    var autoList = qualities.auto || qualities.Auto || [];
    for (var k = 0; k < autoList.length; k++) {
      var h = autoList[k] || {};
      if (!h.url || h.type === 'application/vnd.lumberjack.manifest') continue;
      if (h.type === 'application/x-mpegURL' || /\.m3u8(\?|$)/i.test(h.url)) {
        if (isDirectorMaster(h.url)) takeMaster(h.url);
        else takeDirect(h.url, 'Auto');
      }
    }

    if (!direct.length && !masters.length) {
      for (var qi = 0; qi < keys.length; qi++) {
        var qk = keys[qi];
        var ql = qualities[qk] || [];
        for (var qj = 0; qj < ql.length; qj++) {
          var item = ql[qj] || {};
          if (!item.url || item.type === 'application/vnd.lumberjack.manifest') continue;
          if (isDirectorMaster(item.url)) takeMaster(item.url);
          else takeDirect(item.url, qualityLabel(qk));
        }
      }
    }

    if (!masters.length) return Promise.resolve(direct);

    return Promise.all(
      masters.map(function (mu) {
        return expandMaster(mu, subs);
      }),
    ).then(function (chunks) {
      var out = direct.slice();
      var seenUrl = {};
      for (var d = 0; d < out.length; d++) seenUrl[out[d].url] = 1;
      for (var c = 0; c < chunks.length; c++) {
        var rows = chunks[c] || [];
        for (var r = 0; r < rows.length; r++) {
          if (!rows[r] || !rows[r].url || seenUrl[rows[r].url]) continue;
          seenUrl[rows[r].url] = 1;
          out.push(rows[r]);
        }
      }
      // Prefer higher qualities first.
      out.sort(function (a, b) {
        var pa = parseInt(String(a.quality || '').replace(/\D/g, ''), 10) || 0;
        var pb = parseInt(String(b.quality || '').replace(/\D/g, ''), 10) || 0;
        return pb - pa;
      });
      return out;
    });
  }

  var id = videoId(url);
  if (!id) return Promise.resolve([]);

  var metaUrl =
    'https://www.dailymotion.com/player/metadata/video/' +
    id +
    '?app=com.dailymotion.neon';

  return ctx
    .fetch(origin, { headers: browserHeaders({ Accept: 'text/html' }) })
    .then(function (r) {
      storeCookies(r.headers);
      return ctx.fetch(metaUrl, {
        headers: browserHeaders({ Accept: 'application/json' }),
      });
    })
    .then(function (r) {
      storeCookies(r.headers);
      return r.json();
    })
    .then(function (meta) {
      return streamsFromMeta(meta);
    })
    .catch(function () {
      return [];
    });
}
