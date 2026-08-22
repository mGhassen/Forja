function extract(ctx) {
  var cfg = ctx.config || {};
  var fallback = cfg.base || 'https://new3.moviesdrives.my';
  var domainsUrl = cfg.domainsUrl || 'https://raw.githubusercontent.com/phisher98/TVVVV/refs/heads/main/domains.json';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,application/xhtml+xml,*/*', 'Accept-Language': 'en-US,en;q=0.9', Connection: 'keep-alive' };
  var isTv = ctx.type !== 'movie';

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) { return r.text(); });
  }

  function latestDomain() {
    return ctx.fetch(domainsUrl, { headers: { 'User-Agent': ua } }).then(function (r) { return r.json(); })
      .then(function (j) { return (j && j.moviesdrive) || fallback; })
      .catch(function () { return fallback; });
  }

  function hubCloudExtract(url, referer) {
    var current = url.replace('hubcloud.ink', 'hubcloud.dad');
    return fetchText(current, { Referer: referer }).then(function (html) {
      var $ = ctx.html(html);
      var nextHref = '';
      if (current.indexOf('hubcloud.php') < 0) {
        nextHref = $('#download').attr('href') || '';
        if (!nextHref) {
          var m = String(html || '').match(/var url = '([^']*)'/);
          if (m) nextHref = m[1];
        }
      }
      var fetchNext = nextHref
        ? (function () {
            if (!/^https?:/i.test(nextHref)) {
              try { var u = new URL(current); nextHref = u.protocol + '//' + u.hostname + '/' + nextHref.replace(/^\//, ''); } catch (e) {}
            }
            return fetchText(nextHref, { Referer: current });
          })()
        : Promise.resolve(html);
      return fetchNext.then(function (pageData) {
        var $p = ctx.html(pageData);
        var size = $p('i#size').text().trim();
        var header = $p('div.card-header').text().trim();
        var qm = header.match(/(\d{3,4})[pP]/);
        var quality = qm ? parseInt(qm[1], 10) : 1080;
        var links = [];
        $p('a.btn').each(function () {
          var a = $p(this);
          var href = a.attr('href') || '';
          var text = a.text().toLowerCase();
          if (!href) return;
          var label = 'HubCloud';
          if (/download file|fsl server|s3 server|fslv2|mega server/i.test(text) || /r2\.dev/i.test(href)) {
            if (/r2\.dev/i.test(href)) label = 'Direct R2';
            else if (/workers\.dev/i.test(href)) label = 'ZipDisk Server';
            else if (/fsl server/i.test(text)) label = 'HubCloud - FSL';
            else if (/s3 server/i.test(text)) label = 'HubCloud - S3';
            else if (/fslv2/i.test(text)) label = 'HubCloud - FSLv2';
            else if (/mega server/i.test(text)) label = 'HubCloud - Mega';
            links.push({ name: label, quality: quality, url: href, size: size });
          }
        });
        return links;
      });
    }).catch(function () { return []; });
  }

  function loadExtractor(url, referer) {
    if (!url) return Promise.resolve([]);
    var hostname;
    try { hostname = new URL(url).hostname; } catch (e) { return Promise.resolve([]); }
    if (/hubcloud/i.test(hostname)) return hubCloudExtract(url, referer);
    if (/gdflix|gdlink/i.test(hostname)) return Promise.resolve([{ name: 'Google Drive', quality: 1080, url: url }]);
    return Promise.resolve([]);
  }

  function extractMdrive(url) {
    return fetchText(url).then(function (html) {
      var $ = ctx.html(html);
      if (/search-recover\.php/i.test(url)) {
        var qM = String(html || '').match(/const Q_INITIAL\s*=\s*"([^"]+)"/);
        var tM = String(html || '').match(/const FROM_AC_TOKEN\s*=\s*"([^"]+)"/);
        if (qM && tM) {
          var apiBase = url.split('?')[0];
          var params = 'api=search&q=' + encodeURIComponent(qM[1]) + '&page=1&from_ac=' + encodeURIComponent(tM[1]);
          return ctx.fetch(apiBase + '?' + params, { headers: Object.assign({}, hdrs, { Accept: 'application/json' }) })
            .then(function (r) { return r.json(); })
            .then(function (d) { return (d && d.hits || []).map(function (h) { return h.url; }).filter(Boolean); })
            .catch(function () { return []; });
        }
      }
      var hrefs = [];
      $('a[href]').each(function () {
        var href = $(this).attr('href') || '';
        if (/hubcloud|gdflix|gdlink/i.test(href)) hrefs.push(href);
      });
      return hrefs;
    }).catch(function () { return []; });
  }

  return Promise.all([
    ctx.fetch(
      'https://api.themoviedb.org/3/' + (isTv ? 'tv' : 'movie') + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' + encodeURIComponent(tmdbKey) + '&append_to_response=external_ids',
      { headers: { 'User-Agent': ua, Accept: 'application/json' } },
    ).then(function (r) { return r.json(); }),
    latestDomain(),
  ]).then(function (pair) {
    var tmdbData = pair[0];
    var mainUrl = pair[1].replace(/\/$/, '');
    var imdbId = tmdbData && tmdbData.external_ids && tmdbData.external_ids.imdb_id;
    if (!imdbId) return [];
    var searchUrl = mainUrl + '/search.php?q=' + encodeURIComponent(imdbId);
    return ctx.fetch(searchUrl, { headers: hdrs }).then(function (r) { return r.json(); })
      .then(function (data) {
        if (!data || !data.hits || !data.hits.length) return [];
        var matchDoc = data.hits.map(function (h) { return h.document; })
          .find(function (d) { return d.imdb_id === imdbId; });
        if (!matchDoc) return [];
        var permalink = matchDoc.permalink;
        var href = /^https?:/i.test(permalink) ? permalink : mainUrl + permalink;
        return fetchText(href).then(function (pageHtml) {
          var $ = ctx.html(pageHtml);
          var allLinks = [];
          var title = (tmdbData.title || tmdbData.name || '');
          if (!isTv) {
            var downloadLinks = [];
            $('h5 > a').each(function () { downloadLinks.push($(this).attr('href')); });
            var unique = downloadLinks.filter(function (u, i) { return u && downloadLinks.indexOf(u) === i; });
            return Promise.all(unique.map(function (dLink) {
              return extractMdrive(dLink).then(function (servers) {
                return Promise.all(servers.map(function (server) {
                  return loadExtractor(server, href).then(function (streams) {
                    return streams.map(function (s) {
                      return { name: 'MoviesDrive ' + s.name, url: s.url, quality: s.quality + 'p' };
                    });
                  });
                })).then(function (gs) { return [].concat.apply([], gs); });
              });
            })).then(function (gs) { return [].concat.apply([], gs); });
          } else {
            var stag = 'Season ' + (ctx.season || 1);
            var sep = 'Ep' + String(ctx.episode || 1).padStart(2, '0') + '|Ep' + (ctx.episode || 1);
            var entries = [];
            $('h5').each(function () {
              if (new RegExp(stag, 'i').test($(this).text())) entries.push(this);
            });
            return Promise.all(entries.map(function (entry) {
              var nextHref = $(entry).next().find('a').attr('href');
              if (!nextHref) return [];
              return fetchText(nextHref).then(function (epPageHtml) {
                var $ep = ctx.html(epPageHtml);
                var epEntries = [];
                $ep('h5').each(function () {
                  if (new RegExp(sep, 'i').test($ep(this).text())) epEntries.push(this);
                });
                return Promise.all(epEntries.map(function (epEntry) {
                  var link1 = $ep(epEntry).next().find('a').attr('href');
                  var link2 = $ep(epEntry).next().next().find('a').attr('href');
                  var epLinks = [link1, link2].filter(Boolean);
                  return Promise.all(epLinks.map(function (epLink) {
                    return loadExtractor(epLink, nextHref).then(function (streams) {
                      return streams.map(function (s) {
                        return { name: 'MoviesDrive ' + s.name, url: s.url, quality: s.quality + 'p' };
                      });
                    });
                  })).then(function (gs) { return [].concat.apply([], gs); });
                })).then(function (gs) { return [].concat.apply([], gs); });
              });
            })).then(function (gs) { return [].concat.apply([], gs); });
          }
        });
      });
  }).catch(function () { return []; });
}
