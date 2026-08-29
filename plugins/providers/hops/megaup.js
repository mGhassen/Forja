var SPECS = {
  "enc": "https://enc-dec.app/api",
  "dec": "dec-mega"
};

function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var enc = cfg.enc;
  var dec = cfg.dec;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var referer = url.split('/e/')[0] + '/';
  if (referer === url + '/') {
    try {
      referer = new URL(url).origin + '/';
    } catch (e) {
      referer = url;
    }
  }
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json',
    Referer: referer,
  };
  var media = url.replace('/e/', '/media/').replace('/e2/', '/media/');

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
    .fetch(media, { headers: headers })
    .then(function (r) {
      return r.json();
    })
    .then(function (mediaJson) {
      var encrypted = mediaJson && mediaJson.result;
      if (!encrypted) return [];
      return ctx
        .fetch(enc + '/' + dec, {
          method: 'POST',
          headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({ text: encrypted, agent: ua }),
        })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          var payload = validate(j);
          var urls = [];
          walk(payload, urls);
          (payload && payload.sources ? payload.sources : []).forEach(function (s) {
            if (s && s.file) urls.push(s.file);
          });
          var seen = {};
          return urls
            .filter(function (u) {
              if (seen[u]) return false;
              seen[u] = true;
              return true;
            })
            .map(function (u) {
              return {
                url: u,
                name: cfg.name || (dec === 'dec-rapid' ? 'Rapidshare' : 'MegaUp'),
                headers: { 'User-Agent': ua, Referer: referer },
              };
            });
        });
    })
    .catch(function () {
      return [];
    });
}
