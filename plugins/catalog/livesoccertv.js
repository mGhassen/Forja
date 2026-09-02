var SPECS = {
  base: 'https://www.livesoccertv.com',
  jinaPrefix: 'https://r.jina.ai/',
};

var CATALOG_MAX = 120;
var LIVE_SCORES_URL = 'https://proxy.livesoccertv.com/rss/livescores.xml';

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

function isLiveTimer(raw) {
  var t = String(raw || '').trim();
  if (!t) return false;
  if (/^[0-9]/.test(t)) return true;
  return (
    t === 'HT' ||
    t === 'ET' ||
    t === 'P' ||
    t === 'Pen' ||
    t === 'Break' ||
    t === 'Pause' ||
    t === 'BT'
  );
}

function extractProgress(block) {
  var timer = '';
  var tm = String(block || '').match(/\bdata-timer\s*=\s*["']([^"']*)["']/i);
  if (tm) timer = tm[1];
  var prog = String(block || '').match(
    /<span[^>]*class\s*=\s*["']inprogress["'][^>]*>([\s\S]*?)<\/span>/i,
  );
  var minute = prog ? String(prog[1]).replace(/<[^>]+>/g, '').trim() : '';
  return { timer: timer, minute: minute };
}

function isAiring(block) {
  if (/title\s*=\s*["']Match ended/i.test(block)) return false;
  if (/class\s*=\s*["'][^"']*\bft\b[^"']*["'][^>]*title\s*=\s*["']Match ended/i.test(block)) {
    return false;
  }

  var prog = extractProgress(block);
  if (isLiveTimer(prog.timer) || isLiveTimer(prog.minute)) return true;

  if (/class\s*=\s*["'][^"']*\blivematch\b/i.test(block)) {
    return isLiveTimer(prog.timer) || isLiveTimer(prog.minute);
  }

  return false;
}

function parseEtKickoffMs(dateStr, timeStr) {
  var d = String(dateStr || '').trim();
  var t = String(timeStr || '00:00:00').trim();
  if (!d) return 0;
  var ms = Date.parse(d + 'T' + t + '-04:00');
  return isNaN(ms) ? 0 : ms;
}

function attrValue(attrs, name) {
  var m = String(attrs || '').match(new RegExp('\\b' + name + '\\s*=\\s*["\']([^"\']*)["\']', 'i'));
  return m ? m[1] : '';
}

function titleFromLiveGame(game, result) {
  var s = String(game || '').trim();
  if (!s) return '';
  var score = String(result || '').trim();
  if (score) {
    var parts = score.split(/\s*-\s*/);
    if (parts.length === 2) {
      var scoreRe = new RegExp(
        '\\s+' + parts[0].trim() + '\\s*-\\s*' + parts[1].trim() + '\\s+',
      );
      if (scoreRe.test(s)) {
        s = s.replace(scoreRe, ' vs ').trim();
      }
    }
  }
  return s.replace(/\s+/g, ' ').trim();
}

function parseCompetitionLinks(html) {
  var out = {};
  var s = String(html || '');

  var re =
    /class\s*=\s*["'][^"']*sortable_comp[^"']*["'][^>]*\bid\s*=\s*["'](\d+)["'][\s\S]*?href\s*=\s*["'](\/competitions\/[^#"']+)["']/gi;
  var m;
  while ((m = re.exec(s))) {
    out[m[1]] = m[2];
  }

  // New schedule layout: showMatches('565',…) + r_complink href (no sortable_comp id).
  var showRe = /showMatches\s*\(\s*['"](\d+)['"]/gi;
  while ((m = showRe.exec(s))) {
    var cid = m[1];
    if (out[cid]) continue;
    var end = s.indexOf('competition_row', m.index + 1);
    if (end < 0) end = Math.min(s.length, m.index + 900);
    else end = Math.min(s.length, end);
    var chunk = s.slice(m.index, end);
    var hrefM = chunk.match(/href\s*=\s*["'](\/competitions\/[^#"']+)["']/i);
    if (hrefM) out[cid] = hrefM[1];
  }
  return out;
}

function parseLiveScoresXml(xml) {
  var out = {};
  var re = /<match\b([^>]*)(?:\/>|>)/gi;
  var m;
  while ((m = re.exec(String(xml || '')))) {
    var attrs = m[1];
    var id = attrValue(attrs, 'id');
    var status = attrValue(attrs, 'status');
    if (!id || !isLiveTimer(status)) continue;
    out[id] = {
      id: id,
      status: status,
      game: attrValue(attrs, 'game'),
      result: attrValue(attrs, 'result'),
      date: attrValue(attrs, 'date'),
      time: attrValue(attrs, 'time'),
      cid: attrValue(attrs, 'cid'),
    };
  }
  return out;
}

async function fetchLiveScores(ctx) {
  try {
    var res = await ctx.fetch(LIVE_SCORES_URL, {
      headers: { Accept: 'application/xml,text/xml,*/*' },
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return parseLiveScoresXml(await res.text());
  } catch (e) {
    return {};
  }
}

function rowFromLiveScore(live, pluginId, competition) {
  var eventId = String(live.id || '');
  if (!eventId) return null;
  var title = titleFromLiveGame(live.game, live.result);
  if (!title) return null;
  var dateMs = parseEtKickoffMs(live.date, live.time);
  if (!dateMs) return null;
  var teams = parseTeams(title);
  var category = normCategory(competition || '');
  var sportMatchGame = {
    id: eventId,
    title: title,
    sport: category,
    category: competition || 'Live Soccer TV',
    homeTeam: teams.home,
    awayTeam: teams.away,
    dateMs: dateMs,
    broadcastChannels: [],
    matchPath: '',
  };
  return {
    id: 'lstv_' + eventId,
    title: title,
    category: category,
    date: dateMs,
    poster: '',
    popular: false,
    airing: true,
    homeTeam: teams.home,
    awayTeam: teams.away,
    sources: [],
    catalog: 'forja_live',
    pluginId: pluginId,
    matchPath: '',
    sportMatchGame: sportMatchGame,
  };
}

function applyLiveScores(rows, liveMap, pluginId, compNames) {
  var seen = {};
  rows.forEach(function (row) {
    var eventId = String(row.id || '').replace(/^lstv_/, '');
    if (!eventId) return;
    seen[eventId] = true;
    row.airing = liveMap[eventId] != null;
  });

  Object.keys(liveMap).forEach(function (id) {
    if (seen[id]) return;
    var comp = compNames && liveMap[id].cid ? compNames[liveMap[id].cid] : '';
    var row = rowFromLiveScore(liveMap[id], pluginId, comp);
    if (row) rows.push(row);
  });
  return rows;
}

async function fetchMissingLiveRows(ctx, cfg, rows, liveMap, compLinks, compNames) {
  var have = {};
  rows.forEach(function (row) {
    have[String(row.id || '').replace(/^lstv_/, '')] = true;
  });

  var pending = [];
  Object.keys(liveMap).forEach(function (id) {
    if (have[id]) return;
    var cid = String(liveMap[id].cid || '');
    var path = compLinks[cid];
    if (!path) return;
    pending.push({ id: id, path: path, cid: cid });
  });
  if (!pending.length) return rows;

  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var seenPath = {};
  for (var i = 0; i < pending.length; i++) {
    var item = pending[i];
    if (seenPath[item.path]) continue;
    seenPath[item.path] = true;
    try {
      var html = await fetchHtml(ctx, cfg, base + item.path);
      var parsed = parsePage(html, pluginIdFromCtx(ctx, cfg));
      parsed.forEach(function (row) {
        var eventId = String(row.id || '').replace(/^lstv_/, '');
        if (!eventId || have[eventId]) return;
        if (!liveMap[eventId]) return;
        have[eventId] = true;
        row.airing = true;
        rows.push(row);
      });
    } catch (e) {}
  }
  return rows;
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

function parseCompetitionNames(html) {
  var out = {};
  var s = String(html || '');

  var re =
    /class\s*=\s*["'][^"']*sortable_comp[^"']*["'][^>]*\bid\s*=\s*["'](\d+)["'][\s\S]*?<span[^>]*>([^<]+)</gi;
  var m;
  while ((m = re.exec(s))) {
    out[m[1]] = m[2].trim();
  }

  var showRe = /showMatches\s*\(\s*['"](\d+)['"]/gi;
  while ((m = showRe.exec(s))) {
    var cid = m[1];
    if (out[cid]) continue;
    var end = s.indexOf('competition_row', m.index + 1);
    if (end < 0) end = Math.min(s.length, m.index + 900);
    else end = Math.min(s.length, end);
    var chunk = s.slice(m.index, end);
    var nameM = chunk.match(/class\s*=\s*["'][^"']*r_compname[^"']*["'][^>]*>([^<]+)</i);
    if (nameM) out[cid] = nameM[1].trim();
  }
  return out;
}

function parsePage(html, pluginId) {
  var out = [];
  var seen = {};
  var compHeads = parseCompetitionHeaders(html);
  var rowRe =
    /<tr[^>]*\bid\s*=\s*["'](\d+)["'][^>]*\bdata-ko\s*=\s*["'][^"']+["'][\s\S]*?<\/tr>/gi;
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
    var airing = isAiring(block);
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

function isUsableHtml(html) {
  var s = String(html || '');
  if (s.length < 400) return false;
  if (isCloudflareChallenge(s)) return false;
  return true;
}

function matchPathFromHtml(html, eventId) {
  var s = String(html || '');
  if (!eventId) return '';
  var byId = new RegExp(
    "href\\s*=\\s*[\"'](\\/match\\/[^#\"']+)#" + eventId + "[\"']",
    'i',
  );
  var hm = s.match(byId);
  if (hm) return hm[1];
  var md = new RegExp(
    "\\]\\((?:https?:\\/\\/[^)]*)?\\/match\\/([^#)]+)#" + eventId + "\\)",
    'i',
  );
  var mm = s.match(md);
  if (mm) return '/match/' + mm[1];
  return '';
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
    if (!isUsableHtml(html)) throw new Error('jina CF');
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
      if (isUsableHtml(html)) return html;
      throw new Error('cloudflare');
    })
    .catch(function () {
      if (flareSolverrBase(ctx)) {
        return fetchTextViaFlareSolverr(ctx, targetUrl).then(function (html) {
          if (isUsableHtml(html)) return html;
          throw new Error('flare unusable');
        });
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
    return {
      html: html,
      rows: parsePage(html, pluginIdFromCtx(ctx, cfg)),
      compLinks: parseCompetitionLinks(html),
      compNames: parseCompetitionNames(html),
    };
  } catch (e) {
    return { html: '', rows: [], compLinks: {}, compNames: {} };
  }
}

async function resolveMatchPath(ctx, cfg, base, row) {
  var path = String(
    row.matchPath || (row.sportMatchGame && row.sportMatchGame.matchPath) || '',
  ).trim();
  if (path) return path;

  var eventId = String(row.id || '').replace(/^lstv_/, '');
  var game = row.sportMatchGame || {};
  var home = String(row.homeTeam || game.homeTeam || '').trim();
  var away = String(row.awayTeam || game.awayTeam || '').trim();
  if (!eventId || !home || !away) return '';

  try {
    var html = await fetchHtml(
      ctx,
      cfg,
      base + '/search/?q=' + encodeURIComponent(home + ' ' + away),
    );
    path = matchPathFromHtml(html, eventId);
    if (path) {
      row.matchPath = path;
      game.matchPath = path;
      row.sportMatchGame = game;
    }
  } catch (e) {}
  return path;
}

async function enrichInternationalCoverage(ctx, cfg, rows) {
  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var pending = [];
  var needPath = [];

  rows.forEach(function (row) {
    var path = String(
      row.matchPath || (row.sportMatchGame && row.sportMatchGame.matchPath) || '',
    ).trim();
    if (path) {
      pending.push({ row: row, url: base + path });
      return;
    }
    needPath.push(row);
  });

  var pathConcurrency = 4;
  for (var p = 0; p < needPath.length; p += pathConcurrency) {
    var pathBatch = needPath.slice(p, p + pathConcurrency);
    await Promise.all(
      pathBatch.map(async function (row) {
        var path = await resolveMatchPath(ctx, cfg, base, row);
        if (path) pending.push({ row: row, url: base + path });
      }),
    );
  }

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

async function fetchBroadcastLookup(ctx, cfg) {
  var home = String(cfg.homeTeam || '').trim();
  var away = String(cfg.awayTeam || '').trim();
  if (!home || !away) return [];
  var eventId = String(cfg.eventId || '').replace(/^lstv_/, '');
  var base = String(cfg.base || SPECS.base).replace(/\/$/, '');
  var row = {
    id: 'lstv_' + (eventId || 'lookup'),
    title: home + ' vs ' + away,
    homeTeam: home,
    awayTeam: away,
    matchPath: String(cfg.matchPath || '').trim(),
    sportMatchGame: {
      id: eventId,
      title: home + ' vs ' + away,
      homeTeam: home,
      awayTeam: away,
      dateMs: Number(cfg.dateMs || 0) || 0,
      broadcastChannels: [],
      matchPath: String(cfg.matchPath || '').trim(),
    },
  };

  if (!row.matchPath && eventId) {
    var liveMap = await fetchLiveScores(ctx);
    var live = liveMap[eventId];
    if (live) {
      var compLinks = {};
      var pages = schedulePages(cfg);
      for (var pi = 0; pi < pages.length; pi++) {
        var sched = await fetchPage(ctx, cfg, pages[pi]);
        Object.keys(sched.compLinks || {}).forEach(function (k) {
          compLinks[k] = sched.compLinks[k];
        });
      }
      var compPath = compLinks[String(live.cid || '')];
      if (compPath) {
        try {
          var compHtml = await fetchHtml(ctx, cfg, base + compPath);
          var fromComp = matchPathFromHtml(compHtml, eventId);
          if (fromComp) {
            row.matchPath = fromComp;
            row.sportMatchGame.matchPath = fromComp;
          }
        } catch (e) {}
      }
    }
  }

  await enrichInternationalCoverage(ctx, cfg, [row]);
  var game = row.sportMatchGame || {};
  var channels = game.broadcastChannels || row.broadcastChannels || [];
  if (!channels.length) return [];
  return [
    {
      id: row.id,
      title: row.title,
      sportMatchGame: game,
      broadcastChannels: channels,
    },
  ];
}

async function fetchCatalog(ctx, cfg) {
  if (cfg.broadcastLookup) {
    return fetchBroadcastLookup(ctx, cfg);
  }
  var pages = schedulePages(cfg);
  var seen = {};
  var out = [];
  var compLinks = {};
  var compNames = {};
  for (var i = 0; i < pages.length; i++) {
    var page = await fetchPage(ctx, cfg, pages[i]);
    Object.keys(page.compLinks || {}).forEach(function (k) {
      compLinks[k] = page.compLinks[k];
    });
    Object.keys(page.compNames || {}).forEach(function (k) {
      compNames[k] = page.compNames[k];
    });
    (page.rows || []).forEach(function (row) {
      var key = String(row.id || row.title);
      if (seen[key]) return;
      seen[key] = true;
      out.push(row);
    });
  }

  var liveMap = await fetchLiveScores(ctx);
  await fetchMissingLiveRows(ctx, cfg, out, liveMap, compLinks, compNames);
  applyLiveScores(out, liveMap, pluginIdFromCtx(ctx, cfg), compNames);

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
