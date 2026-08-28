var SPECS = {
  "origin": "https://vidsrc.sbs",
  "nxshaOrigin": "https://web.nxsha.app",
  "nxshaKey": "S8x!Jk4ZP1uG8$my",
  "videasyApi": "https://api.speedracelight.com",
  "videasyOrigin": "https://player.videasy.to"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var origin = cfg.origin;
  var nxshaOrigin = cfg.nxshaOrigin;
  var nxshaKey = cfg.nxshaKey;
  var videasyApi = cfg.videasyApi;
  var videasyOrigin = cfg.videasyOrigin;
  var tmdbId = String(ctx.tmdbId);
  var season = String(ctx.season || 1);
  var episode = String(ctx.episode || 1);
  var isMovie = ctx.type === 'movie';
  var embed =
    isMovie
      ? origin + '/embed/movie/' + tmdbId
      : origin + '/embed/tv/' + tmdbId + '/' + season + '/' + episode;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: origin + '/', Accept: 'text/html,application/xhtml+xml' };
  var CryptoJS = ctx.crypto || globalThis.CryptoJS;

  ctx.log('start ' + embed);

  function b64url(b64) {
    return String(b64 || '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  function fromB64url(str) {
    var b64 = String(str || '')
      .replace(/-/g, '+')
      .replace(/_/g, '/');
    while (b64.length % 4) b64 += '=';
    return b64;
  }

  function extractServersJson(html) {
    var marker = html.indexOf('servers:');
    if (marker < 0) return null;
    var start = html.indexOf('[', marker);
    if (start < 0) return null;
    var depth = 0;
    for (var i = start; i < html.length; i++) {
      var c = html.charAt(i);
      if (c === '[') depth++;
      else if (c === ']') {
        depth--;
        if (depth === 0) return html.substring(start, i + 1);
      }
    }
    return null;
  }

  function parseServers(html) {
    var raw = extractServersJson(html);
    if (!raw) return [];
    try {
      var decoded = JSON.parse(raw);
      if (!Array.isArray(decoded)) return [];
      return decoded.filter(function (item) {
        if (!item || typeof item !== 'object') return false;
        var name = String(item.name || '').trim();
        return name && (item.movie_url || item.tv_url || item.url || item.src || item.embed);
      });
    } catch (e) {
      return [];
    }
  }

  function expandServer(server) {
    var name = String(server.name || server.title || 'VidSrc.sbs');
    var tpl = isMovie
      ? String(server.movie_url || server.url || server.src || server.embed || '')
      : String(server.tv_url || server.url || server.src || server.embed || '');
    var url = tpl
      .replace(/\{tmdb_id\}/g, tmdbId)
      .replace(/\{season\}/g, season)
      .replace(/\{episode\}/g, episode);
    return { name: name, url: url };
  }

  function nxshaEncode(obj) {
    var payload = Object.assign({}, obj, {
      _req_ts: Date.now(),
      _req_salt: Math.random().toString(36).slice(2, 12),
    });
    return b64url(CryptoJS.AES.encrypt(JSON.stringify(payload), nxshaKey).toString());
  }

  function preferHlsMaster(url) {
    var u = String(url || '');
    if (!/index-s\d+p-v\d+-a\d+\.m3u8/i.test(u)) return u;
    var withSd = u.replace(/\/sd\/\d+\/index-s\d+p-v\d+-a\d+\.m3u8/i, '/master.m3u8');
    if (withSd !== u) return withSd;
    return u.replace(/\/index-s\d+p-v\d+-a\d+\.m3u8/i, '/master.m3u8');
  }

  function nxshaDecode(hash) {
    if (!hash) return null;
    var text = CryptoJS.AES.decrypt(fromB64url(hash), nxshaKey).toString(CryptoJS.enc.Utf8);
    if (!text) return null;
    try {
      var obj = JSON.parse(text);
      delete obj._req_ts;
      delete obj._req_salt;
      return obj;
    } catch (e) {
      return null;
    }
  }

  function nxshaGet(path, queryObj) {
    var q = nxshaEncode(queryObj);
    return ctx
      .fetch(nxshaOrigin + path + '?q=' + encodeURIComponent(q), {
        headers: { 'User-Agent': ua, Accept: '*/*', Referer: nxshaOrigin + '/' },
      })
      .then(function (r) {
        if (r.status < 200 || r.status >= 300) {
          ctx.log('nxsha ' + path + ' http ' + r.status);
          return null;
        }
        return r.json();
      })
      .then(function (j) {
        return j ? nxshaDecode(j._hash) : null;
      })
      .catch(function (e) {
        ctx.error('nxsha ' + path + ': ' + (e && e.message ? e.message : e));
        return null;
      });
  }

  function pickNxshaSource(sources) {
    if (!Array.isArray(sources)) return null;
    for (var i = 0; i < sources.length; i++) {
      var s = sources[i];
      if (s && s.type === 'm3u8' && !s.isEmbed && s.url) return s;
    }
    for (var j = 0; j < sources.length; j++) {
      var p = sources[j];
      if (p && p.type === 'mp4' && !p.isEmbed && p.url) return p;
    }
    for (var k = 0; k < sources.length; k++) {
      var m = sources[k];
      if (m && m.url && !m.isEmbed) return m;
    }
    return null;
  }

  function nxshaStreams(label) {
    var base = {
      tmdbId: tmdbId,
      type: isMovie ? 'movie' : 'tv',
      imdb_id: '',
      season: season,
      episode: episode,
      method: 'stream',
    };
    return nxshaGet('/api/servers', base).then(function (serversRes) {
      var servers = (serversRes && serversRes.servers) || [];
      ctx.log('nxsha servers=' + servers.length);
      if (!servers.length) return [];
      return Promise.all(
        servers.slice(0, 12).map(function (server) {
          return nxshaGet(
            '/api/sources',
            Object.assign({}, base, { provider: server.scraper || server.id }),
          ).then(function (srcRes) {
            var chosen = pickNxshaSource(srcRes && srcRes.sources);
            if (!chosen || !chosen.url) return null;
            var hdrs = chosen.headers || {};
            var referer = hdrs.Referer || hdrs.referer || nxshaOrigin + '/';
            return {
              url: chosen.url,
              name: (label || 'VidSrc.sbs') + ' · ' + (server.name || server.scraper || 'nxsha'),
              quality: chosen.quality || chosen.label || '',
              headers: Object.assign(
                { 'User-Agent': ua, Referer: referer },
                hdrs.Origin || hdrs.origin ? { Origin: hdrs.Origin || hdrs.origin } : {},
              ),
            };
          });
        }),
      ).then(function (rows) {
        return rows.filter(Boolean);
      });
    });
  }

  function videasyNest(label) {
    var playHeaders = {
      'User-Agent': ua,
      Referer: videasyOrigin + '/',
      Origin: videasyOrigin,
    };
    var apiHeaders = Object.assign({}, playHeaders, {
      Accept: 'application/json, text/plain, */*',
    });
    return ctx
      .fetch(videasyApi + '/seed?mediaId=' + encodeURIComponent(tmdbId), { headers: apiHeaders })
      .then(function (r) {
        return r.json();
      })
      .then(function (seedJson) {
        var seed = seedJson && seedJson.seed;
        if (!seed) {
          ctx.log('videasy nest: no seed');
          return [];
        }
        var q =
          'title=' +
          encodeURIComponent(ctx.title || '') +
          '&mediaType=' +
          (isMovie ? 'movie' : 'tv') +
          '&tmdbId=' +
          encodeURIComponent(tmdbId) +
          '&seasonId=' +
          season +
          '&episodeId=' +
          episode +
          '&enc=2&seed=' +
          encodeURIComponent(seed);
        if (ctx.year) q += '&year=' + encodeURIComponent(String(ctx.year).substring(0, 4));
        return ctx
          .fetch(videasyApi + '/cdn/sources-with-title?' + q, { headers: apiHeaders })
          .then(function (r) {
            return r.text();
          })
          .then(function (body) {
            body = (body || '').trim();
            if (!body || body.length < 50 || body.charAt(0) === '{' || body.charAt(0) === '<') {
              return [];
            }
            var json = JSON.parse(ctx.crypto.streamDecrypt(body, seed, tmdbId));
            var srcs = (json && json.sources) || [];
            return srcs
              .map(function (s) {
                var url = preferHlsMaster((s.url || s.file || '').toString());
                if (!url) return null;
                return {
                  url: url,
                  name: (label || 'VidSrc.sbs') + ' · Videasy',
                  quality: (s.quality || s.label || '').toString(),
                  headers: playHeaders,
                };
              })
              .filter(Boolean);
          });
      })
      .catch(function (e) {
        ctx.error('videasy nest: ' + (e && e.message ? e.message : e));
        return [];
      });
  }

  function handleNested(server) {
    var resolved = expandServer(server);
    var u = resolved.url;
    var name = resolved.name;
    if (!u) return Promise.resolve([]);
    ctx.log('mirror ' + name + ' ' + u.slice(0, 100));
    if (/\.m3u8|\.mp4|\.mpd/i.test(u) || /ice.*m3u8=/i.test(u)) {
      return Promise.resolve([
        { url: u, name: name, headers: { 'User-Agent': ua, Referer: origin + '/' } },
      ]);
    }
    if (/nxsha\.app/i.test(u)) return nxshaStreams(name);
    if (/videasy\.(to|net)/i.test(u)) return videasyNest(name);
    return ctx.hop(u).then(function (rows) {
      if (rows && rows.length) return rows;
      ctx.log('hop empty for ' + name);
      return [];
    });
  }

  function fromCfg(html) {
    var servers = parseServers(html);
    ctx.log('CFG.servers=' + servers.length);
    if (!servers.length) return Promise.resolve([]);
    return Promise.all(servers.slice(0, 8).map(handleNested)).then(function (groups) {
      return [].concat.apply([], groups).filter(function (r) {
        return r && r.url;
      });
    });
  }

  return ctx
    .fetch(embed, { headers: headers })
    .then(function (r) {
      ctx.log('embed http ' + r.status);
      return r.text();
    })
    .then(function (html) {
      if (/just a moment|cf-challenge|challenge-platform/i.test(html)) {
        ctx.log('cloudflare challenge — falling back to nxsha API');
        return nxshaStreams('VidSrc.sbs');
      }
      return fromCfg(html).then(function (cfgRows) {
        if (cfgRows.length) {
          ctx.log('streams=' + cfgRows.length);
          return cfgRows;
        }
        ctx.log('CFG empty — nxsha API fallback (Decryptor)');
        return nxshaStreams('VidSrc.sbs').then(function (rows) {
          ctx.log('streams=' + rows.length);
          return rows;
        });
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return nxshaStreams('VidSrc.sbs').then(function (rows) {
        ctx.log('streams=' + rows.length);
        return rows;
      });
    });
}
