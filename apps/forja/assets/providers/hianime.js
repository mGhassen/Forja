function extract(ctx) {
  var cfg = ctx.config || {};
  var megaplay = cfg.megaplay || 'https://megaplay.buzz';
  var vidwish = cfg.vidwish || 'https://vidwish.live';
  var megacloud = cfg.megacloud || 'https://megacloud.bloggy.click';
  var tmdbKey = cfg.tmdbKey || '';
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Accept: '*/*' };
  var tmdbId = String(ctx.tmdbId);
  var mediaType = ctx.type === 'movie' ? 'movie' : 'tv';
  var episode = ctx.type === 'movie' ? 1 : ctx.episode || 1;
  var season = ctx.type === 'movie' ? 1 : ctx.season || 1;

  function getJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.json();
    });
  }

  function getText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function playerId(html) {
    var $ = ctx.html ? ctx.html(html) : null;
    if ($) {
      var el = $('#megaplay-player');
      if (el && el.length) {
        return { id: el.attr('data-id') || '', real: el.attr('data-realid') || '' };
      }
    }
    return {
      id: (html.match(/id=["']megaplay-player["'][^>]*data-id=["']([^"']+)/) ||
        html.match(/data-id=["']([^"']+)["'][^>]*id=["']megaplay-player/) ||
        [])[1] || '',
      real: (html.match(/data-realid=["']([^"']+)/) || [])[1] || '',
    };
  }

  function extractSources(apiUrl, referer, origin, name, kind) {
    return getJson(apiUrl, {
      'X-Requested-With': 'XMLHttpRequest',
      Referer: referer,
      Origin: origin,
    })
      .then(function (json) {
        var file = json && json.sources && json.sources.file;
        if (!file) return [];
        return [
          {
            url: file,
            name: 'HiAnime [' + name + '] (' + kind.toUpperCase() + ')',
            headers: { 'User-Agent': ua, Referer: origin + '/', Origin: origin },
          },
        ];
      })
      .catch(function () {
        return [];
      });
  }

  function scrapeType(malId, ep, kind) {
    var megaUrl = megaplay + '/stream/mal/' + malId + '/' + ep + '/' + kind;
    return getText(megaUrl, { Referer: megaUrl })
      .then(function (html) {
        var ids = playerId(html);
        var tasks = [];
        if (ids.id) {
          tasks.push(
            extractSources(
              megaplay + '/stream/getSources?id=' + ids.id + '&id=' + ids.id,
              megaUrl,
              megaplay,
              'MegaPlay',
              kind,
            ),
          );
        }
        if (ids.real) {
          var vidPage = vidwish + '/stream/s-2/' + ids.real + '/' + kind;
          tasks.push(
            getText(vidPage, { Referer: megaUrl }).then(function (vidHtml) {
              var v = playerId(vidHtml);
              if (!v.id) return [];
              return extractSources(
                vidwish + '/stream/getSources?id=' + v.id + '&id=' + v.id,
                vidPage,
                vidwish,
                'Vidwish',
                kind,
              );
            }),
          );
          var mcPage = megacloud + '/stream/s-3/' + ids.real + '/' + kind;
          tasks.push(
            getText(mcPage, { Referer: megaUrl }).then(function (mcHtml) {
              var m = playerId(mcHtml);
              if (!m.id) return [];
              return extractSources(
                megacloud + '/stream/getSources?id=' + m.id + '&id=' + m.id,
                mcPage,
                megacloud,
                'MegaCloud',
                kind,
              );
            }),
          );
        }
        return Promise.all(tasks).then(function (groups) {
          return [].concat.apply([], groups);
        });
      })
      .catch(function () {
        return [];
      });
  }

  function resolveMal() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) {
      return Promise.resolve({ mal: fromHost.mal, ep: fromHost.ep });
    }
    var title = String(ctx.title || '');
    var imdb = String(ctx.imdbId || '');
    function fromJikan() {
      if (!title) return Promise.resolve(null);
      var type = mediaType === 'movie' ? 'movie' : 'tv';
      return getJson(jikan + '?q=' + encodeURIComponent(title) + '&type=' + type + '&limit=1')
        .then(function (data) {
          return data && data.data && data.data[0] ? data.data[0].mal_id : null;
        })
        .catch(function () {
          return null;
        });
    }
    if (mediaType === 'movie') return fromJikan();
    if (!imdb) return fromJikan();
    return getJson(mapApi + '?id=' + encodeURIComponent(imdb) + '&s=' + season + '&e=' + episode)
      .then(function (data) {
        if (data && data.mal_id) {
          return { mal: data.mal_id, ep: data.mal_episode || episode };
        }
        return fromJikan().then(function (mal) {
          return mal ? { mal: mal, ep: episode } : null;
        });
      })
      .catch(function () {
        return fromJikan().then(function (mal) {
          return mal ? { mal: mal, ep: episode } : null;
        });
      });
  }

  function imdbFromTmdb() {
    if (ctx.imdbId) return Promise.resolve(String(ctx.imdbId));
    if (!tmdbKey) return Promise.resolve('');
    var path = mediaType === 'tv' ? 'tv' : 'movie';
    return getJson(
      'https://api.themoviedb.org/3/' + path + '/' + tmdbId + '/external_ids?api_key=' + tmdbKey,
    )
      .then(function (d) {
        return (d && d.imdb_id) || '';
      })
      .catch(function () {
        return '';
      });
  }

  return imdbFromTmdb()
    .then(function (imdb) {
      if (imdb) ctx.imdbId = imdb;
      return resolveMal();
    })
    .then(function (mapped) {
      var mal = mapped && mapped.mal ? mapped.mal : mapped;
      var ep = mapped && mapped.ep ? mapped.ep : episode;
      if (!mal) return ctx.host('hianime');
      return Promise.all([scrapeType(mal, ep, 'sub'), scrapeType(mal, ep, 'dub')]).then(function (
        groups,
      ) {
        var seen = {};
        var out = [];
        ;[].concat.apply([], groups).forEach(function (r) {
          if (!r || !r.url || seen[r.url]) return;
          seen[r.url] = true;
          out.push(r);
        });
        return out.length ? out : ctx.host('hianime');
      });
    })
    .catch(function () {
      return ctx.host('hianime');
    });
}
