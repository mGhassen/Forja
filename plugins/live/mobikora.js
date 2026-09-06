var SPECS = {
  origin: 'https://mobikora.live',
};

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

function withChannelLabel(rows, channelUrl) {
  var label = channelLabel(channelUrl);
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    if (!row || !row.url) continue;
    if (row.name && row.name.indexOf(label) < 0) {
      row.name =
        'MobiKora · ' +
        label +
        ' · ' +
        String(row.name || '').replace(/^MobiKora · /, '');
    }
    out.push(row);
  }
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];

  // Prefer matchId (channel HTML) over a stale signed m3u8 in embedUrl.
  var channelUrl =
    channelUrlFromMatchId(ctx.matchId) ||
    String(ctx.embedUrl || ctx.url || '').trim();
  if (!channelUrl) return [];

  var rows = await nestUnlockChannel(ctx, channelUrl, {
    brand: 'MobiKora',
    originReferer: SPECS.origin + '/',
  });
  return withChannelLabel(rows, channelUrl);
}
