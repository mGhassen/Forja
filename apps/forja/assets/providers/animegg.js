function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://www.animegg.org').replace(/\/$/, '');
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Accept: 'text/html,application/xhtml+xml' };
  var isTv = ctx.type === 'tv';

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

  function search(query) {
    return fetchText(base + '/search/?q=' + encodeURIComponent(query)).then(function (html) {
      var results = [];
      var re = /<a\b[^>]*class=["'][^"']*\bmse\b[^"']*["'][^>]*>[\s\S]*?<\/a>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var tag = (m[0].match(/<a\b[^>]*>/i) || [])[0] || '';
        var hrefM = tag.match(/href=["']([^"']+)["']/i);
        var href = hrefM ? hrefM[1] : '';
        var slugM = href.match(/^\/series\/([^/?#]+)/);
        if (!slugM) continue;
        var strongM = m[0].match(/<strong[^>]*>([\s\S]*?)<\/strong>/i);
        var text = strongM ? strongM[1].replace(/<[^>]+>/g, '').trim() : slugM[1].replace(/-/g, ' ');
        results.push({ slug: slugM[1], text: text });
      }
      return results;
    });
  }

  function pickSlug(results, query) {
    if (!results.length) return null;
    var target = normalize(query);
    for (var i = 0; i < results.length; i++) {
      if (normalize(results[i].text) === target || normalize(results[i].text).indexOf(target) >= 0) return results[i].slug;
    }
    return results[0].slug;
  }

  function scrapeSeries(slug) {
    return fetchText(base + '/series/' + slug).then(function (html) {
      var episodes = [];
      var re = /<li\b[^>]*>([\s\S]*?)<\/li>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var block = m[1];
        if (block.indexOf('anm_det_pop') < 0) continue;
        var linkM = block.match(/<a\b[^>]*class=["'][^"']*anm_det_pop[^"']*["'][^>]*href=["']([^"']+)["']/i);
        if (!linkM) continue;
        var href = linkM[1].replace(/#.*$/, '').replace(/^\//, '');
        var strongM = block.match(/<strong[^>]*>([\s\S]*?)<\/strong>/i);
        var strong = strongM ? strongM[1].replace(/<[^>]+>/g, '').trim() : '';
        var rangeMatch = strong.match(/(\d+)-(\d+)\s*$/);
        var numMatch = rangeMatch || strong.match(/(\d+)\s*$/);
        if (!numMatch) continue;
        var number = parseInt(numMatch[1], 10);
        episodes.push({
          number: number,
          epSlug: href,
          hasSub: /\bbtn-subbed\b/.test(block),
          hasDub: /\bbtn-dubbed\b/.test(block),
        });
      }
      return episodes;
    });
  }

  function scrapeEmbed(embedId) {
    return fetchText(base + '/embed/' + embedId, { Referer: base }).then(function (html) {
      var m = html.match(/var\s+videoSources\s*=\s*(\[[\s\S]*?\]);/);
      if (!m) return [];
      try {
        var asJson = m[1]
          .replace(/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g, '$1"$2":')
          .replace(/:\s*'([^']*)'/g, ': "$1"');
        var parsed = JSON.parse(asJson);
        return parsed
          .map(function (s) {
            var url = s.file ? (s.file.indexOf('http') === 0 ? s.file : base + s.file) : '';
            return url ? { url: url, quality: s.label || 'unknown' } : null;
          })
          .filter(Boolean);
      } catch (e) {
        return [];
      }
    });
  }

  function scrapeEpisodeWatch(epSlug, audio) {
    return fetchText(base + '/' + epSlug, { Referer: base }).then(function (html) {
      var tabs = [];
      var re = /<a\b[^>]*data-toggle=["']tab["'][^>]*>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var tag = m[0];
        var embedIdM = tag.match(/data-id=["']([^"']+)["']/i);
        var versionM = tag.match(/data-version=["']([^"']+)["']/i);
        if (!embedIdM) continue;
        var normalized = (versionM ? versionM[1] : 'subbed').indexOf('dub') === 0 ? 'dub' : 'sub';
        if (normalized === audio) tabs.push(embedIdM[1]);
      }
      if (!tabs.length) {
        var allRe = /data-id=["']([^"']+)["']/gi;
        var am;
        while ((am = allRe.exec(html)) !== null) tabs.push(am[1]);
      }
      return Promise.all(
        tabs.slice(0, 3).map(function (embedId) {
          return scrapeEmbed(embedId).then(function (sources) {
            return sources.map(function (s) {
              return {
                url: s.url,
                name: 'AnimeGG ' + s.quality,
                headers: hdrs,
                quality: s.quality,
                language: audio === 'dub' ? 'Dub' : 'Sub',
              };
            });
          });
        }),
      ).then(function (groups) {
        return [].concat.apply([], groups);
      });
    });
  }

  return titleAndMapping()
    .then(function (state) {
      var query = (state.title || String(ctx.title || '')).split(':')[0].trim();
      if (!query) return [];
      return search(query).then(function (results) {
        var slug = pickSlug(results, query);
        if (!slug) return [];
        return scrapeSeries(slug).then(function (episodes) {
          var ep = episodes.find(function (e) {
            return e.number === state.mappedEp;
          });
          if (!ep) return [];
          return scrapeEpisodeWatch(ep.epSlug, 'sub').then(function (sub) {
            if (sub.length) return sub;
            return scrapeEpisodeWatch(ep.epSlug, 'dub');
          });
        });
      });
    })
    .then(function (rows) {
      return rows && rows.length ? rows : ctx.host('animegg');
    })
    .catch(function () {
      return ctx.host('animegg');
    });
}
