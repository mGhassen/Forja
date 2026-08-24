/**
 * Browser port of goat/unlock.mjs crack() — runs inside Android/iOS WebView.
 * Page baseUrl must be https://embed.st/ (see LiveGoatWebviewUnlock).
 * Dart POST /fetch; this only decrypts via lock.wasm + set_stream_jw.
 *
 * Result protocol: console.log('GOAT_RESULT:' + JSON.stringify({ok,url,error}))
 */
function assetUrl(path) {
  const base = String(window.__GOAT_ASSET_BASE || '').replace(/\/+$/, '');
  if (!base) throw new Error('__GOAT_ASSET_BASE missing');
  return base + (path.startsWith('/') ? path : '/' + path);
}

const wasmBytesPromise = fetch(assetUrl('/vendor/lock.wasm')).then((r) => {
  if (!r.ok) throw new Error('lock.wasm HTTP ' + r.status);
  return r.arrayBuffer();
});

function mountJw() {
  const doc = document;
  const jwCfg = { file: null };
  const jwBase = {
    getContainer: () => doc.getElementById('player'),
    getState: () => 'idle',
    load: (cfg) => {
      if (cfg?.file) jwCfg.file = cfg.file;
    },
    setConfig: (cfg) => {
      if (cfg?.file) jwCfg.file = cfg.file;
    },
    getConfig: () => jwCfg,
    setup: () => {},
    on: () => {},
    play: () => {},
    getPlaylistItem: () => jwCfg,
    getPlaylist: () => (jwCfg.file ? [{ file: jwCfg.file }] : []),
  };
  window.__wasm_jw_player = new Proxy(jwBase, {
    get(target, prop, receiver) {
      if (Reflect.has(target, prop)) return Reflect.get(target, prop, receiver);
      if (prop === Symbol.toStringTag) return 'Object';
      return () => null;
    },
  });
  window.jwplayer = () => window.__wasm_jw_player;
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

function mockFetch(goat, body, onM3u8, wasmBytes) {
  return async (input) => {
    const href =
      typeof input === 'string' ? input : input?.url ?? String(input);
    if (href.includes('lock.wasm')) {
      return new Response(wasmBytes.slice(0), {
        status: 200,
        headers: { 'Content-Type': 'application/wasm' },
      });
    }
    if (href.includes('/fetch')) {
      return new Response(body, {
        status: 200,
        headers: {
          goat: String(goat),
          'Content-Type': 'application/octet-stream',
        },
      });
    }
    if (href.includes('.m3u8')) {
      onM3u8(href);
      return new Response('#EXTM3U\n#EXT-X-VERSION:3\n', {
        status: 200,
        headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
      });
    }
    return new Response('', { status: 404 });
  };
}

function patchImports(imports, goat, body, onM3u8) {
  const bg = imports?.['./locked_bg.js'];
  if (!bg) {
    console.log('[ForjaGoat] no ./locked_bg.js in imports keys=' + Object.keys(imports || {}));
    return;
  }
  for (const key of Object.keys(bg)) {
    if (!key.includes('instanceof')) continue;
    const orig = bg[key];
    bg[key] = (...args) => (orig(...args) ? 1 : 1);
  }
  const fetchKey = Object.keys(bg).find((k) => k.includes('fetch_e6e8e0'));
  if (!fetchKey) {
    console.log('[ForjaGoat] no fetch import keys=' + Object.keys(bg).slice(0, 12));
    return;
  }
  bg[fetchKey] = (_win, req) => {
    const href = req?.url ?? '';
    if (href.includes('/fetch')) {
      return Promise.resolve(
        new Response(body, {
          status: 200,
          headers: {
            goat: String(goat),
            'Content-Type': 'application/octet-stream',
          },
        }),
      );
    }
    if (href.includes('.m3u8')) {
      onM3u8(href);
      return Promise.resolve(
        new Response('#EXTM3U\n#EXT-X-VERSION:3\n', {
          status: 200,
          headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
        }),
      );
    }
    return Promise.reject(new Error('unexpected wasm fetch ' + href));
  };
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

async function crack(slot, goat, bodyHex, embedOrigin) {
  const source = String(slot?.source ?? '');
  const id = String(slot?.id ?? '');
  const stream = String(slot?.stream ?? '1');
  if (!source || !id) throw new Error('slot missing source/id');

  const origin = String(embedOrigin || 'https://embed.st').replace(/\/+$/, '');
  const embedPath = '/embed/' + source + '/' + id + '/' + stream;
  try {
    history.replaceState(null, '', embedPath);
  } catch (e) {
    console.log('[ForjaGoat] replaceState failed ' + errText(e));
  }
  console.log('[ForjaGoat] crack ' + source + '/' + id + '/' + stream + ' href=' + location.href);

  // Module-level capture: lock-browser caches wasm after first initLock; a
  // reused page can fire the *previous* import patch (log only). Prefer local
  // m3u8; fall back to window only within this crack. Dart reloads the page
  // between unlocks so initLock is fresh.
  let m3u8 = null;
  window.__forjaGoatM3u8 = null;
  const capture = (url, via) => {
    m3u8 = url;
    window.__forjaGoatM3u8 = url;
    console.log('[ForjaGoat] m3u8(' + via + ') ' + url);
  };
  const body = hexToBytes(bodyHex);
  const wasmBytes = await wasmBytesPromise;
  console.log('[ForjaGoat] wasm ' + wasmBytes.byteLength + 'B body ' + body.length + 'B');
  mountJw();

  const fetchFn = mockFetch(
    goat,
    body,
    (url) => capture(url, 'fetch'),
    wasmBytes,
  );
  const prevFetch = window.fetch;
  window.fetch = fetchFn;

  const origInstantiate = WebAssembly.instantiate.bind(WebAssembly);
  WebAssembly.instantiate = async (sourceArg, imports) => {
    patchImports(imports, goat, body, (url) => capture(url, 'import'));
    let bytes = sourceArg;
    if (!(bytes instanceof ArrayBuffer) && !ArrayBuffer.isView(bytes)) {
      bytes = wasmBytes.slice(0);
    }
    return origInstantiate(bytes, imports);
  };
  WebAssembly.instantiateStreaming = async (_resp, imports) =>
    WebAssembly.instantiate(wasmBytes.slice(0), imports);

  try {
    // Dynamic import + cache-bust: document reload alone can keep a stale
    // wasm-bindgen module (initLock no-ops → old import patch).
    const lockUrl = assetUrl('/vendor/lock-browser.mjs') + '?t=' + Date.now();
    console.log('[ForjaGoat] initLock…');
    const lockMod = await import(lockUrl);
    const initLock = lockMod.default || lockMod.initSync || lockMod;
    const api = await initLock({
      module_or_path: origin + '/js/wasm/lock.wasm?t=' + Date.now(),
      fetch: fetchFn,
    });
    console.log('[ForjaGoat] init_wasm keys=' + Object.keys(api || {}).join(','));
    if (typeof api?.init_wasm === 'function') await api.init_wasm();
    console.log('[ForjaGoat] set_stream_jw…');
    try {
      if (typeof api?.set_stream_jw !== 'function') {
        throw new Error('api.set_stream_jw missing keys=' + Object.keys(api || {}));
      }
      const ret = api.set_stream_jw(source, id, stream);
      console.log('[ForjaGoat] set_stream_jw typeof ret=' + typeof ret);
      // Reflect.get often throws *after* m3u8 is already captured — race settle.
      await Promise.race([
        Promise.resolve(ret),
        new Promise((resolve) => {
          const iv = setInterval(() => {
            if (m3u8 || window.__forjaGoatM3u8) {
              clearInterval(iv);
              resolve(null);
            }
          }, 10);
          setTimeout(() => {
            clearInterval(iv);
            resolve(null);
          }, 8000);
        }),
      ]);
      console.log('[ForjaGoat] set_stream_jw settled m3u8=' + !!(m3u8 || window.__forjaGoatM3u8));
    } catch (err) {
      console.log('[ForjaGoat] set_stream_jw catch ' + errText(err));
      if (!m3u8 && !window.__forjaGoatM3u8) {
        throw err || new Error('set_stream_jw failed nullish');
      }
      console.log('[ForjaGoat] set_stream_jw threw but m3u8 ok');
    }
    const out = m3u8 || window.__forjaGoatM3u8;
    if (!out) throw new Error('lock did not yield m3u8');
    return out;
  } finally {
    WebAssembly.instantiate = origInstantiate;
    try {
      delete WebAssembly.instantiateStreaming;
    } catch (_) {}
    window.fetch = prevFetch;
  }
}

window.__goatCrackJson = async function (slotJson, goat, bodyHex, embedOrigin) {
  try {
    const slot = typeof slotJson === 'string' ? JSON.parse(slotJson) : slotJson;
    const url = await crack(slot, goat, bodyHex, embedOrigin);
    const payload = JSON.stringify({ ok: true, url: String(url) });
    console.log('GOAT_RESULT:' + payload);
    return payload;
  } catch (e) {
    const payload = JSON.stringify({ ok: false, error: errText(e) });
    console.log('GOAT_RESULT:' + payload);
    console.log('[ForjaGoat] fail ' + errText(e));
    return payload;
  }
};

window.__goatReady = true;
console.log('[ForjaGoat] ready href=' + location.href);
