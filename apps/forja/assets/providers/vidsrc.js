function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://vidsrc.xyz';
  var tmdbId = String(ctx.tmdbId);
  var embed =
    ctx.type === 'movie'
      ? origin + '/embed/movie/' + tmdbId
      : origin +
        '/embed/tv/' +
        tmdbId +
        '/' +
        (ctx.season || 1) +
        '/' +
        (ctx.episode || 1);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: origin + '/' };

  ctx.log('start ' + embed);

  function parseMaster(m3u8Content, masterUrl) {
    var lines = String(m3u8Content || '')
      .split('\n')
      .map(function (l) {
        return l.trim();
      });
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].indexOf('#EXT-X-STREAM-INF:') === 0) {
        var q = 'Auto';
        var res = lines[i].match(/RESOLUTION=(\d+x\d+)/i);
        if (res) {
          var h = parseInt((res[1].split('x')[1] || '0'), 10);
          if (h >= 2160) q = '4K';
          else if (h >= 1080) q = '1080p';
          else if (h >= 720) q = '720p';
          else if (h >= 480) q = '480p';
          else q = res[1];
        }
        if (i + 1 < lines.length && lines[i + 1] && lines[i + 1].charAt(0) !== '#') {
          var part = lines[i + 1];
          var full = part;
          try {
            full = new URL(part, masterUrl).toString();
          } catch (e) {}
          out.push({
            url: full,
            name: 'VSEmbed ' + q,
            quality: q,
            headers: { 'User-Agent': ua, Referer: origin + '/' },
          });
          i++;
        }
      }
    }
    if (!out.length && /#EXTM3U/i.test(m3u8Content)) {
      out.push({
        url: masterUrl,
        name: 'VSEmbed',
        headers: { 'User-Agent': ua, Referer: origin + '/' },
      });
    }
    return out;
  }

  function prorcp(base, hash) {
    var url = base + '/prorcp/' + hash;
    ctx.log('prorcp ' + url);
    return ctx.fetch(url, { headers: Object.assign({}, headers, { Referer: base + '/' }) }).then(function (r) {
      return r.text();
    }).then(function (body) {
      var m = body.match(/file:\s*'([^']+)'/);
      if (!m) {
        ctx.log('prorcp no file');
        return [];
      }
      return ctx
        .fetch(m[1], { headers: { 'User-Agent': ua, Referer: url, Accept: '*/*' } })
        .then(function (r) {
          return r.text().then(function (t) {
            return parseMaster(t, m[1]);
          });
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
        ctx.log('cloudflare challenge');
        return [];
      }
      var iframe = (html.match(/<iframe[^>]*src=["']([^"']+)["']/i) || [])[1] || '';
      var base = origin;
      if (iframe) {
        try {
          var abs = iframe.indexOf('//') === 0 ? 'https:' + iframe : iframe;
          base = new URL(abs, origin).origin;
          ctx.log('iframe base ' + base);
        } catch (e) {}
      }
      var servers = [];
      String(html).replace(
        /class=["'][^"']*server[^"']*["'][^>]*data-hash=["']([^"']+)["'][^>]*>([^<]*)</gi,
        function (_, hash, name) {
          servers.push({ hash: hash, name: String(name || '').trim() || 'Server' });
          return _;
        },
      );
      String(html).replace(/data-hash=["']([^"']+)["']/gi, function (_, hash) {
        if (!servers.some(function (s) {
          return s.hash === hash;
        }))
          servers.push({ hash: hash, name: 'Server' });
        return _;
      });
      ctx.log('servers=' + servers.length);
      if (!servers.length) {
        var direct = [];
        String(html).replace(/https?:\/\/[^"'\s]+(?:\.m3u8|\.mp4)[^"'\s]*/gi, function (u) {
          direct.push(u);
          return u;
        });
        if (direct.length) {
          return direct.slice(0, 4).map(function (u) {
            return {
              url: u,
              name: 'VSEmbed',
              headers: { 'User-Agent': ua, Referer: origin + '/' },
            };
          });
        }
        ctx.log('no data-hash / m3u8 (WASM player — needs green Play sniff)');
        return [];
      }
      return Promise.all(
        servers.slice(0, 4).map(function (s) {
          return ctx
            .fetch(base + '/rcp/' + s.hash, {
              headers: Object.assign({}, headers, {
                Referer: embed,
                'Sec-Fetch-Dest': 'iframe',
              }),
            })
            .then(function (r) {
              return r.text();
            })
            .then(function (rcpHtml) {
              var src = (rcpHtml.match(/src:\s*'([^']+)'/) || [])[1] || '';
              if (src.indexOf('/prorcp/') === 0) {
                return prorcp(base, src.replace('/prorcp/', ''));
              }
              if (/\.m3u8/i.test(src)) {
                return [
                  {
                    url: src.indexOf('http') === 0 ? src : base + src,
                    name: s.name,
                    headers: { 'User-Agent': ua, Referer: base + '/' },
                  },
                ];
              }
              ctx.log('rcp unhandled ' + src.slice(0, 60));
              return [];
            })
            .catch(function (e) {
              ctx.error('rcp ' + s.name + ': ' + (e && e.message ? e.message : e));
              return [];
            });
        }),
      ).then(function (groups) {
        var out = [].concat.apply([], groups);
        ctx.log('streams=' + out.length);
        return out;
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
