/**
 * Browser port of gasm/unlock.mjs crack() — Android/iOS WebView.
 * Page baseUrl must be https://embedindia.st/ (see LiveGasmWebviewUnlock).
 * Dart POST /fetch; this only runs set_stream_jw(island, body) + memory scrape.
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
    name: 'ref',
    js: '/vendor/gasm.js',
    wasm: '/vendor/gasm.wasm',
    applyFlags: true,
  },
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
  const re = /https:\/\/[a-z0-9.-]+\/secure\/[^\x00-\x1f\s"']+?index\.m3u8/gi;
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

function mountJw() {
  const jwEngine = { destroy() {} };
  const jwPlayer = {
    remove() {
      return jwEngine;
    },
    setup() {},
    on() {},
    load() {},
    play() {},
    getPlaylistItem: () => ({}),
    getState: () => 'idle',
  };
  window.__wasm_jw_player = jwPlayer;
  window.__wasm_jw_engine = jwEngine;
  window.__wasm_player = { core: { mediaControl: { volume: 0 } } };
  window.__wasm_p2p_config = {};
  window.P2PEngineHls = class {};
  window.jwplayer = () => jwPlayer;
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

  mountJw();

  const embedFetch = async () =>
    new Response(body, {
      status: 200,
      headers: {
        'content-type': 'application/octet-stream',
        island: String(island),
      },
    });

  const prevFetch = window.fetch;
  window.fetch = embedFetch;

  try {
    const mod = await import(jsUrl);
    const init = mod.default || mod;
    if (typeof init !== 'function') {
      throw new Error(pair.name + ': no default init export');
    }
    const wasm = await init({ module_or_path: wasmBytes, fetch: embedFetch });
    if (!wasm || typeof wasm.set_stream_jw !== 'function') {
      throw new Error(
        pair.name +
          ': set_stream_jw missing keys=' +
          Object.keys(wasm || {}).join(','),
      );
    }

    if (pair.applyFlags) {
      try {
        applyRefFlags(wasm.memory);
      } catch (_) {}
    }

    console.log('[ForjaGasm] set_stream_jw…');
    const result = wasm.set_stream_jw(island, body);
    await Promise.race([
      Promise.resolve(result),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('timeout')), 15000),
      ),
    ]).catch((e) => {
      console.log('[ForjaGasm] set_stream_jw settle ' + errText(e));
    });

    const streamUrl = extractUrl(wasm.memory, slug);
    if (!streamUrl) {
      throw new Error(
        pair.name +
          ': no m3u8 (slug=' +
          (slug || '-') +
          ' mem=' +
          wasm.memory.buffer.byteLength +
          ')',
      );
    }
    console.log('[ForjaGasm] m3u8(' + pair.name + ') ' + streamUrl);
    return streamUrl;
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
      return await decryptWithPair(
        pair,
        island,
        body,
        origin,
        path,
        slug,
      );
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
