var SPECS = {
  "origin": "https://playhydrax.com",
  "enc": "https://enc-dec.app/api"
};

function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var enc = cfg.enc;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var origin = cfg.origin;
  var headers = {
    'User-Agent': ua,
    Origin: origin,
    Referer: origin + '/',
  };

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o)) o.forEach(function (e) { walk(e, urls); });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream', 'link'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  return ctx
    .fetch(url, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var encrypted = (html.match(/const\s+datas\s*=\s*"([^"]*)"/) || [])[1];
      if (!encrypted) return [];
      return ctx
        .fetch(enc + '/dec-abyss', {
          method: 'POST',
          headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({ text: encrypted }),
        })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          var urls = [];
          walk(validate(j), urls);
          return urls.map(function (u) {
            return {
              url: u,
              name: 'Abyss',
              headers: { 'User-Agent': ua, Referer: origin + '/' },
            };
          });
        });
    })
    .catch(function () {
      return [];
    });
}
