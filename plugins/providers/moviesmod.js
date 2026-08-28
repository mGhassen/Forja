var SPECS = {
  "base": "https://moviesmod.cc",
  "domainsUrl": "https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/domains.json",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var fallback = cfg.base;
  var domainsUrl = cfg.domainsUrl;
  var tmdbKey = cfg.tmdbKey;
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,application/xhtml+xml,*/*', 'Accept-Language': 'en-US,en;q=0.9', Connection: 'keep-alive' };
  var isTv = ctx.type !== 'movie';

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) { return r.text(); });
  }

  function latestDomain() {
    return ctx.fetch(domainsUrl, { headers: { 'User-Agent': ua } }).then(function (r) { return r.json(); })
      .then(function (j) { return (j && j.moviesmod) || fallback; })
      .catch(function () { return fallback; });
  }

  function getTmdb() {
    var kind = isTv ? 'tv' : 'movie';
    return ctx.fetch(
      'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' + encodeURIComponent(tmdbKey) + '&append_to_response=external_ids',
      { headers: { 'User-Agent': ua, Accept: 'application/json' } },
    ).then(function (r) { return r.json(); })
      .then(function (d) {
        var title = isTv ? (d.name || d.original_name) : (d.title || d.original_title);
        var date = (d.release_date || d.first_air_date) || '';
        return { title: title, year: date.substring(0, 4), imdbId: (d.external_ids && d.external_ids.imdb_id) || null };
      });
  }

  function getQuality(str) {
    if (!str) return 'Unknown';
    var m = str.match(/(\d{3,4})[pP]/);
    if (m) return m[1] + 'p';
    if (/4K|UHD/i.test(str)) return '2160p';
    return 'Unknown';
  }

  function getBaseUrl(url) {
    try { var u = new URL(url); return u.protocol + '//' + u.host; } catch (e) { return ''; }
  }

  function fixUrl(url, domain) {
    if (!url) return '';
    if (/^https?:/i.test(url)) return url;
    if (url.startsWith('//')) return 'https:' + url;
    if (url.startsWith('/')) return domain + url;
    return domain + '/' + url;
  }

  function bypassHrefli(url) {
    var host = getBaseUrl(url);
    return fetchText(url).then(function (html1) {
      var $1 = ctx.html(html1);
      var formUrl1 = $1('form#landing').attr('action');
      var formData1 = {};
      $1('form#landing input').each(function () {
        formData1[$1(this).attr('name')] = $1(this).attr('value') || '';
      });
      if (!formUrl1) return null;
      return ctx.fetch(formUrl1, {
        method: 'POST', headers: Object.assign({}, hdrs, { 'Content-Type': 'application/x-www-form-urlencoded' }),
        body: Object.keys(formData1).map(function (k) { return k + '=' + encodeURIComponent(formData1[k]); }).join('&'),
      }).then(function (r) { return r.text(); }).then(function (html2) {
        var $2 = ctx.html(html2);
        var formUrl2 = $2('form#landing').attr('action');
        var formData2 = {};
        $2('form#landing input').each(function () {
          formData2[$2(this).attr('name')] = $2(this).attr('value') || '';
        });
        if (!formUrl2) return null;
        return ctx.fetch(formUrl2, {
          method: 'POST', headers: Object.assign({}, hdrs, { 'Content-Type': 'application/x-www-form-urlencoded' }),
          body: Object.keys(formData2).map(function (k) { return k + '=' + encodeURIComponent(formData2[k]); }).join('&'),
        }).then(function (r) { return r.text(); }).then(function (html3) {
          var skM = String(html3 || '').match(/\?go=([^"]+)/);
          if (!skM) return null;
          var skToken = skM[1];
          var wpHttp2 = formData2['_wp_http2'] || '';
          return fetchText(host + '?go=' + skToken, { Cookie: skToken + '=' + wpHttp2 }).then(function (html4) {
            var metaM = String(html4 || '').match(/url=(.+)/i);
            if (!metaM) return null;
            return fetchText(metaM[1]).then(function (html5) {
              var pm = String(html5 || '').match(/replace\("([^"]+)"\)/);
              if (!pm || pm[1] === '/404') return null;
              return fixUrl(pm[1], getBaseUrl(metaM[1]));
            });
          });
        });
      });
    }).catch(function () { return null; });
  }

  function extractDriveseed(url) {
    var pageUrl = url;
    var p1 = url.indexOf('r?key=') >= 0
      ? fetchText(url).then(function (h) {
          var m = String(h || '').match(/replace\("([^"]+)"\)/);
          if (m) pageUrl = getBaseUrl(url) + m[1];
          return fetchText(pageUrl);
        })
      : fetchText(pageUrl);
    return p1.then(function (html) {
      var $ = ctx.html(html);
      var qualityText = $('li.list-group-item').first().text() || '';
      var size = $('li:nth-child(3)').text().replace('Size : ', '').trim();
      var quality = getQuality(qualityText);
      var base = getBaseUrl(pageUrl);
      var streams = [];
      var tasks = [];
      $('div.text-center > a').each(function () {
        var a = $(this);
        var text = a.text().toLowerCase();
        var href = a.attr('href');
        if (!href) return;
        if (text.indexOf('instant download') >= 0) {
          tasks.push(ctx.fetch(href, { headers: hdrs }).then(function (r) {
            var fu = r.url || '';
            if (fu.indexOf('url=') >= 0) streams.push({ name: 'Driveseed Instant', url: fu.split('url=')[1], quality: quality, size: size });
          }).catch(function () {}));
        } else if (text.indexOf('resume cloud') >= 0) {
          tasks.push(fetchText(base + href).then(function (ch) {
            var link = ctx.html(ch)('a.btn-success').first().attr('href');
            if (link) streams.push({ name: 'Driveseed Cloud', url: link, quality: quality, size: size });
          }).catch(function () {}));
        } else if (text.indexOf('cloud download') >= 0) {
          streams.push({ name: 'Driveseed Cloud', url: href, quality: quality, size: size });
        }
      });
      return Promise.all(tasks).then(function () { return streams; });
    }).catch(function () { return []; });
  }

  function processLink(url, referer, quality) {
    return fetchText(url, { Referer: referer }).then(function (html) {
      var $ = ctx.html(html);
      var hrefs = [];
      $('a[href*="driveseed.org"], a[href*="tech.unblockedgames.world"]').each(function () {
        hrefs.push($(this).attr('href'));
      });
      var unique = hrefs.filter(function (u, i) { return hrefs.indexOf(u) === i; });
      return Promise.all(unique.map(function (link) {
        var p = /unblockedgames/i.test(link) ? bypassHrefli(link) : Promise.resolve(link);
        return p.then(function (final) {
          if (!final || !/driveseed/i.test(final)) return [];
          return extractDriveseed(final).then(function (streams) {
            return streams.map(function (s) {
              return {
                name: 'MoviesMod [' + s.name + ']',
                url: s.url,
                quality: s.quality || quality,
                size: s.size || undefined,
              };
            });
          });
        });
      })).then(function (groups) { return [].concat.apply([], groups); });
    }).catch(function () { return []; });
  }

  return Promise.all([getTmdb(), latestDomain()]).then(function (pair) {
    var info = pair[0];
    var mainUrl = pair[1].replace(/\/$/, '');
    if (!info || !info.title) return [];
    var q = info.title;
    if (isTv && ctx.season) q += ' Season ' + ctx.season;
    var searchUrl = mainUrl + '/?s=' + encodeURIComponent(q);
    return fetchText(searchUrl).then(function (html) {
      var $ = ctx.html(html);
      var targetUrl = '';
      $('article.gridlove-post, article.latestPost, #content_box article').each(function () {
        if (targetUrl) return;
        var title = $('h1.sanket, h2.title a', this).text() || $('a', this).attr('title') || '';
        var href = $('div.entry-image > a, h2.title a, a', this).first().attr('href');
        if (href && title.toLowerCase().indexOf(info.title.toLowerCase()) >= 0) targetUrl = href;
      });
      if (!targetUrl) targetUrl = $('#content_box article > a').first().attr('href');
      if (!targetUrl) return [];
      return fetchText(targetUrl).then(function (pageHtml) {
        var $p = ctx.html(pageHtml);
        var content = $p('.thecontent');
        var hTag = isTv ? 'h3' : 'h4';
        var aTag = isTv ? 'Episode' : 'Download';
        var sTag = isTv ? '(S0?' + String(ctx.season || 1) + '|Season ' + (ctx.season || 1) + ')' : '';
        var qualityRegex = new RegExp((sTag ? sTag + '.*' : '') + '(480p|720p|1080p|2160p)', 'i');
        var tasks = [];
        content.find(hTag).each(function () {
          var text = $p(this).text();
          if (!qualityRegex.test(text) || text.indexOf('MoviesMod') >= 0) return;
          var quality = getQuality(text);
          var linkEl = $p(this).nextAll('p, div').find("a:contains('" + aTag + "')").first();
          var href = linkEl.attr('href');
          if (href) tasks.push(processLink(href, targetUrl, quality));
        });
        return Promise.all(tasks).then(function (groups) {
          return [].concat.apply([], groups);
        });
      });
    });
  }).catch(function () { return []; });
}
