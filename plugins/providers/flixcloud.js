var SPECS = {
  "origin": "https://flixcloud.cc",
  "enc": "https://enc-dec.app/api",
  "name": "FlixCloud"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var origin = cfg.origin;
  var enc = cfg.enc;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: origin + '/' };

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  function pageUrl() {
    var page = (ctx.url || '').trim();
    if (!page || !/flixcloud\./i.test(page)) return '';
    return page;
  }

  var page = pageUrl();
  if (!page) {
    ctx.error('flixcloud: embed url required');
    return [];
  }

  return ctx
    .fetch(page, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var m = html.match(/type:\s*"data",\s*data:\s*(\{[\s\S]*?\})\s*,\s*uses:/);
      if (!m) {
        ctx.error('flixcloud: page data block missing');
        return [];
      }
      var data;
      try {
        data = new Function('return (' + m[1] + ')')();
      } catch (e) {
        data = null;
      }
      if (!data) {
        ctx.error('flixcloud: page data parse failed');
        return [];
      }
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
          if (!token || !token.token) {
            ctx.error('flixcloud: enc-dec token failed');
            return [];
          }
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
                  if (!stream) {
                    ctx.error('flixcloud: stream decrypt empty');
                    return [];
                  }
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
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
