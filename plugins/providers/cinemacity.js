var SPECS = {
  "base": "https://cinemacity.cc",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var cookie = cfg.cookie || 'dle_user_id=32729; dle_password=894171c6a8dab18ee594d5c652009a35;';
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36';
  var isTv = ctx.type !== 'movie';

  function hdrs(extra) {
    return Object.assign({ 'User-Agent': ua, Cookie: cookie, Referer: base + '/' }, extra || {});
  }

  function fetchText(url) {
    return ctx.fetch(url, { headers: hdrs() }).then(function (r) { return r.text(); });
  }

  function atobCompat(s) {
    try { return atob(s); } catch (e) { return ''; }
  }

  function qualityFromUrl(url) {
    var low = String(url || '').toLowerCase();
    if (/2160p|4k/i.test(low)) return '4K';
    if (/1080p/i.test(low)) return '1080p';
    if (/720p/i.test(low)) return '720p';
    if (/480p/i.test(low)) return '480p';
    if (/360p/i.test(low)) return '360p';
    return 'HD';
  }

  function parseSubs(raw) {
    var subs = [];
    if (!raw || typeof raw !== 'string') return subs;
    raw.split(',').forEach(function (entry) {
      var m = entry.trim().match(/\[(.+?)\](https?:\/\/.+)/);
      if (m) subs.push({ url: m[2], language: m[1], name: m[1], headers: { Referer: base + '/' } });
    });
    return subs;
  }

  function addStream(out, url, title, quality, subtitles) {
    if (!url || !/^https?:/i.test(url) || url.length < 15) return;
    out.push({
      name: 'CinemaCity',
      url: url,
      quality: quality || qualityFromUrl(url),
      headers: hdrs(),
      subtitles: subtitles || [],
    });
  }

  function processFile(out, str, title, subtitles) {
    if (String(str).indexOf('.urlset/master.m3u8') >= 0) {
      addStream(out, str, title, 'Auto', subtitles);
      return;
    }
    var parts = String(str).indexOf('[') >= 0 ? String(str).split(',') : [str];
    parts.forEach(function (u) {
      var m = String(u).match(/\[(.*?)\](.*)/);
      if (m) addStream(out, m[2], title, m[1], subtitles);
      else addStream(out, u, title, qualityFromUrl(u), subtitles);
    });
  }

  return ctx.fetch(
    'https://api.themoviedb.org/3/' + (isTv ? 'tv' : 'movie') + '/' + encodeURIComponent(String(ctx.tmdbId || '')) +
      '?api_key=' + encodeURIComponent(tmdbKey) + '&append_to_response=external_ids',
    { headers: { Accept: 'application/json', 'User-Agent': ua } },
  ).then(function (r) { return r.json(); }).then(function (tmdb) {
    var title = isTv ? tmdb.name : tmdb.title;
    var imdbId = (tmdb.external_ids && tmdb.external_ids.imdb_id) || tmdb.imdb_id;
    if (!title && !imdbId) return [];
    var query = imdbId || title;
    var searchUrl = base + '/?do=search&subaction=search&search_start=0&full_search=0&story=' + encodeURIComponent(query);
    return fetchText(searchUrl).then(function (html) {
      var $ = ctx.html(html);
      var mediaUrl = '';
      $('div.dar-short_item').each(function () {
        if (mediaUrl) return;
        var anchor = $(this).find('a').filter(function () {
          return String($(this).attr('href') || '').indexOf('.html') >= 0;
        }).first();
        if (!anchor.length) return;
        var href = anchor.attr('href') || '';
        var found = anchor.text().toLowerCase();
        if ((imdbId && html.indexOf(imdbId) >= 0) || found.indexOf(String(title).toLowerCase()) >= 0 ||
            String(title).toLowerCase().indexOf(found) >= 0) mediaUrl = href;
      });
      if (!mediaUrl && imdbId && query !== title) {
        return fetchText(base + '/?do=search&subaction=search&search_start=0&full_search=0&story=' + encodeURIComponent(title))
          .then(function (html2) {
            var $2 = ctx.html(html2);
            $2('div.dar-short_item').each(function () {
              if (mediaUrl) return;
              var anchor = $2(this).find('a').filter(function () {
                return String($2(this).attr('href') || '').indexOf('.html') >= 0;
              }).first();
              if (anchor.length) mediaUrl = anchor.attr('href') || '';
            });
            return mediaUrl;
          });
      }
      return mediaUrl;
    }).then(function (mediaUrl) {
      if (!mediaUrl) return [];
      return fetchText(mediaUrl).then(function (pageHtml) {
        var $p = ctx.html(pageHtml);
        var fileData = null;
        var globalSubs = null;
        $p('script').each(function () {
          if (fileData) return;
          var script = $p(this).html() || '';
          if (script.indexOf('atob') < 0) return;
          var regex = /atob\s*\(\s*(['"])(.*?)\1\s*\)/g;
          var m;
          while ((m = regex.exec(script)) !== null) {
            try {
              var decoded = atobCompat(m[2]);
              var fm = decoded.match(/file\s*:\s*(['"])(.*?)\1/s) ||
                decoded.match(/file\s*:\s*(\[.*?\])/s) ||
                decoded.match(/file\s*:\s*(\{.*?\})/s);
              var sm = decoded.match(/subtitle\s*:\s*(['"])(.*?)\1/s);
              if (fm) {
                var raw = fm[2] || fm[1];
                if (raw && raw.length > 5) {
                  if (raw.charAt(0) === '[' || raw.charAt(0) === '{') {
                    try { fileData = JSON.parse(raw.replace(/\\(.)/g, '$1')); }
                    catch (e) { try { fileData = JSON.parse(raw); } catch (e2) { fileData = raw; } }
                  } else fileData = raw;
                }
              }
              if (sm) globalSubs = sm[2];
              if (fileData) return false;
            } catch (e) {}
          }
        });
        if (!fileData) return [];
        var streams = [];
        if (!isTv) {
          if (Array.isArray(fileData)) {
            var obj = fileData.find(function (f) { return !f.folder && f.file; }) || fileData[0];
            if (obj && obj.file) processFile(streams, obj.file, title, parseSubs(obj.subtitle || globalSubs));
          } else if (typeof fileData === 'string') {
            processFile(streams, fileData, title, parseSubs(globalSubs));
          }
        } else {
          var season = ctx.season || 1;
          var episode = ctx.episode || 1;
          if (Array.isArray(fileData)) {
            var sObj = fileData.find(function (s) {
              var t = s.title || '';
              return t.indexOf('Season ' + season) >= 0 || t.indexOf('S' + season) >= 0;
            });
            if (sObj && sObj.folder) {
              var eObj = sObj.folder.find(function (e) {
                var t = e.title || '';
                return t.indexOf('Episode ' + episode) >= 0 || t.indexOf('E' + episode) >= 0;
              });
              if (eObj && eObj.file) {
                processFile(streams, eObj.file, title + ' S' + season + 'E' + episode, parseSubs(eObj.subtitle || sObj.subtitle || globalSubs));
              }
            }
          }
        }
        return streams;
      });
    });
  }).catch(function () { return []; });
}
