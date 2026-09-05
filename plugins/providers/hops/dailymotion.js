function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var cfg = ctx.config || {};
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var origin = 'https://www.dailymotion.com/';
  var sessionCookies = { family_filter: 'off', ff: 'off' };

  function row(u, extra) {
    extra = extra || {};
    var headers = Object.assign(
      { 'User-Agent': ua, Referer: extra.referer || origin },
      extra.headers || {}
    );
    var cookie = cookieHeader();
    if (cookie && !headers.Cookie) headers.Cookie = cookie;
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
      extra || {}
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
      var first = urls[0];
      if (!first) continue;
      out.push({
        url: first,
        lang: lang,
        label: info.label || lang,
      });
    }
    return out;
  }

  function streamsFromMeta(meta) {
    if (!meta || meta.error) return [];
    var qualities = meta.qualities || {};
    var subs = collectSubtitles(meta);
    var out = [];
    var seen = {};

    function push(u, quality) {
      if (!u || seen[u]) return;
      seen[u] = 1;
      out.push(
        row(u, {
          quality: quality,
          subtitles: subs.length ? subs : undefined,
        })
      );
    }

    // Progressive MP4 first (when present), then HLS auto.
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
          push(m.url, qualityLabel(key));
        }
      }
    }

    var autoList = qualities.auto || qualities.Auto || [];
    for (var k = 0; k < autoList.length; k++) {
      var h = autoList[k] || {};
      if (!h.url || h.type === 'application/vnd.lumberjack.manifest') continue;
      if (
        h.type === 'application/x-mpegURL' ||
        /\.m3u8(\?|$)/i.test(h.url)
      ) {
        push(h.url, 'Auto');
      }
    }

    // Fallback: any remaining playable URL in qualities.
    if (!out.length) {
      for (var qi = 0; qi < keys.length; qi++) {
        var qk = keys[qi];
        var ql = qualities[qk] || [];
        for (var qj = 0; qj < ql.length; qj++) {
          var item = ql[qj] || {};
          if (!item.url || item.type === 'application/vnd.lumberjack.manifest') continue;
          push(item.url, qualityLabel(qk));
        }
      }
    }

    return out;
  }

  var id = videoId(url);
  if (!id) return Promise.resolve([]);

  var metaUrl =
    'https://www.dailymotion.com/player/metadata/video/' +
    id +
    '?app=com.dailymotion.neon';

  // Warm session cookies, then hit the public player metadata endpoint.
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
