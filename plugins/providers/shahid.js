// Shahid provider — playout → clear HLS or Widevine license row (RFC-101).
// Auth: sessionId/jwt from Connected Services (hub extractPluginIds).

var SHAHID_UA =
  'Shahid/6.8.3.3660 CFNetwork/1220.1 Darwin/20.3.0 (iPhone/6s iOS/14.4) Safari/604.1';
var SHAHID_BASE = 'https://shahid.mbc.net';
var SHAHID_PROXY = 'https://api2.shahid.net/proxy';
var SHAHID_AES_KEY = 'gx8KSZyPdfJhXes7';
// Web client HMAC key (CryptoJS HmacSHA256 → Hex). See shahid.mbc.net _app chunk.
var SHAHID_SIGN_KEY = 'z3qQSk17nbajIYUF0dU5f4+O/CxjFizcsEJr9ejOYFw=';
var SHAHID_GUEST_PROFILE = JSON.stringify({
  id: '00000000-0000-0000-0000-000000000000',
  ageRestriction: false,
  master: true,
});
var SHAHID_PROFILE_KEY = JSON.stringify({
  isAdult: true,
  ageRestriction: false,
});

var _shahidSessionId = '';
var _shahidJwt = '';
var _shahidCountry = '';

function shahidHeaders(sessionId, jwt) {
  var h = {
    'User-Agent': SHAHID_UA,
    'Shahid-Agent': SHAHID_UA,
    UUID: 'ios',
    language: 'AR',
    Accept: 'application/json',
    shahid_os: 'WEB',
    SHAHID_OS: 'WEB',
    BROWSER_NAME: 'CHROME',
    BROWSER_VERSION: '120.0',
    OS_VERSION: '10',
    'Shd-Platform': 'WEB',
    'Shd-App-Name': 'WEB',
    'Shd-OS': 'WINDOWS',
    'Shd-OS-Version': '10',
    'Shd-Browser': 'CHROME',
    'Shd-Browser-Version': '120.0',
    profile: SHAHID_GUEST_PROFILE,
    'profile-key': SHAHID_PROFILE_KEY,
  };
  if (jwt) h['S-Session'] = jwt;
  if (sessionId) h.Token = sessionId;
  return h;
}

function encryptPassword(ctx, password) {
  var C = ctx.crypto || globalThis.CryptoJS;
  if (!C || !C.AES) return '';
  var key = C.enc.Utf8.parse(SHAHID_AES_KEY);
  var padded = password;
  var bs = 16;
  var pad = bs - (padded.length % bs);
  for (var i = 0; i < pad; i++) padded += String.fromCharCode(pad);
  var encrypted = C.AES.encrypt(C.enc.Utf8.parse(padded), key, {
    mode: C.mode.ECB,
    padding: C.pad.NoPadding,
  });
  return C.enc.Base64.stringify(encrypted.ciphertext);
}

function signParams(ctx, obj) {
  var C = ctx.crypto || globalThis.CryptoJS;
  if (!C || !C.HmacSHA256 || !C.enc || !C.enc.Hex) return '';
  var keys = Object.keys(obj).sort();
  var parts = [];
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i];
    parts.push(k + '=' + String(obj[k]));
  }
  var digest = C.HmacSHA256(parts.join(';'), SHAHID_SIGN_KEY);
  return C.enc.Hex.stringify(digest);
}

function getJwt(ctx) {
  if (_shahidJwt) return Promise.resolve(_shahidJwt);
  return ctx
    .fetch(SHAHID_PROXY + '/v2/session/ios', {
      method: 'POST',
      headers: shahidHeaders('', ''),
      body: '{}',
    })
    .then(function (res) {
      return res.json();
    })
    .then(function (j) {
      _shahidJwt = (j && j.jwt) || '';
      if (j && j.country) _shahidCountry = String(j.country);
      return _shahidJwt;
    })
    .catch(function () {
      return '';
    });
}

function login(ctx, email, password) {
  if (!email || !password) return Promise.resolve('');
  if (_shahidSessionId) return Promise.resolve(_shahidSessionId);
  return getJwt(ctx).then(function (jwt) {
    var enc = encryptPassword(ctx, password);
    if (!enc) return '';
    return ctx
      .fetch(SHAHID_PROXY + '/v2.1/usersservice/validateLogin', {
        method: 'POST',
        headers: Object.assign(shahidHeaders('', jwt), {
          'Content-Type': 'application/json',
          UUID: 'web',
        }),
        body: JSON.stringify({
          email: email,
          password: enc,
          deviceType: 'Mobile',
          physicalDeviceType: 'IOS',
          isNewUser: false,
          captchaToken: 'c2hhaGlkLWF1dGgta2V5LXRva2Vu',
        }),
      })
      .then(function (res) {
        return res.json();
      })
      .then(function (j) {
        var user = (j && j.user) || {};
        _shahidSessionId = user.sessionId || '';
        return _shahidSessionId;
      })
      .catch(function () {
        return '';
      });
  });
}

function parseVideoId(raw) {
  raw = String(raw || '').trim();
  if (raw.indexOf('shahid:') === 0) raw = raw.substring(7);
  var m = raw.match(/(\d+)/);
  return m ? m[1] : '';
}

function cleanPlayUrl(raw) {
  var url = String(raw || '').trim();
  if (!url) return '';
  // API sometimes concatenates two manifests with `&`.
  var amp = url.indexOf('.mpd&');
  if (amp > 0) url = url.substring(0, amp + 4);
  amp = url.indexOf('.m3u8&');
  if (amp > 0) url = url.substring(0, amp + 5);
  return url.replace(/aws\.manifestfilter=[\w:;,-]+&?/g, '');
}

function buildDrmRow(videoUrl, licenceUrl) {
  var headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    Referer: SHAHID_BASE + '/',
    Origin: SHAHID_BASE,
  };
  var authority = '';
  try {
    var m = String(licenceUrl).match(/^https?:\/\/([^/]+)/i);
    if (m) authority = m[1];
  } catch (e) {}
  var licenseHeaders = {
    origin: SHAHID_BASE,
    'User-Agent': headers['User-Agent'],
    referer: SHAHID_BASE + '/',
  };
  if (authority) licenseHeaders.authority = authority;
  return {
    url: videoUrl,
    title: 'Shahid',
    name: 'Shahid',
    headers: headers,
    drm: {
      scheme: 'widevine',
      licenseUrl: licenceUrl,
      licenseHeaders: licenseHeaders,
    },
  };
}

function fetchLicenseUrl(ctx, streamId, auth) {
  var country = _shahidCountry || 'SA';
  var ts = Date.now();
  // Compact JSON — web + Kodi both omit spaces.
  var assetId = Number(streamId);
  if (!isFinite(assetId)) assetId = streamId;
  var requestStr = JSON.stringify({ assetId: assetId });
  var authSig = signParams(ctx, {
    country: String(country),
    request: requestStr,
    ts: String(ts),
  });
  if (!authSig) {
    if (ctx && ctx.log) ctx.log('shahid drm: hmac unavailable');
    return Promise.resolve('');
  }
  // Web: request + ts + country. Do NOT send DRMSCHEMA (500s). Shd-* required.
  var qs =
    'request=' +
    encodeURIComponent(requestStr) +
    '&ts=' +
    String(ts) +
    '&country=' +
    encodeURIComponent(String(country));
  var hdrs = Object.assign(shahidHeaders(auth.sessionId, auth.jwt), {
    Authorization: authSig,
    'Accept-Language': 'ar',
  });

  function readSig(res, label) {
    if (!res.ok) {
      return res.text().then(function (body) {
        if (ctx && ctx.log) {
          ctx.log(
            'shahid drm: ' +
              label +
              ' HTTP ' +
              res.status +
              ' ' +
              String(body || '').slice(0, 160),
          );
        }
        return '';
      });
    }
    return res.json().then(function (j) {
      return (j && j.signature) || '';
    });
  }

  return ctx
    .fetch(SHAHID_PROXY + '/v2.1/playout/new/drm?' + qs, { headers: hdrs })
    .then(function (res) {
      return readSig(res, 'v2.1');
    })
    .then(function (sig) {
      if (sig) return sig;
      // Kodi fallback: unsigned v2 + browser OS headers only.
      var kodiQs = 'request=' + encodeURIComponent(requestStr);
      return ctx
        .fetch(SHAHID_PROXY + '/v2/playout/new/drm?' + kodiQs, {
          headers: {
            'User-Agent': SHAHID_UA,
            'Shahid-Agent': SHAHID_UA,
            UUID: 'ios',
            language: 'AR',
            'S-Session': auth.jwt || '',
            Token: auth.sessionId || '',
            BROWSER_NAME: 'CHROME',
            SHAHID_OS: 'LINUX',
            BROWSER_VERSION: '79.0',
          },
        })
        .then(function (res) {
          return readSig(res, 'v2-kodi');
        });
    })
    .catch(function (e) {
      if (ctx && ctx.log) {
        ctx.log('shahid drm: ' + ((e && e.message) || String(e)));
      }
      return '';
    });
}

function extract(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var videoId = parseVideoId(cfg.videoId || '');
  if (!videoId) {
    if (ctx && ctx.log) ctx.log('shahid extract: missing videoId');
    return Promise.resolve([]);
  }

  var email = String(cfg.email || '').trim();
  var password = String(cfg.password || '').trim();
  var sessionFromHost = String(cfg.sessionId || '').trim();
  var jwtFromHost = String(cfg.jwt || '').trim();
  if (sessionFromHost) _shahidSessionId = sessionFromHost;
  if (jwtFromHost) _shahidJwt = jwtFromHost;

  return getJwt(ctx)
    .then(function (jwt) {
      if (_shahidSessionId) {
        return { jwt: jwtFromHost || jwt, sessionId: _shahidSessionId };
      }
      return login(ctx, email, password).then(function (sessionId) {
        return { jwt: jwt, sessionId: sessionId };
      });
    })
    .then(function (auth) {
      var country = _shahidCountry || 'SA';
      return ctx
        .fetch(
          SHAHID_PROXY +
            '/v2.1/playout/new/url/' +
            videoId +
            '?country=' +
            encodeURIComponent(country),
          { headers: shahidHeaders(auth.sessionId, auth.jwt) },
        )
        .then(function (res) {
          if (!res.ok) {
            if (ctx && ctx.log) {
              ctx.log(
                'shahid playout: HTTP ' +
                  res.status +
                  (res.status === 422 ? ' (VIP/login required)' : '') +
                  ' id=' +
                  videoId,
              );
            }
            return [];
          }
          return res.json().then(function (j) {
            return { playout: (j && j.playout) || {}, auth: auth };
          });
        });
    })
    .then(function (pack) {
      if (!pack || !pack.playout) return [];
      var playout = pack.playout || {};
      var videoUrl = cleanPlayUrl(playout.url || '');
      if (!videoUrl) {
        if (ctx && ctx.log) ctx.log('shahid playout: empty url');
        return [];
      }
      var drmFlag = playout.drm === true || playout.drm === 'true';
      var isHls =
        /\.m3u8(\?|$)/i.test(videoUrl) || videoUrl.toLowerCase().indexOf('m3u8') >= 0;

      // Clear HLS only when Shahid says no DRM.
      if (!drmFlag && isHls) {
        return [
          {
            url: videoUrl,
            title: 'Shahid',
            name: 'Shahid',
            headers: {
              'User-Agent': SHAHID_UA,
              Referer: SHAHID_BASE + '/',
            },
          },
        ];
      }
      if (!drmFlag) {
        return [
          {
            url: videoUrl,
            title: 'Shahid',
            name: 'Shahid',
            headers: {
              'User-Agent': SHAHID_UA,
              Referer: SHAHID_BASE + '/',
            },
          },
        ];
      }

      // DRM DASH — license URL required. Host only plays Widevine on Android Exo.
      return fetchLicenseUrl(ctx, videoId, pack.auth).then(function (lic) {
        if (!lic) {
          if (ctx && ctx.log) {
            ctx.log('shahid extract: drm license miss');
          }
          return [];
        }
        return [buildDrmRow(videoUrl, lic)];
      });
    })
    .catch(function (e) {
      if (ctx && ctx.log) ctx.log('shahid extract: ' + (e && e.message));
      return [];
    });
}
