function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://hexa.su';
  var api = (cfg.api || 'https://theemoviedb.hexa.su').replace(/\/$/, '');
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var path =
    ctx.type === 'movie'
      ? '/api/tmdb/movie/' + tmdbId + '/images'
      : '/api/tmdb/tv/' +
        tmdbId +
        '/season/' +
        (ctx.season || 1) +
        '/episode/' +
        (ctx.episode || 1) +
        '/images';
  var CryptoJS = ctx.crypto;
  var key = '';
  try {
    if (CryptoJS && CryptoJS.lib && CryptoJS.lib.WordArray && CryptoJS.lib.WordArray.random) {
      key = CryptoJS.lib.WordArray.random(32).toString(CryptoJS.enc.Hex);
    }
  } catch (e) {
    key = '';
  }
  if (!key) {
    var hex = '';
    for (var i = 0; i < 32; i++) {
      var h = Math.floor(Math.random() * 256).toString(16);
      hex += h.length < 2 ? '0' + h : h;
    }
    key = hex;
  }
  var apiHeaders = {
    'User-Agent': ua,
    Referer: origin + '/',
    Accept: 'text/plain',
    'X-Fingerprint-Lite': cfg.fingerprint || 'e9136c41504646444',
    'X-Api-Key': key,
  };

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  function playHeaders(extraReferer) {
    return {
      'User-Agent': ua,
      Referer: extraReferer || origin + '/',
    };
  }

  function isDirectStream(url) {
    return (
      /\.m3u8|\.mp4|\.mpd/i.test(url) ||
      /\/playlist\/|\/hls\/|master\.txt/i.test(url)
    );
  }

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o)) o.forEach(function (e) { walk(e, urls); });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream', 'link', 'sources'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  function rowsFromPayload(payload) {
    var hdrs = playHeaders(payload && payload.referer);
    if (payload && Array.isArray(payload.sources) && payload.sources.length) {
      return Promise.resolve(
        payload.sources
          .filter(function (s) {
            return s && s.url;
          })
          .map(function (s) {
            var label = 'Hexa';
            if (s.server) label += ' ' + s.server;
            else if (s.quality) label += ' ' + s.quality;
            return {
              url: s.url,
              name: label,
              quality: s.quality || '',
              headers: hdrs,
            };
          }),
      );
    }
    var urls = [];
    walk(payload, urls);
    return Promise.all(
      urls.map(function (u) {
        if (isDirectStream(u)) {
          return Promise.resolve([
            {
              url: u,
              name: 'Hexa',
              headers: hdrs,
            },
          ]);
        }
        return ctx.hop(u);
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  return ctx
    .fetch(enc + '/enc-hexa', { headers: { 'User-Agent': ua } })
    .then(function (r) {
      return r.json();
    })
    .then(function (j) {
      var token = (validate(j) || {}).token;
      if (!token) {
        ctx.error('hexa: no enc token');
        return null;
      }
      apiHeaders['X-Cap-Token'] = token;
      return ctx.fetch(api + path, { headers: apiHeaders }).then(function (r) {
        return r.text();
      });
    })
    .then(function (encrypted) {
      var text = (encrypted || '').trim();
      if (!text || /^</.test(text)) {
        ctx.error('hexa: empty or blocked api response');
        return [];
      }
      return ctx
        .fetch(enc + '/dec-hexa', {
          method: 'POST',
          headers: {
            'User-Agent': ua,
            Accept: 'application/json',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ text: text, key: key }),
        })
        .then(function (r) {
          return r.json();
        })
        .then(function (dj) {
          var payload = validate(dj);
          if (!payload) {
            ctx.error('hexa: decrypt failed');
            return [];
          }
          return rowsFromPayload(payload);
        });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
