var SPECS = {
  origin: 'https://mobikora.live',
};

function ua() {
  return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
}

function decodeB64url(raw) {
  var s = String(raw || '')
    .replace(/-/g, '+')
    .replace(/_/g, '/');
  while (s.length % 4) s += '=';
  try {
    var bin = atob(s);
    if (typeof TextDecoder !== 'undefined') {
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i) & 0xff;
      return new TextDecoder('utf-8').decode(bytes);
    }
    return decodeURIComponent(escape(bin));
  } catch (_) {
    try {
      return decodeURIComponent(String(raw || ''));
    } catch (e2) {
      return '';
    }
  }
}

function channelUrlFromMatchId(mid) {
  var id = String(mid || '').replace(/^mk_/, '').trim();
  if (!id) return '';
  if (/^https?:\/\//i.test(id)) return id;
  return decodeB64url(id);
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

function uniq(urls) {
  var out = [];
  var seen = {};
  for (var i = 0; i < urls.length; i++) {
    var u = String(urls[i] || '').trim();
    if (!u || seen[u]) continue;
    seen[u] = 1;
    out.push(u);
  }
  return out;
}

function extractIframeSrcs(html) {
  var out = [];
  var re = /<iframe\b[^>]*\bsrc=["']([^"']+)["']/gi;
  var m;
  while ((m = re.exec(String(html || '')))) {
    var src = String(m[1] || '').trim();
    if (src) out.push(src);
  }
  return uniq(out);
}

function htmlUnescape(s) {
  return String(s || '')
    .replace(/&quot;/gi, '"')
    .replace(/&#34;/g, '"')
    .replace(/&amp;/gi, '&')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>');
}

function isCleanPlayUrl(url) {
  var u = String(url || '').trim();
  if (!/^https?:\/\//i.test(u)) return false;
  if (/&quot;|&amp;|"|'/i.test(u)) return false;
  if (/\.s3\.us-north-\d+\.amazonaws\.com/i.test(u)) return false;
  return true;
}

function extractOkRuHls(html) {
  var text = htmlUnescape(html);
  var out = [];
  var keys = ['hlsMasterPlaylistUrl', 'hlsPlaybackMasterPlaylistUrl'];
  for (var i = 0; i < keys.length; i++) {
    var re = new RegExp('"' + keys[i] + '"\\s*:\\s*"([^"]+)"', 'gi');
    var m;
    while ((m = re.exec(text))) {
      var url = String(m[1] || '').trim();
      if (isCleanPlayUrl(url)) out.push(url);
    }
  }
  return uniq(out);
}

function extractM3u8(html) {
  var out = extractOkRuHls(html);
  var text = htmlUnescape(html);
  var re = /https?:\/\/[^\s"'<>\\]+?\.m3u8[^\s"'<>\\]*/gi;
  var m;
  while ((m = re.exec(text))) {
    var url = m[0].replace(/\\+$/, '').replace(/&amp;/g, '&');
    if (isCleanPlayUrl(url)) out.push(url);
  }
  var srcRe = /(?:source|file|src)\s*[:=]\s*["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/gi;
  while ((m = srcRe.exec(text))) {
    if (isCleanPlayUrl(m[1])) out.push(m[1]);
  }
  return uniq(out);
}

function extractServPages(playerHtml, baseUrl) {
  var out = [baseUrl];
  var re = /href=["']([^"']+\?serv=\d+)["']/gi;
  var m;
  while ((m = re.exec(String(playerHtml || '')))) {
    var href = String(m[1] || '').trim();
    if (!href) continue;
    try {
      out.push(new URL(href, baseUrl).href);
    } catch (_) {
      out.push(href);
    }
  }
  return uniq(out);
}

function servLabel(url, html) {
  try {
    var u = new URL(url);
    var serv = u.searchParams.get('serv');
    if (serv) {
      var re = new RegExp(
        'href=["\'][^"\']*\\?serv=' + serv + '["\'][^>]*>([\\s\\S]*?)<\\/a>',
        'i',
      );
      var m = String(html || '').match(re);
      if (m) {
        var label = String(m[1] || '')
          .replace(/<[^>]+>/g, ' ')
          .replace(/\s+/g, ' ')
          .trim();
        if (label) return label;
      }
      return 'Server ' + serv;
    }
  } catch (_) {}
  var active = String(html || '').match(
    /class=["'][^"']*aplr-link[^"']*active[^"']*["'][^>]*>([\s\S]*?)<\/a>/i,
  );
  if (active) {
    var activeLabel = String(active[1] || '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (activeLabel) return activeLabel;
  }
  return 'Server';
}

async function fetchHtml(ctx, url, referer) {
  var headers = {
    'User-Agent': ua(),
    Accept: 'text/html,application/xhtml+xml',
  };
  if (referer) headers.Referer = referer;
  try {
    var res = await ctx.fetch(url, { headers: headers });
    if (!res || !res.ok) return '';
    return await res.text();
  } catch (_) {
    return '';
  }
}

function isBrightcoveUrl(url) {
  try {
    return new URL(String(url || '')).host.toLowerCase().indexOf('brightcove') >= 0;
  } catch (_) {
    return /brightcove\.com/i.test(String(url || ''));
  }
}

function isAmazonS3Url(url) {
  try {
    return (
      new URL(String(url || '')).host.toLowerCase().indexOf('amazonaws.com') >=
      0
    );
  } catch (_) {
    return /amazonaws\.com/i.test(String(url || ''));
  }
}

function isOkCdUrl(url) {
  try {
    var h = new URL(String(url || '')).host.toLowerCase();
    return (
      h.indexOf('okcdn.ru') >= 0 ||
      h.indexOf('vkuser.net') >= 0 ||
      h.indexOf('ok.ru') >= 0 ||
      h.endsWith('.ok.ru')
    );
  } catch (_) {
    return /okcdn\.ru|vkuser\.net|\bok\.ru\b/i.test(String(url || ''));
  }
}

/** Bunny/Livepeer edge returns 307 — MediaKit often won't follow; open final. */
function canonicalizePlayUrl(url) {
  var raw = String(url || '').trim();
  if (!raw) return '';
  try {
    var u = new URL(raw);
    var host = u.host.toLowerCase();
    if (host === 'livepeercdn.studio' || host === 'cdn.livepeer.com') {
      u.host = 'playback.livepeer.studio';
      return u.href;
    }
  } catch (_) {}
  return raw;
}

function playbackHeaders(playUrl, playerPageUrl) {
  if (isBrightcoveUrl(playUrl) || isAmazonS3Url(playUrl)) {
    return { 'User-Agent': ua() };
  }
  if (isOkCdUrl(playUrl)) {
    return {
      Referer: 'https://ok.ru/',
      Origin: 'https://ok.ru',
      'User-Agent': ua(),
    };
  }
  var origin = '';
  try {
    origin = new URL(playerPageUrl || playUrl).origin;
  } catch (_) {}
  return {
    Referer: playerPageUrl || origin + '/',
    Origin: origin || 'https://25.streemach.fun',
    'User-Agent': ua(),
  };
}

function playRow(url, name, playerPageUrl) {
  var playUrl = canonicalizePlayUrl(url);
  return {
    url: playUrl,
    name: name || 'MobiKora',
    headers: playbackHeaders(playUrl, playerPageUrl),
    // S3/Foorja: hls-proxy. OK.ru signed HLS + others: direct with headers.
    directPlayback: !isAmazonS3Url(playUrl),
  };
}

/**
 * Only drop clearly dead URLs. Do NOT require a live #EXTM3U probe — OK.ru /
 * Livepeer flap and a failed probe caused empty Providers while web still played.
 */
function acceptPlayUrl(url) {
  var playUrl = canonicalizePlayUrl(url);
  if (!isCleanPlayUrl(playUrl)) return '';
  return playUrl;
}

function nestedEmbedUrls(html, baseUrl) {
  var out = [];
  var iframes = extractIframeSrcs(html);
  for (var i = 0; i < iframes.length; i++) {
    var src = String(iframes[i] || '').trim();
    if (!src || /^javascript:/i.test(src)) continue;
    if (
      /acscdn|doubleclick|googlesyndication|pagead2|adservice|\.js($|\?)|\.css($|\?)/i.test(
        src,
      )
    ) {
      continue;
    }
    var abs = src;
    try {
      abs = new URL(src, baseUrl).href;
    } catch (_) {}
    if (!/^https?:\/\//i.test(abs)) continue;
    out.push(abs);
  }
  return uniq(out);
}

async function unlockPlayerPage(ctx, playerUrl, channelReferer, depth, seenPages) {
  depth = depth || 0;
  if (depth > 4) return [];
  seenPages = seenPages || {};
  var key = String(playerUrl || '').trim();
  if (!key || seenPages[key]) return [];
  seenPages[key] = 1;

  var html = await fetchHtml(ctx, playerUrl, channelReferer || playerUrl);
  if (!html) return [];

  var pages = extractServPages(html, playerUrl);
  var out = [];
  var seen = {};

  for (var i = 0; i < pages.length; i++) {
    var pageUrl = pages[i];
    var pageHtml =
      pageUrl === playerUrl ? html : await fetchHtml(ctx, pageUrl, playerUrl);
    if (!pageHtml) continue;
    seenPages[pageUrl] = 1;

    var m3u8s = extractM3u8(pageHtml);
    var label = servLabel(pageUrl, pageHtml);
    for (var j = 0; j < m3u8s.length; j++) {
      var accepted = acceptPlayUrl(m3u8s[j]);
      if (!accepted || seen[accepted]) continue;
      seen[accepted] = 1;
      out.push(playRow(accepted, 'MobiKora · ' + label, pageUrl));
    }

    // Nest: AlbaPlayer → tirfoot/blogger → ok.ru embed → signed HLS.
    if (!out.length && depth < 4) {
      var nested = nestedEmbedUrls(pageHtml, pageUrl);
      for (var k = 0; k < nested.length; k++) {
        var nestUrl = nested[k];
        if (seenPages[nestUrl]) continue;
        var nestRows = await unlockPlayerPage(
          ctx,
          nestUrl,
          pageUrl,
          depth + 1,
          seenPages,
        );
        for (var n = 0; n < nestRows.length; n++) {
          var row = nestRows[n];
          if (!row || !row.url || seen[row.url]) continue;
          seen[row.url] = 1;
          if (row.name && row.name.indexOf(label) < 0) {
            row.name =
              'MobiKora · ' +
              label +
              ' · ' +
              String(row.name || '').replace(/^MobiKora · /, '');
          }
          out.push(row);
        }
      }
    }
  }
  return out;
}

async function unlockChannelPage(ctx, channelUrl) {
  var raw = String(channelUrl || '').trim();
  if (!raw) return [];

  if (/\.m3u8|\.mp4/i.test(raw)) {
    if (/\.mp4/i.test(raw) && !/\.m3u8/i.test(raw)) {
      return [playRow(raw, 'MobiKora', raw)];
    }
    var ready = acceptPlayUrl(raw);
    return ready ? [playRow(ready, 'MobiKora', raw)] : [];
  }

  // Direct OK.ru embed URL from a nest.
  if (/ok\.ru\/videoembed\//i.test(raw)) {
    var okHtml = await fetchHtml(ctx, raw, 'https://ok.ru/');
    if (!okHtml) return [];
    var okUrls = extractM3u8(okHtml);
    var okOut = [];
    for (var oi = 0; oi < okUrls.length; oi++) {
      var okReady = acceptPlayUrl(okUrls[oi]);
      if (!okReady) continue;
      okOut.push(playRow(okReady, 'MobiKora · OK', raw));
    }
    return okOut;
  }

  if (/albaplayer/i.test(raw)) {
    return unlockPlayerPage(ctx, raw, raw);
  }

  var html = await fetchHtml(ctx, raw, SPECS.origin + '/');
  if (!html) return [];

  var direct = extractM3u8(html);
  if (direct.length) {
    var rows = [];
    var seenDirect = {};
    for (var d = 0; d < direct.length; d++) {
      var accepted = acceptPlayUrl(direct[d]);
      if (!accepted || seenDirect[accepted]) continue;
      seenDirect[accepted] = 1;
      rows.push(playRow(accepted, 'MobiKora · ' + channelLabel(raw), raw));
    }
    if (rows.length) return rows;
  }

  var iframes = extractIframeSrcs(html).filter(function (src) {
    return /albaplayer|streemach|player|ok\.ru\/videoembed/i.test(src);
  });
  if (!iframes.length) return [];

  var out = [];
  var seen = {};
  for (var i = 0; i < iframes.length; i++) {
    var nestRows = [];
    try {
      nestRows = await unlockPlayerPage(ctx, iframes[i], raw);
    } catch (_) {
      nestRows = [];
    }
    for (var j = 0; j < nestRows.length; j++) {
      var row = nestRows[j];
      if (!row || !row.url || seen[row.url]) continue;
      seen[row.url] = 1;
      if (row.name && row.name.indexOf(channelLabel(raw)) < 0) {
        row.name =
          'MobiKora · ' +
          channelLabel(raw) +
          ' · ' +
          row.name.replace(/^MobiKora · /, '');
      }
      out.push(row);
    }
  }
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];

  var embed = String(ctx.embedUrl || ctx.url || '').trim();
  if (embed) return unlockChannelPage(ctx, embed);

  var channelUrl = channelUrlFromMatchId(ctx.matchId);
  if (!channelUrl) return [];
  return unlockChannelPage(ctx, channelUrl);
}
