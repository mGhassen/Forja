function extract(ctx) {
  var cfg = ctx.config || {};
  var domain = cfg.base || 'https://new1.hdhub4u.limo';
  var searchApi = cfg.searchApi || 'https://search.hdhub4u.glass/collections/post/documents/search';
  var domainsUrl = cfg.domainsUrl || 'https://raw.githubusercontent.com/phisher98/TVVVV/refs/heads/main/domains.json';
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0';
  var isTv = ctx.type !== 'movie';

  function hdrs(extra) {
    return Object.assign({ 'User-Agent': ua, Cookie: 'xla=s4t', Referer: domain + '/' }, extra || {});
  }

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: hdrs(extra) }).then(function (r) { return r.text(); });
  }

  function fetchJson(url, extra) {
    return ctx.fetch(url, { headers: hdrs(extra) }).then(function (r) { return r.json(); });
  }

  function latestDomain() {
    return fetchJson(domainsUrl, { 'User-Agent': ua })
      .then(function (j) {
        return (j && (j.HDHUB4u || j.HDHub4u || j.hdhub4u)) || domain;
      })
      .catch(function () { return domain; });
  }

  function getTmdb() {
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
      '?api_key=' + encodeURIComponent(tmdbKey) + '&append_to_response=external_ids',
      { Accept: 'application/json', 'User-Agent': ua },
    ).then(function (d) {
      var title = isTv ? d.name : d.title;
      var date = (isTv ? d.first_air_date : d.release_date) || '';
      var year = parseInt(date.split('-')[0], 10) || null;
      var imdbId = (d.external_ids && d.external_ids.imdb_id) || ctx.imdbId || null;
      return { title: title, year: year, imdbId: imdbId || null };
    });
  }

  function normTitle(title) {
    return String(title || '').toLowerCase()
      .replace(/\b(the|a|an)\b/g, '').replace(/[:\-_]/g, ' ')
      .replace(/[^\w\s]/g, '').replace(/\s+/g, ' ').trim();
  }

  function titleScore(a, b) {
    var na = normTitle(a).split(/\s+/).filter(Boolean);
    var nb = normTitle(b).split(/\s+/).filter(Boolean);
    if (!na.length || !nb.length) return 0;
    var sb = new Set(nb);
    var intersect = na.filter(function (w) { return sb.has(w); });
    var union = new Set(na.concat(nb));
    var score = intersect.length / union.size;
    if (na.every(function (w) { return sb.has(w); })) score += 0.2;
    return score;
  }

  function bestMatch(info, hits) {
    var best = null, bestScore = 0;
    hits.forEach(function (h) {
      var score = titleScore(info.title, h.title);
      if (info.year && h.year) {
        var diff = Math.abs(info.year - h.year);
        if (diff === 0) score += 0.2;
        else if (diff <= 1) score += 0.1;
        else if (diff > 5) score -= 0.3;
      }
      if (isTv && ctx.season) {
        var s = String(ctx.season);
        var tl = String(h.title).toLowerCase();
        if (tl.indexOf('season ' + s) >= 0 || tl.indexOf('s' + s.padStart(2, '0')) >= 0) score += 0.5;
        else score -= 0.3;
      }
      if (score > bestScore && score > 0.3) { bestScore = score; best = h; }
    });
    return best;
  }

  function rot13(s) {
    return String(s || '').replace(/[a-zA-Z]/g, function (c) {
      return String.fromCharCode((c <= 'Z' ? 90 : 122) >= (c = c.charCodeAt(0) + 13) ? c : c - 26);
    });
  }

  function atobCompat(s) {
    try { return atob(s); } catch (e) { return ''; }
  }

  function decodeRedirectLink(html) {
    var regex = /s\s*\(\s*['"]o['"]\s*,\s*['"]([A-Za-z0-9+/=]+)['"]|ck\s*\(\s*['"]_wp_http_\d+['"]\s*,\s*['"]([^'"]+)['"]/g;
    var combined = '', m;
    while ((m = regex.exec(html)) !== null) combined += m[1] || m[2] || '';
    if (!combined) return null;
    try {
      var decoded = atobCompat(rot13(atobCompat(atobCompat(combined))));
      var obj = JSON.parse(decoded);
      return atobCompat(obj.o || '').trim() || null;
    } catch (e) { return null; }
  }

  function getRedirectLink(url) {
    return fetchText(url).then(function (html) {
      var decoded = decodeRedirectLink(html);
      if (decoded) return decoded;
      var loc = String(html || '').match(/window\.location\.href\s*=\s*['"]([^'"]+)['"]/);
      if (loc && loc[1] && loc[1] !== url) return getRedirectLink(loc[1]);
      return null;
    }).catch(function () { return null; });
  }

  function qualityStr(q) {
    if (!q) return 'Unknown';
    if (q >= 2160) return '4K';
    if (q >= 1080) return '1080p';
    if (q >= 720) return '720p';
    if (q >= 480) return '480p';
    return 'Unknown';
  }

  function hubCloudExtractor(url, referer) {
    var current = url.replace('hubcloud.ink', 'hubcloud.dad');
    return fetchText(current, { Referer: referer || url })
      .then(function (html) {
        var $ = ctx.html(html);
        var nextHref = '';
        if (current.indexOf('hubcloud.php') < 0) {
          nextHref = $('#download').attr('href') || '';
          if (!nextHref) {
            var m = String(html || '').match(/var url\s*=\s*'([^']*)'/);
            if (m) nextHref = m[1];
          }
        }
        var fetchNext = nextHref
          ? (function () {
            if (!/^https?:/i.test(nextHref)) {
              try {
                var u = new URL(current);
                nextHref = u.protocol + '//' + u.hostname + '/' + nextHref.replace(/^\//, '');
              } catch (e) { }
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
          $p('a.btn, a').each(function () {
            var a = $p(this);
            var href = a.attr('href') || '';
            var text = a.text().toLowerCase();
            if (!href || /\/drive\//i.test(href)) return;
            var label = 'HubCloud';
            if (/pixeldrain\.(?:dev|net)\//i.test(href) || /pixelserver/i.test(text)) {
              var pd = href.match(/pixeldrain\.(?:dev|net)\/(?:u|api\/file)\/([A-Za-z0-9]+)/i);
              label = 'HubCloud - PixelServer';
              href = pd
                ? 'https://pixeldrain.net/api/file/' + pd[1] + '?download='
                : href;
            } else if (/r2\.dev/i.test(href)) label = 'Direct R2';
            else if (/workers\.dev/i.test(href)) label = 'ZipDisk Server';
            else if (/pixel\.hubcloud\./i.test(href) || /10gbps/i.test(text)) label = 'HubCloud - 10Gbps';
            else if (/fsl server/i.test(text)) label = 'HubCloud - FSL';
            else if (/s3 server/i.test(text)) label = 'HubCloud - S3';
            else if (/fslv2/i.test(text)) label = 'HubCloud - FSLv2';
            else if (/mega server/i.test(text)) label = 'HubCloud - Mega';
            else if (!/download file|fsl|s3|mega|zipdisk|10gbps|pixelserver/i.test(text)) return;
            links.push({
              name: label,
              title: header || undefined,
              quality: quality,
              url: href,
              size: size || undefined,
            });
          });
          return links;
        });
      }).catch(function () { return []; });
  }

  function loadExtractor(url, referer) {
    if (!url) return Promise.resolve([]);
    var hostname;
    try { hostname = new URL(url).hostname; } catch (e) { return Promise.resolve([]); }
    if (/techyboy4u|gadgetsweb|cryptoinsights|bloggingvector|ampproject|[?&]id=/i.test(url) || !hostname) {
      return getRedirectLink(url).then(function (redir) {
        return redir && redir !== url ? loadExtractor(redir, url) : [];
      });
    }
    if (/hubcloud/i.test(hostname)) return hubCloudExtractor(url, referer);
    if (/hubdrive/i.test(hostname)) {
      return fetchText(url, { Referer: referer || url }).then(function (html) {
        var $ = ctx.html(html);
        var tasks = [];
        $('a[href*="hubcloud"]').each(function () {
          var href = $(this).attr('href') || '';
          if (href) tasks.push(hubCloudExtractor(href, url));
        });
        if (!tasks.length) {
          var m = String(html || '').match(/href=["']([^"']*hubcloud[^"']*)["']/i);
          if (m && m[1]) tasks.push(hubCloudExtractor(m[1], url));
        }
        return Promise.all(tasks).then(function (groups) {
          return [].concat.apply([], groups);
        });
      }).catch(function () { return []; });
    }
    if (/pixeldrain/i.test(hostname)) {
      var pid = url.match(/(?:file|u)\/([A-Za-z0-9]+)/);
      var purl = pid ? 'https://pixeldrain.net/api/file/' + pid[1] : url;
      return Promise.resolve([{ name: 'Pixeldrain', quality: 0, url: purl, size: '' }]);
    }
    return Promise.resolve([]);
  }

  function searchHits(query, currentDomain) {
    var today = new Date().toISOString().split('T')[0];
    var url = searchApi + '?q=' + encodeURIComponent(query) +
      '&query_by=post_title,category&query_by_weights=4,2&sort_by=sort_by_date:desc' +
      '&limit=15&highlight_fields=none&use_cache=true&page=1&analytics_tag=' + today;
    return typesenseHits(url, currentDomain);
  }

  function searchByImdb(imdbId, season, currentDomain) {
    var url = searchApi + '?q=' + encodeURIComponent(imdbId) +
      '&query_by=imdb_id&limit=15&highlight_fields=none&use_cache=true';
    return typesenseHits(url, currentDomain).then(function (hits) {
      return hits.filter(function (h) {
        if (h.imdbId && h.imdbId !== imdbId) return false;
        if (!isTv || !season) return true;
        var s = String(season);
        var sp = s.padStart(2, '0');
        var tl = String(h.title || '').toLowerCase();
        return tl.indexOf('season ' + s) >= 0 ||
          tl.indexOf('s' + s) >= 0 ||
          tl.indexOf('s' + sp) >= 0;
      });
    });
  }

  function typesenseHits(url, currentDomain) {
    return ctx.fetch(url, { headers: hdrs() }).then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d || !d.hits) return [];
        return d.hits.map(function (h) {
          var doc = h.document || {};
          var ym = (doc.post_title || '').match(/\((\d{4})\)|\b(\d{4})\b/);
          var url2 = doc.permalink || '';
          if (url2.startsWith('/')) url2 = currentDomain + url2;
          return {
            title: doc.post_title || '',
            url: url2,
            year: ym ? parseInt(ym[1] || ym[2], 10) : null,
            imdbId: doc.imdb_id || null,
          };
        });
      })
      .catch(function () { return []; });
  }

  function collectHubLinks(html, normalized) {
    var $ = ctx.html(html);
    var linkHrefs = [];
    $('a[href*="hubdrive"]').each(function () {
      var text = $(this).text() || '';
      if (text.indexOf('⚡') >= 0) return;
      var href = $(this).attr('href') || '';
      if (href) linkHrefs.push({ url: href, episode: null });
    });
    var gadgets = [];
    $('a[href*="gadgetsweb"]').each(function () {
      var href = $(this).attr('href') || '';
      if (href) gadgets.push(href);
    });
    if (!gadgets.length) return Promise.resolve(linkHrefs);
    return Promise.all(gadgets.map(function (href) {
      return getRedirectLink(href).then(function (redir) {
        if (!redir) return [];
        return fetchText(redir, { Referer: normalized }).then(function (hubHtml) {
          var $h = ctx.html(hubHtml);
          var out = [];
          $h('a[href*="hubdrive"]').each(function () {
            var t = $h(this).text() || '';
            if (t.indexOf('⚡') >= 0) return;
            var h = $h(this).attr('href') || '';
            if (h) out.push({ url: h, episode: null });
          });
          return out;
        }).catch(function () { return []; });
      }).catch(function () { return []; });
    })).then(function (groups) {
      groups.forEach(function (g) { linkHrefs.push.apply(linkHrefs, g); });
      return linkHrefs;
    });
  }

  function getDownloadLinks(mediaUrl, currentDomain) {
    var normalized = mediaUrl;
    try {
      var mu = new URL(mediaUrl);
      var du = new URL(currentDomain);
      mu.hostname = du.hostname;
      normalized = mu.toString();
    } catch (e) { }
    return fetchText(normalized, { Referer: currentDomain + '/' }).then(function (html) {
      return collectHubLinks(html, normalized).then(function (hubLinks) {
        var $ = ctx.html(html);
        var typeRaw = $('h1.page-title span').text().toLowerCase();
        var isMovie = typeRaw.indexOf('movie') >= 0 || !isTv;
        var linkHrefs = hubLinks.slice();
        if (isMovie) {
          $('h3 a, h4 a').filter(function () {
            return /480|720|1080|2160|4K/i.test($(this).text());
          }).each(function () { linkHrefs.push({ url: $(this).attr('href'), episode: null }); });
          $('.page-body > div a').filter(function () {
            var href = $(this).attr('href') || '';
            return /hdstream4u|hubstream/i.test(href);
          }).each(function () { linkHrefs.push({ url: $(this).attr('href'), episode: null }); });
        } else {
          var episodeMap = {};
          $('h3, h4').each(function () {
            var el = $(this);
            var text = el.text();
            var epM = text.match(/(?:EPiSODE\s*(\d+)|E(\d+))/i);
            if (epM) {
              var epNum = parseInt(epM[1] || epM[2], 10);
              el.find('a').each(function () {
                var href = $(this).attr('href') || '';
                if (!episodeMap[epNum]) episodeMap[epNum] = [];
                episodeMap[epNum].push(href);
              });
            }
          });
          Object.keys(episodeMap).forEach(function (ep) {
            episodeMap[ep].forEach(function (u) {
              linkHrefs.push({ url: u, episode: parseInt(ep, 10) });
            });
          });
        }
        var unique = {};
        var filtered = linkHrefs.filter(function (l) {
          if (!l.url || unique[l.url]) return false;
          unique[l.url] = true;
          return true;
        });
        return Promise.all(filtered.map(function (l) {
          return loadExtractor(l.url, normalized).then(function (extracted) {
            return extracted.map(function (e) { return Object.assign({}, e, { episode: l.episode }); });
          });
        })).then(function (groups) {
          var seen = {};
          return [].concat.apply([], groups).filter(function (l) {
            if (!l.url || l.url.indexOf('.zip') >= 0 || seen[l.url]) return false;
            seen[l.url] = true;
            return true;
          });
        });
      });
    });
  }

  return Promise.all([getTmdb(), latestDomain()]).then(function (pair) {
    var info = pair[0];
    var currentDomain = pair[1];
    if (!info || !info.title) {
      ctx.error('no tmdb title');
      return [];
    }
    ctx.log('imdb=' + (info.imdbId || '') + ' domain=' + currentDomain + ' q=' + (isTv && ctx.season ? info.title + ' Season ' + ctx.season : info.title));
    var q = isTv && ctx.season ? info.title + ' Season ' + ctx.season : info.title;
    var searchPromise = info.imdbId
      ? searchByImdb(info.imdbId, ctx.season, currentDomain).then(function (imdbHits) {
        if (imdbHits.length) return imdbHits;
        return searchHits(q, currentDomain);
      })
      : searchHits(q, currentDomain);
    return searchPromise.then(function (hits) {
      if (!hits.length) {
        ctx.error('no search hits');
        return [];
      }
      ctx.log('hits=' + hits.length + ' first=' + (hits[0].title || hits[0].url));
      var match = info.imdbId && hits[0].imdbId === info.imdbId
        ? hits[0]
        : (bestMatch(info, hits) || hits[0]);
      return getDownloadLinks(match.url, currentDomain).then(function (links) {
        var episode = ctx.episode ? parseInt(ctx.episode, 10) : null;
        if (isTv && episode !== null) {
          links = links.filter(function (l) { return l.episode === episode; });
        }
        ctx.log('links=' + links.length + (episode != null ? ' ep=' + episode : ''));
        return links.map(function (l) {
          var name = 'HDHub4u';
          if (l.name) name += ' ' + l.name.replace(/^HubCloud\s*-?\s*/i, '');
          return {
            url: l.url,
            name: name,
            title: l.title || undefined,
            quality: qualityStr(l.quality),
            size: l.size || undefined,
            headers: l.headers || undefined,
          };
        }).sort(function (a, b) {
          var order = { '4K': 4, '1080p': 3, '720p': 2, '480p': 1, Unknown: 0 };
          return (order[b.quality] || 0) - (order[a.quality] || 0);
        });
      });
    });
  }).catch(function (e) {
    ctx.error(e && e.message ? e.message : e);
    return [];
  });
}
