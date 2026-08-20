/// EngineRuntime polyfills (atob/URL/CryptoJS). Copied from NuvioRuntime host, own heap.
const String kEnginePolyfillsJs = r'''
(function(){
  // ── globals ─────────────────────────────────────────────────────────────
  if (typeof globalThis.global === 'undefined') globalThis.global = globalThis;
  if (typeof globalThis.window === 'undefined') globalThis.window = globalThis;
  if (typeof globalThis.self   === 'undefined') globalThis.self   = globalThis;

  // ── console (route through native bridge) ───────────────────────────────
  function _stringifyArgs(args){
    try {
      return Array.prototype.slice.call(args).map(function(a){
        if (a == null) return String(a);
        if (typeof a === 'string') return a;
        try { return JSON.stringify(a); } catch (e) { return String(a); }
      }).join(' ');
    } catch (e) { return ''; }
  }
  function _send(level, args){
    try { sendMessage('Console', JSON.stringify({level: level, msg: _stringifyArgs(args)})); } catch (e) {}
  }
  globalThis.console = {
    log:   function(){ _send('log',   arguments); },
    info:  function(){ _send('info',  arguments); },
    warn:  function(){ _send('warn',  arguments); },
    error: function(){ _send('err',   arguments); },
    debug: function(){ _send('log',   arguments); },
    trace: function(){ _send('log',   arguments); },
  };

  // ── ES2019+ shims ──────────────────────────────────────────────────────
  if (!Array.prototype.flat) {
    Array.prototype.flat = function(depth){
      depth = depth === undefined ? 1 : Math.floor(depth);
      if (depth < 1) return Array.prototype.slice.call(this);
      return (function flatten(arr, d){
        return d > 0
          ? arr.reduce(function(acc, val){ return acc.concat(Array.isArray(val) ? flatten(val, d-1) : val); }, [])
          : arr.slice();
      })(this, depth);
    };
  }
  if (!Array.prototype.flatMap) {
    Array.prototype.flatMap = function(cb, thisArg){ return this.map(cb, thisArg).flat(); };
  }
  if (!Object.entries) {
    Object.entries = function(o){
      var r = [];
      for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) r.push([k, o[k]]);
      return r;
    };
  }
  if (!Object.fromEntries) {
    Object.fromEntries = function(entries){
      var r = {};
      for (var i = 0; i < entries.length; i++) r[entries[i][0]] = entries[i][1];
      return r;
    };
  }
  if (!String.prototype.replaceAll) {
    String.prototype.replaceAll = function(s, r){
      if (s instanceof RegExp) {
        if (!s.global) throw new TypeError('replaceAll must be called with a global RegExp');
        return this.replace(s, r);
      }
      return this.split(s).join(r);
    };
  }

  // ── atob / btoa ────────────────────────────────────────────────────────
  var _b64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  if (typeof atob === 'undefined') {
    globalThis.atob = function(input){
      var str = String(input).replace(/=+$/, '');
      if (str.length % 4 === 1) throw new Error('InvalidCharacterError');
      var output = '', bc = 0, bs = 0, buffer, idx = 0;
      while ((buffer = str.charAt(idx++))) {
        buffer = _b64Chars.indexOf(buffer);
        if (buffer === -1) continue;
        bs = bc % 4 ? bs * 64 + buffer : buffer;
        if (bc++ % 4) output += String.fromCharCode(255 & (bs >> ((-2 * bc) & 6)));
      }
      return output;
    };
  }
  if (typeof btoa === 'undefined') {
    globalThis.btoa = function(input){
      var str = String(input), output = '', map = _b64Chars, block, charCode, idx = 0;
      for (; str.charAt(idx | 0) || (map = '=', idx % 1);
           output += map.charAt(63 & (block >> (8 - (idx % 1) * 8)))) {
        charCode = str.charCodeAt(idx += 3 / 4);
        if (charCode > 0xFF) throw new Error('InvalidCharacterError');
        block = (block << 8) | charCode;
      }
      return output;
    };
  }

  // ── AbortController / AbortSignal ──────────────────────────────────────
  if (typeof AbortSignal === 'undefined') {
    var AbortSignal = function(){ this.aborted = false; this.reason = undefined; this._listeners = []; };
    AbortSignal.prototype.addEventListener = function(t, l){ if (t === 'abort' && typeof l === 'function') this._listeners.push(l); };
    AbortSignal.prototype.removeEventListener = function(t, l){ if (t === 'abort') this._listeners = this._listeners.filter(function(x){ return x !== l; }); };
    AbortSignal.prototype.dispatchEvent = function(ev){
      if (!ev || ev.type !== 'abort') return true;
      for (var i = 0; i < this._listeners.length; i++) { try { this._listeners[i].call(this, ev); } catch (e) {} }
      return true;
    };
    globalThis.AbortSignal = AbortSignal;
  }
  if (typeof AbortController === 'undefined') {
    var AbortController = function(){ this.signal = new AbortSignal(); };
    AbortController.prototype.abort = function(reason){
      if (this.signal.aborted) return;
      this.signal.aborted = true;
      this.signal.reason = reason;
      this.signal.dispatchEvent({ type: 'abort' });
    };
    globalThis.AbortController = AbortController;
  }

  // ── URL / URLSearchParams ──────────────────────────────────────────────
  globalThis.URLSearchParams = function(init){
    this._params = {};
    var self = this;
    if (init && typeof init === 'object' && !Array.isArray(init)) {
      Object.keys(init).forEach(function(k){ self._params[k] = String(init[k]); });
    } else if (typeof init === 'string') {
      init.replace(/^\?/, '').split('&').forEach(function(pair){
        if (!pair) return;
        var i = pair.indexOf('=');
        var k = i < 0 ? pair : pair.substring(0, i);
        var v = i < 0 ? '' : pair.substring(i + 1);
        try { self._params[decodeURIComponent(k)] = decodeURIComponent(v); }
        catch (e) { self._params[k] = v; }
      });
    }
  };
  globalThis.URLSearchParams.prototype.toString = function(){
    var self = this;
    return Object.keys(this._params).map(function(k){
      return encodeURIComponent(k) + '=' + encodeURIComponent(self._params[k]);
    }).join('&');
  };
  globalThis.URLSearchParams.prototype.get    = function(k){ return Object.prototype.hasOwnProperty.call(this._params, k) ? this._params[k] : null; };
  globalThis.URLSearchParams.prototype.set    = function(k, v){ this._params[k] = String(v); };
  globalThis.URLSearchParams.prototype.append = function(k, v){ this._params[k] = String(v); };
  globalThis.URLSearchParams.prototype.has    = function(k){ return Object.prototype.hasOwnProperty.call(this._params, k); };
  globalThis.URLSearchParams.prototype.delete = function(k){ delete this._params[k]; };
  globalThis.URLSearchParams.prototype.keys   = function(){ return Object.keys(this._params); };
  globalThis.URLSearchParams.prototype.values = function(){ var s = this; return Object.keys(this._params).map(function(k){ return s._params[k]; }); };
  globalThis.URLSearchParams.prototype.entries = function(){ var s = this; return Object.keys(this._params).map(function(k){ return [k, s._params[k]]; }); };
  globalThis.URLSearchParams.prototype.forEach = function(cb){ var s = this; Object.keys(this._params).forEach(function(k){ cb(s._params[k], k, s); }); };
  globalThis.URLSearchParams.prototype.getAll  = function(k){ return Object.prototype.hasOwnProperty.call(this._params, k) ? [this._params[k]] : []; };
  globalThis.URLSearchParams.prototype.sort    = function(){ var s = {}; var t = this; Object.keys(this._params).sort().forEach(function(k){ s[k] = t._params[k]; }); this._params = s; };

  globalThis.URL = function(urlString, base){
    var fullUrl = urlString;
    if (base && !/^[a-z][a-z0-9+\-.]*:\/\//i.test(urlString)) {
      var b = typeof base === 'string' ? base : base.href;
      if (urlString.charAt(0) === '/') {
        var m = b.match(/^([a-z][a-z0-9+\-.]*:\/\/[^\/]+)/i);
        fullUrl = m ? m[1] + urlString : urlString;
      } else {
        fullUrl = b.replace(/\/[^\/]*$/, '/') + urlString;
      }
    }
    var data = sendMessage('ParseUrl', JSON.stringify({url: fullUrl}));
    this.href = fullUrl;
    this.protocol = data.protocol;
    this.host = data.host;
    this.hostname = data.hostname;
    this.port = data.port;
    this.pathname = data.pathname;
    this.search = data.search;
    this.hash = data.hash;
    this.origin = data.protocol + '//' + data.host;
    this.searchParams = new URLSearchParams(data.search || '');
  };
  globalThis.URL.prototype.toString = function(){ return this.href; };

  // ── CryptoJS façade (Dart-backed) ──────────────────────────────────────
  function _hexToWords(hex){
    var w = [];
    for (var i = 0; i < hex.length; i += 8) {
      var c = hex.substring(i, i + 8);
      while (c.length < 8) c += '0';
      w.push(parseInt(c, 16) | 0);
    }
    return w;
  }
  function _wordsToHex(words, sigBytes){
    var hex = '';
    for (var i = 0; i < sigBytes; i++) {
      var w = words[i >>> 2] || 0;
      var b = (w >>> (24 - (i % 4) * 8)) & 0xff;
      var p = b.toString(16); if (p.length < 2) p = '0' + p;
      hex += p;
    }
    return hex;
  }
  function _waToHex(v){
    if (!v) return '';
    if (typeof v.__hex === 'string') return v.__hex.toLowerCase();
    if (Array.isArray(v.words) && typeof v.sigBytes === 'number') return _wordsToHex(v.words, v.sigBytes);
    return sendMessage('CryptoUtf8ToHex', JSON.stringify({data: String(v)}));
  }
  function _waBuild(hex, utf8Override){
    var nh = (hex || '').toLowerCase();
    if (nh.length % 2 !== 0) nh = '0' + nh;
    var wa = {
      __hex: nh,
      __utf8: utf8Override !== undefined ? utf8Override : sendMessage('CryptoHexToUtf8', JSON.stringify({data: nh})),
      sigBytes: nh.length / 2,
      words: _hexToWords(nh),
      toString: function(enc){
        if (!enc || enc === CryptoJS.enc.Hex) return this.__hex;
        if (enc === CryptoJS.enc.Utf8) return this.__utf8;
        if (enc === CryptoJS.enc.Base64) return _hexToB64(this.__hex);
        return this.__hex;
      },
      clamp: function(){ return this; },
      concat: function(o){
        var oh = _waToHex(o);
        this.__hex += oh;
        this.__utf8 = sendMessage('CryptoHexToUtf8', JSON.stringify({data: this.__hex}));
        this.sigBytes = this.__hex.length / 2;
        this.words = _hexToWords(this.__hex);
        return this;
      }
    };
    return wa;
  }
  function _waFromHex(h){ return _waBuild(h, undefined); }
  function _waFromUtf8(t){
    var s = (t == null) ? '' : String(t);
    return _waBuild(sendMessage('CryptoUtf8ToHex', JSON.stringify({data: s})), s);
  }
  function _hexToLatin1(hex){
    var s = '';
    for (var i = 0; i + 1 < hex.length; i += 2) {
      s += String.fromCharCode(parseInt(hex.substring(i, i + 2), 16));
    }
    return s;
  }
  function _latin1ToHex(s){
    var hex = '';
    for (var i = 0; i < s.length; i++) {
      var h = (s.charCodeAt(i) & 0xff).toString(16);
      hex += h.length < 2 ? '0' + h : h;
    }
    return hex;
  }
  function _b64ToHex(b){
    var str = String(b || '').replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    try { return _latin1ToHex(atob(str)); } catch (e) { return ''; }
  }
  function _hexToB64(hex){
    try { return btoa(_hexToLatin1(hex)); } catch (e) { return ''; }
  }
  function _waFromBase64(b){ return _waFromHex(_b64ToHex(b)); }
  function _aesModeName(mode, padding){
    var name = mode && mode.name ? mode.name : mode;
    name = String(name || 'AES-CBC');
    if (name.indexOf('GCM') >= 0) name = 'AES-GCM';
    else if (name.indexOf('ECB') >= 0) name = 'AES-ECB';
    else name = 'AES-CBC';
    if (padding === 'NoPadding' || (CryptoJS.pad && padding === CryptoJS.pad.NoPadding)) name += '-NoPadding';
    return name;
  }
  function _nativeAes(encrypt, mode, keyHex, ivHex, dataHex){
    return sendMessage('CryptoAes', JSON.stringify({
      encrypt: !!encrypt, mode: mode, key: keyHex || '', iv: ivHex || '', data: dataHex || ''
    }));
  }
  function _evpKdf(passHex, saltHex, keyLen, ivLen){
    var need = (keyLen + ivLen) * 2;
    var derived = '';
    var block = '';
    while (derived.length < need) {
      block = sendMessage('CryptoDigest', JSON.stringify({algo: 'MD5', hex: block + passHex + (saltHex || '')}));
      derived += block;
    }
    return { key: derived.substring(0, keyLen * 2), iv: derived.substring(keyLen * 2, keyLen * 2 + ivLen * 2) };
  }
  function _normInput(v){
    if (v && typeof v === 'object' && typeof v.__utf8 === 'string') return v.__utf8;
    if (v && typeof v === 'object' && typeof v.__hex  === 'string') return sendMessage('CryptoHexToUtf8', JSON.stringify({data: v.__hex}));
    if (v && typeof v === 'object' && Array.isArray(v.words) && typeof v.sigBytes === 'number') return sendMessage('CryptoHexToUtf8', JSON.stringify({data: _wordsToHex(v.words, v.sigBytes)}));
    if (v == null) return '';
    return String(v);
  }
  function _hashWa(algo, msg){
    var hex = sendMessage('CryptoDigest', JSON.stringify({algo: algo, data: _normInput(msg)}));
    return _waFromHex(hex);
  }
  function _hmacWa(algo, msg, key){
    var hex = sendMessage('CryptoHmac', JSON.stringify({algo: algo, key: _normInput(key), data: _normInput(msg)}));
    return _waFromHex(hex);
  }

  var CryptoJS = {
    enc: {
      Hex: {
        stringify: function(wa){ return _waToHex(wa); },
        parse: function(h){ return _waFromHex(h || ''); }
      },
      Utf8: {
        stringify: function(wa){
          if (wa && typeof wa.__utf8 === 'string') return wa.__utf8;
          if (wa && typeof wa.__hex  === 'string') return sendMessage('CryptoHexToUtf8', JSON.stringify({data: wa.__hex}));
          return _normInput(wa);
        },
        parse: function(t){ return _waFromUtf8(t); }
      },
      Base64: {
        stringify: function(wa){ return _hexToB64(_waToHex(wa)); },
        parse: function(b){ return _waFromBase64(b); }
      },
      Latin1: {
        stringify: function(wa){ return _hexToLatin1(_waToHex(wa)); },
        parse: function(t){ return _waFromHex(_latin1ToHex(String(t == null ? '' : t))); }
      }
    },
    lib: {
      WordArray: {
        create: function(words, sigBytes){
          if (words == null) return _waBuild('');
          if (words && typeof words.__hex === 'string') return _waBuild(words.__hex, words.__utf8);
          if (typeof words === 'string') return _waFromUtf8(words);
          var sb = typeof sigBytes === 'number' ? sigBytes : words.length * 4;
          return _waBuild(_wordsToHex(words, sb));
        },
        random: function(nBytes){
          var n = nBytes|0;
          var hex = '';
          for (var i = 0; i < n; i++) {
            var h = Math.floor(Math.random() * 256).toString(16);
            hex += h.length < 2 ? '0' + h : h;
          }
          return _waFromHex(hex);
        }
      }
    },
    format: {
      OpenSSL: {
        stringify: function(params){
          var ct = _waToHex(params && params.ciphertext ? params.ciphertext : params);
          if (params && params.salt) ct = '53616c7465645f5f' + _waToHex(params.salt) + ct;
          return _hexToB64(ct);
        },
        parse: function(str){
          var hex = _b64ToHex(str);
          if (hex.indexOf('53616c7465645f5f') === 0 && hex.length >= 32) {
            return { salt: _waFromHex(hex.substring(16, 32)), ciphertext: _waFromHex(hex.substring(32)) };
          }
          return { ciphertext: _waFromHex(hex) };
        }
      }
    },
    mode: { CBC: 'AES-CBC', GCM: 'AES-GCM', ECB: 'AES-ECB' },
    pad: { Pkcs7: 'Pkcs7', NoPadding: 'NoPadding' },
    MD5:    function(m){ return _hashWa('MD5',    m); },
    SHA1:   function(m){ return _hashWa('SHA1',   m); },
    SHA256: function(m){ return _hashWa('SHA256', m); },
    SHA512: function(m){ return _hashWa('SHA512', m); },
    HmacMD5:    function(m, k){ return _hmacWa('MD5',    m, k); },
    HmacSHA1:   function(m, k){ return _hmacWa('SHA1',   m, k); },
    HmacSHA256: function(m, k){ return _hmacWa('SHA256', m, k); },
    HmacSHA512: function(m, k){ return _hmacWa('SHA512', m, k); },
    AES: {
      encrypt: function(message, key, options){
        options = options || {};
        var dataHex = _waToHex(typeof message === 'string' ? _waFromUtf8(message) : message);
        var keyHex, ivHex;
        if (typeof key === 'string') {
          var saltHex = options.salt ? _waToHex(options.salt) : _waToHex(CryptoJS.lib.WordArray.random(8));
          var derived = _evpKdf(sendMessage('CryptoUtf8ToHex', JSON.stringify({data: key})), saltHex, 32, 16);
          keyHex = derived.key;
          ivHex = options.iv ? _waToHex(options.iv) : derived.iv;
          var encHex = _nativeAes(true, _aesModeName(options.mode, options.padding), keyHex, ivHex, dataHex);
          return {
            ciphertext: _waFromHex(encHex),
            salt: _waFromHex(saltHex),
            toString: function(fmt){ return (fmt || CryptoJS.format.OpenSSL).stringify(this); }
          };
        }
        keyHex = _waToHex(key);
        ivHex = options.iv ? _waToHex(options.iv) : '';
        return _waFromHex(_nativeAes(true, _aesModeName(options.mode, options.padding), keyHex, ivHex, dataHex));
      },
      decrypt: function(cipher, key, options){
        options = options || {};
        var parsed = typeof cipher === 'string' ? CryptoJS.format.OpenSSL.parse(cipher) : cipher;
        var dataHex = parsed && parsed.ciphertext ? _waToHex(parsed.ciphertext) : _waToHex(parsed);
        var keyHex, ivHex;
        if (typeof key === 'string') {
          var saltHex = options.salt ? _waToHex(options.salt) : (parsed && parsed.salt ? _waToHex(parsed.salt) : '');
          var derived = _evpKdf(sendMessage('CryptoUtf8ToHex', JSON.stringify({data: key})), saltHex, 32, 16);
          keyHex = derived.key;
          ivHex = options.iv ? _waToHex(options.iv) : derived.iv;
        } else {
          keyHex = _waToHex(key);
          ivHex = options.iv ? _waToHex(options.iv) : '';
        }
        return _waFromHex(_nativeAes(false, _aesModeName(options.mode, options.padding), keyHex, ivHex, dataHex));
      }
    }
  };
  globalThis.CryptoJS = CryptoJS;
  globalThis.__engineCheerio = globalThis.__engineCheerio || null;
  globalThis.__engineRequire = function(name){
    if (name === 'crypto-js') return globalThis.CryptoJS;
    if (name === 'cheerio' || name === 'cheerio-without-node-native' || name === 'react-native-cheerio') {
      return globalThis.__engineCheerio || {};
    }
    throw new Error("Module '" + name + "' is not available in EngineRuntime");
  };

  globalThis.__engineCtxMal = function(ctx) {
    var id = ctx.malId;
    if (id == null || id === '' || Number(id) <= 0) return null;
    var ep = ctx.mappedEpisode != null && ctx.mappedEpisode !== ''
      ? Number(ctx.mappedEpisode)
      : (ctx.episode || 1);
    return {
      malId: Number(id),
      mal: Number(id),
      mappedEp: ep,
      ep: ep,
      title: String(ctx.title || '')
    };
  };
  globalThis.__engineCtxAnilist = function(ctx) {
    var id = ctx.anilistId;
    if (id == null || id === '' || Number(id) <= 0) return null;
    return Number(id);
  };

})();
''';
