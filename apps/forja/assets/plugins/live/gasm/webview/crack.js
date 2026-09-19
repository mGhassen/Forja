/**
 * Browser port of gasm/unlock.mjs crack() — Android/iOS WebView.
 * Page baseUrl must be https://embedindia.st/ (see LiveGasmWebviewUnlock).
 * Dart POST /fetch; this runs set_stream / set_stream_jw + memory scrape.
 *
 * Result: console.log('GASM_RESULT:' + JSON.stringify({ok,url,error}))
 */

function assetUrl(path) {
  const base = String(window.__GASM_ASSET_BASE || '').replace(/\/+$/, '');
  if (!base) throw new Error('__GASM_ASSET_BASE missing');
  return base + (path.startsWith('/') ? path : '/' + path);
}

const PAIRS = [
  {
    name: 'live',
    js: '/vendor/gasm-browser.mjs',
    wasm: '/vendor/gasm-live.wasm',
    applyFlags: true,
  },
  {
    name: 'live-noflags',
    js: '/vendor/gasm-browser.mjs',
    wasm: '/vendor/gasm-live.wasm',
    applyFlags: false,
  },
  {
    name: 'ref',
    js: '/vendor/gasm.js',
    wasm: '/vendor/gasm.wasm',
    applyFlags: true,
  },
];

function pagePath(slot) {
  return slot.path || `${slot.league}/${slot.date}/${slot.slug}`;
}

function hexToBytes(hex) {
  const clean = String(hex || '').replace(/[^0-9a-fA-F]/g, '');
  if (clean.length % 2) throw new Error('bodyHex odd length');
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.substr(i * 2, 2), 16);
  }
  return out;
}

function readVarint(buf, offset) {
  let value = 0;
  let shift = 0;
  let i = offset;
  while (i < buf.length) {
    const byte = buf[i++];
    value |= (byte & 0x7f) << shift;
    if (!(byte & 0x80)) return { value, next: i };
    shift += 7;
  }
  return { value, next: i };
}

function slugFromFetchBody(body) {
  let i = 0;
  while (i < body.length) {
    const tag = body[i++];
    const field = tag >> 3;
    const wire = tag & 7;
    if (wire !== 2) break;
    const { value: len, next } = readVarint(body, i);
    i = next;
    if (i + len > body.length) break;
    let value = '';
    for (let j = 0; j < len; j++) value += String.fromCharCode(body[i + j]);
    i += len;
    if (field === 2 && value && !value.startsWith('{')) return value;
  }
  return null;
}

function extractUrl(memory, slug) {
  const u8 = new Uint8Array(memory.buffer);
  let text = '';
  for (let i = 0; i < u8.length; i++) text += String.fromCharCode(u8[i]);
  const re = /https:\/\/[a-z0-9.-]+\/secure\/[^\x00-\x1f\s"']+?\.m3u8/gi;
  const matches = [];
  let match;
  while ((match = re.exec(text)) !== null) matches.push(match[0]);
  if (!matches.length) return null;
  if (slug) {
    const hit = matches.find((url) => url.includes('/' + slug + '/'));
    if (hit) return hit;
  }
  return matches[matches.length - 1];
}

function lookLikeStream(url) {
  if (typeof url !== 'string' || !url) return false;
  return /\.m3u8/i.test(url) || url.includes('/secure/') || url.includes('/stream/');
}

/** Same linear-memory flags as decrypt.js (tuned for ref gasm.wasm). */
function applyRefFlags(memory) {
  const u8 = new Uint8Array(memory.buffer);
  const dv = new DataView(memory.buffer);
  if (u8.length <= 1070513) return;
  u8[1070512] = 3;
  u8[1070513] = 1;
  u8[1070488] = 1;
  u8[1070508] = 1;
  dv.setInt32(1070476, -2147483648, true);
  dv.setInt32(1070472, 0, true);
  dv.setInt32(1070496, -2147483648, true);
  dv.setInt32(1070492, 0, true);
}

function mountJw(onFile) {
  const jwCfg = { file: null };
  const takeFile = (cfg) => {
    const file =
      typeof cfg === 'string'
        ? cfg
        : cfg && (cfg.file || (cfg.sources && cfg.sources[0] && cfg.sources[0].file));
    if (typeof file !== 'string' || !file) return;
    jwCfg.file = file;
    if (onFile) onFile(file);
  };
  const jwEngine = { destroy() {} };
  const jwBase = {
    id: 'player',
    uniqueId: 'player',
    plugins: {},
    version: '8.38.10',
    Events: {},
    utils: {},
    _: {},
    remove() {
      return jwEngine;
    },
    setup: takeFile,
    load: takeFile,
    setConfig: takeFile,
    getConfig: () => jwCfg,
    on() {},
    play() {},
    getPlaylistItem: () => jwCfg,
    getPlaylist: () => (jwCfg.file ? [{ file: jwCfg.file }] : []),
    getState: () => 'idle',
    getContainer: () => null,
    getAudioTracks: () => [],
    getBuffer: () => 0,
    getCaptions: () => null,
    getCaptionsList: () => [],
    getControls: () => true,
    getCues: () => [],
    qoe: () => ({}),
    addCues() {},
  };
  const jwPlayer = new Proxy(jwBase, {
    get(target, prop, receiver) {
      if (Reflect.has(target, prop)) return Reflect.get(target, prop, receiver);
      if (prop === Symbol.toStringTag) return 'Object';
      return () => null;
    },
  });
  window.__wasm_jw_player = jwPlayer;
  window.__wasm_jw_engine = jwEngine;
  window.__wasm_jw_p2p_config = {
    live: true,
    token: '',
    channelId: '',
    announce: '',
    showSlogan: false,
    sharePlaylist: false,
    startFromSegmentOffset: 0,
    trickleICE: false,
  };
  window.__wasm_p2p_config = window.__wasm_jw_p2p_config;
  window.__wasm_player = { core: { mediaControl: { volume: 0 } } };
  window.P2PEngineHls = class {
    static isSupported() {
      return false;
    }
    static isMSESupported() {
      return false;
    }
  };
  window.P2pEngineHls = window.P2PEngineHls;
  window.jwplayer = () => jwPlayer;
  return jwCfg;
}

function errText(e) {
  try {
    if (e == null) return 'nullish:' + String(e);
    if (typeof e === 'string') return e.length ? e : 'empty-string';
    if (typeof e !== 'object') return typeof e + ':' + String(e);
    const msg = e.message || e.error || e.reason;
    const stack = e.stack;
    if (msg || stack) return String(stack || msg);
    try {
      return JSON.stringify(e, Object.getOwnPropertyNames(e));
    } catch (_) {
      return Object.prototype.toString.call(e);
    }
  } catch (x) {
    return 'errText-failed:' + String(x);
  }
}

async function decryptWithPair(pair, island, body, embedOrigin, path, slug) {
  const wasmUrl = assetUrl(pair.wasm) + '?t=' + Date.now();
  const jsUrl = assetUrl(pair.js) + '?t=' + Date.now();
  console.log('[ForjaGasm] pair=' + pair.name + ' js=' + pair.js);

  const wasmResp = await fetch(wasmUrl);
  if (!wasmResp.ok) throw new Error(pair.name + ': wasm HTTP ' + wasmResp.status);
  const wasmBytes = await wasmResp.arrayBuffer();

  let captured = null;
  const jwCfg = mountJw((file) => {
    if (lookLikeStream(file)) captured = file;
  });

  const origin = String(embedOrigin || '').replace(/\/+$/, '');
  const resolveEmbedUrl = (url) => {
    if (typeof url !== 'string') return url;
    if (url.startsWith('/')) return origin + url;
    return url;
  };

  const prevFetch = window.fetch;
  window.fetch = async (input) => {
    let href =
      typeof input === 'string'
        ? input
        : (input && input.url) || String(input);
    href = resolveEmbedUrl(href);
    if (lookLikeStream(href)) {
      captured = href;
      return new Response('#EXTM3U\n#EXT-X-VERSION:3\n', {
        status: 200,
        headers: { 'content-type': 'application/vnd.apple.mpegurl' },
      });
    }
    return new Response(body, {
      status: 200,
      headers: {
        'content-type': 'application/octet-stream',
        island: String(island),
      },
    });
  };

  try {
    const mod = await import(jsUrl);
    const init = mod.default || mod;
    if (typeof init !== 'function') {
      throw new Error(pair.name + ': no default init export');
    }
    const wasm = await init({ module_or_path: wasmBytes, fetch: window.fetch });
    if (!wasm) {
      throw new Error(pair.name + ': init returned empty');
    }

    if (typeof wasm.init_wasm === 'function') {
      try {
        await Promise.resolve(wasm.init_wasm());
      } catch (_) {}
    }

    if (pair.applyFlags) {
      try {
        applyRefFlags(wasm.memory);
      } catch (_) {}
    }

    const setters = [];
    if (typeof wasm.set_stream === 'function') setters.push(['set_stream', wasm.set_stream]);
    if (typeof wasm.set_stream_jw === 'function') {
      setters.push(['set_stream_jw', wasm.set_stream_jw]);
    }
    if (!setters.length) {
      throw new Error(
        pair.name +
          ': no set_stream / set_stream_jw keys=' +
          Object.keys(wasm).join(','),
      );
    }

    for (const [name, fn] of setters) {
      console.log('[ForjaGasm] ' + name + '…');
      try {
        const result = fn.call(wasm, island, body);
        await Promise.race([
          Promise.resolve(result),
          new Promise((resolve) => {
            const iv = setInterval(() => {
              if (captured || extractUrl(wasm.memory, slug)) {
                clearInterval(iv);
                resolve(null);
              }
            }, 10);
            setTimeout(() => {
              clearInterval(iv);
              resolve(null);
            }, 8000);
          }),
        ]).catch((e) => {
          console.log('[ForjaGasm] ' + name + ' settle ' + errText(e));
        });
      } catch (e) {
        console.log('[ForjaGasm] ' + name + ' throw ' + errText(e));
      }

      const streamUrl = captured || jwCfg.file || extractUrl(wasm.memory, slug);
      if (streamUrl) {
        console.log('[ForjaGasm] m3u8(' + pair.name + '/' + name + ') ' + streamUrl);
        return streamUrl;
      }
    }

    throw new Error(
      pair.name +
        ': no m3u8 (slug=' +
        (slug || '-') +
        ' mem=' +
        wasm.memory.buffer.byteLength +
        ')',
    );
  } finally {
    window.fetch = prevFetch;
  }
}

async function crack(slot, island, bodyHex, embedOrigin) {
  if (!island || !bodyHex) throw new Error('missing island or bodyHex');
  const body = hexToBytes(bodyHex);
  const path = pagePath(slot);
  if (!path) throw new Error('slot missing path');
  const slug = slugFromFetchBody(body);
  const origin = String(embedOrigin || 'https://embedindia.st').replace(
    /\/+$/,
    '',
  );

  try {
    history.replaceState(null, '', '/embed/' + path);
  } catch (e) {
    console.log('[ForjaGasm] replaceState failed ' + errText(e));
  }
  console.log(
    '[ForjaGasm] crack path=' +
      path +
      ' slug=' +
      (slug || '-') +
      ' body=' +
      body.length +
      'B href=' +
      location.href,
  );

  const errors = [];
  for (const pair of PAIRS) {
    try {
      return await decryptWithPair(pair, island, body, origin, path, slug);
    } catch (e) {
      const msg = errText(e);
      console.log('[ForjaGasm] pair fail ' + pair.name + ': ' + msg);
      errors.push(pair.name + ': ' + msg);
    }
  }
  throw new Error('gasm did not yield m3u8 — ' + errors.join(' | '));
}

window.__gasmCrackJson = async function (slotJson, island, bodyHex, embedOrigin) {
  try {
    const slot = typeof slotJson === 'string' ? JSON.parse(slotJson) : slotJson;
    const url = await crack(slot, island, bodyHex, embedOrigin);
    const payload = JSON.stringify({ ok: true, url: String(url) });
    console.log('GASM_RESULT:' + payload);
    return payload;
  } catch (e) {
    const payload = JSON.stringify({ ok: false, error: errText(e) });
    console.log('GASM_RESULT:' + payload);
    console.log('[ForjaGasm] fail ' + errText(e));
    return payload;
  }
};

window.__gasmReady = true;
console.log('[ForjaGasm] ready href=' + location.href);
