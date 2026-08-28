var SPECS = {
  "base": "https://animenosub.to",
  "mapApi": "https://id-mapping-api-malid.hf.space/api/resolve",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var mapApi = cfg.mapApi;
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var armBase = (cfg.armBase || 'https://arm.haglund.dev/api/v2').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Accept: 'text/html,application/xhtml+xml' };
  var isTv = ctx.type !== 'movie';
  var epNum = isTv ? ctx.episode || 1 : 1;
  var NOVA_KEY = '6b69656d7469656e6d75613931316361';
  var NOVA_IV = '313233343536373839306f6975797472';

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}, { Accept: 'application/json' }) }).then(function (r) {
      return r.json();
    });
  }

  function normalize(str) {
    return String(str || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '')
      .trim();
  }

  function decodeEntities(s) {
    return String(s || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>');
  }

  function resolveMal() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) return Promise.resolve(fromHost.malId);
    if (!isTv) {
      return fetchJson(
        'https://api.themoviedb.org/3/movie/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
      )
        .then(function (d) {
          var title = d.title || d.original_title || '';
          if (!title) return null;
          return fetchJson(jikan + '?q=' + encodeURIComponent(title) + '&type=movie&limit=1').then(function (j) {
            return j && j.data && j.data[0] ? { mal: j.data[0].mal_id, ep: 1, title: title } : null;
          });
        })
        .catch(function () {
          return null;
        });
    }
    var imdbP = ctx.imdbId
      ? Promise.resolve(String(ctx.imdbId))
      : fetchJson(
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
      if (!imdbId) return null;
      return fetchJson(
        mapApi +
          '?id=' +
          encodeURIComponent(imdbId) +
          '&s=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&e=' +
          encodeURIComponent(String(epNum)),
      )
        .then(function (m) {
          if (!m || !m.mal_id) return null;
          return fetchJson(jikan + '/' + m.mal_id).then(function (j) {
            return {
              mal: m.mal_id,
              ep: m.mal_episode || epNum,
              title: (j && j.data && j.data.title) || '',
            };
          });
        })
        .catch(function () {
          return null;
        });
    });
  }

  function search(query) {
    return ctx
      .fetch(base + '/wp-admin/admin-ajax.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent': ua,
          Origin: base,
          Referer: base + '/',
        },
        body: 'action=ts_ac_do_search&ts_ac_query=' + encodeURIComponent(query),
      })
      .then(function (r) {
        return r.json();
      })
      .then(function (data) {
        var results = [];
        var items = (((data || {}).anime || [])[0] || {}).all || [];
        for (var i = 0; i < items.length; i++) {
          var item = items[i];
          var slugM = (item.post_link || '').match(/\/anime\/([^/]+)\/?$/);
          if (!slugM) continue;
          results.push({ slug: slugM[1], text: item.post_title || slugM[1].replace(/-/g, ' ') });
        }
        return results;
      })
      .catch(function () {
        return [];
      });
  }

  function pickSlug(results, query) {
    if (!results.length) return null;
    var target = normalize(query);
    for (var i = 0; i < results.length; i++) {
      if (normalize(results[i].text) === target || normalize(results[i].text).indexOf(target) >= 0) return results[i].slug;
    }
    return results[0].slug;
  }

  function scrapeSeries(slug) {
    return fetchText(base + '/anime/' + slug + '/').then(function (html) {
      var isSlugDub = /-dub$/.test(slug);
      var episodes = [];
      var seen = {};
      var re = /<li\b[^>]*data-index="\d+"[^>]*>[\s\S]*?<a\s+href="(https?:\/\/animenosub\.to\/[^"]+)"[\s\S]*?<div\s+class="epl-num">([^<]+)<\/div>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var epUrl = decodeEntities(m[1]);
        var label = m[2].trim();
        var number;
        if (/^movie$/i.test(label)) number = 1;
        else {
          var n = parseFloat(label);
          number = Number.isFinite(n) && n >= 1 ? Math.round(n) : null;
        }
        if (number === null || seen[number]) continue;
        seen[number] = true;
        var isDub = isSlugDub || /-dub(?:$|\/)/.test(epUrl);
        episodes.push({ number: number, epUrl: epUrl, hasSub: !isDub, hasDub: isDub });
      }
      return episodes;
    });
  }

  function scrapeEmbeds(epUrl) {
    return fetchText(epUrl).then(function (html) {
      var streams = [];
      var re = /<option\s+value="([A-Za-z0-9+/=]+)"\s+data-index="\d+"[^>]*>([^<]+)<\/option>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var serverName = m[2].trim();
        if (!serverName || /select video server/i.test(serverName)) continue;
        try {
          var decoded = atob(m[1]);
          var srcM = decoded.match(/src=["']([^"']+)["']/i);
          if (!srcM) continue;
          streams.push({ url: srcM[1], server: serverName });
        } catch (e) {}
      }
      if (!streams.length) {
        var iframeRe = /<iframe[^>]+src=["']([^"']+)["'][^>]*>/gi;
        while ((m = iframeRe.exec(html)) !== null) {
          if (/vidmoly|vtbe|streamtape|dood|filemoon|upn\.one|bysesa/i.test(m[1])) {
            streams.push({ url: m[1], server: 'Direct' });
            break;
          }
        }
      }
      return streams;
    });
  }

  function resolveVidmoly(embedUrl) {
    var url = embedUrl.indexOf('//') === 0 ? 'https:' + embedUrl : embedUrl;
    return fetchText(url, { Referer: base + '/' }).then(function (html) {
      var m = html.match(/sources:\s*\[\s*\{\s*file:\s*['"]([^'"]+\.m3u8[^'"]*)['"]/);
      return m ? [m[1]] : [];
    });
  }

  function resolveNova(embedUrl) {
    var idM = embedUrl.match(/upn\.one\/#([A-Za-z0-9]+)/i);
    if (!idM) return Promise.resolve([]);
    return fetchText('https://nova.upn.one/api/v1/video?id=' + idM[1] + '&w=1920&h=1080&r=', {
      Referer: 'https://nova.upn.one/',
    }).then(function (hex) {
      hex = hex.trim();
      if (!hex || !ctx.crypto || !ctx.crypto.AES) return [];
      var decrypted = ctx.crypto.AES.decrypt(
        { ciphertext: ctx.crypto.enc.Hex.parse(hex) },
        ctx.crypto.enc.Hex.parse(NOVA_KEY),
        { iv: ctx.crypto.enc.Hex.parse(NOVA_IV), mode: ctx.crypto.mode.CBC, padding: ctx.crypto.pad.Pkcs7 },
      );
      var text = ctx.crypto.enc.Utf8.stringify(decrypted);
      var data = JSON.parse(text);
      var m3u8 = data.cf || data.source;
      return m3u8 ? [m3u8] : [];
    });
  }

  function isByse(url) {
    return /bysesayeveum\.com\/e\//i.test(url);
  }
  function isVidmoly(url) {
    return /vidmoly\.(net|biz|to)/i.test(url);
  }
  function isNova(url) {
    return /upn\.one/i.test(url);
  }

  function resolveEmbeds(embeds) {
    return Promise.all(
      embeds.map(function (stream) {
        var url = stream.url;
        if (isVidmoly(url)) {
          return resolveVidmoly(url)
            .then(function (urls) {
              return urls.map(function (u) {
                return {
                  url: u,
                  name: 'AnimeNoSub ' + stream.server,
                  headers: { 'User-Agent': ua, Referer: 'https://vidmoly.biz/' },
                  language: 'Sub',
                };
              });
            })
            .catch(function () {
              return ctx.hop(url);
            });
        }
        if (isNova(url)) {
          return resolveNova(url)
            .then(function (urls) {
              return urls.map(function (u) {
                return {
                  url: u,
                  name: 'AnimeNoSub ' + stream.server,
                  headers: { 'User-Agent': ua, Referer: 'https://nova.upn.one/' },
                  language: 'Sub',
                };
              });
            })
            .catch(function () {
              return ctx.hop(url);
            });
        }
        if (isByse(url)) {
          return ctx.hop(url).then(function (rows) {
            return rows.map(function (r) {
              return Object.assign({}, r, { name: 'AnimeNoSub ' + stream.server });
            });
          });
        }
        return ctx.hop(url).then(function (rows) {
          return rows.length
            ? rows.map(function (r) {
                return Object.assign({}, r, { name: 'AnimeNoSub ' + stream.server });
              })
            : [{ url: url, name: 'AnimeNoSub ' + stream.server, headers: hdrs }];
        });
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  return resolveMal()
    .then(function (mapped) {
      if (!mapped) return [];
      var query = (mapped.title || String(ctx.title || '')).split(':')[0].trim();
      if (!query) return [];
      return search(query).then(function (results) {
        var slug = pickSlug(results, query);
        if (!slug) return [];
        return scrapeSeries(slug).then(function (episodes) {
          var ep =
            episodes.find(function (e) {
              return e.number === mapped.ep && e.hasSub;
            }) ||
            episodes.find(function (e) {
              return e.number === mapped.ep;
            });
          if (!ep) return [];
          return scrapeEmbeds(ep.epUrl).then(resolveEmbeds);
        });
      });
    })
    .catch(function () {
      return [];
    });
}
