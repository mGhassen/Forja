function extract(ctx) {
  var cfg = ctx.config || {};
  var fallback = cfg.base || 'https://uhdmovies.pink';
  var domainsUrl =
    cfg.domainsUrl ||
    'https://raw.githubusercontent.com/mGhassen/Forja/main/forjahq-plugin/domains.json';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,application/xhtml+xml,*/*', 'Accept-Language': 'en-US,en;q=0.9', Connection: 'keep-alive' };
  var isTv = ctx.type !== 'movie';

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) { return r.text(); });
  }

  function latestDomain() {
    return ctx.fetch(domainsUrl, { headers: { 'User-Agent': ua } }).then(function (r) { return r.json(); })
      .then(function (j) { return (j && j.UHDMovies) || fallback; })
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
      if (!formUrl1) return null;
      var formData1 = {};
      $1('form#landing input').each(function () { formData1[$1(this).attr('name')] = $1(this).attr('value') || ''; });
      return ctx.fetch(formUrl1, {
        method: 'POST', headers: Object.assign({}, hdrs, { 'Content-Type': 'application/x-www-form-urlencoded' }),
        body: Object.keys(formData1).map(function (k) { return k + '=' + encodeURIComponent(formData1[k]); }).join('&'),
      }).then(function (r) { return r.text(); }).then(function (html2) {
        var $2 = ctx.html(html2);
        var formUrl2 = $2('form#landing').attr('action');
        if (!formUrl2) return null;
        var formData2 = {};
        $2('form#landing input').each(function () { formData2[$2(this).attr('name')] = $2(this).attr('value') || ''; });
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

  function extractVideoSeed(url) {
    var hostname;
    try { hostname = new URL(url).hostname; } catch (e) { return Promise.resolve(null); }
    var token = (url.split('?url=')[1] || '').trim();
    if (!token) return Promise.resolve(null);
    return ctx.fetch('https://' + hostname + '/api', {
      method: 'POST',
      headers: Object.assign({}, hdrs, { 'Content-Type': 'application/x-www-form-urlencoded', 'x-token': hostname, Referer: url }),
      body: 'keys=' + encodeURIComponent(token),
    }).then(function (r) { return r.text(); })
      .then(function (text) {
        var m = text.match(/url":"([^"]+)"/);
        return m ? m[1].replace(/\\\//g, '/') : null;
      }).catch(function () { return null; });
  }

  return Promise.all([getTmdb(), latestDomain()]).then(function (pair) {
    var info = pair[0];
    var mainUrl = pair[1].replace(/\/$/, '');
    if (!info || !info.title) return [];
    var searchUrl = mainUrl + '/?s=' + encodeURIComponent(info.title);
    return fetchText(searchUrl).then(function (html) {
      var $ = ctx.html(html);
      var targetUrl = '';
      $('article.gridlove-post, article.latestPost').each(function () {
        if (targetUrl) return;
        var title = $('h1.sanket, h2.title a', this).text() || $('a', this).attr('title') || '';
        var href = $('div.entry-image > a, h2.title a, a', this).first().attr('href');
        if (href && title.toLowerCase().indexOf(info.title.toLowerCase()) >= 0) targetUrl = href;
      });
      if (!targetUrl) return [];
      return fetchText(targetUrl).then(function (pageHtml) {
        var $p = ctx.html(pageHtml);
        var items = [];
        if (!isTv) {
          $p('div.entry-content > p, div.entry-content > div').each(function () {
            var text = $p(this).text();
            if (/\[.*\]/.test(text)) {
              var quality = getQuality(text);
              var href2 = $p(this).next().find('a.maxbutton-1, a.maxbutton').attr('href') ||
                $p(this).find('a.maxbutton-1, a.maxbutton').attr('href');
              if (href2) items.push({ url: href2, quality: quality });
            }
          });
        } else {
          var episodesMap = {};
          var currentSeason = ctx.season || 1;
          $p('pre, p, a, h3').each(function () {
            var el = $p(this);
            var text = el.text().trim();
            var sM = text.match(/(?:season\s*|S)(\d+)/i);
            if (sM && text.length < 20) currentSeason = parseInt(sM[1], 10);
            if ((el.is('a') || el.find('a').length > 0) && /episode/i.test(text) && !/zip/i.test(text)) {
              var epM = text.match(/Episode\s*(\d+)/i);
              if (epM) {
                var ep = parseInt(epM[1], 10);
                var epUrl = el.is('a') ? el.attr('href') : el.find('a').attr('href');
                if (epUrl) {
                  var key = currentSeason + '-' + ep;
                  if (!episodesMap[key]) episodesMap[key] = [];
                  episodesMap[key].push(epUrl);
                }
              }
            }
          });
          var targetKey = (ctx.season || 1) + '-' + (ctx.episode || 1);
          (episodesMap[targetKey] || []).forEach(function (u) { items.push({ url: u, quality: 'Unknown' }); });
        }
        return Promise.all(items.map(function (item) {
          var getLink = /unblockedgames/i.test(item.url)
            ? bypassHrefli(item.url)
            : Promise.resolve(item.url);
          return getLink.then(function (finalLink) {
            if (!finalLink) return [];
            if (/driveseed|driveleech/i.test(finalLink)) {
              return extractDriveseed(finalLink).then(function (streams) {
                return streams.map(function (s) {
                  return { name: 'UHDMovies [Driveseed]', url: s.url, quality: s.quality || item.quality, size: s.size };
                });
              });
            }
            if (/video-seed/i.test(finalLink)) {
              return extractVideoSeed(finalLink).then(function (streamUrl) {
                if (!streamUrl) return [];
                return [{ name: 'UHDMovies [VideoSeed]', url: streamUrl, quality: item.quality }];
              });
            }
            return [{ name: 'UHDMovies', url: finalLink, quality: item.quality }];
          });
        })).then(function (groups) { return [].concat.apply([], groups); });
      });
    });
  }).catch(function () { return []; });
}
