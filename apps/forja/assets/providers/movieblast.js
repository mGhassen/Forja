function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://app.cloud-mb.xyz').replace(/\/$/, '');
  var token = cfg.token || '';
  var appId = cfg.appId || 'com.movieblast';
  var secret = cfg.signSecret || '';
  if (!token || !secret) return Promise.resolve([]);
  var title = String(ctx.title || '').trim();
  if (!title) return Promise.resolve([]);
  var headers = {
    'user-agent': 'okhttp/5.0.0-alpha.6',
    'x-request-x': appId,
  };
  var searchHeaders = Object.assign({}, headers, {
    hash256: cfg.hash256 || '',
    packagename: appId,
  });
  var isTv = ctx.type === 'tv';
  var CryptoJS = ctx.crypto;

  function sign(urlStr) {
    try {
      var u = new URL(urlStr);
      var ts = String(Math.floor(Date.now() / 1000));
      var hash = CryptoJS.HmacSHA256(u.pathname + ts, secret);
      var sig = encodeURIComponent(CryptoJS.enc.Base64.stringify(hash));
      return urlStr + '?verify=' + ts + '-' + sig;
    } catch (e) {
      return urlStr;
    }
  }

  function quality(s) {
    var v = String(s || '').toLowerCase();
    if (v.indexOf('2160') >= 0 || v.indexOf('4k') >= 0) return '4K';
    if (v.indexOf('1080') >= 0) return '1080p';
    if (v.indexOf('720') >= 0) return '720p';
    if (v.indexOf('480') >= 0) return '480p';
    return '';
  }

  function norm(t) {
    return String(t || '')
      .toLowerCase()
      .replace(/\b(the|a|an)\b/g, '')
      .replace(/[:\-_]/g, ' ')
      .replace(/[^\w\s]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function best(results) {
    var want = norm(title);
    var year = String(ctx.year || '').substring(0, 4);
    var hit = null;
    var score = 0;
    (results || []).forEach(function (r) {
      var n = norm(r.name);
      var s = n === want ? 1 : 0;
      if (!s) {
        var a = want.split(/\s+/).filter(Boolean);
        var b = n.split(/\s+/).filter(Boolean);
        var inter = a.filter(function (w) {
          return b.indexOf(w) >= 0;
        }).length;
        s = inter / Math.max(a.length, b.length, 1);
      }
      if (year && String(r.release_date || '').indexOf(year) === 0) s += 0.2;
      if (s > score && s > 0.4) {
        score = s;
        hit = r;
      }
    });
    return hit;
  }

  return ctx
    .fetch(api + '/api/search/' + encodeURIComponent(title) + '/' + token, {
      headers: searchHeaders,
    })
    .then(function (r) {
      return r.json();
    })
    .then(function (j) {
      var match = best(j && j.search);
      if (!match || !match.id) return [];
      var series =
        isTv || String(match.type || '').toLowerCase().indexOf('serie') >= 0;
      var path = series ? 'series/show' : 'media/detail';
      return ctx
        .fetch(api + '/api/' + path + '/' + match.id + '/' + token, { headers: headers })
        .then(function (r) {
          return r.json();
        })
        .then(function (detail) {
          var videos = [];
          if (series) {
            var seasons = detail.seasons || [];
            var sn = ctx.season || 1;
            var en = ctx.episode || 1;
            var ts = seasons.filter(function (s) {
              return s.season_number == sn;
            })[0];
            var ep = ts && (ts.episodes || []).filter(function (e) {
              return e.episode_number == en;
            })[0];
            videos = (ep && ep.videos) || [];
          } else {
            videos = detail.videos || [];
          }
          return videos
            .filter(function (v) {
              return v && v.link;
            })
            .map(function (v) {
              var raw = v.link;
              var httpsUrl = /^https?:/i.test(raw) ? raw : 'https://' + raw;
              return {
                url: sign(httpsUrl),
                name: 'MovieBlast ' + (v.server || ''),
                quality: quality(v.server),
                language: v.lang || '',
                headers: {
                  Referer: 'MovieBlast',
                  'User-Agent': 'MovieBlast',
                  'x-request-x': appId,
                },
              };
            });
        });
    })
    .catch(function () {
      return [];
    });
}
