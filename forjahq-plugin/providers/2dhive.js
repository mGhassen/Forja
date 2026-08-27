function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://2dhive.com').replace(/\/$/, '');
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua };
  var title = String(ctx.title || '');
  var epNum = ctx.type === 'movie' ? 1 : ctx.episode || 1;
  var audio = 'sub';

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

  function malId() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) return Promise.resolve(fromHost.malId);
    if (!title) return Promise.resolve(null);
    var type = ctx.type === 'movie' ? 'movie' : 'tv';
    return getJson(jikan + '?q=' + encodeURIComponent(title) + '&type=' + type + '&limit=1')
      .then(function (d) {
        return d && d.data && d.data[0] ? d.data[0].mal_id : null;
      })
      .catch(function () {
        return null;
      });
  }

  function astroDecode(v) {
    if (!Array.isArray(v)) return v;
    var type = v[0];
    var data = v[1];
    if (type === 0) {
      if (!data || typeof data !== 'object' || Array.isArray(data)) return data;
      var o = {};
      Object.keys(data).forEach(function (k) {
        o[k] = astroDecode(data[k]);
      });
      return o;
    }
    if (type === 1) return Array.isArray(data) ? data.map(astroDecode) : data;
    return data;
  }

  function extractProps(html) {
    var idx = html.indexOf('prefetchedHls');
    if (idx < 0) return null;
    var propsIdx = html.lastIndexOf('props="', idx);
    if (propsIdx < 0) return null;
    var valueIdx = propsIdx + 7;
    var endIdx = html.indexOf('"', valueIdx);
    if (endIdx < 0) return null;
    var raw = html
      .slice(valueIdx, endIdx)
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>');
    try {
      var parsed = JSON.parse(raw);
      var out = {};
      Object.keys(parsed).forEach(function (k) {
        out[k] = astroDecode(parsed[k]);
      });
      return out;
    } catch (e) {
      return null;
    }
  }

  return malId()
    .then(function (mal) {
      if (!mal) return ctx.host('2dhive');
      var referer = base + '/episode?anime=' + mal + '&ep_num=' + epNum;
      var mega = 'https://megaplay.buzz/stream/mal/' + mal + '/' + epNum + '/' + audio;
      return Promise.all([
        getText(referer, { Referer: base + '/' })
          .then(extractProps)
          .catch(function () {
            return null;
          }),
        getJson(base + '/api/hianime?mal_id=' + mal + '&ep_num=' + epNum, { Referer: referer }).catch(
          function () {
            return null;
          },
        ),
        ctx.hop(mega),
      ]).then(function (parts) {
        var props = parts[0];
        var hi = parts[1];
        var hopped = parts[2] || [];
        var rows = hopped.slice();
        if (hi && hi.m3u8) {
          rows.push({
            url: hi.m3u8,
            name: '2DHive hiAnime',
            headers: { 'User-Agent': ua, Referer: referer },
          });
        }
        var servers = props && Array.isArray(props.servers) ? props.servers : [];
        var had = servers.filter(function (s) {
          return s && s.server_name === 'HAdfree' && s.slug && !s.dub;
        });
        return Promise.all(
          had.slice(0, 4).map(function (entry) {
            return getJson(base + '/api/hadfree?slug=' + encodeURIComponent(entry.slug), {
              Referer: referer,
            })
              .then(function (j) {
                return j && j.streamUrl
                  ? [
                      {
                        url: j.streamUrl,
                        name: '2DHive HAdfree',
                        headers: { 'User-Agent': ua, Referer: referer },
                      },
                    ]
                  : [];
              })
              .catch(function () {
                return [];
              });
          }),
        ).then(function (groups) {
          var out = rows.concat.apply(rows, groups || []);
          return out.length ? out : ctx.host('2dhive');
        });
      });
    })
    .catch(function () {
      return ctx.host('2dhive');
    });
}
