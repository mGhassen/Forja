var SPECS = {
  origin: 'https://mobikora.live',
  pages: ['/', '/matches-today/', '/matches-tomorrow/'],
  // Schedule times on the site are Cairo local.
  tzOffset: '+03:00',
};

var CATALOG_MAX = 120;

function ua() {
  return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
}

function originOf(cfg) {
  return String((cfg && cfg.origin) || SPECS.origin).replace(/\/$/, '');
}

function absUrl(origin, href) {
  var h = String(href || '').trim();
  if (!h || h === '#' || h === '/') return '';
  if (/^https?:\/\//i.test(h)) return h;
  if (h.charAt(0) !== '/') h = '/' + h;
  return origin + h;
}

function decodeEntities(s) {
  return String(s || '')
    .replace(/&#(\d+);/g, function (_, n) {
      return String.fromCharCode(Number(n));
    })
    .replace(/&#x([0-9a-f]+);/gi, function (_, h) {
      return String.fromCharCode(parseInt(h, 16));
    })
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ');
}

function stripTags(s) {
  return decodeEntities(String(s || '').replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

function b64url(raw) {
  var s = String(raw || '');
  var bin = '';
  try {
    if (typeof TextEncoder !== 'undefined') {
      var bytes = new TextEncoder().encode(s);
      for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    } else {
      bin = unescape(encodeURIComponent(s));
    }
  } catch (_) {
    bin = s;
  }
  try {
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  } catch (_) {
    return encodeURIComponent(s).replace(/%/g, '');
  }
}

function channelLabel(url) {
  try {
    var u = new URL(url);
    var slug = u.pathname
      .replace(/\.html?$/i, '')
      .split('/')
      .filter(Boolean)
      .pop();
    if (!slug) return 'MobiKora';
    return slug
      .replace(/[-_]+/g, ' ')
      .replace(/\b\w/g, function (c) {
        return c.toUpperCase();
      });
  } catch (_) {
    return 'MobiKora';
  }
}

function parseKickoffMs(title, timeHm, tzOffset) {
  var dateM = String(title || '').match(/بتاريخ\s+(\d{4}-\d{2}-\d{2})/);
  var day = dateM ? dateM[1] : '';
  var hm = String(timeHm || '').trim();
  if (!day || !/^\d{1,2}:\d{2}$/.test(hm)) return 0;
  var parts = hm.split(':');
  var hh = parts[0].length === 1 ? '0' + parts[0] : parts[0];
  var mm = parts[1];
  var ms = Date.parse(day + 'T' + hh + ':' + mm + ':00' + (tzOffset || '+03:00'));
  return isNaN(ms) ? 0 : ms;
}

function isAiringClass(cls, stat) {
  var c = String(cls || '').toLowerCase();
  if (/\blive\b/.test(c) || /\bgools\b/.test(c) || /\bstarted\b/.test(c)) return true;
  var s = String(stat || '');
  return /جارية|مباشر|live/i.test(s);
}

function isFinishedClass(cls, stat) {
  var c = String(cls || '').toLowerCase();
  if (/\bfinished\b/.test(c)) return true;
  return /انتهت|finished|ft\b/i.test(String(stat || ''));
}

function inCatalogWindow(ms) {
  if (!ms) return true;
  var now = Date.now();
  return ms >= now - 6 * 3600000 && ms <= now + 2 * 24 * 3600000;
}

function parseMatchBlock(block, origin, tzOffset) {
  var clsM = String(block || '').match(/class=["']AY_Match\s+([^"']+)["']/i);
  var cls = clsM ? clsM[1] : '';
  var names = [];
  var nameRe = /class=["']TM_Name["'][^>]*>([\s\S]*?)<\/div>/gi;
  var nm;
  while ((nm = nameRe.exec(block))) {
    var name = stripTags(nm[1]);
    if (name) names.push(name);
  }
  var home = names[0] || '';
  var away = names[1] || '';
  if (!home && !away) return null;

  var timeM = block.match(/class=["']MT_Time["'][^>]*>([\s\S]*?)<\/(?:span|div|strong)>/i);
  var timeHm = timeM ? stripTags(timeM[1]) : '';
  var statM = block.match(/class=["']MT_Stat["'][^>]*>([\s\S]*?)<\/(?:div|span|strong)>/i);
  var stat = statM ? stripTags(statM[1]) : '';
  if (isFinishedClass(cls, stat)) return null;

  var tourM = block.match(/class=["']TourName["'][^>]*>([\s\S]*?)<\/div>/i);
  var tour = tourM ? stripTags(tourM[1]) : '';

  var linkM = block.match(/<a\s+href=["']([^"']*)["'][^>]*title=["']([^"']*)["']/i);
  var href = linkM ? decodeEntities(linkM[1]) : '';
  var titleAttr = linkM ? decodeEntities(linkM[2]) : '';
  var channelUrl = absUrl(origin, href);
  if (!channelUrl) return null;

  var badges = [];
  var badgeRe = /(?:data-src|src)="(https?:\/\/[^"]+\.(?:png|jpe?g|webp|gif)[^"]*)"/gi;
  var bm;
  while ((bm = badgeRe.exec(block))) {
    if (badges.indexOf(bm[1]) < 0) badges.push(bm[1]);
  }

  var dateMs = parseKickoffMs(titleAttr, timeHm, tzOffset);
  if (!inCatalogWindow(dateMs)) return null;

  var airing = isAiringClass(cls, stat);
  var mid = b64url(channelUrl);
  var title =
    home && away ? home + ' vs ' + away : home || away || channelLabel(channelUrl);
  var label = channelLabel(channelUrl);

  var row = {
    id: 'mk_' + mid,
    title: title,
    category: 'football',
    date: dateMs || Date.now(),
    poster: badges[0] || '',
    popular: airing || /\bcomming-soon\b/i.test(cls),
    airing: airing,
    viewers: 0,
    sources: [{ source: 'mobikora', id: mid }],
    streams: [
      {
        id: mid + '_1',
        streamNo: 1,
        language: label,
        hd: false,
        embedUrl: channelUrl,
        source: 'mobikora',
        viewers: 0,
      },
    ],
    catalog: 'forja_live',
    streamCount: 1,
  };
  if (home) row.homeTeam = home;
  if (away) row.awayTeam = away;
  if (badges[0]) row.homeBadge = badges[0];
  if (badges[1]) row.awayBadge = badges[1];
  if (tour) row.league = tour;
  return row;
}

function parseMatchesHtml(html, origin, tzOffset) {
  var parts = String(html || '').split(/(?=<div class="AY_Match\s)/i);
  var out = [];
  var seen = {};
  for (var i = 1; i < parts.length; i++) {
    var end = parts[i].search(/<\/div>\s*(?=<div class="AY_Match\s|<div class="AY_Block|<\/div>\s*<\/div>\s*<div class="AY_Block)/i);
    var block = end > 0 ? parts[i].slice(0, end + 6) : parts[i].slice(0, 4000);
    var row = parseMatchBlock(block, origin, tzOffset);
    if (!row || !row.id || seen[row.id]) continue;
    seen[row.id] = 1;
    out.push(row);
  }
  return out;
}

async function fetchPage(ctx, url) {
  var res = await ctx.fetch(url, {
    headers: {
      'User-Agent': ua(),
      Accept: 'text/html,application/xhtml+xml',
      'Accept-Language': 'ar,en;q=0.8',
    },
  });
  if (!res.ok) return '';
  return await res.text();
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var pluginId = String(cfg.providerId || 'live-mobikora');
  var origin = originOf(cfg);
  var pages = Array.isArray(cfg.pages) && cfg.pages.length ? cfg.pages : SPECS.pages;
  var tzOffset = String(cfg.tzOffset || SPECS.tzOffset);

  var byId = {};
  for (var i = 0; i < pages.length; i++) {
    var path = String(pages[i] || '').trim() || '/';
    var url = path.indexOf('http') === 0 ? path : origin + (path.charAt(0) === '/' ? path : '/' + path);
    try {
      var html = await fetchPage(ctx, url);
      if (!html) continue;
      var rows = parseMatchesHtml(html, origin, tzOffset);
      for (var j = 0; j < rows.length; j++) {
        var row = rows[j];
        row.pluginId = pluginId;
        if (!byId[row.id] || (row.airing && !byId[row.id].airing)) {
          byId[row.id] = row;
        }
      }
    } catch (_) {}
  }

  return Object.keys(byId)
    .map(function (k) {
      return byId[k];
    })
    .sort(function (a, b) {
      if (a.airing !== b.airing) return a.airing ? -1 : 1;
      return Number(a.date || 0) - Number(b.date || 0);
    })
    .slice(0, CATALOG_MAX);
}
