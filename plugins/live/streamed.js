var SPECS = {
  "origin": "https://streamed.pk",
  "embedOrigin": "https://embed.st"
};

async function resolveStream(ctx, cfg) {
  var embedUrl = String(ctx.embedUrl || ctx.url || '').trim();
  var slot = parseEmbedUrl(embedUrl, cfg);
  if (!slot) {
    if (ctx.source && ctx.matchId && ctx.stream) {
      slot = {
        origin: embedOrigin(cfg),
        source: String(ctx.source),
        id: String(ctx.matchId),
        stream: String(ctx.stream),
        path: ctx.source + '/' + ctx.matchId + '/' + ctx.stream,
      };
    }
  }
  if (!slot) throw new Error('streamed resolve: missing embed slot');

  // golf is a normal GOAT slot now (old exposestrat.com scrape is dead).
  var fetched = await postFetch(ctx, slot, cfg);
  var m3u8 = '';
  if (ctx.live && typeof ctx.live.goatUnlock === 'function') {
    m3u8 = await ctx.live.goatUnlock(fetched.bodyHex, fetched.goat, slot);
  }
  if (!m3u8) throw new Error('goat unlock failed');
  var headers = playbackHeadersForSlot(slot, cfg);
  var src = String(slot.source || '').toLowerCase();
  if (src === 'echo' || src === 'streamed' || src === 'golf') {
    if (!(await probePlayableM3u8(ctx, m3u8, headers))) {
      throw new Error('goat m3u8 not playable');
    }
  }
  return [
    {
      url: m3u8,
      headers: headers,
      directPlayback: preferDirectPlayback(m3u8),
    },
  ];
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  return resolveStream(ctx, Object.assign({}, SPECS, ctx.config || {}));
}
