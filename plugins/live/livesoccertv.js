var SPECS = {
  base: 'https://www.livesoccertv.com',
  jinaPrefix: 'https://r.jina.ai/',
};

var CATALOG_MAX = 120;

function ua() {
  return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'livesoccertv');
}

function cleanChannelName(raw) {
  return String(raw || '')
    .replace(/\s*\(live stream available\)\s*/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseTeams(title) {
  var s = String(title || '').trim();
  var m = s.match(/^(.+?)\s+(?:v|vs|@)\s+(.+)$/i);
  if (!m) return { home: '', away: '', title: s };
  return { home: m[1].trim(), away: m[2].trim(), title: s };
}

function normCategory(comp) {
  var c = String(comp || '').toLowerCase();
  if (c.indexOf('nba') >= 0 || c.indexOf('basketball') >= 0) return 'basketball';
  if (c.indexOf('nhl') >= 0 || c.indexOf('hockey') >= 0) return 'hockey';
  if (c.indexOf('mlb') >= 0 || c.indexOf('baseball') >= 0) return 'baseball';
  if (c.indexOf('nfl') >= 0 || (c.indexOf('football') >= 0 && c.indexOf('soccer') < 0)) {
    return 'american-football';
  }
  if (c.indexOf('ufc') >= 0 || c.indexOf('mma') >= 0 || c.indexOf('boxing') >= 0) {
    return 'mma';
  }
  if (c.indexOf('tennis') >= 0) return 'tennis';
  if (c.indexOf('rugby') >= 0) return 'rugby';
  if (c.indexOf('cricket') >= 0) return 'cricket';
  if (c.indexOf('f1') >= 0 || c.indexOf('formula') >= 0 || c.indexOf('motogp') >= 0) {
    return 'motorsport';
  }
  return 'football';
}

function pad2(n) {
  return n < 10 ? '0' + n : String(n);
}

function schedulePages(cfg) {
  if (cfg.pages && cfg.pages.length) return cfg.pages;
  var out = [];
  var now = new Date();
  for (var i = 0; i < 2; i++) {
    var d = new Date(now.getTime());
    d.setDate(d.getDate() + i);
    out.push(
      '/schedules/' +
        d.getFullYear() +
        '-' +
        pad2(d.getMonth() + 1) +
        '-' +
        pad2(d.getDate()) +
        '/',
    );
  }
  return out;
}

function inCatalogWindow(dateMs) {
  if (!dateMs) return false;
  var now = Date.now();
  return dateMs >= now - 6 * 3600000 && dateMs <= now + 7 * 24 * 3600000;
}

function isAiring(block, dateMs) {
  if (/class\s*=\s*["'][^"']*livecell[^"']*\blive\b/i.test(block)) return true;
  if (!dateMs) return false;
  var now = Date.now();
  return dateMs <= now + 15 * 60000 && dateMs >= now - 4 * 3600000;
}

function mergeChannelLists(a, b) {
  var out = [];
  var seen = {};
  function push(name) {
    var cleaned = cleanChannelName(name);
    if (!cleaned) return;
    var key = cleaned.toLowerCase();
    if (seen[key]) return;
    seen[key] = true;
    out.push(cleaned);
  }
  (a || []).forEach(push);
  (b || []).forEach(push);
  return out;
}

function extractChannels(block) {
  var out = [];
  var seen = {};
  var skip = {
    'available on-demand': true,
    'more channels': true,
  };

  function pushName(name) {
    var cleaned = cleanChannelName(name);
    if (!cleaned) return;
    var key = cleaned.toLowerCase();
    if (skip[key]) return;
    if (seen[key]) return;
    seen[key] = true;
    out.push(cleaned);
  }

  var channelsBlock =
    block.match(/id\s*=\s*["']channels["'][\s\S]*?<div class\s*=\s*["']mchannels[^"']*["'][^>]*>([\s\S]*?)<\/div>/i) ||
    null;
  var channelHtml = channelsBlock ? channelsBlock[1] : block;

  var linkRe = /<a\b[^>]*>([^<]+)<\/a>/gi;
  var lm;
  while ((lm = linkRe.exec(channelHtml))) {
    pushName(lm[1]);
  }

  var titleRe = /<a\b[^>]*title\s*=\s*["']([^"']+)["']/gi;
  var tm;
  while ((tm = titleRe.exec(channelHtml))) {
    pushName(tm[1]);
  }

  return out;
}

function extractInternationalChannels(html) {
  var out = [];
  var seen = {};
  var skip = {
    'available on-demand': true,
    'more channels': true,
  };

  function pushName(name) {
    var cleaned = cleanChannelName(name);
    if (!cleaned) return;
    var key = cleaned.toLowerCase();
    if (skip[key]) return;
    if (seen[key]) return;
    seen[key] = true;
    out.push(cleaned);
  }

  var jsonLdRe = /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  var jm;
  while ((jm = jsonLdRe.exec(String(html || '')))) {
    try {
      var data = JSON.parse(jm[1]);
      var graph = data && data['@graph'];
      var nodes = Array.isArray(graph) ? graph : data ? [data] : [];
      nodes.forEach(function (node) {
        if (!node || node['@type'] !== 'BroadcastEvent') return;
        var pub = node.publishedOn;
        if (pub && pub.name) pushName(pub.name);
      });
    } catch (e) {}
  }

  var section = String(html || '').match(
    /id\s*=\s*["']dynamic-international-tv["'][\s\S]*?<table class\s*=\s*["'][^"']*ichannels[^"']*["']([\s\S]*?)<\/table>/i,
  );
  if (section) {
    var rowRe = /<tr[\s\S]*?<\/tr>/gi;
    var row;
    while ((row = rowRe.exec(section[1]))) {
      var tdRe = /<td[\s\S]*?<\/td>/gi;
      var tds = [];
      var td;
      while ((td = tdRe.exec(row[0]))) tds.push(td[0]);
      if (tds.length < 2) continue;
      var linkRe = /<a[^>]*>([^<]+)<\/a>/gi;
      var lm;
      while ((lm = linkRe.exec(tds[1]))) {
        pushName(lm[1]);
      }
    }
  }

  return out;
}

function extractMatchPath(block) {
  var m = String(block || '').match(/href\s*=\s*["'](\/match\/[^#"']+)/i);
  return m ? m[1] : '';
}

function parseCompetitionHeaders(html) {
  var out = [];
  var re = /class\s*=\s*["']sortable_comp["'][^>]*>[\s\S]*?<span class\s*=\s*["']flag\s+[^"']+["']>([^<]+)</gi;
  var m;
  while ((m = re.exec(html))) {
    out.push({ index: m.index, text: m[1].trim() });
  }
  return out;
}

function competitionForIndex(compHeads, idx) {
  var competition = 'Live Soccer TV';
  for (var i = 0; i < compHeads.length; i++) {
    if (compHeads[i].index < idx) competition = compHeads[i].text;
    else break;
  }
  return competition;
}

function parsePage(html, pluginId) {
  var out = [];
  var seen = {};
  var compHeads = parseCompetitionHeaders(html);
  var rowRe = /<tr[^>]*\bid\s*=\s*["'](\d+)["'][^>]*class\s*=\s*["'][^"']*matchrow[^"']*["'][\s\S]*?<\/tr>/gi;
  var match;

  while ((match = rowRe.exec(html))) {
    var block = match[0];
    var eventId = match[1];
    if (!eventId) continue;

    var idxInPage = match.index;
    var competition = competitionForIndex(compHeads, idxInPage);

    var dvMatch = block.match(/\bdv\s*=\s*["'](\d+)["']/i);
    var dateMs = dvMatch ? parseInt(dvMatch[1], 10) : 0;
    if (!dateMs || isNaN(dateMs)) continue;
    if (!inCatalogWindow(dateMs)) continue;

    var titleMatch =
      block.match(/id\s*=\s*["']match["'][^>]*>[\s\S]*?title\s*=\s*["']([^"']+)["']/i) ||
      block.match(/id\s*=\s*["']g\d+["'][^>]*title\s*=\s*["']([^"']+)["']/i);
    if (!titleMatch) continue;
    var title = String(titleMatch[1] || '')
      .replace(/<score>[\s\S]*?<\/score>/gi, ' vs ')
      .replace(/\s+/g, ' ')
      .trim();
    if (!title) continue;

    var teams = parseTeams(title);
    var channels = extractChannels(block);
    var matchPath = extractMatchPath(block);
    var dedupeKey =
      title.toLowerCase() + '|' + String(dateMs) + '|' + competition.toLowerCase();
    if (seen[dedupeKey]) continue;
    seen[dedupeKey] = true;

    var category = normCategory(competition);
    var airing = isAiring(block, dateMs);
    var sportMatchGame = {
      id: eventId,
      title: title,
      sport: category,
      category: competition,
      homeTeam: teams.home,
      awayTeam: teams.away,
      dateMs: dateMs,
      broadcastChannels: channels,
      matchPath: matchPath,
    };

    out.push({
      id: 'lstv_' + eventId,
      title: title,
      category: category,
      date: dateMs,
      poster: '',
      popular: false,
      airing: airing,
      homeTeam: teams.home,
      awayTeam: teams.away,
      sources: [],
      catalog: 'forja_live',
      pluginId: pluginId,
      matchPath: matchPath,
      sportMatchGame: sportMatchGame,
    });
  }

  return out;
}

function isCloudflareChallenge(html) {
  var s = String(html || '');
  if (/class\s*=\s*["'][^"']*matchrow/i.test(s)) return false;
  return /<title>\s*Just a moment/i.test(s) || /cf-browser-verification/i.test(s);
}

function flareSolverrBase(ctx) {
  var u = String((ctx.config && ctx.config.flareSolverrUrl) || '').trim();
  if (!u) return '';
  return u.replace(/\/+$/, '');
}

function fetchText(ctx, url, headers) {
  return ctx.fetch(url, { headers: headers || {} }).then(function (res) {
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.text();
  });
}

function fetchTextViaFlareSolverr(ctx, url) {
  var base = flareSolverrBase(ctx);
  if (!base) return Promise.reject(new Error('no flare solver'));
  var endpoint = base + (/\/v1$/i.test(base) ? '' : '/v1');
  return ctx
    .fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        cmd: 'request.get',
        url: url,
        maxTimeout: 60000,
      }),
    })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    })
    .then(function (v) {
      if (!v || v.status !== 'ok' || !v.solution) throw new Error('flare failed');
      var body = String(v.solution.response || '');
      if (!body || isCloudflareChallenge(body)) throw new Error('flare CF');
      return body;
    });
}

function jinaUrl(cfg, targetUrl) {
  var prefix = String(cfg.jinaPrefix || SPECS.jinaPrefix).replace(/\/+$/, '') + '/';
  return prefix + String(targetUrl || '').replace(/^\/+/, function (m) {
    return m.length === 1 ? '' : m;
  });
}

function fetchTextViaJina(ctx, cfg, targetUrl) {
  var url = jinaUrl(cfg, targetUrl);
  return fetchText(ctx, url, {
    Accept: 'text/html',
    'X-Return-Format': 'html',
  }).then(function (html) {
    if (!html || isCloudflareChallenge(html)) throw new Error('jina CF');
    return html;
  });
}

function fetchHtml(ctx, cfg, targetUrl) {
  var headers = {
    'User-Agent': ua(),
    Accept: 'text/html,application/xhtml+xml',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  return fetchText(ctx, targetUrl, headers)
    .then(function (html) {
      if (!isCloudflareChallenge(html)) return html;
      throw new Error('cloudflare');
    })
    .catch(function () {
      if (flareSolverrBase(ctx)) {
        return fetchTextViaFlareSolverr(ctx, targetUrl);
      }
      return fetchTextViaJina(ctx, cfg, targetUrl);
    });
}

async function fetchPage(ctx, cfg, page) {
  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var path = String(page || '/schedules/');
  if (!path.startsWith('/')) path = '/' + path;
  var targetUrl = base + path;
  try {
    var html = await fetchHtml(ctx, cfg, targetUrl);
    return parsePage(html, pluginIdFromCtx(ctx, cfg));
  } catch (e) {
    return [];
  }
}

async function enrichInternationalCoverage(ctx, cfg, rows) {
  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var pending = [];
  rows.forEach(function (row) {
    var path = String(
      row.matchPath || (row.sportMatchGame && row.sportMatchGame.matchPath) || '',
    ).trim();
    if (!path) return;
    pending.push({ row: row, url: base + path });
  });
  if (!pending.length) return rows;

  var concurrency = 4;
  for (var i = 0; i < pending.length; i += concurrency) {
    var batch = pending.slice(i, i + concurrency);
    await Promise.all(
      batch.map(async function (item) {
        try {
          var html = await fetchHtml(ctx, cfg, item.url);
          var intl = extractInternationalChannels(html);
          if (!intl.length) return;
          var row = item.row;
          var game = row.sportMatchGame || {};
          var merged = mergeChannelLists(game.broadcastChannels || [], intl);
          game.broadcastChannels = merged;
          row.sportMatchGame = game;
          row.broadcastChannels = merged;
        } catch (e) {}
      }),
    );
  }
  return rows;
}

async function fetchCatalog(ctx, cfg) {
  var pages = schedulePages(cfg);
  var seen = {};
  var out = [];
  for (var i = 0; i < pages.length; i++) {
    var rows = await fetchPage(ctx, cfg, pages[i]);
    rows.forEach(function (row) {
      var key = String(row.id || row.title);
      if (seen[key]) return;
      seen[key] = true;
      out.push(row);
    });
  }
  out = out
    .sort(function (a, b) {
      return Number(a.date || 0) - Number(b.date || 0);
    })
    .slice(0, CATALOG_MAX);
  return enrichInternationalCoverage(ctx, cfg, out);
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  return [];
}
