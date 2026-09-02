var CATALOG_MAX = 80;

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'streamic');
}

function streamicOrigin(cfg) {
  return String((cfg && cfg.origin) || 'https://streamic.st').replace(/\/$/, '');
}

function streamicHeaders(cfg) {
  var origin = streamicOrigin(cfg);
  var headers = {
    Accept: '*/*',
    Referer: origin + '/',
    'User-Agent': ua(),
  };
  var ssig = String((cfg && cfg.ssig) || 'bytmo8xialhem066').trim();
  if (ssig) headers['X-SSIG'] = ssig;
  return headers;
}

function hexByte(n) {
  var hex = (n & 0xff).toString(16);
  return hex.length < 2 ? '0' + hex : hex;
}

function utf8FromBinary(bin) {
  if (!bin) return '';
  if (typeof TextDecoder !== 'undefined') {
    try {
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i) & 0xff;
      return new TextDecoder('utf-8').decode(bytes);
    } catch (_) {}
  }
  try {
    return decodeURIComponent(
      bin
        .split('')
        .map(function (c) {
          return '%' + hexByte(c.charCodeAt(0));
        })
        .join('')
    );
  } catch (_) {
    try {
      return decodeURIComponent(escape(bin));
    } catch (e2) {
      return bin;
    }
  }
}

function b64decodeUTF8(b64) {
  var raw = String(b64 || '')
    .replace(/^\uFEFF/, '')
    .replace(/\s+/g, '');
  if (!raw) return '';
  try {
    return utf8FromBinary(atob(raw));
  } catch (_) {
    return '';
  }
}

function parseStreamicEventsBody(body) {
  var trimmed = String(body || '')
    .replace(/^\uFEFF/, '')
    .trim();
  if (!trimmed) return [];
  if (trimmed.charAt(0) === '[' || trimmed.charAt(0) === '{') {
    var direct = JSON.parse(trimmed);
    return Array.isArray(direct) ? direct : direct.events || direct.streams || [];
  }
  var decoded = b64decodeUTF8(trimmed);
  if (!decoded) return [];
  var data = JSON.parse(decoded);
  return Array.isArray(data) ? data : data.events || data.streams || [];
}

async function readFetchBody(res) {
  if (!res) return '';
  if (res._bodyB64) {
    try {
      var bin = atob(String(res._bodyB64 || ''));
      var fromB64 = '';
      for (var i = 0; i < bin.length; i++) fromB64 += bin.charAt(i);
      if (fromB64) return fromB64.trim();
    } catch (_) {}
  }
  if (typeof res.text === 'function') {
    try {
      var text = await res.text();
      if (text) return String(text).trim();
    } catch (_) {}
  }
  if (typeof res.arrayBuffer === 'function') {
    try {
      var buf = await res.arrayBuffer();
      var view = new Uint8Array(buf);
      var out = '';
      for (var j = 0; j < view.length; j++) out += String.fromCharCode(view[j]);
      if (out) return out.trim();
    } catch (_) {}
  }
  return '';
}

function eventTitle(m) {
  var title = m && m.title;
  if (title && typeof title === 'object') {
    if (title.pl && title.pl.home && title.pl.away) {
      return String(title.pl.home) + ' - ' + String(title.pl.away);
    }
    return String(title.home || title.away || title.en || title.pl || '');
  }
  return String((m && (m.title || m.name)) || 'Streamic');
}

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('pilkanozna') >= 0 || s.indexOf('pilka') >= 0) return 'football';
  if (s.indexOf('basket') >= 0 || s.indexOf('koszykowka') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0 || s.indexOf('hokej') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
  if (s.indexOf('tenis') >= 0 || s.indexOf('tennis') >= 0) return 'tennis';
  if (s.indexOf('baseball') >= 0 || s.indexOf('bejsbol') >= 0) return 'baseball';
  if (s.indexOf('krykiet') >= 0 || s.indexOf('cricket') >= 0) return 'cricket';
  if (s.indexOf('siatkowka') >= 0 || s.indexOf('volleyball') >= 0) return 'volleyball';
  if (s.indexOf('pilkareczna') >= 0 || s.indexOf('handball') >= 0) return 'handball';
  if (s.indexOf('kolarstwo') >= 0 || s.indexOf('cycling') >= 0) return 'cycling';
  if (s.indexOf('motorsport') >= 0 || s.indexOf('f1') >= 0) return 'motor-sports';
  if (s.indexOf('golf') >= 0) return 'golf';
  if (s.indexOf('magazyn') >= 0) return 'other';
  if (s.indexOf('australianfootball') >= 0) return 'australian-football';
  return s.replace(/\s+/g, '-');
}

function inCatalogWindow(ts) {
  if (!ts) return false;
  var ms = ts >= 1e12 ? ts : ts * 1000;
  var now = Date.now();
  return ms >= now - 24 * 3600000 && ms <= now + 7 * 24 * 3600000;
}

function isAiring(startTime) {
  if (!startTime) return false;
  var nowSec = Math.floor(Date.now() / 1000);
  return startTime <= nowSec && startTime >= nowSec - 6 * 3600;
}

function streamicReferer(cfg) {
  return streamicOrigin(cfg) + '/';
}

function m3u8FromEmbedUrl(url) {
  try {
    var u = new URL(String(url || '').trim());
    var q = u.searchParams.get('url') || u.searchParams.get('src') || '';
    if (q) {
      var decoded = decodeURIComponent(q);
      if (/\.m3u8/i.test(decoded)) return decoded;
    }
  } catch (_) {}
  return '';
}

function embedPriority(url) {
  var u = String(url || '').toLowerCase();
  if (/\.m3u8|\.mp4/i.test(u)) return 0;
  if (u.indexOf('embed.st') >= 0 || u.indexOf('embedindia.st') >= 0) return 1;
  if (u.indexOf('embed/') >= 0 && u.indexOf('admin/') >= 0) return 1;
  if (u.indexOf('strmi.buzz') >= 0 || u.indexOf('strm.buzz') >= 0) return 2;
  if (u.indexOf('lovetier.bz') >= 0 || u.indexOf('dlhd.pk') >= 0) return 3;
  return 4;
}

async function unlockEmbed(ctx, url, cfg) {
  var raw = String(url || '').trim();
  if (!raw) return null;

  var nested = m3u8FromEmbedUrl(raw);
  if (nested) {
    return {
      url: nested,
      name: 'Streamic',
      headers: {
        Referer: streamicReferer(cfg),
        Origin: streamicOrigin(cfg),
        'User-Agent': ua(),
      },
      directPlayback: preferDirectPlayback(nested),
    };
  }

  if (isEmbedIndiaUrl(raw)) {
    try {
      var india = await resolveEmbedIndia(ctx, raw, cfg);
      if (india && india.length) return india[0];
    } catch (_) {}
  }

  if (raw.indexOf('embed.st') >= 0 || parseEmbedUrl(raw, cfg)) {
    try {
      var goat = await resolveGoatEmbed(ctx, raw, cfg);
      if (goat && goat.length) return goat[0];
    } catch (_) {}
  }

  if (isSportsEmbedUrl(raw)) {
    var mapped = embedStUrlFromSportsEmbed(raw);
    if (mapped) {
      try {
        var mappedGoat = await resolveGoatEmbed(ctx, mapped, cfg);
        if (mappedGoat && mappedGoat.length) return mappedGoat[0];
      } catch (_) {}
    }
    var candidates = embedStAdminCandidatesFromSportsEmbed(raw);
    for (var i = 0; i < candidates.length; i++) {
      try {
        var candidate = await resolveGoatEmbed(ctx, candidates[i], cfg);
        if (candidate && candidate.length) return candidate[0];
      } catch (_) {}
    }
  }

  return null;
}

function withName(row, name) {
  if (!row) return null;
  row.name = name || row.name || 'Streamic';
  return row;
}

async function resolveUrl(ctx, url, name, cfg) {
  var raw = String(url || '').trim();
  if (!raw) return null;
  var ref = streamicReferer(cfg);

  if (/\.m3u8|\.mp4/i.test(raw)) {
    return {
      url: raw,
      name: name || 'Streamic',
      headers: {
        Referer: ref,
        Origin: streamicOrigin(cfg),
        'User-Agent': ua(),
      },
      directPlayback: preferDirectPlayback(raw),
    };
  }

  var unlocked = await unlockEmbed(ctx, raw, cfg);
  if (unlocked) return withName(unlocked, name || 'Streamic');

  return null;
}

function parseTeams(m) {
  var title = m && m.title;
  if (title && typeof title === 'object' && title.pl) {
    return {
      home: String(title.pl.home || '').trim(),
      away: String(title.pl.away || '').trim(),
    };
  }
  var text = eventTitle(m);
  var dash = text.split(/\s+-\s+/);
  if (dash.length >= 2) {
    return {
      home: dash[0].trim(),
      away: dash.slice(1).join(' - ').trim(),
    };
  }
  return { home: '', away: '' };
}

function normTeam(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function teamPairKey(home, away) {
  var h = normTeam(home);
  var a = normTeam(away);
  if (!h || !a) return '';
  return [h, a].sort().join('|');
}

function kickoffClose(aSec, bSec) {
  if (!aSec || !bSec) return true;
  return Math.abs(Number(aSec) - Number(bSec)) <= 45 * 60;
}

function teamsOverlap(home, away, otherHome, otherAway) {
  var pair = teamPairKey(home, away);
  var other = teamPairKey(otherHome, otherAway);
  if (pair && other && pair === other) return true;
  var h = normTeam(home);
  var a = normTeam(away);
  var oh = normTeam(otherHome);
  var oa = normTeam(otherAway);
  if (!h || !a || !oh || !oa) return false;
  function hit(x, y) {
    if (!x || !y) return false;
    if (x === y) return true;
    if (x.length >= 4 && y.indexOf(x) >= 0) return true;
    if (y.length >= 4 && x.indexOf(y) >= 0) return true;
    var xw = x.split(' ').filter(Boolean);
    var yw = y.split(' ').filter(Boolean);
    return xw.some(function (w) {
      return w.length >= 4 && yw.indexOf(w) >= 0;
    });
  }
  return (hit(h, oh) || hit(h, oa)) && (hit(a, oh) || hit(a, oa));
}

var ESPN_LEAGUES = {
  baseball: ['MLB'],
  basketball: ['NBA', 'WNBA', 'NCAAMB'],
  hockey: ['NHL'],
  football: ['EPL', 'UCL', 'MLS', 'LALIGA', 'SERIEA', 'BUNDESLIGA', 'LIGUE1', 'EUROPA'],
  mma: ['UFC'],
  'american-football': ['NFL', 'NCAAFB'],
};

var ESPN_ENDPOINTS = {
  NBA: 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard',
  WNBA: 'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard',
  NCAAMB: 'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard',
  NFL: 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard',
  NCAAFB: 'https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard',
  MLB: 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard',
  NHL: 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard',
  EPL: 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard',
  MLS: 'https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/scoreboard',
  LALIGA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard',
  SERIEA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/ita.1/scoreboard',
  BUNDESLIGA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/ger.1/scoreboard',
  LIGUE1: 'https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1/scoreboard',
  UCL: 'https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.champions/scoreboard',
  EUROPA: 'https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.europa/scoreboard',
  UFC: 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard',
};

function espnGameFromEvent(event) {
  var comp = (event.competitions && event.competitions[0]) || {};
  var teams = comp.competitors || [];
  var home = {};
  var away = {};
  teams.forEach(function (t) {
    if (t.homeAway === 'home') home = t;
    if (t.homeAway === 'away') away = t;
  });
  var homeTeam = (home.team && (home.team.displayName || home.team.name)) || '';
  var awayTeam = (away.team && (away.team.displayName || away.team.name)) || '';
  var homeLogo = (home.team && home.team.logo) || '';
  var awayLogo = (away.team && away.team.logo) || '';
  var startSec = 0;
  if (event.date) {
    var ms = Date.parse(String(event.date));
    if (!isNaN(ms)) startSec = Math.floor(ms / 1000);
  }
  return {
    homeTeam: String(homeTeam || ''),
    awayTeam: String(awayTeam || ''),
    homeLogo: String(homeLogo || ''),
    awayLogo: String(awayLogo || ''),
    startSec: startSec,
  };
}

async function buildEspnIndex(ctx, rows) {
  var leagues = {};
  rows.forEach(function (row) {
    var list = ESPN_LEAGUES[row.category] || [];
    list.forEach(function (lg) {
      leagues[lg] = true;
    });
  });
  var keys = Object.keys(leagues);
  if (!keys.length) return [];
  var games = [];
  await Promise.all(
    keys.map(async function (lg) {
      var url = ESPN_ENDPOINTS[lg];
      if (!url) return;
      try {
        var res = await ctx.fetch(url, { headers: { 'User-Agent': ua() } });
        if (!res.ok) return;
        var data = await res.json();
        (data.events || []).forEach(function (ev) {
          var g = espnGameFromEvent(ev);
          if (g.homeTeam && g.awayTeam) games.push(g);
        });
      } catch (e) {
        ctx.error(e);
      }
    })
  );
  return games;
}

function matchEspnGame(games, home, away, startSec) {
  var pair = teamPairKey(home, away);
  for (var i = 0; i < games.length; i++) {
    var g = games[i];
    if (!teamsOverlap(home, away, g.homeTeam, g.awayTeam)) continue;
    var maxDelta = pair && teamPairKey(g.homeTeam, g.awayTeam) === pair ? 24 * 3600 : 45 * 60;
    if (startSec > 0 && g.startSec > 0 && Math.abs(startSec - g.startSec) > maxDelta) continue;
    return g;
  }
  return null;
}

function ppvHeaders(cfg) {
  var origin = String((cfg && cfg.ppvOrigin) || 'https://ppv.st').replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

async function buildPpvIndex(ctx, cfg) {
  var apis = (cfg && cfg.ppvApis) || [
    'https://api.ppv.st/api/streams',
    'https://api.ppv.cx/api/streams',
  ];
  var headers = ppvHeaders(cfg);
  for (var i = 0; i < apis.length; i++) {
    try {
      var res = await ctx.fetch(apis[i], { headers: headers });
      if (!res.ok) continue;
      var data = await res.json();
      if (!data || data.success !== true || !Array.isArray(data.streams)) continue;
      var rows = [];
      data.streams.forEach(function (cat) {
        (cat.streams || []).forEach(function (s) {
          if (!s || s.id == null) return;
          rows.push({
            title: String(s.name || ''),
            startsAt: Number(s.starts_at || 0),
            viewers: Number(s.viewers || 0),
            poster: String(s.poster || ''),
          });
        });
      });
      if (rows.length) return rows;
    } catch (e) {
      ctx.error(e);
    }
  }
  return [];
}

function normTitle(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function matchPpvRow(ppvRows, title, home, away, startSec) {
  var best = null;
  var titleKey = normTitle(title);
  var pair = teamPairKey(home, away);
  for (var i = 0; i < ppvRows.length; i++) {
    var row = ppvRows[i];
    if (row.viewers <= 0) continue;
    var parts = String(row.title || '').split(/\s+vs\.?\s+/i);
    var rowHome = (parts[0] || '').trim();
    var rowAway = (parts[1] || '').trim();
    var rowTitle = normTitle(row.title);
    var score = 0;
    if (pair && teamPairKey(rowHome, rowAway) === pair) score += 5;
    if (titleKey && rowTitle && (rowTitle.indexOf(titleKey) >= 0 || titleKey.indexOf(rowTitle) >= 0)) {
      score += 3;
    }
    if (score < 5 && teamsOverlap(home, away, rowHome, rowAway)) score += 4;
    if (score <= 0) continue;
    var maxDelta = score >= 5 ? 24 * 3600 : 45 * 60;
    if (startSec > 0 && row.startsAt > 0 && Math.abs(startSec - row.startsAt) > maxDelta) continue;
    if (!best || score > best.score || (score === best.score && row.viewers > best.row.viewers)) {
      best = { row: row, score: score };
    }
  }
  return best ? best.row : null;
}

async function enrichCatalogRows(ctx, cfg, rows) {
  if (!rows.length) return rows;
  var espnGames = await buildEspnIndex(ctx, rows);
  var ppvRows = await buildPpvIndex(ctx, cfg);
  return rows.map(function (row) {
    var home = String(row.homeTeam || '');
    var away = String(row.awayTeam || '');
    var startSec = Number(row.date || 0);
    if (startSec > 1e12) startSec = Math.floor(startSec / 1000);
    var espn = matchEspnGame(espnGames, home, away, startSec);
    if (espn) {
      if (!home) row.homeTeam = espn.homeTeam;
      if (!away) row.awayTeam = espn.awayTeam;
      row.homeBadge = espn.homeLogo;
      row.awayBadge = espn.awayLogo;
      row.poster = espn.homeLogo || espn.awayLogo || row.poster || '';
      row.teams = {
        home: { name: row.homeTeam, badge: row.homeBadge || '' },
        away: { name: row.awayTeam, badge: row.awayBadge || '' },
      };
    }
    var ppv = matchPpvRow(ppvRows, row.title, home, away, startSec);
    if (ppv) {
      row.viewers = ppv.viewers;
      row.popular = row.popular || ppv.viewers > 50;
      row.airing = row.airing || ppv.viewers > 0;
      if (!row.poster && ppv.poster) row.poster = ppv.poster;
    }
    return row;
  });
}

function embedRows(group) {
  var embeds = group && group.embeds;
  if (!embeds) return [];
  if (Array.isArray(embeds)) return embeds;
  if (typeof embeds === 'object') {
    return Object.keys(embeds)
      .sort()
      .map(function (k) {
        return embeds[k];
      })
      .filter(Boolean);
  }
  return [];
}

async function fetchPopularList(ctx, cfg) {
  var origin = streamicOrigin(cfg);
  var api = (cfg && cfg.popularApi) || origin + '/api/J.php';
  try {
    var res = await ctx.fetch(api, { headers: streamicHeaders(cfg) });
    if (!res.ok) return [];
    var data = await res.json();
    return Array.isArray(data) ? data : (data.events || data.streams || []);
  } catch (e) {
    ctx.error(e);
    return [];
  }
}

async function fetchMainList(ctx, cfg) {
  var origin = streamicOrigin(cfg);
  var api = (cfg && cfg.api) || origin + '/api/getEvents.php';
  try {
    var res = await ctx.fetch(api, { headers: streamicHeaders(cfg) });
    if (!res.ok) return [];
    var body = await readFetchBody(res);
    if (!body) return [];
    return parseStreamicEventsBody(body);
  } catch (e) {
    ctx.error(e);
    return [];
  }
}

async function mapWithConcurrency(items, limit, fn) {
  if (!items.length) return [];
  var out = new Array(items.length);
  var index = 0;
  async function worker() {
    while (index < items.length) {
      var i = index++;
      out[i] = await fn(items[i], i);
    }
  }
  var workers = [];
  var count = Math.max(1, Math.min(limit, items.length));
  for (var w = 0; w < count; w++) workers.push(worker());
  await Promise.all(workers);
  return out;
}

async function collectEmbeds(ctx, m, cfg) {
  var pending = [];
  (m._embeds || []).forEach(function (group) {
    var lang = String(group.language || '').trim();
    embedRows(group).forEach(function (e) {
      var url = String(e.embed || e.url || '').trim();
      if (!url) return;
      var label = String(e.label || '').trim();
      var name = lang && label ? lang + ' · ' + label : lang || label || 'Streamic';
      pending.push({ url: url, name: name, priority: embedPriority(url) });
    });
  });
  if (!pending.length) {
    var direct = String(m.url || m.link || '').trim();
    if (direct) pending.push({ url: direct, name: 'Streamic', priority: embedPriority(direct) });
  }
  pending.sort(function (a, b) {
    return a.priority - b.priority;
  });

  var resolved = await mapWithConcurrency(pending, 4, function (item) {
    return resolveUrl(ctx, item.url, item.name, cfg);
  });
  var out = [];
  for (var i = 0; i < resolved.length; i++) {
    var row = resolved[i];
    if (row && row.url && !row.webviewOnly) out.push(row);
  }
  return out;
}

async function fetchList(ctx, cfg) {
  var popular = await fetchPopularList(ctx, cfg);
  var main = await fetchMainList(ctx, cfg);
  var byId = {};
  popular.forEach(function (m, i) {
    if (!m) return;
    var id = String(m.id || 'pop_' + i);
    m._popular = true;
    byId[id] = m;
  });
  main.forEach(function (m, i) {
    if (!m) return;
    var id = String(m.id || 'evt_' + i);
    byId[id] = m;
  });
  return Object.keys(byId).map(function (k) {
    return byId[k];
  });
}

function catalogRow(m, pluginId, i) {
  var id = String(m.id || i);
  var startTime = m.startTime ? Number(m.startTime) : 0;
  var airing = isAiring(startTime);
  var teams = parseTeams(m);
  var row = {
    id: 'sic_' + id,
    title: eventTitle(m),
    category: normCategory(m.sport || m.category || 'other'),
    date: startTime > 0 ? startTime : Date.now(),
    poster: '',
    popular: m._popular === true || airing,
    airing: airing,
    viewers: 0,
    sources: [{ source: 'streamic', id: id }],
    catalog: 'forja_live',
    pluginId: pluginId,
  };
  if (teams.home) row.homeTeam = teams.home;
  if (teams.away) row.awayTeam = teams.away;
  if (teams.home || teams.away) {
    row.teams = {
      home: { name: teams.home, badge: '' },
      away: { name: teams.away, badge: '' },
    };
  }
  return row;
}

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var list = await fetchList(ctx, cfg);
  var rows = list
    .filter(function (m) {
      var startTime = m.startTime ? Number(m.startTime) : 0;
      if (m._popular === true && startTime > 0) return inCatalogWindow(startTime);
      return inCatalogWindow(startTime);
    })
    .sort(function (a, b) {
      if (a._popular === true && b._popular !== true) return -1;
      if (b._popular === true && a._popular !== true) return 1;
      return Number(a.startTime || 0) - Number(b.startTime || 0);
    })
    .slice(0, CATALOG_MAX)
    .map(function (m, i) {
      return catalogRow(m, pluginId, i);
    });
  return enrichCatalogRows(ctx, cfg, rows);
}

async function resolveByEvent(ctx, cfg) {
  var eventKey = String(ctx.eventId || ctx.matchId || '').replace(/^sic_/, '');
  if (!eventKey) return [];
  var list = await fetchList(ctx, cfg);
  for (var i = 0; i < list.length; i++) {
    var m = list[i];
    if (String(m.id || i) === eventKey) {
      var streams = await collectEmbeds(ctx, m, cfg);
      var catalogViewers = Number(ctx.viewers || 0);
      if (catalogViewers <= 0) {
        var row = catalogRow(m, pluginIdFromCtx(ctx, cfg), i);
        var enriched = await enrichCatalogRows(ctx, cfg, [row]);
        catalogViewers = Number((enriched[0] && enriched[0].viewers) || 0);
      }
      if (catalogViewers > 0) {
        streams.forEach(function (s) {
          s.viewers = catalogViewers;
        });
      }
      return streams;
    }
  }
  return [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') {
    var direct = String(ctx.url || ctx.embedUrl || '').trim();
    if (direct) {
      var row = await resolveUrl(ctx, direct, 'Streamic', cfg);
      return row ? [row] : [];
    }
    return resolveByEvent(ctx, cfg);
  }
  return [];
}
