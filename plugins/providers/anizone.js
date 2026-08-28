var SPECS = {
  "base": "https://anizone.to",
  "mapApi": "https://id-mapping-api-malid.hf.space/api/resolve",
  "jikan": "https://api.jikan.moe/v4/anime",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var mapApi = cfg.mapApi;
  var jikan = cfg.jikan;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: base + '/' };
  var isTv = ctx.type !== 'movie';

  function getText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function getJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      return r.json();
    });
  }

  function normalize(str) {
    return String(str || '').toLowerCase().replace(/[^a-z0-9]/g, '').trim();
  }

  function titleAndMapping() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) {
      return getJson(jikan + '/' + fromHost.malId)
        .then(function (j) {
          return {
            title: (j && j.data && j.data.title) || fromHost.title || ctx.title || '',
            mappedEp: fromHost.mappedEp,
            mapping: { mal_id: fromHost.malId, mal_episode: fromHost.mappedEp },
          };
        })
        .catch(function () {
          return {
            title: fromHost.title || ctx.title || '',
            mappedEp: fromHost.mappedEp,
            mapping: { mal_id: fromHost.malId, mal_episode: fromHost.mappedEp },
          };
        });
    }
    if (!isTv) {
      return getJson(
        'https://api.themoviedb.org/3/movie/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
      ).then(function (d) {
        return { title: d.title || d.original_title || '', mappedEp: 1, mapping: null };
      });
    }
    var imdbP = ctx.imdbId
      ? Promise.resolve(String(ctx.imdbId))
      : getJson(
          'https://api.themoviedb.org/3/tv/' +
            encodeURIComponent(String(ctx.tmdbId || '')) +
            '/external_ids?api_key=' +
            encodeURIComponent(tmdbKey),
        )
          .then(function (d) {
            return (d && d.imdb_id) || '';
          })
          .catch(function () {
            return '';
          });
    return imdbP.then(function (imdbId) {
      if (!imdbId) return { title: '', mappedEp: ctx.episode || 1, mapping: null };
      return getJson(
        mapApi +
          '?id=' +
          encodeURIComponent(imdbId) +
          '&s=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&e=' +
          encodeURIComponent(String(ctx.episode || 1)),
      )
        .then(function (mapping) {
          if (!mapping || !mapping.mal_id) return { title: '', mappedEp: ctx.episode || 1, mapping: null };
          return getJson(jikan + '/' + mapping.mal_id).then(function (j) {
            return {
              title: (j && j.data && j.data.title) || '',
              mappedEp: mapping.mal_episode || ctx.episode || 1,
              mapping: mapping,
            };
          });
        })
        .catch(function () {
          return { title: '', mappedEp: ctx.episode || 1, mapping: null };
        });
    });
  }

  function extractCardInfo($, el) {
    var href = $(el).find('a[href*="/anime/"]').first().attr('href');
    if (!href) return null;
    var parts = href.split('/');
    var slug = parts[parts.length - 1] || parts[parts.length - 2];
    var xData = $(el).attr('x-data') || '';
    var titles = {};
    var defaultTitle = (xData.match(/window\.getTitle\(this\.anmTitles,\s*'([^']+)'\)/) || [])[1];
    if (defaultTitle) titles[defaultTitle] = true;
    var jsonMatch = xData.match(/JSON\.parse\('([^']+)'\)/);
    if (jsonMatch) {
      try {
        var jsonStr = jsonMatch[1]
          .replace(/\\\\/g, '\\')
          .replace(/\\u([0-9a-fA-F]{4})/g, function (_, grp) {
            return String.fromCharCode(parseInt(grp, 16));
          })
          .replace(/\\'/g, "'");
        var parsed = JSON.parse(jsonStr);
        Object.keys(parsed || {}).forEach(function (k) {
          if (parsed[k]) titles[parsed[k]] = true;
        });
      } catch (e) {}
    }
    return { slug: slug, titles: Object.keys(titles) };
  }

  function matchCard(cards, animeTitle, baseTitle, season) {
    var normalizedJikan = normalize(animeTitle);
    var normalizedJikanNoSub = normalize(String(animeTitle).split(':')[0]);
    var normalizedBase = normalize(baseTitle);
    var mustNot = season === 1 ? [/season\s*[2-9]/i, /[\s\-][iI]{2,}/, /\s+[2-9](nd|rd|th)/i] : [];
    var must = [];
    if (season === 2) must = [/season\s*2/i, /2nd\s*season/i, /[\s\-]ii\b/i, /\b2\b/];
    else if (season === 3) must = [/season\s*3/i, /3rd\s*season/i, /[\s\-]iii\b/i, /\b3\b/];
    else if (season > 3) must = [new RegExp('season\\s*' + season, 'i'), new RegExp('\\b' + season + '\\b')];
    for (var i = 0; i < cards.length; i++) {
      for (var j = 0; j < cards[i].titles.length; j++) {
        var normTitle = normalize(cards[i].titles[j]);
        var normTitleNoSub = normalize(String(cards[i].titles[j]).split(':')[0]);
        if (normTitle === normalizedJikan || normTitleNoSub === normalizedJikanNoSub) return cards[i].slug;
      }
    }
    for (var c = 0; c < cards.length; c++) {
      var matchesBase = false;
      for (var t = 0; t < cards[c].titles.length; t++) {
        if (normalize(cards[c].titles[t]).indexOf(normalizedBase) >= 0) {
          matchesBase = true;
          break;
        }
      }
      if (!matchesBase) continue;
      if (season === 1) {
        var hasOtherSeason = cards[c].titles.some(function (title) {
          return mustNot.some(function (re) { return re.test(title); });
        });
        if (!hasOtherSeason) return cards[c].slug;
      } else {
        var seasonMatches = cards[c].titles.some(function (title) {
          return must.some(function (re) { return re.test(title); });
        });
        if (seasonMatches) return cards[c].slug;
      }
    }
    return null;
  }

  return titleAndMapping()
    .then(function (state) {
      if (!state.title) return [];
      var searchQuery = isTv
        ? ((state.mapping && state.mapping.anime_title) || String(state.title).split(':')[0].trim())
        : String(state.title).split(':')[0].trim();
      return getText(base + '/anime?search=' + encodeURIComponent(searchQuery)).then(function (searchHtml) {
        var $search = ctx.html(searchHtml);
        var cards = [];
        $search('[x-data*="anmTitles"]').each(function (_, el) {
          var info = extractCardInfo($search, el);
          if (info) cards.push(info);
        });
        var animeSlug = null;
        if (cards.length) {
          animeSlug = isTv
            ? matchCard(cards, state.title, (state.mapping && state.mapping.anime_title) || state.title, ctx.season || 1)
            : (function () {
                var target = normalize(state.title);
                for (var i = 0; i < cards.length; i++) {
                  for (var j = 0; j < cards[i].titles.length; j++) {
                    var n = normalize(cards[i].titles[j]);
                    if (n === target || n.indexOf(target) >= 0 || target.indexOf(n) >= 0) return cards[i].slug;
                  }
                }
                return cards[0] ? cards[0].slug : null;
              })();
        }
        if (!animeSlug) return [];
        return getText(base + '/anime/' + animeSlug + '/' + state.mappedEp).then(function (episodeHtml) {
          var $ep = ctx.html(episodeHtml);
          var masterUrl = $ep('media-player').attr('src') || (episodeHtml.match(/https:\/\/[^"']+\/master\.m3u8/) || [])[0];
          if (!masterUrl) return [];
          var subtitles = [];
          $ep('track').each(function (_, el) {
            var src = $ep(el).attr('src');
            var kind = $ep(el).attr('kind');
            if (src && (kind === 'subtitles' || kind === 'captions' || /\.ass$|\.vtt$/i.test(src))) {
              subtitles.push({
                url: src,
                lang: $ep(el).attr('srclang') || 'en',
              });
            }
          });
          var format = 'Sub';
          $ep('button').each(function (_, el) {
            var text = $ep(el).text();
            if (text.indexOf('Audio:') >= 0) {
              var hasJapanese = text.indexOf('Japanese') >= 0;
              var hasEnglish = text.indexOf('English') >= 0;
              if (hasEnglish && !hasJapanese) format = 'Dub';
              else if (hasEnglish && hasJapanese) format = 'Sub & Dub';
            }
          });
          return [
            {
              url: masterUrl,
              name: 'AniZone',
              quality: 'Multi',
              headers: headers,
              subtitles: subtitles,
              language: format,
            },
          ];
        });
      });
    })
    .catch(function () {
      return [];
    });
}
