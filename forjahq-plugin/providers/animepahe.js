function extract(ctx) {
  var cfg = ctx.config || {};
  var mirrors = Array.isArray(cfg.mirrors) && cfg.mirrors.length
    ? cfg.mirrors.map(function (m) { return String(m).replace(/\/$/, ''); })
    : [
        'https://animepahe.su',
        'https://animepahe.pw',
        'https://animepahe.ru',
        'https://animepahe.com',
        'https://animepahe.org',
      ];
  var base = (cfg.base || mirrors[0] || 'https://animepahe.su').replace(/\/$/, '');
  var proxy =
    cfg.proxy || 'https://animepaheproxy.phisheranimepahe.workers.dev/?url=';
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
    return (
      /Just a moment|cdn-cgi|challenge-platform|__ddg|Attention Required|cf-browser-verification|noindex,\s*noarchive|ddos|Enable JavaScript and cookies/i.test(
        s,
      ) || /^<!--\s*\d+\s*-->/.test(s) || /^<!DOCTYPE/i.test(s) || /^<html/i.test(s)
    );
  }

  function fetchText(url) {
    var isAbs = /^https?:/i.test(url);
    var candidates = isAbs
      ? [url]
      : mirrors.map(function (m) {
          return String(m).replace(/\/$/, '') + url;
        });

    function directOne(target) {
      var origin = (String(target).match(/^https?:\/\/[^/]+/) || [base])[0];
      var reqHdrs = Object.assign({}, hdrs, { Referer: origin + '/' });
      return ctx.fetch(target, { headers: reqHdrs }).then(function (r) {
        return r.text().then(function (text) {
          if (isBlockedBody(text)) throw new Error('blocked');
          if (!isAbs) {
            base = origin;
            hdrs.Referer = origin + '/';
          }
          return text;
        });
      });
    }

    function proxyOne(target) {
      if (!proxy) return Promise.resolve('');
      var origin = (String(target).match(/^https?:\/\/[^/]+/) || [base])[0];
      var reqHdrs = Object.assign({}, hdrs, { Referer: origin + '/' });
      return ctx
        .fetch(proxy + encodeURIComponent(target), { headers: reqHdrs })
        .then(function (r) {
          return r.text().then(function (text) {
            if (isBlockedBody(text)) return '';
            if (!isAbs) {
              base = origin;
              hdrs.Referer = origin + '/';
            }
            return text;
          });
        })
        .catch(function () {
          return '';
        });
    }

    function directWalk(i) {
      if (i >= candidates.length) {
        function proxyWalk(j) {
          if (j >= candidates.length) return Promise.resolve('');
          return proxyOne(candidates[j]).then(function (t) {
            return t || proxyWalk(j + 1);
          });
        }
        return proxyWalk(0);
      }
      return directOne(candidates[i]).catch(function () {
        return directWalk(i + 1);
      });
    }

    return directWalk(0);
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
        var plyr = kwikFromPlyrSplit(html, kwikUrl);
        if (plyr) return plyr;
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

  function normTitle(s) {
    return String(s || '')
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function searchQueries(title) {
    var t = String(title || '').trim();
    if (!t) return [];
    var out = [t];
    var short = t.split(':')[0].trim();
    if (short && short !== t && short.length >= 4) out.push(short);
    var words = t.replace(/[^\w\s]/g, ' ').replace(/\s+/g, ' ').trim().split(' ');
    if (words.length > 5) out.push(words.slice(0, 5).join(' '));
    // Aniyomi-style trailing window (last 4 / last 3 words)
    if (words.length > 4) out.push(words.slice(-4).join(' '));
    if (words.length > 3) out.push(words.slice(-3).join(' '));
    return out.filter(function (q, i, a) {
      return q && a.indexOf(q) === i;
    });
  }

  function jikanTitles(malId) {
    if (!malId) return Promise.resolve([]);
    return ctx
      .fetch('https://api.jikan.moe/v4/anime/' + malId, {
        headers: { Accept: 'application/json' },
      })
      .then(function (r) {
        return r.json();
      })
      .then(function (j) {
        var d = j && j.data;
        if (!d) return [];
        var out = [];
        function push(v) {
          v = String(v || '').trim();
          if (v && out.indexOf(v) < 0) out.push(v);
        }
        push(d.title);
        push(d.title_english);
        push(d.title_japanese);
        (d.titles || []).forEach(function (row) {
          push(row && row.title);
        });
        return out;
      })
      .catch(function () {
        return [];
      });
  }

  function searchAnime(query) {
    return fetchJson('/api?m=search&q=' + encodeURIComponent(query)).then(function (res) {
      return (res && res.data) || [];
    });
  }

  function verifySessionMal(session, malId) {
    if (!session || !malId) return Promise.resolve(null);
    return fetchText('/anime/' + session)
      .then(function (html) {
        return html.indexOf('myanimelist.net/anime/' + malId) >= 0 ? session : null;
      })
      .catch(function () {
        return null;
      });
  }

  function pickSession(results, titles, malId) {
    if (!results || !results.length) return Promise.resolve(null);
    var wants = (titles || []).map(normTitle).filter(Boolean);
    var i;
    var j;
    for (j = 0; j < wants.length; j++) {
      for (i = 0; i < results.length; i++) {
        if (normTitle(results[i].title) === wants[j]) {
          return Promise.resolve(results[i].session);
        }
      }
    }
    for (j = 0; j < wants.length; j++) {
      for (i = 0; i < results.length; i++) {
        var got = normTitle(results[i].title);
        if (got.indexOf(wants[j]) >= 0 || wants[j].indexOf(got) >= 0) {
          return Promise.resolve(results[i].session);
        }
      }
    }
    if (malId) {
      var tasks = results.slice(0, 8).map(function (item) {
        return verifySessionMal(item.session, malId);
      });
      return Promise.all(tasks).then(function (sessions) {
        return sessions.find(Boolean) || null;
      });
    }
    return Promise.resolve(null);
  }

  function findSessionByTitles(titles, malId) {
    var queries = [];
    (titles || []).forEach(function (t) {
      searchQueries(t).forEach(function (q) {
        if (q && queries.indexOf(q) < 0) queries.push(q);
      });
    });
    function walk(i) {
      if (i >= queries.length) return Promise.resolve(null);
      return searchAnime(queries[i]).then(function (results) {
        return pickSession(results, titles, malId).then(function (session) {
          return session || walk(i + 1);
        });
      });
    }
    return walk(0);
  }

  // xenmods AnimepaheAPI.get_release pagination
  function releaseSession(animeSession, episode) {
    var ep = Math.floor(Number(episode) || 1);
    return fetchJson('/api?m=release&id=' + animeSession + '&sort=episode_asc').then(function (first) {
      if (!first || !first.data || !first.data.length) return null;
      if (ep > (first.total || 0)) return null;
      if ((first.last_page || 1) === 1) {
        var single = (first.data || []).find(function (file) {
          return Math.floor(file.episode) === ep;
        });
        return single ? single.session : null;
      }
      var page = Math.ceil((ep * (first.last_page || 1)) / (first.total || 1)) || 1;
      return fetchJson(
        '/api?m=release&id=' + animeSession + '&sort=episode_asc&page=' + page,
      ).then(function (resp) {
        var hit = (resp && resp.data ? resp.data : []).find(function (file) {
          return Math.floor(file.episode) === ep;
        });
        return hit ? hit.session : null;
      });
    });
  }

  function kwikFromPlyrSplit(html, kwikUrl) {
    try {
      var scripts = html.match(/<script[^>]*>([\s\S]*?)<\/script>/gi) || [];
      for (var si = 0; si < scripts.length; si++) {
        if (scripts[si].indexOf('Plyr') < 0 || scripts[si].indexOf('.split') < 0) continue;
        var body = scripts[si].replace(/^<script[^>]*>/i, '').replace(/<\/script>$/i, '');
        var part = body.split('Plyr')[1].split('.split')[0];
        var bits = part.split('|');
        if (bits.length < 10) continue;
        var origin = (kwikUrl.match(/^https?:\/\/[^/]+/) || [kwikOrigin])[0];
        var m3u8 =
          'https://' +
          bits[bits.length - 2] +
          '-' +
          bits[bits.length - 3] +
          '.' +
          bits[bits.length - 4] +
          '.' +
          bits[bits.length - 5] +
          '.' +
          bits[bits.length - 6] +
          '/hls/' +
          bits[bits.length - 8] +
          '/' +
          bits[bits.length - 9] +
          '/' +
          bits[bits.length - 10] +
          '/owo.m3u8';
        return {
          m3u8: m3u8,
          headers: { Referer: origin + '/', Origin: origin, 'User-Agent': ua },
        };
      }
    } catch (e) {}
    return null;
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

  function sortStreams(streams) {
    var order = { '1080p': 3, '720p': 2, '360p': 1 };
    return streams.sort(function (a, b) {
      return (order[b.quality] || 0) - (order[a.quality] || 0);
    });
  }

  function streamsFromLinksApi(episodeSessionId) {
    return fetchJson('/api?m=links&id=' + episodeSessionId + '&p=kwik').then(function (res) {
      if (!res || !res.data || !res.data.length) return [];
      var streams = [];
      var tasks = [];
      (res.data || []).forEach(function (item) {
        var keys = Object.keys(item || {});
        for (var ki = 0; ki < keys.length; ki++) {
          var qKey = keys[ki];
          var entry = item[qKey];
          if (!entry || !entry.kwik) continue;
          var q = /^\d+$/.test(String(qKey)) ? String(qKey) + 'p' : qualityFromText(qKey);
          var audio = String(entry.audio || '').toLowerCase();
          var type =
            audio === 'eng' || audio === 'english' || audio.indexOf('eng') >= 0 ? 'Dub' : 'Sub';
          pushKwik(tasks, streams, entry.kwik, q, type);
        }
      });
      return Promise.all(tasks).then(function () {
        return streams;
      });
    });
  }

  function playStreams(animeSession, episodeSessionId) {
    return streamsFromLinksApi(episodeSessionId).then(function (fromApi) {
      if (fromApi.length) return sortStreams(fromApi);
      return fetchText('/play/' + animeSession + '/' + episodeSessionId).then(function (html) {
        var streams = [];
        var tasks = [];
        collectFromHtml(html, streams, tasks);
        return Promise.all(tasks).then(function () {
          return sortStreams(streams);
        });
      });
    });
  }

  function resolveEpisodic() {
    var ep = Number(ctx.mappedEpisode || ctx.episode || 1) || 1;
    var title = String(ctx.title || '').trim();
    var mal = Number(ctx.malId) || 0;

    function pipeline(titles, malId) {
      var list = (titles || []).filter(Boolean);
      if (!list.length) return Promise.resolve([]);
      return findSessionByTitles(list, malId).then(function (animeSession) {
        if (!animeSession) return [];
        return releaseSession(animeSession, ep).then(function (epSess) {
          if (!epSess) return [];
          return playStreams(animeSession, epSess);
        });
      });
    }

    function withMalTitles(seedTitles, malId) {
      if (!malId) return pipeline(seedTitles, 0);
      return jikanTitles(malId).then(function (jt) {
        var merged = [];
        seedTitles.concat(jt).forEach(function (t) {
          t = String(t || '').trim();
          if (t && merged.indexOf(t) < 0) merged.push(t);
        });
        return pipeline(merged, malId);
      });
    }

    if (title || mal > 0) {
      return withMalTitles(title ? [title] : [], mal > 0 ? mal : 0).catch(function () {
        return [];
      });
    }

    return resolveMal()
      .then(function (info) {
        if (!info) return [];
        return withMalTitles(
          info.title ? [info.title] : [],
          info.malId || 0,
        );
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
        return releaseSession(first.session, 1).then(function (epSess) {
          if (!epSess) return [];
          return playStreams(first.session, epSess);
        });
      });
    })
    .catch(function () {
      return [];
    });
}
