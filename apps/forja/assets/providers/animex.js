function extract(ctx) {
  var cfg = ctx.config || {};
  var gql = cfg.gql || 'https://graphql.animex.one/graphql';
  var rest = (cfg.rest || 'https://pp.animex.one/rest/api').replace(/\/$/, '');
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Accept: 'application/json' };
  var blocked = { yuki: 1, sora: 1 };
  var priority = ['uwu', 'kiwi', 'miku', 'beep', 'mimi', 'mochi', 'vee', 'neko', 'shiro'];
  var title = String(ctx.title || '');
  var episode = ctx.type === 'movie' ? 1 : ctx.episode || 1;
  var season = ctx.type === 'movie' ? 1 : ctx.season || 1;

  function getJson(url) {
    return ctx.fetch(url, { headers: headers }).then(function (r) {
      return r.json();
    });
  }

  function gqlQuery(query, variables) {
    return ctx
      .fetch(gql, {
        method: 'POST',
        headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
        body: JSON.stringify({ query: query, variables: variables || {} }),
      })
      .then(function (r) {
        return r.json();
      })
      .then(function (j) {
        return j && j.data;
      });
  }

  function restGet(path, params) {
    var qs = Object.keys(params)
      .map(function (k) {
        return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]);
      })
      .join('&');
    return getJson(rest + path + '?' + qs);
  }

  function xorShiro(rawUrl) {
    var last = String(rawUrl).split('/').pop() || '';
    if (last.length < 8 || last.length % 2 || !/^[0-9a-f]+$/i.test(last)) return rawUrl;
    var decoded = '';
    for (var i = 0; i < last.length; i += 2) {
      decoded += String.fromCharCode(parseInt(last.substring(i, i + 2), 16) ^ 137);
    }
    return decoded.indexOf('http') === 0 ? decoded + '&origin=https://kem.clvd.xyz/' : rawUrl;
  }

  function resolveMal() {
    var imdb = String(ctx.imdbId || '');
    function fromJikan() {
      if (!title) return Promise.resolve(null);
      return getJson(jikan + '?q=' + encodeURIComponent(title) + '&limit=1')
        .then(function (d) {
          return d && d.data && d.data[0] ? d.data[0].mal_id : null;
        })
        .catch(function () {
          return null;
        });
    }
    if (!imdb) return fromJikan();
    return getJson(mapApi + '?id=' + encodeURIComponent(imdb) + '&s=' + season + '&e=' + episode)
      .then(function (d) {
        if (d && d.mal_id) return { mal: d.mal_id, ep: d.mal_episode || episode };
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

  function internalFromMal(mal) {
    return gqlQuery(
      'query($malId: Int) { anime(malId: $malId) { id titleEnglish titleRomaji } }',
      { malId: mal },
    ).then(function (d) {
      return d && d.anime && d.anime.id ? d.anime.id : null;
    });
  }

  function internalFromTitle() {
    if (!title) return Promise.resolve(null);
    return gqlQuery(
      'query($query: String!, $limit: Int) { searchAnime(query: $query, limit: $limit) { items { id malId titleEnglish titleRomaji } } }',
      { query: title, limit: 5 },
    ).then(function (d) {
      var items = (d && d.searchAnime && d.searchAnime.items) || [];
      return items[0] ? items[0].id : null;
    });
  }

  function sortProviders(list) {
    return (list || [])
      .filter(function (p) {
        return p && p.id && !blocked[p.id];
      })
      .sort(function (a, b) {
        var ai = priority.indexOf(a.id);
        var bi = priority.indexOf(b.id);
        if (ai < 0 && bi < 0) return 0;
        if (ai < 0) return 1;
        if (bi < 0) return -1;
        return ai - bi;
      })
      .slice(0, 2);
  }

  function sourcesFor(internalId, ep, type, providers) {
    var tasks = sortProviders(providers).map(function (p) {
      return restGet('/sources', {
        id: internalId,
        epNum: String(ep),
        type: type,
        providerId: p.id,
      })
        .then(function (result) {
          var rows = [];
          ((result && result.sources) || []).forEach(function (src) {
            if (!src || !src.url) return;
            var url = p.id === 'shiro' ? xorShiro(src.url) : src.url;
            var hdrs = { 'User-Agent': ua };
            if (result.headers && result.headers.Referer) hdrs.Referer = result.headers.Referer;
            if (result.headers && result.headers.Origin) hdrs.Origin = result.headers.Origin;
            rows.push({
              url: url,
              name: 'AnimeX ' + p.id,
              quality: src.quality || '',
              language: type === 'dub' ? 'Dub' : 'Sub',
              headers: hdrs,
            });
          });
          return rows;
        })
        .catch(function () {
          return [];
        });
    });
    return Promise.all(tasks).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  return resolveMal()
    .then(function (mapped) {
      var mal = mapped && mapped.mal ? mapped.mal : mapped;
      var ep = mapped && mapped.ep ? mapped.ep : episode;
      var idP = mal ? internalFromMal(mal) : Promise.resolve(null);
      return idP.then(function (id) {
        return (id ? Promise.resolve(id) : internalFromTitle()).then(function (internalId) {
          if (!internalId) return [];
          return restGet('/servers', { id: internalId, epNum: String(ep) }).then(function (servers) {
            if (!servers) return [];
            return Promise.all([
              sourcesFor(internalId, ep, 'sub', servers.subProviders),
              sourcesFor(internalId, ep, 'dub', servers.dubProviders),
            ]).then(function (groups) {
              var seen = {};
              var out = [];
              [].concat.apply([], groups).forEach(function (r) {
                if (!r || !r.url || seen[r.url]) return;
                seen[r.url] = true;
                out.push(r);
              });
              return out;
            });
          });
        });
      });
    })
    .catch(function () {
      return [];
    });
}
