var SPECS = {
  "api": "https://app.cloud-mb.xyz",
  "token": "jdvhhjv255vghhghdhvfch2565656jhdcghfdf",
  "appId": "com.movieblast",
  "signSecret": "GJ8reydarI7Jqat9rvbAJKNQ9gY4DoEQF2H5nfuI1gi",
  "hash256": "86dc03244adddb3cbedbf0ae36074a736ee293a64774b18e82a6244eafd0df30",
  "tmdbKey": "439c478a771f35c05022f9feabcca01c"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var api = cfg.api.replace(/\/$/, '');
  var token = cfg.token || '';
  var appId = cfg.appId;
  var secret = cfg.signSecret || '';
  var tmdbKey = cfg.tmdbKey;
  if (!token || !secret) return Promise.resolve([]);
  var headers = {
    'user-agent': 'okhttp/5.0.0-alpha.6',
    'x-request-x': appId,
  };
  var searchHeaders = Object.assign({}, headers, {
    hash256: cfg.hash256 || '',
    packagename: appId,
  });
  var isTv = ctx.type !== 'movie';
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
    if (v.indexOf('1440') >= 0) return '2K';
    if (v.indexOf('1080') >= 0) return '1080p';
    if (v.indexOf('720') >= 0) return '720p';
    if (v.indexOf('480') >= 0) return '480p';
    if (v.indexOf('360') >= 0) return '360p';
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

  function similarity(a, b) {
    var na = norm(a);
    var nb = norm(b);
    if (!na || !nb) return 0;
    if (na === nb) return 1;
    var wa = na.split(/\s+/).filter(Boolean);
    var wb = nb.split(/\s+/).filter(Boolean);
    if (!wa.length || !wb.length) return 0;
    var setB = {};
    wb.forEach(function (w) {
      setB[w] = true;
    });
    var inter = wa.filter(function (w) {
      return setB[w];
    }).length;
    var union = {};
    wa.concat(wb).forEach(function (w) {
      union[w] = true;
    });
    return inter / Object.keys(union).length;
  }

  function best(mediaInfo, results) {
    var hit = null;
    var score = 0;
    (results || []).forEach(function (r) {
      var s = similarity(mediaInfo.title, r.name);
      if (mediaInfo.year && r.release_date) {
        var ry = parseInt(String(r.release_date).substring(0, 4), 10);
        if (ry === mediaInfo.year) s += 0.2;
      }
      if (s > score && s > 0.4) {
        score = s;
        hit = r;
      }
    });
    return hit;
  }

  function resolveMedia() {
    var title = String(ctx.title || '').trim();
    var year = parseInt(String(ctx.year || '').substring(0, 4), 10) || null;
    if (title) return Promise.resolve({ title: title, year: year });
    if (!ctx.tmdbId) return Promise.resolve(null);
    var kind = isTv ? 'tv' : 'movie';
    return ctx
      .fetch(
        'https://api.themoviedb.org/3/' +
          kind +
          '/' +
          encodeURIComponent(String(ctx.tmdbId)) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
        {
          headers: {
            Accept: 'application/json',
            'User-Agent': 'Mozilla/5.0',
          },
        },
      )
      .then(function (r) {
        return r.json();
      })
      .then(function (d) {
        var t = isTv ? d.name : d.title;
        var date = isTv ? d.first_air_date : d.release_date;
        if (!t) return null;
        return {
          title: t,
          year: date ? parseInt(String(date).substring(0, 4), 10) : year,
        };
      })
      .catch(function () {
        return null;
      });
  }

  return resolveMedia()
    .then(function (mediaInfo) {
      if (!mediaInfo || !mediaInfo.title) return [];
      return ctx
        .fetch(
          api +
            '/api/search/' +
            encodeURIComponent(mediaInfo.title) +
            '/' +
            token,
          { headers: searchHeaders },
        )
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          var match = best(mediaInfo, j && j.search);
          if (!match || !match.id) return [];
          var series =
            isTv ||
            String(match.type || '')
              .toLowerCase()
              .indexOf('serie') >= 0;
          var path = series ? 'series/show' : 'media/detail';
          return ctx
            .fetch(api + '/api/' + path + '/' + match.id + '/' + token, {
              headers: headers,
            })
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
                var ep =
                  ts &&
                  (ts.episodes || []).filter(function (e) {
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
                      'Accept-Encoding': 'identity',
                      'Icy-MetaData': '1',
                      Referer: 'MovieBlast',
                      'User-Agent': 'MovieBlast',
                      'x-request-x': appId,
                    },
                  };
                });
            });
        });
    })
    .catch(function () {
      return [];
    });
}
