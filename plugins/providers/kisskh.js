var SPECS = {
  "origin": "https://kisskh.co",
  "mirrors": [
    "https://kisskh.co",
    "https://kisskh.nl",
    "https://kisskh.ovh",
    "https://kisskh.la",
    "https://kisskh.do",
    "https://kisskh.is",
    "https://kisskh.id"
  ]
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var mirrors = (Array.isArray(cfg.mirrors) ? cfg.mirrors : []).map(function (m) {
    return String(m).replace(/\/$/, '');
  });
  var preferred = String(cfg.origin || mirrors[0] || '').replace(/\/$/, '');
  var ordered = [preferred].concat(
    mirrors.filter(function (m) {
      return m && m !== preferred;
    }),
  );
  var sticky = null;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  // Hub Sources injects KissKh drama/episode ids — Search never returns tmdbID.
  var episodeId = cfg.episodeId || ctx.config.episodeId;
  var dramaId = cfg.dramaId || ctx.config.dramaId;
  var tmdbId = String(ctx.tmdbId || '');
  var title = String(ctx.title || '');
  ctx.log(
    'kisskh start dramaId=' +
      (dramaId || '') +
      ' episodeId=' +
      (episodeId || '') +
      ' title=' +
      title +
      ' ep=' +
      (ctx.episode || 1) +
      ' mirrors=' +
      ordered.length +
      ' hasKkey=' +
      !!(ctx.crypto && ctx.crypto.kisskhKkey),
  );

  function headersFor(origin) {
    return { 'User-Agent': ua, Accept: 'application/json', Referer: origin + '/' };
  }

  function playHeaders(origin) {
    return { 'User-Agent': ua, Referer: origin + '/', Origin: origin };
  }

  function mirrorOrder() {
    if (!sticky) return ordered;
    return [sticky].concat(
      ordered.filter(function (m) {
        return m !== sticky;
      }),
    );
  }

  function fetchJson(path) {
    var list = mirrorOrder();
    function tryAt(i) {
      if (i >= list.length) return Promise.reject(new Error('KissKh mirrors failed'));
      var origin = list[i];
      return ctx
        .fetch(origin + path, { headers: headersFor(origin) })
        .then(function (r) {
          return r.text().then(function (body) {
            var trimmed = String(body || '').trim();
            if (!r.ok) {
              ctx.log('kisskh HTTP ' + r.status + ' @ ' + origin);
              return tryAt(i + 1);
            }
            if (!trimmed || trimmed.charAt(0) === '<') {
              ctx.log('kisskh HTML shell @ ' + origin);
              return tryAt(i + 1);
            }
            try {
              sticky = origin;
              return { origin: origin, json: JSON.parse(trimmed) };
            } catch (e) {
              ctx.log('kisskh JSON parse fail @ ' + origin);
              return tryAt(i + 1);
            }
          });
        })
        .catch(function (e) {
          ctx.log(
            'kisskh fetch error @ ' +
              origin +
              ': ' +
              (e && e.message ? e.message : e),
          );
          return tryAt(i + 1);
        });
    }
    return tryAt(0);
  }

  // API returns ThirdParty as array, string URL, or single {src|url} object.
  function thirdPartyUrls(api) {
    var raw = api && (api.ThirdParty || api.thirdParty);
    if (raw == null || raw === '') return [];
    if (typeof raw === 'string') {
      return /^https?:/i.test(raw) ? [raw] : [];
    }
    if (Array.isArray(raw)) {
      return raw
        .map(function (e) {
          return e && (e.src || e.url);
        })
        .filter(Boolean);
    }
    if (typeof raw === 'object') {
      var u = raw.src || raw.url;
      return u ? [u] : [];
    }
    return [];
  }

  // Site Sub CDN cues are AES line-encrypted (same keys as kisskh.co player).
  // Decrypt here and emit plaintext `content` — host must not special-case KissKh.
  var SUB_KEY_VARIANTS = [
    { key: 'AmSmZVcH93UQUezi', iv: 'ReBKWW8cqdjPEnF6' },
    { key: '8056483646328763', iv: '6852612370185273' },
    { key: 'sWODXX04QRTkHdlZ', iv: '8pwhapJeC4hrS9hO' },
  ];

  function preferredSubKeyIndex(url) {
    var path = String(url || '').split('?')[0];
    var ext = path.split('.').pop();
    if (!ext) return null;
    ext = ext.toLowerCase();
    if (ext === 'srt') return null;
    if (ext === 'txt') return 1;
    if (ext === 'txt1') return 0;
    return 2;
  }

  function tryDecryptCue(b64, key, iv) {
    if (!(ctx.crypto && ctx.crypto.AES && ctx.crypto.enc)) return null;
    try {
      var C = ctx.crypto;
      var pt = C.AES.decrypt(
        { ciphertext: C.enc.Base64.parse(String(b64).replace(/\n/g, '')) },
        C.enc.Utf8.parse(key),
        {
          iv: C.enc.Utf8.parse(iv),
          mode: C.mode.CBC,
          padding: C.pad.Pkcs7,
        },
      );
      var text = C.enc.Utf8.stringify(pt);
      return text ? text : null;
    } catch (e) {
      return null;
    }
  }

  function decryptCue(b64, sourceUrl) {
    var trimmed = String(b64 || '').trim();
    if (!trimmed || !/^[A-Za-z0-9+/=\s]+$/.test(trimmed)) return null;
    var preferred = preferredSubKeyIndex(sourceUrl);
    if (preferred != null) {
      var hit = tryDecryptCue(
        trimmed,
        SUB_KEY_VARIANTS[preferred].key,
        SUB_KEY_VARIANTS[preferred].iv,
      );
      if (hit) return hit;
    }
    for (var i = 0; i < SUB_KEY_VARIANTS.length; i++) {
      if (i === preferred) continue;
      var r = tryDecryptCue(
        trimmed,
        SUB_KEY_VARIANTS[i].key,
        SUB_KEY_VARIANTS[i].iv,
      );
      if (r) return r;
    }
    return null;
  }

  function decryptSubBody(body, sourceUrl) {
    var lines = String(body || '').split(/\r?\n/);
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var t = line.trim();
      if (
        !t ||
        t === 'WEBVTT' ||
        t.indexOf('NOTE') === 0 ||
        /^\d+$/.test(t) ||
        line.indexOf('-->') >= 0
      ) {
        out.push(line);
        continue;
      }
      var decoded = decryptCue(line, sourceUrl);
      out.push(decoded != null ? decoded : line);
    }
    return out.join('\n');
  }

  // Site player uses /api/Sub/{id}. HLS mux tracks are often mistimed — attach
  // decrypted Sub API rows so the host prefers them as generic sideloads.
  function fetchSubtitles(episodeId, origin) {
    if (!(ctx.crypto && ctx.crypto.kisskhKkey && ctx.crypto.AES)) {
      return Promise.resolve([]);
    }
    var kkey = ctx.crypto.kisskhKkey(episodeId, 'subtitle');
    if (!kkey) return Promise.resolve([]);
    var path = '/api/Sub/' + episodeId + '?kkey=' + encodeURIComponent(kkey);
    return fetchJson(path)
      .then(function (res) {
        var list = Array.isArray(res.json) ? res.json : [];
        var originUsed = res.origin || origin;
        return Promise.all(
          list.map(function (t) {
            if (!t || typeof t !== 'object') return Promise.resolve(null);
            var src = String(t.src || t.url || '').trim();
            if (!src || !/^https?:/i.test(src)) return Promise.resolve(null);
            var label = String(t.label || t.language || t.land || 'Unknown').trim();
            var ext = (src.split('?')[0].split('.').pop() || '').toLowerCase();
            return ctx
              .fetch(src, { headers: headersFor(originUsed) })
              .then(function (r) {
                if (!r.ok) return null;
                return r.text().then(function (body) {
                  var text =
                    ext === 'srt' ? String(body || '') : decryptSubBody(body, src);
                  if (!String(text || '').trim()) return null;
                  return {
                    url: src,
                    language: label,
                    name: label,
                    content: text,
                  };
                });
              })
              .catch(function () {
                return null;
              });
          }),
        ).then(function (rows) {
          var out = rows.filter(Boolean);
          ctx.log(
            'kisskh Sub API tracks=' + out.length + ' @ ' + originUsed,
          );
          return out;
        });
      })
      .catch(function (e) {
        ctx.log('kisskh Sub API error: ' + (e && e.message ? e.message : e));
        return [];
      });
  }

  function rowsFromEpisode(api, origin, subtitles) {
    if (!api || typeof api !== 'object') return Promise.resolve([]);
    var urls = [];
    ['Video', 'video', 'VideoUrl', 'videoUrl'].forEach(function (k) {
      if (api[k] && /^https?:/i.test(String(api[k]))) urls.push(String(api[k]));
    });
    thirdPartyUrls(api).forEach(function (u) {
      urls.push(u);
    });
    var subs = Array.isArray(subtitles) ? subtitles : [];
    return Promise.all(
      urls.map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          var row = {
            url: u,
            name: 'KissKh',
            headers: playHeaders(origin),
          };
          if (subs.length) row.subtitles = subs;
          return Promise.resolve([row]);
        }
        return ctx.hop(u).then(function (hopped) {
          if (!subs.length || !Array.isArray(hopped)) return hopped;
          return hopped.map(function (r) {
            if (!r || typeof r !== 'object') return r;
            if (r.subtitles && r.subtitles.length) return r;
            var copy = Object.assign({}, r);
            copy.subtitles = subs;
            return copy;
          });
        });
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  function episodePath(id, withKkey) {
    var q = '.png?err=false&ts=&time=';
    if (withKkey && ctx.crypto && ctx.crypto.kisskhKkey) {
      q += '&kkey=' + encodeURIComponent(ctx.crypto.kisskhKkey(id, 'video'));
    }
    return '/api/DramaList/Episode/' + id + q;
  }

  function fetchEpisode(id) {
    if (!(ctx.crypto && ctx.crypto.kisskhKkey)) {
      ctx.log('kisskh kkey missing — Episode API will return SPA HTML');
      return Promise.resolve([]);
    }
    // API requires consumet kkey; bare GET returns HTML.
    return fetchJson(episodePath(id, true))
      .then(function (res) {
        var api = res.json;
        var tp = api.ThirdParty || api.thirdParty;
        ctx.log(
          'kisskh episode payload Video=' +
            typeof api.Video +
            ' ThirdParty=' +
            (tp == null ? 'null' : typeof tp) +
            (Array.isArray(tp) ? '[]' + tp.length : ''),
        );
        var hasVideo =
          api.Video ||
          api.video ||
          api.VideoUrl ||
          api.videoUrl ||
          thirdPartyUrls(api).length > 0;
        if (!hasVideo) {
          ctx.log('kisskh episode JSON has no Video/ThirdParty');
          return [];
        }
        return fetchSubtitles(id, res.origin).then(function (subs) {
          return rowsFromEpisode(api, res.origin, subs);
        });
      })
      .catch(function (e) {
        ctx.log('kisskh episode error: ' + (e && e.message ? e.message : e));
        return [];
      });
  }

  function episodeFromDrama(drama, origin) {
    var eps = drama.episodes || drama.Episodes || [];
    var want = Number(ctx.episode || 1);
    var ep =
      eps.find(function (e) {
        return Number(e.number || e.Number) === want;
      }) || eps[0];
    if (!ep) return [];
    sticky = origin;
    return fetchEpisode(ep.id || ep.Id);
  }

  function fetchDrama(id) {
    return fetchJson('/api/DramaList/Drama/' + id + '?isq=false')
      .then(function (res) {
        return episodeFromDrama(res.json, res.origin);
      })
      .catch(function () {
        return [];
      });
  }

  if (episodeId) return fetchEpisode(episodeId);
  if (dramaId) return fetchDrama(dramaId);

  var q = encodeURIComponent(title);
  if (!q) return Promise.resolve([]);
  return fetchJson('/api/DramaList/Search?q=' + q + '&type=0')
    .then(function (res) {
      var list = res.json;
      var hit =
        (Array.isArray(list) ? list : []).find(function (d) {
          return String(d.tmdbID || d.tmdbId || '') === tmdbId;
        }) ||
        (Array.isArray(list) ? list[0] : null);
      if (!hit) return [];
      sticky = res.origin;
      return fetchDrama(hit.id);
    })
    .catch(function () {
      return [];
    });
}
