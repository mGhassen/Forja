var SPECS = {
  "base": "https://anidb.app",
  "mapApi": "https://id-mapping-api-malid.hf.space/api/resolve",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var mapApi = cfg.mapApi;
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var armBase = (cfg.armBase || 'https://arm.haglund.dev/api/v2').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var navHdrs = {
    'User-Agent': ua,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'same-origin',
  };
  var xhrHdrs = Object.assign({}, navHdrs, {
    Accept: 'application/json, text/html, */*;q=0.8',
    'X-Requested-With': 'XMLHttpRequest',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
  });
  var isTv = ctx.type !== 'movie';
  var epNum = isTv ? ctx.episode || 1 : 1;

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, navHdrs, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, xhrHdrs, extra || {}) }).then(function (r) {
      return r.json();
    });
  }

  function stripTags(html) {
    return String(html || '').replace(/<[^>]+>/g, '').trim();
  }

  function decodeEntities(s) {
    return String(s || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>');
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

  function resolveAnilist(malId) {
    return fetchJson(armBase + '/ids?source=myanimelist&id=' + encodeURIComponent(String(malId))).then(function (d) {
      return d && d.anilist ? d.anilist : null;
    });
  }

  function titleFromMal(malId) {
    return fetchJson(jikan + '/' + malId).then(function (j) {
      var d = j && j.data;
      return (d && (d.title || d.title_english)) || '';
    });
  }

  function search(query) {
    return fetchText(base + '/search/suggestions?q=' + encodeURIComponent(query), { Referer: base + '/home' })
      .then(function (html) {
        var results = [];
        var re = /<a\b[^>]*data-search-item\b[^>]*>[\s\S]*?<\/a>/gi;
        var m;
        while ((m = re.exec(html)) !== null) {
          var tag = (m[0].match(/<a\b[^>]*>/i) || [])[0] || '';
          var hrefM = tag.match(/href=["']([^"']+)["']/i);
          var href = hrefM ? hrefM[1] : '';
          var path = href.indexOf('http') === 0 ? href.replace(/^https?:\/\/[^/]+/, '') : href;
          var slugM = path.match(/^\/anime\/([^/?#]+)/);
          if (!slugM) continue;
          var titleM = m[0].match(/<p\b[^>]*class=["'][^"']*text-sm[^"']*["'][^>]*>([\s\S]*?)<\/p>/i);
          var siteId = Number((slugM[1].match(/-(\d+)$/) || [])[1]);
          results.push({ slug: slugM[1], title: titleM ? stripTags(titleM[1]) : slugM[1], siteId: siteId });
        }
        if (results.length) return results;
        return fetchText(base + '/browse?q=' + encodeURIComponent(query), { Referer: base + '/home' }).then(function (browse) {
          var seen = {};
          var out = [];
          var cardRe =
            /<a\b[^>]*href=["'](?:https:\/\/anidb\.app)?\/anime\/([^"']+)["'][^>]*class=["'][^"']*\banime-card\b[^"']*["'][^>]*>[\s\S]*?<\/a>/gi;
          while ((m = cardRe.exec(browse)) !== null) {
            if (seen[m[1]]) continue;
            seen[m[1]] = true;
            out.push({
              slug: m[1],
              title: stripTags((m[0].match(/title=["']([^"']+)["']/i) || [])[1] || m[1]),
              siteId: Number((m[1].match(/-(\d+)$/) || [])[1]),
            });
          }
          return out;
        });
      })
      .catch(function () {
        return [];
      });
  }

  function parseExternalIds(html) {
    return {
      anilistId: Number((html.match(/https:\/\/anilist\.co\/anime\/(\d+)/i) || [])[1]) || null,
      malId: Number((html.match(/https:\/\/myanimelist\.net\/anime\/(\d+)/i) || [])[1]) || null,
    };
  }

  function resolveSeries(anilistId, malId, title) {
    var queries = [title].filter(Boolean);
    return Promise.all(
      queries.map(function (q) {
        return search(q);
      }),
    ).then(function (groups) {
      var candidates = {};
      groups.forEach(function (list) {
        list.forEach(function (r) {
          if (!candidates[r.slug]) candidates[r.slug] = r;
        });
      });
      var slugs = Object.keys(candidates);
      if (!slugs.length) return null;
      return Promise.all(
        slugs.slice(0, 6).map(function (slug) {
          var c = candidates[slug];
          return fetchText(base + '/anime/' + slug, { Referer: base + '/home' }).then(function (html) {
            var ids = parseExternalIds(html);
            if (anilistId && ids.anilistId === Number(anilistId)) return { slug: slug, siteId: c.siteId, title: c.title };
            if (malId && ids.malId === Number(malId)) return { slug: slug, siteId: c.siteId, title: c.title };
            return null;
          });
        }),
      ).then(function (matches) {
        for (var i = 0; i < matches.length; i++) if (matches[i]) return matches[i];
        return candidates[slugs[0]] || null;
      });
    });
  }

  function inferOffset(episodes) {
    var nums = episodes
      .map(function (e) {
        return Number(e.number);
      })
      .filter(function (n) {
        return n > 0;
      });
    if (!nums.length) return 0;
    var min = Math.min.apply(null, nums);
    return min > 1 ? min - 1 : 0;
  }

  function languageForAudio(languages, audio) {
    var preferred = audio === 'sub' ? ['jpn', 'ja', 'japanese'] : ['eng', 'en', 'english'];
    for (var i = 0; i < languages.length; i++) {
      var code = String(languages[i].code || languages[i].name || '').toLowerCase();
      if (preferred.indexOf(code) >= 0 && languages[i].embed_url) return languages[i];
    }
    return null;
  }

  function extractHls(html) {
    var patterns = [
      /file\s*:\s*["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/i,
      /["'](https?:\/\/[^"']+\/master\.m3u8[^"']*)["']/i,
      /["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/i,
    ];
    for (var i = 0; i < patterns.length; i++) {
      var m = html.match(patterns[i]);
      if (m && m[1]) return decodeEntities(m[1]);
    }
    return null;
  }

  function streamsForEmbed(embedUrl, audio) {
    return fetchText(embedUrl, { Referer: base + '/' }).then(function (html) {
      var hls = extractHls(html);
      if (hls) {
        return [
          {
            url: hls,
            name: 'AniDB.app',
            headers: { 'User-Agent': ua, Referer: new URL(embedUrl).origin + '/' },
            language: audio === 'dub' ? 'Dub' : 'Sub',
          },
        ];
      }
      return ctx.hop(embedUrl).then(function (rows) {
        return rows.map(function (r) {
          return Object.assign({}, r, { name: 'AniDB.app embed', language: audio === 'dub' ? 'Dub' : 'Sub' });
        });
      });
    });
  }

  return resolveMal()
    .then(function (mapped) {
      if (!mapped) return [];
      var malId = mapped.mal;
      var episode = mapped.ep;
      return resolveAnilist(malId)
        .then(function (alId) {
          return titleFromMal(malId).then(function (title) {
            return resolveSeries(alId, malId, title);
          });
        })
        .then(function (series) {
          if (!series || !series.siteId) return [];
          return fetchJson(base + '/api/frontend/anime/' + series.siteId + '/episodes', {
            Referer: base + '/anime/' + series.slug,
          }).then(function (data) {
            var episodes = (data && data.episodes) || [];
            var offset = inferOffset(episodes);
            var providerEp = Number(episode) + offset;
            var ep = episodes.find(function (e) {
              return Number(e.number) === providerEp;
            });
            if (!ep || !ep.id) return [];
            return fetchJson(base + '/api/frontend/episode/' + ep.id + '/languages', {
              Referer: base + '/anime/' + series.slug,
            }).then(function (langData) {
              var languages = (langData && langData.languages) || [];
              var subLang = languageForAudio(languages, 'sub');
              var embed = subLang && subLang.embed_url ? decodeEntities(subLang.embed_url) : '';
              if (!embed) {
                var dubLangOnly = languageForAudio(languages, 'dub');
                embed = dubLangOnly && dubLangOnly.embed_url ? decodeEntities(dubLangOnly.embed_url) : '';
                if (!embed) return [];
                return streamsForEmbed(embed, 'dub');
              }
              return streamsForEmbed(embed, 'sub').then(function (sub) {
                if (sub.length) return sub;
                var dubLang = languageForAudio(languages, 'dub');
                if (!dubLang || !dubLang.embed_url) return [];
                return streamsForEmbed(decodeEntities(dubLang.embed_url), 'dub');
              });
            });
          });
        });
    })
    .then(function (rows) {
      return rows && rows.length ? rows : [];
    })
    .catch(function () {
      return [];
    });
}
