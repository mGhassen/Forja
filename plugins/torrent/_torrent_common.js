function magnetFromHash(hash, name) {
  var h = String(hash || '').trim().toLowerCase();
  var dn = encodeURIComponent(String(name || ''));
  return 'magnet:?xt=urn:btih:' + h + '&dn=' + dn;
}

function formatBytes(bytes) {
  var b = Number(bytes);
  if (!isFinite(b) || b < 0) return 'Unknown';
  var KB = 1024;
  var MB = KB * 1024;
  var GB = MB * 1024;
  var TB = GB * 1024;
  if (b >= TB) return (b / TB).toFixed(2) + ' TB';
  if (b >= GB) return (b / GB).toFixed(2) + ' GB';
  if (b >= MB) return (b / MB).toFixed(1) + ' MB';
  if (b >= KB) return Math.round(b / KB) + ' KB';
  return Math.round(b) + ' B';
}

function jsonInt(v) {
  if (v == null) return null;
  if (typeof v === 'number') return Math.floor(v);
  var n = parseInt(String(v).replace(/[^0-9-]/g, ''), 10);
  return isNaN(n) ? null : n;
}

function jsonUint(v) {
  var n = jsonInt(v);
  return n == null || n < 0 ? null : n;
}

function unwrapJina(v) {
  if (!v || typeof v !== 'object') return v;
  var content = v.data && v.data.content;
  if (typeof content === 'string') {
    try {
      return JSON.parse(content);
    } catch (e) {}
  }
  return v;
}

function htmlUnescape(s) {
  return String(s || '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function sourceTag(ctx, fallback) {
  var cfg = ctx.config || {};
  return String(cfg.source || fallback || '');
}

function row(ctx, name, hash, seeders, size, fallbackSource) {
  if (!name || !hash) return null;
  return {
    name: String(name),
    magnet: magnetFromHash(hash, name),
    seeders: String(seeders == null ? '0' : seeders),
    size: String(size || 'Unknown'),
    source: sourceTag(ctx, fallbackSource),
  };
}

function fetchJson(ctx, url) {
  return ctx.fetch(url).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  });
}

function fetchText(ctx, url, headers) {
  return ctx.fetch(url, { headers: headers || {} }).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.text();
  });
}

function fetchJsonMaybeJina(ctx, directUrl, jinaUrl) {
  return fetchJson(ctx, directUrl).catch(function () {
    return fetchJson(ctx, jinaUrl).then(unwrapJina);
  });
}

function fetchViaCodetabs(ctx, targetUrl) {
  var proxy =
    'https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(targetUrl);
  return fetchText(ctx, proxy);
}

function fetchTextMaybeProxy(ctx, directUrl, proxyUrl) {
  return fetchText(ctx, directUrl).catch(function () {
    if (!proxyUrl) return fetchViaCodetabs(ctx, directUrl);
    return fetchText(ctx, proxyUrl).catch(function () {
      return fetchViaCodetabs(ctx, directUrl);
    });
  });
}

function isCloudflareChallenge(html) {
  return /Just a moment|cf-browser-verification|challenges\.cloudflare\.com/i.test(
    String(html || ''),
  );
}

function flareSolverrBase(ctx) {
  var u = String((ctx.config && ctx.config.flareSolverrUrl) || '').trim();
  if (!u) return '';
  return u.replace(/\/+$/, '');
}

function fetchTextViaFlareSolverr(ctx, url) {
  var base = flareSolverrBase(ctx);
  if (!base) return Promise.reject(new Error('no flare solver'));
  var endpoint = base + (/\/v1$/i.test(base) ? '' : '/v1');
  return ctx
    .fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        cmd: 'request.get',
        url: url,
        maxTimeout: 60000,
      }),
    })
    .then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function (v) {
      if (!v || v.status !== 'ok' || !v.solution) throw new Error('flare failed');
      var body = String(v.solution.response || '');
      if (!body || isCloudflareChallenge(body)) throw new Error('flare CF');
      return body;
    });
}

function fetchTextCloudflare(ctx, directUrl) {
  function viaFlare() {
    if (!flareSolverrBase(ctx)) {
      return Promise.reject(new Error('Cloudflare blocked (configure FlareSolverr)'));
    }
    return fetchTextViaFlareSolverr(ctx, directUrl);
  }

  return fetchText(ctx, directUrl)
    .then(function (html) {
      if (!isCloudflareChallenge(html)) return html;
      return viaFlare();
    })
    .catch(function (err) {
      if (!flareSolverrBase(ctx)) return Promise.reject(err);
      return viaFlare();
    });
}
