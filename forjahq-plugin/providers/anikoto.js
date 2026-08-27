function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://anikototv.to').replace(/\/$/, '');
  var mapperBases = Array.isArray(cfg.mappers) && cfg.mappers.length
    ? cfg.mappers
    : [
        cfg.mapper || 'https://mapper.nekostream.site/api/mal',
        'https://mapper.mewcdn.online/api/mal',
      ];
  var anilistUrl = cfg.anilistUrl || 'https://graphql.anilist.co';
  var armBase = (cfg.armBase || 'https://arm.haglund.dev/api/v2').replace(/\/$/, '');
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var spoofRef = cfg.spoofRef || 'https://hianimes.re/';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,*/*', 'Accept-Language': 'en-US,en;q=0.9' };
  var isTv = ctx.type !== 'movie';
  var epNum = isTv ? ctx.episode || 1 : 1;

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url, extra) {
    return ctx
      .fetch(url, { headers: Object.assign({}, hdrs, extra || {}, { Accept: 'application/json,*/*' }) })
      .then(function (r) {
        return r.json();
      });
  }

  function normalize(s) {
    return String(s || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
  }

  function resolveMal() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) return Promise.resolve(fromHost.malId);
    if (!isTv) {
      return fetchJson(
        'https://api.themoviedb.org/3/movie/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
      )
        .then(function (d) {
          var title = d.title || d.original_title || '';
          if (!title) return null;
          return fetchJson(jikan + '?q=' + encodeURIComponent(title) + '&type=movie&limit=1').then(function (j) {
            return j && j.data && j.data[0] ? j.data[0].mal_id : null;
          });
        })
        .catch(function () {
          return null;
        });
    }
    var imdbP = ctx.imdbId
      ? Promise.resolve(String(ctx.imdbId))
      : fetchJson(
          'https://api.themoviedb.org/3/tv/' +
            encodeURIComponent(String(ctx.tmdbId || '')) +
            '/external_ids?api_key=' +
            encodeURIComponent(tmdbKey),
        )
          .then(function (d) {
            return (d && d.imdb_id) || '';
          })
          .catch(function () {
            return '';
          });
    return imdbP.then(function (imdbId) {
      if (!imdbId) return null;
      return fetchJson(
        mapApi +
          '?id=' +
          encodeURIComponent(imdbId) +
          '&s=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&e=' +
          encodeURIComponent(String(epNum)),
      )
        .then(function (m) {
          return m && m.mal_id ? { mal: m.mal_id, ep: m.mal_episode || epNum } : null;
        })
        .catch(function () {
          return null;
        });
    });
  }

  function fetchAnilistMedia(anilistId) {
    return ctx
      .fetch(anilistUrl, {
        method: 'POST',
        headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json', Accept: 'application/json' }),
        body: JSON.stringify({
          query: 'query($id:Int){Media(id:$id,type:ANIME){id idMal title{english romaji native} synonyms}}',
          variables: { id: Number(anilistId) },
        }),
      })
      .then(function (r) {
        return r.json();
      })
      .then(function (j) {
        var m = j && j.data && j.data.Media;
        if (!m) return null;
        return {
          idMal: m.idMal,
          title: { english: m.title && m.title.english, romaji: m.title && m.title.romaji },
          synonyms: m.synonyms || [],
        };
      });
  }

  function searchAnikoto(query) {
    return fetchText(base + '/filter?keyword=' + encodeURIComponent(query), { Referer: base + '/' }).then(function (html) {
      var candidates = [];
      var re =
        /<a\s+class="name d-title"\s+href="https:\/\/anikototv\.to\/watch\/([^"/]+)(?:\/ep-\d+)?"[^>]*data-jp="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g;
      var m;
      while ((m = re.exec(html)) !== null) {
        candidates.push({ slug: m[1], jp: m[2].trim(), name: m[3].replace(/<[^>]*>/g, '').trim() });
      }
      if (!candidates.length) {
        var re2 = /<a\s+href="https:\/\/anikototv\.to\/watch\/([^"/]+)(?:\/ep-\d+)?"[^>]*>([\s\S]*?)<\/a>/g;
        while ((m = re2.exec(html)) !== null) candidates.push({ slug: m[1], name: m[1], jp: '' });
      }
      var seen = {};
      return candidates.filter(function (c) {
        if (seen[c.slug]) return false;
        seen[c.slug] = true;
        return true;
      });
    });
  }

  function scoreCandidate(cand, primaryEn, primaryRom, synonyms) {
    var score = 0;
    var candNameNorm = normalize(cand.name);
    var normEn = normalize(primaryEn);
    var normRom = normalize(primaryRom);
    if (normEn && candNameNorm === normEn) score += 1000;
    if (normRom && candNameNorm === normRom) score += 900;
    return score;
  }

  function findAnikotoShow(media) {
    var primaryEn = media.title && media.title.english;
    var primaryRom = media.title && media.title.romaji;
    var synonyms = media.synonyms || [];
    var keywords = [];
    [primaryEn, primaryRom].concat(synonyms).forEach(function (k) {
      if (k && keywords.indexOf(k) < 0) keywords.push(k);
    });
    var allMap = {};
    return Promise.all(
      keywords.slice(0, 5).map(function (k) {
        return searchAnikoto(k).catch(function () {
          return [];
        });
      }),
    ).then(function (groups) {
      groups.forEach(function (res) {
        res.forEach(function (c) {
          allMap[c.slug] = c;
        });
      });
      var candidates = Object.keys(allMap).map(function (k) {
        return allMap[k];
      });
      if (!candidates.length) throw new Error('no anikoto results');
      candidates.sort(function (a, b) {
        return (
          scoreCandidate(b, primaryEn, primaryRom, synonyms) - scoreCandidate(a, primaryEn, primaryRom, synonyms)
        );
      });
      var chosen = candidates[0];
      return fetchText(base + '/watch/' + chosen.slug, { Referer: base + '/' }).then(function (watchHtml) {
        var showIdM = watchHtml.match(/data-id="(\d+)"/);
        if (!showIdM) throw new Error('no show id');
        return { slug: chosen.slug, showId: showIdM[1], title: chosen.name };
      });
    });
  }

  function rewriteMewstream(m3u8, tracks) {
    if (!m3u8 || m3u8.indexOf('mewstream.buzz') < 0) return m3u8;
    var replacementHost = '1oe.lostproject.club';
    if (Array.isArray(tracks)) {
      for (var i = 0; i < tracks.length; i++) {
        var tUrl = tracks[i] && tracks[i].file;
        if (tUrl && tUrl.indexOf('mewstream.buzz') < 0) {
          try {
            replacementHost = new URL(tUrl).host;
            break;
          } catch (e) {}
        }
      }
    }
    try {
      var parsed = new URL(m3u8);
      parsed.host = replacementHost;
      return parsed.toString();
    } catch (e) {
      return m3u8;
    }
  }

  function normalizeMegaplayUrl(embedUrl) {
    return String(embedUrl || '')
      .replace('vidwish.live', 'megaplay.buzz')
      .replace('megacloud.bloggy.click', 'megaplay.buzz');
  }

  function extractEmbedSource(embedUrl) {
    var normalized = normalizeMegaplayUrl(embedUrl);
    return fetchText(normalized, { Referer: spoofRef, 'Accept-Language': 'en-US,en;q=0.9' })
      .then(function (pageHtml) {
        var m = pageHtml.match(/data-id="([^"]*)"/) || pageHtml.match(/ File ([0-9]+)/);
        if (!m || !m[1]) return null;
        var fileId = m[1];
        var origin = (normalized.match(/^https?:\/\/[^/]+/) || [''])[0];
        return fetchJson(origin + '/stream/getSources?id=' + fileId + (fileId.indexOf('&') >= 0 ? '' : '&id=' + fileId), {
          Referer: origin + '/',
          'X-Requested-With': 'XMLHttpRequest',
        }).then(function (data) {
          if (data && data.sources && data.sources.file) {
            data.sources.file = rewriteMewstream(data.sources.file, data.tracks);
          }
          return { fileId: fileId, data: data, origin: origin };
        });
      })
      .catch(function () {
        return null;
      });
  }

  function fetchKiwiMapper(mal, slug, timestamp) {
    var chain = Promise.resolve(null);
    mapperBases.forEach(function (mapperBase) {
      chain = chain.then(function (found) {
        if (found) return found;
        return fetchJson(mapperBase + '/' + mal + '/' + slug + '/' + timestamp, { Referer: base + '/' }).catch(function () {
          return null;
        });
      });
    });
    return chain;
  }

  function parseEpisodeTarget(html, episode) {
    var re = /<a\s+[^>]*data-id="([^"]*)"[^>]*>/g;
    var m;
    while ((m = re.exec(html)) !== null) {
      var tag = m[0];
      function getAttr(attr) {
        var x = tag.match(new RegExp('data-' + attr + '="([^"]*)"'));
        return x ? x[1] : '';
      }
      if (parseInt(getAttr('num'), 10) === episode) {
        return {
          ids: getAttr('ids'),
          mal: getAttr('mal'),
          slug: getAttr('slug'),
          timestamp: getAttr('timestamp'),
        };
      }
    }
    return null;
  }

  function streamsForAudio(show, targetEp, audio) {
    return fetchJson(base + '/ajax/server/list?servers=' + encodeURIComponent(targetEp.ids), {
      'X-Requested-With': 'XMLHttpRequest',
      Referer: base + '/',
    })
      .then(function (serverData) {
        var mapperP =
          targetEp.mal && targetEp.slug && targetEp.timestamp
            ? fetchKiwiMapper(targetEp.mal, targetEp.slug, targetEp.timestamp)
            : Promise.resolve(null);
        return mapperP.then(function (mapperData) {
          var serverHtml = (serverData && serverData.result) || '';
          var serverItems = [];
          var typeRe = /<div class="type" data-type="([^"]+)">([\s\S]*?)<\/ul>\s*<\/div>/g;
          var typeM;
          while ((typeM = typeRe.exec(serverHtml)) !== null) {
            if (typeM[1] !== audio) continue;
            var liRe = /<li\s+([^>]*data-link-id[^>]*)>([\s\S]*?)<\/li>/g;
            var liM;
            while ((liM = liRe.exec(typeM[2])) !== null) {
              var linkIdM = liM[1].match(/data-link-id="([^"]+)"/);
              var name = liM[2].replace(/<[^>]+>/g, '').trim();
              if (linkIdM) serverItems.push({ linkId: linkIdM[1], name: name });
            }
          }
          if (mapperData) {
            Object.keys(mapperData).forEach(function (sKey) {
              if (sKey === 'status') return;
              var sObj = mapperData[sKey];
              if (sObj && sObj[audio] && sObj[audio].url) {
                serverItems.push({ linkId: sObj[audio].url, name: sKey.replace(/[-_]+$/, '').trim() });
              }
            });
          }
          return Promise.all(
            serverItems.slice(0, 6).map(function (item) {
              var resolvedP = item.linkId.indexOf('http') === 0
                ? Promise.resolve({ result: { url: item.linkId } })
                : fetchJson(base + '/ajax/server?get=' + encodeURIComponent(item.linkId), {
                    'X-Requested-With': 'XMLHttpRequest',
                    Referer: base + '/',
                  }).catch(function () {
                    return null;
                  });
              return resolvedP.then(function (resolved) {
                var embedUrl = resolved && resolved.result && resolved.result.url;
                if (!embedUrl) return [];
                if (embedUrl.indexOf('#aHR0c') >= 0) {
                  try {
                    var decoded = atob(embedUrl.split('#')[1]);
                    if (decoded.indexOf('.m3u8') >= 0) {
                      return [
                        {
                          url: decoded,
                          name: 'Anikoto ' + item.name,
                          headers: { 'User-Agent': ua, Referer: base + '/watch/' + show.slug },
                          language: audio === 'dub' ? 'Dub' : 'Sub',
                        },
                      ];
                    }
                  } catch (e) {}
                }
                return extractEmbedSource(embedUrl).then(function (extracted) {
                  if (extracted && extracted.data && extracted.data.sources && extracted.data.sources.file) {
                    return [
                      {
                        url: extracted.data.sources.file,
                        name: 'Anikoto ' + item.name,
                        headers: { 'User-Agent': ua, Referer: extracted.origin + '/' },
                        language: audio === 'dub' ? 'Dub' : 'Sub',
                      },
                    ];
                  }
                  return ctx.hop(embedUrl).then(function (rows) {
                    return rows.map(function (r) {
                      return Object.assign({}, r, { name: 'Anikoto ' + item.name, language: audio === 'dub' ? 'Dub' : 'Sub' });
                    });
                  });
                });
              });
            }),
          ).then(function (groups) {
            return [].concat.apply([], groups);
          });
        });
      });
  }

  return resolveMal()
    .then(function (mapped) {
      if (!mapped) return [];
      return fetchJson(armBase + '/ids?source=myanimelist&id=' + mapped.mal).then(function (arm) {
        var alId = arm && arm.anilist;
        if (!alId) return [];
        return fetchAnilistMedia(alId).then(function (media) {
          if (!media) return [];
          return findAnikotoShow(media).then(function (show) {
            return fetchJson(base + '/ajax/episode/list/' + show.showId, {
              'X-Requested-With': 'XMLHttpRequest',
              Referer: base + '/watch/' + show.slug,
            }).then(function (listJson) {
              var targetEp = parseEpisodeTarget((listJson && listJson.result) || '', mapped.ep);
              if (!targetEp || !targetEp.ids) return [];
              return streamsForAudio(show, targetEp, 'sub').then(function (sub) {
                if (sub.length) return sub;
                return streamsForAudio(show, targetEp, 'dub');
              });
            });
          });
        });
      });
    })
    .catch(function () {
      return [];
    });
}
