var SPECS = {
  "megaplay": "https://megaplay.buzz",
  "vidwish": "https://vidwish.live",
  "megacloud": "https://megacloud.bloggy.click",
  "vidtube": "https://vidtube.site",
  "scrapeReferer": "https://www.enma.lol/"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var megaplay = String(cfg.megaplay).replace(/\/$/, '');
  var vidwish = String(cfg.vidwish).replace(/\/$/, '');
  var megacloud = String(cfg.megacloud).replace(/\/$/, '');
  var vidtube = String(cfg.vidtube).replace(/\/$/, '');
  var scrapeReferer = cfg.scrapeReferer;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Accept: '*/*' };
  var ep = Number(ctx.mappedEpisode || ctx.episode || 1) || 1;

  function getJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      if (!r.ok) return null;
      return r.json();
    });
  }

  function getText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, headers, extra || {}) }).then(function (r) {
      if (!r.ok) return '';
      return r.text();
    });
  }

  function playerId(html) {
    try {
      var $ = ctx.html ? ctx.html(html) : null;
      if ($) {
        var el = $('#megaplay-player');
        if (el && el.length) {
          return { id: el.attr('data-id') || '', real: el.attr('data-realid') || '' };
        }
      }
    } catch (e) {}
    return {
      id:
        (html.match(/id=["']megaplay-player["'][^>]*data-id=["']([^"']+)/) ||
          html.match(/data-id=["']([^"']+)["'][^>]*id=["']megaplay-player/) ||
          [])[1] || '',
      real: (html.match(/data-realid=["']([^"']+)/) || [])[1] || '',
    };
  }

  function extractSources(apiUrl, referer, origin, name, kind) {
    return getJson(apiUrl, {
      'X-Requested-With': 'XMLHttpRequest',
      Referer: referer,
      Origin: origin,
    })
      .then(function (json) {
        var file = json && json.sources && json.sources.file;
        if (!file) return [];
        return [
          {
            url: file,
            name: 'Megaplay [' + name + '] (' + kind.toUpperCase() + ')',
            language: kind === 'dub' ? 'Dub' : 'Sub',
            headers: { 'User-Agent': ua, Referer: origin + '/', Origin: origin },
          },
        ];
      })
      .catch(function () {
        return [];
      });
  }

  function scrapePage(pageUrl, kind) {
    return getText(pageUrl, { Referer: scrapeReferer }).then(function (html) {
      if (!html) return [];
      var ids = playerId(html);
      var tasks = [];
      if (ids.id) {
        tasks.push(
          extractSources(
            megaplay + '/stream/getSources?id=' + ids.id + '&id=' + ids.id,
            pageUrl,
            megaplay,
            'MegaPlay',
            kind,
          ),
        );
      }
      if (ids.real) {
        var vidPage = vidwish + '/stream/s-2/' + ids.real + '/' + kind;
        tasks.push(
          getText(vidPage, { Referer: pageUrl }).then(function (vidHtml) {
            var v = playerId(vidHtml);
            if (!v.id) return [];
            return extractSources(
              vidwish + '/stream/getSources?id=' + v.id + '&id=' + v.id,
              vidPage,
              vidwish,
              'Vidwish',
              kind,
            );
          }),
        );
        var mcPage = megacloud + '/stream/s-3/' + ids.real + '/' + kind;
        tasks.push(
          getText(mcPage, { Referer: pageUrl }).then(function (mcHtml) {
            var m = playerId(mcHtml);
            if (!m.id) return [];
            return extractSources(
              megacloud + '/stream/getSources?id=' + m.id + '&id=' + m.id,
              mcPage,
              megacloud,
              'MegaCloud',
              kind,
            );
          }),
        );
        var vtPage = vidtube + '/stream/s-2/' + ids.real + '/' + kind;
        tasks.push(
          getText(vtPage, { Referer: pageUrl }).then(function (vtHtml) {
            var v = playerId(vtHtml);
            if (!v.id) return [];
            return extractSources(
              vidtube + '/stream/getSources?id=' + v.id + '&id=' + v.id,
              vtPage,
              vidtube,
              'VidTube',
              kind,
            );
          }),
        );
      }
      return Promise.all(tasks).then(function (groups) {
        return [].concat.apply([], groups);
      });
    });
  }

  function ids() {
    var al = Number(ctx.anilistId) || 0;
    var mal = Number(ctx.malId) || 0;
    var fromAl = globalThis.__engineCtxAnilist && globalThis.__engineCtxAnilist(ctx);
    var fromMal = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (!al && fromAl) al = Number(fromAl) || 0;
    if (!mal && fromMal && fromMal.mal) mal = Number(fromMal.mal) || 0;
    return { al: al, mal: mal };
  }

  var id = ids();
  if (!id.al && !id.mal) return Promise.resolve([]);

  var pages = [];
  var cats =
    (globalThis.__engineAudioCategories &&
      globalThis.__engineAudioCategories(ctx)) ||
    ['sub', 'dub'];
  cats.forEach(function (kind) {
    if (id.al) {
      pages.push({
        url: megaplay + '/stream/ani/' + id.al + '/' + ep + '/' + kind,
        kind: kind,
      });
    }
    if (id.mal) {
      pages.push({
        url: megaplay + '/stream/mal/' + id.mal + '/' + ep + '/' + kind,
        kind: kind,
      });
    }
  });

  return Promise.all(
    pages.map(function (p) {
      return scrapePage(p.url, p.kind).catch(function () {
        return [];
      });
    }),
  ).then(function (groups) {
    var seen = {};
    var out = [];
    groups.forEach(function (rows) {
      (rows || []).forEach(function (r) {
        if (!r || !r.url || seen[r.url]) return;
        seen[r.url] = true;
        out.push(r);
      });
    });
    return out;
  });
}
