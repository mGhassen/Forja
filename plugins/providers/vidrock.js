var SPECS = {
  "origin": "https://vidrock.ru",
  "aesKey": "7f3e9c2a8b5d1f4e6a9c3b7d2e5f8a1c4b6d9e2f5a8c1b4d7e9f2a5c8b1d4e7f"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var origin = cfg.origin;
  var aesKey = cfg.aesKey;
  var ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    Referer: origin + '/',
    Origin: origin,
  };
  var playHeaders = {
    'User-Agent': ua,
    Referer: origin + '/',
    Origin: origin,
  };
  var tmdbId = String(ctx.tmdbId);
  var path =
    ctx.type === 'movie'
      ? 'movie/' + tmdbId
      : 'tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);

  function qualityOf(url) {
    var m = String(url || '').match(/(\d{3,4})p/i);
    return m ? m[1] + 'p' : '';
  }

  function needsHeaders(name, url) {
    if (name === 'Astra') return true;
    return /cdn\.vidrock\.store|proxy\.vidrock\.store|hls1\.vdrk\.site|cdn\.niggaflix\.xyz|1shows\.app|streamrk\.site/i.test(
      url || '',
    );
  }

  function isAstraPlaylist(url) {
    return /cdn\.vidrock\.store\/playlist\//i.test(url || '') ||
      /streamrk\.site\/playlist\//i.test(url || '');
  }

  function row(url, name, language) {
    var hdrs = needsHeaders(name, url) ? playHeaders : undefined;
    var label = 'VidRock ' + name + (language ? ' [' + language + ']' : '');
    var out = { url: url, name: label, quality: qualityOf(url) };
    if (hdrs) out.headers = hdrs;
    return out;
  }

  function decryptUrl(enc) {
    if (!enc) return '';
    if (/^https?:\/\//i.test(enc)) return enc;
    var CryptoJS = ctx.crypto;
    if (!CryptoJS || !aesKey) return '';
    try {
      var packed = CryptoJS.enc.Base64.parse(enc);
      var hex = CryptoJS.enc.Hex.stringify(packed);
      if (hex.length < 56) return '';
      var iv = CryptoJS.enc.Hex.parse(hex.substring(0, 24));
      var ct = CryptoJS.enc.Hex.parse(hex.substring(24));
      var pt = CryptoJS.AES.decrypt(
        { ciphertext: ct },
        CryptoJS.enc.Hex.parse(aesKey),
        { iv: iv, mode: CryptoJS.mode.GCM },
      );
      return CryptoJS.enc.Utf8.stringify(pt) || '';
    } catch (e) {
      return '';
    }
  }

  function parseAstra(playlistUrl, name) {
    return ctx
      .fetch(playlistUrl, { headers: playHeaders })
      .then(function (r) {
        return r.json();
      })
      .then(function (data) {
        var rows = [];
        (Array.isArray(data) ? data : []).forEach(function (item) {
          if (item && item.url) {
            var q = item.resolution ? item.resolution + 'p' : qualityOf(item.url);
            rows.push({
              url: item.url,
              name: 'VidRock ' + name,
              quality: q,
              headers: playHeaders,
            });
          }
        });
        return rows;
      })
      .catch(function () {
        return [];
      });
  }

  function process(data) {
    if (!data || typeof data !== 'object') return Promise.resolve([]);
    var tasks = [];
    Object.keys(data).forEach(function (serverName) {
      var source = data[serverName];
      var url = decryptUrl(source && source.url);
      if (!url) return;
      if (serverName === 'Astra' && isAstraPlaylist(url)) {
        tasks.push(parseAstra(url, serverName));
        return;
      }
      tasks.push(Promise.resolve([row(url, serverName, source.language)]));
    });
    return Promise.all(tasks).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  if (!aesKey) return [];

  return ctx
    .fetch(origin.replace(/\/$/, '') + '/api/' + path, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (body) {
      var data = null;
      try {
        data = JSON.parse(body);
      } catch (e) {
        data = null;
      }
      return process(data);
    })
    .then(function (rows) {
      var seen = {};
      var out = [];
      (rows || []).forEach(function (r) {
        if (!r || !r.url || seen[r.url]) return;
        seen[r.url] = true;
        out.push(r);
      });
      return out.length ? out : [];
    })
    .catch(function () {
      return [];
    });
}
