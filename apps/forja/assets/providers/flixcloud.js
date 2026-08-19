function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://flixcloud.cc';
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var page = ctx.url || '';
  var headers = { 'User-Agent': ua, Referer: origin + '/' };

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  if (!page || !/flixcloud\./i.test(page)) {
    return ctx.host('flixcloud');
  }

  return ctx
    .fetch(page, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var m = html.match(/type:\s*"data",\s*data:\s*(\{[\s\S]*?\})\s*,\s*uses:/);
      if (!m) return ctx.host('flixcloud');
      var data;
      try {
        data = new Function('return (' + m[1] + ')')();
      } catch (e) {
        data = null;
      }
      if (!data) return ctx.host('flixcloud');
      delete data.subtitles;
      return ctx
        .fetch(enc + '/dec-flixcloud?type=token', {
          method: 'POST',
          headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({ data: data }),
        })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          var token = validate(j);
          if (!token || !token.token) return ctx.host('flixcloud');
          return ctx
            .fetch(origin + '/api/m3u8/' + token.token, { headers: headers })
            .then(function (r) {
              return r.json();
            })
            .then(function (streamResponse) {
              return ctx
                .fetch(enc + '/dec-flixcloud?type=stream', {
                  method: 'POST',
                  headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
                  body: JSON.stringify({
                    data: { context: token.context, stream_response: streamResponse },
                  }),
                })
                .then(function (r) {
                  return r.json();
                })
                .then(function (sj) {
                  var resolved = validate(sj);
                  var stream = resolved && resolved.stream;
                  if (!stream) return ctx.host('flixcloud');
                  return [
                    {
                      url: stream,
                      name: 'FlixCloud',
                      headers: { 'User-Agent': ua, Referer: origin + '/' },
                    },
                  ];
                });
            });
        });
    })
    .catch(function () {
      return ctx.host('flixcloud');
    });
}
