function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://cinesrc.st';
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var imdb = ctx.imdbId || '';
  var tmdbId = String(ctx.tmdbId);
  var url =
    ctx.type === 'movie'
      ? origin + '/embed/movie/' + (imdb || tmdbId)
      : origin +
        '/embed/tv/' +
        (imdb || tmdbId) +
        '?s=' +
        (ctx.season || 1) +
        '&e=' +
        (ctx.episode || 1);
  var headers = {
    Origin: origin,
    Referer: origin + '/',
    'Content-Type': 'text/plain;charset=UTF-8',
    'User-Agent': ua,
  };

  ctx.log('start ' + url);

  function validate(j) {
    return j && j.status === 200 ? j.result : null;
  }

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o))
      o.forEach(function (e) {
        walk(e, urls);
      });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  return ctx
    .fetch(enc + '/enc-cinesrc', {
      method: 'POST',
      headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
      body: JSON.stringify({ url: url, agent: ua }),
    })
    .then(function (r) {
      ctx.log('enc-cinesrc http ' + r.status);
      return r.json();
    })
    .then(function (j) {
      var data = validate(j);
      if (!data) {
        ctx.log('enc-cinesrc miss');
        return [];
      }
      var getStream = (data.headers && data.headers.getStream) || data.getStream;
      var token = data.token;
      var key = data.key;
      if (!getStream || !token) {
        ctx.log('missing getStream/token');
        return [];
      }
      var payload = [
        tmdbId,
        ctx.type === 'tv' ? 'show' : 'movie',
        ctx.type === 'tv' ? String(ctx.season || 1) : '$undefined',
        ctx.type === 'tv' ? String(ctx.episode || 1) : '$undefined',
        token,
        cfg.provider || '',
      ];
      return ctx
        .fetch(url, {
          method: 'POST',
          headers: Object.assign({}, headers, { 'Next-Action': getStream }),
          body: JSON.stringify(payload),
        })
        .then(function (r) {
          return r.text();
        })
        .then(function (text) {
          var line = text.split('\n')[1] || text;
          var encrypted = (line.split(',')[1] || line).split(':')[0];
          return ctx.fetch(enc + '/dec-cinesrc', {
            method: 'POST',
            headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
            body: JSON.stringify({ text: encrypted, key: key }),
          });
        })
        .then(function (r) {
          return r.json();
        })
        .then(function (dj) {
          var decrypted = validate(dj);
          var urls = [];
          walk(decrypted, urls);
          ctx.log('streams=' + urls.length);
          return urls.map(function (u) {
            return { url: u, name: 'Cinesrc', headers: { 'User-Agent': ua, Referer: origin + '/' } };
          });
        });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
