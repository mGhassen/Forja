// CryptoJS façade — Dart engine_polyfills parity; natives are Rust __native_crypto_*.
(function () {
  function _hexToWords(hex) {
    var w = [];
    for (var i = 0; i < hex.length; i += 8) {
      var c = hex.substring(i, i + 8);
      while (c.length < 8) c += '0';
      w.push(parseInt(c, 16) | 0);
    }
    return w;
  }
  function _wordsToHex(words, sigBytes) {
    var hex = '';
    for (var i = 0; i < sigBytes; i++) {
      var w = words[i >>> 2] || 0;
      var b = (w >>> (24 - (i % 4) * 8)) & 0xff;
      var p = b.toString(16);
      if (p.length < 2) p = '0' + p;
      hex += p;
    }
    return hex;
  }
  function _waToHex(v) {
    if (!v) return '';
    if (typeof v.__hex === 'string') return v.__hex.toLowerCase();
    if (Array.isArray(v.words) && typeof v.sigBytes === 'number')
      return _wordsToHex(v.words, v.sigBytes);
    return __native_crypto_utf8_to_hex(String(v));
  }
  function _waBuild(hex, utf8Override) {
    var nh = (hex || '').toLowerCase();
    if (nh.length % 2 !== 0) nh = '0' + nh;
    var wa = {
      __hex: nh,
      __utf8:
        utf8Override !== undefined
          ? utf8Override
          : __native_crypto_hex_to_utf8(nh),
      sigBytes: nh.length / 2,
      words: _hexToWords(nh),
      toString: function (enc) {
        if (!enc || enc === CryptoJS.enc.Hex) return this.__hex;
        if (enc === CryptoJS.enc.Utf8) return this.__utf8;
        if (enc === CryptoJS.enc.Base64) return _hexToB64(this.__hex);
        return this.__hex;
      },
      clamp: function () {
        return this;
      },
      concat: function (o) {
        var oh = _waToHex(o);
        this.__hex += oh;
        this.__utf8 = __native_crypto_hex_to_utf8(this.__hex);
        this.sigBytes = this.__hex.length / 2;
        this.words = _hexToWords(this.__hex);
        return this;
      },
    };
    return wa;
  }
  function _waFromHex(h) {
    return _waBuild(h, undefined);
  }
  function _waFromUtf8(t) {
    var s = t == null ? '' : String(t);
    return _waBuild(__native_crypto_utf8_to_hex(s), s);
  }
  function _hexToLatin1(hex) {
    var s = '';
    for (var i = 0; i + 1 < hex.length; i += 2) {
      s += String.fromCharCode(parseInt(hex.substring(i, i + 2), 16));
    }
    return s;
  }
  function _latin1ToHex(s) {
    var hex = '';
    for (var i = 0; i < s.length; i++) {
      var h = (s.charCodeAt(i) & 0xff).toString(16);
      hex += h.length < 2 ? '0' + h : h;
    }
    return hex;
  }
  function _b64ToHex(b) {
    var str = String(b || '')
      .replace(/-/g, '+')
      .replace(/_/g, '/');
    while (str.length % 4) str += '=';
    try {
      return _latin1ToHex(atob(str));
    } catch (e) {
      return '';
    }
  }
  function _hexToB64(hex) {
    try {
      return btoa(_hexToLatin1(hex));
    } catch (e) {
      return '';
    }
  }
  function _waFromBase64(b) {
    return _waFromHex(_b64ToHex(b));
  }
  function _aesModeName(mode, padding) {
    var name = mode && mode.name ? mode.name : mode;
    name = String(name || 'AES-CBC');
    if (name.indexOf('GCM') >= 0) name = 'AES-GCM';
    else if (name.indexOf('ECB') >= 0) name = 'AES-ECB';
    else name = 'AES-CBC';
    if (
      padding === 'NoPadding' ||
      (CryptoJS.pad && padding === CryptoJS.pad.NoPadding)
    )
      name += '-NoPadding';
    return name;
  }
  function _nativeAes(encrypt, mode, keyHex, ivHex, dataHex) {
    return __native_crypto_aes(
      JSON.stringify({
        encrypt: !!encrypt,
        mode: mode,
        key: keyHex || '',
        iv: ivHex || '',
        data: dataHex || '',
      }),
    );
  }
  function _evpKdf(passHex, saltHex, keyLen, ivLen) {
    var need = (keyLen + ivLen) * 2;
    var derived = '';
    var block = '';
    while (derived.length < need) {
      block = __native_crypto_digest(
        JSON.stringify({ algo: 'MD5', hex: block + passHex + (saltHex || '') }),
      );
      derived += block;
    }
    return {
      key: derived.substring(0, keyLen * 2),
      iv: derived.substring(keyLen * 2, keyLen * 2 + ivLen * 2),
    };
  }
  function _normInput(v) {
    if (v && typeof v === 'object' && typeof v.__utf8 === 'string') return v.__utf8;
    if (v && typeof v === 'object' && typeof v.__hex === 'string')
      return __native_crypto_hex_to_utf8(v.__hex);
    if (
      v &&
      typeof v === 'object' &&
      Array.isArray(v.words) &&
      typeof v.sigBytes === 'number'
    )
      return __native_crypto_hex_to_utf8(_wordsToHex(v.words, v.sigBytes));
    if (v == null) return '';
    return String(v);
  }
  function _hashWa(algo, msg) {
    var hex = __native_crypto_digest(
      JSON.stringify({ algo: algo, data: _normInput(msg) }),
    );
    return _waFromHex(hex);
  }
  function _hmacWa(algo, msg, key) {
    var hex = __native_crypto_hmac(
      JSON.stringify({
        algo: algo,
        key: _normInput(key),
        data: _normInput(msg),
      }),
    );
    return _waFromHex(hex);
  }

  var CryptoJS = {
    enc: {
      Hex: {
        stringify: function (wa) {
          return _waToHex(wa);
        },
        parse: function (h) {
          return _waFromHex(h || '');
        },
      },
      Utf8: {
        stringify: function (wa) {
          if (wa && typeof wa.__utf8 === 'string') return wa.__utf8;
          if (wa && typeof wa.__hex === 'string')
            return __native_crypto_hex_to_utf8(wa.__hex);
          return _normInput(wa);
        },
        parse: function (t) {
          return _waFromUtf8(t);
        },
      },
      Base64: {
        stringify: function (wa) {
          return _hexToB64(_waToHex(wa));
        },
        parse: function (b) {
          return _waFromBase64(b);
        },
      },
      Latin1: {
        stringify: function (wa) {
          return _hexToLatin1(_waToHex(wa));
        },
        parse: function (t) {
          return _waFromHex(_latin1ToHex(String(t == null ? '' : t)));
        },
      },
    },
    lib: {
      WordArray: {
        create: function (words, sigBytes) {
          if (words == null) return _waBuild('');
          if (words && typeof words.__hex === 'string')
            return _waBuild(words.__hex, words.__utf8);
          if (typeof words === 'string') return _waFromUtf8(words);
          var sb = typeof sigBytes === 'number' ? sigBytes : words.length * 4;
          return _waBuild(_wordsToHex(words, sb));
        },
        random: function (nBytes) {
          var n = nBytes | 0;
          var hex = '';
          for (var i = 0; i < n; i++) {
            var h = Math.floor(Math.random() * 256).toString(16);
            hex += h.length < 2 ? '0' + h : h;
          }
          return _waFromHex(hex);
        },
      },
    },
    format: {
      OpenSSL: {
        stringify: function (params) {
          var ct = _waToHex(params && params.ciphertext ? params.ciphertext : params);
          if (params && params.salt) ct = '53616c7465645f5f' + _waToHex(params.salt) + ct;
          return _hexToB64(ct);
        },
        parse: function (str) {
          var hex = _b64ToHex(str);
          if (hex.indexOf('53616c7465645f5f') === 0 && hex.length >= 32) {
            return {
              salt: _waFromHex(hex.substring(16, 32)),
              ciphertext: _waFromHex(hex.substring(32)),
            };
          }
          return { ciphertext: _waFromHex(hex) };
        },
      },
    },
    mode: { CBC: 'AES-CBC', GCM: 'AES-GCM', ECB: 'AES-ECB' },
    pad: { Pkcs7: 'Pkcs7', NoPadding: 'NoPadding' },
    MD5: function (m) {
      return _hashWa('MD5', m);
    },
    SHA1: function (m) {
      return _hashWa('SHA1', m);
    },
    SHA256: function (m) {
      return _hashWa('SHA256', m);
    },
    SHA512: function (m) {
      return _hashWa('SHA512', m);
    },
    HmacMD5: function (m, k) {
      return _hmacWa('MD5', m, k);
    },
    HmacSHA1: function (m, k) {
      return _hmacWa('SHA1', m, k);
    },
    HmacSHA256: function (m, k) {
      return _hmacWa('SHA256', m, k);
    },
    HmacSHA512: function (m, k) {
      return _hmacWa('SHA512', m, k);
    },
    AES: {
      encrypt: function (message, key, options) {
        options = options || {};
        var dataHex = _waToHex(
          typeof message === 'string' ? _waFromUtf8(message) : message,
        );
        var keyHex, ivHex;
        if (typeof key === 'string') {
          var saltHex = options.salt
            ? _waToHex(options.salt)
            : _waToHex(CryptoJS.lib.WordArray.random(8));
          var derived = _evpKdf(
            __native_crypto_utf8_to_hex(key),
            saltHex,
            32,
            16,
          );
          keyHex = derived.key;
          ivHex = options.iv ? _waToHex(options.iv) : derived.iv;
          var encHex = _nativeAes(
            true,
            _aesModeName(options.mode, options.padding),
            keyHex,
            ivHex,
            dataHex,
          );
          return {
            ciphertext: _waFromHex(encHex),
            salt: _waFromHex(saltHex),
            toString: function (fmt) {
              return (fmt || CryptoJS.format.OpenSSL).stringify(this);
            },
          };
        }
        keyHex = _waToHex(key);
        ivHex = options.iv ? _waToHex(options.iv) : '';
        return _waFromHex(
          _nativeAes(
            true,
            _aesModeName(options.mode, options.padding),
            keyHex,
            ivHex,
            dataHex,
          ),
        );
      },
      decrypt: function (cipher, key, options) {
        options = options || {};
        var parsed =
          typeof cipher === 'string'
            ? CryptoJS.format.OpenSSL.parse(cipher)
            : cipher;
        var dataHex =
          parsed && parsed.ciphertext
            ? _waToHex(parsed.ciphertext)
            : _waToHex(parsed);
        var keyHex, ivHex;
        if (typeof key === 'string') {
          var saltHex = options.salt
            ? _waToHex(options.salt)
            : parsed && parsed.salt
              ? _waToHex(parsed.salt)
              : '';
          var derived = _evpKdf(
            __native_crypto_utf8_to_hex(key),
            saltHex,
            32,
            16,
          );
          keyHex = derived.key;
          ivHex = options.iv ? _waToHex(options.iv) : derived.iv;
        } else {
          keyHex = _waToHex(key);
          ivHex = options.iv ? _waToHex(options.iv) : '';
        }
        return _waFromHex(
          _nativeAes(
            false,
            _aesModeName(options.mode, options.padding),
            keyHex,
            ivHex,
            dataHex,
          ),
        );
      },
    },
  };
  globalThis.CryptoJS = CryptoJS;
  globalThis.__engineRequire = function (name) {
    if (name === 'crypto-js') return globalThis.CryptoJS;
    if (
      name === 'cheerio' ||
      name === 'cheerio-without-node-native' ||
      name === 'react-native-cheerio'
    ) {
      return globalThis.__engineCheerio || {};
    }
    throw new Error("Module '" + name + "' is not available in EngineRuntime");
  };
})();
