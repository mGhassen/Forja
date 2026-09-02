var SPECS = {
  base: 'https://m.liveonsat.com',
  pages: ['2day.php'],
};

var CATALOG_MAX = 120;
var MONTHS = {
  january: 0,
  february: 1,
  march: 2,
  april: 3,
  may: 4,
  june: 5,
  july: 6,
  august: 7,
  september: 8,
  october: 9,
  november: 10,
  december: 11,
};

function ua() {
  return 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'liveonsat');
}

function cleanChannelName(raw) {
  return String(raw || '')
    .replace(/\s+/g, ' ')
    .replace(/\s*\(\$\/geo\/R\)\s*/gi, '')
    .replace(/\s*\(\$\/geo\)\s*/gi, '')
    .replace(/\s*\[\$?\]\s*/g, '')
    .replace(/\s*\[online\]\s*/gi, '')
    .replace(/\s*\[via APP\]\s*/gi, '')
    .replace(/\s*\[APP\]\s*/gi, '')
    .replace(/\s*\(uk only\)\s*/gi, '')
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

function parseBritishDate(header, refYear) {
  var m = String(header || '').match(/(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)/i);
  if (!m) return null;
  var day = parseInt(m[1], 10);
  var mon = MONTHS[m[2].toLowerCase()];
  if (mon == null || isNaN(day)) return null;
  return new Date(refYear, mon, day);
}

function parseKickoffMs(dateHeader, timeStr, refYear) {
  var base = parseBritishDate(dateHeader, refYear);
  if (!base) return 0;
  var tm = String(timeStr || '').match(/(\d{1,2}):(\d{2})/);
  if (!tm) return base.getTime();
  var h = parseInt(tm[1], 10);
  var min = parseInt(tm[2], 10);
  if (isNaN(h) || isNaN(min)) return base.getTime();
  // LiveOnSat lists UK local kickoff (GMT/BST). Approximate with +0 offset.
  return Date.UTC(base.getFullYear(), base.getMonth(), base.getDate(), h, min);
}

function inCatalogWindow(dateMs) {
  if (!dateMs) return false;
  var now = Date.now();
  return dateMs >= now - 6 * 3600000 && dateMs <= now + 7 * 24 * 3600000;
}

function isAiring(dateMs) {
  if (!dateMs) return false;
  var now = Date.now();
  return dateMs <= now + 15 * 60000 && dateMs >= now - 4 * 3600000;
}

function extractChannels(block) {
  var out = [];
  var seen = {};
  var re = /class\s*=\s*chan_live[^>]*>([^<]+)</gi;
  var m;
  while ((m = re.exec(block))) {
    var name = cleanChannelName(m[1]);
    if (!name) continue;
    var key = name.toLowerCase();
    if (seen[key]) continue;
    seen[key] = true;
    out.push(name);
  }
  return out;
}

function parsePage(html, pluginId, now) {
  var refYear = now.getFullYear();
  var out = [];
  var seen = {};

  var timeHeads = [];
  var thRe = /class\s*=\s*time_head[^>]*>([^<]+)</gi;
  var thm;
  while ((thm = thRe.exec(html))) {
    timeHeads.push({ index: thm.index, text: thm[1].trim() });
  }

  function dateHeaderForIndex(idx) {
    for (var i = timeHeads.length - 1; i >= 0; i--) {
      if (timeHeads[i].index < idx) return timeHeads[i].text;
    }
    return '';
  }

  var compHeads = [];
  var chRe = /class\s*=\s*comp_head[^>]*>([^<]+)</gi;
  var chm;
  while ((chm = chRe.exec(html))) {
    compHeads.push({ index: chm.index, text: chm[1].trim() });
  }

  function competitionForIndex(idx) {
    for (var i = compHeads.length - 1; i >= 0; i--) {
      if (compHeads[i].index < idx) return compHeads[i].text;
    }
    return 'LiveOnSat';
  }

  var parts = String(html || '').split(/expandContract\('/i);
  for (var p = 1; p < parts.length; p++) {
    var block = parts[p];
    var idMatch = block.match(/^(\d+)/);
    if (!idMatch) continue;
    var eventId = idMatch[1];

    var head = block.slice(0, Math.min(block.length, 1800));
    var titleMatch = head.match(/background-color:#ffd379[^>]*>([^<]+)</i);
    if (!titleMatch) {
      var before = parts[p - 1];
      var tail = before.slice(Math.max(0, before.length - 1200));
      titleMatch = tail.match(/background-color:#ffd379[^>]*>([^<]+)</i);
    }
    if (!titleMatch) continue;
    var title = String(titleMatch[1] || '').trim();
    if (!title) continue;

    var teams = parseTeams(title);
    var idxInPage = html.indexOf("expandContract('" + eventId);
    var competition = competitionForIndex(idxInPage >= 0 ? idxInPage : 0);
    var dateHeader = dateHeaderForIndex(idxInPage >= 0 ? idxInPage : 0);

    var timeMatch = block.match(/ST:\s*(\d{1,2}:\d{2})/i);
    var dateMs = parseKickoffMs(dateHeader, timeMatch ? timeMatch[1] : '', refYear);
    if (!inCatalogWindow(dateMs)) continue;

    var channels = extractChannels(block);
    var dedupeKey =
      title.toLowerCase() + '|' + String(dateMs) + '|' + competition.toLowerCase();
    if (seen[dedupeKey]) continue;
    seen[dedupeKey] = true;

    var category = normCategory(competition);
    var airing = isAiring(dateMs);
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
      id: 'los_' + eventId,
      title: title,
      category: category,
      date: dateMs,
      poster: '',
      popular: airing && channels.length > 0,
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

async function fetchPage(ctx, cfg, page) {
  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var path = String(page || '2day.php').replace(/^\//, '');
  var res = await ctx.fetch(base + '/' + path, {
    headers: { 'User-Agent': ua(), Accept: 'text/html' },
  });
  if (!res.ok) return [];
  var html = await res.text();
  return parsePage(html, pluginIdFromCtx(ctx, cfg), new Date());
}

async function fetchCatalog(ctx, cfg) {
  var pages = cfg.pages && cfg.pages.length ? cfg.pages : SPECS.pages;
  var pluginId = pluginIdFromCtx(ctx, cfg);
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
