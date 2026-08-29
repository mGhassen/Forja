var SPECS = {
  "bases": [
    "https://www.miruro.tv",
    "https://www.miruro.to",
    "https://www.miruro.bz"
  ]
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var bases = (Array.isArray(cfg.bases) ? cfg.bases : []).map(function (b) {
    return String(b).replace(/\/$/, '');
  });
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var isEpisodic = ctx.type !== 'movie';
  var epNum = isEpisodic
    ? Number(ctx.mappedEpisode || ctx.episode || 1) || 1
    : 1;
  var providers = cfg.providers || ['bonk', 'kiwi', 'bee', 'bun', 'ally', 'moo', 'hop', 'zoro'];

  function encodeReq(payload) {
    if (ctx.crypto && ctx.crypto.encodePipe) return ctx.crypto.encodePipe(payload);
    return '';
  }

  function decodeBody(text, xObf) {
    if (ctx.crypto && ctx.crypto.decodePipe) {
      var first = ctx.crypto.decodePipe(text, xObf);
      if (first) return first;
      // WKWebView / CORS often omit x-obfuscated — try known levels.
      if (!xObf) {
        var l2 = ctx.crypto.decodePipe(text, '2');
        if (l2) return l2;
        var l1 = ctx.crypto.decodePipe(text, '1');
        if (l1) return l1;
      }
      return null;
    }
    try {
      return JSON.parse(text);
    } catch (e) {
      return null;
    }
  }

  function pipeGet(base, payload) {
    var e = encodeReq(payload);
    if (!e) return Promise.resolve(null);
    var url = base + '/api/secure/pipe?e=' + e;
    return ctx
      .fetch(url, {
        headers: {
          'User-Agent': ua,
          Referer: base + '/',
          Origin: base,
          Accept: 'application/json, text/plain, */*',
        },
      })
      .then(function (r) {
        if (!r.ok) return null;
        return r.text().then(function (text) {
          var xObf = (
            r.headers.get('x-obfuscated') ||
            r.headers.get('X-Obfuscated') ||
            r.headers.get('x-obf') ||
            r.headers.get('X-Obf') ||
            ''
          ).trim();
          return decodeBody(text, xObf);
        });
      })
      .catch(function () {
        return null;
      });
  }

  function pipeAny(payload) {
    var chain = Promise.resolve(null);
    bases.forEach(function (base) {
      chain = chain.then(function (found) {
        if (found) return found;
        return pipeGet(base, payload).then(function (data) {
          if (data) data._base = base;
          return data;
        });
      });
    });
    return chain;
  }

  function anilistId() {
    if (ctx.anilistId) return Promise.resolve(Number(ctx.anilistId));
    var fromHost = globalThis.__engineCtxAnilist && globalThis.__engineCtxAnilist(ctx);
    if (fromHost) return Promise.resolve(Number(fromHost));
    return Promise.resolve(0);
  }

  function pickHls(streams, headers, base) {
    var list = Array.isArray(streams) ? streams : [];
    var hls = list.filter(function (s) {
      var t = String((s && s.type) || '').toLowerCase();
      if (t === 'iframe' || t === 'embed' || t === 'html' || t === 'player') return false;
      var u = String((s && (s.url || s.file)) || '');
      if (!/^https?:/i.test(u)) return false;
      if (t === 'hls' || t === 'file' || t === 'mp4' || t === 'dash') return true;
      return /\.m3u8|\.mp4|\/hls|master\.m3u8/i.test(u);
    });
    var candidates = hls.length
      ? hls
      : list.filter(function (s) {
          return (
            s &&
            /^https?:/i.test(String(s.url || s.file || '')) &&
            String(s.type || '').toLowerCase() !== 'embed'
          );
        });
    candidates.sort(function (a, b) {
      if (a.default && !b.default) return -1;
      if (!a.default && b.default) return 1;
      var qa = parseInt(String(a.quality || '').replace(/\D/g, ''), 10) || 0;
      var qb = parseInt(String(b.quality || '').replace(/\D/g, ''), 10) || 0;
      return qb - qa;
    });
    var best = candidates[0];
    if (!best) return null;
    var referer =
      (best.referer ||
        best.Referer ||
        (headers && (headers.Referer || headers.referer || headers.Origin || headers.origin)) ||
        '') + '';
    if (!referer) referer = base + '/';
    return {
      url: best.url || best.file,
      name: 'Miruro ' + (best.server || best.label || best.name || 'HLS'),
      headers: { 'User-Agent': ua, Referer: referer },
    };
  }

  function episodesFor(prov, category) {
    var eps = prov && prov.episodes;
    if (!eps) return [];
    if (Array.isArray(eps)) return category === 'sub' ? eps : [];
    return eps[category] || [];
  }

  return anilistId()
    .then(function (al) {
      if (!al) return [];
      return pipeAny({
        path: 'episodes',
        method: 'GET',
        query: { anilistId: String(al) },
        body: null,
        version: '0.2.0',
      }).then(function (data) {
        if (!data || !data.providers) return [];
        var provMap = data.providers;
        var names = providers.concat(
          Object.keys(provMap).filter(function (k) {
            return providers.indexOf(k) < 0;
          }),
        );
        var tasks = [];
        names.slice(0, 8).forEach(function (name) {
          var prov = provMap[name];
          if (!prov) return;
          ['sub', 'dub'].forEach(function (cat) {
            var eps = episodesFor(prov, cat);
            var ep = eps.find(function (e) {
              return Number(e.number || e.num) === Number(epNum);
            });
            if (!ep || !ep.id) return;
            // episodeId is the raw pipe id — do NOT base64 it again (whole payload is encoded).
            tasks.push(
              pipeGet(data._base || bases[0], {
                path: 'sources',
                method: 'GET',
                query: {
                  episodeId: String(ep.id),
                  provider: name,
                  category: cat,
                  anilistId: String(al),
                },
                body: null,
                version: '0.2.0',
              }).then(function (src) {
                if (!src) return [];
                var streams = src.streams || src.sources;
                var row = pickHls(streams, src.headers, data._base || bases[0]);
                if (!row) return [];
                row.name = 'Miruro ' + name + ' ' + cat.toUpperCase();
                row.language = cat === 'dub' ? 'Dub' : 'Sub';
                return [row];
              }),
            );
          });
        });
        return Promise.all(tasks).then(function (groups) {
          var seen = {};
          var out = [];
          ;[].concat.apply([], groups).forEach(function (r) {
            if (!r || !r.url || seen[r.url]) return;
            seen[r.url] = true;
            out.push(r);
          });
          return out;
        });
      });
    })
    .catch(function () {
      return [];
    });
}
