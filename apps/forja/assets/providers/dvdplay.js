function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://dvdplay.xyz').replace(/\/$/, '');
  var searchBase = (cfg.searchBase || base + '/search.php?q=').replace(/\/$/, '');
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    Referer: base + '/',
  };
  var isTv = ctx.type !== 'movie';
  var title = String(ctx.title || '').trim();
  var year = String(ctx.year || '').trim();

  function abs(url, from) {
    if (!url) return '';
    if (/^https?:/i.test(url)) return url;
    try {
      return new URL(url, from || base).toString();
    } catch (e) {
      return url;
    }
  }

  function fetchText(url, extraHeaders) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extraHeaders || {}) }).then(function (r) {
      return r.text();
    });
  }

  function normalize(text) {
    return String(text || '')
      .toLowerCase()
      .replace(/s\d{1,2}e\d{1,2}/g, ' ')
      .replace(/season\s*\d+/g, ' ')
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function similarity(a, b) {
    var aw = normalize(a).split(' ').filter(Boolean);
    var bw = normalize(b).split(' ').filter(Boolean);
    if (!aw.length || !bw.length) return 0;
    var hit = 0;
    aw.forEach(function (w) {
      if (w.length > 2 && bw.indexOf(w) >= 0) hit += 1;
    });
    return hit / Math.max(aw.length, bw.length);
  }

  function scoreCandidate(label) {
    var score = similarity(title, label);
    if (year && String(label).indexOf(year) >= 0) score += 0.2;
    if (isTv) {
      var seasonToken = 'season ' + String(ctx.season || 1);
      if (normalize(label).indexOf(seasonToken) >= 0) score += 0.3;
    }
    return score;
  }

  function decodeB64(s) {
    try {
      return decodeURIComponent(escape(atob(s)));
    } catch (e) {
      try {
        return atob(s);
      } catch (e2) {
        return '';
      }
    }
  }

  function rot13(s) {
    return String(s || '').replace(/[A-Za-z]/g, function (ch) {
      var start = ch <= 'Z' ? 65 : 97;
      return String.fromCharCode(((ch.charCodeAt(0) - start + 13) % 26) + start);
    });
  }

  function getRedirectLink(url) {
    return fetchText(url)
      .then(function (html) {
        var regex = /s\('o','([A-Za-z0-9+/=]+)'|ck\('_wp_http_\d+','([^']+)'/g;
        var combined = '';
        var m;
        while ((m = regex.exec(html)) !== null) combined += m[1] || m[2] || '';
        if (!combined) return '';
        try {
          var decoded = decodeB64(rot13(decodeB64(decodeB64(combined))));
          var obj = JSON.parse(decoded);
          var encodedurl = decodeB64(obj.o || '').trim();
          var data = decodeB64(obj.data || '').trim();
          var blog = String(obj.blog_url || '').trim();
          if (encodedurl) return encodedurl;
          if (blog && data) return fetchText(blog + '?re=' + encodeURIComponent(data)).then(function (txt) { return String(txt || '').trim(); });
        } catch (e) {}
        return '';
      })
      .catch(function () {
        return '';
      });
  }

  function directize(url) {
    if (!url) return Promise.resolve('');
    var decoded = abs(url).replace(/&amp;/g, '&');
    var linkMatch = decoded.match(/[?&]link=([^&]+)/);
    if (linkMatch) {
      try {
        decoded = decodeURIComponent(linkMatch[1]);
      } catch (e) {}
    }
    var pixel = decoded.match(/pixeldrain\.(?:net|dev)\/u\/([a-zA-Z0-9]+)/i);
    if (pixel) return Promise.resolve('https://pixeldrain.net/api/file/' + pixel[1]);
    if (/r2\.cloudflarestorage\.com|video-downloads\.googleusercontent\.com|pixeldrain\.net\/api\/file\//i.test(decoded)) {
      return Promise.resolve(decoded);
    }
    if (/hubcloud\.php|\/dl\.php\?/i.test(decoded)) {
      return resolveHubCloud(decoded);
    }
    if (/workers\.dev|r2\.dev|buzzheavier|10gbps|download/i.test(decoded)) {
      return getRedirectLink(decoded).then(function (redir) {
        return redir || decoded;
      });
    }
    return Promise.resolve(decoded);
  }

  function scrapeUrls(html, pageUrl) {
    var urls = [];
    var $ = ctx.html ? ctx.html(html) : null;
    if ($) {
      $('a[href], iframe[src], button[data-url]').each(function () {
        var href = $(this).attr('href') || $(this).attr('src') || $(this).attr('data-url') || '';
        if (href) urls.push(abs(href, pageUrl));
      });
      var dl = $('#download').attr('href') || $('.download-btn').attr('href') || $('a[href*="hubcloud.php"]').attr('href');
      if (dl) urls.push(abs(dl, pageUrl));
    }
    String(html || '').replace(/https?:\/\/[^"'\s<>]+/gi, function (u) {
      urls.push(u);
      return u;
    });
    var seen = {};
    return urls.filter(function (u) {
      if (!u || seen[u]) return false;
      seen[u] = true;
      return /(hubcloud|hubdrive|pixeldrain|buzz|10gbps|workers\.dev|r2\.dev|download|api\/file|cloudflarestorage)/i.test(u);
    });
  }

  function resolveHubCloud(url) {
    return fetchText(url)
      .then(function (html) {
        var candidates = scrapeUrls(html, url);
        if (!candidates.length) return [];
        return Promise.all(candidates.slice(0, 8).map(directize)).then(function (resolved) {
          return resolved.filter(Boolean);
        });
      })
      .catch(function () {
        return [];
      });
  }

  function search() {
    var q = title.replace(/\s+/g, '+');
    return fetchText(searchBase + q).then(function (html) {
      var candidates = [];
      var $ = ctx.html ? ctx.html(html) : null;
      if ($) {
        $('a[href]').each(function () {
          var href = $(this).attr('href') || '';
          var text = ($(this).text() || '').trim();
          if (!href || !text) return;
          var url = abs(href, base);
          if (/search\.php/i.test(url)) return;
          if (url.indexOf(base) !== 0) return;
          var score = scoreCandidate(text);
          if (score > 0.15) candidates.push({ url: url, title: text, score: score });
        });
      }
      candidates.sort(function (a, b) { return b.score - a.score; });
      return candidates.slice(0, 3);
    });
  }

  function extractFromPage(pageUrl) {
    return fetchText(pageUrl).then(function (html) {
      var links = scrapeUrls(html, pageUrl);
      return Promise.all(
        links.slice(0, 12).map(function (u) {
          return directize(u);
        }),
      ).then(function (resolved) {
        var out = [];
        var seen = {};
        resolved.forEach(function (u) {
          if (!u || seen[u]) return;
          seen[u] = true;
          var q = /2160/i.test(u)
            ? '4K'
            : /1080/i.test(u)
              ? '1080p'
              : /720/i.test(u)
                ? '720p'
                : /480/i.test(u)
                  ? '480p'
                  : 'Unknown';
          out.push({
            url: u,
            name: 'DVDPlay - ' + q,
            quality: q,
            headers: { 'User-Agent': ua, Referer: pageUrl },
          });
        });
        return out;
      });
    });
  }

  return search()
    .then(function (matches) {
      if (!matches.length) return [];
      return extractFromPage(matches[0].url);
    })
    .catch(function () {
      return [];
    });
}
