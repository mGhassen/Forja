function extract(ctx) {
  var cfg = ctx.config || {};
  var site = (cfg.origin || 'https://onlykdrama.shop').replace(/\/$/, '');
  var filepress = (cfg.filepress || 'https://new3.filepress.baby').replace(/\/$/, '');
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';
  var baseHeaders = {
    'User-Agent': ua,
    'Accept-Language': 'en-US,en;q=0.9',
  };
  var isMovie = ctx.type === 'movie';
  var title = String(ctx.title || '').trim();
  var year = ctx.year ? String(ctx.year) : '';
  var season = Number(ctx.season) || 1;
  var episode = Number(ctx.episode) || 1;
  if (!title) return Promise.resolve([]);

  var STOP = {
    a: 1, an: 1, and: 1, at: 1, by: 1, for: 1, from: 1,
    in: 1, of: 1, on: 1, the: 1, to: 1, tv: 1,
  };

  function decodeHtml(s) {
    if (!s) return '';
    return String(s)
      .replace(/&#(\d+);/g, function (_, n) {
        return String.fromCharCode(parseInt(n, 10));
      })
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>');
  }

  function stripTags(s) {
    return decodeHtml(String(s || '').replace(/<[^>]+>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim();
  }

  function normalize(s) {
    return decodeHtml(s || '')
      .toLowerCase()
      .replace(/&#8212;/g, ' ')
      .replace(/[\u2019\u0027\u0060]/g, '')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function tokens(s) {
    var out = [];
    var seen = {};
    normalize(s).split(' ').forEach(function (t) {
      if (!t || t.length < 2 || STOP[t] || seen[t]) return;
      seen[t] = 1;
      out.push(t);
    });
    return out;
  }

  function qualityOf(s) {
    var m = String(s || '').match(/\b(2160p|1440p|1080p|720p|540p|480p|360p)\b/i);
    return m ? m[1].toUpperCase() : 'HD';
  }

  function escapeRe(s) {
    return String(s || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, baseHeaders, extra || {}) }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status + ' for ' + url);
      return r.text();
    });
  }

  function fetchJson(url, opts) {
    opts = opts || {};
    return ctx.fetch(url, {
      method: opts.method || 'GET',
      headers: Object.assign({}, baseHeaders, opts.headers || {}),
      body: opts.body,
    }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status + ' for ' + url);
      return r.json();
    });
  }

  function searchQueries() {
    var cleaned = decodeHtml(title).replace(/[:\-]/g, ' ').replace(/\s+/g, ' ').trim();
    var out = [];
    var seen = {};
    function add(q) {
      var n = normalize(q);
      if (!n || seen[n]) return;
      seen[n] = 1;
      out.push(q);
    }
    add(title);
    add(cleaned);
    if (year) {
      add(title + ' ' + year);
      add(cleaned + ' ' + year);
    }
    return out;
  }

  function extractCandidateUrls(html) {
    var needle = isMovie ? '/movies/' : '/drama/';
    var host = site.replace(/^https?:\/\//, '');
    var re = new RegExp('href=["\'](https?:\\/\\/' + escapeRe(host) + '\\/[^"\'#?]+)["\']', 'gi');
    var out = [];
    var seen = {};
    var m;
    while ((m = re.exec(html))) {
      if (m[1].indexOf(needle) === -1 || seen[m[1]]) continue;
      seen[m[1]] = 1;
      out.push(m[1]);
    }
    return out;
  }

  function scoreUrl(url) {
    var score = 0;
    if (isMovie) {
      if (url.indexOf('/movies/') !== -1) score += 10;
    } else if (url.indexOf('/drama/') !== -1) {
      score += 10;
    }
    var normUrl = normalize(url);
    tokens(title).forEach(function (t) {
      if (normUrl.indexOf(t) !== -1) score += 12;
    });
    if (year && normUrl.indexOf(String(year)) !== -1) score += 15;
    return score;
  }

  function collectCandidates(queries, i, acc) {
    if (i >= queries.length) {
      var ranked = [];
      var seen = {};
      acc.forEach(function (u, idx) {
        if (seen[u]) return;
        seen[u] = 1;
        ranked.push({ url: u, score: scoreUrl(u), index: idx });
      });
      ranked.sort(function (a, b) {
        if (b.score !== a.score) return b.score - a.score;
        return a.index - b.index;
      });
      return Promise.resolve(ranked.slice(0, 8).map(function (r) { return r.url; }));
    }
    return fetchText(site + '/?s=' + encodeURIComponent(queries[i]))
      .then(function (html) {
        return collectCandidates(queries, i + 1, acc.concat(extractCandidateUrls(html)));
      })
      .catch(function () {
        return collectCandidates(queries, i + 1, acc);
      });
  }

  function pageTitle(html) {
    var m =
      html.match(/<div class="data">\s*<h1>([\s\S]*?)<\/h1>/i) ||
      html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) ||
      html.match(/<meta property="og:title" content="([^"]+)"/i);
    return m ? stripTags(m[1]) : '';
  }

  function titleRelevant(pageTit) {
    var want = tokens(title);
    var got = tokens(pageTit);
    var set = {};
    got.forEach(function (t) { set[t] = 1; });
    var hit = 0;
    want.forEach(function (t) { if (set[t]) hit += 1; });
    var pageYear = String(pageTit || '').match(/\b((?:19|20)\d{2})\b/);
    if (year && pageYear && pageYear[1] !== String(year)) return false;
    if (want.length <= 2) return hit >= 1;
    return hit >= 2;
  }

  function attr(block, name) {
    var m = block.match(new RegExp(name + "=['\"]([^'\"]+)['\"]", 'i'));
    return m ? m[1] : '';
  }

  function resolveMovie(pageUrl, html) {
    var re = /<li[^>]*class=['"][^'"]*dooplay_player_option[^'"]*['"][^>]*>[\s\S]*?<\/li>/gi;
    var options = [];
    var m;
    while ((m = re.exec(html))) {
      options.push({
        label: stripTags(m[0]),
        post: attr(m[0], 'data-post'),
        type: attr(m[0], 'data-type'),
        nume: attr(m[0], 'data-nume'),
      });
    }
    var pick = null;
    for (var i = 0; i < options.length; i++) {
      if (/fast stream/i.test(options[i].label) && options[i].post && options[i].nume) {
        pick = options[i];
        break;
      }
    }
    if (!pick) return Promise.resolve([]);
    var body =
      'action=' + encodeURIComponent('doo_player_ajax') +
      '&post=' + encodeURIComponent(pick.post) +
      '&nume=' + encodeURIComponent(pick.nume) +
      '&type=' + encodeURIComponent(pick.type || 'movie');
    return fetchJson(site + '/wp-admin/admin-ajax.php', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
        Referer: pageUrl,
      },
      body: body,
    }).then(function (j) {
      var embed = j && j.embed_url;
      if (!embed) return [];
      var direct = embed;
      try {
        var u = new URL(embed);
        var src = u.searchParams.get('source');
        if (src) direct = src;
      } catch (e) {}
      if (!direct) return [];
      return [{
        url: direct,
        name: 'OnlyKDrama Fast Stream',
        quality: qualityOf(direct),
        headers: { 'User-Agent': ua, Referer: site + '/' },
      }];
    });
  }

  function episodeAnchors(html) {
    var host = filepress.replace(/^https?:\/\//, '');
    var re = new RegExp(
      '<a[^>]+href=["\'](https?:\\/\\/' + escapeRe(host) + '\\/file\\/([A-Za-z0-9]+))["\'][^>]*>([\\s\\S]*?)<\\/a>',
      'gi',
    );
    var out = [];
    var seen = {};
    var m;
    while ((m = re.exec(html))) {
      if (seen[m[2]]) continue;
      seen[m[2]] = 1;
      out.push({ url: m[1], fileId: m[2], text: stripTags(m[3]) });
    }
    return out;
  }

  function episodeMatches(text, hasSeLabels) {
    var ep = escapeRe(String(episode));
    var se = escapeRe(String(season));
    if (new RegExp('(?:^|[^A-Z0-9])S0*' + se + 'E0*' + ep + '(?:[^A-Z0-9]|$)', 'i').test(text)) return true;
    if (hasSeLabels) return false;
    if (season > 1) return false;
    return (
      new RegExp('(?:^|[^A-Z0-9])E0*' + ep + '(?:[^A-Z0-9]|$)', 'i').test(text) ||
      new RegExp('Episode\\s*0*' + ep + '(?:[^0-9]|$)', 'i').test(text)
    );
  }

  function pickEpisode(anchors) {
    var hasSe = anchors.some(function (a) { return /S\d{1,2}E\d{1,2}/i.test(a.text); });
    for (var i = 0; i < anchors.length; i++) {
      if (episodeMatches(anchors[i].text, hasSe)) return anchors[i];
    }
    return null;
  }

  function filepressHeaders(fileId) {
    return {
      Accept: 'application/json, text/plain, */*',
      'Content-Type': 'application/json',
      Origin: filepress,
      Referer: filepress + '/file/' + fileId,
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
    };
  }

  // Upstream FilePress API keeps these misspellings.
  function filepressUrl(data, method) {
    if (method === 'indexDownlaod' || method === 'cloudDownlaod' || method === 'cloudR2Downlaod') {
      return Array.isArray(data) && data[0] ? data[0] : '';
    }
    if (method === 'publicDownlaod' || method === 'publicUserDownlaod') {
      return data ? 'https://drive.google.com/uc?id=' + data : '';
    }
    return '';
  }

  function resolveFilepress(fileId, methods, i) {
    if (i >= methods.length) return Promise.resolve('');
    var method = methods[i];
    var hdrs = filepressHeaders(fileId);
    return fetchJson(filepress + '/api/file/downlaod/', {
      method: 'POST',
      headers: hdrs,
      body: JSON.stringify({ id: fileId, method: method, captchaValue: '' }),
    })
      .then(function (step1) {
        if (!step1 || !step1.status || !step1.data) {
          return resolveFilepress(fileId, methods, i + 1);
        }
        return fetchJson(filepress + '/api/file/downlaod2/', {
          method: 'POST',
          headers: hdrs,
          body: JSON.stringify({ id: step1.data, method: method, captchaValue: '' }),
        }).then(function (step2) {
          var url = step2 && step2.status ? filepressUrl(step2.data, method) : '';
          if (url) return url;
          return resolveFilepress(fileId, methods, i + 1);
        });
      })
      .catch(function () {
        return resolveFilepress(fileId, methods, i + 1);
      });
  }

  function resolveEpisode(html) {
    var pick = pickEpisode(episodeAnchors(html));
    if (!pick) return Promise.resolve([]);
    return resolveFilepress(pick.fileId, ['indexDownlaod', 'publicDownlaod', 'publicUserDownlaod'], 0).then(function (url) {
      if (!url) return [];
      return [{
        url: url,
        name: 'OnlyKDrama ' + (pick.text || 'Episode ' + episode),
        quality: qualityOf(pick.text),
        headers: { 'User-Agent': ua, Referer: filepress + '/' },
      }];
    });
  }

  function tryPages(urls, i) {
    if (i >= urls.length) return Promise.resolve([]);
    return fetchText(urls[i])
      .then(function (html) {
        if (!titleRelevant(pageTitle(html))) return tryPages(urls, i + 1);
        return (isMovie ? resolveMovie(urls[i], html) : resolveEpisode(html)).then(function (rows) {
          if (rows && rows.length) return rows;
          return tryPages(urls, i + 1);
        });
      })
      .catch(function () {
        return tryPages(urls, i + 1);
      });
  }

  return collectCandidates(searchQueries(), 0, [])
    .then(function (urls) { return tryPages(urls, 0); })
    .catch(function () { return []; });
}
