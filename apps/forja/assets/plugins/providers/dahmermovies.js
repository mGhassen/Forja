function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://a.111477.xyz').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var isTv = ctx.type !== 'movie';
  var allowed = [2160, 1440, 1080, 720, 480];

  ctx.log('start tmdb=' + ctx.tmdbId + ' type=' + (isTv ? 'tv' : 'movie'));

  function fetchText(url) {
    return ctx
      .fetch(url, {
        headers: {
          'User-Agent': ua,
          Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
          Referer: api + '/',
        },
      })
      .then(function (r) {
        ctx.log('list http ' + r.status + ' ' + url.slice(0, 120));
        return r.text();
      });
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
    if (sizeText == null || sizeText === '') return undefined;
    if (/\d+(\.\d+)?\s*(GB|MB|KB|TB)/i.test(String(sizeText))) return String(sizeText);
    var bytes = parseInt(sizeText, 10);
    if (isNaN(bytes) || bytes < 0) return undefined;
    var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    if (!bytes) return '0 Bytes';
    var i = Math.floor(Math.log(bytes) / Math.log(1024));
    return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
  }

  function absolute(href) {
    if (!href) return '';
    if (/^https?:/i.test(href)) return href;
    try {
      return new URL(href, api + '/').href;
    } catch (e) {
      return api + (href.charAt(0) === '/' ? href : '/' + href);
    }
  }

  // Match Rust index111477: data-entry rows, fallback to <a> listings.
  function parseEntries(html) {
    var out = [];
    var re =
      /<tr[^>]*data-entry="true"[^>]*data-name="([^"]*)"[^>]*data-url="([^"]*)"[^>]*>([\s\S]*?)<\/tr>/gi;
    var m;
    while ((m = re.exec(html)) !== null) {
      var name = m[1];
      var url = m[2];
      var row = m[3];
      var size = -1;
      var sm =
        row.match(/data-sort=["']?(-?\d+)["']?/i) ||
        row.match(/class=["']size["'][^>]*data-sort=["']?(-?\d+)/i);
      if (sm) size = parseInt(sm[1], 10);
      if (name && url) out.push({ text: name, href: url, size: size });
    }
    if (out.length) return out;

    var rowRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    var rowM;
    while ((rowM = rowRe.exec(html)) !== null) {
      var r = rowM[1];
      var linkM = r.match(/<a[^>]*href=["']([^"']*)["'][^>]*>([^<]*)<\/a>/i);
      if (!linkM) continue;
      var href = linkM[1];
      var text = linkM[2].trim();
      if (!text || href === '../' || text === '../') continue;
      var sz = null;
      var s2 =
        r.match(/<td[^>]*data-sort=["']?(-?\d+)["']?/i) ||
        r.match(/(\d+(?:\.\d+)?\s*(?:GB|MB|KB|B))/i);
      if (s2) sz = s2[1];
      out.push({ text: text, href: href, size: sz });
    }
    return out;
  }

  function invoke(title, year, season, episode) {
    var cleanTitle = String(title || '').replace(/:/g, isTv ? ' -' : '');
    var encodedUrl =
      season == null
        ? api + '/movies/' + encodeURIComponent(cleanTitle + ' (' + year + ')') + '/'
        : api +
          '/tvs/' +
          encodeURIComponent(cleanTitle) +
          '/' +
          encodeURIComponent('Season ' + season) +
          '/';
    ctx.log('index ' + encodedUrl);
    return fetchText(encodedUrl).then(function (html) {
      if (/just a moment|cf-challenge|challenge-platform|error\s*1015|rate limited/i.test(html)) {
        ctx.log('cloudflare / rate limit on listing');
        return [];
      }
      var paths = parseEntries(html);
      ctx.log('entries=' + paths.length);
      var filtered;
      if (season == null) {
        filtered = paths.filter(function (p) {
          return (
            /\.(mkv|mp4|avi|m4v|mov|webm)$/i.test(p.text) &&
            allowed.indexOf(indexQuality(p.text)) >= 0
          );
        });
      } else {
        var ss = season < 10 ? '0' + season : String(season);
        var es = episode < 10 ? '0' + episode : String(episode);
        var epRe = new RegExp('S' + ss + 'E' + es, 'i');
        filtered = paths.filter(function (p) {
          return (
            epRe.test(p.text) &&
            /\.(mkv|mp4|avi|m4v|mov|webm)$/i.test(p.text) &&
            allowed.indexOf(indexQuality(p.text)) >= 0
          );
        });
      }
      filtered = filtered.slice(0, 12);
      ctx.log('matched=' + filtered.length);
      // Return a.111477.xyz file URLs directly — player seek proxy handles them.
      // Do NOT chase redirects / reject *111477.xyz* (that wiped every hit).
      var results = filtered.map(function (path) {
        return {
          name: '111477',
          url: absolute(path.href),
          quality: qualityWithCodecs(path.text),
          size: formatSize(path.size),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Android) ExoPlayer',
            Referer: api + '/',
          },
        };
      });
      results.sort(function (a, b) {
        return indexQuality(b.quality) - indexQuality(a.quality);
      });
      ctx.log('streams=' + results.length);
      return results;
    });
  }

  function fromMeta(title, year) {
    if (!title) {
      ctx.log('no title');
      return Promise.resolve([]);
    }
    return invoke(
      title,
      year,
      isTv ? ctx.season || 1 : null,
      isTv ? ctx.episode || 1 : null,
    );
  }

  if (ctx.title) {
    var y = ctx.year ? parseInt(String(ctx.year).substring(0, 4), 10) : null;
    return fromMeta(ctx.title, y).catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
  }

  return ctx
    .fetch(
      'https://api.themoviedb.org/3/' +
        (isTv ? 'tv' : 'movie') +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
      { headers: { 'User-Agent': ua, Accept: 'application/json' } },
    )
    .then(function (r) {
      ctx.log('tmdb http ' + r.status);
      return r.json();
    })
    .then(function (d) {
      var title = isTv ? d.name : d.title;
      var date = (isTv ? d.first_air_date : d.release_date) || '';
      var year = date ? parseInt(date.substring(0, 4), 10) : null;
      return fromMeta(title, year);
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
