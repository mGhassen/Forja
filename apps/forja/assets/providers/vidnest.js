function extract(ctx) {
  var cfg = ctx.config || {};
  var api = cfg.api || 'https://new.vidnest.fun';
  var origin = cfg.origin || 'https://vidnest.fun';
  var alphabet =
    cfg.alphabet ||
    'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    Origin: origin,
    Referer: origin + '/',
  };
  var tmdbId = String(ctx.tmdbId);
  var isMovie = ctx.type === 'movie';
  var servers = cfg.servers || [
    { id: 'gama', name: 'Gama', movie: 'moviebox/movie', tv: 'moviebox/tv' },
    { id: 'hexa', name: 'Hexa', movie: 'vidlink/movie', tv: 'vidlink/tv' },
    { id: 'lamda', name: 'Lamda', movie: 'allmovies/movie', tv: 'allmovies/tv' },
    { id: 'delta', name: 'Delta', movie: 'allmovies/movie', tv: 'allmovies/tv' },
    { id: 'beta', name: 'Beta', movie: 'videasy/movie', tv: 'videasy/tv' },
    { id: 'prime', name: 'Prime', movie: 'hollymoviehd/movie', tv: 'hollymoviehd/tv' },
    { id: 'sigma', name: 'Sigma', movie: 'hollymoviehd', tv: 'hollymoviehd' },
    { id: 'alfa', name: 'Alfa', movie: 'moviesapi/movie', tv: 'moviesapi/tv' },
    { id: 'catflix', name: 'Catflix', movie: 'movies5f/movie', tv: 'movies5f/tv' },
    { id: 'ophim', name: 'Ophim', movie: 'klikxxi/movie', tv: 'klikxxi/tv' },
  ];

  function decryptCipher(data) {
    var index = {};
    for (var i = 0; i < alphabet.length; i++) index[alphabet[i]] = i;
    var out = [];
    for (var t = 0; t < data.length; t += 4) {
      var chunk = data.substring(t, Math.min(t + 4, data.length));
      while (chunk.length < 4) chunk += '=';
      var l = [0, 1, 2, 3].map(function (e) {
        return index[chunk[e]] == null ? 64 : index[chunk[e]];
      });
      out.push((l[0] << 2) | (l[1] >> 4));
      if (l[2] !== 64) out.push(((l[1] & 15) << 4) | (l[2] >> 2));
      if (l[3] !== 64) out.push(((l[2] & 3) << 6) | l[3]);
    }
    var bytes = new Uint8Array(out);
    var s = '';
    for (var j = 0; j < bytes.length; j++) s += String.fromCharCode(bytes[j]);
    try {
      return decodeURIComponent(escape(s));
    } catch (e) {
      return s;
    }
  }

  function decodeBody(body) {
    try {
      var map = JSON.parse(body);
      if (!map || typeof map !== 'object') return null;
      if (map.encrypted === true && map.data) {
        var plain = decryptCipher(String(map.data));
        var parsed = JSON.parse(plain);
        return parsed && typeof parsed === 'object' ? parsed : null;
      }
      return map;
    } catch (e) {
      return null;
    }
  }

  function isDirect(u) {
    return /\.m3u8(\?|$)/i.test(u) || /\.mp4(\?|$)/i.test(u) || /\/mp4\//i.test(u);
  }

  function emit(json, server) {
    var rows = [];
    function push(u, name, quality, language, hdrs) {
      if (!u) return;
      rows.push({
        url: u,
        name: name || server.name,
        quality: quality || '',
        language: language || '',
        headers: hdrs || { 'User-Agent': ua },
      });
    }
    var urlField = json.url;
    if (Array.isArray(urlField)) {
      urlField.forEach(function (row) {
        var link = (row && (row.link || row.url)) || '';
        if (!link) return;
        push(link, server.name, String(row.resolution || ''), String(row.lang || ''));
      });
    } else if (typeof urlField === 'string' && urlField) {
      push(urlField, server.name, '', '', json.headers || { 'User-Agent': ua });
    }
    (json.streams || []).forEach(function (row) {
      var u = row && row.url;
      if (!u) return;
      push(
        u,
        server.name,
        String(row.quality || row.type || ''),
        String(row.language || row.lang || ''),
        row.headers,
      );
    });
    return rows;
  }

  function resolveRows(rows) {
    return Promise.all(
      rows.map(function (r) {
        if (isDirect(r.url)) return Promise.resolve([r]);
        return ctx.hop(r.url).then(function (hopped) {
          return hopped && hopped.length ? hopped : [r];
        });
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  var tasks = servers.map(function (server) {
    var path = isMovie ? server.movie : server.tv;
    var suffix = isMovie
      ? '/' + tmdbId
      : '/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);
    var uri = api + '/' + path + suffix;
    return ctx
      .fetch(uri, { headers: headers })
      .then(function (r) {
        if (!r.ok) return [];
        return r.text();
      })
      .then(function (body) {
        var json = decodeBody(body);
        if (!json) return [];
        return resolveRows(emit(json, server));
      })
      .catch(function () {
        return [];
      });
  });

  return Promise.all(tasks).then(function (groups) {
    var out = [];
    var seen = {};
    groups.forEach(function (rows) {
      (rows || []).forEach(function (r) {
        if (!r || !r.url || seen[r.url]) return;
        seen[r.url] = true;
        out.push(r);
      });
    });
    if (out.length) return out;
    return ctx.host('vidnest');
  });
}
