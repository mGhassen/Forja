//! Run one plugin `extract(ctx)` in a fresh rquickjs AsyncRuntime.

use std::collections::HashMap;
use std::io::Read;
use std::time::Duration;

use base64::Engine as _;
use flate2::read::{DeflateDecoder, GzDecoder, ZlibDecoder};
use rquickjs::{
    async_with, function::Async, AsyncContext, AsyncRuntime, CatchResultExt, Ctx, Function,
    Promise,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

/// Same key as `crates/archive/anime/src/extractors/miruro.rs` PIPE_OBF_KEY.
const PIPE_OBF_KEY: [u8; 16] = [
    0x71, 0x95, 0x10, 0x34, 0xf8, 0xfb, 0xcf, 0x53, 0xd8, 0x9d, 0xb5, 0x2c, 0xeb, 0x3d, 0xc2, 0x2c,
];

fn cancelled() -> bool {
    utils::engine_cancel::cancellation_token().is_cancelled()
        || utils::engine_cancel::is_shutdown_requested()
}

fn encode_pipe(json: String) -> String {
    if json.is_empty() {
        return String::new();
    }
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(json.as_bytes())
}

fn decode_pipe(body: String, x_obf: String) -> String {
    if body.is_empty() {
        return String::new();
    }
    let level = x_obf.trim();
    if level.is_empty() {
        if serde_json::from_str::<Value>(&body).is_ok() {
            return body;
        }
        return inflate_pipe_body(&body, false);
    }
    inflate_pipe_body(&body, level == "2")
}

fn inflate_pipe_body(body: &str, xor: bool) -> String {
    let mut b64 = body.replace('-', "+").replace('_', "/");
    let pad = b64.len() % 4;
    if pad != 0 {
        b64.push_str(&"=".repeat(4 - pad));
    }
    let Ok(mut data) = base64::engine::general_purpose::STANDARD.decode(b64) else {
        return String::new();
    };
    if xor {
        for (i, b) in data.iter_mut().enumerate() {
            *b ^= PIPE_OBF_KEY[i % PIPE_OBF_KEY.len()];
        }
    }
    let plain = String::from_utf8_lossy(&decompress(&data)).into_owned();
    if serde_json::from_str::<Value>(&plain).is_ok() {
        plain
    } else {
        String::new()
    }
}

fn decompress(data: &[u8]) -> Vec<u8> {
    if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
        let mut dec = GzDecoder::new(data);
        let mut out = Vec::new();
        if dec.read_to_end(&mut out).is_ok() {
            return out;
        }
    }
    {
        let mut dec = ZlibDecoder::new(data);
        let mut out = Vec::new();
        if dec.read_to_end(&mut out).is_ok() {
            return out;
        }
    }
    let mut prefixed = vec![0x78, 0x01];
    prefixed.extend_from_slice(data);
    let mut dec = DeflateDecoder::new(&prefixed[..]);
    let mut out = Vec::new();
    if dec.read_to_end(&mut out).is_ok() {
        return out;
    }
    data.to_vec()
}

#[derive(Debug, Clone, Deserialize)]
pub struct HopScript {
    pub id: String,
    #[serde(default)]
    pub hosts: Vec<String>,
    pub code: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ExtractRequest {
    pub plugin_id: String,
    pub code: String,
    pub ctx: Value,
    #[serde(default = "default_timeout_ms")]
    pub timeout_ms: u64,
    #[serde(default)]
    pub allow_host_fallback: bool,
    /// Hop plugins (`kind: hop`) for `ctx.hop(url)`.
    #[serde(default)]
    pub hops: Vec<HopScript>,
    /// Nesting depth for `ctx.hop` (max 3, same as Dart EngineRuntime).
    #[serde(default)]
    pub hop_depth: u32,
}

fn default_timeout_ms() -> u64 {
    60_000
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtractResult {
    pub streams: Vec<Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub unsupported: Option<bool>,
    /// Plugin called `ctx.host(id)` with no streams; optional app host fallback may run.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub needs_host: Option<String>,
}

const HOST_JS: &str = r#"
(function(){
  globalThis.__engineRegistry = globalThis.__engineRegistry || {};
  globalThis.fetch = function(url, options){
    options = options || {};
    var method = (options.method || 'GET').toString().toUpperCase();
    var headers = options.headers || {};
    var bodyOut = '';
    if (options.body != null) {
      bodyOut = typeof options.body === 'string' ? options.body : String(options.body);
    }
    return __native_fetch(String(url), method, JSON.stringify(headers), bodyOut).then(function(raw){
      var env = {};
      try { env = JSON.parse(raw || '{}'); } catch (e) { env = { ok:false, status:0, body:'', headers:{} }; }
      var lowered = {};
      if (env.headers) for (var k in env.headers) if (Object.prototype.hasOwnProperty.call(env.headers, k))
        lowered[String(k).toLowerCase()] = String(env.headers[k]);
      var body = env.body == null ? '' : String(env.body);
      return {
        ok: !!env.ok,
        status: env.status | 0,
        statusText: env.statusText || '',
        url: env.url || url,
        headers: { get: function(name){ return lowered[String(name).toLowerCase()] || null; } },
        text: function(){ return Promise.resolve(body); },
        json: function(){
          try { return Promise.resolve(body ? JSON.parse(body) : null); }
          catch (e) { return Promise.resolve(null); }
        }
      };
    });
  };
  // Chrome TLS fingerprint (JA3) — for CDNs that 403 plain reqwest (Dailymotion cdndirector, …).
  globalThis.__engineChromeFetch = function(url, options){
    options = options || {};
    var method = (options.method || 'GET').toString().toUpperCase();
    var headers = options.headers || {};
    var bodyOut = '';
    if (options.body != null) {
      bodyOut = typeof options.body === 'string' ? options.body : String(options.body);
    }
    return __native_chrome_fetch(String(url), method, JSON.stringify(headers), bodyOut).then(function(raw){
      var env = {};
      try { env = JSON.parse(raw || '{}'); } catch (e) { env = { ok:false, status:0, body:'', headers:{} }; }
      var lowered = {};
      if (env.headers) for (var k in env.headers) if (Object.prototype.hasOwnProperty.call(env.headers, k))
        lowered[String(k).toLowerCase()] = String(env.headers[k]);
      var body = env.body == null ? '' : String(env.body);
      return {
        ok: !!env.ok,
        status: env.status | 0,
        statusText: env.statusText || '',
        url: env.url || url,
        headers: { get: function(name){ return lowered[String(name).toLowerCase()] || null; } },
        text: function(){ return Promise.resolve(body); },
        json: function(){
          try { return Promise.resolve(body ? JSON.parse(body) : null); }
          catch (e) { return Promise.resolve(null); }
        }
      };
    });
  };
  globalThis.setTimeout = function(fn, ms){
    var args = Array.prototype.slice.call(arguments, 2);
    return __native_set_timeout(ms|0, function(){
      try { (typeof fn === 'function' ? fn : function(){}).apply(null, args); } catch (e) {}
    });
  };
  globalThis.clearTimeout = function(id){ __native_clear_timeout(id|0); };
  globalThis.setInterval = function(fn, ms){
    var args = Array.prototype.slice.call(arguments, 2);
    return __native_set_interval(ms|0, function(){
      try { (typeof fn === 'function' ? fn : function(){}).apply(null, args); } catch (e) {}
    });
  };
  globalThis.clearInterval = globalThis.clearTimeout;
  globalThis.console = {
    log: function(){ __native_log([].slice.call(arguments).join(' ')); },
    error: function(){ __native_log('[err] '+[].slice.call(arguments).join(' ')); },
    warn: function(){ __native_log('[warn] '+[].slice.call(arguments).join(' ')); }
  };
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
  if (typeof TextEncoder === 'undefined') {
    globalThis.TextEncoder = function TextEncoder() {};
    TextEncoder.prototype.encode = function(str) {
      str = String(str);
      var out = [];
      for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i);
        if (c < 0x80) out.push(c);
        else if (c < 0x800) {
          out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
        } else if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
          var c2 = str.charCodeAt(++i);
          var u = 0x10000 + ((c & 0x3ff) << 10) + (c2 & 0x3ff);
          out.push(
            0xf0 | (u >> 18),
            0x80 | ((u >> 12) & 0x3f),
            0x80 | ((u >> 6) & 0x3f),
            0x80 | (u & 0x3f)
          );
        } else {
          out.push(
            0xe0 | (c >> 12),
            0x80 | ((c >> 6) & 0x3f),
            0x80 | (c & 0x3f)
          );
        }
      }
      return new Uint8Array(out);
    };
  }
  if (typeof URLSearchParams === 'undefined') {
    globalThis.URLSearchParams = function(init){
      this._params = {};
      var self = this;
      if (init && typeof init === 'object' && !Array.isArray(init)) {
        Object.keys(init).forEach(function(k){ self._params[k] = String(init[k]); });
      } else if (typeof init === 'string') {
        String(init).replace(/^\?/, '').split('&').forEach(function(pair){
          if (!pair) return;
          var i = pair.indexOf('=');
          var k = i < 0 ? pair : pair.substring(0, i);
          var v = i < 0 ? '' : pair.substring(i + 1);
          try { self._params[decodeURIComponent(k)] = decodeURIComponent(v); }
          catch (e) { self._params[k] = v; }
        });
      }
    };
    URLSearchParams.prototype.toString = function(){
      var self = this;
      return Object.keys(this._params).map(function(k){
        return encodeURIComponent(k) + '=' + encodeURIComponent(self._params[k]);
      }).join('&');
    };
    URLSearchParams.prototype.get = function(k){ return Object.prototype.hasOwnProperty.call(this._params, k) ? this._params[k] : null; };
    URLSearchParams.prototype.set = function(k, v){ this._params[k] = String(v); };
    URLSearchParams.prototype.append = function(k, v){ this._params[k] = String(v); };
    URLSearchParams.prototype.has = function(k){ return Object.prototype.hasOwnProperty.call(this._params, k); };
    URLSearchParams.prototype.delete = function(k){ delete this._params[k]; };
  }
  if (typeof URL === 'undefined') {
    globalThis.URL = function(urlString, base){
      var fullUrl = String(urlString == null ? '' : urlString);
      if (base && !/^[a-z][a-z0-9+\-.]*:\/\//i.test(fullUrl)) {
        var b = typeof base === 'string' ? base : (base && base.href ? base.href : '');
        if (fullUrl.charAt(0) === '/') {
          var origin = b.match(/^([a-z][a-z0-9+\-.]*:\/\/[^\/]*)/i);
          fullUrl = origin ? origin[1] + fullUrl : fullUrl;
        } else {
          fullUrl = String(b).replace(/\/[^\/]*$/, '/') + fullUrl;
        }
      }
      var m = fullUrl.match(/^([a-z][a-z0-9+\-.]*:)\/\/([^\/?#]*)([^?#]*)(\?[^#]*)?(#.*)?$/i);
      if (!m) throw new TypeError('Invalid URL');
      var hostPart = m[2] || '';
      var at = hostPart.lastIndexOf('@');
      if (at >= 0) hostPart = hostPart.substring(at + 1);
      var hostname = hostPart;
      var port = '';
      if (hostPart.charAt(0) === '[') {
        var end = hostPart.indexOf(']');
        hostname = end >= 0 ? hostPart.substring(0, end + 1) : hostPart;
        port = end >= 0 && hostPart.charAt(end + 1) === ':' ? hostPart.substring(end + 2) : '';
      } else {
        var colon = hostPart.lastIndexOf(':');
        if (colon >= 0) {
          hostname = hostPart.substring(0, colon);
          port = hostPart.substring(colon + 1);
        }
      }
      this.href = fullUrl;
      this.protocol = m[1].toLowerCase();
      this.host = hostPart;
      this.hostname = hostname;
      this.port = port;
      this.pathname = m[3] || '/';
      this.search = m[4] || '';
      this.hash = m[5] || '';
      this.origin = this.protocol + '//' + this.host;
      this.searchParams = new URLSearchParams(this.search);
    };
    URL.prototype.toString = function(){ return this.href; };
  }
  globalThis.__engineHtml = function(html){
    if (!globalThis.__engineCheerio || typeof globalThis.__engineCheerio.load !== 'function') {
      try { __native_ensure_cheerio(); } catch (e) {}
    }
    var c = globalThis.__engineCheerio;
    if (!c || typeof c.load !== 'function') throw new Error('UNSUPPORTED:cheerio');
    return c.load(String(html == null ? '' : html));
  };
  globalThis.__engineHop = function(url){
    return __native_hop(String(url == null ? '' : url)).then(function(raw){
      try { var v = JSON.parse(raw || '[]'); return Array.isArray(v) ? v : []; }
      catch (e) { return []; }
    });
  };
  globalThis.__engineHost = function(hostId){
    try { __native_request_host(String(hostId == null ? '' : hostId)); } catch (e) {}
    return Promise.resolve([]);
  };
  globalThis.__engineAudioCategories = function(ctx) {
    var c = String(
      (ctx && ctx.category) ||
        (ctx && ctx.config && ctx.config.category) ||
        '',
    )
      .trim()
      .toLowerCase();
    if (c === 'sub' || c === 'dub') return [c];
    return ['sub', 'dub'];
  };
})();
"#;

const CRYPTO_JS: &str = include_str!("crypto_js_polyfill.js");
const STREAMCRYPTO_JS: &str = include_str!("../../../plugins/providers/_streamcrypto.js");
const CHEERIO_BUNDLE: &str =
    include_str!("../../../apps/forja/assets/nuvio/cheerio.bundle.js");

fn cheerio_load_js() -> String {
    format!(
        r#"(function(){{
  var module = {{ exports: {{}} }};
  var exports = module.exports;
  try {{
    {bundle}
    var c = (module.exports && Object.keys(module.exports).length > 0)
      ? module.exports
      : (typeof cheerio !== 'undefined' ? cheerio : null);
    if (c && typeof c.load === 'function') globalThis.__engineCheerio = c;
  }} catch (e) {{
    console.error('[engine] cheerio load failed: ' + (e && e.message ? e.message : e));
  }}
}})();"#,
        bundle = CHEERIO_BUNDLE
    )
}

fn url_host(url: &str) -> Option<String> {
    let after = url.trim().split("://").nth(1)?;
    let hostport = after.split(['/', '?', '#']).next()?;
    let host = hostport.split('@').next_back()?;
    let host = host.split(':').next()?;
    let h = host.trim().to_lowercase();
    if h.is_empty() {
        None
    } else {
        Some(h)
    }
}

fn hop_plugin_for_url<'a>(url: &str, hops: &'a [HopScript]) -> Option<&'a HopScript> {
    let host = url_host(url)?;
    for h in hops {
        for cand in &h.hosts {
            let n = cand.trim().to_lowercase();
            if n.is_empty() {
                continue;
            }
            if host == n || host.ends_with(&format!(".{n}")) {
                return Some(h);
            }
        }
    }
    None
}

async fn run_hop(
    url: String,
    hops: std::sync::Arc<Vec<HopScript>>,
    parent_meta: std::sync::Arc<Value>,
    hop_depth: u32,
) -> String {
    if cancelled() || hop_depth >= 3 || url.trim().is_empty() {
        return "[]".into();
    }
    let Some(hop) = hop_plugin_for_url(&url, &hops) else {
        return "[]".into();
    };
    let mut meta = (*parent_meta).clone();
    if let Some(obj) = meta.as_object_mut() {
        obj.insert("url".into(), Value::String(url));
    }
    let result = Box::pin(extract(ExtractRequest {
        plugin_id: hop.id.clone(),
        code: hop.code.clone(),
        ctx: meta,
        timeout_ms: 20_000,
        allow_host_fallback: true,
        hops: (*hops).clone(),
        hop_depth: hop_depth + 1,
    }))
    .await;
    serde_json::to_string(&result.streams).unwrap_or_else(|_| "[]".into())
}

fn fetch_cancelled_json(url: &str) -> String {
    serde_json::json!({
        "ok": false, "status": 0, "statusText": "cancelled",
        "url": url, "body": "", "headers": {}
    })
    .to_string()
}

async fn native_tmdb_match(payload: String) -> rquickjs::Result<String> {
    if cancelled() {
        return Ok("null".into());
    }
    let out = tokio::task::spawn_blocking(move || tmdb::match_json(&payload))
        .await
        .unwrap_or_else(|_| "null".into());
    Ok(out)
}

async fn native_chrome_fetch(
    url: String,
    method: String,
    headers_json: String,
    body: String,
) -> rquickjs::Result<String> {
    Ok(crate::chrome_fetch::chrome_fetch(url, method, headers_json, body).await)
}

async fn native_fetch(
    url: String,
    method: String,
    headers_json: String,
    body: String,
) -> rquickjs::Result<String> {
    if cancelled() {
        return Ok(fetch_cancelled_json(&url));
    }
    let headers: HashMap<String, String> =
        serde_json::from_str(&headers_json).unwrap_or_default();
    let client = match reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .timeout(Duration::from_secs(25))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            return Ok(serde_json::json!({
                "ok": false, "status": 0, "statusText": e.to_string(),
                "url": url, "body": "", "headers": {}
            })
            .to_string());
        }
    };
    let mut req = match method.to_uppercase().as_str() {
        "POST" => client.post(&url),
        "PUT" => client.put(&url),
        "PATCH" => client.patch(&url),
        "DELETE" => client.delete(&url),
        _ => client.get(&url),
    };
    for (k, v) in &headers {
        req = req.header(k, v);
    }
    if !body.is_empty() && method.to_uppercase() != "GET" {
        req = req.body(body);
    }
    let token = utils::engine_cancel::cancellation_token();
    let resp = tokio::select! {
        r = req.send() => match r {
            Ok(r) => r,
            Err(e) => {
                return Ok(serde_json::json!({
                    "ok": false, "status": 0, "statusText": e.to_string(),
                    "url": url, "body": "", "headers": {}
                })
                .to_string());
            }
        },
        _ = token.cancelled() => return Ok(fetch_cancelled_json(&url)),
    };
    let status = resp.status().as_u16();
    let final_url = resp.url().to_string();
    let mut hdrs = serde_json::Map::new();
    for (k, v) in resp.headers().iter() {
        if let Ok(s) = v.to_str() {
            hdrs.insert(k.to_string(), Value::String(s.to_string()));
        }
    }
    let text = tokio::select! {
        t = resp.text() => t.unwrap_or_default(),
        _ = token.cancelled() => return Ok(fetch_cancelled_json(&url)),
    };
    Ok(serde_json::json!({
        "ok": status >= 200 && status < 300,
        "status": status,
        "statusText": "",
        "url": final_url,
        "body": text,
        "headers": hdrs
    })
    .to_string())
}

fn solve_pow(challenge: String, difficulty: i32, max: i32) -> String {
    if challenge.is_empty() || !(0..=8).contains(&difficulty) {
        return String::new();
    }
    let cap = max.clamp(1, 5_000_000) as u32;
    let prefix = "0".repeat(difficulty as usize);
    for n in 0..cap {
        if cancelled() {
            return String::new();
        }
        let h = format!("{:x}", Sha256::digest(format!("{challenge}{n}").as_bytes()));
        if h.starts_with(&prefix) {
            return serde_json::json!({ "challenge": challenge, "nonce": n.to_string() })
                .to_string();
        }
    }
    String::new()
}

/// Consumet-compatible KissKh Episode/Sub `kkey` (same as Dart/flutter_js host).
fn kisskh_kkey(episode_id: i32, kind: String) -> String {
    if episode_id <= 0 {
        return String::new();
    }
    let k = if kind == "sub" || kind == "subtitle" {
        crate::kisskh_kkey::KkeyKind::Subtitle
    } else {
        crate::kisskh_kkey::KkeyKind::Video
    };
    crate::kisskh_kkey::generate_kkey(episode_id, k)
}

pub async fn extract(req: ExtractRequest) -> ExtractResult {
    let timeout = Duration::from_millis(req.timeout_ms.max(1_000));
    let token = utils::engine_cancel::cancellation_token();
    tokio::select! {
        r = tokio::time::timeout(timeout, extract_inner(req)) => match r {
            Ok(r) => r,
            Err(_) => ExtractResult {
                streams: vec![],
                error: Some("engine timed out".into()),
                unsupported: None,
                needs_host: None,
            },
        },
        _ = token.cancelled() => ExtractResult {
            streams: vec![],
            error: Some("cancelled".into()),
            unsupported: None,
            needs_host: None,
        },
    }
}

async fn extract_inner(req: ExtractRequest) -> ExtractResult {
    if cancelled() {
        return ExtractResult {
            streams: vec![],
            error: Some("cancelled".into()),
            unsupported: None,
            needs_host: None,
        };
    }

    let rt = match AsyncRuntime::new() {
        Ok(r) => r,
        Err(e) => {
            return ExtractResult {
                streams: vec![],
                error: Some(format!("AsyncRuntime: {e}")),
                unsupported: Some(true),
                needs_host: None,
            };
        }
    };
    let ctx = match AsyncContext::full(&rt).await {
        Ok(c) => c,
        Err(e) => {
            return ExtractResult {
                streams: vec![],
                error: Some(format!("AsyncContext: {e}")),
                unsupported: Some(true),
                needs_host: None,
            };
        }
    };

    let plugin_id = req.plugin_id.clone();
    let code = req.code.clone();
    let meta = req.ctx.clone();
    let plugin_label = plugin_id.clone();
    let hops = std::sync::Arc::new(req.hops.clone());
    let hop_depth = req.hop_depth;
    let allow_host = req.allow_host_fallback;

    let result = async_with!(ctx => |ctx| {
        run_in_ctx(ctx, plugin_id, code, meta, plugin_label, hops, hop_depth, allow_host).await
    })
    .await;

    let _ = rt.idle().await;

    match result {
        Ok((streams, needs_host)) => {
            let needs_host = if streams.is_empty() { needs_host } else { None };
            ExtractResult {
                streams,
                error: None,
                unsupported: None,
                needs_host,
            }
        }
        Err(e) => {
            let msg = e.to_string();
            let unsupported = msg.contains("UNSUPPORTED:");
            ExtractResult {
                streams: vec![],
                error: Some(msg),
                unsupported: if unsupported { Some(true) } else { None },
                needs_host: None,
            }
        }
    }
}

async fn run_in_ctx<'js>(
    ctx: Ctx<'js>,
    plugin_id: String,
    code: String,
    meta: Value,
    plugin_label: String,
    hops: std::sync::Arc<Vec<HopScript>>,
    hop_depth: u32,
    allow_host: bool,
) -> Result<(Vec<Value>, Option<String>), String> {
    let fetch_fn = Function::new(ctx.clone(), Async(native_fetch))
        .map_err(|e| e.to_string())?
        .with_name("__native_fetch")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_fetch", fetch_fn)
        .map_err(|e| e.to_string())?;

    let chrome_fetch_fn = Function::new(ctx.clone(), Async(native_chrome_fetch))
        .map_err(|e| e.to_string())?
        .with_name("__native_chrome_fetch")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_chrome_fetch", chrome_fetch_fn)
        .map_err(|e| e.to_string())?;

    let tmdb_match_fn = Function::new(ctx.clone(), Async(native_tmdb_match))
        .map_err(|e| e.to_string())?
        .with_name("__native_tmdb_match")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_tmdb_match", tmdb_match_fn)
        .map_err(|e| e.to_string())?;

    let pow_fn = Function::new(ctx.clone(), solve_pow)
        .map_err(|e| e.to_string())?
        .with_name("__native_solve_pow")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_solve_pow", pow_fn)
        .map_err(|e| e.to_string())?;

    let encode_pipe_fn = Function::new(ctx.clone(), encode_pipe)
        .map_err(|e| e.to_string())?
        .with_name("__native_encode_pipe")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_encode_pipe", encode_pipe_fn)
        .map_err(|e| e.to_string())?;

    let decode_pipe_fn = Function::new(ctx.clone(), decode_pipe)
        .map_err(|e| e.to_string())?
        .with_name("__native_decode_pipe")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_decode_pipe", decode_pipe_fn)
        .map_err(|e| e.to_string())?;

    let kisskh_kkey_fn = Function::new(ctx.clone(), kisskh_kkey)
        .map_err(|e| e.to_string())?
        .with_name("__native_kisskh_kkey")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_kisskh_kkey", kisskh_kkey_fn)
        .map_err(|e| e.to_string())?;

    let log_fn = Function::new(ctx.clone(), |msg: String| {
        eprintln!("[engine] {msg}");
    })
    .map_err(|e| e.to_string())?
    .with_name("__native_log")
    .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_log", log_fn)
        .map_err(|e| e.to_string())?;

    ctx.globals()
        .set(
            "__native_crypto_aes",
            Function::new(ctx.clone(), |payload: String| {
                crate::crypto_host::aes_bridge_json(&payload)
            })
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set(
            "__native_crypto_digest",
            Function::new(ctx.clone(), |payload: String| {
                crate::crypto_host::digest_bridge_json(&payload)
            })
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set(
            "__native_crypto_hmac",
            Function::new(ctx.clone(), |payload: String| {
                crate::crypto_host::hmac_bridge_json(&payload)
            })
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set(
            "__native_crypto_utf8_to_hex",
            Function::new(ctx.clone(), |data: String| {
                crate::crypto_host::utf8_to_hex(&data)
            })
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set(
            "__native_crypto_hex_to_utf8",
            Function::new(ctx.clone(), |hex: String| {
                crate::crypto_host::hex_to_utf8(&hex)
            })
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set(
            "__native_solve_scrypt_pow",
            Function::new(ctx.clone(), |payload: String| {
                crate::scrypt_pow::solve_scrypt_pow_json(&payload)
            })
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;

    let host_req: std::sync::Arc<std::sync::Mutex<Option<String>>> =
        std::sync::Arc::new(std::sync::Mutex::new(None));
    {
        let host_req = host_req.clone();
        ctx.globals()
            .set(
                "__native_request_host",
                Function::new(ctx.clone(), move |host_id: String| {
                    if !allow_host {
                        return;
                    }
                    let id = host_id.trim().to_string();
                    if id.is_empty() {
                        return;
                    }
                    if let Ok(mut g) = host_req.lock() {
                        *g = Some(id);
                    }
                })
                .map_err(|e| e.to_string())?,
            )
            .map_err(|e| e.to_string())?;
    }

    let cheerio_loaded = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    {
        let cheerio_loaded = cheerio_loaded.clone();
        ctx.globals()
            .set(
                "__native_ensure_cheerio",
                Function::new(ctx.clone(), move |ctx: Ctx<'js>| -> rquickjs::Result<()> {
                    if cheerio_loaded.load(std::sync::atomic::Ordering::Relaxed) {
                        return Ok(());
                    }
                    let script = cheerio_load_js();
                    ctx.eval::<(), _>(script.as_str())?;
                    cheerio_loaded.store(true, std::sync::atomic::Ordering::Relaxed);
                    Ok(())
                })
                .map_err(|e| e.to_string())?,
            )
            .map_err(|e| e.to_string())?;
    }

    let hops_for_fn = hops.clone();
    let meta_for_hop = std::sync::Arc::new(meta.clone());
    let hop_fn = Function::new(
        ctx.clone(),
        Async({
            let hops_for_fn = hops_for_fn.clone();
            let meta_for_hop = meta_for_hop.clone();
            move |url: String| {
                let hops_for_fn = hops_for_fn.clone();
                let meta_for_hop = meta_for_hop.clone();
                async move { run_hop(url, hops_for_fn, meta_for_hop, hop_depth).await }
            }
        }),
    )
    .map_err(|e| e.to_string())?
    .with_name("__native_hop")
    .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_hop", hop_fn)
        .map_err(|e| e.to_string())?;

    let set_timeout = Function::new(
        ctx.clone(),
        |ctx: Ctx<'js>, ms: u32, cb: Function<'js>| -> rquickjs::Result<u32> {
            ctx.clone().spawn(async move {
                tokio::time::sleep(Duration::from_millis(ms as u64)).await;
                let _ = cb.call::<(), ()>(());
            });
            Ok(1)
        },
    )
    .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_set_timeout", set_timeout)
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set(
            "__native_clear_timeout",
            Function::new(ctx.clone(), |_id: u32| ()).map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    let set_interval = Function::new(
        ctx.clone(),
        |ctx: Ctx<'js>, ms: u32, cb: Function<'js>| -> rquickjs::Result<u32> {
            ctx.clone().spawn(async move {
                loop {
                    tokio::time::sleep(Duration::from_millis(ms as u64)).await;
                    if cb.call::<(), ()>(()).is_err() {
                        break;
                    }
                }
            });
            Ok(1)
        },
    )
    .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_set_interval", set_interval)
        .map_err(|e| e.to_string())?;

    ctx.eval::<(), _>(HOST_JS)
        .catch(&ctx)
        .map_err(|e| e.to_string())?;
    ctx.eval::<(), _>(CRYPTO_JS)
        .catch(&ctx)
        .map_err(|e| e.to_string())?;
    ctx.eval::<(), _>(STREAMCRYPTO_JS)
        .catch(&ctx)
        .map_err(|e| e.to_string())?;

    let load = format!(
        r#"(function(){{
  var module = {{ exports: {{}} }};
  var exports = module.exports;
  globalThis.extract = undefined;
  {code}
  if (typeof extract === 'function') {{
    if (typeof module.exports.extract !== 'function') module.exports.extract = extract;
    if (typeof globalThis.extract !== 'function') globalThis.extract = extract;
  }}
  var fn = (module.exports && module.exports.extract) || globalThis.extract;
  globalThis.__engineRegistry[{pid}] = {{ extract: fn }};
}})();"#,
        code = code,
        pid = serde_json::to_string(&plugin_id).unwrap(),
    );
    ctx.eval::<(), _>(load.as_str())
        .catch(&ctx)
        .map_err(|e| e.to_string())?;

    let meta_json = serde_json::to_string(&meta).unwrap_or_else(|_| "{}".into());
    let invoker = format!(
        r#"
(async function(){{
  var entry = globalThis.__engineRegistry[{pid}];
  var fn = entry && entry.extract;
  if (typeof fn !== 'function') return JSON.stringify([]);
  var meta = {meta};
  var pluginLabel = {label};
  var streamDecrypt = function(body, seed, tmdbId) {{
    var fn = globalThis.__engineStreamDecrypt;
    if (typeof fn !== 'function') throw new Error('STREAMCRYPTO: not loaded');
    return fn(
      String(body == null ? '' : body),
      String(seed == null ? '' : seed),
      String(tmdbId == null ? '' : tmdbId),
    );
  }};
  var ctx = {{
    tmdbId: meta.tmdbId,
    imdbId: meta.imdbId || '',
    malId: meta.malId || '',
    anilistId: meta.anilistId || '',
    mappedEpisode: meta.mappedEpisode || meta.episode || 1,
    type: meta.type,
    season: meta.season || 1,
    episode: meta.episode || 1,
    title: meta.title || '',
    year: meta.year || '',
    url: meta.url || '',
    config: meta.config || {{}},
    action: meta.action || '',
    params: meta.params || {{}},
    auth: meta.auth || {{}},
    cache: meta.cache || {{}},
    kit: meta.kit || 0,
    protocol: meta.protocol || 0,
    matchId: meta.matchId || '',
    source: meta.source || '',
    stream: meta.stream || '',
    eventId: meta.eventId || '',
    embedUrl: meta.embedUrl || '',
    iframe: meta.iframe || meta.embedUrl || '',
    category: meta.category || '',
    log: function(msg) {{ console.log('[' + pluginLabel + '] ' + String(msg == null ? '' : msg)); }},
    error: function(msg) {{ console.error('[' + pluginLabel + '] Error: ' + String(msg == null ? '' : msg)); }},
    fetch: globalThis.fetch,
    chromeFetch: globalThis.__engineChromeFetch || globalThis.fetch,
    html: globalThis.__engineHtml,
    host: (function(){{
      var h = globalThis.__engineHost;
      if (typeof h !== 'function') h = function(){{ return Promise.resolve([]); }};
      h.tmdb = {{
        match: function(query) {{
          return Promise.resolve(__native_tmdb_match(JSON.stringify(query == null ? {{}} : query))).then(function(raw){{
            if (!raw || raw === 'null') return null;
            try {{ return JSON.parse(raw); }} catch (e) {{ return null; }}
          }});
        }}
      }};
      return h;
    }})(),
    hop: globalThis.__engineHop,
    crypto: Object.assign({{}}, globalThis.CryptoJS || {{}}, {{
      streamDecrypt: streamDecrypt,
      kisskhKkey: function(episodeId, kind) {{
        return __native_kisskh_kkey((episodeId|0), String(kind == null ? 'video' : kind)) || '';
      }},
      encodePipe: function(payload) {{
        var raw = typeof payload === 'string' ? payload : JSON.stringify(payload == null ? {{}} : payload);
        return __native_encode_pipe(String(raw)) || '';
      }},
      decodePipe: function(body, xObf) {{
        var raw = __native_decode_pipe(String(body == null ? '' : body), String(xObf == null ? '' : xObf)) || '';
        if (!raw) return null;
        try {{ return JSON.parse(raw); }} catch (e) {{ return null; }}
      }},
      solvePow: function(challenge, difficulty, max) {{
        var raw = __native_solve_pow(String(challenge||''), difficulty|0, (max==null?5000000:max)|0);
        if (!raw) return null;
        try {{ return JSON.parse(raw); }} catch (e) {{ return null; }}
      }},
      solveScryptPow: function(challenge) {{
        var raw = __native_solve_scrypt_pow(JSON.stringify(challenge == null ? {{}} : challenge));
        return raw || null;
      }}
    }}),
    streamcrypto: {{ decrypt: streamDecrypt }}
  }};
  var r = await fn(ctx);
  return JSON.stringify(r == null ? [] : r);
}})()
"#,
        pid = serde_json::to_string(&plugin_id).unwrap(),
        meta = meta_json,
        label = serde_json::to_string(&plugin_label).unwrap(),
    );

    let promise: Promise = ctx
        .eval(invoker.as_str())
        .catch(&ctx)
        .map_err(|e| e.to_string())?;
    let raw: String = promise
        .into_future()
        .await
        .catch(&ctx)
        .map_err(|e| e.to_string())?;
    let streams: Vec<Value> = serde_json::from_str(&raw).unwrap_or_default();
    let needs_host = host_req.lock().ok().and_then(|g| g.clone());
    Ok((streams, needs_host))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn two_runtimes_parallel_smoke() {
        let code = r#"
function extract(ctx) {
  return Promise.resolve([{ url: 'https://example.com/' + ctx.tmdbId, name: 't' }]);
}
"#;
        let mk = |id: &str| ExtractRequest {
            plugin_id: id.into(),
            code: code.into(),
            ctx: serde_json::json!({ "tmdbId": id, "type": "movie", "title": "x" }),
            timeout_ms: 5_000,
            allow_host_fallback: false,
            hops: vec![],
            hop_depth: 0,
        };
        let (a, b) = tokio::join!(extract(mk("a")), extract(mk("b")));
        assert_eq!(a.streams.len(), 1);
        assert_eq!(b.streams.len(), 1);
        assert!(a.error.is_none());
        assert!(b.error.is_none());
    }

    #[tokio::test]
    async fn cryptojs_aes_passphrase_roundtrip() {
        let code = r#"
function extract(ctx) {
  var C = ctx.crypto;
  var enc = C.AES.encrypt('hello-forja', 'secret-key').toString();
  var dec = C.AES.decrypt(enc, 'secret-key').toString(C.enc.Utf8);
  return Promise.resolve([{ url: 'https://example.com/' + dec, name: 't' }]);
}
"#;
        let r = extract(ExtractRequest {
            plugin_id: "crypto".into(),
            code: code.into(),
            ctx: serde_json::json!({ "tmdbId": "1", "type": "movie" }),
            timeout_ms: 5_000,
            allow_host_fallback: false,
            hops: vec![],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert_eq!(r.streams.len(), 1);
        assert_eq!(
            r.streams[0].get("url").and_then(|u| u.as_str()),
            Some("https://example.com/hello-forja")
        );
    }

    #[tokio::test]
    async fn hop_nested_extract() {
        let hop_code = r#"
function extract(ctx) {
  return Promise.resolve([{ url: ctx.url + '/hopped', name: 'hop' }]);
}
"#;
        let code = r#"
function extract(ctx) {
  return ctx.hop('https://filemoon.sx/e/abc').then(function(rows){
    return rows;
  });
}
"#;
        let r = extract(ExtractRequest {
            plugin_id: "parent".into(),
            code: code.into(),
            ctx: serde_json::json!({ "tmdbId": "1", "type": "movie" }),
            timeout_ms: 10_000,
            allow_host_fallback: false,
            hops: vec![HopScript {
                id: "filemoon".into(),
                hosts: vec!["filemoon.sx".into()],
                code: hop_code.into(),
            }],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert_eq!(r.streams.len(), 1);
        assert_eq!(
            r.streams[0].get("url").and_then(|u| u.as_str()),
            Some("https://filemoon.sx/e/abc/hopped")
        );
    }

    #[tokio::test]
    async fn cheerio_html_select() {
        let code = r#"
function extract(ctx) {
  var $ = ctx.html('<div><a class="btn-success" href="/watch/1">Play</a></div>');
  var href = $('a.btn-success').first().attr('href');
  var text = $('a.btn-success').first().text();
  return Promise.resolve([{ url: 'https://ex.com' + href, name: String(text).trim() }]);
}
"#;
        let r = extract(ExtractRequest {
            plugin_id: "cheerio".into(),
            code: code.into(),
            ctx: serde_json::json!({ "tmdbId": "1", "type": "movie" }),
            timeout_ms: 30_000,
            allow_host_fallback: false,
            hops: vec![],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert_eq!(r.streams.len(), 1);
        assert_eq!(
            r.streams[0].get("url").and_then(|u| u.as_str()),
            Some("https://ex.com/watch/1")
        );
    }


    #[tokio::test]
    async fn host_fallback_flag() {
        let code = r#"
function extract(ctx) {
  return ctx.host('vidrock').then(function(){ return []; });
}
"#;
        let r = extract(ExtractRequest {
            plugin_id: "hosty".into(),
            code: code.into(),
            ctx: serde_json::json!({ "tmdbId": "1", "type": "movie" }),
            timeout_ms: 5_000,
            allow_host_fallback: true,
            hops: vec![],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert!(r.streams.is_empty());
        assert_eq!(r.needs_host.as_deref(), Some("vidrock"));
    }

    #[tokio::test]
    async fn catalog_request_fields_are_first_class_on_ctx() {
        let code = r#"
function extract(ctx) {
  return [{
    url: 'catalog',
    action: String(ctx.action || ''),
    rail: String((ctx.params && ctx.params.rail) || ''),
    kit: ctx.kit || 0,
    protocol: ctx.protocol || 0,
    etag: String((ctx.cache && ctx.cache.etag) || ''),
    subject: String((ctx.auth && ctx.auth.subject) || ''),
    hasTmdbMatch: !!(ctx.host && ctx.host.tmdb && typeof ctx.host.tmdb.match === 'function')
  }];
}
"#;
        let r = extract(ExtractRequest {
            plugin_id: "hub".into(),
            code: code.into(),
            ctx: serde_json::json!({
                "type": "live",
                "action": "rail",
                "params": { "rail": "trending", "limit": 12 },
                "auth": { "subject": "u1" },
                "cache": { "etag": "abc" },
                "kit": 1,
                "protocol": 1,
                "config": { "apiKey": "x" }
            }),
            timeout_ms: 5_000,
            allow_host_fallback: false,
            hops: vec![],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert_eq!(r.streams.len(), 1);
        let row = &r.streams[0];
        assert_eq!(row.get("action").and_then(|v| v.as_str()), Some("rail"));
        assert_eq!(row.get("rail").and_then(|v| v.as_str()), Some("trending"));
        assert_eq!(row.get("kit").and_then(|v| v.as_i64()), Some(1));
        assert_eq!(row.get("protocol").and_then(|v| v.as_i64()), Some(1));
        assert_eq!(row.get("etag").and_then(|v| v.as_str()), Some("abc"));
        assert_eq!(row.get("subject").and_then(|v| v.as_str()), Some("u1"));
        assert_eq!(
            row.get("hasTmdbMatch").and_then(|v| v.as_bool()),
            Some(true)
        );
    }

    #[tokio::test]
    async fn dailymotion_http_provider_finds_streams() {
        let http = std::fs::read_to_string(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../plugins/providers/dailymotion.js"
        ))
        .expect("http script");
        let hop = std::fs::read_to_string(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../plugins/providers/hops/dailymotion.js"
        ))
        .expect("hop script");
        let r = extract(ExtractRequest {
            plugin_id: "dailymotion".into(),
            code: http,
            ctx: serde_json::json!({
                "tmdbId": "299952",
                "type": "drama",
                "season": 1,
                "episode": 1,
                "title": "The Early Spring",
                "config": {}
            }),
            timeout_ms: 60_000,
            allow_host_fallback: false,
            hops: vec![HopScript {
                id: "hop-dailymotion".into(),
                hosts: vec![
                    "dailymotion.com".into(),
                    "dai.ly".into(),
                    "geo.dailymotion.com".into(),
                ],
                code: hop,
            }],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert!(!r.streams.is_empty(), "expected streams, got {r:?}");
        for s in &r.streams {
            let u = s.get("url").and_then(|v| v.as_str()).unwrap_or("");
            assert!(!u.contains("cdndirector.dailymotion.com"), "{u}");
        }
    }

    #[tokio::test]
    async fn dailymotion_hop_expands_cdndirector_to_dmcdn() {
        let code = std::fs::read_to_string(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../plugins/providers/hops/dailymotion.js"
        ))
        .expect("hop script");
        let r = extract(ExtractRequest {
            plugin_id: "hop-dailymotion".into(),
            code,
            ctx: serde_json::json!({
                "url": "https://www.dailymotion.com/video/xb1gvle",
                "config": { "name": "Dailymotion" }
            }),
            timeout_ms: 30_000,
            allow_host_fallback: false,
            hops: vec![],
            hop_depth: 0,
        })
        .await;
        assert!(r.error.is_none(), "{:?}", r.error);
        assert!(!r.streams.is_empty(), "expected expanded streams: {r:?}");
        for s in &r.streams {
            let u = s.get("url").and_then(|v| v.as_str()).unwrap_or("");
            assert!(
                !u.contains("cdndirector.dailymotion.com"),
                "must not return fingerprinted master: {u}"
            );
            assert!(
                u.contains("dmcdn.net") || u.contains(".m3u8") || u.contains(".mp4"),
                "unexpected url: {u}"
            );
        }
    }
}
