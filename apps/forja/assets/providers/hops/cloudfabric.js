function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var referer = 'https://player.autoembed.co/';
  try {
    referer = new URL(url).origin + '/';
  } catch (e) {}
  var headers = {
    'User-Agent': ua,
    Referer: referer,
    Accept: 'text/html,application/xhtml+xml,application/json',
  };

  function abs(u, base) {
    if (!u) return '';
    if (/^https?:/i.test(u)) return u;
    try {
      return new URL(u, base).toString();
    } catch (e) {
      return u;
    }
  }

  function scrape(html, base) {
    var urls = [];
    var re = /https?:\/\/[^"'\\\s<>]+(?:\.m3u8|\.mp4|\.mpd)[^"'\\\s<>]*/gi;
    var m;
    while ((m = re.exec(html))) urls.push(m[0]);
    String(html).replace(
      /["'](file|src|url|source|playlist|stream)["']\s*:\s*["'](https?:[^"']+)["']/gi,
      function (_, _k, u) {
        urls.push(u);
        return _;
      },
    );
    String(html).replace(/<source[^>]*src=["']([^"']+)["']/gi, function (_, s) {
      urls.push(abs(s, base));
      return _;
    });
    String(html).replace(/<video[^>]*src=["']([^"']+)["']/gi, function (_, s) {
      urls.push(abs(s, base));
      return _;
    });
    return urls.filter(function (u, i, a) {
      return u && a.indexOf(u) === i;
    });
  }

  return ctx
    .fetch(url, { headers: headers })
    .then(function (r) {
      return r.text().then(function (html) {
        return { status: r.status, html: html, finalUrl: r.url || url };
      });
    })
    .then(function (res) {
      var html = res.html || '';
      if (
        /cf-turnstile|turnstile-verify|data-sitekey|challenges\.cloudflare\.com\/turnstile/i.test(
          html,
        )
      ) {
        ctx.log(
          'cloudfabric Turnstile gate — no HTTP stream (needs browser / FlareSolverr; issue 167)',
        );
        return [];
      }
      if (/just a moment|cf-challenge|challenge-platform/i.test(html)) {
        ctx.log('cloudfabric cloudflare challenge');
        return [];
      }
      var urls = scrape(html, res.finalUrl);
      ctx.log('cloudfabric scraped=' + urls.length);
      var playable = urls.filter(function (u) {
        return /\.m3u8|\.mp4|\.mpd/i.test(u) || /ice.*m3u8=/i.test(u);
      });
      if (playable.length) {
        return playable.slice(0, 8).map(function (u) {
          return {
            url: u,
            name: 'AutoEmbed',
            headers: { 'User-Agent': ua, Referer: referer },
          };
        });
      }
      var embeds = [];
      String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
        embeds.push(abs(s, res.finalUrl));
        return _;
      });
      if (!embeds.length) return [];
      return Promise.all(
        embeds.slice(0, 4).map(function (u) {
          return ctx.hop(u);
        }),
      ).then(function (groups) {
        return [].concat.apply([], groups).filter(function (r) {
          return r && r.url;
        });
      });
    })
    .catch(function (e) {
      ctx.error('cloudfabric: ' + (e && e.message ? e.message : e));
      return [];
    });
}
