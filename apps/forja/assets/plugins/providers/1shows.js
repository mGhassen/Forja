function extract(ctx) {
  var cfg = ctx.config || {};
  var site = (cfg.origin || 'https://www.1shows.org').replace(/\/$/, '');
  var api = (cfg.api || 'https://api.viduki.net').replace(/\/$/, '');
  // AES-256 key from 1Shows public makimaDL.wasm StaticArray (rotates with that asset).
  var downloadKeyHex =
    cfg.downloadKeyHex ||
    '7e82474d94d34f79c91eda37abfe27fb44e515fe8eea8db0a89958b798f745b1';
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua =
    cfg.ua ||
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36';
  var apiHeaders = {
    Accept: 'application/json',
    Origin: site,
    Referer: site + '/',
    'User-Agent': ua,
  };
  var pageHeaders = {
    Accept:
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    Referer: site + '/',
    'User-Agent': ua,
  };
  var isTv = ctx.type !== 'movie';
  var tmdbId = String(ctx.tmdbId || '').trim();
  var season = Number(ctx.season) || 1;
  var episode = Number(ctx.episode) || 1;

  function fetchJson(url, headers) {
    return ctx.fetch(url, { headers: headers || apiHeaders }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + url);
      return r.json();
    });
  }

  function fetchText(url, headers) {
    return ctx
      .fetch(url, { headers: headers || pageHeaders })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + url);
        return r.text().then(function (html) {
          return { html: html, url: r.url || url };
        });
      });
  }

  function hexToBytes(hex) {
    var h = String(hex || '').trim();
    if (!h || h.length % 2) throw new Error('Invalid encrypted payload');
    var out = new Uint8Array(h.length / 2);
    for (var i = 0; i < out.length; i++) {
      var n = parseInt(h.slice(i * 2, i * 2 + 2), 16);
      if (Number.isNaN(n)) throw new Error('Invalid encrypted payload');
      out[i] = n;
    }
    return out;
  }

  function safeUtf8Decode(bytes) {
    var s = '';
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    try {
      return decodeURIComponent(escape(s));
    } catch (e) {
      return s;
    }
  }

  var AES_SBOX = new Uint8Array([
    99, 124, 119, 123, 242, 107, 111, 197, 48, 1, 103, 43, 254, 215, 171, 118, 202, 130, 201, 125,
    250, 89, 71, 240, 173, 212, 162, 175, 156, 164, 114, 192, 183, 253, 147, 38, 54, 63, 247, 204,
    52, 165, 229, 241, 113, 216, 49, 21, 4, 199, 35, 195, 24, 150, 5, 154, 7, 18, 128, 226, 235, 39,
    178, 117, 9, 131, 44, 26, 27, 110, 90, 160, 82, 59, 214, 179, 41, 227, 47, 132, 83, 209, 0, 237,
    32, 252, 177, 91, 106, 203, 190, 57, 74, 76, 88, 207, 208, 239, 170, 251, 67, 77, 51, 133, 69,
    249, 2, 127, 80, 60, 159, 168, 81, 163, 64, 143, 146, 157, 56, 245, 188, 182, 218, 33, 16, 255,
    243, 210, 205, 12, 19, 236, 95, 151, 68, 23, 196, 167, 126, 61, 100, 93, 25, 115, 96, 129, 79,
    220, 34, 42, 144, 136, 70, 238, 184, 20, 222, 94, 11, 219, 224, 50, 58, 10, 73, 6, 36, 92, 194,
    211, 172, 98, 145, 149, 228, 121, 231, 200, 55, 109, 141, 213, 78, 169, 108, 86, 244, 234, 101,
    122, 174, 8, 186, 120, 37, 46, 28, 166, 180, 198, 232, 221, 116, 31, 75, 189, 139, 138, 112, 62,
    181, 102, 72, 3, 246, 14, 97, 53, 87, 185, 134, 193, 29, 158, 225, 248, 152, 17, 105, 217, 142,
    148, 155, 30, 135, 233, 206, 85, 40, 223, 140, 161, 137, 13, 191, 230, 66, 104, 65, 153, 45, 15,
    176, 84, 187, 22,
  ]);
  var AES_RCON = new Uint8Array([0, 1, 2, 4, 8, 16, 32, 64, 128, 27, 54]);

  function expandAes256Key(key) {
    if (key.length !== 32) throw new Error('Invalid AES-256 key');
    var rk = new Uint8Array(240);
    rk.set(key);
    var i = 32;
    var rcon = 1;
    var t = new Uint8Array(4);
    while (i < rk.length) {
      for (var j = 0; j < 4; j++) t[j] = rk[i - 4 + j];
      if (i % 32 === 0) {
        var tmp = t[0];
        t[0] = AES_SBOX[t[1]] ^ AES_RCON[rcon++];
        t[1] = AES_SBOX[t[2]];
        t[2] = AES_SBOX[t[3]];
        t[3] = AES_SBOX[tmp];
      } else if (i % 32 === 16) {
        for (j = 0; j < 4; j++) t[j] = AES_SBOX[t[j]];
      }
      for (j = 0; j < 4 && i < rk.length; j++) {
        rk[i] = rk[i - 32] ^ t[j];
        i++;
      }
    }
    return rk;
  }

  function aesXtime(b) {
    return ((b << 1) ^ (b & 0x80 ? 0x1b : 0)) & 0xff;
  }

  function aesEncryptBlock(block, rk) {
    var s = new Uint8Array(block);
    for (var i = 0; i < 16; i++) s[i] ^= rk[i];
    for (var round = 1; round <= 14; round++) {
      for (i = 0; i < 16; i++) s[i] = AES_SBOX[s[i]];
      var shifted = new Uint8Array(16);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) shifted[r + 4 * c] = s[r + 4 * ((c + r) & 3)];
      }
      s.set(shifted);
      if (round < 14) {
        for (r = 0; r < 4; r++) {
          var o = r * 4;
          var a0 = s[o];
          var a1 = s[o + 1];
          var a2 = s[o + 2];
          var a3 = s[o + 3];
          var t = a0 ^ a1 ^ a2 ^ a3;
          s[o] ^= t ^ aesXtime(a0 ^ a1);
          s[o + 1] ^= t ^ aesXtime(a1 ^ a2);
          s[o + 2] ^= t ^ aesXtime(a2 ^ a3);
          s[o + 3] ^= t ^ aesXtime(a3 ^ a0);
        }
      }
      var off = round * 16;
      for (i = 0; i < 16; i++) s[i] ^= rk[off + i];
    }
    return s;
  }

  function xorBlock(a, b) {
    for (var i = 0; i < 16; i++) a[i] ^= b[i];
  }

  function ghashMultiply(x, y) {
    var z = new Uint8Array(16);
    var v = new Uint8Array(y);
    for (var i = 0; i < 128; i++) {
      if ((x[i >> 3] >> (7 - (i & 7))) & 1) xorBlock(z, v);
      var lsb = v[15] & 1;
      for (var j = 15; j > 0; j--) v[j] = (v[j] >>> 1) | ((v[j - 1] & 1) << 7);
      v[0] >>>= 1;
      if (lsb) v[0] ^= 0xe1;
    }
    return z;
  }

  function ghashUpdate(state, h, data) {
    for (var i = 0; i < data.length; i += 16) {
      var block = new Uint8Array(16);
      block.set(data.subarray(i, Math.min(i + 16, data.length)));
      xorBlock(state, block);
      state.set(ghashMultiply(state, h));
    }
  }

  function writeBitLength(buf, offset, byteLen) {
    var bits = byteLen * 8;
    for (var i = 7; i >= 0; i--) {
      buf[offset + i] = bits & 0xff;
      bits = Math.floor(bits / 256);
    }
  }

  function incrementCounter(counter) {
    for (var i = 15; i >= 12; i--) {
      counter[i] = (counter[i] + 1) & 0xff;
      if (counter[i]) break;
    }
  }

  function constantTimeEqual(a, b) {
    if (a.length !== b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) d |= a[i] ^ b[i];
    return d === 0;
  }

  function decryptDownload(payload, token) {
    var key = hexToBytes(downloadKeyHex);
    var iv = hexToBytes(payload.iv);
    var ct = hexToBytes(payload.ct);
    var tag = hexToBytes(payload.tag);
    var aad = hexToBytes(token);
    if (iv.length !== 12 || tag.length !== 16) throw new Error('Unsupported 1Shows AES-GCM payload');
    var rk = expandAes256Key(key);
    var h = aesEncryptBlock(new Uint8Array(16), rk);
    var s = new Uint8Array(16);
    ghashUpdate(s, h, aad);
    ghashUpdate(s, h, ct);
    var lenBlock = new Uint8Array(16);
    writeBitLength(lenBlock, 0, aad.length);
    writeBitLength(lenBlock, 8, ct.length);
    xorBlock(s, lenBlock);
    s.set(ghashMultiply(s, h));
    var j0 = new Uint8Array(16);
    j0.set(iv);
    j0[15] = 1;
    var tCheck = aesEncryptBlock(j0, rk);
    xorBlock(tCheck, s);
    if (!constantTimeEqual(tCheck, tag)) throw new Error('1Shows authentication failed');
    var counter = new Uint8Array(j0);
    var plain = new Uint8Array(ct.length);
    for (var i = 0; i < ct.length; i += 16) {
      incrementCounter(counter);
      var keystream = aesEncryptBlock(counter, rk);
      var n = Math.min(16, ct.length - i);
      for (var j = 0; j < n; j++) plain[i + j] = ct[i + j] ^ keystream[j];
    }
    return JSON.parse(safeUtf8Decode(plain));
  }

  function absoluteUrl(href, base) {
    if (!href) return '';
    try {
      return new URL(href, base).toString();
    } catch (e) {
      return '';
    }
  }

  function decodeHtml(s) {
    return String(s || '')
      .replace(/&amp;/gi, '&')
      .replace(/&#0*39;|&apos;/gi, "'")
      .replace(/&quot;/gi, '"')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>');
  }

  function stripTags(s) {
    return decodeHtml(String(s || '').replace(/<[^>]*>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim();
  }

  function attribute(tag, name) {
    var m = String(tag || '').match(new RegExp('\\b' + name + '\\s*=\\s*([\"\'])([\\s\\S]*?)\\1', 'i'));
    return m ? decodeHtml(m[2]) : '';
  }

  function anchors(html, base) {
    var out = [];
    var re = /<a\b[^>]*>[\s\S]*?<\/a>/gi;
    var m;
    while ((m = re.exec(String(html || '')))) {
      var href = absoluteUrl(attribute(m[0], 'href'), base);
      if (href) out.push({ href: href, text: stripTags(m[0]) });
    }
    return out;
  }

  function isDirectMedia(url) {
    if (/\.(?:m3u8|mpd|mp4|mkv|webm)(?:$|[?#])/i.test(url)) return true;
    try {
      var host = new URL(url).hostname.toLowerCase();
      return (
        host === 'fffast.filesdl.in' ||
        host === 'video-downloads.googleusercontent.com' ||
        host === 'fuckingfast.net' ||
        host.endsWith('.workers.dev') ||
        host.endsWith('.r2.cloudflarestorage.com') ||
        host.indexOf('pixeldrain') >= 0 ||
        host.indexOf('iwebp.store') >= 0
      );
    } catch (e) {
      return false;
    }
  }

  function isKnownUnplayableHost(url) {
    try {
      var host = new URL(url).hostname.toLowerCase();
      return (
        host === 'moondl.com' ||
        host.endsWith('.moondl.com') ||
        host === 'takefile.link' ||
        host.endsWith('.takefile.link') ||
        host === 'pixel.hubcloud.cx'
      );
    } catch (e) {
      return false;
    }
  }

  function normalizeDirectUrl(url) {
    var u = String(url || '').replace(/ /g, '%20');
    try {
      var parsed = new URL(u);
      var host = parsed.hostname.toLowerCase();
      if (
        host === 'pixeldrain.com' ||
        host === 'www.pixeldrain.com' ||
        host === 'pixeldrain.dev' ||
        host === 'www.pixeldrain.dev' ||
        host.endsWith('.iwebp.store')
      ) {
        var m = parsed.pathname.match(/^\/(?:u|l)\/([^/?#]+)/i);
        if (m) return 'https://pixeldrain.com/api/file/' + m[1];
      }
    } catch (e) {}
    return u;
  }

  function preferredDownloadLink(links) {
    var usable = links.filter(function (l) {
      return l && l.href && !isKnownUnplayableHost(l.href);
    });
    var prefs = [
      /(?:direct download|instant dl)/i,
      /(?:pixeldrain|buzzheavier)/i,
      /(?:fast cloud|zipdisk)/i,
    ];
    for (var i = 0; i < prefs.length; i++) {
      var hit = usable.find(function (l) {
        return prefs[i].test(l.text);
      });
      if (hit) return hit;
    }
    return (
      usable.find(function (l) {
        return isDirectMedia(l.href);
      }) || null
    );
  }

  function routeName(text, url) {
    var t = String(text || '');
    if (/fast cloud|zipdisk/i.test(t)) return 'Fast Cloud';
    if (/cloud direct/i.test(t)) return 'Cloud Direct';
    if (/pixeldrain/i.test(t)) return 'Pixeldrain';
    if (/hubcloud/i.test(t)) return 'HubCloud';
    if (/gd\s*index|gdflix/i.test(t)) return 'GD Index';
    if (/streamtape/i.test(t)) return 'Streamtape';
    if (/instant dl/i.test(t)) return 'Instant DL';
    if (/direct download/i.test(t)) return 'Direct';
    try {
      var host = new URL(url || text).hostname.toLowerCase();
      if (host.indexOf('pixeldrain') >= 0) return 'Pixeldrain';
      if (host.indexOf('streamtape') >= 0) return 'Streamtape';
      if (host.indexOf('hubcloud') >= 0) return 'HubCloud';
      if (host.endsWith('.r2.cloudflarestorage.com')) return 'Fast Cloud';
    } catch (e) {}
    return 'Direct';
  }

  function sourceName(label) {
    if (/4khdhub|hubcloud/i.test(label)) return 'HubCloud';
    if (/katmovies/i.test(label)) return 'KatMovies';
    if (/filmyfly/i.test(label)) return 'FilmyFly';
    if (/premium\s*hm/i.test(label)) return 'Premium HM';
    return '1Shows';
  }

  function qualityFromLabel(label) {
    var s = String(label || '').replace(/р/gi, 'p');
    if (/\b(?:2160p|4k)\b/i.test(s)) return '2160p';
    var m = s.match(/\b(1080|720|480)p\b/i);
    return m ? m[1] + 'p' : '';
  }

  function sizeFromLabel(label) {
    var m = String(label || '').match(/([\d.]+)\s*(GB|MB|KB)/i);
    return m ? m[1] + ' ' + m[2].toUpperCase() : '';
  }

  function isHubCloudDrivePage(url) {
    try {
      return new URL(url).pathname.toLowerCase().indexOf('/drive/') >= 0;
    } catch (e) {
      return /\/drive\//i.test(String(url || ''));
    }
  }

  function appendDownloadQuery(apiUrl) {
    try {
      var u = new URL(apiUrl);
      u.searchParams.set('download', '');
      return u.href;
    } catch (e) {
      return apiUrl + (apiUrl.indexOf('?') >= 0 ? '&' : '?') + 'download=';
    }
  }

  function pixeldrainDownloadUrl(href) {
    var m = String(href || '').match(
      /pixeldrain\.(?:dev|net)\/(?:u|api\/file)\/([A-Za-z0-9]+)/i,
    );
    if (m) return appendDownloadQuery('https://pixeldrain.net/api/file/' + m[1]);
    var userUrl = href.replace('/api/file/', '/u/');
    return appendDownloadQuery(userUrl.replace('/u/', '/api/file/'));
  }

  function collectHubCloudLinks($) {
    var results = [];
    $('a.btn, a').each(function () {
      var a = $(this);
      var text = a.text().trim();
      var href = a.attr('href') || '';
      if (!href || isHubCloudDrivePage(href)) return;
      if (/PixelServer/i.test(text) || /pixeldrain\.(?:dev|net)\//i.test(href)) {
        results.push({ url: pixeldrainDownloadUrl(href), route: 'Pixeldrain' });
      } else if (/FSLv2/i.test(text)) {
        results.push({ url: href, route: 'FSLv2' });
      } else if (/FSL/i.test(text)) {
        results.push({ url: href, route: 'FSL' });
      } else if (/Download File/i.test(text) || /r2\.dev/i.test(href)) {
        results.push({ url: href, route: 'Direct R2' });
      } else if (/ZipDisk|Fast Cloud/i.test(text) || /workers\.dev/i.test(href)) {
        results.push({ url: href, route: 'Fast Cloud' });
      } else if (/10Gbps/i.test(text) || /pixel\.hubcloud\./i.test(href)) {
        results.push({ url: href, route: 'HubCloud 10Gbps' });
      }
    });
    return results;
  }

  // /drive/<id> is the HubCloud entry hop now — follow to hubcloud.php; never emit /drive/.
  function extractHubCloud(hubCloudUrl) {
    return fetchText(hubCloudUrl, Object.assign({}, pageHeaders, { Referer: hubCloudUrl }))
      .then(function (page) {
        var entryHtml = page.html || '';
        var $entry = ctx.html(entryHtml);
        var linksUrl = '';
        var redirectUrlMatch = String(entryHtml).match(/var url ?= ?'(.*?)'/);
        if (redirectUrlMatch) linksUrl = redirectUrlMatch[1];
        if (!linksUrl) {
          linksUrl = $entry('#download').attr('href') || '';
          if (linksUrl && !/^https?:/i.test(linksUrl)) {
            try {
              var base = new URL(hubCloudUrl);
              linksUrl = base.protocol + '//' + base.hostname + '/' + linksUrl.replace(/^\//, '');
            } catch (e) {}
          }
        }
        if (linksUrl && isHubCloudDrivePage(linksUrl)) linksUrl = '';
        var next = linksUrl
          ? fetchText(linksUrl, Object.assign({}, pageHeaders, { Referer: hubCloudUrl }))
          : Promise.resolve(page);
        return next.then(function (linksPage) {
          var html = linksPage.html != null ? linksPage.html : linksPage;
          var results = collectHubCloudLinks(ctx.html(html));
          if (results.length || !linksUrl) return results;
          return collectHubCloudLinks($entry);
        });
      })
      .catch(function () {
        return [];
      });
  }

  function resolveSourceUrl(src, depth, referer, route) {
    depth = depth || 0;
    referer = referer || site + '/';
    route = route || '';
    if (depth > 5) return Promise.resolve([]);
    var url = absoluteUrl(src.url, site);
    if (!url || isKnownUnplayableHost(url)) return Promise.resolve([]);
    if (isDirectMedia(url)) {
      return Promise.resolve([{ url: normalizeDirectUrl(url), route: route || routeName('', url) }]);
    }
    if (/hubcloud/i.test(url) || /hubcloud/i.test(src.label || '') || /4khdhub/i.test(src.label || '')) {
      return extractHubCloud(url).then(function (links) {
        if (links.length) return links;
        return followPage(url, depth, referer, route || 'HubCloud');
      });
    }
    return followPage(url, depth, referer, route);
  }

  function followPage(url, depth, referer, route) {
    return fetchText(url, Object.assign({}, pageHeaders, { Referer: referer }))
      .then(function (page) {
        var redirect = page.html.match(/window\.location(?:\.href)?\s*=\s*["']([^"']+)["']/i);
        var links = anchors(page.html, page.url);
        var preferred = preferredDownloadLink(links);
        var next =
          preferred ||
          (redirect
            ? { href: absoluteUrl(redirect[1], page.url), text: '' }
            : null);
        if (!next || !next.href || next.href === url) return [];
        return resolveSourceUrl(
          { url: next.href, label: next.text || '' },
          depth + 1,
          page.url,
          route || routeName(next.text, next.href),
        );
      })
      .catch(function () {
        return [];
      });
  }

  function makeRow(src, resolved) {
    var label = src.label || '';
    var quality = qualityFromLabel(label) || qualityFromLabel(resolved.url);
    var size = src.size || src.directSize || sizeFromLabel(label);
    var provider = sourceName(label);
    var route = resolved.route || routeName(label, resolved.url);
    var name =
      '1Shows - ' + provider + (route ? ' / ' + route : '') + (quality ? ' ' + quality : '');
    return {
      name: name,
      title: label || undefined,
      url: resolved.url,
      quality: quality || undefined,
      size: size || undefined,
      headers: { 'User-Agent': ua, Referer: site + '/' },
    };
  }

  function hasWrongYear(text, year) {
    if (!year) return false;
    var years = String(text || '').match(/\b(?:19|20)\d{2}\b/g) || [];
    return years.some(function (y) {
      return Math.abs(Number(y) - year) > 1;
    });
  }

  function fetchDownloadSources() {
    return fetchJson(api + '/download-token', apiHeaders).then(function (tok) {
      if (!tok || !tok.token) throw new Error('1Shows returned no download token');
      var path = isTv
        ? '/download/tv/' +
          encodeURIComponent(tmdbId) +
          '/' +
          encodeURIComponent(season) +
          '/' +
          encodeURIComponent(episode)
        : '/download/movie/' + encodeURIComponent(tmdbId);
      return fetchJson(
        api + path,
        Object.assign({}, apiHeaders, { 'x-download-token': tok.token }),
      ).then(function (payload) {
        var decoded = decryptDownload(payload, tok.token);
        var sources = Array.isArray(decoded.sources) ? decoded.sources : [];
        return sources;
      });
    });
  }

  function mediaYear() {
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(tmdbId) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
      { Accept: 'application/json', 'User-Agent': ua },
    )
      .then(function (d) {
        var date = d.release_date || d.first_air_date || '';
        return Number(String(date).slice(0, 4)) || 0;
      })
      .catch(function () {
        return 0;
      });
  }

  if (!tmdbId) return Promise.resolve([]);
  if (isTv && (!Number.isInteger(season) || season < 1 || !Number.isInteger(episode) || episode < 1)) {
    return Promise.resolve([]);
  }

  return Promise.all([fetchDownloadSources(), mediaYear()])
    .then(function (pair) {
      var sources = pair[0];
      var year = pair[1];
      ctx.log('1shows sources=' + sources.length);
      var filtered = sources.filter(function (s) {
        if (!s || !s.url) return false;
        return !hasWrongYear((s.label || '') + ' ' + s.url, year);
      });
      return Promise.all(
        filtered.map(function (src) {
          return resolveSourceUrl(src, 0, site + '/', '').then(function (resolved) {
            return resolved
              .filter(function (r) {
                return r && r.url && !isKnownUnplayableHost(r.url);
              })
              .map(function (r) {
                return makeRow(src, r);
              });
          });
        }),
      ).then(function (groups) {
        var rows = [].concat.apply([], groups);
        var seen = {};
        return rows.filter(function (row) {
          if (!row || !row.url || seen[row.url]) return false;
          seen[row.url] = true;
          return true;
        });
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
