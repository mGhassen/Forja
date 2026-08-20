function extract(ctx) {
  var cfg = ctx.config || {};
  var hostId = cfg.hostId;
  ctx.log(
    'host_wrap has no HTTP extract — hostId=' +
      (hostId || '') +
      ' (Forja JS-only; green Play still has Dart/Rust)',
  );
  return Promise.resolve([]);
}
