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
    parts.push(k + '=' + obj[k]);
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

function drmSchemaForUrl(url) {
  var u = String(url || '').toLowerCase();
  if (u.indexOf('.mpd') >= 0 || u.indexOf('dash') >= 0) return 'WIDEVINE_DASH';
  if (u.indexOf('.ism') >= 0 || u.indexOf('smooth') >= 0) return 'WIDEVINE';
  return 'WIDEVINE';
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

function fetchLicenseUrl(ctx, streamId, auth, mediaUrl) {
  var country = _shahidCountry || 'SA';
  var ts = Date.now();
  var assetId = Number(streamId) || streamId;
  var requestObj = { assetId: assetId };
  var requestStr = JSON.stringify(requestObj);
  var authSig = signParams(ctx, {
    country: country,
    request: requestStr,
    ts: ts,
  });
  if (!authSig) {
    if (ctx && ctx.log) ctx.log('shahid drm: hmac unavailable');
    return Promise.resolve('');
  }
  var schema = drmSchemaForUrl(mediaUrl);
  var qs =
    'request=' +
    encodeURIComponent(requestStr) +
    '&ts=' +
    encodeURIComponent(String(ts)) +
    '&country=' +
    encodeURIComponent(country);
  return ctx
    .fetch(SHAHID_PROXY + '/v2.1/playout/new/drm?' + qs, {
      headers: Object.assign(shahidHeaders(auth.sessionId, auth.jwt), {
        Authorization: authSig,
        DRMSCHEMA: schema,
        BROWSER_NAME: 'CHROME',
        SHAHID_OS: 'WEB',
        BROWSER_VERSION: '120.0',
      }),
    })
    .then(function (res) {
      if (!res.ok) {
        if (ctx && ctx.log) {
          ctx.log('shahid drm: HTTP ' + res.status + ' schema=' + schema);
        }
        return '';
      }
      return res.json().then(function (j) {
        return (j && j.signature) || '';
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

      // DRM DASH/ISM/HLS — need license URL for Android Exo Widevine.
      return fetchLicenseUrl(ctx, videoId, pack.auth, videoUrl).then(
        function (lic) {
          if (!lic) {
            if (ctx && ctx.log) {
              ctx.log(
                'shahid extract: drm license miss (Android Exo + Connected Services login required)',
              );
            }
            return [];
          }
          return [buildDrmRow(videoUrl, lic)];
        },
      );
    })
    .catch(function (e) {
      if (ctx && ctx.log) ctx.log('shahid extract: ' + (e && e.message));
      return [];
    });
}
