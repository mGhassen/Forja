function ppvHeaders(cfg) {
  var origin = ((cfg && cfg.webOrigin) || 'https://ppv.st').replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

function ppvIframeFromDetail(data) {
  if (!data) return '';
  var sources = data.sources;
  if (!Array.isArray(sources)) return '';
  var picked = '';
  for (var i = 0; i < sources.length; i++) {
    var s = sources[i];
    if (!s) continue;
    var url = String(s.data || s.url || '').trim();
    if (!url || !/^https?:/i.test(url)) continue;
    if (s.default === true) return url;
    if (!picked) picked = url;
  }
  return picked;
}

function ppvPlayableUrl(data) {
  if (!data) return '';
  var fields = [data.m3u8, data.source, data.vip_mpegts];
  for (var i = 0; i < fields.length; i++) {
    var url = String(fields[i] || '').trim();
    if (url && /\.m3u8|\.mp4/i.test(url)) return url;
  }
  return '';
}

async function resolvePpv(ctx, cfg) {
  var streamId = String(ctx.matchId || (cfg && cfg.streamId) || '').replace(/^ppv_/, '');
  var iframe = String(ctx.embedUrl || ctx.iframe || (cfg && cfg.iframe) || '').trim();
  if (streamId) {
    var apis = (cfg && cfg.apis) || [
      'https://api.ppv.st/api/streams',
      'https://api.ppv.cx/api/streams',
    ];
    var headers = ppvHeaders(cfg);
    for (var i = 0; i < apis.length; i++) {
      try {
        var base = apis[i].replace(/\/$/, '');
        var detail = await ctx.fetch(base + '/' + streamId, { headers: headers });
        if (!detail.ok) continue;
        var body = await detail.json();
        if (!body || body.success !== true || !body.data) continue;
        var source = ppvPlayableUrl(body.data);
        if (source) {
          return [{ url: source, headers: headers }];
        }
        var fromDetail = ppvIframeFromDetail(body.data);
        if (fromDetail) iframe = fromDetail;
      } catch (_) {}
    }
  }
  if (iframe) {
    try {
      if (isEmbedIndiaUrl(iframe)) {
        var embedIndia = await resolveEmbedIndia(ctx, iframe, cfg);
        if (embedIndia) return embedIndia;
      }
      if (iframe.indexOf('embed.st') >= 0) {
        var embedResolved = await resolveGoatEmbed(ctx, iframe, cfg);
        if (embedResolved) return embedResolved;
      }
    } catch (_) {}
  }
  return [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  return resolvePpv(ctx, ctx.config || {});
}
