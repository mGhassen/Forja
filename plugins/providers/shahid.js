// Shahid provider — playout → clear HLS or Widevine license row (RFC-101).
// Auth: email/password from pack settings (hub extractPluginIds or self).

var SHAHID_UA =
  'Shahid/6.8.3.3660 CFNetwork/1220.1 Darwin/20.3.0 (iPhone/6s iOS/14.4) Safari/604.1';
var SHAHID_BASE = 'https://shahid.mbc.net';
var SHAHID_PROXY = 'https://api2.shahid.net/proxy';
var SHAHID_AES_KEY = 'gx8KSZyPdfJhXes7';

var _shahidSessionId = '';
var _shahidJwt = '';

function shahidHeaders(sessionId, jwt) {
  var h = {
    'User-Agent': SHAHID_UA,
    'Shahid-Agent': SHAHID_UA,
    UUID: 'ios',
    language: 'ar',
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

function buildDrmRow(ctx, streamId, videoUrl, licenceUrl) {
  var headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
  };
  var licenseHeaders = {
    authority: 'shahiddotnet.keydelivery.westeurope.media.azure.net',
    origin: SHAHID_BASE,
    'User-Agent': headers['User-Agent'],
    referer: SHAHID_BASE + '/',
  };
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

function fetchLicenseUrl(ctx, streamId, jwt) {
  var filter =
    'request=' +
    encodeURIComponent(JSON.stringify({ assetId: String(streamId) }));
  return ctx
    .fetch(SHAHID_PROXY + '/v2/playout/new/drm?' + filter, {
      headers: Object.assign(shahidHeaders('', jwt), {
        BROWSER_NAME: 'CHROME',
        SHAHID_OS: 'LINUX',
        BROWSER_VERSION: '79.0',
      }),
    })
    .then(function (res) {
      return res.json();
    })
    .then(function (j) {
      return (j && j.signature) || '';
    })
    .catch(function () {
      return '';
    });
}

function extract(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var videoId = parseVideoId(cfg.videoId || '');
  if (!videoId) return Promise.resolve([]);

  var email = String(cfg.email || '').trim();
  var password = String(cfg.password || '').trim();

  return getJwt(ctx)
    .then(function (jwt) {
      return login(ctx, email, password).then(function (sessionId) {
        return { jwt: jwt, sessionId: sessionId };
      });
    })
    .then(function (auth) {
      return ctx
        .fetch(SHAHID_PROXY + '/v2.1/playout/new/url/' + videoId, {
          headers: shahidHeaders(auth.sessionId, auth.jwt),
        })
        .then(function (res) {
          if (!res.ok) {
            if (res.status === 422) return [];
            throw new Error('HTTP ' + res.status);
          }
          return res.json().then(function (j) {
            return { playout: (j && j.playout) || {}, auth: auth };
          });
        });
    })
    .then(function (pack) {
      var playout = pack.playout || {};
      var videoUrl = String(playout.url || '').trim();
      if (!videoUrl) return [];
      var drmFlag = playout.drm === true || playout.drm === 'true';
      var isHls = /\.m3u8(\?|$)/i.test(videoUrl) || videoUrl.indexOf('m3u8') >= 0;
      if (!drmFlag || isHls) {
        return [
          {
            url: videoUrl.replace(/aws\.manifestfilter=[\w:;,-]+&?/g, ''),
            title: 'Shahid',
            name: 'Shahid',
            headers: {
              'User-Agent': SHAHID_UA,
              Referer: SHAHID_BASE + '/',
            },
          },
        ];
      }
      return fetchLicenseUrl(ctx, videoId, pack.auth.jwt).then(function (lic) {
        if (!lic) return [];
        return [buildDrmRow(ctx, videoId, videoUrl, lic)];
      });
    })
    .catch(function (e) {
      if (ctx && ctx.log) ctx.log('shahid extract: ' + (e && e.message));
      return [];
    });
}

