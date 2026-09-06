function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

var CATALOG_MAX = 120;

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

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('pilkanozna') >= 0 || s.indexOf('pilka') >= 0) return 'football';
  if (s.indexOf('basket') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
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

function countEmbeds(m) {
  var n = 0;
  (m._embeds || []).forEach(function (group) {
    n += embedRows(group).length;
  });
  return n;
}

function streamsFromEmbeds(m) {
  var out = [];
  var n = 0;
  var id = String((m && m.id) || '');
  (m._embeds || []).forEach(function (group) {
    var lang = String(group.language || '').trim();
    embedRows(group).forEach(function (e) {
      var url = String((e && (e.embed || e.url)) || '').trim();
      if (!url) return;
      n += 1;
      var label = String((e && e.label) || '').trim();
      var language = lang && label ? lang + ' · ' + label : lang || label || '';
      out.push({
        id: id ? id + '_' + n : String(n),
        streamNo: n,
        language: language,
        hd: /uhd|fhd|\bhd\b|4k/i.test(label + ' ' + lang),
        embedUrl: url,
        source: 'streamic',
        viewers: 0,
      });
    });
  });
  return out;
}

async function fetchPopularList(ctx, cfg) {
  var origin = streamicOrigin(cfg);
  var api = (cfg && cfg.popularApi) || origin + '/api/J.php';
  try {
    var res = await ctx.fetch(api, { headers: streamicHeaders(cfg) });
    if (!res.ok) return [];
    var data = await res.json();
    return Array.isArray(data) ? data : data.events || data.streams || [];
  } catch (_) {
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
  } catch (_) {
    return [];
  }
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, ctx.config || {});
  var pluginId = String(cfg.providerId || 'live-streamic');
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
    if (!byId[id]) byId[id] = m;
    else if (m._embeds && m._embeds.length) byId[id]._embeds = m._embeds;
  });

  return Object.keys(byId)
    .map(function (k) {
      return byId[k];
    })
    .filter(function (m) {
      return inCatalogWindow(m.startTime ? Number(m.startTime) : 0);
    })
    .sort(function (a, b) {
      if (a._popular === true && b._popular !== true) return -1;
      if (b._popular === true && a._popular !== true) return 1;
      return Number(a.startTime || 0) - Number(b.startTime || 0);
    })
    .slice(0, CATALOG_MAX)
    .map(function (m, i) {
      var id = String(m.id || i);
      var startTime = m.startTime ? Number(m.startTime) : 0;
      var airing = isAiring(startTime);
      var teams = parseTeams(m);
      var nEmbeds = countEmbeds(m);
      var streams = streamsFromEmbeds(m);
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
        streams: streams,
        catalog: 'forja_live',
        pluginId: pluginId,
        streamCount: nEmbeds || streams.length,
      };
      if (teams.home) row.homeTeam = teams.home;
      if (teams.away) row.awayTeam = teams.away;
      return row;
    });
}
