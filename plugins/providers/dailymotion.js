var SPECS = {
  api: 'https://api.dailymotion.com',
  origin: 'https://www.dailymotion.com',
  tmdbKey: '439c478a771f35c05022f9feabcca01c',
  searchLimit: 12,
  maxResolve: 6,
  minScore: 25,
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var api = String(cfg.api || '').replace(/\/$/, '');
  var origin = String(cfg.origin || 'https://www.dailymotion.com').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var searchLimit = Math.max(1, Math.min(25, parseInt(cfg.searchLimit, 10) || 12));
  var maxResolve = Math.max(1, Math.min(12, parseInt(cfg.maxResolve, 10) || 6));
  var minScore = Math.max(0, parseInt(cfg.minScore, 10) || 25);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var mediaType = String(ctx.type || 'movie').toLowerCase();
  var isMovie = mediaType === 'movie';
  var tmdbId = String(ctx.tmdbId || '').trim();
  var season = parseInt(ctx.season, 10);
  if (!season || season < 1) season = 1;
  var episode = parseInt(ctx.episode, 10);
  if (!episode || episode < 1) episode = 1;
  if (!api || !tmdbId) return Promise.resolve([]);

  var chromeFetch =
    typeof ctx.chromeFetch === 'function' ? ctx.chromeFetch.bind(ctx) : ctx.fetch.bind(ctx);

  function log(msg) {
    if (ctx && typeof ctx.log === 'function') ctx.log(msg);
  }

  function getJson(url, headers) {
    return ctx.fetch(url, { headers: headers || { 'User-Agent': ua, Accept: 'application/json' } }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }

  function pad2(n) {
    var s = String(n);
    return s.length >= 2 ? s : '0' + s;
  }

  function normalizeTitle(s) {
    return String(s || '')
      .toLowerCase()
      .replace(/['']/g, '')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function titleTokens(s) {
    return normalizeTitle(s)
      .split(' ')
      .filter(function (t) {
        return t.length > 1 && ['the', 'and', 'of', 'a', 'an'].indexOf(t) < 0;
      });
  }

  function isJunkTitle(t) {
    return /trailer|teaser|clip|scene|ost|soundtrack|review|reaction|recap|behind the scenes|bande[\s-]?annonce|fragman|spoiler|explained|ending explained/i.test(
      String(t || ''),
    );
  }

  function scoreHit(hit, meta) {
    var title = normalizeTitle(hit.title);
    var want = normalizeTitle(meta.title);
    if (!title || !want) return 0;
    var score = 0;
    if (title === want || title.indexOf(want) >= 0 || want.indexOf(title) >= 0) score += 40;
    var tokens = titleTokens(meta.title);
    var matched = 0;
    for (var i = 0; i < tokens.length; i++) {
      if (title.indexOf(tokens[i]) >= 0) matched++;
    }
    if (tokens.length) score += Math.round((matched / tokens.length) * 30);
    if (meta.year && title.indexOf(String(meta.year)) >= 0) score += 15;
    var dur = parseInt(hit.duration, 10) || 0;
    if (!isMovie) {
      var epPat = new RegExp(
        '(?:s\\s*0*' +
          season +
          '\\s*e\\s*0*' +
          episode +
          '|season\\s*0*' +
          season +
          '.*?episode\\s*0*' +
          episode +
          '|episode\\s*0*' +
          episode +
          '|ep\\.?\\s*0*' +
          episode +
          '|0*' +
          season +
          'x0*' +
          episode +
          ')',
        'i',
      );
      if (epPat.test(hit.title || '')) score += 35;
      // Wrong episode number in title → strong penalty.
      var otherEp = (hit.title || '').match(/episode\s*0*(\d+)/i);
      if (otherEp && parseInt(otherEp[1], 10) !== episode) score -= 20;
      if (dur >= 20 * 60) score += 20;
      if (dur >= 40 * 60) score += 10;
      if (dur > 0 && dur < 8 * 60) score -= 30;
    } else {
      if (dur >= 50 * 60) score += 25;
      if (dur >= 80 * 60) score += 10;
      if (dur > 0 && dur < 20 * 60) score -= 40;
    }
    if (isJunkTitle(hit.title)) score -= 55;
    if (/full\s*(movie|film|episode)|watch\s+online|eng(?:lish)?\s*sub/i.test(hit.title || '')) {
      score += 8;
    }
    var views = parseInt(hit.views_total, 10) || 0;
    if (views > 1000) score += 3;
    return score;
  }

  function tmdbKind() {
    // anime/drama/tv all use TMDB tv when not movie.
    return isMovie ? 'movie' : 'tv';
  }

  function tmdbMeta() {
    var seeded = {
      title: String(ctx.title || '').trim(),
      year: parseInt(ctx.year, 10) || 0,
    };
    if (!tmdbKey) return Promise.resolve(seeded);
    return getJson(
      'https://api.themoviedb.org/3/' +
        tmdbKind() +
        '/' +
        encodeURIComponent(tmdbId) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
    )
      .then(function (d) {
        var title = isMovie
          ? d.title || d.original_title
          : d.name || d.original_name;
        var date = isMovie ? d.release_date : d.first_air_date;
        var year = date ? parseInt(String(date).slice(0, 4), 10) : 0;
        return {
          title: String(title || seeded.title || '').trim(),
          year: year || seeded.year || 0,
        };
      })
      .catch(function () {
        return seeded;
      });
  }

  function searchQueries(meta) {
    var q = [];
    var base = meta.title;
    if (!base) return q;
    if (!isMovie) {
      q.push(base + ' S' + pad2(season) + 'E' + pad2(episode));
      q.push(base + ' episode ' + episode);
      q.push(base + ' season ' + season + ' episode ' + episode);
      q.push(base + ' ' + season + 'x' + pad2(episode));
    } else {
      if (meta.year) q.push(base + ' ' + meta.year + ' full movie');
      q.push(base + ' full movie');
      if (meta.year) q.push(base + ' ' + meta.year);
      q.push(base);
    }
    return q;
  }

  function searchOnce(query) {
    var url =
      api +
      '/videos?search=' +
      encodeURIComponent(query) +
      '&fields=id,title,url,duration,views_total,language,channel' +
      '&limit=' +
      searchLimit +
      '&sort=relevance&password_protected=false&private=false';
    return getJson(url)
      .then(function (d) {
        return (d && d.list) || [];
      })
      .catch(function () {
        return [];
      });
  }

  function qualityLabel(key) {
    var k = String(key || '').replace(/@\d+/g, '');
    if (!k || k.toLowerCase() === 'auto') return 'Auto';
    if (/^\d+$/.test(k)) return k + 'p';
    return k;
  }

  function resolveRelative(line, baseUrl) {
    if (!line) return '';
    if (/^https?:\/\//i.test(line)) return line;
    if (line.indexOf('//') === 0) return 'https:' + line;
    try {
      return new URL(line, baseUrl).toString();
    } catch (e) {
      return line;
    }
  }

  function playHeaders() {
    return { 'User-Agent': ua, Referer: origin + '/' };
  }

  function expandMaster(masterUrl, label) {
    return chromeFetch(masterUrl, {
      headers: {
        'User-Agent': ua,
        Accept: 'application/vnd.apple.mpegurl,*/*',
        Referer: origin + '/',
        Origin: origin,
      },
    })
      .then(function (r) {
        if (!r || !r.ok) return [];
        return r.text().then(function (text) {
          var lines = String(text || '').split('\n');
          var out = [];
          var info = null;
          var seen = {};
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            if (line.indexOf('#EXT-X-STREAM-INF:') === 0) {
              info = {};
              var name = line.match(/NAME="([^"]+)"/i);
              var res = line.match(/RESOLUTION=(\d+)x(\d+)/i);
              if (name) info.quality = qualityLabel(name[1]);
              else if (res) info.quality = qualityLabel(res[2]);
              else info.quality = 'Auto';
            } else if (line.charAt(0) !== '#') {
              var abs = resolveRelative(line, masterUrl);
              if (abs && !seen[abs] && !/cdndirector\.dailymotion\.com/i.test(abs)) {
                seen[abs] = 1;
                out.push({
                  url: abs,
                  name: label,
                  quality: (info && info.quality) || 'Auto',
                  headers: playHeaders(),
                });
              }
              info = null;
            }
          }
          return out;
        });
      })
      .catch(function () {
        return [];
      });
  }

  function streamsFromMeta(meta, label) {
    if (!meta || meta.error) return Promise.resolve([]);
    var qualities = meta.qualities || {};
    var masters = [];
    var direct = [];
    var seen = {};
    var keys = Object.keys(qualities);
    for (var i = 0; i < keys.length; i++) {
      var list = qualities[keys[i]] || [];
      for (var j = 0; j < list.length; j++) {
        var m = list[j] || {};
        if (!m.url || m.type === 'application/vnd.lumberjack.manifest') continue;
        if (m.type === 'video/mp4' || /\.mp4(\?|$)/i.test(m.url)) {
          if (!seen[m.url]) {
            seen[m.url] = 1;
            direct.push({
              url: m.url,
              name: label,
              quality: qualityLabel(keys[i]),
              headers: playHeaders(),
            });
          }
        } else if (
          m.type === 'application/x-mpegURL' ||
          /\.m3u8(\?|$)/i.test(m.url)
        ) {
          if (/cdndirector\.dailymotion\.com/i.test(m.url)) {
            if (!seen[m.url]) {
              seen[m.url] = 1;
              masters.push(m.url);
            }
          } else if (!seen[m.url]) {
            seen[m.url] = 1;
            direct.push({
              url: m.url,
              name: label,
              quality: qualityLabel(keys[i] === 'auto' ? 'Auto' : keys[i]),
              headers: playHeaders(),
            });
          }
        }
      }
    }
    if (!masters.length) return Promise.resolve(direct);
    return Promise.all(
      masters.map(function (mu) {
        return expandMaster(mu, label);
      }),
    ).then(function (chunks) {
      var out = direct.slice();
      var seenUrl = {};
      for (var d = 0; d < out.length; d++) seenUrl[out[d].url] = 1;
      for (var c = 0; c < chunks.length; c++) {
        var rows = chunks[c] || [];
        for (var r = 0; r < rows.length; r++) {
          if (!rows[r] || !rows[r].url || seenUrl[rows[r].url]) continue;
          seenUrl[rows[r].url] = 1;
          out.push(rows[r]);
        }
      }
      out.sort(function (a, b) {
        var pa = parseInt(String(a.quality || '').replace(/\D/g, ''), 10) || 0;
        var pb = parseInt(String(b.quality || '').replace(/\D/g, ''), 10) || 0;
        return pb - pa;
      });
      return out;
    });
  }

  function resolveHit(hit) {
    var id = hit.id;
    var label = 'Dailymotion · ' + String(hit.title || id || '').slice(0, 48);
    var metaUrl =
      origin +
      '/player/metadata/video/' +
      encodeURIComponent(id) +
      '?app=com.dailymotion.neon';
    // Resolve in-process with chromeFetch (do not depend on hop being cached/enabled).
    return chromeFetch(metaUrl, {
      headers: {
        'User-Agent': ua,
        Accept: 'application/json',
        Referer: origin + '/',
        Cookie: 'family_filter=off; ff=off',
      },
    })
      .then(function (r) {
        if (!r || !r.ok) throw new Error('meta ' + (r && r.status));
        return r.json();
      })
      .then(function (meta) {
        return streamsFromMeta(meta, label);
      })
      .catch(function () {
        // Fallback: hop path (same chrome expand inside hop script).
        var videoUrl = hit.url || origin + '/video/' + id;
        if (typeof ctx.hop !== 'function') return [];
        return ctx.hop(videoUrl).then(function (rows) {
          return (rows || [])
            .filter(function (row) {
              return row && row.url && !/cdndirector\.dailymotion\.com/i.test(row.url);
            })
            .map(function (row) {
              return {
                url: row.url,
                name: label,
                quality: row.quality || 'Auto',
                headers: row.headers || playHeaders(),
                subtitles: row.subtitles,
              };
            });
        });
      });
  }

  return tmdbMeta()
    .then(function (meta) {
      if (!meta.title) {
        log('no title for tmdb=' + tmdbId);
        return [];
      }
      log('search "' + meta.title + '" type=' + mediaType + ' S' + season + 'E' + episode);
      return Promise.all(searchQueries(meta).map(searchOnce)).then(function (lists) {
        var byId = {};
        var hitCount = 0;
        for (var i = 0; i < lists.length; i++) {
          var list = lists[i] || [];
          hitCount += list.length;
          for (var j = 0; j < list.length; j++) {
            var hit = list[j];
            if (!hit || !hit.id) continue;
            var sc = scoreHit(hit, meta);
            if (!byId[hit.id] || byId[hit.id].score < sc) {
              byId[hit.id] = { hit: hit, score: sc };
            }
          }
        }
        var ranked = Object.keys(byId)
          .map(function (id) {
            return byId[id];
          })
          .sort(function (a, b) {
            return b.score - a.score;
          });
        var picked = ranked.filter(function (x) {
          return x.score >= minScore;
        });
        // If nothing clears the bar, still try the best long-form hit.
        if (!picked.length && ranked.length) {
          var best = ranked[0];
          var dur = parseInt(best.hit.duration, 10) || 0;
          if (best.score >= 15 && dur >= (isMovie ? 40 * 60 : 15 * 60)) {
            picked = [best];
          }
        }
        picked = picked.slice(0, maxResolve);
        log(
          'hits=' +
            hitCount +
            ' unique=' +
            ranked.length +
            ' picked=' +
            picked.length +
            (picked[0] ? ' top=' + picked[0].score + ' "' + String(picked[0].hit.title || '').slice(0, 40) + '"' : ''),
        );
        if (!picked.length) return [];

        return Promise.all(
          picked.map(function (row) {
            return resolveHit(row.hit);
          }),
        ).then(function (chunks) {
          var out = [];
          var seen = {};
          for (var c = 0; c < chunks.length; c++) {
            var rows = chunks[c] || [];
            for (var r = 0; r < rows.length; r++) {
              var s = rows[r];
              if (!s || !s.url || seen[s.url]) continue;
              seen[s.url] = 1;
              out.push(s);
            }
          }
          log('streams=' + out.length);
          return out;
        });
      });
    })
    .catch(function (e) {
      log('extract failed: ' + (e && e.message ? e.message : e));
      return [];
    });
}
