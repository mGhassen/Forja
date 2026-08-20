function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://animepahe.com').replace(/\/$/, '');
  var proxy = cfg.proxy || 'https://animepaheproxy.phisheranimepahe.workers.dev/?url=';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Cookie: '__ddg2_=1234567890', Referer: base + '/' };
  var isTv = ctx.type === 'tv';

  function fetchText(url, useProxy) {
    var finalUrl = /^https?:/i.test(url) ? url : base + url;
    var target = useProxy !== false ? proxy + encodeURIComponent(finalUrl) : finalUrl;
    return ctx.fetch(target, { headers: hdrs }).then(function (r) { return r.text(); });
  }

  function fetchJson(url) {
    return fetchText(url).then(function (t) { return JSON.parse(t); });
  }

  function unpack(code) {
    try {
      var match = code.match(/}\((['"])([\s\S]*?)\1,\s*(\d+),\s*(\d+),\s*(['"])([\s\S]*?)\5\.split\((['"])\|\7\)/);
      if (!match) return code;
      var p = match[2].replace(/\\'/g, "'").replace(/\\"/g, '"').replace(/\\\\/g, '\\');
      var a = parseInt(match[3], 10);
      var c = parseInt(match[4], 10);
      var k = match[6].split('|');
      var e = function (c2) {
        return (c2 < a ? '' : e(parseInt(c2 / a, 10))) + ((c2 = c2 % a) > 35 ? String.fromCharCode(c2 + 29) : c2.toString(36));
      };
      var d = {};
      while (c--) d[e(c)] = k[c] || e(c);
      return p.replace(/\b\w+\b/g, function (w) { return d[w]; });
    } catch (e) { return code; }
  }

  function paheDecrypt(fullString, key, v1, v2) {
    var keyIndexMap = {};
    for (var i = 0; i < key.length; i++) keyIndexMap[key[i]] = i;
    var result = '';
    var idx = 0;
    var toFind = key[v2];
    while (idx < fullString.length) {
      var nextIndex = fullString.indexOf(toFind, idx);
      if (nextIndex === -1) break;
      var decodedCharStr = '';
      for (var j = idx; j < nextIndex; j++) decodedCharStr += keyIndexMap[fullString[j]];
      idx = nextIndex + 1;
      result += String.fromCharCode(parseInt(decodedCharStr, v2) - v1);
    }
    return result;
  }

  function extractKwik(url) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, { Referer: base + '/' }) })
      .then(function (r) { return r.text(); })
      .then(function (html) {
        var scripts = html.match(/<script.*?>([\s\S]*?)<\/script>/g) || [];
        for (var si = 0; si < scripts.length; si++) {
          if (scripts[si].indexOf('eval(function(p,a,c,k,e,d)') < 0) continue;
          var pos = 0;
          while (true) {
            var start = scripts[si].indexOf('eval(function(p,a,c,k,e,d)', pos);
            if (start < 0) break;
            var end = scripts[si].indexOf('.split(\'|\')', start);
            if (end < 0) break;
            var closeParen = scripts[si].indexOf('))', end);
            if (closeParen < 0) break;
            var unpacked = unpack(scripts[si].substring(start, closeParen + 2));
            var m3u8M = unpacked.match(/source\s*=\s*'([^']+m3u8[^']*)'/) || unpacked.match(/source\s*=\s*"([^"]+m3u8[^"]*)"/);
            if (m3u8M) {
              var m3u8Url = m3u8M[1];
              var titleM = html.match(/<title>([\s\S]*?)<\/title>/);
              var title = titleM ? titleM[1].trim() : 'video';
              var fileName = title.endsWith('.mp4') ? title : title + '.mp4';
              var parts = m3u8Url.replace('/stream/', '/mp4/').split('/');
              parts.pop();
              return {
                m3u8: m3u8Url,
                mp4: parts.join('/') + '?file=' + encodeURIComponent(fileName),
                headers: { Referer: 'https://kwik.cx/', Origin: 'https://kwik.cx', 'User-Agent': ua },
              };
            }
            pos = closeParen + 2;
          }
        }
        return null;
      }).catch(function () { return null; });
  }

  function extractPahe(url) {
    var initUrl = url.endsWith('/i') ? url : url + '/i';
    return ctx.fetch(initUrl, {
      method: 'GET',
      headers: Object.assign({}, hdrs, { Referer: 'https://pahe.win/' }),
    }).then(function (r) {
      var loc = r.headers.get('location') || r.headers.get('Location');
      if (!loc) return null;
      var kwikUrl = /^https?:/i.test(loc) ? loc : 'https://' + loc.replace(/^\/+/, '');
      return ctx.fetch(kwikUrl, { headers: Object.assign({}, hdrs, { Referer: 'https://kwik.cx/' }) })
        .then(function (r2) {
          return r2.text().then(function (html) {
            var cookie = (r2.headers.get('set-cookie') || r2.headers.get('Set-Cookie') || '').split(';')[0];
            var pm = html.match(/\("(\w+)",\d+,"(\w+)",(\d+),(\d+),\d+\)/);
            if (!pm) return null;
            var decrypted = paheDecrypt(pm[1], pm[2], parseInt(pm[3], 10), parseInt(pm[4], 10));
            var actionM = decrypted.match(/action="([^"]+)"/);
            var tokenM = decrypted.match(/value="([^"]+)"/);
            if (!actionM || !tokenM) return null;
            return ctx.fetch(actionM[1], {
              method: 'POST',
              redirect: 'manual',
              headers: Object.assign({}, hdrs, {
                Referer: kwikUrl, Cookie: cookie, 'Content-Type': 'application/x-www-form-urlencoded',
              }),
              body: '_token=' + encodeURIComponent(tokenM[1]),
            }).then(function (r3) {
              var location = r3.headers.get('location') || r3.headers.get('Location');
              if (!location) return null;
              return { url: location, headers: { Referer: 'https://kwik.cx/', 'User-Agent': ua } };
            });
          });
        });
    }).catch(function () { return null; });
  }

  function qualityFromText(text) {
    var m = String(text || '').match(/(\d{3,4})p/);
    return m ? m[1] + 'p' : '720p';
  }

  function resolveTv() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) return Promise.resolve(fromHost);
    return ctx.fetch(
      'https://api.themoviedb.org/3/tv/' + encodeURIComponent(String(ctx.tmdbId || '')) +
        '/external_ids?api_key=' + encodeURIComponent(tmdbKey),
      { headers: { Accept: 'application/json' } },
    ).then(function (r) { return r.json(); }).then(function (d) {
      var imdbId = d.imdb_id;
      if (!imdbId) return null;
      return ctx.fetch(
        'https://id-mapping-api-malid.hf.space/api/resolve?id=' + imdbId +
          '&s=' + (ctx.season || 1) + '&e=' + (ctx.episode || 1),
      ).then(function (r) { return r.json(); }).then(function (map) {
        if (!map || !map.mal_id) return null;
        return ctx.fetch('https://api.jikan.moe/v4/anime/' + map.mal_id).then(function (r) { return r.json(); })
          .then(function (mal) {
            return { malId: map.mal_id, mappedEp: map.mal_episode || ctx.episode || 1, title: mal.data.title };
          });
      });
    });
  }

  function findSession(title, malId) {
    return fetchJson('/api?m=search&l=8&q=' + encodeURIComponent(title)).then(function (res) {
      var data = (res && res.data) || [];
      var tasks = data.slice(0, 3).map(function (item) {
        return fetchText('/anime/' + item.session).then(function (html) {
          return html.indexOf('myanimelist.net/anime/' + malId) >= 0 ? item.session : null;
        }).catch(function () { return null; });
      });
      return Promise.all(tasks).then(function (sessions) {
        return sessions.find(Boolean) || null;
      });
    });
  }

  function episodeSession(animeSession, mappedEp) {
    return fetchJson('/api?m=release&id=' + animeSession + '&sort=episode_asc&page=1').then(function (first) {
      var epStart = Math.floor(((first.data || [])[0] || {}).episode || 1);
      var perPage = first.per_page || 30;
      var targetEp = epStart - 1 + mappedEp;
      var page = Math.ceil(mappedEp / perPage) || 1;
      return fetchJson('/api?m=release&id=' + animeSession + '&sort=episode_asc&page=' + page).then(function (pageData) {
        var found = (pageData.data || []).find(function (e) { return Math.floor(e.episode) == targetEp; });
        if (found) return found.session;
        var fallback = (first.data || []).find(function (e) { return Math.floor(e.episode) == targetEp; });
        return fallback ? fallback.session : null;
      });
    });
  }

  function playStreams(animeSession, episodeSessionId, animeTitle, mappedEp) {
    return fetchText('/play/' + animeSession + '/' + episodeSessionId).then(function (html) {
      var $ = ctx.html(html);
      var streams = [];
      var tasks = [];
      $('#resolutionMenu button').each(function () {
        var btn = $(this);
        var kwikUrl = btn.attr('data-src') || '';
        var q = qualityFromText(btn.text());
        var type = /eng/i.test(btn.text()) ? 'Dub' : 'Sub';
        if (kwikUrl.indexOf('kwik') >= 0) {
          tasks.push(extractKwik(kwikUrl).then(function (res) {
            if (!res) return;
            if (res.m3u8) streams.push({ name: 'AnimePahe [HLS] (' + q + ' ' + type + ')', url: res.m3u8, quality: q, headers: res.headers });
            if (res.mp4) streams.push({ name: 'AnimePahe [MP4] (' + q + ' ' + type + ')', url: res.mp4, quality: q, headers: Object.assign({}, res.headers, { Referer: kwikUrl }) });
          }));
        }
      });
      $('div#pickDownload a').each(function () {
        var link = $(this);
        var href = link.attr('href') || '';
        var q = qualityFromText(link.text());
        var type = /eng/i.test(link.find('span').text()) ? 'Dub' : 'Sub';
        if (/pahe\.|kwik/i.test(href)) {
          tasks.push(extractPahe(href).then(function (res) {
            if (res && res.url) streams.push({ name: 'AnimePahe [Direct] (' + q + ' ' + type + ')', url: res.url, quality: q, headers: res.headers });
          }));
        }
      });
      return Promise.all(tasks).then(function () {
        var order = { '1080p': 3, '720p': 2, '360p': 1 };
        return streams.sort(function (a, b) { return (order[b.quality] || 0) - (order[a.quality] || 0); });
      });
    });
  }

  if (!isTv) {
    return ctx.fetch(
      'https://api.themoviedb.org/3/movie/' + encodeURIComponent(String(ctx.tmdbId || '')) + '?api_key=' + encodeURIComponent(tmdbKey),
    ).then(function (r) { return r.json(); }).then(function (d) {
      var title = d.title || d.original_title;
      if (!title) return [];
      return fetchJson('/api?m=search&l=8&q=' + encodeURIComponent(title)).then(function (res) {
        var first = ((res && res.data) || [])[0];
        if (!first || first.title.toLowerCase() !== title.toLowerCase()) return [];
        return episodeSession(first.session, 1).then(function (epSess) {
          if (!epSess) return [];
          return playStreams(first.session, epSess, title, 1);
        });
      });
    }).catch(function () { return []; });
  }

  return resolveTv().then(function (info) {
    if (!info) return [];
    return findSession(info.title, info.malId).then(function (animeSession) {
      if (!animeSession) return [];
      return episodeSession(animeSession, info.mappedEp).then(function (epSess) {
        if (!epSess) return [];
        return playStreams(animeSession, epSess, info.title, info.mappedEp);
      });
    });
  }).catch(function () { return []; });
}
