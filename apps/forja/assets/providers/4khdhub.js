function extract(ctx) {
  var cfg = ctx.config || {};
  var domain = cfg.base || 'https://4khdhub.link';
  var domainsUrl =
    cfg.domainsUrl ||
    'https://raw.githubusercontent.com/phisher98/TVVVV/refs/heads/main/domains.json';
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Accept: 'text/html,application/xhtml+xml,*/*' };
  var isTv = ctx.type === 'tv';

  function fetchText(url, extraHeaders) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extraHeaders || {}) }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url) {
    return ctx.fetch(url, { headers: { 'User-Agent': ua, Accept: 'application/json' } }).then(function (r) {
      return r.json();
    });
  }

  function latestDomain() {
    return fetchJson(domainsUrl)
      .then(function (j) {
        return (j && j['4khdhub']) || domain;
      })
      .catch(function () {
        return domain;
      });
  }

  function getTmdbDetails() {
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
    ).then(function (data) {
      return {
        title: isTv ? data.name : data.title,
        year: parseInt(String(isTv ? data.first_air_date : data.release_date || '').split('-')[0], 10) || 0,
      };
    });
  }

  function normalizeTitle(title) {
    return String(title || '')
      .replace(/\[.*?\]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function levenshtein(a, b) {
    if (a === b) return 0;
    if (!a.length) return b.length;
    if (!b.length) return a.length;
    var dp = [];
    for (var i = 0; i <= a.length; i++) {
      dp[i] = [i];
    }
    for (var j = 1; j <= b.length; j++) dp[0][j] = j;
    for (i = 1; i <= a.length; i++) {
      for (j = 1; j <= b.length; j++) {
        var cost = a.charAt(i - 1) === b.charAt(j - 1) ? 0 : 1;
        dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost);
      }
    }
    return dp[a.length][b.length];
  }

  function parseBytes(text) {
    var m = String(text || '').match(/([0-9.]+)\s*([KMGTP]?B)/i);
    if (!m) return 0;
    var n = parseFloat(m[1]);
    var unit = m[2].toUpperCase();
    var pow = unit === 'TB' ? 4 : unit === 'GB' ? 3 : unit === 'MB' ? 2 : unit === 'KB' ? 1 : 0;
    return n * Math.pow(1024, pow);
  }

  function formatBytes(bytes) {
    if (!bytes) return '0 B';
    var sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = Math.floor(Math.log(bytes) / Math.log(1024));
    return (bytes / Math.pow(1024, i)).toFixed(2).replace(/\.00$/, '') + ' ' + sizes[i];
  }

  function atobCompat(input) {
    try {
      return atob(input);
    } catch (e) {
      return '';
    }
  }

  function rot13(str) {
    return String(str || '').replace(/[a-zA-Z]/g, function (c) {
      return String.fromCharCode((c <= 'Z' ? 90 : 122) >= (c = c.charCodeAt(0) + 13) ? c : c - 26);
    });
  }

  function resolveRedirect(url) {
    if (/hubcloud|hubdrive/i.test(url)) return Promise.resolve(url);
    return fetchText(url)
      .then(function (html) {
        var m = String(html || '').match(/'o','(.*?)'/);
        if (!m) return url;
        try {
          var step1 = atobCompat(m[1]);
          var step2 = atobCompat(step1);
          var step3 = rot13(step2);
          var step4 = atobCompat(step3);
          var decoded = JSON.parse(step4);
          return decoded && decoded.o ? atobCompat(decoded.o) : url;
        } catch (e) {
          return url;
        }
      })
      .catch(function () {
        return url;
      });
  }

  function fetchPageUrl(name, year) {
    return latestDomain().then(function (baseUrl) {
      return fetchText(baseUrl + '/?s=' + encodeURIComponent(name)).then(function (html) {
        var articleMatch = findArticleMatch(html, baseUrl, name);
        if (articleMatch) return articleMatch;
        return findMovieCardMatch(html, baseUrl, name, year);
      });
    });
  }

  function findMovieCardMatch(html, baseUrl, name, year) {
    var $ = ctx.html(html);
    var targetType = isTv ? 'Series' : 'Movies';
    var matches = [];
    $('.movie-card').each(function () {
      var card = $(this);
      if (!card.find('.movie-card-format:contains("' + targetType + '")').length) return;
      var metaYear = parseInt(card.find('.movie-card-meta').text(), 10);
      if (!metaYear || Math.abs(metaYear - year) > 1) return;
      var cardTitle = card.find('.movie-card-title').text().trim();
      if (levenshtein(normalizeTitle(cardTitle), normalizeTitle(name)) >= 4) return;
      var href = card.attr('href') || card.find('a').attr('href') || '';
      if (href) matches.push(/^https?:/i.test(href) ? href : baseUrl + (href.charAt(0) === '/' ? '' : '/') + href);
    });
    return matches[0] || null;
  }

  function findArticleMatch(html, baseUrl, name) {
    var $ = ctx.html(html);
    var best = null;
    var bestDist = 999;
    $('article h2 a').each(function () {
      var title = $(this).text().trim();
      var dist = levenshtein(normalizeTitle(title), normalizeTitle(name));
      if (dist >= 4) return;
      if (dist < bestDist) {
        bestDist = dist;
        var href = $(this).attr('href') || '';
        if (href) {
          best = /^https?:/i.test(href) ? href : baseUrl + (href.charAt(0) === '/' ? '' : '/') + href;
        }
      }
    });
    return best;
  }

  function extractSourceResult($, el) {
    var html = $(el).html() || '';
    var sizeMatch = html.match(/([\d.]+ ?[GM]B)/i);
    var heightMatch = html.match(/(\d{3,4})p/i);
    var title = $(el).find('.file-title, .episode-file-title').text().trim();
    var height = heightMatch ? parseInt(heightMatch[1], 10) : 0;
    if (!height && /4k/i.test(title + ' ' + html)) height = 2160;
    var meta = {
      bytes: sizeMatch ? parseBytes(sizeMatch[1]) : 0,
      height: height,
      title: title,
    };

    var hubCloudLink = '';
    $(el)
      .find('a')
      .each(function () {
        var a = $(this);
        var text = a.text();
        var href = a.attr('href') || '';
        if (!hubCloudLink && (/HubCloud/i.test(text) || /hubcloud/i.test(href))) hubCloudLink = href;
      });
    if (hubCloudLink) return resolveRedirect(hubCloudLink).then(function (u) { return { url: u, meta: meta }; });

    var hubDriveLink = '';
    $(el)
      .find('a')
      .each(function () {
        var a = $(this);
        var text = a.text();
        var href = a.attr('href') || '';
        if (!hubDriveLink && (/HubDrive/i.test(text) || /hubdrive/i.test(href))) hubDriveLink = href;
      });
    if (!hubDriveLink) return Promise.resolve(null);
    return resolveRedirect(hubDriveLink).then(function (resolvedDrive) {
      if (!resolvedDrive) return null;
      return fetchText(resolvedDrive).then(function (innerHtml) {
        var $2 = ctx.html(innerHtml);
        var innerCloud = '';
        $2('a').each(function () {
          var a = $2(this);
          var text = a.text();
          var href = a.attr('href') || '';
          if (!innerCloud && (/HubCloud/i.test(text) || /hubcloud/i.test(href))) innerCloud = href;
        });
        return innerCloud ? { url: innerCloud, meta: meta } : null;
      });
    });
  }

  function isHubCloudDrivePage(url) {
    try {
      return new URL(url).pathname.toLowerCase().indexOf('/drive/') >= 0;
    } catch (e) {
      return /\/drive\//i.test(String(url || ''));
    }
  }

  function appendDownloadQuery(apiUrl) {
    try {
      var u = new URL(apiUrl);
      u.searchParams.set('download', '');
      return u.href;
    } catch (e) {
      return apiUrl + (apiUrl.indexOf('?') >= 0 ? '&' : '?') + 'download=';
    }
  }

  function extractHubCloud(hubCloudUrl, baseMeta) {
    if (isHubCloudDrivePage(hubCloudUrl)) return Promise.resolve([]);
    return fetchText(hubCloudUrl, { Referer: hubCloudUrl })
      .then(function (redirectHtml) {
        var $r = ctx.html(redirectHtml);
        var linksUrl = '';
        var redirectUrlMatch = String(redirectHtml || '').match(/var url ?= ?'(.*?)'/);
        if (redirectUrlMatch) linksUrl = redirectUrlMatch[1];
        if (!linksUrl) {
          linksUrl = $r('#download').attr('href') || '';
          if (linksUrl && !/^https?:/i.test(linksUrl)) {
            try {
              var base = new URL(hubCloudUrl);
              linksUrl = base.protocol + '//' + base.hostname + '/' + linksUrl.replace(/^\//, '');
            } catch (e) {}
          }
        }
        if (!linksUrl || isHubCloudDrivePage(linksUrl)) return [];
        return fetchText(linksUrl, { Referer: hubCloudUrl }).then(function (linksHtml) {
          var $ = ctx.html(linksHtml);
          var sizeText = $('#size').text();
          var titleText = $('title').text().trim();
          var meta = {
            bytes: parseBytes(sizeText) || baseMeta.bytes,
            height: baseMeta.height,
            title: titleText || baseMeta.title,
          };
          var results = [];
          $('a.btn, a').each(function () {
            var a = $(this);
            var text = a.text().trim();
            var href = a.attr('href') || '';
            if (!href || isHubCloudDrivePage(href)) return;
            if (/PixelServer/i.test(text)) {
              var userUrl = href.replace('/api/file/', '/u/');
              var apiUrl = userUrl.replace('/u/', '/api/file/');
              results.push({
                source: 'HubCloud (PixelServer)',
                url: appendDownloadQuery(apiUrl),
                meta: meta,
              });
            } else if (/FSLv2/i.test(text)) {
              results.push({ source: 'FSLv2', url: href, meta: meta });
            } else if (/FSL/i.test(text)) {
              results.push({ source: 'FSL', url: href, meta: meta });
            } else if (/Download File/i.test(text) || /r2\.dev/i.test(href)) {
              results.push({ source: 'Direct R2', url: href, meta: meta });
            } else if (/ZipDisk/i.test(text) || /workers\.dev/i.test(href)) {
              results.push({ source: 'ZipDisk Server', url: href, meta: meta });
            } else if (/10Gbps/i.test(text) && /workers\.dev|r2\.dev|\/api\/file\//i.test(href)) {
              results.push({ source: 'HubCloud 10Gbps', url: href, meta: meta });
            }
          });
          return results;
        });
      })
      .catch(function () {
        return [];
      });
  }

  return getTmdbDetails()
    .then(function (media) {
      if (!media || !media.title) {
        ctx.error('no tmdb title');
        return [];
      }
      ctx.log(media.title + ' ' + media.year);
      return fetchPageUrl(media.title, media.year).then(function (pageUrl) {
        if (!pageUrl) {
          ctx.error('no page url');
          return [];
        }
        ctx.log('page=' + pageUrl);
        return fetchText(pageUrl).then(function (html) {
          var $ = ctx.html(html);
          var items = [];
          if (isTv && ctx.season && ctx.episode) {
            var seasonStr = 'S' + String(ctx.season).padStart(2, '0');
            var episodeStr = 'Episode-' + String(ctx.episode).padStart(2, '0');
            $('.episode-item').each(function () {
              if ($('.episode-title', this).text().indexOf(seasonStr) >= 0) {
                $('.episode-download-item', this).each(function () {
                  if ($(this).text().indexOf(episodeStr) >= 0) items.push(this);
                });
              }
            });
          } else {
            $('.download-item').each(function () {
              items.push(this);
            });
          }
          ctx.log('items=' + items.length + (isTv ? ' ' + seasonStr + ' ' + episodeStr : ''));
          return Promise.all(
            items.map(function (item) {
              return extractSourceResult($, item).then(function (result) {
                if (!result || !result.url) return [];
                return extractHubCloud(result.url, result.meta).then(function (links) {
                  return links.map(function (link) {
                    return {
                      name:
                        '4KHDHub - ' +
                        link.source +
                        (result.meta.height ? ' ' + result.meta.height + 'p' : ''),
                      title: (link.meta.title || result.meta.title || '4KHDHub') + '\n' + formatBytes(link.meta.bytes || 0),
                      url: link.url,
                      quality: result.meta.height ? String(result.meta.height) + 'p' : undefined,
                      behaviorHints: { bingeGroup: '4khdhub-' + link.source },
                    };
                  });
                });
              });
            }),
          ).then(function (groups) {
            return [].concat.apply([], groups);
          });
        });
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
