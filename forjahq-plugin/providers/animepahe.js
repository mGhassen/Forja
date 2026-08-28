function extract(ctx) {
  var cfg = ctx.config || {};
  var mirrors = Array.isArray(cfg.mirrors) && cfg.mirrors.length
    ? cfg.mirrors.map(function (m) { return String(m).replace(/\/$/, ''); })
    : ['https://animepahe.pw', 'https://animepahe.ru', 'https://animepahe.com'];
  var base = (cfg.base || mirrors[0] || 'https://animepahe.pw').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Cookie: '__ddg2_=1234567890', Referer: base + '/' };
  // Anime Sources pass type=anime — must NOT fall through to the movie/TMDB branch.
  var isEpisodic = ctx.type !== 'movie';
  var kwikOrigin = 'https://kwik.si';

  function isBlockedBody(text) {
    if (text == null || text === '') return true;
    var s = String(text).trim();
    if (s.charAt(0) === '{' || s.charAt(0) === '[') return false;
    return /Just a moment|cdn-cgi|challenge-platform|__ddg/i.test(s);
  }

  function fetchText(url) {
    var isAbs = /^https?:/i.test(url);
    var candidates = isAbs
      ? [url]
      : mirrors.map(function (m) {
          return String(m).replace(/\/$/, '') + url;
        });

    function tryDirect(target, idx) {
      var origin = (String(target).match(/^https?:\/\/[^/]+/) || [base])[0];
      var reqHdrs = Object.assign({}, hdrs, { Referer: origin + '/' });
      return ctx
        .fetch(target, { headers: reqHdrs })
        .then(function (r) {
          return r.text().then(function (text) {
            if (isBlockedBody(text)) throw new Error('blocked');
            if (!isAbs) {
              base = origin;
              hdrs.Referer = origin + '/';
            }
            return text;
          });
        })
        .catch(function () {
          if (idx + 1 < candidates.length) return tryDirect(candidates[idx + 1], idx + 1);
          return '';
        });
    }

    return tryDirect(candidates[0], 0);
  }

  function fetchJson(url) {
    return fetchText(url).then(function (t) {
      if (!t || isBlockedBody(t)) return null;
      try {
        return JSON.parse(t);
      } catch (e) {
        return null;
      }
    });
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
        return (
          (c2 < a ? '' : e(parseInt(c2 / a, 10))) +
          ((c2 = c2 % a) > 35 ? String.fromCharCode(c2 + 29) : c2.toString(36))
        );
      };
      var d = {};
      while (c--) d[e(c)] = k[c] || e(c);
      return p.replace(/\b\w+\b/g, function (w) {
        return d[w];
      });
    } catch (e) {
      return code;
    }
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

  function extractKwik(kwikUrl) {
    return ctx
      .fetch(kwikUrl, { headers: Object.assign({}, hdrs, { Referer: base + '/' }) })
      .then(function (r) {
        return r.text();
      })
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
            var m3u8M =
              unpacked.match(/source\s*=\s*'([^']+m3u8[^']*)'/) ||
              unpacked.match(/source\s*=\s*"([^"]+m3u8[^"]*)"/);
            if (m3u8M) {
              var m3u8Url = m3u8M[1];
              var titleM = html.match(/<title>([\s\S]*?)<\/title>/);
              var title = titleM ? titleM[1].trim() : 'video';
              var fileName = title.endsWith('.mp4') ? title : title + '.mp4';
              var parts = m3u8Url.replace('/stream/', '/mp4/').split('/');
              parts.pop();
              var origin = (kwikUrl.match(/^https?:\/\/[^/]+/) || [kwikOrigin])[0];
              return {
                m3u8: m3u8Url,
                mp4: parts.join('/') + '?file=' + encodeURIComponent(fileName),
                headers: { Referer: origin + '/', Origin: origin, 'User-Agent': ua },
              };
            }
            pos = closeParen + 2;
          }
        }
        return null;
      })
      .catch(function () {
        return null;
      });
  }

  function extractPahe(url) {
    var initUrl = url.endsWith('/i') ? url : url + '/i';
    return ctx
      .fetch(initUrl, {
        method: 'GET',
        headers: Object.assign({}, hdrs, { Referer: 'https://pahe.win/' }),
      })
      .then(function (r) {
        var loc = r.headers.get('location') || r.headers.get('Location');
        if (!loc) return null;
        var kwikUrl = /^https?:/i.test(loc) ? loc : 'https://' + loc.replace(/^\/+/, '');
        return ctx
          .fetch(kwikUrl, { headers: Object.assign({}, hdrs, { Referer: kwikOrigin + '/' }) })
          .then(function (r2) {
            return r2.text().then(function (html) {
              var cookie = (r2.headers.get('set-cookie') || r2.headers.get('Set-Cookie') || '').split(
                ';',
              )[0];
              var pm = html.match(/\("(\w+)",\d+,"(\w+)",(\d+),(\d+),\d+\)/);
              if (!pm) return null;
              var decrypted = paheDecrypt(pm[1], pm[2], parseInt(pm[3], 10), parseInt(pm[4], 10));
              var actionM = decrypted.match(/action="([^"]+)"/);
              var tokenM = decrypted.match(/value="([^"]+)"/);
              if (!actionM || !tokenM) return null;
              var origin = (kwikUrl.match(/^https?:\/\/[^/]+/) || [kwikOrigin])[0];
              return ctx
                .fetch(actionM[1], {
                  method: 'POST',
                  redirect: 'manual',
                  headers: Object.assign({}, hdrs, {
                    Referer: kwikUrl,
                    Cookie: cookie,
                    'Content-Type': 'application/x-www-form-urlencoded',
                  }),
                  body: '_token=' + encodeURIComponent(tokenM[1]),
                })
                .then(function (r3) {
                  var location = r3.headers.get('location') || r3.headers.get('Location');
                  if (!location) return null;
                  return {
                    url: location,
                    headers: { Referer: origin + '/', Origin: origin, 'User-Agent': ua },
                  };
                });
            });
          });
      })
      .catch(function () {
        return null;
      });
  }

  function qualityFromText(text) {
    var m = String(text || '').match(/(\d{3,4})p/);
    return m ? m[1] + 'p' : '720p';
  }

  function pushKwik(tasks, streams, kwikUrl, q, type) {
    if (!kwikUrl || !/kwik/i.test(kwikUrl)) return;
    tasks.push(
      extractKwik(kwikUrl).then(function (res) {
        if (!res) return;
        if (res.m3u8) {
          streams.push({
            name: 'AnimePahe [HLS] (' + q + ' ' + type + ')',
            url: res.m3u8,
            quality: q,
            language: type,
            headers: res.headers,
          });
        }
        if (res.mp4) {
          streams.push({
            name: 'AnimePahe [MP4] (' + q + ' ' + type + ')',
            url: res.mp4,
            quality: q,
            language: type,
            headers: Object.assign({}, res.headers, { Referer: kwikUrl }),
          });
        }
      }),
    );
  }

  function resolveMal() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost && fromHost.malId) {
      return Promise.resolve({
        malId: fromHost.malId,
        mappedEp: fromHost.mappedEp || fromHost.ep || 1,
        title: fromHost.title || String(ctx.title || ''),
      });
    }
    var mal = Number(ctx.malId) || 0;
    if (mal > 0) {
      var ep = Number(ctx.mappedEpisode || ctx.episode || 1) || 1;
      var title = String(ctx.title || '');
      if (title) return Promise.resolve({ malId: mal, mappedEp: ep, title: title });
      return ctx
        .fetch('https://api.jikan.moe/v4/anime/' + mal, { headers: { Accept: 'application/json' } })
        .then(function (r) {
          return r.json();
        })
        .then(function (malJson) {
          return {
            malId: mal,
            mappedEp: ep,
            title: (malJson && malJson.data && malJson.data.title) || title,
          };
        })
        .catch(function () {
          return { malId: mal, mappedEp: ep, title: title };
        });
    }
    return ctx
      .fetch(
        'https://api.themoviedb.org/3/tv/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '/external_ids?api_key=' +
          encodeURIComponent(tmdbKey),
        { headers: { Accept: 'application/json' } },
      )
      .then(function (r) {
        return r.json();
      })
      .then(function (d) {
        var imdbId = d.imdb_id;
        if (!imdbId) return null;
        return ctx
          .fetch(
            'https://id-mapping-api-malid.hf.space/api/resolve?id=' +
              imdbId +
              '&s=' +
              (ctx.season || 1) +
              '&e=' +
              (ctx.episode || 1),
          )
          .then(function (r) {
            return r.json();
          })
          .then(function (map) {
            if (!map || !map.mal_id) return null;
            return ctx
              .fetch('https://api.jikan.moe/v4/anime/' + map.mal_id)
              .then(function (r) {
                return r.json();
              })
              .then(function (malJson) {
                return {
                  malId: map.mal_id,
                  mappedEp: map.mal_episode || ctx.episode || 1,
                  title: malJson.data.title,
                };
              });
          });
      });
  }

  function findSession(title, malId) {
    return fetchJson('/api?m=search&l=8&q=' + encodeURIComponent(title)).then(function (res) {
      var data = (res && res.data) || [];
      var tasks = data.slice(0, 5).map(function (item) {
        return fetchText('/anime/' + item.session)
          .then(function (html) {
            return html.indexOf('myanimelist.net/anime/' + malId) >= 0 ? item.session : null;
          })
          .catch(function () {
            return null;
          });
      });
      return Promise.all(tasks).then(function (sessions) {
        return sessions.find(Boolean) || null;
      });
    });
  }

  function episodeSession(animeSession, mappedEp) {
    return fetchJson('/api?m=release&id=' + animeSession + '&sort=episode_asc&page=1').then(
      function (first) {
        var epStart = Math.floor(((first.data || [])[0] || {}).episode || 1);
        var perPage = first.per_page || 30;
        var targetEp = epStart - 1 + mappedEp;
        var page = Math.ceil(mappedEp / perPage) || 1;
        return fetchJson(
          '/api?m=release&id=' + animeSession + '&sort=episode_asc&page=' + page,
        ).then(function (pageData) {
          var found = (pageData.data || []).find(function (e) {
            return Math.floor(e.episode) == targetEp;
          });
          if (found) return found.session;
          var fallback = (first.data || []).find(function (e) {
            return Math.floor(e.episode) == targetEp;
          });
          return fallback ? fallback.session : null;
        });
      },
    );
  }

  function collectFromHtml(html, streams, tasks) {
    var cheerioOk = false;
    try {
      if (ctx.html) {
        var $ = ctx.html(html);
        cheerioOk = true;
        $('#resolutionMenu button').each(function () {
          var btn = $(this);
          var kwikUrl = btn.attr('data-src') || '';
          var q = qualityFromText(btn.text());
          var type = /eng/i.test(btn.text()) ? 'Dub' : 'Sub';
          pushKwik(tasks, streams, kwikUrl, q, type);
        });
        $('button[data-kwa], [data-kwa]').each(function () {
          var btn = $(this);
          var kwa = btn.attr('data-kwa') || btn.attr('data-src') || '';
          var q = qualityFromText(btn.text() || btn.attr('data-resolution'));
          var type = /eng|dub/i.test(btn.attr('data-audio') || btn.text()) ? 'Dub' : 'Sub';
          pushKwik(tasks, streams, kwa, q, type);
        });
        $('div#pickDownload a').each(function () {
          var link = $(this);
          var href = link.attr('href') || '';
          var q = qualityFromText(link.text());
          var type = /eng/i.test(link.find('span').text()) ? 'Dub' : 'Sub';
          if (/pahe\.|kwik/i.test(href)) {
            tasks.push(
              extractPahe(href).then(function (res) {
                if (res && res.url) {
                  streams.push({
                    name: 'AnimePahe [Direct] (' + q + ' ' + type + ')',
                    url: res.url,
                    quality: q,
                    language: type,
                    headers: res.headers,
                  });
                }
              }),
            );
          }
        });
      }
    } catch (e) {
      cheerioOk = false;
    }
    if (cheerioOk && tasks.length) return;

    // Forja EngineJS has no cheerio — scrape buttons via regex.
    var btnRe =
      /<button[^>]*data-src=["']([^"']+)["'][^>]*>([\s\S]*?)<\/button>/gi;
    var m;
    while ((m = btnRe.exec(html)) !== null) {
      var src = m[1];
      var label = m[2].replace(/<[^>]+>/g, ' ');
      pushKwik(tasks, streams, src, qualityFromText(label), /eng/i.test(label) ? 'Dub' : 'Sub');
    }
    var kwaRe =
      /<(?:button|div|a)[^>]*data-kwa=["']([^"']+)["'][^>]*(?:data-audio=["']([^"']*)["'])?[^>]*>([\s\S]*?)<\/(?:button|div|a)>/gi;
    while ((m = kwaRe.exec(html)) !== null) {
      var kwa = m[1];
      var audio = m[2] || '';
      var lab = m[3].replace(/<[^>]+>/g, ' ');
      pushKwik(
        tasks,
        streams,
        kwa,
        qualityFromText(lab),
        /eng|dub/i.test(audio + ' ' + lab) ? 'Dub' : 'Sub',
      );
    }
    var dlRe = /<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
    while ((m = dlRe.exec(html)) !== null) {
      if (!/pahe\.|kwik/i.test(m[1])) continue;
      if (html.indexOf('pickDownload') < 0 && html.indexOf('id="pickDownload"') < 0) {
        // still allow pahe.win links anywhere on play page
      }
      var href = m[1];
      var text = m[2].replace(/<[^>]+>/g, ' ');
      var q = qualityFromText(text);
      var type = /eng/i.test(text) ? 'Dub' : 'Sub';
      if (/pahe\./i.test(href)) {
        tasks.push(
          extractPahe(href).then(function (res) {
            if (res && res.url) {
              streams.push({
                name: 'AnimePahe [Direct] (' + q + ' ' + type + ')',
                url: res.url,
                quality: q,
                language: type,
                headers: res.headers,
              });
            }
          }),
        );
      } else {
        pushKwik(tasks, streams, href, q, type);
      }
    }
  }

  function playStreams(animeSession, episodeSessionId) {
    return fetchText('/play/' + animeSession + '/' + episodeSessionId).then(function (html) {
      var streams = [];
      var tasks = [];
      collectFromHtml(html, streams, tasks);
      return Promise.all(tasks).then(function () {
        var order = { '1080p': 3, '720p': 2, '360p': 1 };
        return streams.sort(function (a, b) {
          return (order[b.quality] || 0) - (order[a.quality] || 0);
        });
      });
    });
  }

  function resolveEpisodic() {
    return resolveMal()
      .then(function (info) {
        if (!info || !info.malId) return [];
        var title = info.title || String(ctx.title || '');
        if (!title) return [];
        return findSession(title, info.malId).then(function (animeSession) {
          if (!animeSession) return [];
          return episodeSession(animeSession, info.mappedEp).then(function (epSess) {
            if (!epSess) return [];
            return playStreams(animeSession, epSess);
          });
        });
      })
      .catch(function () {
        return [];
      });
  }

  if (isEpisodic) return resolveEpisodic();

  return ctx
    .fetch(
      'https://api.themoviedb.org/3/movie/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
    )
    .then(function (r) {
      return r.json();
    })
    .then(function (d) {
      var title = d.title || d.original_title;
      if (!title) return [];
      return fetchJson('/api?m=search&l=8&q=' + encodeURIComponent(title)).then(function (res) {
        var first = ((res && res.data) || [])[0];
        if (!first || first.title.toLowerCase() !== title.toLowerCase()) return [];
        return episodeSession(first.session, 1).then(function (epSess) {
          if (!epSess) return [];
          return playStreams(first.session, epSess);
        });
      });
    })
    .catch(function () {
      return [];
    });
}
