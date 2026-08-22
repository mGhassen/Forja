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

use crate::stream_crypto;

/// Same key as `crates/anime/src/extractors/miruro.rs` PIPE_OBF_KEY.
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
pub struct ExtractRequest {
    pub plugin_id: String,
    pub code: String,
    pub ctx: Value,
    #[serde(default = "default_timeout_ms")]
    pub timeout_ms: u64,
    #[serde(default)]
    pub allow_host_fallback: bool,
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
  globalThis.__engineHtml = function(){ throw new Error('UNSUPPORTED:cheerio'); };
  globalThis.__engineHop = function(){ return Promise.reject(new Error('UNSUPPORTED:hop')); };
  globalThis.__engineHost = function(){ return Promise.resolve([]); };
})();
"#;

fn fetch_cancelled_json(url: &str) -> String {
    serde_json::json!({
        "ok": false, "status": 0, "statusText": "cancelled",
        "url": url, "body": "", "headers": {}
    })
    .to_string()
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

fn stream_decrypt_safe(body: String, seed: String, tmdb_id: String) -> String {
    match stream_crypto::decrypt(&body, &seed, &tmdb_id) {
        Ok(s) => s,
        Err(e) => format!("ENGINE_DECRYPT_ERROR:{e}"),
    }
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
        kisskh::KkeyKind::Subtitle
    } else {
        kisskh::KkeyKind::Video
    };
    kisskh::generate_kkey(episode_id, k)
}

pub async fn extract(req: ExtractRequest) -> ExtractResult {
    let timeout = Duration::from_millis(req.timeout_ms.max(1_000));
    let token = utils::engine_cancel::cancellation_token();
    tokio::select! {
        r = tokio::time::timeout(timeout, extract_inner(req)) => match r {
            Ok(r) => r,
            Err(_) => ExtractResult {
                streams: vec![],
                error: Some("engine-js timed out".into()),
                unsupported: None,
            },
        },
        _ = token.cancelled() => ExtractResult {
            streams: vec![],
            error: Some("cancelled".into()),
            unsupported: None,
        },
    }
}

async fn extract_inner(req: ExtractRequest) -> ExtractResult {
    if cancelled() {
        return ExtractResult {
            streams: vec![],
            error: Some("cancelled".into()),
            unsupported: None,
        };
    }

    let rt = match AsyncRuntime::new() {
        Ok(r) => r,
        Err(e) => {
            return ExtractResult {
                streams: vec![],
                error: Some(format!("AsyncRuntime: {e}")),
                unsupported: Some(true),
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
            };
        }
    };

    let plugin_id = req.plugin_id.clone();
    let code = req.code.clone();
    let meta = req.ctx.clone();
    let plugin_label = plugin_id.clone();

    let result = async_with!(ctx => |ctx| {
        run_in_ctx(ctx, plugin_id, code, meta, plugin_label).await
    })
    .await;

    let _ = rt.idle().await;

    match result {
        Ok(streams) => ExtractResult {
            streams,
            error: None,
            unsupported: None,
        },
        Err(e) => {
            let msg = e.to_string();
            let unsupported = msg.contains("UNSUPPORTED:");
            ExtractResult {
                streams: vec![],
                error: Some(msg),
                unsupported: if unsupported { Some(true) } else { None },
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
) -> Result<Vec<Value>, String> {
    let fetch_fn = Function::new(ctx.clone(), Async(native_fetch))
        .map_err(|e| e.to_string())?
        .with_name("__native_fetch")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_fetch", fetch_fn)
        .map_err(|e| e.to_string())?;

    let decrypt_fn = Function::new(ctx.clone(), stream_decrypt_safe)
        .map_err(|e| e.to_string())?
        .with_name("__native_stream_decrypt")
        .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_stream_decrypt", decrypt_fn)
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
        eprintln!("[engine-js] {msg}");
    })
    .map_err(|e| e.to_string())?
    .with_name("__native_log")
    .map_err(|e| e.to_string())?;
    ctx.globals()
        .set("__native_log", log_fn)
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
    var out = __native_stream_decrypt(String(body == null ? '' : body), String(seed == null ? '' : seed), String(tmdbId == null ? '' : tmdbId));
    if (typeof out === 'string' && out.indexOf('ENGINE_DECRYPT_ERROR:') === 0) {{
      throw new Error(out.substring('ENGINE_DECRYPT_ERROR:'.length));
    }}
    return out;
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
    log: function(msg) {{ console.log('[' + pluginLabel + '] ' + String(msg == null ? '' : msg)); }},
    error: function(msg) {{ console.error('[' + pluginLabel + '] Error: ' + String(msg == null ? '' : msg)); }},
    fetch: globalThis.fetch,
    html: globalThis.__engineHtml,
    host: globalThis.__engineHost,
    hop: globalThis.__engineHop,
    crypto: {{
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
      }}
    }},
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
    Ok(streams)
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
        };
        let (a, b) = tokio::join!(extract(mk("a")), extract(mk("b")));
        assert_eq!(a.streams.len(), 1);
        assert_eq!(b.streams.len(), 1);
        assert!(a.error.is_none());
        assert!(b.error.is_none());
    }
}
