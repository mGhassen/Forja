function extract(ctx) {
  var cfg = ctx.config || {};
  var hostId = cfg.hostId;
  if (!hostId) return Promise.resolve([]);
  return ctx.host(hostId);
}
