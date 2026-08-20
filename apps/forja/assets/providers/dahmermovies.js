function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://a.111477.xyz').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  var isTv = ctx.type === 'tv';
  var allowed = [2160, 1440, 1080, 720, 480];

  function fetchText(url) {
    return ctx.fetch(url, { headers: { 'User-Agent': ua, Accept: 'text/html,*/*', Connection: 'keep-alive' } })
      .then(function (r) { return r.text(); });
  }

  function indexQuality(str) {
    var m = String(str || '').match(/(\d{3,4})[pP]/);
    return m ? parseInt(m[1], 10) : 0;
  }

  function qualityWithCodecs(str) {
    if (!str) return 'Unknown';
    var qm = str.match(/(\d{3,4})[pP]/);
    var base = qm ? qm[1] + 'p' : 'Unknown';
    var low = str.toLowerCase();
    var codecs = [];
    if (/dv|dolby vision/i.test(low)) codecs.push('DV');
    if (/hdr10\+/i.test(low)) codecs.push('HDR10+');
    else if (/hdr10|hdr/i.test(low)) codecs.push('HDR');
    if (/remux/i.test(low)) codecs.push('REMUX');
    if (/imax/i.test(low)) codecs.push('IMAX');
    return codecs.length ? base + ' | ' + codecs.join(' | ') : base;
  }

  function formatSize(sizeText) {
    if (!sizeText) return undefined;
    if (/\d+(\.\d+)?\s*(GB|MB|KB|TB)/i.test(sizeText)) return sizeText;
    var bytes = parseInt(sizeText, 10);
    if (isNaN(bytes)) return sizeText;
    var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    if (!bytes) return '0 Bytes';
    var i = Math.floor(Math.log(bytes) / Math.log(1024));
    return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
  }

  function parseLinks(html) {
    var links = [];
    var rowRe = /<tr[^>]*>(.*?)<\/tr>/gis;
    var rowM;
    while ((rowM = rowRe.exec(html)) !== null) {
      var row = rowM[1];
      var linkM = row.match(/<a[^>]*href=["']([^"']*)["'][^>]*>([^<]*)<\/a>/i);
      if (!linkM) continue;
      var href = linkM[1];
      var text = linkM[2].trim();
      if (!text || href === '../' || text === '../') continue;
      var size = null;
      var sm = row.match(/<td[^>]*data-sort=["']?(\d+)["']?[^>]*>/i) ||
        row.match(/<td[^>]*class=["']filesize["'][^>]*>([^<]+)<\/td>/i) ||
        row.match(/(\d+(?:\.\d+)?\s*(?:GB|MB|KB|B))/i);
      if (sm) size = sm[1].trim ? sm[1].trim() : sm[1];
      links.push({ text: text, href: href, size: size });
    }
    if (!links.length) {
      var re = /<a[^>]*href=["']([^"']*)["'][^>]*>([^<]*)<\/a>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        if (m[2].trim() && m[1] && m[1] !== '../') links.push({ text: m[2].trim(), href: m[1], size: null });
      }
    }
    return links;
  }

  function resolveFinalUrl(startUrl, count) {
    count = count || 0;
    if (count >= 5) return Promise.resolve(startUrl.indexOf('111477.xyz') >= 0 ? null : startUrl);
    return ctx.fetch(startUrl, {
      method: 'HEAD',
      headers: { 'User-Agent': ua, Referer: api + '/' },
    }).then(function (r) {
      if (r.status >= 300 && r.status < 400) {
        var loc = r.headers.get('location');
        if (loc) {
          var next = /^https?:/i.test(loc) ? loc : new URL(loc, startUrl).href;
          return resolveFinalUrl(next, count + 1);
        }
      }
      if (startUrl.indexOf('111477.xyz') >= 0) return null;
      return startUrl;
    }).catch(function () { return null; });
  }

  function invoke(title, year, season, episode) {
    var encodedUrl = season == null
      ? api + '/movies/' + encodeURIComponent(String(title).replace(/:/g, '') + ' (' + year + ')') + '/'
      : api + '/tvs/' + encodeURIComponent(String(title).replace(/:/g, ' -')) + '/' +
        encodeURIComponent('Season ' + season) + '/';
    return fetchText(encodedUrl).then(function (html) {
      var paths = parseLinks(html);
      var filtered;
      if (season == null) {
        filtered = paths.filter(function (p) { return allowed.indexOf(indexQuality(p.text)) >= 0; });
      } else {
        var ss = season < 10 ? '0' + season : String(season);
        var es = episode < 10 ? '0' + episode : String(episode);
        var epRe = new RegExp('S' + ss + 'E' + es, 'i');
        filtered = paths.filter(function (p) {
          return epRe.test(p.text) && allowed.indexOf(indexQuality(p.text)) >= 0;
        });
      }
      filtered = filtered.slice(0, 10);
      var results = [];
      var chain = Promise.resolve();
      filtered.forEach(function (path) {
        chain = chain.then(function () {
          var fullUrl;
          if (/^https?:/i.test(path.href)) fullUrl = path.href;
          else if (path.href.charAt(0) === '/') {
            var u = new URL(api);
            fullUrl = u.protocol + '//' + u.host + path.href.split('/').map(encodeURIComponent).join('/');
          } else {
            fullUrl = (encodedUrl.endsWith('/') ? encodedUrl : encodedUrl + '/') + path.href;
          }
          return resolveFinalUrl(fullUrl).then(function (finalUrl) {
            if (finalUrl) {
              results.push({
                name: 'DahmerMovies',
                url: finalUrl,
                quality: qualityWithCodecs(path.text),
                size: formatSize(path.size),
                headers: { 'User-Agent': 'Mozilla/5.0 (Android) ExoPlayer', Referer: api + '/' },
              });
            }
          });
        });
      });
      return chain.then(function () {
        results.sort(function (a, b) { return indexQuality(b.quality) - indexQuality(a.quality); });
        return results;
      });
    });
  }

  return ctx.fetch(
    'https://api.themoviedb.org/3/' + (isTv ? 'tv' : 'movie') + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
      '?api_key=' + encodeURIComponent(tmdbKey),
    { headers: { 'User-Agent': ua, Accept: 'application/json' } },
  ).then(function (r) { return r.json(); }).then(function (d) {
    var title = isTv ? d.name : d.title;
    var date = (isTv ? d.first_air_date : d.release_date) || '';
    var year = date ? parseInt(date.substring(0, 4), 10) : null;
    if (!title) return [];
    return invoke(title, year, isTv ? (ctx.season || 1) : null, isTv ? (ctx.episode || 1) : null);
  }).catch(function () { return []; });
}
