function extract(ctx) {
  var API = 'https://panel.watchkaroabhi.com';
  var KEY = 'qNhKLJiZVyoKdi9NCQGz8CIGrpUijujE';
  var REF = 'https://molop.art/';
  var apiHeaders = {
    'X-Package-Name': 'com.king.moja',
    'User-Agent': 'dooflix',
    'X-App-Version': '305',
  };
  var playHeaders = { Referer: REF, 'User-Agent': 'dooflix' };
  var isMovie = ctx.type === 'movie';
  var tmdbId = String(ctx.tmdbId);
  var listUrl = isMovie
    ? API + '/api/3/movie/' + tmdbId + '/links?api_key=' + KEY
    : API +
      '/api/3/tv/' +
      tmdbId +
      '/season/' +
      (ctx.season || 1) +
      '/episode/' +
      (ctx.episode || 1) +
      '/links?api_key=' +
      KEY;

  if (!isMovie && (!ctx.season || !ctx.episode)) return Promise.resolve([]);

  return ctx
    .fetch(listUrl, { headers: apiHeaders })
    .then(function (r) {
      return r.json();
    })
    .then(function (data) {
      var links = (data && data.links) || [];
      return Promise.all(
        links.map(function (linkObj) {
          var url = linkObj && linkObj.url;
          if (!url) return null;
          return ctx
            .fetch(url, { headers: playHeaders })
            .then(function (res) {
              var loc = res.headers.get('location');
              var finalUrl = loc || res.url;
              if (!finalUrl || finalUrl === url) return null;
              return {
                url: finalUrl,
                title: 'DooFlix · ' + (linkObj.host || 'Server'),
                headers: playHeaders,
              };
            })
            .catch(function () {
              return null;
            });
        }),
      );
    })
    .then(function (rows) {
      var out = [];
      for (var i = 0; i < rows.length; i++) {
        if (rows[i]) out.push(rows[i]);
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}
