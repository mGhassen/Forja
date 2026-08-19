function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://vidrock.net';
  var passphrase = cfg.passphrase || '';
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
  var mediaType = ctx.type === 'movie' ? 'movie' : 'tv';
  var itemId =
    mediaType === 'tv'
      ? tmdbId + '_' + (ctx.season || 1) + '_' + (ctx.episode || 1)
      : tmdbId;

  function encryptId(text) {
    var CryptoJS = ctx.crypto;
    if (!passphrase || !CryptoJS || !CryptoJS.AES) return '';
    return CryptoJS.AES.encrypt(String(text), String(passphrase)).toString();
  }

  function qualityOf(url) {
    var m = String(url || '').match(/(\d{3,4})p/i);
    return m ? m[1] + 'p' : '';
  }

  function needsHeaders(name, url) {
    if (name === 'Astra') return true;
    return /cdn\.vidrock\.store|proxy\.vidrock\.store|hls1\.vdrk\.site|cdn\.niggaflix\.xyz/i.test(
      url || '',
    );
  }

  function row(url, name, language) {
    var hdrs = needsHeaders(name, url) ? playHeaders : undefined;
    var label = 'VidRock ' + name + (language ? ' [' + language + ']' : '');
    var out = { url: url, name: label, quality: qualityOf(url) };
    if (hdrs) out.headers = hdrs;
    return out;
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
      var url = source && source.url;
      if (!url) return;
      if (serverName === 'Astra' && /cdn\.vidrock\.store\/playlist\//i.test(url)) {
        tasks.push(parseAstra(url, serverName));
        return;
      }
      tasks.push(Promise.resolve([row(url, serverName, source.language)]));
    });
    return Promise.all(tasks).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  var encrypted = encryptId(itemId);
  if (!encrypted) return ctx.host('vidrock');

  return ctx
    .fetch(origin + '/api/' + mediaType + '/' + encodeURIComponent(encrypted), {
      headers: headers,
    })
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
      return out.length ? out : ctx.host('vidrock');
    })
    .catch(function () {
      return ctx.host('vidrock');
    });
}
