var SPECS = {
  "api": "https://streamdata.vaplayer.ru/api.php",
  "origin": "https://nextgencloudfabric.com"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var api = String(cfg.api).trim();
  var origin = cfg.origin;
  var ua =
    cfg.ua ||
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Origin: origin,
    Referer: String(origin).replace(/\/?$/, '/'),
  };
  var tmdbId = String(ctx.tmdbId || '').trim();
  if (!tmdbId) return Promise.resolve([]);
  var isMovie = ctx.type === 'movie';
  var mediaType = isMovie ? 'movie' : 'tv';
  if (!isMovie && (!ctx.season || !ctx.episode)) return Promise.resolve([]);

  function qualityFromName(fileName) {
    var n = String(fileName || '').toLowerCase();
    if (n.indexOf('2160p') >= 0 || n.indexOf('4k') >= 0) return '4K';
    if (n.indexOf('1080p') >= 0) return '1080p';
    if (n.indexOf('720p') >= 0) return '720p';
    return '1080p';
  }

  function languageFromName(fileName) {
    var n = String(fileName || '').toLowerCase();
    if (n.indexOf('dual') >= 0 || (n.indexOf('hindi') >= 0 && n.indexOf('english') >= 0)) {
      return 'English • Hindi';
    }
    if (n.indexOf('multi') >= 0) return 'Multi';
    if (n.indexOf('hindi') >= 0) return 'Hindi';
    if (n.indexOf('english') >= 0) return 'English';
    return '';
  }

  function okStatus(j) {
    var code = j && j.status_code;
    return code == 200 || code === '200';
  }

  var url = api + (api.indexOf('?') >= 0 ? '&' : '?') + 'tmdb=' + encodeURIComponent(tmdbId) + '&type=' + mediaType;
  if (!isMovie) {
    url += '&season=' + encodeURIComponent(String(ctx.season)) + '&episode=' + encodeURIComponent(String(ctx.episode));
  }

  return ctx
    .fetch(url, { headers: headers })
    .then(function (r) {
      return r.json();
    })
    .then(function (j) {
      if (!okStatus(j) || !j.data || !Array.isArray(j.data.stream_urls)) return [];
      var fileName = String(j.data.file_name || '');
      var quality = qualityFromName(fileName);
      var language = languageFromName(fileName);
      var subs = [];
      if (Array.isArray(j.default_subs)) {
        j.default_subs.forEach(function (s) {
          if (!s || !s.url) return;
          subs.push({
            id: String(s.code || s.lang || ''),
            url: String(s.url),
            lang: String(s.lang || s.code || ''),
          });
        });
      }
      return j.data.stream_urls
        .map(function (streamUrl, i) {
          if (!streamUrl) return null;
          var row = {
            url: String(streamUrl),
            name: 'Server ' + (i + 1),
            quality: quality,
            language: language,
            headers: headers,
          };
          if (subs.length) row.subtitles = subs;
          return row;
        })
        .filter(Boolean);
    })
    .catch(function () {
      return [];
    });
}
