var SPECS = {
  base: 'https://www.livesoccertv.com',
  pages: ['/'],
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
      sportMatchGame: sportMatchGame,
    });
  }

  return out;
}

function isCloudflareChallenge(html) {
  return /Just a moment|cf-browser-verification|challenges\.cloudflare\.com/i.test(
    String(html || ''),
  );
}

async function fetchPage(ctx, cfg, page) {
  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var path = String(page || '/');
  if (!path.startsWith('/')) path = '/' + path;
  var res = await ctx.fetch(base + path, {
    headers: {
      'User-Agent': ua(),
      Accept: 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  });
  if (!res.ok) return [];
  var html = await res.text();
  if (isCloudflareChallenge(html)) return [];
  return parsePage(html, pluginIdFromCtx(ctx, cfg));
}

async function fetchCatalog(ctx, cfg) {
  var pages = cfg.pages && cfg.pages.length ? cfg.pages : SPECS.pages;
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
  return out
    .sort(function (a, b) {
      return Number(a.date || 0) - Number(b.date || 0);
    })
    .slice(0, CATALOG_MAX);
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  return [];
}
