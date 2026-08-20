function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://cinevibe.asia').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var fingerprint = cfg.fingerprint || 'eyJzY3JlZW4iOiIzNjB4ODA2eDI0Iiwi';
  var session = cfg.session || 'pjght152dw2rb.ssst4bzleDI0Iiwibv78';
  var ua = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  var isTv = ctx.type === 'tv';

  if (isTv) return Promise.resolve([]);

  function hdrs() {
    return {
      Referer: base + '/',
      'User-Agent': ua,
      'X-CV-Fingerprint': fingerprint,
      'X-CV-Session': session,
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  function fnv1a32(s) {
    var hash = 2166136261;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.charCodeAt(i);
      hash = (hash + (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24)) >>> 0;
    }
    return hash.toString(16).padStart(8, '0');
  }

  function rot13(str) {
    return String(str).replace(/[A-Za-z]/g, function (c) {
      var code = c.charCodeAt(0);
      if (code >= 65 && code <= 90) return String.fromCharCode(((code - 65 + 13) % 26) + 65);
      if (code >= 97 && code <= 122) return String.fromCharCode(((code - 97 + 13) % 26) + 97);
      return c;
    });
  }

  function b64Encode(str) {
    try {
      return btoa(unescape(encodeURIComponent(str)));
    } catch (e) { return ''; }
  }

  function customEncode(e) {
    var encoded = b64Encode(e);
    encoded = encoded.split('').reverse().join('');
    encoded = rot13(encoded);
    encoded = b64Encode(encoded);
    return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  function qualityFromSource(source) {
    if (!source) return 'Auto';
    var label = (source.label || source.quality || '').toLowerCase();
    if (/2160|4k/.test(label)) return '4K';
    if (/1440|2k/.test(label)) return '1440p';
    if (/1080/.test(label)) return '1080p';
    if (/720/.test(label)) return '720p';
    if (/480/.test(label)) return '480p';
    if (/360/.test(label)) return '360p';
    if (/240/.test(label)) return '240p';
    if (source.url) {
      var m = source.url.match(/(\d{3,4})[pP]/);
      if (m) {
        var r = parseInt(m[1], 10);
        if (r >= 2160) return '4K';
        if (r >= 1440) return '1440p';
        if (r >= 1080) return '1080p';
        if (r >= 720) return '720p';
        if (r >= 480) return '480p';
      }
    }
    return 'Auto';
  }

  return ctx.fetch(
    'https://api.themoviedb.org/3/movie/' + encodeURIComponent(String(ctx.tmdbId || '')) +
      '?api_key=' + encodeURIComponent(tmdbKey),
    { headers: { 'User-Agent': ua, Accept: 'application/json' } },
  ).then(function (r) { return r.json(); }).then(function (data) {
    var title = data.title;
    var releaseYear = data.release_date ? data.release_date.split('-')[0] : null;
    if (!title || !releaseYear) return [];
    var cleanTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '');
    var timeWindow = Math.floor(Date.now() / 300000);
    var hashedKey = fnv1a32(timeWindow + '_' + fingerprint + '_cinevibe_2025');
    var timeStamp = Math.floor(Date.now() / 1000 / 600);
    var tokenString = session + '|' + ctx.tmdbId + '|' + cleanTitle + '|' + releaseYear + '||' +
      hashedKey + '|' + timeStamp + '|' + fingerprint;
    var token = customEncode(tokenString);
    var apiUrl = base + '/api/stream/fetch?server=cinebox-1&type=movie&mediaId=' + ctx.tmdbId +
      '&title=' + encodeURIComponent(title) + '&releaseYear=' + releaseYear +
      '&_token=' + token + '&_ts=' + Date.now();
    return ctx.fetch(apiUrl, { headers: hdrs() }).then(function (r) { return r.json(); }).then(function (resp) {
      if (!resp || !Array.isArray(resp.sources) || !resp.sources.length) return [];
      return resp.sources.filter(function (s) { return s && s.url; }).map(function (source) {
        return {
          name: 'Cinevibe - ' + qualityFromSource(source),
          url: source.url,
          quality: qualityFromSource(source),
          headers: hdrs(),
        };
      });
    });
  }).catch(function () { return []; });
}
