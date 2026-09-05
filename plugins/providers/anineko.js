var SPECS = {
  "base": "https://anineko.to",
  "mapApi": "https://id-mapping-api-malid.hf.space/api/resolve",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49",
  "jikan": "https://api.jikan.moe/v4/anime"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var mapApi = cfg.mapApi;
  var jikan = cfg.jikan;
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Accept: 'text/html,application/xhtml+xml' };
  var isTv = ctx.type !== 'movie';

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, { Accept: 'application/json' }) }).then(function (r) {
      return r.json();
    });
  }

  function normalize(str) {
    return String(str || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '')
      .trim();
  }

  function decodeEntities(s) {
    return String(s || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>');
  }

  function titleAndMapping() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) {
      return fetchJson(jikan + '/' + fromHost.malId)
        .then(function (j) {
          return {
            title: (j && j.data && j.data.title) || fromHost.title || ctx.title || '',
            mappedEp: fromHost.mappedEp,
          };
        })
        .catch(function () {
          return {
            title: fromHost.title || ctx.title || '',
            mappedEp: fromHost.mappedEp,
          };
        });
    }
    if (!isTv) {
      return fetchJson(
        'https://api.themoviedb.org/3/movie/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
      ).then(function (d) {
        return { title: d.title || d.original_title || '', mappedEp: 1 };
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
      if (!imdbId) return { title: '', mappedEp: ctx.episode || 1 };
      return fetchJson(
        mapApi +
          '?id=' +
          encodeURIComponent(imdbId) +
          '&s=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&e=' +
          encodeURIComponent(String(ctx.episode || 1)),
      )
        .then(function (mapping) {
          if (!mapping || !mapping.mal_id) return { title: '', mappedEp: ctx.episode || 1 };
          return fetchJson(jikan + '/' + mapping.mal_id).then(function (j) {
            return {
              title: (j && j.data && j.data.title) || '',
              mappedEp: mapping.mal_episode || ctx.episode || 1,
            };
          });
        })
        .catch(function () {
          return { title: '', mappedEp: ctx.episode || 1 };
        });
    });
  }

  function searchSlug(query) {
    return fetchText(base + '/browser?keyword=' + encodeURIComponent(query)).then(function (html) {
      var results = [];
      var re = /<a\b[^>]*class=["'][^"']*nv-anime-thumb[^"']*["'][^>]*>[\s\S]*?<\/a>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var tag = (m[0].match(/<a\b[^>]*>/i) || [])[0] || '';
        var hrefM = tag.match(/href=["']([^"']+)["']/i);
        var href = hrefM ? hrefM[1] : '';
        var slugM = href.match(/\/watch\/([^/?#]+)/);
        if (!slugM) continue;
        var titleM = m[0].match(/<(?:h3|[^>]+class=["'][^"']*nv-anime-title[^"']*["'][^>]*)>([\s\S]*?)<\/(?:h3|[^>]+)>/i);
        var text = titleM ? titleM[1].replace(/<[^>]+>/g, '').trim() : slugM[1].replace(/-/g, ' ');
        results.push({ slug: slugM[1], text: text });
      }
      if (!results.length) return null;
      var target = normalize(query);
      for (var i = 0; i < results.length; i++) {
        if (normalize(results[i].text) === target || normalize(results[i].text).indexOf(target) >= 0) return results[i].slug;
      }
      return results[0].slug;
    });
  }

  function extractHls(embedUrl) {
    return fetchText(embedUrl, { Referer: base + '/' }).then(function (html) {
      var patterns = [
        /const\s+src\s*=\s*["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/i,
        /file\s*:\s*["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/i,
        /["'](https?:\/\/[^"']+\/master\.m3u8[^"']*)["']/i,
        /["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/i,
      ];
      for (var i = 0; i < patterns.length; i++) {
        var m = html.match(patterns[i]);
        if (m) return decodeEntities(m[1]);
      }
      return null;
    });
  }

  function scrapeEpisodeWatch(seriesSlug, epSlug, audio) {
    return fetchText(base + '/watch/' + seriesSlug + '/' + epSlug, { Referer: base + '/watch/' + seriesSlug }).then(
      function (html) {
        var byAudio = { sub: [], dub: [] };
        var panelRe =
          /<div\b[^>]*class=["'][^"']*nv-server-grid[^"']*["'][^>]*data-id=["']([^"']+)["'][^>]*>([\s\S]*?)(?=<div\b[^>]*class=["'][^"']*nv-server-grid|$)/gi;
        var pm;
        while ((pm = panelRe.exec(html)) !== null) {
          var rawAudio = pm[1].toLowerCase();
          var panelAudio = rawAudio.indexOf('dub') >= 0 ? 'dub' : 'sub';
          var btnRe = /data-video=["']([^"']+)["']/gi;
          var bm;
          while ((bm = btnRe.exec(pm[2])) !== null) byAudio[panelAudio].push(decodeEntities(bm[1]));
        }
        var embeds = byAudio[audio] || byAudio.sub || [];
        return Promise.all(
          embeds.slice(0, 4).map(function (embed, idx) {
            return extractHls(embed)
              .then(function (hls) {
                if (hls) {
                  return {
                    url: hls,
                    name: 'AniNeko',
                    headers: { 'User-Agent': ua, Referer: new URL(embed).origin + '/' },
                    language: audio === 'dub' ? 'Dub' : 'Sub',
                  };
                }
                return ctx.hop(embed).then(function (rows) {
                  return rows.map(function (r) {
                    return Object.assign({}, r, { name: 'AniNeko embed', language: audio === 'dub' ? 'Dub' : 'Sub' });
                  });
                });
              })
              .catch(function () {
                return [];
              });
          }),
        ).then(function (groups) {
          return [].concat.apply([], groups);
        });
      },
    );
  }

  return titleAndMapping()
    .then(function (state) {
      var query = state.title || String(ctx.title || '');
      if (!query) return [];
      return searchSlug(query.split(':')[0].trim()).then(function (slug) {
        if (!slug) return [];
        var epSlug = 'ep-' + state.mappedEp;
        var cats =
          (globalThis.__engineAudioCategories &&
            globalThis.__engineAudioCategories(ctx)) ||
          ['sub', 'dub'];
        var first = cats[0] || 'sub';
        return scrapeEpisodeWatch(slug, epSlug, first).then(function (rows) {
          if (rows.length || cats.length < 2) return rows;
          return scrapeEpisodeWatch(slug, epSlug, cats[1]);
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
