function extract(ctx) {
  var cfg = ctx.config || {};
  var api = cfg.api || 'https://api.2embed.cc';
  var embedBase = cfg.embed || 'https://www.2embed.cc';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: embedBase + '/' };
  var tmdbId = String(ctx.tmdbId);
  var mediaType = ctx.type === 'movie' ? 'movie' : 'tv';
  var season = ctx.season || 1;
  var episode = ctx.episode || 1;

  ctx.log('start tmdb=' + tmdbId + ' type=' + mediaType);

  function getText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function getJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.json();
    });
  }

  function parseServers(html) {
    var servers = [];
    var re = /onclick="go\('(https:\/\/streamsrcs\.2embed\.cc\/([^?]+)\?([^']*))'\)"/g;
    var m;
    while ((m = re.exec(html))) {
      var path = m[2];
      var type = '';
      if (path.indexOf('swish') === 0) type = 'swish';
      else if (path.indexOf('xps') === 0) type = 'xps';
      else if (path.indexOf('vesy') === 0) type = 'vesy';
      else if (path.indexOf('vcr') === 0) type = 'vcr';
      else continue;
      servers.push({ url: m[1], type: type });
    }
    var ds = (html.match(/data-src="([^"]+)"/) || [])[1];
    if (ds && !servers.some(function (s) { return s.url === ds; })) {
      var type = 'swish';
      if (ds.indexOf('/xps') >= 0) type = 'xps';
      else if (ds.indexOf('/vesy') >= 0) type = 'vesy';
      else if (ds.indexOf('/vcr') >= 0) type = 'vcr';
      servers.unshift({ url: ds, type: type });
    }
    return servers;
  }

  function param(url, key) {
    var m = String(url).match(new RegExp('[?&]' + key + '=([^&]+)'));
    return m ? decodeURIComponent(m[1]) : '';
  }

  function resolveSrc(server) {
    var content = mediaType === 'tv' ? 'tv' : 'movie';
    if (server.type === 'swish') {
      var hash = param(server.url, 'id') || server.url.split('/').pop();
      return 'https://2vcdn.skin/e/' + hash;
    }
    if (server.type === 'xps') {
      if (mediaType === 'tv') {
        var tmdb = param(server.url, 'tmdb') || tmdbId;
        var s = param(server.url, 's') || season;
        var e = param(server.url, 'e') || episode;
        return 'https://play.xpass.top/e/tv/' + tmdb + '/' + s + '/' + e + '?autostart=true';
      }
      var imdb = param(server.url, 'imdb');
      return 'https://play.xpass.top/e/movie/' + imdb + (imdb ? '?autostart=true' : '');
    }
    if (server.type === 'vesy') {
      return 'https://player.videasy.to/' + content + '/' + (param(server.url, 'tmdb') || tmdbId);
    }
    if (server.type === 'vcr') {
      return (
        'https://vidcore.net/' +
        content +
        '/' +
        (param(server.url, 'tmdb') || tmdbId) +
        (content === 'tv' ? '/' + season + '/' + episode : '') +
        '/'
      );
    }
    return server.url;
  }

  function balanced(html, openIdx) {
    var open = html.charAt(openIdx);
    var close = open === '[' ? ']' : '}';
    var depth = 0;
    var inStr = false;
    var esc = false;
    for (var i = openIdx; i < html.length; i++) {
      var ch = html.charAt(i);
      if (inStr) {
        if (esc) esc = false;
        else if (ch === '\\') esc = true;
        else if (ch === '"') inStr = false;
        continue;
      }
      if (ch === '"') {
        inStr = true;
        continue;
      }
      if (ch === open) depth++;
      else if (ch === close) {
        depth--;
        if (depth === 0) return html.slice(openIdx, i + 1);
      }
    }
    return '';
  }

  // xpass lists dead mirrors next to live 1x2 CDNs (NXDOMAIN / hang).
  function isDeadCdn(url) {
    return /pinecrestproductionworks\.shop|goldenmeadowproduction\.space/i.test(String(url));
  }

  function cdnRank(url) {
    var u = String(url || '');
    if (/1x2\.space\//i.test(u)) return 0;
    if (/suprox\.xpass\.top/i.test(u)) return 2;
    return 1;
  }

  function rankRows(rows) {
    return (rows || []).slice().sort(function (a, b) {
      return cdnRank(a && a.url) - cdnRank(b && b.url);
    });
  }

  function playlistRows(playlistUrl, baseUrl, referer) {
    var full = /^https?:/i.test(playlistUrl)
      ? playlistUrl
      : baseUrl.replace(/\/$/, '') + (playlistUrl.charAt(0) === '/' ? '' : '/') + playlistUrl;
    return getJson(full, { Referer: referer, Origin: baseUrl, Accept: 'application/json,*/*' })
      .then(function (data) {
        var rows = [];
        var items = data && Array.isArray(data.playlist) ? data.playlist : [];
        items.forEach(function (item) {
          (item && item.sources ? item.sources : []).forEach(function (source) {
            if (!source || !source.file) return;
            if (/\/video\/error|\/error\b/i.test(source.file)) return;
            if (!/^https?:/i.test(source.file)) return;
            if (isDeadCdn(source.file)) return;
            rows.push({
              url: source.file,
              name: '2embed ' + (source.label || source.id || ''),
              quality: source.label || '',
              headers: { 'User-Agent': ua, Referer: 'https://play.xpass.top/' },
            });
          });
        });
        return rankRows(rows);
      })
      .catch(function () {
        return [];
      });
  }

  function followXps(xpsUrl) {
    var xpsBase = 'https://play.xpass.top';
    return getText(xpsUrl, { Referer: 'https://streamsrcs.2embed.cc/' }).then(function (html) {
      var primary = '';
      var dataKey = html.indexOf('var data=');
      if (dataKey >= 0) {
        var objStart = html.indexOf('{', dataKey);
        var json = objStart >= 0 ? balanced(html, objStart) : '';
        try {
          var data = JSON.parse(json);
          if (data && typeof data.playlist === 'string') primary = data.playlist;
        } catch (e) {}
      }
      var backups = [];
      var backupsKey = html.indexOf('var backups=');
      if (backupsKey >= 0) {
        var arrStart = html.indexOf('[', backupsKey);
        var bjson = arrStart >= 0 ? balanced(html, arrStart) : '';
        try {
          backups = JSON.parse(bjson) || [];
        } catch (e2) {}
      }
      // Prefer VIP / mdata paths (1x2) before flaky FIL/WIS mirrors.
      backups = backups.slice().sort(function (a, b) {
        function pathRank(u) {
          u = String((u && u.url) || '');
          if (/\/vip\//i.test(u)) return 0;
          if (/\/mdata\//i.test(u)) return 1;
          return 2;
        }
        return pathRank(a) - pathRank(b);
      });
      var paths = [];
      if (primary) paths.push(primary);
      backups.slice(0, 12).forEach(function (b) {
        if (b && b.url) paths.push(b.url);
      });
      return Promise.all(paths.map(function (p) {
        return playlistRows(p, xpsBase, xpsUrl);
      })).then(function (groups) {
        var out = rankRows([].concat.apply([], groups));
        if (out.length) return out;
        var m3u8 = html.match(/https?:\/\/[^"'\s]+\.m3u8[^"'\s]*/g) || [];
        return rankRows(
          m3u8
            .filter(function (u) {
              return !isDeadCdn(u);
            })
            .map(function (u) {
              return {
                url: u,
                name: '2embed',
                headers: { 'User-Agent': ua, Referer: 'https://play.xpass.top/' },
              };
            })
        );
      });
    });
  }

  function embedPath(imdbId) {
    if (mediaType === 'movie') return '/embed/' + (imdbId || tmdbId);
    return '/embedtv/' + tmdbId + '&s=' + season + '&e=' + episode;
  }

  var imdbP =
    mediaType === 'movie'
      ? getJson(api + '/movie?tmdb_id=' + tmdbId)
          .then(function (d) {
            return (d && d.imdb_id) || ctx.imdbId || '';
          })
          .catch(function () {
            return ctx.imdbId || '';
          })
      : Promise.resolve(ctx.imdbId || '');

  return imdbP
    .then(function (imdb) {
      return getText(embedBase + embedPath(imdb));
    })
    .then(function (html) {
      var servers = parseServers(html);
      if (!servers.length) return ctx.host('multiembed');
      var order = ['xps', 'swish', 'vesy', 'vcr'];
      var chain = Promise.resolve([]);
      order.forEach(function (type) {
        chain = chain.then(function (acc) {
          if (acc.length) return acc;
          var server = null;
          servers.forEach(function (s) {
            if (!server && s.type === type) server = s;
          });
          if (!server) return acc;
          var finalUrl = resolveSrc(server);
          if (type === 'xps') return followXps(finalUrl);
          if (type === 'vcr') {
            return ctx.hop(finalUrl).then(function (rows) {
              return rows && rows.length ? rows : acc;
            });
          }
          return getText(finalUrl, { Referer: 'https://streamsrcs.2embed.cc/' })
            .then(function (playerHtml) {
              var urls = playerHtml.match(/https?:\/\/[^"'\s]+\.m3u8[^"'\s]*/g) || [];
              var rows = urls.map(function (u) {
                return {
                  url: u,
                  name: '2embed ' + type,
                  headers: { 'User-Agent': ua, Referer: finalUrl },
                };
              });
              if (rows.length) return rows;
              return ctx.hop(finalUrl);
            })
            .catch(function () {
              return acc;
            });
        });
      });
      return chain.then(function (rows) {
        var seen = {};
        var out = [];
        rankRows(rows || []).forEach(function (r) {
          if (!r || !r.url || seen[r.url] || isDeadCdn(r.url)) return;
          seen[r.url] = true;
          out.push(r);
        });
        return out.length ? out : ctx.host('multiembed');
      });
    })
    .catch(function () {
      return ctx.host('multiembed');
    });
}
