// STREAMCRYPTO (`enc=2`) — seed + media id → XOR keystream → `mvm1` JSON.
// Shared by Videasy, VidSrc.sbs nested player, and any provider using enc=2.

(function (global) {
  var MASK = 0xffffffff;
  var GOLDEN = 0x9e3779b9;
  var MAGIC = [109, 118, 109, 49];

  function imul(a, b) {
    return Math.imul(a, b) >>> 0;
  }

  function f(e) {
    e = e >>> 0;
    e ^= e >>> 16;
    e = imul(e, 2246822507);
    e ^= e >>> 13;
    e = imul(e, 3266489909);
    e ^= e >>> 16;
    return e >>> 0;
  }

  function rotl(e, t) {
    e = e >>> 0;
    t = t & 31;
    if (t === 0) return e;
    return ((e << t) | (e >>> (32 - t))) >>> 0;
  }

  function fnvF(text) {
    var t = 2166136261;
    for (var i = 0; i < text.length; i++) {
      t = imul(t ^ text.charCodeAt(i), 16777619);
    }
    return f(t);
  }

  function keySchedule(seed, mediaId) {
    var n = f(fnvF(seed) ^ f((mediaId >>> 0) ^ GOLDEN));
    var state = {};
    for (var e = 0; e < 8; e++) {
      var idx = n % 61;
      n = rotl((n + GOLDEN) >>> 0, 7 + (e & 7));
      state[idx] = (n ^ f(n)) >>> 0;
      n = f((n + idx) >>> 0);
    }
    return { state: state, acc: f(2779096485 ^ n) };
  }

  function keystream(seed, mediaId, length) {
    var sched = keySchedule(seed, mediaId);
    var state = sched.state;
    var acc = sched.acc;
    var out = new Uint8Array(length);
    var pos = 0;
    var counter = 0;
    while (pos < length) {
      var a = acc;
      var i = a % 61;
      var mask = Object.prototype.hasOwnProperty.call(state, i) ? MASK : 0;
      var low = state[i] || 0;
      var mixed = (low ^ imul(GOLDEN, counter + 1)) >>> 0;
      var c = ((a ^ mixed) | (a & mixed & mask)) >>> 0;
      c = (rotl((c + a) >>> 0, i & 31) ^ rotl(a, imul(i, 7) & 31)) >>> 0;
      acc = f((c + GOLDEN) >>> 0);
      state[i] = acc >>> 0;
      counter++;
      var val = acc;
      out[pos++] = val & 255;
      if (pos < length) out[pos++] = (val >>> 8) & 255;
      if (pos < length) out[pos++] = (val >>> 16) & 255;
      if (pos < length) out[pos++] = (val >>> 24) & 255;
    }
    return out;
  }

  function b64urlDecode(text) {
    var t = String(text).trim().replace(/-/g, '+').replace(/_/g, '/');
    if (!t) throw new Error('STREAMCRYPTO: empty payload');
    var pad = (4 - (t.length % 4)) % 4;
    t += '===='.substring(0, pad);
    var bin = atob(t);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function utf8Decode(bytes) {
    var out = '';
    var i = 0;
    while (i < bytes.length) {
      var c = bytes[i++];
      if (c < 0x80) out += String.fromCharCode(c);
      else if (c < 0xe0) {
        out += String.fromCharCode(((c & 0x1f) << 6) | (bytes[i++] & 0x3f));
      } else {
        out += String.fromCharCode(
          ((c & 0x0f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f),
        );
      }
    }
    return out;
  }

  function streamDecrypt(payload, seed, mediaId) {
    var data = b64urlDecode(payload);
    if (data.length < MAGIC.length) {
      throw new Error('STREAMCRYPTO: payload too short');
    }
    var id = parseInt(String(mediaId).trim(), 10);
    if (!isFinite(id)) {
      throw new Error('STREAMCRYPTO: invalid media id ' + mediaId);
    }
    var ks = keystream(seed, id, data.length);
    for (var i = 0; i < data.length; i++) data[i] ^= ks[i];
    for (var j = 0; j < MAGIC.length; j++) {
      if (data[j] !== MAGIC[j]) {
        throw new Error('STREAMCRYPTO: bad seed or tampered payload');
      }
    }
    return utf8Decode(data.subarray(MAGIC.length));
  }

  function streamEncryptForTest(json, seed, mediaId) {
    var id = parseInt(String(mediaId).trim(), 10);
    if (!isFinite(id)) throw new Error('STREAMCRYPTO: invalid media id');
    var plain = new Uint8Array(MAGIC.length + json.length);
    for (var m = 0; m < MAGIC.length; m++) plain[m] = MAGIC[m];
    for (var k = 0; k < json.length; k++) {
      plain[MAGIC.length + k] = json.charCodeAt(k);
    }
    var ks = keystream(seed, id, plain.length);
    for (var n = 0; n < plain.length; n++) plain[n] ^= ks[n];
    var b64 = btoa(String.fromCharCode.apply(null, plain));
    return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  }

  global.__engineStreamDecrypt = streamDecrypt;
  global.__engineStreamEncryptForTest = streamEncryptForTest;
})(typeof globalThis !== 'undefined' ? globalThis : this);
