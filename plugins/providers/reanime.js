var SPECS = {
  "base": "https://reanime.to",
  "tmdbKey": "439c478a771f35c05022f9feabcca01c"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var anilistUrl = cfg.anilistUrl || 'https://graphql.anilist.co';
  var armBase = cfg.armBase || 'https://arm.haglund.dev/api/v2';
  var cinemetaUrl = cfg.cinemetaUrl || 'https://v3-cinemeta.strem.io/meta';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,application/json,*/*', 'Accept-Language': 'en-US,en;q=0.9' };
  var isTv = ctx.type !== 'movie';

  function abs(path) {
    if (!path) return '';
    if (/^https?:/i.test(path)) return path;
    return base + (path.startsWith('/') ? path : '/' + path);
  }

  function fetchText(url, extra) {
    return ctx.fetch(abs(url), { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) { return r.text(); });
  }

  function fetchJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}, { Accept: 'application/json' }) })
      .then(function (r) { return r.json(); });
  }

  function getTmdb() {
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' + encodeURIComponent(tmdbKey) + '&append_to_response=external_ids',
    ).then(function (d) {
      return {
        title: d.name || d.title || '',
        year: ((d.first_air_date || d.release_date || '').match(/\d{4}/) || [])[0],
        imdbId: d.external_ids && d.external_ids.imdb_id,
      };
    });
  }

  function cinemetaEpisode(imdbId, season, episode) {
    return fetchJson(cinemetaUrl + '/series/' + imdbId + '.json').then(function (data) {
      var videos = (data.meta && data.meta.videos) || [];
      var target = videos.find(function (v) { return v.season == season && v.episode == episode; });
      if (!target || !target.released) return { date: null, title: null, dayIndex: 1 };
      var date = target.released.split('T')[0];
      var dayIndex = videos.filter(function (v) {
        return v.season == season && v.released && v.released.split('T')[0] === date &&
          parseInt(v.episode, 10) < parseInt(episode, 10);
      }).length + 1;
      return { date: date, title: target.name || null, dayIndex: dayIndex };
    }).catch(function () { return { date: null, title: null, dayIndex: 1 }; });
  }

  function getSyncInfo(season, episode) {
    var kind = isTv ? 'tv' : 'movie';
    var tmdbBase = 'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(ctx.tmdbId || ''));
    return Promise.all([
      fetchJson(tmdbBase + (isTv ? '/external_ids' : '') + '?api_key=' + encodeURIComponent(tmdbKey)),
      fetchJson(tmdbBase + '?api_key=' + encodeURIComponent(tmdbKey)),
    ]).then(function (pair) {
      var details = pair[0];
      var meta = pair[1];
      var imdbId = details.imdb_id;
      var title = meta.name || meta.title;
      if (!imdbId) {
        return fetchJson(armBase + '/themoviedb?id=' + encodeURIComponent(String(ctx.tmdbId))).then(function (arm) {
          imdbId = Array.isArray(arm) && arm.length ? arm[0].imdb : null;
          if (!imdbId) throw new Error('no imdb');
          return { title: title, releaseDate: meta.release_date, episodeTitle: null, dayIndex: 1, episode: episode };
        });
      }
      if (!isTv) {
        return cinemetaEpisode(imdbId, 1, 1).then(function () {
          return { title: title, releaseDate: meta.release_date, episodeTitle: null, dayIndex: 1, episode: 1 };
        });
      }
      return cinemetaEpisode(imdbId, season, episode).then(function (ep) {
        if (!ep.date) throw new Error('no date');
        return { title: title, releaseDate: ep.date, episodeTitle: ep.title, dayIndex: ep.dayIndex, episode: episode };
      });
    });
  }

  function resolveByDate(releaseDate, showTitle, episode, episodeTitle, dayIndex) {
    var query = 'query($search:String){Page(perPage:20){media(search:$search,type:ANIME){id type format title{romaji english}startDate{year month day}endDate{year month day}episodes streamingEpisodes{title}}}}';
    return ctx.fetch(anilistUrl, {
      method: 'POST',
      headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json' }),
      body: JSON.stringify({ query: query, variables: { search: showTitle } }),
    }).then(function (r) { return r.json(); }).then(function (json) {
      var candidates = (((json.data || {}).Page || {}).media) || [];
      var targetDate = new Date(releaseDate);
      for (var i = 0; i < candidates.length; i++) {
        var anime = candidates[i];
        var s = anime.startDate || {};
        if (!s.year || !s.month || !s.day) continue;
        var startStr = s.year + '-' + String(s.month).padStart(2, '0') + '-' + String(s.day).padStart(2, '0');
        var startDate = new Date(startStr);
        var diffDays = Math.ceil(Math.abs(targetDate - startDate) / 86400000);
        var isMatch = false;
        if (anime.format === 'MOVIE' || anime.format === 'SPECIAL' || anime.episodes === 1) {
          if (diffDays <= 2) isMatch = true;
        } else {
          var startLimit = new Date(startDate);
          startLimit.setDate(startLimit.getDate() - 2);
          if (targetDate >= startLimit) isMatch = true;
        }
        if (!isMatch) continue;
        var isTV = anime.format !== 'MOVIE' && anime.format !== 'SPECIAL' && anime.episodes !== 1;
        var epNum = isTV && episode ? episode : dayIndex || 1;
        var episodes = anime.streamingEpisodes || [];
        if (episodes.length > 1 && episodeTitle) {
          var cleanTarget = episodeTitle.toLowerCase().replace(/[^a-z0-9]/g, '');
          for (var j = 0; j < episodes.length; j++) {
            var cleanAl = String(episodes[j].title || '').toLowerCase().replace(/[^a-z0-9]/g, '');
            if (cleanAl && (cleanAl.indexOf(cleanTarget) >= 0 || cleanTarget.indexOf(cleanAl) >= 0)) epNum = j + 1;
          }
        }
        return { alId: anime.id, episode: epNum, title: (anime.title && (anime.title.english || anime.title.romaji)) || showTitle };
      }
      return null;
    });
  }

  function searchReanime(query, year, targetAlId) {
    var endpoints = [
      '/api/search?q=' + encodeURIComponent(query),
      '/api/anime/search?q=' + encodeURIComponent(query),
      '/search?keyword=' + encodeURIComponent(query),
    ];
    var chain = Promise.resolve([]);
    endpoints.forEach(function (ep) {
      chain = chain.then(function (found) {
        if (found.length) return found;
        return fetchText(ep).then(function (text) {
          var list = [];
          if (text.trim().charAt(0) === '{' || text.trim().charAt(0) === '[') {
            try {
              var json = JSON.parse(text);
              var arr = json.data || json.results || json.anime || json;
              if (Array.isArray(arr)) {
                arr.forEach(function (item) {
                  var slug = item.anime_id || item.slug || item.id;
                  if (!slug) return;
                  var cleanSlug = String(slug).replace(/-[a-z0-9]{6}$/, '');
                  list.push({ slug: cleanSlug, anilistId: item.anilist_id || item.anilistId, title: item.title || item.name || cleanSlug });
                });
              }
            } catch (e) {}
          } else {
            var re = /\/(?:anime|watch)\/([^?#"'\s]+)/g;
            var m;
            while ((m = re.exec(text)) !== null) list.push({ slug: m[1], title: query, anilistId: null });
          }
          return list;
        }).catch(function () { return []; });
      });
    });
    return chain.then(function (candidates) {
      if (targetAlId) {
        var hit = candidates.find(function (c) { return c.anilistId && String(c.anilistId) === String(targetAlId); });
        if (hit) return hit;
      }
      return candidates[0] || null;
    });
  }

  function flixEmbeds(slug, episode, language, alId) {
    var watchPath = '/watch/' + slug + '?ep=' + episode + '&lang=' + language;
    return fetchText(watchPath).then(function (html) {
      var embeds = [];
      var re = /https?:\/\/flixcloud\.cc\/e\/[A-Za-z0-9_-]+[^"'\\\s<]*/g;
      var m;
      while ((m = re.exec(html)) !== null) embeds.push(m[0]);
      // Anivault-style dataLink / data-an-video attributes on watch pages.
      var attrRe = /data-(?:an-video|link|src)=["'](https?:\/\/[^"']+)["']/gi;
      while ((m = attrRe.exec(html)) !== null) embeds.push(m[1]);
      var dataLinkRe = /"dataLink"\s*:\s*"(https?:\\\/\\\/[^"]+|https?:\/\/[^"]+)"/g;
      while ((m = dataLinkRe.exec(html)) !== null) {
        embeds.push(m[1].replace(/\\\//g, '/'));
      }
      if (!embeds.length && alId) {
        return fetchJson(base + '/api/flix/' + alId + '/' + episode).then(function (json) {
          var text = JSON.stringify(json);
          while ((m = re.exec(text)) !== null) embeds.push(m[0]);
          var dl = json && (json.dataLink || (json.sub && json.sub[0] && json.sub[0].dataLink));
          if (dl) embeds.push(dl);
          return embeds;
        }).catch(function () { return embeds; });
      }
      return embeds;
    });
  }

  function normalizeFlix(url) {
    if (!url) return '';
    if (!/^https?:/i.test(url)) url = 'https://flixcloud.cc' + (url.startsWith('/') ? url : '/' + url);
    return url.replace(/[?&]v=[^&]+/, '').replace(/[?&]kuudere_ts=[^&]+/, '');
  }

  var season = ctx.season || 1;
  var episode = ctx.episode || 1;
  var hostAl = globalThis.__engineCtxAnilist && globalThis.__engineCtxAnilist(ctx);
  if (hostAl) {
    var epNum = Number(ctx.mappedEpisode || episode);
    var showTitle = String(ctx.title || '');
    return searchReanime(showTitle, null, hostAl).then(function (anime) {
      if (!anime || !anime.slug) return [];
      var langs = ['sub', 'dub'];
      return Promise.all(langs.map(function (lang) {
        return flixEmbeds(anime.slug, epNum, lang, hostAl).then(function (embeds) {
          return Promise.all(embeds.map(function (embed, idx) {
            return ctx.hop(normalizeFlix(embed)).then(function (rows) {
              return rows.map(function (r) {
                return Object.assign({}, r, { name: 'Reanime ' + lang.toUpperCase() + ' HD-' + (idx + 1) });
              });
            });
          })).then(function (groups) { return [].concat.apply([], groups); });
        });
      })).then(function (groups) {
        var seen = {};
        return [].concat.apply([], groups).filter(function (s) {
          if (!s.url || seen[s.url]) return false;
          seen[s.url] = true;
          return true;
        });
      });
    });
  }
  return getSyncInfo(season, episode).then(function (syncInfo) {
    return resolveByDate(syncInfo.releaseDate, syncInfo.title, episode, syncInfo.episodeTitle, syncInfo.dayIndex)
      .then(function (resolved) {
        var alId = resolved && resolved.alId;
        var epNum = resolved ? resolved.episode : episode;
        var title = (resolved && resolved.title) || syncInfo.title;
        return searchReanime(title, null, alId).then(function (anime) {
          if (!anime || !anime.slug) return [];
          var langs = ['sub', 'dub'];
          return Promise.all(langs.map(function (lang) {
            return flixEmbeds(anime.slug, epNum, lang, alId || anime.anilistId).then(function (embeds) {
              return Promise.all(embeds.map(function (embed, idx) {
                return ctx.hop(normalizeFlix(embed)).then(function (rows) {
                  return rows.map(function (r) {
                    return Object.assign({}, r, { name: 'Reanime ' + lang.toUpperCase() + ' HD-' + (idx + 1) });
                  });
                });
              })).then(function (groups) { return [].concat.apply([], groups); });
            });
          })).then(function (groups) {
            var seen = {};
            return [].concat.apply([], groups).filter(function (s) {
              if (!s.url || seen[s.url]) return false;
              seen[s.url] = true;
              return true;
            });
          });
        });
      });
  }).catch(function () { return []; });
}
