function extract(ctx) {
  var cfg = ctx.config || {};
  var mainUrl = (cfg.base || 'https://allmovieland.one').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,application/xhtml+xml,*/*', 'Accept-Language': 'en-US,en;q=0.5' };
  var isTv = ctx.type !== 'movie';

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) { return r.text(); });
  }

  function getTmdb() {
    var kind = isTv ? 'tv' : 'movie';
    return ctx.fetch(
      'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' + encodeURIComponent(tmdbKey) + '&append_to_response=external_ids',
      { headers: { 'User-Agent': ua, Accept: 'application/json' } },
    ).then(function (r) { return r.json(); })
      .then(function (d) {
        var title = isTv ? d.name : d.title;
        var date = (d.release_date || d.first_air_date) || '';
        var year = date ? parseInt(date.split('-')[0], 10) : null;
        return { title: title, year: year, imdbId: (d.external_ids && d.external_ids.imdb_id) || null };
      });
  }

  function normTitle(t) {
    return String(t || '').toLowerCase()
      .replace(/\b(the|a|an)\b/g, '').replace(/[:\-_]/g, ' ')
      .replace(/[^\w\s]/g, '').replace(/\s+/g, ' ').trim();
  }

  function titleScore(a, b) {
    var na = normTitle(a).split(/\s+/).filter(Boolean);
    var nb = normTitle(b).split(/\s+/).filter(Boolean);
    if (!na.length || !nb.length) return 0;
    var sb = new Set(nb);
    var inter = na.filter(function (w) { return sb.has(w); });
    var union = new Set(na.concat(nb));
    var score = inter.length / union.size;
    if (na.every(function (w) { return sb.has(w); })) score += 0.2;
    return score;
  }

  function bestMatch(info, results) {
    var best = null, bestScore = 0;
    results.forEach(function (r) {
      var score = titleScore(info.title, r.title);
      if (info.year && r.year) {
        var diff = Math.abs(info.year - r.year);
        if (diff === 0) score += 0.2;
        else if (diff <= 1) score += 0.1;
        else if (diff > 5) score -= 0.3;
      }
      if (score > bestScore && score > 0.3) { bestScore = score; best = r; }
    });
    return best;
  }

  return getTmdb().then(function (info) {
    if (!info || !info.title) return [];
    var searchUrl = mainUrl + '/index.php?story=' + encodeURIComponent(info.title) + '&do=search&subaction=search';
    return fetchText(searchUrl).then(function (html) {
      var $ = ctx.html(html);
      var results = [];
      $('article.short-mid').each(function () {
        var title = $(this).find('a > h3').text().trim();
        var href = $(this).find('a').attr('href') || '';
        var ym = title.match(/\((\d{4})\)/);
        results.push({ title: title, href: href, year: ym ? parseInt(ym[1], 10) : null });
      });
      if (!results.length) return [];
      var match = bestMatch(info, results);
      if (!match) return [];
      return fetchText(match.href).then(function (docHtml) {
        var doc$ = ctx.html(docHtml);
        var tabsScript = doc$('div.tabs__content script').html() || '';
        var playerDomainM = tabsScript.match(/const AwsIndStreamDomain\s*=\s*'([^']+)'/);
        var idM = tabsScript.match(/src:\s*'([^']+)'/);
        if (!playerDomainM || !idM) return [];
        var playerDomain = playerDomainM[1].replace(/\/$/, '');
        var embedLink = playerDomain + '/play/' + idM[1];
        return fetchText(embedLink, { Referer: match.href }).then(function (embedHtml) {
          var embed$ = ctx.html(embedHtml);
          var lastScript = embed$('body > script').last().html() || '';
          var p3M = lastScript.match(/let\s+p3\s*=\s*(\{.*?\});/);
          if (!p3M) return [];
          var json;
          try { json = JSON.parse(p3M[1]); } catch (e) { return []; }
          var fileUrl = json.file.replace(/\\\//g, '/');
          if (!fileUrl.startsWith('http')) fileUrl = playerDomain + fileUrl;
          return ctx.fetch(fileUrl, {
            method: 'POST',
            headers: Object.assign({}, hdrs, { 'X-CSRF-TOKEN': json.key, Referer: embedLink }),
          }).then(function (r) { return r.text(); }).then(function (fileText) {
            var parsed;
            try { parsed = JSON.parse(fileText.replace(/,\]/g, ']')); } catch (e) { return []; }
            var targetFiles = [];
            if (!isTv) {
              targetFiles = parsed.filter(function (s) { return s && s.file; });
            } else {
              var seasonData = parsed.find(function (s) {
                var m = (s.title || '').match(/Season\s*(\d+)/i);
                return m ? parseInt(m[1], 10) === (ctx.season || 1) : s.id == (ctx.season || 1);
              });
              if (seasonData && seasonData.folder) {
                var ep = ctx.episode || 1;
                var epData = seasonData.folder.find(function (e) {
                  var m = (e.title || '').match(/Episode\s*(\d+)/i);
                  return m ? parseInt(m[1], 10) === ep : e.episode == ep;
                });
                if (epData && epData.folder) targetFiles = epData.folder.filter(function (s) { return s && s.file; });
              }
            }
            if (!targetFiles.length) return [];
            return Promise.all(targetFiles.map(function (fileObj) {
              var playlistFile = fileObj.file.replace(/^~/, '');
              var playlistUrl = playerDomain + '/playlist/' + playlistFile + '.txt';
              return ctx.fetch(playlistUrl, {
                method: 'POST',
                headers: Object.assign({}, hdrs, { 'X-CSRF-TOKEN': json.key, Referer: embedLink }),
              }).then(function (r) { return r.text(); }).then(function (m3u8Url) {
                m3u8Url = (m3u8Url || '').trim();
                if (!m3u8Url.startsWith('http')) return null;
                return {
                  name: 'AllMovieLand',
                  url: m3u8Url,
                  quality: fileObj.title || 'Unknown',
                  headers: { Referer: playerDomain + '/', Origin: playerDomain, 'User-Agent': ua },
                };
              }).catch(function () { return null; });
            })).then(function (items) { return items.filter(Boolean); });
          });
        });
      });
    });
  }).catch(function () { return []; });
}
