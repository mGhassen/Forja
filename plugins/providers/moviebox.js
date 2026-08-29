var SPECS = {
  "api": "https://api3.aoneroom.com",
  "referer": "https://videodownloader.site/",
  "keyB64Default": "NzZpUmwwN3MweFNOOWpxbUVXQXQ3OUVCSlp1bElRSXNWNjRGWnIyTw==",
  "keyB64Alt": "WHFuMm5uTzQxL0w5Mm8xaXVYaFNMSFRiWHZZNFo1Wlo2Mm04bVNMQQ==",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49",
  "packageName": "com.community.mbox.in",
  "versionCode": 50020042,
  "versionName": "3.0.03.0529.03"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var api = cfg.api.replace(/\/$/, '');
  var keyB64Default = cfg.keyB64Default;
  var keyB64Alt = cfg.keyB64Alt;
  var tmdbKey = cfg.tmdbKey;
  var pkg = cfg.packageName;
  var versionCode = cfg.versionCode;
  var versionName = cfg.versionName;
  var ua =
    pkg +
    '/' +
    versionCode +
    ' (Linux; U; Android 16; en_IN; MovieBox; Build/BP22.250325.006; Cronet/133.0.6876.3)';
  var isTv = ctx.type !== 'movie';
  var season = isTv ? Number(ctx.season) || 1 : 0;
  var episode = isTv ? Number(ctx.episode) || 1 : 0;
  var deviceId = '';
  var selectedBrand = 'Samsung';
  var selectedModel = 'SM-S918B';

  function initSession() {
    if (deviceId) return;
    var chars = '0123456789abcdef';
    for (var i = 0; i < 32; i++) deviceId += chars[Math.floor(Math.random() * 16)];
  }

  function md5Hex(input) {
    return ctx.crypto.MD5(String(input)).toString(ctx.crypto.enc.Hex);
  }

  function secretKey(alt) {
    var outer = ctx.crypto.enc.Base64.parse(alt ? keyB64Alt : keyB64Default);
    var inner = ctx.crypto.enc.Utf8.stringify(outer);
    return ctx.crypto.enc.Base64.parse(inner);
  }

  function hmacMd5B64(key, data) {
    return ctx.crypto.HmacMD5(String(data), key).toString(ctx.crypto.enc.Base64);
  }

  function xClientToken(ts) {
    var t = String(ts || Date.now());
    return t + ',' + md5Hex(t.split('').reverse().join(''));
  }

  function canonicalString(method, accept, contentType, url, body, ts) {
    var path = '';
    var query = '';
    try {
      var u = new URL(url);
      path = u.pathname;
      var keys = [];
      u.searchParams.forEach(function (_, k) {
        if (keys.indexOf(k) < 0) keys.push(k);
      });
      keys.sort();
      if (keys.length) {
        query = keys
          .map(function (k) {
            return u.searchParams
              .getAll(k)
              .map(function (v) {
                return k + '=' + v;
              })
              .join('&');
          })
          .join('&');
      }
    } catch (e) {
      return '';
    }
    var canonicalUrl = query ? path + '?' + query : path;
    var bodyHash = '';
    var bodyLength = '';
    if (body) {
      bodyHash = md5Hex(body);
      bodyLength = String(ctx.crypto.enc.Utf8.parse(body).sigBytes);
    }
    return (
      method.toUpperCase() +
      '\n' +
      (accept || '') +
      '\n' +
      (contentType || '') +
      '\n' +
      bodyLength +
      '\n' +
      ts +
      '\n' +
      bodyHash +
      '\n' +
      canonicalUrl
    );
  }

  function xTrSignature(method, accept, contentType, url, body, ts, alt) {
    var canonical = canonicalString(method, accept, contentType, url, body, ts);
    return ts + '|2|' + hmacMd5B64(secretKey(alt), canonical);
  }

  function mbRequest(method, url, body, extra, altKey) {
    initSession();
    var ts = Date.now();
    var contentType = (extra && extra['Content-Type']) || (body ? 'application/json; charset=utf-8' : 'application/json');
    var accept = (extra && extra.Accept) || 'application/json';
    var xClientInfo = JSON.stringify({
      package_name: pkg,
      version_name: versionName,
      version_code: versionCode,
      os: 'android',
      os_version: '16',
      device_id: deviceId,
      install_store: 'ps',
      gaid: 'd7578036d13336cc',
      brand: selectedBrand.toLowerCase(),
      model: selectedModel,
      system_language: 'en',
      net: 'NETWORK_WIFI',
      region: 'IN',
      timezone: 'Asia/Calcutta',
      sp_code: '',
    });
    var headers = Object.assign(
      {
        Accept: accept,
        'Content-Type': contentType,
        'x-client-token': xClientToken(ts),
        'x-tr-signature': xTrSignature(method, accept, contentType, url, body, ts, !!altKey),
        'User-Agent': ua,
        'x-client-info': xClientInfo,
        'x-client-status': '0',
      },
      extra || {},
    );
    return ctx
      .fetch(url, { method: method, headers: headers, body: body || undefined })
      .then(function (r) {
        if (r.status === 403 && !altKey) {
          return mbRequest(method, url, body, extra, true);
        }
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json().then(function (j) {
          return { json: j, headers: r.headers };
        });
      });
  }

  function normalizeTitle(s) {
    return String(s || '')
      .replace(/\[.*?\]/g, ' ')
      .replace(/\(.*?\|/g, ' ')
      .replace(/\b(dub|dubbed|hd|4k|hindi|tamil|telugu|dual audio)\b/gi, ' ')
      .trim()
      .toLowerCase()
      .replace(/:/g, ' ')
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ');
  }

  function tmdbDetails() {
    var kind = isTv ? 'tv' : 'movie';
    return ctx
      .fetch(
        'https://api.themoviedb.org/3/' +
          kind +
          '/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
        { headers: { Accept: 'application/json', 'User-Agent': ua } },
      )
      .then(function (r) {
        return r.json();
      })
      .then(function (d) {
        return {
          title: (isTv ? d.name || d.original_name : d.title || d.original_title) || String(ctx.title || ''),
          year: String((isTv ? d.first_air_date : d.release_date) || ctx.year || '').substring(0, 4),
          originalTitle: d.original_title || d.original_name || '',
        };
      });
  }

  function searchSubjects(query) {
    var url = api + '/wefeed-mobile-bff/subject-api/search/v2';
    var body = JSON.stringify({ page: 1, perPage: 20, keyword: query });
    return mbRequest('POST', url, body).then(function (res) {
      var j = res.json || {};
      var groups = ((((j || {}).data || {}).data || {}).results) || [];
      var out = [];
      groups.forEach(function (g) {
        (g.subjects || []).forEach(function (s) {
          out.push(s);
        });
      });
      if (typeof ctx.log === 'function') ctx.log('moviebox subjects=' + out.length);
      return out;
    }).catch(function () {
      return [];
    });
  }

  function pickSubject(subjects, details) {
    var want = normalizeTitle(details.title);
    var alt = normalizeTitle(details.originalTitle);
    var targetType = isTv ? 2 : 1;
    var best = null;
    var bestScore = 0;
    (subjects || []).forEach(function (s) {
      if (Number(s.subjectType) !== targetType) return;
      var title = normalizeTitle(s.title);
      var year = String(s.year || (s.releaseDate || '').substring(0, 4) || '');
      var score = 0;
      if (title === want || title === alt) score += 50;
      else if (title.indexOf(want) >= 0 || want.indexOf(title) >= 0) score += 15;
      if (details.year && year === details.year) score += 35;
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    });
    return bestScore >= 40 ? best : null;
  }

  function playStreams(subjectId, details, authHeaders) {
    var url =
      api +
      '/wefeed-mobile-bff/subject-api/play-info?subjectId=' +
      encodeURIComponent(String(subjectId)) +
      '&se=' +
      season +
      '&ep=' +
      episode;
    return mbRequest('GET', url, null, authHeaders).then(function (res) {
      var playData = ((((res.json || {}).data || {}).data) || {});
      var streams = playData.streams;
      var out = [];
      if (Array.isArray(streams)) {
        streams.forEach(function (s) {
          if (!s || !s.url) return;
          var q = s.resolutions || s.quality || 'Auto';
          var qn = String(q).match(/(\d{3,4})/);
          out.push({
            url: s.url,
            name: 'MovieBox',
            quality: qn ? qn[1] + 'p' : 'Auto',
            headers: Object.assign(
              { Referer: api + '/', 'User-Agent': ua },
              s.signCookie ? { Cookie: s.signCookie } : {},
            ),
          });
        });
      } else if (Array.isArray(playData.resourceDetectors)) {
        playData.resourceDetectors.forEach(function (det) {
          (det.resolutionList || []).forEach(function (v) {
            if (!v || !v.resourceLink) return;
            out.push({
              url: v.resourceLink,
              name: 'MovieBox',
              quality: v.resolution ? v.resolution + 'p' : 'Auto',
              headers: { Referer: api + '/', 'User-Agent': ua },
            });
          });
        });
      }
      return out;
    });
  }

  function streamsForSubject(subjectId, details) {
    var subjectUrl = api + '/wefeed-mobile-bff/subject-api/get?subjectId=' + encodeURIComponent(String(subjectId));
    return mbRequest('GET', subjectUrl, null).then(function (res) {
      var token = '';
      try {
        var xUser = res.headers && res.headers.get ? res.headers.get('x-user') : '';
        if (xUser) token = JSON.parse(xUser).token || '';
      } catch (e) {}
      var authHeaders = token ? { Authorization: 'Bearer ' + token } : {};
      var dubs = (((((res.json || {}).data || {}).data) || {}).dubs) || [];
      var ids = [{ id: subjectId, lang: 'Original' }];
      dubs.forEach(function (d) {
        if (d && d.subjectId && String(d.subjectId) !== String(subjectId)) {
          ids.push({ id: d.subjectId, lang: d.lanName || 'Dub' });
        }
      });
      return Promise.all(
        ids.slice(0, 4).map(function (item) {
          return playStreams(item.id, details, authHeaders).catch(function () {
            return [];
          });
        }),
      ).then(function (groups) {
        return [].concat.apply([], groups);
      });
    });
  }

  return tmdbDetails()
    .then(function (details) {
      if (!details.title) return [];
      return searchSubjects(details.title).then(function (subjects) {
        var match = pickSubject(subjects, details);
        if (!match && details.originalTitle && details.originalTitle !== details.title) {
          return searchSubjects(details.originalTitle).then(function (more) {
            return pickSubject(more, details);
          });
        }
        return match;
      }).then(function (match) {
        if (!match || !match.subjectId) return [];
        return streamsForSubject(match.subjectId, details);
      });
    })
    .catch(function () {
      return [];
    });
}
