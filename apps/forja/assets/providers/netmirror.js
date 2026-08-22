function extract(ctx) {
  var cfg = ctx.config || {};
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var domains = cfg.domains || [
    'aHR0cHM6Ly9tb2JpbGVkZXRlY3RzLmNvbQ==',
    'aHR0cHM6Ly9tb2JpbGVkZXRlY3QuYXBw',
    'aHR0cHM6Ly9tb2JpZGV0ZWN0LmNsaWNr',
    'aHR0cHM6Ly9tb2JpZGV0ZWN0LnNpdGU=',
  ];
  var platforms = cfg.platforms || ['netflix', 'primevideo', 'hotstar', 'disney'];
  var platformMap = {
    netflix: 'nf',
    primevideo: 'pv',
    hotstar: 'hs',
    disney: 'hs',
  };
  var baseHeaders = {
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    Pragma: 'no-cache',
    Expires: '0',
    'X-Requested-With': 'NetmirrorNewTV v1.0',
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0 /OS.GatuNewTV v1.0',
    Accept: 'application/json, text/plain, */*',
  };

  function safeAtob(encoded) {
    return ctx.crypto.enc.Utf8.stringify(ctx.crypto.enc.Base64.parse(encoded));
  }

  function getJson(url, headers) {
    return ctx.fetch(url, { headers: headers }).then(function (r) {
      return r.json();
    });
  }

  function buildHeaders(ott, extra) {
    return Object.assign({}, baseHeaders, { Ott: ott }, extra || {});
  }

  function resolveApiUrl() {
    var chain = Promise.resolve('');
    domains.forEach(function (encoded) {
      chain = chain.then(function (resolved) {
        if (resolved) return resolved;
        var base = safeAtob(encoded).replace(/\/$/, '');
        return getJson(base + '/checknewtv.php', Object.assign({}, baseHeaders, {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }))
          .then(function (data) {
            return data && data.token_hash ? safeAtob(data.token_hash).replace(/\/$/, '') : '';
          })
          .catch(function () {
            return '';
          });
      });
    });
    return chain;
  }

  function tmdbTitle() {
    var kind = ctx.type === 'movie' ? 'movie' : 'tv';
    return getJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
      {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Accept: 'application/json',
      },
    ).then(function (d) {
      return ctx.type === 'movie' ? d.title : d.name;
    });
  }

  function fetchEpisodesPage(apiBase, ott, seasonId, page, seasonNumber) {
    var out = [];
    function walk(pg) {
      return getJson(
        apiBase + '/newtv/episodes.php?id=' + encodeURIComponent(seasonId) + '&page=' + encodeURIComponent(String(pg)),
        buildHeaders(ott),
      ).then(function (data) {
        (data.episodes || []).filter(Boolean).forEach(function (ep) {
          out.push({
            id: ep.id,
            s: seasonNumber || (ep.sNum ? parseInt(String(ep.sNum).replace('S', ''), 10) : null),
            ep: ep.ep ? parseInt(ep.ep, 10) : ep.epNum ? parseInt(String(ep.epNum).replace('E', ''), 10) : null,
          });
        });
        if (data.nextPageShow === 1) return walk(pg + 1);
        return out;
      });
    }
    return walk(page);
  }

  function getAllEpisodes(apiBase, ott, contentId, postData) {
    var episodes = [];
    var selectedSeasonIdx = postData.season ? postData.season.findIndex(function (s) { return s.selected === true; }) : -1;
    var selectedSeasonId = selectedSeasonIdx >= 0 ? postData.season[selectedSeasonIdx].id : postData.nextPageSeason;
    var selectedSeasonNumber = selectedSeasonIdx >= 0 ? selectedSeasonIdx + 1 : null;
    (postData.episodes || []).filter(Boolean).forEach(function (ep) {
      episodes.push({
        id: ep.id,
        s: selectedSeasonNumber || (ep.sNum ? parseInt(String(ep.sNum).replace('S', ''), 10) : null),
        ep: ep.ep ? parseInt(ep.ep, 10) : ep.epNum ? parseInt(String(ep.epNum).replace('E', ''), 10) : null,
      });
    });
    var tasks = [];
    if (postData.nextPageShow === 1 && selectedSeasonId) {
      tasks.push(fetchEpisodesPage(apiBase, ott, selectedSeasonId, 2, selectedSeasonNumber));
    }
    (postData.season || []).forEach(function (season, index) {
      if (season.id !== selectedSeasonId && season.id) {
        tasks.push(fetchEpisodesPage(apiBase, ott, season.id, 1, index + 1));
      }
    });
    return Promise.all(tasks).then(function (groups) {
      groups.forEach(function (list) {
        episodes.push.apply(episodes, list || []);
      });
      return episodes;
    });
  }

  function fetchFromPlatform(apiBase, platformKey, title) {
    var ott = platformMap[platformKey];
    return getJson(
      apiBase + '/newtv/search.php?s=' + encodeURIComponent(title),
      buildHeaders(ott),
    ).then(function (searchData) {
      if (!searchData.searchResult || !searchData.searchResult.length) return [];
      var contentId = searchData.searchResult[0].id;
      return getJson(
        apiBase + '/newtv/post.php?id=' + encodeURIComponent(String(contentId)),
        buildHeaders(ott, { Lastep: '', Usertoken: '' }),
      ).then(function (postData) {
        var targetId = contentId;
        if (ctx.type !== 'movie') {
          return getAllEpisodes(apiBase, ott, contentId, postData).then(function (episodes) {
            var hit = episodes.filter(function (ep) {
              return ep && ep.s === (ctx.season || 1) && ep.ep === (ctx.episode || 1);
            })[0];
            if (!hit) return [];
            targetId = hit.id;
            return getJson(
              apiBase + '/newtv/player.php?id=' + encodeURIComponent(String(targetId)),
              buildHeaders(ott, { Usertoken: '' }),
            );
          });
        }
        var isSeries = postData.type === 't' || ((postData.episodes || []).filter(Boolean).length > 0);
        if (isSeries) return [];
        targetId = postData.main_id || contentId;
        return getJson(
          apiBase + '/newtv/player.php?id=' + encodeURIComponent(String(targetId)),
          buildHeaders(ott, { Usertoken: '' }),
        );
      }).then(function (response) {
        if (!response || response.status !== 'ok' || !response.video_link) return [];
        return [
          {
            url: response.video_link,
            name: 'NetMirror (' + platformKey + ')',
            quality: 'Auto',
            headers: { Referer: response.referer || apiBase },
          },
        ];
      });
    }).catch(function () {
      return [];
    });
  }

  return Promise.all([resolveApiUrl(), tmdbTitle()])
    .then(function (pair) {
      var apiBase = pair[0];
      var title = pair[1];
      if (!apiBase || !title) return [];
      var chain = Promise.resolve([]);
      platforms.forEach(function (platformKey) {
        chain = chain.then(function (rows) {
          if (rows.length) return rows;
          return fetchFromPlatform(apiBase, platformKey, title);
        });
      });
      return chain;
    })
    .catch(function () {
      return [];
    });
}
